extends Node3D
@onready var stars_node = $"Spheres"


var cur_line := 0

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
	stars_node.create_stars_from_data([1,2,3,4,5,6,7,8], [], true, true)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		get_tree().quit()
	if event.is_action_pressed("toggle_automation"):
		set_automation(not automation)
		return
	if automation and _is_user_input(event):
		set_automation(false)
		return
	
	if event.is_action_pressed("next_line"):
		_advance_line()

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
