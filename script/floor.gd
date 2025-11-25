extends Control
@onready var floor_1: TouchScreenButton = $floor/Control/floor1
@onready var floor_2: TouchScreenButton = $floor/Control2/floor2
@onready var floor_3: TouchScreenButton = $floor/Control3/floor3
@onready var mainmenu: TouchScreenButton = $floor/Control4/back
@onready var floor_2_lock: Control = $Floor2Lock
@onready var floor_3_lock: Control = $Floor3Lock
@onready var back_2: TouchScreenButton = $Floor2Lock/Control3/back_2
@onready var okay_2: TouchScreenButton = $Floor2Lock/Control/okay2
@onready var back_3: TouchScreenButton = $Floor3Lock/Control3/back_3
@onready var okay_3: TouchScreenButton = $Floor3Lock/Control/okay3
@onready var floor: Control = $floor

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
	await get_tree().create_timer(0.15).timeout
	Global.selected_floor = "floor_1"
	transition_out("res://scene/floor_level.tscn")

func _on_floor_2_pressed() -> void:
	await get_tree().create_timer(0.15).timeout
	if f2_unlocked:
		Global.selected_floor = "floor_2"
		transition_out("res://scene/floor_level.tscn")
	else:
		floor.visible = false
		floor_2_lock.visible = true

func _on_floor_3_pressed() -> void:
	await get_tree().create_timer(0.15).timeout
	if f3_unlocked:
		Global.selected_floor = "floor_3"
		transition_out("res://scene/floor_level.tscn")
	else:
		floor.visible = false
		floor_3_lock.visible = true

func _on_mainmenu_pressed() -> void:
	await get_tree().create_timer(0.15).timeout
	slide_out_transition("res://scene/main_menu.tscn")

func transition_out(scene_path: String) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Fade out all elements
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	
	await tween.finished
	
	get_tree().change_scene_to_file(scene_path)

func slide_out_transition(scene_path: String) -> void:
	# Preload the next scene (main menu)
	var next_scene = load(scene_path).instantiate()
	
	# Position it normally behind current scene
	next_scene.position.x = 0
	next_scene.z_index = -1  # Behind current scene
	get_tree().root.add_child(next_scene)
	
	# Create the slide animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Slide current scene out to the right (revealing main menu underneath)
	tween.tween_property(self, "position:x", get_viewport_rect().size.x, 0.5)
	
	await tween.finished
	
	# Clean up and switch scenes properly
	get_tree().current_scene = next_scene
	queue_free()

func _show_popup(message: String) -> void:
	var popup = AcceptDialog.new()
	popup.dialog_text = message
	popup.title = "Locked"
	add_child(popup)
	popup.popup_centered()
	# Auto-free the popup when closed
	popup.connect("confirmed", popup.queue_free)
	popup.connect("canceled", popup.queue_free)


func _on_back_2_pressed() -> void:
	floor_2_lock.visible = false
	floor.visible = true

func _on_okay_2_pressed() -> void:
	floor_2_lock.visible = false
	floor.visible = true

func _on_back_3_pressed() -> void:
	floor_3_lock.visible = false
	floor.visible = true

func _on_okay_3_pressed() -> void:
	floor_3_lock.visible = false
	floor.visible = true
