extends Node3D

const STAR_SCENE = preload("res://emb_star.tscn")

const SCALE := 1000
@export var datapath := "res://data"
@export var default_filename := ""
var stars: Array[EmbStar] = []


@export var radius: float = 0.5
@export var show_lines := false

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
	var star_data: Array[EmbStarData] = []
	var first_line: String = data["lines"][0]
	var emb_dict = data["embedding_dict"]

	for word in first_line.split(" "):
		var single_star_data = EmbStarData.new()
		var emb = emb_dict[word].slice(0, 3)
		# print(word, emb)
		single_star_data.label = word
		single_star_data.spawn_pos = Vector3(emb[0] * SCALE, emb[1] * SCALE, emb[2] * SCALE)
		star_data.append(single_star_data)


	var pairs: Array = []
	var prev: MeshInstance3D = null
	for sd in star_data:
		var inst: MeshInstance3D = STAR_SCENE.instantiate()
		inst.data = sd
		inst.position = sd.spawn_pos

		add_child(inst)
		stars.append(inst)
		if prev: pairs.append([prev, inst])
		prev = inst

		#print("Star created at %s", inst.position)
		#print("Star created at %s", inst.mesh)

	if show_lines:
		draw_lines(pairs)


func draw_lines(pairs: Array):
	var verts := PackedVector3Array()
	for p in pairs:
		verts.append(p[0].position)
		verts.append(p[1].position)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var line_inst := MeshInstance3D.new()
	line_inst.mesh = mesh
	add_child(line_inst)
