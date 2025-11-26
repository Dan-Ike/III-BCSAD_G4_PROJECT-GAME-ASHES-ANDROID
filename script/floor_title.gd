extends CanvasLayer

signal title_finished

@onready var floor_level: Label = $FloorLevel
@onready var color_rect: ColorRect = $ColorRect

var level_titles = {
	"1_1": "The Molten Rift",
	"1_2": "Spined Passage",
	"1_3": "The Ascending Crucible",
	"2_1": "The Ember Trial",
	"2_2": "Trial of Emberlight",
	"2_3": "The Maze of Shadows",
	"3_1": "The Midnight Hunt",
	"3_2": "The Warlock's Verdant Siege",
	"3_3": "The Memory That Hunts You"
}

func _ready() -> void:
	# Setup ColorRect if it doesn't exist
	if not has_node("ColorRect"):
		color_rect = ColorRect.new()
		color_rect.name = "ColorRect"
		color_rect.color = Color.BLACK
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(color_rect)
		move_child(color_rect, 0)
	else:
		color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	visible = false
	#_update_floor_level_display()

func show_title() -> void:
	print("[FloorTitle] Starting floor title display")
	_update_floor_level_display()  # Move it here!
	visible = true
	get_tree().paused = true
	
	# Set initial alpha
	if color_rect:
		color_rect.modulate.a = 1.0
	if floor_level:
		floor_level.modulate.a = 0.0
	
	# Fade in text (black background stays)
	await _fade_in(0.5)
	
	# Hold for 2 seconds
	await get_tree().create_timer(2.0).timeout
	
	# Fade out text
	await _fade_out(0.5)
	
	print("[FloorTitle] Finished, unpausing game")
	visible = false
	get_tree().paused = false
	title_finished.emit()

func _fade_in(duration: float) -> void:
	var elapsed = 0.0
	while elapsed < duration:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var alpha = elapsed / duration
		# Fade text in while black background stays
		if floor_level:
			floor_level.modulate.a = alpha

func _fade_out(duration: float) -> void:
	var elapsed = 0.0
	while elapsed < duration:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var alpha = 1.0 - (elapsed / duration)
		# Fade text out
		if floor_level:
			floor_level.modulate.a = alpha

func _update_floor_level_display() -> void:
	var current_floor = Global.current_floor
	var current_level = Global.current_level
	var title_key = "%d_%d" % [current_floor, current_level]
	var level_title = level_titles.get(title_key, "Unknown Level")
	
	floor_level.text = "Floor %d - Level %d\n\"%s\"" % [current_floor, current_level, level_title]
	print("[FloorTitle] Updated display to Floor %d, Level %d: %s" % [current_floor, current_level, level_title])

func _extract_floor_number(scene_name: String) -> int:
	var parts = scene_name.split("_")
	for i in range(parts.size()):
		if parts[i] == "floor" and i + 1 < parts.size():
			return int(parts[i + 1])
	return 1

func _extract_level_number(scene_name: String) -> int:
	var parts = scene_name.split("_")
	for i in range(parts.size()):
		if parts[i] == "level" and i + 1 < parts.size():
			return int(parts[i + 1])
	return 1
