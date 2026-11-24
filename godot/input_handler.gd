class_name InputHandler
extends Node

## Translates raw input events into semantic signals.
##
## Knows nothing about Spheres, DimMap or AutoOrbit -- main.gd connects the
## signals to its scene. `exit` quits directly: it needs nothing from the scene.
##
## Dispatch order mirrors the original main.gd _unhandled_input:
## exit -> toggle_automation -> user input -> next_line -> dim windows ->
## dim axes -> debug overlays.

signal next_line_requested
signal dims_window_requested(dir: int)
signal dim_axis_requested(axis: StringName, dir: int)
signal automation_toggled
signal user_input_detected
signal debug_toggled(key: StringName)

## input action -> [axis, direction]
const AXIS_ACTIONS := {
	&"dim_x_plus": [&"x", 1], &"dim_x_minus": [&"x", -1],
	&"dim_y_plus": [&"y", 1], &"dim_y_minus": [&"y", -1],
	&"dim_z_plus": [&"z", 1], &"dim_z_minus": [&"z", -1],
}

## Movement keys count as user input (automation takeover).
const MOVE_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"move_forward", &"move_back",
]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		get_tree().quit()
		return
	if event.is_action_pressed("toggle_automation"):
		automation_toggled.emit()
		return
	if _is_user_input(event):
		user_input_detected.emit()

	if event.is_action_pressed("next_line"):
		next_line_requested.emit()
		return

	# --- dimension switching ---
	if event.is_action_pressed("next_dims"):
		dims_window_requested.emit(1)
		return
	if event.is_action_pressed("prev_dims"):
		dims_window_requested.emit(-1)
		return
	for action: StringName in AXIS_ACTIONS:
		if event.is_action_pressed(action):
			var spec: Array = AXIS_ACTIONS[action]
			dim_axis_requested.emit(spec[0], spec[1])
			return

	# Debug overlays: input action names match the debug registry keys,
	# so dispatch via InputMap directly. Receiving side filters via
	# has_debug().
	if event is InputEventKey and event.pressed and not event.is_echo():
		for action in InputMap.get_actions():
			if event.is_action_pressed(action):
				debug_toggled.emit(action)


func _is_user_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		return event.relative.length() > 3.0 # ignore jitter
	for a in MOVE_ACTIONS:
		if event.is_action_pressed(a):
			return true
	return false
