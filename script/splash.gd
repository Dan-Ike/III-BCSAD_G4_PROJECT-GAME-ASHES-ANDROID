extends Control

@onready var logo: TextureRect = $TextureRect

func _ready() -> void:
	var tween = create_tween()
	logo.modulate.a = 0.0
	tween.tween_property(logo, "modulate:a", 1.0, 1.5)
	tween.tween_interval(1.0) 
	tween.tween_property(logo, "modulate:a", 0.0, 1.0) 
	tween.tween_callback(_go_to_main_menu)

func _go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")
