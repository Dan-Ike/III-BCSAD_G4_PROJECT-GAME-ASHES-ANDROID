extends Control

@onready var floor_1: Button = $FloorBtns/floor1
@onready var floor_2: Button = $FloorBtns/floor2
@onready var floor_3: Button = $FloorBtns/floor3
@onready var mainmenu: Button = $FloorBtns/mainmenu

func _ready() -> void:
	update_floor_buttons()

func update_floor_buttons() -> void:
	# Floor 1 always unlocked
	floor_1.disabled = false
	floor_1.text = "Floor 1"

	# Floor 2
	if SaveManager.is_floor_unlocked("floor_2"):
		floor_2.disabled = false
		floor_2.text = "Floor 2"
	else:
		floor_2.disabled = true
		floor_2.text = "Floor 2 (Locked)"

	# Floor 3
	if SaveManager.is_floor_unlocked("floor_3"):
		floor_3.disabled = false
		floor_3.text = "Floor 3"
	else:
		floor_3.disabled = true
		floor_3.text = "Floor 3 (Locked)"

func _on_floor_1_pressed() -> void:
	Global.selected_floor = "floor_1"
	get_tree().change_scene_to_file("res://scene/floor_level.tscn")

func _on_floor_2_pressed() -> void:
	Global.selected_floor = "floor_2"
	get_tree().change_scene_to_file("res://scene/floor_level.tscn")

func _on_floor_3_pressed() -> void:
	Global.selected_floor = "floor_3"
	get_tree().change_scene_to_file("res://scene/floor_level.tscn")

func _on_mainmenu_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")
