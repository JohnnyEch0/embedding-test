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
##
## User input terminates dispatch: a takeover event never also advances a
## line or toggles a debug overlay. (The original returned only under
## automation; with the current keymap no move key is double-mapped, so the
## observable behavior is identical.)

signal next_line_requested
signal dims_window_requested(dir: int)
signal dim_axis_requested(axis: StringName, dir: int)
signal automation_toggled
signal user_input_detected
signal debug_toggled(key: StringName)

## Movement keys count as user input (automation takeover).
const MOVE_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"move_forward", &"move_back",
]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		get_tree().quit()
		return
	# toggle_automation has no InputMap action yet; has_action guard keeps
	# the engine from logging an error on every event
	if InputMap.has_action(&"toggle_automation") \
			and event.is_action_pressed("toggle_automation"):
		automation_toggled.emit()
		return
	if _is_user_input(event):
		user_input_detected.emit()
		return

	if event.is_action_pressed("next_line"):
		next_line_requested.emit()
		return

	# --- dimension switching: windows. exact_match: without it, Shift+R
	# loosely matches next_dims (checked first) and prev_dims is unreachable
	# (pre-existing bug in main.gd's dispatch order) ---
	if event.is_action_pressed("next_dims", false, true):
		dims_window_requested.emit(1)
		return
	if event.is_action_pressed("prev_dims", false, true):
		dims_window_requested.emit(-1)
		return

	# --- dimension switching: single axes, typed literals (no positional
	# [axis, dir] pairs); exact_match for the same shift reason ---
	if event.is_action_pressed(&"dim_x_plus", false, true):
		dim_axis_requested.emit(&"x", 1)
		return
	if event.is_action_pressed(&"dim_x_minus", false, true):
		dim_axis_requested.emit(&"x", -1)
		return
	if event.is_action_pressed(&"dim_y_plus", false, true):
		dim_axis_requested.emit(&"y", 1)
		return
	if event.is_action_pressed(&"dim_y_minus", false, true):
		dim_axis_requested.emit(&"y", -1)
		return
	if event.is_action_pressed(&"dim_z_plus", false, true):
		dim_axis_requested.emit(&"z", 1)
		return
	if event.is_action_pressed(&"dim_z_minus", false, true):
		dim_axis_requested.emit(&"z", -1)
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
