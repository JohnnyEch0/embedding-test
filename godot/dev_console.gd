extends CanvasLayer

const StarSettingsScript := preload("res://star_settings.gd")

## In-game dev console for tuning star/light/glow/camera settings.
##
## Toggle with the `toggle_console` action (physical key left of "1", or
## ^ / Shift+7 on a German layout). While open: the mouse is released, the
## player is disabled, and every input the LineEdit does not claim is
## swallowed, so the game (InputHandler, CharacterBody3D) cannot react.
## AutoOrbit is _process-driven and keeps orbiting, so the scene stays
## alive while tuning.
##
## The settings model is StarSettings (star_settings.gd). This node is the
## view and the applier: it builds its own UI, harvests defaults from the
## live scene (environment/camera at startup, per-star lights from the
## first spawned star), pushes values onto the nodes, and re-applies the
## star keys after every star rebuild (deferred, so line/verse/poem stars
## spawned after the stars_rebuilt signal are covered).
##
## setup() is public and called from _ready so headless tests can drive
## the console without a scene tree (see test_dev_console.gd).

@export var environment: WorldEnvironment
@export var camera: Camera3D
@export var spheres: Node # Spheres (spheres.gd): .stars + stars_rebuilt
@export var player: CharacterBody3D

var settings: StarSettingsScript
var open := false

const LOG_LIMIT := 200
const HISTORY_LIMIT := 50
const CLUSTER_LIMIT_PATH := "rendering/limits/cluster_builder/max_clustered_elements"

## setting key -> Environment property
const ENV_PROPS := {
	&"glow_enabled": &"glow_enabled",
	&"glow_intensity": &"glow_intensity",
	&"glow_strength": &"glow_strength",
	&"glow_bloom": &"glow_bloom",
	&"glow_hdr_threshold": &"glow_hdr_threshold",
	&"background_energy": &"background_energy_multiplier",
	&"volumetric_fog_enabled": &"volumetric_fog_enabled",
	&"volumetric_fog_density": &"volumetric_fog_density",
}
const GLOW_BLEND_MODES := {
	"additive": Environment.GLOW_BLEND_MODE_ADDITIVE,
	"screen": Environment.GLOW_BLEND_MODE_SCREEN,
	"softlight": Environment.GLOW_BLEND_MODE_SOFTLIGHT,
	"replace": Environment.GLOW_BLEND_MODE_REPLACE,
}
## setting key -> Camera3D property
const CAM_PROPS := {
	&"camera_far": &"far",
	&"camera_near": &"near",
	&"camera_fov": &"fov",
}
## setting key -> OmniLight3D property
const LIGHT_PROPS := {
	&"light_energy": &"light_energy",
	&"light_color": &"light_color",
	&"omni_range": &"omni_range",
	&"omni_attenuation": &"omni_attenuation",
	&"light_specular": &"light_specular",
	&"light_indirect_energy": &"light_indirect_energy",
	&"shadow_enabled": &"shadow_enabled",
	&"distance_fade_enabled": &"distance_fade_enabled",
	&"distance_fade_begin": &"distance_fade_begin",
	&"distance_fade_length": &"distance_fade_length",
}

var _root: Control
var _log: RichTextLabel
var _line: LineEdit
var _log_count := 0
var _history: Array[String] = []
var _history_index := -1
var _draft := ""
var _saved_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _saved_manual := true
var _lights_harvested := false


func _ready() -> void:
	setup()


func setup() -> void:
	if settings != null:
		return # idempotent: _ready runs setup again if the node enters the tree later
	_build_ui()
	settings = StarSettingsScript.new(_harvest_scene())
	settings.changed.connect(_on_setting_changed)
	if spheres != null and spheres.has_signal(&"stars_rebuilt"):
		spheres.connect(&"stars_rebuilt", _on_stars_rebuilt)
	_apply_all()


# ---------------------------------------------------------------------------
# input: toggle + isolation
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# _input runs before the GUI, so the toggle works even while the
	# LineEdit has focus, and the key never gets typed into the console.
	if event.is_action_pressed(&"toggle_console"):
		_toggle()
		_mark_handled()
		return
	if open and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		_close()
		_mark_handled()


func _shortcut_input(event: InputEvent) -> void:
	# _shortcut_input runs after the GUI (the LineEdit already had its
	# chance) and before _unhandled_input (InputHandler, CharacterBody3D).
	# While open, swallow everything the console did not claim.
	if open:
		_mark_handled()


func _mark_handled() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _toggle() -> void:
	if open:
		_close()
	else:
		_open()


func _open() -> void:
	open = true
	_root.visible = true
	_saved_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player != null:
		_saved_manual = player.manual
		player.manual = false
	if is_inside_tree():
		_line.grab_focus()


