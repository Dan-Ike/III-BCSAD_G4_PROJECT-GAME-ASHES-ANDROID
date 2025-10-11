extends CanvasLayer

@onready var background: TextureRect = $Background
@onready var text_container: PanelContainer = $TextContainer
@onready var text_margin: MarginContainer = $TextContainer/TextMargin
@onready var text_label: Label = $TextContainer/TextMargin/TextLabel
@onready var summary_container: CenterContainer = $SummaryContainer
@onready var summary_panel: PanelContainer = $SummaryContainer/SummaryPanel
@onready var summary_margin: MarginContainer = $SummaryContainer/SummaryPanel/SummaryMargin
@onready var summary_v_box: VBoxContainer = $SummaryContainer/SummaryPanel/SummaryMargin/SummaryVBox
@onready var summary_title: Label = $SummaryContainer/SummaryPanel/SummaryMargin/SummaryVBox/SummaryTitle
@onready var summary_text: Label = $SummaryContainer/SummaryPanel/SummaryMargin/SummaryVBox/SummaryText
@onready var skip_button: Button = $SkipButton
@onready var continue_button: Button = $ContinueButton

# Cutscene data structure
var cutscene_data = [
	{
		"background": "res://art/hellimg.jpg",
		"text": "ah line line"
	},
	{
		"background": "res://icon.svg",
		"text": "woohoo"
	},
	{
		"background": "res://path/to/background3.png",
		"text": "line"
	}
]

var summary_data = {
	"title": "Story Summary",
	"text": "bat ka nag skip"
}

# State variables
var current_scene_index = 0
var current_text = ""
var displayed_text = ""
var is_typing = false
var typing_speed = 0.05
var typing_timer = 0.0
var skip_timer = 0.0
var show_skip_after = 5.0
var continue_timer = 0.0
var show_continue_after = 5.0
var in_summary = false

# Reference to player for pausing
var player: Player = null


func _ready() -> void:
	# Find player reference
	var level_node = get_parent()
	if level_node.has_node("player"):
		player = level_node.get_node("player")
	
	skip_button.hide()
	continue_button.hide()
	summary_container.hide()
	text_container.hide()
	
	# Connect text container input instead of full screen
	text_container.gui_input.connect(_on_text_container_input)
	summary_container.gui_input.connect(_on_summary_container_input)
	
	skip_button.pressed.connect(_on_skip_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Make text container clickable
	text_container.mouse_filter = Control.MOUSE_FILTER_STOP
	summary_container.mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	# Handle Enter key to advance
	if Input.is_action_just_pressed("ui_accept"):  # Enter key
		if in_summary:
			if continue_button.visible:
				proceed_to_game()
		else:
			complete_current_text()
	
	if is_typing:
		typing_timer += delta
		if typing_timer >= typing_speed:
			typing_timer = 0.0
			displayed_text += current_text[displayed_text.length()]
			text_label.text = displayed_text
			
			if displayed_text.length() >= current_text.length():
				is_typing = false
	
	if not in_summary and not skip_button.visible:
		skip_timer += delta
		if skip_timer >= show_skip_after:
			skip_button.show()
	
	if in_summary and not continue_button.visible:
		continue_timer += delta
		if continue_timer >= show_continue_after:
			continue_button.show()


func start_cutscene() -> void:
	# PAUSE THE GAME
	_pause_player()
	
	if cutscene_data.size() > 0:
		show_scene(0)


func _pause_player() -> void:
	"""Disable player controls and physics during cutscene"""
	if player:
		player.set_physics_process(false)
		player.set_process_input(false)
		player.velocity = Vector2.ZERO
		
		# Disable touch controls if they exist
		if player.has_node("../Control/TouchControls"):
			var touch_controls = player.get_node("../Control/TouchControls")
			touch_controls.visible = false


func _unpause_player() -> void:
	"""Re-enable player controls after cutscene"""
	if player:
		player.set_physics_process(true)
		player.set_process_input(true)
		
		# Re-enable touch controls
		if player.has_node("../Control/TouchControls"):
			var touch_controls = player.get_node("../Control/TouchControls")
			touch_controls.visible = true


func show_scene(index: int) -> void:
	if index >= cutscene_data.size():
		show_summary()
		return
	
	current_scene_index = index
	var scene = cutscene_data[index]
	
	if scene.has("background"):
		var texture = load(scene["background"])
		if texture:
			background.texture = texture
	
	current_text = scene["text"]
	displayed_text = ""
	text_label.text = ""
	is_typing = true
	typing_timer = 0.0
	
	text_container.show()


func complete_current_text() -> void:
	if is_typing:
		# Complete typing instantly
		displayed_text = current_text
		text_label.text = displayed_text
		is_typing = false
	else:
		# Move to next scene
		show_scene(current_scene_index + 1)


func show_summary() -> void:
	in_summary = true
	text_container.hide()
	skip_button.hide()
	
	summary_title.text = summary_data["title"]
	summary_text.text = summary_data["text"]
	summary_container.show()
	
	continue_timer = 0.0


func proceed_to_game() -> void:
	# UNPAUSE THE GAME
	_unpause_player()
	
	# Enable cameras and music in parent
	var level_node = get_parent()
	if level_node.has_node("player/Camera2D"):
		level_node.get_node("player/Camera2D").enabled = true
	if level_node.has_node("player/Camera2D2"):
		level_node.get_node("player/Camera2D2").enabled = true
	
	MusicManager.play_song("level1")
	
	# Remove cutscene
	queue_free()


func _on_text_container_input(event: InputEvent) -> void:
	"""Handle clicks on text container"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not in_summary:
				complete_current_text()


func _on_summary_container_input(event: InputEvent) -> void:
	"""Handle clicks on summary container"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if in_summary and continue_button.visible:
				proceed_to_game()


func _on_skip_pressed() -> void:
	show_summary()


func _on_continue_pressed() -> void:
	proceed_to_game()
