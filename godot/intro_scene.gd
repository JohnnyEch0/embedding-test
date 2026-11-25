class_name IntroScene
extends Node

signal finished

var camera: Camera3D = null  # set by the mother BEFORE start()
var _done := false

func start() -> void:
	pass  # child overrides: build + play, then call _finish()

func skip() -> void:
	_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
