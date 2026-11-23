extends Node3D

const STAR_SCENE = preload("res://emb_star.tscn")

const SCALE := 1000
const ORIGIN = Vector3(0, 0, 0)
@export var datapath := "res://data"
@export var default_filename := ""
var stars: Array[EmbStar] = []


@export var radius: float = 0.5
@export var show_lines := false
@export var draw_lines_origin := false
@export var show_special_stars:=true
var _lines: Array = []
var _verses: Array = []
var _poem: Dictionary = {}
var metadata: Dictionary = {}

# dimension projection: which embedding indices are shown on X/Y/Z.
# dim_count comes from the data metadata; dim_axes is steered by main.gd's
# DimMap. See dim_map.gd.
var dim_count := 3
var dim_axes := Vector3i(0, 1, 2)

# for automation
signal stars_rebuilt(box: AABB, cone: Dictionary)
var last_box := AABB()
var last_cone: Dictionary = {}

# style
const KIND_STYLE := {
	&"line":  {"color": Color.ORANGE,  "scale": 2.0},
	&"verse": {"color": Color.MAGENTA, "scale": 5.0},
	&"poem":  {"color": Color.WHITE,   "scale": 8.0},
}


func _read_json() -> Variant:
	var path := _resolve_path()
	if path == "":
		return null
	var json := JSON.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open: " + path)
		return null
	var error := json.parse(file.get_as_text())
	if error != OK:
		push_error("JSON Parse Error: %s (line %d)" % [json.get_error_message(), json.get_error_line()])
		return null
	return json.data


func _resolve_path() -> String:
	# Default filename set → use it
	if default_filename != "" and FileAccess.file_exists(datapath + "/" + default_filename):
		return datapath + "/" + default_filename
	# Otherwise pick a random file from the directory
	var dir := DirAccess.open(datapath)
	if dir == null:
		push_error("Data directory not found: " + datapath)
		return ""
	var files := dir.get_files()
	if files.is_empty():
		push_error("No files found in: " + datapath)
		return ""
	return datapath + "/" + files[randi() % files.size()]


func _ready() -> void:
	var data = _read_json()
	if data == null:
		push_error("Failed to load JSON data from " + datapath)
		return
	metadata = data.get("metadata", {})
	_lines = data.get("lines", [])
	_verses = data.get("verses", [])
	_poem = data.get("poem", {})
	dim_count = int(metadata.get("dimensions", _first_embedding_size()))
	if _lines.is_empty():
		push_error("No lines in JSON data")
		return
	# create_stars_from_data([1,2,3,4,5,6,7,8], [], true, true)
	#print_shape(data)
	#create_stars_from_data([0], [], false)  # startup: first line


func create_stars_from_data(
		line_indices: Array,
		verse_indices: Array = [],
		show_poem_star := false,
		show_line_stars := false,
		show_verse_stars := false) -> void:
	clear_stars()

	var wanted := {}
	for i in line_indices:
		wanted[int(i)] = true
	var verses_used: Array[int] = []
	for vi in verse_indices:
		if vi < 0 or vi >= _verses.size():
			push_warning("Verse index out of range: %d" % vi)
			continue
		verses_used.append(int(vi))
		var r: Array = _verses[vi].get("line_range", [])
		if r.size() == 2:
			for li in range(int(r[0]), int(r[1]) + 1):  # ASSUMED inclusive
				wanted[li] = true
	var indices := wanted.keys()
	indices.sort()

	var words: Array[EmbStarData] = []
	var extras: Array[EmbStarData] = []

	for li in indices:
		if li < 0 or li >= _lines.size():
			push_warning("Line index out of range: %d" % li)
			continue
		var line: Dictionary = _lines[li]
		for w in line.get("words", []):
			words.append(_make_star_data(w["word"], w["embedding"]))
		if show_line_stars and line.has("line_embedding"):
			print("Line shown=")
			extras.append(_make_star_data(line.get("line", "line %d" % li), line["line_embedding"], &"line"))

	if show_verse_stars:
		for vi in _verses.size():
			var v: Dictionary = _verses[vi]
			if not v.has("verse_embedding"):
				continue
			var r: Array = v.get("line_range", [])
			var hit := vi in verses_used
			if not hit and r.size() == 2:
				for li in indices:
					if li >= int(r[0]) and li <= int(r[1]):
						hit = true
						break
			if hit:
				extras.append(_make_star_data("verse %d" % vi, v["verse_embedding"], &"verse"))

	if show_poem_star and _poem.has("poem_embedding"):
		extras.append(_make_star_data(metadata.get("title", "poem"), _poem["poem_embedding"], &"poem"))

	if words.is_empty():
		push_warning("Nothing to spawn")
		return
	create_stars(words)  # cone/AABB/chain from words only
	for sd in extras:
		_spawn_extra(sd)

