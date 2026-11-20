extends Node3D
@onready var stars_node = $"Spheres"


const DEBUG_ACTIONS := {
	&"debug_word_connection_lines": &"word_connections",
	&"debug_origin_lines": &"word_to_origin",
	&"debug_sentence_bounds_box": &"sentence_bounds_box",
	&"debug_cone": &"sentence_cone",
} #action names to debug panelnames

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#stars_node = $"Spheres"
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		get_tree().quit()
	if event.is_action_pressed("debug_view"):
		
		for star:EmbStar in stars_node.stars:
			star.label.visibility_range_end = 5000000
	if event.is_action_released("debug_view"):
		for star:EmbStar in stars_node.stars:
			star.label.visibility_range_end = 5
	for action in DEBUG_ACTIONS:
		if event.is_action_pressed(action):
			#print("Event is action pressed %s  --> %s" % [action, DEBUG_ACTIONS[action]]  )
			stars_node.toggle_debug(DEBUG_ACTIONS[action])
	pass
