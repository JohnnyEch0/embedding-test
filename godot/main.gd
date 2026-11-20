extends Node3D
@onready var stars_node = $"Spheres"


const DEBUG_ACTIONS := {
	&"debug_words_view": &"labels",
	&"debug_word_connection_lines": &"word_connections",
	&"debug_origin_lines": &"word_to_origin",
	&"debug_sentence_bounds_box": &"sentence_bounds_box",
	&"debug_cone": &"sentence_cone",
} #action names to debug panelnames
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
	
	for action in DEBUG_ACTIONS:
		if event.is_action_pressed(action):
			#print("Event is action pressed %s  --> %s" % [action, DEBUG_ACTIONS[action]]  )
			stars_node.toggle_debug(DEBUG_ACTIONS[action])
	if event.is_action_pressed("next_line"):
		cur_line = wrapi(cur_line + 1, 0, stars_node.line_count())
		stars_node.create_stars_from_data([cur_line])
	pass


func set_automation(on: bool) -> void:
	automation = on
	orbit.active = on
	player.manual = not on

func _advance_line() -> void:
	cur_line = wrapi(cur_line + 1, 0, stars_node.line_count())
	stars_node.create_stars_from_data([cur_line])  # triggers stars_rebuilt -> orbit.fit

func _is_user_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		return event.relative.length() > 3.0  # ignore jitter
	for a in MOVE_ACTIONS:
		if event.is_action_pressed(a):
			return true
	return false
