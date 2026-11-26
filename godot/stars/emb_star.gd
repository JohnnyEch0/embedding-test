class_name EmbStar
extends MeshInstance3D
var data: EmbStarData

var label: Label3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	label = 	$"Label3D"
	label.text = data.label + str(data.id)
	label.position = Vector3i(0,2,0)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
