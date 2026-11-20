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

	# Store all data in temporaries
	var metadata: Dictionary = data.get("metadata", {})
	var lines: Array = data.get("lines", [])
	var verses: Array = data.get("verses", [])
	var poem: Dictionary = data.get("poem", {})

	if lines.is_empty():
		push_error("No lines in JSON data")
		return
	
	print_shape(data)
	
	
	# from here on, we should be able to get one or multiple lines from within the game instead of once loaded on startup
	# also per verse and per poem should be switchable
	# startup: spawn first line
	# func signature create_stars_from_data(line indices, verse_indices, show_poem_star:bool)
	# called from main input handling

	var first_line: Dictionary = lines[0]
	var words: Array = first_line.get("words", [])
	words.append_array(lines[1].get("words", []))
	var star_data: Array[EmbStarData] = []

	for w in words:
		var emb: Array = w["embedding"].slice(0, 3)
		var single_star_data = EmbStarData.new()
		single_star_data.label = w["word"]
		single_star_data.spawn_pos = Vector3(emb[0] * SCALE, emb[1] * SCALE, emb[2] * SCALE)
		star_data.append(single_star_data)

	create_stars(star_data)
	
	

func find_cluster_volume(star_data: Array[EmbStarData]):

	var minima = Vector3i(INF, INF, INF)
	var maxima = Vector3i(-INF, -INF, -INF)
	for d in star_data:
		minima = minima.min(d.spawn_pos)
		maxima = maxima.max(d.spawn_pos)

	return AABB(minima, maxima-minima)
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
	print(min_max)
	var bounds_box = MeshInstance3D.new()
	add_child(bounds_box)
	draw_aabb(bounds_box, min_max)
	register_debug(&"sentence_bounds_box", bounds_box)


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
var debug_nodes: Dictionary = {}  # StringName -> Array[Node3D]

func register_debug(key: StringName, node: Node3D) -> void:
	node.visible = false  # hidden by default
	debug_nodes.get_or_add(key, []).append(node)  # get_or_add: Godot 4.3+

func toggle_debug(key: StringName) -> void:
	#print("Toggle %s" % key)
	for n: Node3D in debug_nodes.get(key, []):
		n.visible = not n.visible


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
