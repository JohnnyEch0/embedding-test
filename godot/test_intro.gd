extends SceneTree

## Headless unit test for the intro mother scene (res://intro.gd) and the
## IntroScene base contract (res://intro_scene.gd).
##
## Run from the godot/ project directory:
##     godot --headless -s test_intro.gd
##
## Exit code 0 = all checks pass, 1 = at least one failure.
## Fake IntroScene children are built and PackedScene-packed in code; Run C
## also replays the real Title/Stars/Camera scenes (timing shortened) under
## the mother. Frame-driven (process_frame): the mother defers scene switching.

const IntroTscn := preload("res://intro.tscn")
const StarsTscn := preload("res://intro/stars_scene.tscn")
const TitleTscn := preload("res://intro/title_scene.tscn")
const CameraTscn := preload("res://intro/camera_scene.tscn")

enum State { A_WAIT_SLOW, A_SKIP_CHECK, A_WAIT_MAIN, B_WAIT_SLOW, B_WAIT_FAIL, B_RETRY, C_WATCH, C_SKIP, DONE }

var _checks := 0
var _failures := 0
var _state: State = State.A_WAIT_SLOW
var _frame := 0
var _state_frame := 0
var _mother: Intro = null
var _c_seen: Array[String] = []
var _c_main_before: Node = null


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
	_test_star_lines()
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
			elif _state_frame > 3600:
				_check(false, "intro reached main.tscn after last scene (timeout)")
				_state = State.DONE
		State.B_WAIT_SLOW:
			if _current_name() == "SlowE":
				_check(_mother.scene_slot.get_child_count() == 1, "double finished ignored: exactly one advance")
				_mother._unhandled_input(_event(&"skip_step"))  # queues deferred _play(2)
				_mother._unhandled_input(_event(&"skip_all"))  # same frame: finish + fade
				_state = State.B_WAIT_FAIL
				_state_frame = 0
			elif _state_frame > 120:
				_check(false, "double finished ignored (timeout)")
				_state = State.DONE
		State.B_WAIT_FAIL:
			if _state_frame > 400:
				_check(is_instance_valid(_mother) and _mother.is_inside_tree(), "failed scene change leaves intro alive")
				_check(current_scene != null and current_scene.name == "main", "failed scene change keeps current scene")
				_check(_current_name() == "SlowE", "failed scene change leaves intro content visible")
				_check(_mother.scene_slot.get_child_count() == 1, "queued play blocked after skip_all: no child under the fade")
				_check(_mother.fade_rect.self_modulate.a == 0.0, "failed scene change resets fade to transparent")
				_check(_mother._finished == false, "failed scene change re-arms the intro")
				_mother._unhandled_input(_event(&"skip_all"))  # Esc retry
				_state = State.B_RETRY
				_state_frame = 0
		State.B_RETRY:
			if _state_frame > 40:
				_check(_mother.fade_rect.self_modulate.a > 0.0, "Esc retry re-runs the fade")
				_mother.free()
				_mother = null
				_setup_run_c()
				_state = State.C_WATCH
				_state_frame = 0
		State.C_WATCH:
			_track_child()
			if not is_instance_valid(_c_main_before):
				_check(_c_seen == ["TitleScene", "StarsScene", "CameraScene"], "smoke: real scenes play in order under the mother")
				_check(current_scene != null and current_scene.name == "main", "smoke: real-scene run reaches main.tscn")
				_mother.free()
				_mother = null
				_setup_run_c()
				_state = State.C_SKIP
				_state_frame = 0
			elif _state_frame > 1500:
				_check(false, "smoke: real-scene run reaches main.tscn (timeout)")
				_state = State.DONE
		State.C_SKIP:
			if _track_child():
				_mother._unhandled_input(_event(&"skip_step"))  # skip each new child once
			if not is_instance_valid(_c_main_before):
				_check(_c_seen == ["TitleScene", "StarsScene", "CameraScene"], "smoke: skip advances each real scene")
				_check(current_scene != null and current_scene.name == "main", "smoke: skipped real-scene run reaches main.tscn")
				_state = State.DONE
			elif _state_frame > 1500:
				_check(false, "smoke: skipped real-scene run reaches main.tscn (timeout)")
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
		_pack(_fake(FakeSlow, "SlowF")),
	]
	root.add_child(_mother)


func _test_star_lines() -> void:
	var stars: StarsScene = StarsTscn.instantiate()
	root.add_child(stars)
	stars.start()
	# stars reuse EmbStar with readable, initially hidden labels
	var count: int = mini(stars.positions.size(), stars.words.size())
	_check(stars._stars.size() == count, "stars: one EmbStar per word")
	for i in stars._stars.size():
		var star: EmbStar = stars._stars[i]
		var label: Label3D = star.get_node("Label3D")
		_check(label.text == stars.words[i],
			"stars: EmbStar label is the word (%d)" % i)
		_check(label.visibility_range_end > 120.0,
			"stars: label visible at intro distance (%d)" % i)
		_check(is_equal_approx(label.modulate.a, 0.0),
			"stars: label starts transparent for the fade-in (%d)" % i)
	var expected: int = 2 * (count - 1)
	var lines := stars.get_node_or_null("Lines") as MeshInstance3D
	var got := -1
	if lines != null and lines.mesh is ArrayMesh:
		got = (lines.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	_check(got == expected, "stars: line mesh joins stars in order (%d verts, want %d)" % [got, expected])
	stars.skip()
	stars.free()


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

func _setup_run_c() -> void:
	_mother = IntroTscn.instantiate() as Intro
	_mother.name = "MotherC"
	_mother.scenes = [
		_pack_real(TitleTscn, {
			"title_in": 0.05, "title_hold": 0.05, "title_out": 0.05, "gap": 0.05,
			"sub_in": 0.05, "sub_hold": 0.05, "sub_out": 0.05,
		}),
		_pack_real(StarsTscn, {"star_in": 0.05, "appear_gap": 0.05, "hold": 0.05}),
		_pack_real(CameraTscn, {"duration": 0.3}),
	]
	_c_seen = []
	_c_main_before = current_scene
	root.add_child(_mother)


func _pack_real(scene: PackedScene, props: Dictionary) -> PackedScene:
	var inst := scene.instantiate()
	for key in props:
		inst.set(key, props[key])
	return _pack(inst)


func _track_child() -> bool:
	var n := _current_name()
	if n != "" and (_c_seen.is_empty() or _c_seen[_c_seen.size() - 1] != n):
		_c_seen.append(n)
		return true
	return false


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
