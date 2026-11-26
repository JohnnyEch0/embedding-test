class_name CameraScene
extends IntroScene

## Intro scene: glides the mother's camera along an exported path while
## playing the stars scene underneath. By default the camera looks at
## the centroid of the star positions (auto-derived from the StarsScene,
## so the cluster geometry lives only in stars_scene.gd) — the glide
## path ends at z = -30 while the cluster sits at z = -60 .. -120, so a
## fixed origin look target made the final ~20% of the glide face away
## from the stars. An explicitly exported look_target overrides.

@export var path: Array[Vector3] = [
	Vector3(0, 0, 120),
	Vector3(45, 25, 50),
	Vector3(-25, 5, -30),
]
## Point the camera looks at. Default (all-NaN) = auto: the centroid of
## the StarsScene positions. Set a real Vector3 to look somewhere else.
@export var look_target := Vector3(NAN, NAN, NAN)
@export var duration := 8.0

const StarsTscn := preload("res://intro/stars_scene.tscn")

var _look := Vector3.ZERO


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
	_look = _resolve_look_target(stars)
	_tween = create_tween()
	_tween.tween_method(_move, 0.0, 1.0, duration)
	_tween.tween_callback(_finish)


func _move(t: float) -> void:
	camera.position = _pos_at(t)
	camera.look_at(_look)


func _pos_at(t: float) -> Vector3:
	var segs: int = path.size() - 1
	var f: float = clampf(t, 0.0, 1.0) * float(segs)
	var i: int = clampi(int(f), 0, segs - 1)
	return path[i].lerp(path[i + 1], f - float(i))


## Explicit look_target (any non-NaN x) wins; the default auto-derives
## the centroid of the StarsScene positions, so star geometry is not
## hardcoded in two places.
func _resolve_look_target(stars: StarsScene) -> Vector3:
	if not is_nan(look_target.x):
		return look_target
	var sum := Vector3.ZERO
	var n := 0
	for p in stars.positions:
		sum += p
		n += 1
	if n == 0:
		return Vector3.ZERO
	return sum / float(n)
