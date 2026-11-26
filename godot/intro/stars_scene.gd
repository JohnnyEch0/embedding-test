class_name StarsScene
extends IntroScene

## Intro scene: hand-placed labelled stars appearing one by one,
## optionally joined by lines. Stars reuse EmbStar (emb_star.tscn), the
## app's basic visualization unit, so the intro shows the same stars as
## the main app — in particular EmbStar's fixed-size Label3D, which
## stays readable at glide distance (the hand-rolled labels rendered
## ~3 px tall because they lacked fixed_size and a tuned pixel_size).

const StarScene := preload("res://emb_star.tscn")

## EmbStar's base SphereMesh radius (emb_star.tscn); star_scale multiplies it.
const BASE_STAR_RADIUS := 0.5
## Labels visible at any intro distance. EmbStar's default 5.03 hides
## labels beyond 5 units; the intro camera is 60-120 units away.
const LABEL_RANGE_ON := 5000000.0

@export var positions: Array[Vector3] = [
	Vector3(-30, 10, -80),
	Vector3(20, 25, -120),
	Vector3(0, -15, -60),
	Vector3(35, -5, -100),
]
@export var words: Array[String] = ["language", "meaning", "embedding", "machine"]
## Multiplies EmbStar's base radius (0.5); 3.0 keeps the old radius-1.5 look.
@export var star_scale := 3.0
@export var draw_lines := true
@export var star_in := 0.4
@export var appear_gap := 0.4
@export var hold := 3.0

var _tween: Tween = null
var _stars: Array[EmbStar] = []


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


func _star_label(star: EmbStar) -> Label3D:
	# EmbStar.label is only assigned in _ready(), which does not run
	# synchronously on add_child (deferred in headless SceneTree mode) —
	# go through the child node instead.
	return star.get_node("Label3D") as Label3D


func _build_stars() -> void:
	var count: int = mini(positions.size(), words.size())
	for i in count:
		var star: EmbStar = StarScene.instantiate()
		# data must be set before add_child: EmbStar._ready() reads
		# data.label. id stays unset (empty) so EmbStar's label text is
		# exactly the word (it appends str(data.id)).
		var sd := EmbStarData.new()
		sd.label = words[i]
		sd.kind = &"word"
		sd.spawn_pos = positions[i]
		star.data = sd
		star.name = "Star" + str(i)
		star.position = sd.spawn_pos
		star.scale = Vector3.ONE * 0.01
		star.transparency = 1.0
		add_child(star)
		# per-instance label tuning; the text is also set here so it is
		# correct before _ready() converges to the same value
		var label := _star_label(star)
		label.text = words[i]
		label.visibility_range_end = LABEL_RANGE_ON
		label.modulate.a = 0.0 # emb_star default is opaque; reset for the fade-in
		_stars.append(star)
	if draw_lines and count >= 2:
		var line_points := PackedVector3Array()
		for i in range(1, count):
			line_points.append(positions[i - 1])
			line_points.append(positions[i])
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
		var label := _star_label(star)
		_tween.tween_property(star, "scale", Vector3.ONE * star_scale, star_in)
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
