extends Node3D
@onready var stars_node = $"Spheres"
@onready var canvas := $"CanvasLayer"


var cur_line := [0]
# === configuration
# @export var normal_look: ViewSetting   # will be added later


# === dimension switching (state + semantics in dim_map.gd)
@export var enforce_distinct := true
var dim_map: DimMap
var dims_hud: Label

# === automation
@export var automation := false
@export var show_line_stars := false
@export var show_verse_stars := false
@export var show_poem_stars := false
@onready var orbit: AutoOrbit = $AutoOrbit
@onready var player: CharacterBody3D = $CharacterBody3D
@onready var input_handler: InputHandler = $InputHandler

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	orbit.rotation_completed.connect(_advance_line)
	stars_node.stars_rebuilt.connect(orbit.fit)
	orbit.fit(stars_node.last_box, stars_node.last_cone) # Spheres' _ready already ran
	set_automation(automation)
	_rebuild()
	_setup_dim_map()
	_setup_input()


func _setup_input() -> void:
	# after _setup_dim_map: dim_map exists, so its methods can be connected directly
	input_handler.next_line_requested.connect(_advance_line)
	input_handler.dims_window_requested.connect(dim_map.advance_window)
	input_handler.dim_axis_requested.connect(dim_map.advance_axis)
	input_handler.automation_toggled.connect(_toggle_automation)
	input_handler.user_input_detected.connect(_on_user_input)
	input_handler.debug_toggled.connect(_on_debug_toggled)


func _toggle_automation() -> void:
	set_automation(not automation)


func _on_user_input() -> void:
	if automation:
		set_automation(false) # manual takeover


func _on_debug_toggled(key: StringName) -> void:
	if stars_node.has_debug(key):
		stars_node.toggle_debug(key)


func set_automation(on: bool) -> void:
	automation = on
	orbit.active = on
	player.manual = not on

func _advance_line() -> void:
	cur_line = [wrapi(cur_line[0] + 1, 0, stars_node.line_count())]
	_rebuild() # triggers stars_rebuilt -> orbit.fit

func _rebuild() -> void:
	# print(show_poem_stars, show_line_stars, show_verse_stars)
	stars_node.create_stars_from_data(cur_line, [], show_poem_stars, show_line_stars, show_verse_stars)


# ======================= dimension switching

func _setup_dim_map() -> void:
	# Spheres' _ready ran first, so its dim_count (from data metadata) is set.
	# Wiring invariant, not data validation: a failed Spheres data load
	# leaves dim_count at its default 3 and every dim mapping would lie.
	assert(stars_node.dim_count > 3,
		"dim handshake failed: Spheres data not loaded (dim_count=%d)" % stars_node.dim_count)
	dim_map = DimMap.new(stars_node.dim_count, enforce_distinct)
	dim_map.changed.connect(_on_dims_changed)
	stars_node.dim_axes = dim_map.axes_vector()
	_make_dims_hud()

func _on_dims_changed() -> void:
	stars_node.dim_axes = dim_map.axes_vector()
	_update_dims_hud()
	_rebuild() # triggers stars_rebuilt -> orbit.fit

func _make_dims_hud() -> void:
	# built in code: always-visible mapping readout, independent of the
	# toggleable controls label
	dims_hud = Label.new()
	dims_hud.name = "DimsHud"
	dims_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	dims_hud.offset_left = 12.0
	dims_hud.offset_top = 12.0
	dims_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var settings := LabelSettings.new()
	settings.font_color = Color(1, 1, 1, 0.7)
	dims_hud.label_settings = settings
	canvas.add_child(dims_hud)
	_update_dims_hud()

func _update_dims_hud() -> void:
	var v := dim_map.axes_vector()
	dims_hud.text = "dims  X:%d  Y:%d  Z:%d  (of %d)" % [v.x, v.y, v.z, dim_map.dim_count]
