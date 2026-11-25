extends SceneTree

## Headless unit test for DevConsole (res://dev_console.gd).
##
## Run from the godot/ project directory:
##     godot --headless -s test_dev_console.gd
##
## Exit code 0 = all checks pass, 1 = at least one failure.
## Builds the console outside a scene tree (setup() is public, _ready's
## only job is to call it), wires it to synthetic WorldEnvironment /
## Camera3D / fake Spheres with synthetic MeshInstance3D stars, feeds
## commands via _execute(), and checks the values on the nodes.
##
## Not covered headless: opening/closing on the ^ key and LineEdit focus/
## history (need a live GUI), and the visual effect of the settings —
## manual verification (run the game, press ^).

const DevConsoleScript := preload("res://dev_console.gd")
const StarSettingsScript := preload("res://star_settings.gd")

var _checks := 0
var _failures := 0
var _console: Node
var _env: WorldEnvironment
var _camera: Camera3D
var _spheres: FakeSpheres


func _cleanup() -> void:
	if _console != null:
		_console.free()
	if _env != null:
		_env.free()
	if _camera != null:
		_camera.free()
	if _spheres != null:
		for star in _spheres.stars:
			star.free()
		_spheres.stars.clear()
		_spheres.free()
	_console = null
	_env = null
	_camera = null
	_spheres = null


## Spheres stand-in: only what DevConsole touches (.stars + the signal).
class FakeSpheres extends Node:
	signal stars_rebuilt(box: AABB, cone: Dictionary)
	var stars: Array = []


func _init() -> void:
	_test_harvested_defaults()
	_test_env_and_camera_apply()
	_test_star_apply()
	_test_rebuild_reapply()
	_test_light_defaults_harvest()
	_test_commands()
	_test_export()
	_test_toggle()
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

