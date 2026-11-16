extends Node3D

const STAR_SCENE = preload("res://emb_star.tscn")


const POSITIONS: Array[Vector3] = [
	Vector3(0, 0, -5),
	Vector3(3, 1, -8),
	Vector3(-2, -1, -12),
]

var stars: Array[EmbStar] = []


@export var radius: float = 0.5

func _ready() -> void:
	var json = JSON.new()
	var file = FileAccess.open("res://data/sample.json", FileAccess.READ)
	if file == null:
		print("File error: ", )
	var error = json.parse(file.get_as_text())
	var star_data: Array[EmbStarData] = []
	if error == OK:
		var data = json.data	
		var first_line:String = data["lines"][0]
		print(first_line)
		var emb_dict = data["embedding_dict"]
		
		for word in first_line.split(" "):
			var single_star_data = EmbStarData.new()
			var emb = emb_dict[word].slice(0,3)
			# print(word, emb)
			single_star_data.label = word
			single_star_data.spawn_pos = Vector3(emb[0] * 1000, emb[1] * 1000, emb[2] * 1000)
			star_data.append(single_star_data)
	else: 
		print("JSON Parse Error: ", json.get_error_message(), json.get_error_line())

	
	for sd in star_data:
		var inst: MeshInstance3D = STAR_SCENE.instantiate()
		inst.data = sd
		inst.position = sd.spawn_pos
		
		add_child(inst)
		stars.append(inst)
		print("Star created at %s", inst.position)
		print("Star created at %s", inst.mesh)
	
	

func _depr_spawn():
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mesh.material = mat

	for p in POSITIONS:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh          # shared resource, cheap
		mi.position = p
		add_child(mi)
