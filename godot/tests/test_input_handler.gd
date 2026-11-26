extends SceneTree

## Headless unit test for InputHandler (res://dims/input_handler.gd).
##
## Run from the godot/ project directory:
##     godot --headless -s test_input_handler.gd
##
## Exit code 0 = all checks pass, 1 = at least one failure.
## Drives _unhandled_input with synthetic InputEvents (project.godot's
## InputMap is loaded) and asserts exactly which signals fire per event.
##
## Not covered headless: `exit` (quit would end the runner) and
## `toggle_automation` (no such action in the InputMap -- dead branch).
## Both need manual/editor coverage.

const InputHandlerScript := preload("res://dims/input_handler.gd")

var _checks := 0
var _failures := 0
var _fired := {} # StringName(signal) -> Array of arg-arrays


func _init() -> void:
	_test_next_line()
	_test_dim_windows()
	_test_dim_axes()
	_test_user_input_move_key()
	_test_user_input_mouse()
	_test_debug_keys()
	_test_echo_and_unbound_keys()
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

## Handler with all signals recorded. Fresh _fired per handler.
func _make_handler() -> Node:
	_fired = {}
	var h := InputHandlerScript.new()
	h.next_line_requested.connect(func() -> void: _record(&"next_line_requested", []))
	h.dims_window_requested.connect(func(dir: int) -> void: _record(&"dims_window_requested", [dir]))
	h.dim_axis_requested.connect(
		func(axis: StringName, dir: int) -> void: _record(&"dim_axis_requested", [axis, dir]))
	h.automation_toggled.connect(func() -> void: _record(&"automation_toggled", []))
	h.user_input_detected.connect(func() -> void: _record(&"user_input_detected", []))
	h.debug_toggled.connect(func(key: StringName) -> void: _record(&"debug_toggled", [key]))
	return h


func _record(sig: StringName, args: Array) -> void:
	_fired.get_or_add(sig, []).append(args)


## Pressed key event matching project.godot's physical-key bindings.
func _key(code: Key, shift := false, ctrl := false, echo := false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
	ev.shift_pressed = shift
	ev.ctrl_pressed = ctrl
	ev.echo = echo
	return ev


func _motion(rel: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.relative = rel
	return ev


func _expect(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: " + msg)


## Feed one event; assert exactly one signal with exactly one emission
## carrying exactly these args. Pins both dispatch and fallthrough.
func _expect_fire(ev: InputEvent, sig: StringName, args: Array, label: String) -> void:
	var h := _make_handler()
	h._unhandled_input(ev)
	h.free()
	_expect(_fired == {sig: [args]}, label + ", got " + str(_fired))


## Feed one event; assert no signal at all.
func _expect_silent(ev: InputEvent, label: String) -> void:
	var h := _make_handler()
	h._unhandled_input(ev)
	h.free()
	_expect(_fired.is_empty(), label + ", got " + str(_fired))


# ---------------------------------------------------------------------------
# tests
# ---------------------------------------------------------------------------

func _test_next_line() -> void:
	_expect_fire(_key(KEY_E), &"next_line_requested", [], "E fires next_line_requested only")


func _test_dim_windows() -> void:
	_expect_fire(_key(KEY_R), &"dims_window_requested", [1], "R fires dims_window_requested(1)")
	_expect_fire(_key(KEY_R, true), &"dims_window_requested", [-1], "Shift+R fires dims_window_requested(-1)")


func _test_dim_axes() -> void:
	# exact-dict compare also pins the dim branch beating the debug scan
	# (F/G/H are InputMap actions; without the return they would leak
	# debug_toggled emissions too)
	_expect_fire(_key(KEY_F), &"dim_axis_requested", [&"x", 1], "F fires dim_axis_requested(x, 1)")
	_expect_fire(_key(KEY_F, true), &"dim_axis_requested", [&"x", -1], "Shift+F fires dim_axis_requested(x, -1)")
	_expect_fire(_key(KEY_G), &"dim_axis_requested", [&"y", 1], "G fires dim_axis_requested(y, 1)")
	_expect_fire(_key(KEY_G, true), &"dim_axis_requested", [&"y", -1], "Shift+G fires dim_axis_requested(y, -1)")
	_expect_fire(_key(KEY_H), &"dim_axis_requested", [&"z", 1], "H fires dim_axis_requested(z, 1)")
	_expect_fire(_key(KEY_H, true), &"dim_axis_requested", [&"z", -1], "Shift+H fires dim_axis_requested(z, -1)")


func _test_user_input_move_key() -> void:
	# W is move_forward: user input only -- pins user input beating both
	# next_line and the debug scan (move_forward is an InputMap action)
	_expect_fire(_key(KEY_W), &"user_input_detected", [], "W fires user_input_detected only")
	_expect_fire(_key(KEY_A), &"user_input_detected", [], "A fires user_input_detected only")
	_expect_fire(_key(KEY_SPACE), &"user_input_detected", [], "Space fires user_input_detected only")


func _test_user_input_mouse() -> void:
	# jitter threshold: > 3.0 counts, exactly 3.0 does not
	_expect_silent(_motion(Vector2(1, 0)), "tiny mouse motion is jitter, ignored")
	_expect_silent(_motion(Vector2(3, 0)), "exactly 3.0 is not user input")
	_expect_fire(_motion(Vector2(4, 0)), &"user_input_detected", [], "4.0 mouse motion is user input")
	_expect_fire(_motion(Vector2(2, 3)), &"user_input_detected", [], "length 3.6 mouse motion is user input")


func _test_debug_keys() -> void:
	_expect_fire(_key(KEY_1, false, true), &"debug_toggled", [&"word_connections"],
		"Ctrl+1 fires debug_toggled(word_connections)")
	_expect_fire(_key(KEY_2, false, true), &"debug_toggled", [&"word_to_origin"],
		"Ctrl+2 fires debug_toggled(word_to_origin)")
	_expect_fire(_key(KEY_5, false, true), &"debug_toggled", [&"labels"],
		"Ctrl+5 fires debug_toggled(labels)")


func _test_echo_and_unbound_keys() -> void:
	# echoed key presses must not re-toggle debug overlays
	_expect_silent(_key(KEY_1, false, true, true), "echoed Ctrl+1 is ignored")
	_expect_silent(_key(KEY_T), "unbound key fires nothing")