func _expect(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: " + msg)


## Fresh console with a recognizable scene state (background 5.5,
## far 123456 — different from the registry defaults, so harvesting is
## observable).
func _setup() -> void:
	_env = WorldEnvironment.new()
	_env.environment = Environment.new()
	_env.environment.background_energy_multiplier = 5.5
	_camera = Camera3D.new()
	_camera.far = 123456.0
	_spheres = FakeSpheres.new()
	_console = DevConsoleScript.new()
	_console.environment = _env
	_console.camera = _camera
	_console.spheres = _spheres
	_console.setup()


## Synthetic star. scale != 1.0 emulates a line/verse/poem star (bigger
## scale + per-star material_override).
func _make_star(scale := 1.0, light_energy := 100.0, omni_range := 100000.0) -> MeshInstance3D:
	var star := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	var mesh := SphereMesh.new()
	mesh.material = mat
	star.mesh = mesh
	if scale != 1.0:
		star.scale = Vector3.ONE * scale
		var override := StandardMaterial3D.new()
		override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		override.albedo_color = Color.MAGENTA
		star.material_override = override
	var light := OmniLight3D.new()
	light.name = "OmniLight3D" # explicit: Godot 4.7 auto-names are @Class@N
	light.light_energy = light_energy
	light.omni_range = omni_range
	light.omni_attenuation = 2.0
	star.add_child(light)
	_spheres.stars.append(star)
	return star


func _exec(line: String) -> void:
	_console._execute(line)


# ---------------------------------------------------------------------------
# tests
# ---------------------------------------------------------------------------

func _test_harvested_defaults() -> void:
	_setup()
	_expect(_console.settings.get_default(&"background_energy") == 5.5,
		"harvests background_energy from the environment")
	_expect(_console.settings.get_default(&"camera_far") == 123456.0,
		"harvests camera_far from the camera")
	_expect(is_equal_approx(_console.settings.value(&"camera_near"), 0.05),
		"harvested camera_near matches the node")
	_expect(_console.settings.get_default(&"glow_blend_mode") == "screen",
		"harvested glow blend mode as name (engine default = screen)")
	_cleanup()


func _test_env_and_camera_apply() -> void:
	_setup()
	_exec("set glow_enabled true")
	_expect(_env.environment.glow_enabled == true, "glow_enabled applied")
	_exec("set glow_blend_mode softlight")
	_expect(_env.environment.glow_blend_mode == Environment.GLOW_BLEND_MODE_SOFTLIGHT,
		"glow_blend_mode applied")
	_exec("set background_energy 2.0")
	_expect(_env.environment.background_energy_multiplier == 2.0, "background_energy applied")
	_exec("set volumetric_fog_density 0.05")
	_expect(is_equal_approx(_env.environment.volumetric_fog_density, 0.05), "volumetric_fog_density applied")
	_exec("set camera_far 50000")
	_expect(_camera.far == 50000.0, "camera_far applied")
	_exec("set camera_fov 60")
	_expect(_camera.fov == 60.0, "camera_fov applied")
	# bad value: node keeps the value from before the bad set
	_exec("set glow_enabled bogus")
	_expect(_env.environment.glow_enabled == true, "invalid value leaves node state")
	_cleanup()


func _test_star_apply() -> void:
	_setup()
	var word := _make_star()
	var extra := _make_star(8.0)
	_spheres.stars_rebuilt.emit(AABB(), {}) # off-tree -> synchronous apply

	_exec("set star_emission_energy 6")
	var word_mat: StandardMaterial3D = word.mesh.surface_get_material(0)
	_expect(word_mat.emission_energy_multiplier == 6.0, "emission on the word-star mesh material")
	_expect(word_mat.emission_enabled == true, "emission enabled")
	var extra_mat: StandardMaterial3D = extra.material_override
	_expect(extra_mat.emission_enabled == true and extra_mat.emission_energy_multiplier == 6.0,
		"emission on the extra star's override material")

	_exec("set star_unshaded true")
	_expect(word_mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "unshaded applied")
	_exec("set star_unshaded false")
	_expect(word_mat.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL, "shaded restored")

	_exec("set star_size_scale 2")
	_expect(word.scale == Vector3.ONE * 2.0, "word star scaled 1x2")
	_expect(extra.scale == Vector3.ONE * 16.0, "extra star scaled 8x2 (base kept)")
	_exec("set star_size_scale 3")
	_expect(extra.scale == Vector3.ONE * 24.0, "re-apply uses captured base, not current scale")

	_exec("set star_visibility_range_end 5000")
	_expect(word.visibility_range_end == 5000.0, "visibility_range_end applied")

	_exec("set light_energy 5")
	var light: OmniLight3D = word.get_node("OmniLight3D")
	_expect(light.light_energy == 5.0, "light_energy applied")
	_exec("set omni_range 250")
	_expect(light.omni_range == 250.0, "omni_range applied")
	_exec("set omni_attenuation 1")
	_expect(light.omni_attenuation == 1.0, "omni_attenuation applied")
	_exec("set shadow_enabled true")
	_expect(light.shadow_enabled == true, "shadow_enabled applied")
	_exec("set star_lights_enabled false")
	_expect(light.visible == false, "star_lights_enabled hides the light")
	_exec("set star_lights_enabled true")
	_expect(light.visible == true, "star_lights_enabled shows the light")
	_cleanup()


func _test_rebuild_reapply() -> void:
	_setup()
	_make_star()
	_spheres.stars_rebuilt.emit(AABB(), {})
	_exec("set star_emission_energy 8")
	_exec("set omni_range 300")
	# a rebuild adds fresh stars -> they must pick up the current settings
	var late := _make_star()
	_spheres.stars_rebuilt.emit(AABB(), {})
	var late_mat: StandardMaterial3D = late.mesh.surface_get_material(0)
	_expect(late_mat.emission_energy_multiplier == 8.0, "rebuild re-applies emission to new stars")
	var late_light: OmniLight3D = late.get_node("OmniLight3D")
	_expect(late_light.omni_range == 300.0, "rebuild re-applies light settings to new stars")
	_cleanup()


func _test_light_defaults_harvest() -> void:
	_setup()
	var star := _make_star(1.0, 77.0, 12345.0)
	_spheres.stars_rebuilt.emit(AABB(), {})
	_expect(_console.settings.get_default(&"light_energy") == 77.0,
		"light defaults harvested from the first star")
	_expect(_console.settings.get_default(&"omni_range") == 12345.0,
		"omni_range default harvested")
	_expect(_console.settings.value(&"light_energy") == 77.0,
		"unmodified value follows the harvest")

	# a user-modified value survives later rebuilds (harvest is one-shot)
	_exec("set light_energy 5")
	_make_star(1.0, 99.0, 100000.0)
	_spheres.stars_rebuilt.emit(AABB(), {})
	_expect(_console.settings.value(&"light_energy") == 5.0, "user value kept across rebuilds")
	_expect(_console.settings.get_default(&"light_energy") == 77.0, "no re-harvest")
	_expect(star != null, "star still there (sanity)")
	_cleanup()


func _test_commands() -> void:
	_setup()
	# set + relative
	_exec("set light_energy 100")
	_exec("set light_energy +0.5")
	_expect(_console.settings.value(&"light_energy") == 100.5, "relative adjust")
	_exec("set light_energy -0.25")
	_expect(_console.settings.value(&"light_energy") == 100.25, "relative adjust -")
	# unknown setting
	_exec("set nope 1")
	_expect(_console.settings.has_key(&"nope") == false, "unknown set is a no-op")
	# unknown command
	_exec("bogus command")
	_expect(true, "unknown command does not crash")
	# get / list / help / clear do not crash and do not change state
	_exec("get camera_far")
	_exec("list glow")
	_exec("list env")
	_exec("list star")
	_exec("help")
	_exec("help set")
	_exec("clear")
	_expect(_console.settings.value(&"camera_far") == 123456.0, "read-only commands leave state")
	# reset
	_exec("set glow_enabled true")
	_exec("reset glow_enabled")
	_expect(_console.settings.value(&"glow_enabled") == false, "reset key")
	_expect(_env.environment.glow_enabled == false, "reset applied to the environment")
	_exec("set camera_far 1")
	_exec("reset all")
	_expect(_console.settings.value(&"camera_far") == 123456.0, "reset all back to harvested default")
	_expect(_camera.far == 123456.0, "reset all applied to the camera")
	_exec("reset nope")
	_expect(true, "reset unknown key does not crash")
	_cleanup()


func _test_export() -> void:
	_setup()
	_exec("set camera_far 777")
	_exec("set light_color #ff8800")
	_exec("export user://test_dev_console_export.json")
	var f := FileAccess.open("user://test_dev_console_export.json", FileAccess.READ)
	_expect(f != null, "export file written")
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		_expect(parsed is Dictionary, "export is a JSON object")
		if parsed is Dictionary:
			_expect(parsed.get("camera_far") == 777.0, "export carries camera_far")
			_expect(parsed.get("glow_blend_mode") == "screen", "export stores enum as name")
			_expect(parsed.get("light_color") == "#ff8800", "export stores color as hex")
			_expect(parsed.size() == _console.settings.keys().size(), "export has every key")
	# cleanup (user:// data dir, not the repo)
	var global_path := ProjectSettings.globalize_path("user://test_dev_console_export.json")
	DirAccess.remove_absolute(global_path)
	_expect(FileAccess.file_exists("user://test_dev_console_export.json") == false, "export cleaned up")
	_cleanup()


func _test_toggle() -> void:
	_setup()
	var player := CharacterBody3D.new()
	player.set_script(preload("res://camera_rig.gd"))
	_console.player = player
	_expect(_console.open == false, "starts closed")
	_console._toggle()
	_expect(_console.open == true, "opens")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "mouse released while open")
	_expect(player.manual == false, "player disabled while open")
	_console._toggle()
	_expect(_console.open == false, "closes")
	_expect(player.manual == true, "player manual state restored")
	_expect(_console._root.visible == false, "panel hidden when closed")
	# bound key path (test_input_handler pattern: synthetic event, direct
	# dispatch — headless has no OS input pump for Input.parse_input_event)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_APOSTROPHE
	ev.pressed = true
	_expect(ev.is_action_pressed(&"toggle_console"), "bound key matches the action")
	_console._input(ev)
	_expect(_console.open == true, "opens on the bound key")
	_console._input(ev)
	_expect(_console.open == false, "closes on the bound key")
	player.free()
	_cleanup()
