extends Control

@onready var preview_image: TextureRect = $TextureRect
@onready var level_label: Label = $Label
@onready var btn_next: Button = $next
@onready var btn_prev: Button = $prev
@onready var btn_play: Button = $play
@onready var btn_back: Button = $back


var levels := []
var current_index: int = 0

func _ready() -> void:
	var floor = Global.selected_floor
	levels = SaveManager.data["progress"]["floors"][floor]["levels"].keys()
	levels.sort()

	# Start at first unlocked level
	for i in range(levels.size()):
		if SaveManager.is_level_unlocked(floor, levels[i]):
			current_index = i
			break

	_update_ui()

func _update_ui() -> void:
	var floor = Global.selected_floor
	var level_name = levels[current_index]

	level_label.text = level_name.capitalize()

	# Update preview image
	var tex_path = "res://assets/preview_images/%s.png" % level_name
	if ResourceLoader.exists(tex_path):
		preview_image.texture = load(tex_path)
	else:
		preview_image.texture = null

	# Buttons
	btn_prev.visible = current_index > 0
	btn_next.visible = current_index < levels.size() - 1 and SaveManager.is_level_unlocked(floor, levels[current_index + 1])
	btn_play.disabled = not SaveManager.is_level_unlocked(floor, level_name)

func _on_next_pressed() -> void:
	current_index += 1
	_update_ui()

func _on_prev_pressed() -> void:
	current_index -= 1
	_update_ui()

func _on_play_pressed() -> void:
	var floor = Global.selected_floor
	var level_name = levels[current_index]
	if SaveManager.is_level_unlocked(floor, level_name):
		get_tree().change_scene_to_file("res://scene/%s.tscn" % level_name)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/floor_select.tscn")
