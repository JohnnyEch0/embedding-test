class_name Intro
extends Node3D

@export var scenes: Array[PackedScene] = []
@export var main_scene_path := "res://main.tscn"

@onready var camera: Camera3D = $Camera3D
@onready var scene_slot: Node = $SceneSlot

var index := -1
var _finished := false


func _ready() -> void:
	if scenes.is_empty():
		push_error("Intro: no scenes configured, going to main scene.")
		_go_to_main()
		return
	_play(0)


func _play(i: int) -> void:
	index = i
	for child in scene_slot.get_children():
		child.free()
	camera.position = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	if scenes[i] == null:
		push_error("Intro: scenes[%d] is null, skipping it." % i)
		_next()
		return
	var inst := scenes[i].instantiate()
	if inst == null:
		push_error("Intro: scenes[%d] failed to instantiate, skipping it." % i)
		_next()
		return
	if not inst is IntroScene:
		push_error("Intro: scenes[%d] is not an IntroScene, skipping it." % i)
		inst.free()
		_next()
		return
	var child := inst as IntroScene
	child.camera = camera
	child.finished.connect(_next, CONNECT_ONE_SHOT)
	scene_slot.add_child(child)
	child.start()


func _next() -> void:
	if _finished:
		return
	index += 1
	if index >= scenes.size():
		_finish()
		return
	# Deferred: the old child may still be on the call stack (its own
	# finished emission), and freeing it there is a locked-object error.
	call_deferred("_play", index)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_echo():
		return
	if event.is_action_pressed(&"skip_step"):
		var child := _current_child()
		if child != null:
			child.skip()
	elif event.is_action_pressed(&"skip_all"):
		_finish()
	elif event.is_action_pressed(&"exit"):
		get_tree().quit()


func _current_child() -> IntroScene:
	var children := scene_slot.get_children()
	if children.is_empty():
		return null
	return children[children.size() - 1] as IntroScene


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_go_to_main()


func _go_to_main() -> void:
	await get_tree().process_frame
	var err := get_tree().change_scene_to_file(main_scene_path)
	if err != OK:
		push_error("Intro: change_scene_to_file(%s) failed with error %d, staying on intro." % [main_scene_path, err])
