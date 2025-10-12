extends Control

@onready var preview_image: TextureRect = $TextureRect
@onready var level_label: Label = $Label
@onready var btn_next: Button = $next
@onready var btn_prev: Button = $prev
@onready var btn_play: Button = $play
@onready var btn_back: Button = $back

var levels: Array = []
var current_index: int = 0
const LEVELS_PER_FLOOR := 3
const flrsec := 2
const flrlast := 2

func _ready() -> void:
	var floor = Global.selected_floor
	var floor_number = _get_floor_number(floor)
	levels.clear()
	for i in range(1, LEVELS_PER_FLOOR + 1):
		levels.append("%s_level_%d" % [floor, i])
	current_index = _get_highest_unlocked_level_index(floor_number)
	_update_ui()

func _get_highest_unlocked_level_index(floor_number: int) -> int:
	var current_floor = SaveManager.data["progress"]["current_floor"]
	var current_level = SaveManager.data["progress"]["current_level"]
	if current_floor > floor_number:
		return LEVELS_PER_FLOOR - 1
	if current_floor == floor_number:
		return clamp(current_level - 1, 0, LEVELS_PER_FLOOR - 1)
	return 0

func _is_level_unlocked(floor_number: int, level_number: int) -> bool:
	var current_floor = SaveManager.data["progress"]["current_floor"]
	var current_level = SaveManager.data["progress"]["current_level"]
	if current_floor > floor_number:
		return true
	if current_floor == floor_number:
		if level_number <= current_level:
			return true
		if level_number == current_level + 1:
			return SaveManager.is_level_completed(floor_number, level_number - 1)
	return false

func _get_floor_number(floor_name: String) -> int:
	var parts = floor_name.split("_")
	if parts.size() >= 2:
		return int(parts[1])
	return 1

func _update_ui() -> void:
	var level_name = levels[current_index]
	var floor_number = _get_floor_number(Global.selected_floor)
	var level_number = current_index + 1
	var is_completed = SaveManager.is_level_completed(floor_number, level_number)
	var completion_text = " ✓" if is_completed else ""
	level_label.text = level_name.capitalize() + completion_text
	var tex_path = "res://assets/preview_images/%s.png" % level_name
	if ResourceLoader.exists(tex_path):
		preview_image.texture = load(tex_path)
	else:
		preview_image.texture = null
	btn_prev.visible = current_index > 0
	btn_prev.disabled = current_index == 0
	var next_level_unlocked = _is_level_unlocked(floor_number, level_number + 1)
	btn_next.visible = current_index < levels.size() - 1
	btn_next.disabled = not next_level_unlocked
	btn_play.disabled = not _is_level_unlocked(floor_number, level_number)
	if btn_play.disabled:
		level_label.modulate = Color(0.5, 0.5, 0.5)
		preview_image.modulate = Color(0.3, 0.3, 0.3)
	else:
		level_label.modulate = Color(1, 1, 1)
		preview_image.modulate = Color(1, 1, 1)

func _on_next_pressed() -> void:
	if current_index < levels.size() - 1:
		current_index += 1
		_update_ui()

func _on_prev_pressed() -> void:
	if current_index > 0:
		current_index -= 1
		_update_ui()

func _on_play_pressed() -> void:
	var level_name = levels[current_index]
	var floor_number = _get_floor_number(Global.selected_floor)
	var level_number = current_index + 1
	if _is_level_unlocked(floor_number, level_number):
		get_tree().change_scene_to_file("res://scene/%s.tscn" % level_name)
	else:
		print("Level is locked!")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/floor.tscn")
