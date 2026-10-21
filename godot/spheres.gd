extends Node3D

const POSITIONS: Array[Vector3] = [
	Vector3(0, 0, -5),
	Vector3(3, 1, -8),
	Vector3(-2, -1, -12),
]

@export var radius: float = 0.5

func _ready() -> void:
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