func _first_embedding_size() -> int:
	"""Fallback dim_count: size of the first word embedding in the data."""
	for line: Dictionary in _lines:
		for w: Dictionary in line.get("words", []):
			return w.get("embedding", []).size()
	return 3

func _make_star_data(label: String, embedding: Array, kind := &"word") -> EmbStarData:
	var sd := EmbStarData.new()
	sd.label = label
	sd.kind = kind
	# clamp indices against data/metadata disagreement instead of crashing
	var d := embedding.size()
	var ix := mini(dim_axes.x, d - 1)
	var iy := mini(dim_axes.y, d - 1)
	var iz := mini(dim_axes.z, d - 1)
	sd.spawn_pos = Vector3(embedding[ix], embedding[iy], embedding[iz]) * SCALE
	return sd

func clear_stars() -> void:
	for s in stars:
		if is_instance_valid(s):
			s.queue_free()
	stars.clear()
	for key in debug_nodes:
		for n in debug_nodes[key]:
			if is_instance_valid(n):
				n.queue_free()
	debug_nodes.clear()
	


func find_cluster_volume(star_data: Array[EmbStarData]):
	if star_data.is_empty():
			return AABB()
	var minima := Vector3(INF, INF, INF)
	var maxima := Vector3(-INF, -INF, -INF)
	for d in star_data:
		minima = minima.min(d.spawn_pos)
		maxima = maxima.max(d.spawn_pos)
	return AABB(minima, maxima - minima)
		
func find_cluster_cone(star_data: Array[EmbStarData]) -> Dictionary:
	var sum := Vector3.ZERO
	var r_min := INF
	var r_max := 0.0
	for d in star_data:
		var r := d.spawn_pos.length()
		if r < 0.0001: continue  # direction undefined at origin
		r_min = minf(r_min, r)
		r_max = maxf(r_max, r)
		sum += d.spawn_pos / r
	if sum.length() < 0.0001:
		return {}  # directions cancel out, no meaningful cone
	var m := sum.normalized()
	var theta := 0.0
	for d in star_data:
		if d.spawn_pos.length() < 0.0001: continue
		theta = maxf(theta, m.angle_to(d.spawn_pos))
	var omega := TAU * (1.0 - cos(theta))
	return {
		"axis": m, "half_angle": theta, "solid_angle": omega,
		"r_min": r_min, "r_max": r_max,
		"volume": omega / 3.0 * (pow(r_max, 3) - pow(r_min, 3)),
	}

func create_stars(star_data) -> void:
	var pairs: Array = []
	var prev: MeshInstance3D = null
	for sd in star_data:
		var inst: MeshInstance3D = STAR_SCENE.instantiate()
		inst.data = sd
		inst.position = sd.spawn_pos

		add_child(inst)
		stars.append(inst)
		register_debug(&"labels", inst.label, _set_label_range)
		if prev: pairs.append([prev.position, inst.position])
		prev = inst

	if show_lines:
		register_debug(&"word_connections", draw_lines(pairs))
	if draw_lines_origin:
		pairs = []
		for sd in star_data:
			pairs.append([sd.spawn_pos, ORIGIN])
		register_debug(&"word_to_origin",draw_lines(pairs))
	var min_max = find_cluster_volume(star_data)
	var cone = find_cluster_cone(star_data)
	if not cone.is_empty():
		register_debug(&"sentence_cone", draw_cone(cone))
	# print(min_max)
	var bounds_box = MeshInstance3D.new()
	add_child(bounds_box)
	draw_aabb(bounds_box, min_max)
	register_debug(&"sentence_bounds_box", bounds_box)
	
	last_box = min_max
	last_cone = cone
	stars_rebuilt.emit(min_max, cone)
	
func _spawn_extra(sd: EmbStarData) -> void:
	var style: Dictionary = KIND_STYLE[sd.kind]
	var inst: EmbStar = STAR_SCENE.instantiate()
	inst.data = sd
	inst.position = sd.spawn_pos
	
	add_child(inst)
	inst.label.font_size /= 2
	inst.scale = Vector3.ONE * style["scale"]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = style["color"]
	inst.material_override = mat
	stars.append(inst)
	register_debug(StringName(str(sd.kind) + "_stars"), inst)  # line_stars / verse_stars / poem_stars
	register_debug(&"labels", inst.label, _set_label_range)
	if show_special_stars:
		inst.visible = true


