extends SceneTree

## Headless unit test for the intro mother scene (res://intro.gd) and the
## IntroScene base contract (res://intro_scene.gd).
##
## Run from the godot/ project directory:
##     godot --headless -s test_intro.gd
##
## Exit code 0 = all checks pass, 1 = at least one failure.
## Fake IntroScene children are built and PackedScene-packed in code.
## Frame-driven (process_frame): the mother defers scene switching.

const IntroTscn := preload("res://intro.tscn")

enum State { A_WAIT_SLOW, A_SKIP_CHECK, A_WAIT_MAIN, B_WAIT_SLOW, B_WAIT_FAIL, DONE }

var _checks := 0
var _failures := 0
var _state: State = State.A_WAIT_SLOW
var _frame := 0
var _state_frame := 0
var _mother: Intro = null


class FakeInstant extends IntroScene:
	func start() -> void:
		if camera != null:
			camera.fov = 12.0
			camera.position = Vector3(9, 9, 9)
		_finish()


class FakeSlow extends IntroScene:
	pass


class FakeDouble extends IntroScene:
	func start() -> void:
		_finish()
		finished.emit.call_deferred()


func _initialize() -> void:
	_test_base_contract()
	_setup_run_a()
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1
	_state_frame += 1
	match _state:
		State.A_WAIT_SLOW:
			if _current_name() == "SlowB":
				_check(_mother.camera.fov == 12.0, "order: instant scene played first (fov set)")
				_check(_mother.camera.position == Vector3.ZERO, "camera pose reset between children")
				_mother._unhandled_input(_event(&"skip_step"))
				_state = State.A_SKIP_CHECK
				_state_frame = 0
			elif _state_frame > 120:
				_check(false, "order: instant scene finished, slow scene current (timeout)")
				_state = State.DONE
		State.A_SKIP_CHECK:
			if _mother.scene_slot.get_child_count() == 0:
				_check(true, "skip_step advances; bad scene skipped, not added")
				_state = State.A_WAIT_MAIN
				_state_frame = 0
			elif _state_frame > 120:
				_check(false, "skip_step advances; bad scene skipped (timeout)")
				_state = State.DONE
		State.A_WAIT_MAIN:
			if current_scene != null and current_scene.name == "main":
				_check(true, "intro reached main.tscn after last scene")
				_mother.free()
				_mother = null
				_setup_run_b()
				_state = State.B_WAIT_SLOW
				_state_frame = 0
			elif _state_frame > 1800:
				_check(false, "intro reached main.tscn after last scene (timeout)")
				_state = State.DONE
		State.B_WAIT_SLOW:
			if _current_name() == "SlowE":
				_check(_mother.scene_slot.get_child_count() == 1, "double finished ignored: exactly one advance")
				_mother._unhandled_input(_event(&"skip_all"))
				_mother._unhandled_input(_event(&"skip_step"))  # no-op path: must not crash
				_state = State.B_WAIT_FAIL
				_state_frame = 0
			elif _state_frame > 120:
				_check(false, "double finished ignored (timeout)")
				_state = State.DONE
		State.B_WAIT_FAIL:
			if _state_frame > 30:
				_check(is_instance_valid(_mother) and _mother.is_inside_tree(), "failed scene change leaves intro alive")
				_check(current_scene != null and current_scene.name == "main", "failed scene change keeps current scene")
				_check(_current_name() == "SlowE", "failed scene change leaves intro content visible")
				_state = State.DONE
		State.DONE:
			_finish_test()


func _setup_run_a() -> void:
	_mother = IntroTscn.instantiate() as Intro
	_mother.name = "MotherA"
	_mother.scenes = [
		_pack(_fake(FakeInstant, "InstantA")),
		_pack(_fake(FakeSlow, "SlowB")),
		_pack_bad(),
	]
	root.add_child(_mother)


func _setup_run_b() -> void:
	_mother = IntroTscn.instantiate() as Intro
	_mother.name = "MotherB"
	_mother.main_scene_path = "res://no_such_scene.tscn"
	_mother.scenes = [
		_pack(_fake(FakeDouble, "DoubleD")),
		_pack(_fake(FakeSlow, "SlowE")),
	]
	root.add_child(_mother)


func _test_base_contract() -> void:
	var fake := FakeSlow.new()
	var count := [0]
	fake.finished.connect(func() -> void: count[0] += 1)
	fake._finish()
	fake._finish()
	fake.skip()
	_check(count[0] == 1, "base class: finished emitted exactly once")
	fake.free()


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

func _fake(cls: GDScript, node_name: String) -> IntroScene:
	var n: IntroScene = cls.new()
	n.name = node_name
	return n


func _pack(node: Node) -> PackedScene:
	var ps := PackedScene.new()
	var err := ps.pack(node)
	if err != OK:
		_check(false, "pack of fake %s failed (err %d)" % [node.name, err])
	node.free()
	return ps


func _pack_bad() -> PackedScene:
	var bad := Node.new()
	bad.name = "NotAnIntroScene"
	return _pack(bad)


func _event(action: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func _current_name() -> String:
	if _mother == null:
		return ""
	var children := _mother.scene_slot.get_children()
	if children.is_empty():
		return ""
	return children[children.size() - 1].name


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: " + label)


func _finish_test() -> void:
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
