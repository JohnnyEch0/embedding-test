class_name AutoOrbit
extends Node

signal rotation_completed

@export var player: CharacterBody3D
@export var camera: Camera3D
@export var deg_per_sec := 20.0
@export var radius_factor := 1.5   # orbit radius = r_max * factor
@export var active := false

var _angle := 0.0
var _travelled := 0.0
var _radius := 100.0
var _target := Vector3.ZERO

# Fit the orbit to the current line. Restarts the rotation.
func fit(box: AABB, cone: Dictionary) -> void:
	_target = box.get_center()
	var r_max: float = cone.get("r_max", _target.length())
	_radius = maxf(r_max * radius_factor, 1.0)
	# start on the origin side: camera opposite the cluster, so origin is nearer than the stars
	_angle = atan2(-_target.z, -_target.x)
	_travelled = 0.0

func _process(delta: float) -> void:
	if not active or player == null:
		return
	var step := deg_to_rad(deg_per_sec) * delta
	_angle += step
	_travelled += step

	var pos := Vector3(cos(_angle) * _radius, _target.y, sin(_angle) * _radius)
	player.global_position = pos
	_look_at(pos, _target)

	if _travelled >= TAU:
		_travelled = 0.0
		rotation_completed.emit()  # handler may call fit() via stars_rebuilt

# Player body = yaw, camera = pitch (matches your mouse-look setup)
func _look_at(from: Vector3, to: Vector3) -> void:
	var d := to - from
	player.rotation = Vector3(0.0, atan2(-d.x, -d.z), 0.0)
	camera.rotation.x = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.5, 1.5)
