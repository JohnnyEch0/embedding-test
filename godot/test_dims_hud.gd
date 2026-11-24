extends SceneTree

## Headless unit test for DimsHud (res://dims_hud.gd).
##
## Run from the godot/ project directory:
##     godot --headless -s test_dims_hud.gd
##
## Exit code 0 = all checks pass, 1 = at least one failure.
## A Label works headless (no rendering, just state), so the full
## bind -> advance -> refresh path is covered.

const DimMapScript := preload("res://dim_map.gd")
const DimsHudScript := preload("res://dims_hud.gd")

var _checks := 0
var _failures := 0


func _init() -> void:
	_test_bind_renders_current_mapping()
	_test_refresh_on_changed()
	_test_identity_wrap_no_refresh()
	_test_advance_axis_renders()
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


func _hud(dim_count: int) -> Label:
	var hud := DimsHudScript.new()
	hud.bind(DimMapScript.new(dim_count))
	return hud


# ---------------------------------------------------------------------------
# tests
# ---------------------------------------------------------------------------

func _test_bind_renders_current_mapping() -> void:
	var hud := _hud(32)
	_expect(hud.text == "dims  X:0  Y:1  Z:2  (of 32)",
		"bind renders the default mapping, got '%s'" % hud.text)
	hud.free()


func _test_refresh_on_changed() -> void:
	var hud := _hud(32)
	hud.dim_map.advance_window()
	_expect(hud.text == "dims  X:3  Y:4  Z:5  (of 32)",
		"window advance refreshes via changed, got '%s'" % hud.text)
	hud.dim_map.advance_window(-1)
	_expect(hud.text == "dims  X:0  Y:1  Z:2  (of 32)",
		"reverse window advance refreshes, got '%s'" % hud.text)
	hud.free()


func _test_identity_wrap_no_refresh() -> void:
	var hud := _hud(3)
	hud.dim_map.advance_window() # full cycle at d=3: identity, no signal
	_expect(hud.text == "dims  X:0  Y:1  Z:2  (of 3)",
		"identity wrap leaves text untouched, got '%s'" % hud.text)
	hud.free()


func _test_advance_axis_renders() -> void:
	var hud := _hud(32)
	hud.dim_map.advance_axis(&"y")
	_expect(hud.text == "dims  X:0  Y:3  Z:2  (of 32)",
		"axis advance refreshes (distinct skip 1->3), got '%s'" % hud.text)
	hud.free()