func _close() -> void:
	open = false
	_root.visible = false
	Input.mouse_mode = _saved_mouse_mode
	if player != null:
		player.manual = _saved_manual


# ---------------------------------------------------------------------------
# UI (built in code; the scene only carries this CanvasLayer)
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 380.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.05, 0.92)
	style.border_color = Color(0.3, 0.4, 0.6, 0.8)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_log)

	_line = LineEdit.new()
	_line.placeholder_text = "type 'help' — ^ or Esc to close"
	_line.custom_minimum_size = Vector2(0, 34)
	_line.text_submitted.connect(_on_text_submitted)
	_line.gui_input.connect(_on_input_gui)
	vbox.add_child(_line)

	print_log("dev console — type 'help' for commands")


func print_log(text: String, color := Color(0.85, 0.88, 0.95)) -> void:
	if _log == null:
		print(text)
		return
	_log_count += 1
	if _log_count > LOG_LIMIT:
		_log.clear()
		_log_count = 0
	_log.push_color(color)
	_log.append_text(text + "\n")
	_log.pop()


# ---------------------------------------------------------------------------
# command line + history
# ---------------------------------------------------------------------------

func _on_text_submitted(text: String) -> void:
	var cmd := text.strip_edges()
	if not cmd.is_empty():
		if _history.is_empty() or _history.back() != cmd:
			_history.append(cmd)
		if _history.size() > HISTORY_LIMIT:
			_history.pop_front()
		_history_index = _history.size()
		_draft = ""
		_execute(cmd)
	_line.clear()


