extends Node3D
@onready var stars_node = $"Spheres"
@onready var canvas := $"CanvasLayer"


var cur_line := 0

# === dimension switching (state + semantics in dim_map.gd)
@export var enforce_distinct := true
var dim_map: DimMap
var dims_hud: Label
## input action -> [axis, direction]
const AXIS_ACTIONS := {
	&"dim_x_plus": [&"x", 1], &"dim_x_minus": [&"x", -1],
	&"dim_y_plus": [&"y", 1], &"dim_y_minus": [&"y", -1],
	&"dim_z_plus": [&"z", 1], &"dim_z_minus": [&"z", -1],
}

# === automation
@export var automation := false
@onready var orbit: AutoOrbit = $AutoOrbit
@onready var player: CharacterBody3D = $CharacterBody3D

const MOVE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"move_forward", &"move_back"]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	orbit.rotation_completed.connect(_advance_line)
	stars_node.stars_rebuilt.connect(orbit.fit)
	orbit.fit(stars_node.last_box, stars_node.last_cone)  # Spheres' _ready already ran
	set_automation(automation)
	_setup_dim_map()
	stars_node.create_stars_from_data([1,2,3,4,5,6,7,8], [], true, true)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		get_tree().quit()
		return
	if event.is_action_pressed("toggle_automation"):
		set_automation(not automation)
		return
	if automation and _is_user_input(event):
		set_automation(false)
		return
	
	if event.is_action_pressed("next_line"):
		_advance_line()
		return

	# --- dimension switching ---
	if event.is_action_pressed("next_dims"):
		dim_map.advance_window()
		return
	if event.is_action_pressed("prev_dims"):
		dim_map.advance_window(-1)
		return
	for action: StringName in AXIS_ACTIONS:
		if event.is_action_pressed(action):
			var spec: Array = AXIS_ACTIONS[action]
			dim_map.advance_axis(spec[0], spec[1])
			return

	# Debug overlays: input action names match the debug registry keys,
	# so dispatch via InputMap directly.
	if event is InputEventKey and event.pressed and not event.is_echo():
		for action in InputMap.get_actions():
			if event.is_action_pressed(action) and stars_node.has_debug(action):
				stars_node.toggle_debug(action)


func set_automation(on: bool) -> void:
	automation = on
	orbit.active = on
	player.manual = not on

func _advance_line() -> void:
	cur_line = wrapi(cur_line + 1, 0, stars_node.line_count())
	_rebuild() # triggers stars_rebuilt -> orbit.fit

func _is_user_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		return event.relative.length() > 3.0  # ignore jitter
	for a in MOVE_ACTIONS:
		if event.is_action_pressed(a):
			return true
	return false

@export var show_line_stars := false
@export var show_verse_stars := false
@export var show_poem_stars := false


func _rebuild() -> void:
	print(show_poem_stars, show_line_stars, show_verse_stars)
	stars_node.create_stars_from_data([cur_line], [], show_poem_stars, show_line_stars, show_verse_stars)


# ======================= dimension switching

func _setup_dim_map() -> void:
	# Spheres' _ready ran first, so its dim_count (from data metadata) is set.
	dim_map = DimMap.new(stars_node.dim_count, enforce_distinct)
	dim_map.changed.connect(_on_dims_changed)
	stars_node.dim_axes = dim_map.axes_vector()
	_make_dims_hud()

func _on_dims_changed() -> void:
	stars_node.dim_axes = dim_map.axes_vector()
	_update_dims_hud()
	_rebuild()  # triggers stars_rebuilt -> orbit.fit

func _make_dims_hud() -> void:
	# built in code: always-visible mapping readout, independent of the
	# toggleable controls label
	dims_hud = Label.new()
	dims_hud.name = "DimsHud"
	dims_hud.position = Vector2(12, 12)
	dims_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var settings := LabelSettings.new()
	settings.font_color = Color(1, 1, 1, 0.7)
	dims_hud.label_settings = settings
	canvas.add_child(dims_hud)
	_update_dims_hud()

func _update_dims_hud() -> void:
	var v := dim_map.axes_vector()
	dims_hud.text = "dims  X:%d  Y:%d  Z:%d  (of %d)" % [v.x, v.y, v.z, dim_map.dim_count]
