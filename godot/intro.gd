class_name Intro
extends Node3D

@export var scenes: Array[PackedScene] = []
@export var main_scene_path := "res://main.tscn"

var index: int = -1

func _ready() -> void:
	if scenes.is_empty():
		push_error("Intro: no scenes configured, going to main scene.")
		_go_to_main()

func _go_to_main() -> void:
	await get_tree().process_frame
	var err := get_tree().change_scene_to_file(main_scene_path)
	if err != OK:
		push_error("Intro: change_scene_to_file(%s) failed with error %d, staying on intro." % [main_scene_path, err])
