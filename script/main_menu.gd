extends Control

@onready var main_btns: VBoxContainer = $MainBtns
@onready var options: Panel = $Options
@onready var control_choice: OptionButton = $Options/ControlChoice

func _ready() -> void:
	main_btns.visible = true
	options.visible = false
	MusicManager.play_song("menu")
	control_choice.select(Global.control_type)
	control_choice.item_selected.connect(_on_control_choice_selected)

func _on_control_choice_selected(index: int) -> void:
	Global.control_type = index

func _process(delta: float) -> void:
	pass

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/floor.tscn")

func _on_options_pressed() -> void:
	main_btns.visible = false
	options.visible = true

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_back_pressed() -> void:
	_ready()
