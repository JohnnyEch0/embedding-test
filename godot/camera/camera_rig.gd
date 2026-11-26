extends CharacterBody3D

@export var speed: float = 20.0
@export var mouse_sens: float = 0.002

var manual := true:
	set(v):
		manual = v
		if not v: velocity = Vector3.ZERO
	
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not manual:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sens)
		$Camera3D.rotate_x(-event.relative.y * mouse_sens)
		$Camera3D.rotation.x = clampf($Camera3D.rotation.x, -1.5, 1.5)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if not manual:
		return
	var input := Vector3(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_down", "move_up"),
		Input.get_axis("move_forward", "move_back")
	)
	var dir := (global_transform.basis * input).normalized()
	velocity = dir * speed
	move_and_slide()
