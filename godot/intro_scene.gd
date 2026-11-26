class_name IntroScene
extends Node

## Base contract for intro child scenes. Children build and play only
## their own content under themselves, may move the injected camera, and
## finish exactly once via the guarded _finish(). The base owns the
## playback tween: children assign _tween = create_tween() in start(),
## and skip() kills it (if running) before finishing — children do not
## override skip().

signal finished

var camera: Camera3D = null  # set by the mother BEFORE start()
var _done := false
var _tween: Tween = null

func start() -> void:
	pass  # child overrides: build + play, then call _finish()

func skip() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