func draw_lines(pairs: Array):
	var verts := PackedVector3Array()
	for p in pairs:
		verts.append(p[0])
		verts.append(p[1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var line_inst := MeshInstance3D.new()
	line_inst.mesh = mesh
	add_child(line_inst)
	return line_inst

func draw_aabb(mi: MeshInstance3D, box: AABB, color := Color.YELLOW) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color

	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for i in 8:
		for bit in [1, 2, 4]:
			if i & bit == 0:  # edge = corners differing by one bit
				im.surface_add_vertex(box.get_endpoint(i))
				im.surface_add_vertex(box.get_endpoint(i | bit))
	im.surface_end()
	mi.mesh = im

func draw_cone(cone: Dictionary, color := Color.CYAN, segments := 48) -> MeshInstance3D:
	var axis: Vector3 = cone["axis"]
	var theta: float = cone["half_angle"]
	var r_min: float = cone["r_min"]
	var r_max: float = cone["r_max"]

	# orthonormal basis perpendicular to axis
	var helper := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var u := axis.cross(helper).normalized()
	var v := axis.cross(u)

	# point on the cone surface at radius r, azimuth a
	var pt := func(r: float, a: float) -> Vector3:
		return r * (cos(theta) * axis + sin(theta) * (cos(a) * u + sin(a) * v))

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color

	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)

	# axis
	im.surface_add_vertex(Vector3.ZERO)
	im.surface_add_vertex(axis * r_max)

	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		for r in [r_min, r_max]:  # rings
			im.surface_add_vertex(pt.call(r, a0))
			im.surface_add_vertex(pt.call(r, a1))
		if i % (segments / 8) == 0:  # generators, 8 total
			im.surface_add_vertex(Vector3.ZERO)
			im.surface_add_vertex(pt.call(r_min, a0))
			im.surface_add_vertex(pt.call(r_min, a0))
			im.surface_add_vertex(pt.call(r_max, a0))
	im.surface_end()

	var mi := MeshInstance3D.new()
	mi.mesh = im
	add_child(mi)
	return mi


# ======================= debug register
const LABEL_RANGE_ON := 5000000.0
const LABEL_RANGE_OFF := 5.0

var debug_nodes: Dictionary = {}    # StringName -> Array[Node3D]
var debug_on: Dictionary = {}       # StringName -> bool, survives rebuilds
var debug_setters: Dictionary = {}  # StringName -> Callable(node, on); default: visible

func register_debug(key: StringName, node: Node3D, setter := Callable()) -> void:
	if setter.is_valid():
		debug_setters[key] = setter
	debug_nodes.get_or_add(key, []).append(node)
	_apply_debug(key, node)  # applies current state, hidden by default

func set_debug(key: StringName, on: bool) -> void:
	debug_on[key] = on
	for n: Node3D in debug_nodes.get(key, []):
		if is_instance_valid(n):
			_apply_debug(key, n)

func toggle_debug(key: StringName) -> void:
	set_debug(key, not debug_on.get(key, false))

func has_debug(key: StringName) -> bool:
	return debug_nodes.has(key)

func _apply_debug(key: StringName, node: Node3D) -> void:
	var on: bool = debug_on.get(key, false)
	var setter: Callable = debug_setters.get(key, Callable())
	if setter.is_valid():
		setter.call(node, on)
	else:
		node.visible = on

func _set_label_range(label: Node3D, on: bool) -> void:
	(label as Label3D).visibility_range_end = LABEL_RANGE_ON if on else LABEL_RANGE_OFF


func print_shape(v: Variant, key := "root", depth := 0) -> void:
	var pad := "  ".repeat(depth)
	match typeof(v):
		TYPE_DICTIONARY:
			print("%s%s: Dictionary{%d}" % [pad, key, v.size()])
			for k in v:
				print_shape(v[k], str(k), depth + 1)
		TYPE_ARRAY:
			if v.is_empty():
				print("%s%s: Array[0]" % [pad, key])
			elif typeof(v[0]) == TYPE_FLOAT or typeof(v[0]) == TYPE_INT:
				print("%s%s: numbers[%d]" % [pad, key, v.size()])  # e.g. embedding
			else:
				print("%s%s: Array[%d], first element:" % [pad, key, v.size()])
				print_shape(v[0], "[0]", depth + 1)
		_:
			print("%s%s: %s = %s" % [pad, key, type_string(typeof(v)), str(v).left(40)])

func line_count() -> int: return _lines.size()