func _on_input_gui(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_UP:
			_history_prev()
		elif event.keycode == KEY_DOWN:
			_history_next()
		else:
			return
	get_viewport().set_input_as_handled()


func _history_prev() -> void:
	if _history.is_empty():
		return
	if _history_index == _history.size():
		_draft = _line.text
	_history_index = maxi(_history_index - 1, 0)
	_line.text = _history[_history_index]


func _history_next() -> void:
	if _history.is_empty():
		return
	if _history_index < 0:
		return
	if _history_index == _history.size() - 1:
		_history_index = _history.size()
		_line.text = _draft
		return
	_history_index += 1
	_line.text = _history[_history_index]


# ---------------------------------------------------------------------------
# commands
# ---------------------------------------------------------------------------

func _execute(line: String) -> void:
	print_log("> " + line, Color(0.6, 0.9, 0.6))
	var tokens: PackedStringArray = line.strip_edges().split(" ", false)
	if tokens.is_empty():
		return
	var cmd := tokens[0].to_lower()
	match cmd:
		"help": _cmd_help(tokens)
		"list": _cmd_list(tokens)
		"get": _cmd_get(tokens)
		"set": _cmd_set(tokens)
		"reset": _cmd_reset(tokens)
		"export": _cmd_export(tokens)
		"clear":
			_log.clear()
			_log_count = 0
		_:
			_error("unknown command '%s' — try 'help'" % cmd)


func _cmd_help(tokens: PackedStringArray) -> void:
	if tokens.size() > 1:
		match tokens[1].to_lower():
			"set": print_log("set <key> <value> — apply a setting; floats accept relative +0.5 / -0.5")
			"list": print_log("list [prefix] — show settings; prefix narrows by key prefix or group (star/env/camera/project)")
			"get": print_log("get <key> — value, default, range, help")
			"reset": print_log("reset [key|all] — back to the defaults harvested from the scene at startup")
			"export": print_log("export [path] — write all values as JSON (default user://star_settings.json)")
			"clear": print_log("clear — clear the log")
			"help": print_log("help [command] — this help")
			_: _error("unknown command '%s'" % tokens[1])
		return
	print_log("commands:")
	print_log("  help [command]     this help")
	print_log("  list [prefix]      all settings (* = changed)")
	print_log("  get <key>          value, default, range, help")
	print_log("  set <key> <value>  set (floats: relative +0.5 / -0.5)")
	print_log("  reset [key|all]    back to scene defaults")
	print_log("  export [path]      write JSON (default user://star_settings.json)")
	print_log("  clear              clear the log")
	print_log("starters:")
	print_log("  set glow_enabled true · set star_emission_energy 6 · set glow_hdr_threshold 0.8")
	print_log("  set star_lights_enabled false   (emissive-only look, no real lights)")


func _cmd_list(tokens: PackedStringArray) -> void:
	var prefix := tokens[1] if tokens.size() > 1 else ""
	var matched: Array[StringName]
	if StarSettingsScript.GROUPS.has(prefix):
		matched = settings.keys_in_group(StringName(prefix))
	else:
		matched = settings.keys(prefix)
	for key in matched:
		var mark := "*" if settings.is_modified(key) else " "
		print_log("%s %s = %s   (def %s)" % [mark, key, _fmt(settings.value(key)), _fmt(settings.get_default(key))])
	print_log("* = changed from default · 'get <key>' for range and help")


func _cmd_get(tokens: PackedStringArray) -> void:
	if tokens.size() < 2:
		_error("usage: get <key>")
		return
	var key := StringName(tokens[1])
	if not settings.has_key(key):
		_error("unknown setting '%s' — try 'list'" % key)
		return
	var e: Dictionary = settings.entry(key)
	var extra := ""
	match e.type:
		StarSettingsScript.Type.FLOAT, StarSettingsScript.Type.INT:
			extra = "  range " + str(e.min) + " .. " + str(e.max)
		StarSettingsScript.Type.ENUM:
			extra = "  options: " + ", ".join(PackedStringArray(e.options))
	print_log("%s = %s   (def %s)%s" % [key, _fmt(settings.value(key)), _fmt(settings.get_default(key)), extra])
	if e.restart_required:
		print_log("note: restart required to take effect")
	print_log(e.help)


func _cmd_set(tokens: PackedStringArray) -> void:
	if tokens.size() < 3:
		_error("usage: set <key> <value>   (floats accept relative +0.5 / -0.5)")
		return
	var key := StringName(tokens[1])
	# join the rest: allows Color(1, 0.5, 0, 1) with spaces
	var value_text := " ".join(tokens.slice(2))
	var relative := value_text.begins_with("+") or value_text.begins_with("-")
	var err: int = settings.set_from_string(key, value_text, relative)
	if err == StarSettingsScript.ERR_UNKNOWN_KEY:
		_error("unknown setting '%s' — try 'list'" % key)
		return
	if err != OK:
		_error("invalid value '%s' for '%s' — see 'get %s'" % [value_text, key, key])
		return
	print_log("%s = %s" % [key, _fmt(settings.value(key))])
	if settings.entry(key).restart_required:
		print_log("note: in-memory only — add it to project.godot [rendering] and restart to make it stick")


func _cmd_reset(tokens: PackedStringArray) -> void:
	var arg := tokens[1] if tokens.size() > 1 else "all"
	if arg == "all":
		settings.reset_all()
		print_log("reset all settings to defaults")
		return
	var key := StringName(arg)
	var err: int = settings.reset(key)
	if err == StarSettingsScript.ERR_UNKNOWN_KEY:
		_error("unknown setting '%s' — try 'list'" % arg)
		return
	print_log("%s = %s (reset)" % [key, _fmt(settings.value(key))])


func _cmd_export(tokens: PackedStringArray) -> void:
	var path := tokens[1] if tokens.size() > 1 else "user://star_settings.json"
	var json_text := JSON.stringify(settings.to_dict(), "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	file.store_string(json_text + "\n")
	file.close()
	print_log("wrote %s" % path)
	print_log(json_text, Color(0.7, 0.85, 1.0))
	print_log("bake into: emb_star.tscn (star/light_*), main.tscn (glow_*/background_*/volumetric_*/camera_*), project.godot [rendering] (max_clustered_elements)")


func _error(msg: String) -> void:
	print_log("error: " + msg, Color(1.0, 0.5, 0.4))


func _fmt(v: Variant) -> String:
	return str(v)


# ---------------------------------------------------------------------------
# harvesting (defaults from the live scene)
# ---------------------------------------------------------------------------

func _harvest_scene() -> Dictionary:
	var h := {}
	if environment != null and environment.environment != null:
		var env: Environment = environment.environment
		h[&"glow_enabled"] = env.glow_enabled
		h[&"glow_intensity"] = env.glow_intensity
		h[&"glow_strength"] = env.glow_strength
		h[&"glow_bloom"] = env.glow_bloom
		h[&"glow_hdr_threshold"] = env.glow_hdr_threshold
		h[&"glow_blend_mode"] = _glow_blend_name(env.glow_blend_mode)
		h[&"background_energy"] = env.background_energy_multiplier
		h[&"volumetric_fog_enabled"] = env.volumetric_fog_enabled
		h[&"volumetric_fog_density"] = env.volumetric_fog_density
	if camera != null:
		h[&"camera_far"] = camera.far
		h[&"camera_near"] = camera.near
		h[&"camera_fov"] = camera.fov
	return h


func _glow_blend_name(mode: int) -> String:
	for name in GLOW_BLEND_MODES:
		if GLOW_BLEND_MODES[name] == mode:
			return name
	return "screen"


## The per-star lights do not exist at console startup (no stars yet);
## adopt their defaults from the first spawned star.
func _harvest_light_defaults() -> void:
	if _lights_harvested or spheres == null:
		return
	var stars: Array = spheres.stars
	if stars.is_empty():
		return
	var first_star: Node = stars[0] # typed: get_node_or_null needs a NodePath arg
	var light: OmniLight3D = first_star.get_node_or_null("OmniLight3D")
	if light == null:
		return
	settings.adopt_default(&"light_energy", light.light_energy)
	settings.adopt_default(&"light_color", light.light_color)
	settings.adopt_default(&"omni_range", light.omni_range)
	settings.adopt_default(&"omni_attenuation", light.omni_attenuation)
	settings.adopt_default(&"light_specular", light.light_specular)
	settings.adopt_default(&"light_indirect_energy", light.light_indirect_energy)
	settings.adopt_default(&"shadow_enabled", light.shadow_enabled)
	settings.adopt_default(&"distance_fade_enabled", light.distance_fade_enabled)
	settings.adopt_default(&"distance_fade_begin", light.distance_fade_begin)
	settings.adopt_default(&"distance_fade_length", light.distance_fade_length)
	_lights_harvested = true


# ---------------------------------------------------------------------------
# applying settings onto the live nodes
# ---------------------------------------------------------------------------

func _on_setting_changed(key: StringName) -> void:
	_apply_key(key, settings.value(key))


func _on_stars_rebuilt(_box: AABB, _cone: Dictionary) -> void:
	_harvest_light_defaults()
	# Extra (line/verse/poem) stars are spawned after this signal inside
	# create_stars_from_data, so apply deferred in the tree; headless tests
	# (no tree) apply synchronously.
	if is_inside_tree():
		_apply_star_keys.call_deferred()
	else:
		_apply_star_keys()


func _apply_all() -> void:
	for key in settings.keys():
		_apply_key(key, settings.value(key))


func _apply_key(key: StringName, value: Variant) -> void:
	var group: StringName = settings.entry(key).group
	match group:
		&"star":
			_apply_star_key(key, value)
		&"env":
			_apply_env_key(key, value)
		&"camera":
			_apply_camera_key(key, value)
		&"project":
			_apply_project_key(key, value)


func _apply_star_key(key: StringName, value: Variant) -> void:
	if spheres == null:
		return
	for star in spheres.stars:
		_apply_to_star(star, key, value)


func _apply_star_keys() -> void:
	if spheres == null:
		return
	for star in spheres.stars:
		for key in settings.keys_in_group(&"star"):
			_apply_to_star(star, key, settings.value(key))


func _apply_to_star(star: Node, key: StringName, value: Variant) -> void:
	match key:
		&"star_emission_energy", &"star_unshaded":
			var mat: Material = _star_material(star)
			if not (mat is StandardMaterial3D):
				return
			if key == &"star_emission_energy":
				mat.emission_enabled = true
				mat.emission_energy_multiplier = float(value)
			else:
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED \
					if value else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		&"star_size_scale":
			if not star.has_meta(&"console_base_scale"):
				star.set_meta(&"console_base_scale", star.scale)
			var base: Vector3 = star.get_meta(&"console_base_scale")
			star.scale = base * float(value)
		&"star_visibility_range_end":
			star.visibility_range_end = float(value)
		_:
			var light: OmniLight3D = star.get_node_or_null("OmniLight3D")
			if light == null:
				return
			if key == &"star_lights_enabled":
				light.visible = value
			elif LIGHT_PROPS.has(key):
				light.set(LIGHT_PROPS[key], value)


func _star_material(star: Node) -> Material:
	# Active material: the per-star override (line/verse/poem stars) or the
	# mesh material (word stars — the packed scene's shared material, so
	# future instantiations inherit the tuned values too).
	var mat: Material = star.material_override
	if mat:
		return mat
	var mesh: Mesh = star.mesh
	if mesh != null:
		var surface_mat: Material = mesh.surface_get_material(0)
		if surface_mat != null:
			return surface_mat
	return null


func _apply_env_key(key: StringName, value: Variant) -> void:
	if environment == null or environment.environment == null:
		return
	var env: Environment = environment.environment
	if key == &"glow_blend_mode":
		env.glow_blend_mode = GLOW_BLEND_MODES[str(value)]
	elif ENV_PROPS.has(key):
		env.set(ENV_PROPS[key], value)


func _apply_camera_key(key: StringName, value: Variant) -> void:
	if camera == null or not CAM_PROPS.has(key):
		return
	camera.set(CAM_PROPS[key], value)


func _apply_project_key(key: StringName, value: Variant) -> void:
	# In-memory only: ProjectSettings.save() would rewrite project.godot
	# under the user's feet, so the console reports the value and the
	# export command carries it for manual baking.
	if key == &"max_clustered_elements":
		ProjectSettings.set_setting(CLUSTER_LIMIT_PATH, int(value))
