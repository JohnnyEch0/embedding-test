class_name TitleScene
extends IntroScene

@export var title_in := 1.5
@export var title_hold := 2.0
@export var title_out := 1.5
@export var gap := 0.5
@export var sub_in := 3.0
@export var sub_hold := 3.0
@export var sub_out := 1.5
@export var title_text := "Embedding Space"
@export var sub_text := "An interactive visualisation of how machines represent everyday language"

@onready var title_label: Label = $CanvasLayer/Title
@onready var sub_label: Label = $CanvasLayer/Subtitle


func start() -> void:
	title_label.text = title_text
	sub_label.text = sub_text
	_tween = create_tween()
	_tween.tween_property(title_label, "modulate:a", 1.0, title_in)
	_tween.tween_interval(title_hold)
	_tween.tween_property(title_label, "modulate:a", 0.0, title_out)
	_tween.tween_interval(gap)
	_tween.tween_property(sub_label, "modulate:a", 1.0, sub_in)
	_tween.tween_interval(sub_hold)
	_tween.tween_property(sub_label, "modulate:a", 0.0, sub_out)
	_tween.tween_callback(_finish)
