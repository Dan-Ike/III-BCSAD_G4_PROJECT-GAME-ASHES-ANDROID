extends Control

@onready var floor_1: TouchScreenButton = $floor/Control/floor1
@onready var floor_2: TouchScreenButton = $floor/Control2/floor2
@onready var floor_3: TouchScreenButton = $floor/Control3/floor3
@onready var mainmenu: TouchScreenButton = $floor/Control4/back

# Store unlock status
var f2_unlocked = false
var f3_unlocked = false

func delayed_action(delay: float, action: Callable) -> void:
	await get_tree().create_timer(delay).timeout
	action.call()

func _ready() -> void:
	_update_floor_buttons()

func _update_floor_buttons() -> void:
	# Floor 1 always available
	# No need to disable floor_1
	
	# Floor 2
	if typeof(SaveManager) == TYPE_OBJECT and SaveManager.has_method("is_floor_unlocked"):
		f2_unlocked = SaveManager.is_floor_unlocked("floor_2")
	
	# Floor 3
	if typeof(SaveManager) == TYPE_OBJECT and SaveManager.has_method("is_floor_unlocked"):
		f3_unlocked = SaveManager.is_floor_unlocked("floor_3")

func _on_floor_1_pressed() -> void:
	delayed_action(0.2, func():
		Global.selected_floor = "floor_1"
		get_tree().change_scene_to_file("res://scene/floor_level.tscn")
	)

func _on_floor_2_pressed() -> void:
	delayed_action(0.2, func():
		if f2_unlocked:
			Global.selected_floor = "floor_2"
			get_tree().change_scene_to_file("res://scene/floor_level.tscn")
		else:
			_show_popup("Floor 2 is locked! Complete Floor 1 to unlock.")
	)

func _on_floor_3_pressed() -> void:
	delayed_action(0.2, func():
		if f3_unlocked:
			Global.selected_floor = "floor_3"
			get_tree().change_scene_to_file("res://scene/floor_level.tscn")
		else:
			_show_popup("Floor 3 is locked! Complete Floor 2 to unlock.")
	)

func _on_mainmenu_pressed() -> void:
	delayed_action(0.2, func():
		get_tree().change_scene_to_file("res://scene/main_menu.tscn")
	)

func _show_popup(message: String) -> void:
	var popup = AcceptDialog.new()
	popup.dialog_text = message
	popup.title = "Locked"
	add_child(popup)
	popup.popup_centered()
	# Auto-free the popup when closed
	popup.connect("confirmed", popup.queue_free)
	popup.connect("canceled", popup.queue_free)
