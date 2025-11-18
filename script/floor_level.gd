extends Control

@onready var preview_image: TextureRect = $TextureRect
@onready var level_label: Label = $Label
@onready var btn_next: TouchScreenButton = $buttons/Control/next
@onready var btn_prev: TouchScreenButton = $buttons/Control2/prev
@onready var btn_play: TouchScreenButton = $buttons/Control3/play
@onready var btn_back: TouchScreenButton = $buttons/Control4/back

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
	
	var is_unlocked = _is_level_unlocked(floor_number, level_number)
	var is_completed = SaveManager.is_level_completed(floor_number, level_number)
	var completion_text = " ✓" if is_completed else ""
	
	level_label.text = level_name.capitalize() + completion_text
	
	# Load unlock/lock image based on status
	var image_suffix = "_unlock" if is_unlocked else "_lock"
	var tex_path = "res://art/preview_image/flr_%d_lvl_%d%s.png" % [floor_number, level_number, image_suffix]
	
	# Fallback to default image for now (since you don't have all images yet)
	if not ResourceLoader.exists(tex_path):
		tex_path = "res://art/hellimg.jpg"
	
	if ResourceLoader.exists(tex_path):
		preview_image.texture = load(tex_path)
	else:
		preview_image.texture = null
	
	# Previous button - always works if not at first level
	btn_prev.visible = current_index > 0
#	btn_prev.disabled = current_index == 0
	
	# Next button - always visible and clickable if not at last level
	btn_next.visible = current_index < levels.size() - 1
#	btn_next.disabled = current_index >= levels.size() - 1
	
	# Play button - only visible and clickable if level is unlocked
	btn_play.visible = is_unlocked
#	btn_play.disabled = not is_unlocked
	
	level_label.modulate = Color(1, 1, 1)
	preview_image.modulate = Color(1, 1, 1)
	# Visual feedback for locked levels
	#if is_unlocked:
	#	level_label.modulate = Color(1, 1, 1)
	#	preview_image.modulate = Color(1, 1, 1)
	#else:
	#	level_label.modulate = Color(0.5, 0.5, 0.5)
	#	preview_image.modulate = Color(0.3, 0.3, 0.3)

func _on_next_pressed() -> void:
	delayed_action(0.2, func():
		if current_index < levels.size() - 1:
			current_index += 1
			_update_ui()
	)

func _on_prev_pressed() -> void:
	delayed_action(0.2, func():
		if current_index > 0:
			current_index -= 1
			_update_ui()
	)

func _on_play_pressed() -> void:
	delayed_action(0.2, func():
		var level_name = levels[current_index]
		var floor_number = _get_floor_number(Global.selected_floor)
		var level_number = current_index + 1
		
		if _is_level_unlocked(floor_number, level_number):
			get_tree().change_scene_to_file("res://scene/%s.tscn" % level_name)
		else:
			print("Level is locked!")
	)

func _on_back_pressed() -> void:
	delayed_action(0.2, func():
		get_tree().change_scene_to_file("res://scene/floor.tscn")
	)

func delayed_action(delay: float, action: Callable) -> void:
	await get_tree().create_timer(delay).timeout
	action.call()
