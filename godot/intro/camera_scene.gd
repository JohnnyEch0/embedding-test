class_name CameraScene
extends IntroScene

@export var path: Array[Vector3] = [
	Vector3(0, 0, 120),
	Vector3(45, 25, 50),
	Vector3(-25, 5, -30),
]
@export var look_target := Vector3.ZERO
@export var duration := 8.0

const StarsTscn := preload("res://intro/stars_scene.tscn")

var _tween: Tween = null


func start() -> void:
	if path.size() < 2:
		push_error("CameraScene: path needs at least 2 points, finishing at once.")
		_finish()
		return
	if camera == null:
		push_error("CameraScene: no camera injected, finishing at once.")
		_finish()
		return
	var stars := StarsTscn.instantiate()
	add_child(stars)
	stars.start()
	_tween = create_tween()
	_tween.tween_method(_move, 0.0, 1.0, duration)
	_tween.tween_callback(_finish)


func skip() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_finish()


func _move(t: float) -> void:
	camera.position = _pos_at(t)
	camera.look_at(look_target)


func _pos_at(t: float) -> Vector3:
	var segs: int = path.size() - 1
	var f: float = clampf(t, 0.0, 1.0) * float(segs)
	var i: int = clampi(int(f), 0, segs - 1)
	return path[i].lerp(path[i + 1], f - float(i))
