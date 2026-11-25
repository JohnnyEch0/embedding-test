class_name StarsScene
extends IntroScene

@export var positions: Array[Vector3] = [
	Vector3(-30, 10, -80),
	Vector3(20, 25, -120),
	Vector3(0, -15, -60),
	Vector3(35, -5, -100),
]
@export var words: Array[String] = ["language", "meaning", "embedding", "machine"]
@export var star_radius := 1.5
@export var draw_lines := true
@export var star_in := 0.4
@export var appear_gap := 0.4
@export var hold := 3.0

var _tween: Tween = null
var _stars: Array[MeshInstance3D] = []


func start() -> void:
	if positions.is_empty() or words.is_empty():
		push_error("StarsScene: no positions or words exported, finishing at once.")
		_finish()
		return
	if positions.size() != words.size():
		push_error("StarsScene: %d positions but %d words, using the smaller count." % [positions.size(), words.size()])
	_build_stars()
	_play_stars()


func skip() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_finish()


func _build_stars() -> void:
	var count: int = mini(positions.size(), words.size())
	var line_points := PackedVector3Array()
	for i in count:
		var star := MeshInstance3D.new()
		star.name = "Star" + str(i)
		var mesh := SphereMesh.new()
		mesh.radius = star_radius
		mesh.height = star_radius * 2.0
		mesh.material = _unshaded_white()
		star.mesh = mesh
		star.position = positions[i]
		star.scale = Vector3.ONE * 0.01
		star.transparency = 1.0
		var label := Label3D.new()
		label.text = words[i]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 64
		label.modulate = Color(1, 1, 1, 0)
		label.position = Vector3(0, star_radius + 2.0, 0)
		star.add_child(label)
		add_child(star)
		_stars.append(star)
		line_points.append(positions[i])
	if draw_lines and count >= 2:
		var lines := MeshInstance3D.new()
		lines.name = "Lines"
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = line_points
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
		lines.mesh = am
		lines.material_override = _unshaded_white()
		lines.transparency = 1.0
		add_child(lines)


func _play_stars() -> void:
	_tween = create_tween()
	for star in _stars:
		var label: Label3D = star.get_child(0)
		_tween.tween_property(star, "scale", Vector3.ONE, star_in)
		_tween.parallel().tween_property(star, "transparency", 0.0, star_in)
		_tween.parallel().tween_property(label, "modulate:a", 1.0, star_in)
		_tween.tween_interval(appear_gap)
	var lines := get_node_or_null("Lines")
	if lines != null:
		_tween.tween_property(lines, "transparency", 0.0, 0.5)
	_tween.tween_interval(hold)
	_tween.tween_callback(_finish)


func _unshaded_white() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	return mat
