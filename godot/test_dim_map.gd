extends SceneTree

## Headless unit test for DimMap (res://dim_map.gd).
##
## Run from the godot/ project directory:
##     godot --headless -s test_dim_map.gd
##
## Exit code 0 = all checks pass, 1 = at least one failure.
## One "FAIL:" line is printed per failed check; a summary line always prints.

const DimMapScript := preload("res://dim_map.gd")

var _checks := 0
var _failures := 0


func _init() -> void:
	_test_defaults()
	_test_window_advance()
	_test_axis_advance_distinct()
	_test_axis_advance_duplicates_allowed()
	_test_degenerate_dim_counts()
	_test_unknown_axis_is_noop()
	_test_identity_wraps()
	_test_changed_signal()
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

## Fresh DimMap with the given x/y/z starting dims (defaults 0/1/2).
func _make(dim_count: int, enforce_distinct := true,
		x := 0, y := 1, z := 2) -> RefCounted:
	var m = DimMapScript.new(dim_count, enforce_distinct)
	m._dims = {&"x": x, &"y": y, &"z": z}
	return m


func _expect(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: " + msg)


func _xyz(m) -> Array:
	return [m.get_dim(&"x"), m.get_dim(&"y"), m.get_dim(&"z")]


# ---------------------------------------------------------------------------
# tests
# ---------------------------------------------------------------------------

func _test_defaults() -> void:
	var m := _make(32)
	_expect(m.dim_count == 32, "dim_count stored")
	_expect(_xyz(m) == [0, 1, 2], "default mapping is 0/1/2")
	_expect(m.axes_vector() == Vector3i(0, 1, 2), "axes_vector packs mapping")


func _test_window_advance() -> void:
	var m := _make(32)
	m.advance_window()
	_expect(_xyz(m) == [3, 4, 5], "window advance shifts all axes by +3")

	var m2 := _make(32, true, 30, 31, 0)
	m2.advance_window()
	_expect(_xyz(m2) == [1, 2, 3], "window wraps each axis mod dim_count (30,31,0 -> 1,2,3)")

	var m3 := _make(32)
	m3.advance_window(-1)
	_expect(_xyz(m3) == [29, 30, 31], "reverse window advance shifts by -3")

	var m4 := _make(4)
	m4.advance_window()
	_expect(_xyz(m4) == [3, 0, 1], "d=4 window stays distinct across wrap")

	# window advance is a translation: distinctness is preserved, never created
	var m5 := _make(32, false, 5, 5, 9)
	m5.advance_window()
	_expect(_xyz(m5) == [8, 8, 12], "window preserves duplicates (pure translation)")


func _test_axis_advance_distinct() -> void:
	var m := _make(32)
	m.advance_axis(&"x")
	_expect(_xyz(m) == [3, 1, 2], "axis advance skips dims held by other axes (0 -> 3, not 1/2)")

	var m2 := _make(32, true, 31, 1, 2)
	m2.advance_axis(&"x")
	_expect(_xyz(m2) == [0, 1, 2], "axis advance wraps to first free dim (31 -> 0)")

	var m3 := _make(32, true, 0, 1, 2)
	m3.advance_axis(&"y", -1)
	_expect(_xyz(m3) == [0, 31, 2], "reverse axis advance skips downwards (1 -> 31)")

	# distinctness is maintained once established, whenever dim_count >= 4
	var m4 := _make(32)
	for i in 200:
		for axis in [&"x", &"y", &"z"]:
			m4.advance_axis(axis)
			var v := _xyz(m4)
			_expect(v.size() == 3 and v[0] != v[1] and v[0] != v[2] and v[1] != v[2],
				"fuzz %d: mapping stays distinct, got %s" % [i, str(v)])


func _test_axis_advance_duplicates_allowed() -> void:
	var m := _make(32, false)
	m.advance_axis(&"x")
	_expect(_xyz(m) == [1, 1, 2], "enforce_distinct=false: plain step, duplicates allowed")


func _test_degenerate_dim_counts() -> void:
	# d=3 with distinct mapping: every dim is taken, so the advance degrades
	# to a plain step and accepts a duplicate rather than deadlocking.
	var m := _make(3)
	m.advance_axis(&"x")
	_expect(_xyz(m) == [1, 1, 2], "d=3 distinct: degrades to duplicate instead of deadlock")

	# d<=1: constructor clamps, all axes collapse onto dim 0.
	var m2 = DimMapScript.new(0)
	_expect(m2.dim_count == 1, "dim_count clamped to >= 1")
	_expect(_xyz(m2) == [0, 0, 0], "d=1: mapping collapses to all-zero")

	var m3 = DimMapScript.new(2)
	_expect(m3.dim_count == 2, "d=2: dim_count kept")
	_expect(_xyz(m3) == [0, 1, 1], "d=2: z collapses onto y")


func _test_identity_wraps() -> void:
	# a full-cycle window wrap maps onto itself: no state change, no signal,
	# no pointless rebuild + orbit refit downstream
	var m := _make(3)
	var count := [0]
	m.changed.connect(func() -> void: count[0] += 1)
	m.advance_window()
	m.advance_window(-1)
	_expect(_xyz(m) == [0, 1, 2], "d=3: window wrap is the identity mapping")
	_expect(count[0] == 0, "identity window wrap emits nothing")

	var m1 = DimMapScript.new(1)
	var count1 := [0]
	m1.changed.connect(func() -> void: count1[0] += 1)
	m1.advance_axis(&"x")
	m1.advance_window()
	_expect(count1[0] == 0, "d=1: every advance is the identity, emits nothing")


func _test_unknown_axis_is_noop() -> void:
	var m := _make(32)
	m.advance_axis(&"q")  # pushes a warning; must not crash or change state
	_expect(_xyz(m) == [0, 1, 2], "unknown axis: no state change")
	# get_dim mirrors advance_axis's policy: warn once, degrade to 0
	_expect(m.get_dim(&"q") == 0, "unknown axis get_dim returns 0 (warns once)")
	_expect(m.get_dim(&"x") == 0, "known axis unaffected")


func _test_changed_signal() -> void:
	var m := _make(32)
	var count := [0]
	m.changed.connect(func() -> void: count[0] += 1)
	m.get_dim(&"x")
	m.axes_vector()
	_expect(count[0] == 0, "reads do not emit changed")
	m.advance_window()
	m.advance_axis(&"x")
	_expect(count[0] == 2, "each advance emits changed exactly once")
