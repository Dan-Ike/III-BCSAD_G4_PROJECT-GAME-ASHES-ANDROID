extends CanvasLayer

signal cutscene_finished

@onready var background: TextureRect = $Background
@onready var text_container: PanelContainer = $TextContainer
@onready var text_margin: MarginContainer = $TextContainer/TextMargin
@onready var text_label: Label = $TextContainer/TextMargin/TextLabel
@onready var summary_container: CenterContainer = $SummaryContainer
@onready var summary_panel: PanelContainer = $SummaryContainer/SummaryPanel
@onready var summary_margin: MarginContainer = $SummaryContainer/SummaryPanel/SummaryMargin
@onready var summary_v_box: VBoxContainer = $SummaryContainer/SummaryPanel/SummaryMargin/SummaryVBox
@onready var summary_title: Label = $SummaryContainer/SummaryPanel/SummaryMargin/SummaryVBox/SummaryTitle
#@onready var summary_text: Label = $SummaryContainer/SummaryPanel/SummaryMargin/SummaryVBox/SummaryText
#@onready var skip_button: Button = $SkipButton
@onready var continue_button: Button = $ContinueButton
@onready var skip_button: TouchScreenButton = $buttons/Control/SkipButton
@onready var summary_text: Label = $SummaryContainer2/SummaryText
@onready var summary_container_2: Control = $SummaryContainer2
@onready var bg_2: Panel = $bg2
@onready var color_rect: ColorRect = $ColorRect

@onready var skip_cutscene: Control = $skipCutscene
@onready var cancel: TouchScreenButton = $skipCutscene/Control/cancel
@onready var exit: TouchScreenButton = $skipCutscene/Control2/exit
@onready var back_exit: TouchScreenButton = $skipCutscene/Control3/back_exit


var cutscene_data = [

	{
		"background":"res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/NEW VERSION/2 - After 1.3/f01 - new.png",
		"texts": [
			"\"Limbo was quiet. Too quiet. Like the world had stopped breathing.\""
		]
	},
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/NEW VERSION/2 - After 1.3/f02 - new.png",
		"texts": [
			"\"If I stopped, I’d vanish too.\""
		]
	},
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/NEW VERSION/2 - After 1.3/f03 - new.png",
		"texts": [
			"\"Lust burned. Not with desire. But with regret.\""
		]
	},
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/NEW VERSION/2 - After 1.3/f04 - new.png",
		"texts": [
			"\"I ran faster. I didn’t dare look back.\""
		]
	},
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/NEW VERSION/2 - After 1.3/f05 - new.png",
		"texts": [
			"\"Gluttony devours everything. Even the ground.\""
		]
	},
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/NEW VERSION/2 - After 1.3/f06 - new.png",
		"texts": [
			"\"I couldn’t breathe. Just run.\""
		]
	},
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/NEW VERSION/2 - After 1.3/f07 - new.png",
		"texts": [
			"\"I didn’t escape. I endured.\""
		]
	},
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/NEW VERSION/2 - After 1.3/f08  - new.png",
		"texts": [
			"\"I thought I’d earned rest. But the tower doesn’t reward. It reveals.\""
		]
	}
]

var summary_data = {
	"title": "Story Summary",
	"text": "The place felt lifeless, and stopping meant disappearing. Regret hit hard, so he kept running without looking back, even when everything around him was collapsing. He struggled to breathe but continued. He didn’t escape—he endured. He expected rest, but the tower doesn’t give rewards, only truth."
}

# State variables
var current_scene_index = 0
var current_text_index = 0
var current_background_path = ""
var current_text = ""
var displayed_text = ""
var is_typing = false
var typing_speed = 0.05
var typing_timer = 0.0
var skip_timer = 0.0
var show_skip_after = 5.0
var continue_timer = 0.0
var show_continue_after = 3.0
var in_summary = false
var cutscene_paused = false
var is_transitioning = false

# Fade transition
var fade_duration = 0.5
var text_fade_duration = 0.3
var fade_timer = 0.0
var text_fade_timer = 0.0
var fading_out = false
var fading_in = false
var text_fading_out = false
var text_fading_in = false
var next_background_path = ""
var text_delay_timer = 0.0
var text_delay_duration = 0.5
var waiting_for_text_delay = false

# Reference to player for pausing
var player: Player = null

# Track cutscene ID for "play once" mode
var cutscene_id: String = ""

func _ready() -> void:
	# Find player reference
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	var level_node = get_parent()
	if level_node.has_node("player"):
		player = level_node.get_node("player")
	
	skip_cutscene.visible = false
	bg_2.visible = false
	skip_button.hide()
	continue_button.hide()
	summary_container_2.hide()
	text_container.hide()
	text_container.modulate.a = 0.0
	
	continue_button.pressed.connect(_on_continue_pressed)

func _input(event: InputEvent) -> void:
	"""Handle screen clicks anywhere"""
	if cutscene_paused: 
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Check if clicking on buttons - let them handle their own input
			if skip_button.visible and skip_button.is_pressed():
				return
			if continue_button.visible and continue_button.get_global_rect().has_point(event.position):
				return
			
			# Anywhere else on screen advances text
			if not in_summary and not is_transitioning and not waiting_for_text_delay:
				complete_current_text()
			elif in_summary and continue_button.visible:
				proceed_to_game()
			
			get_tree().root.set_input_as_handled()

func _process(delta: float) -> void:
	if in_summary and not continue_button.visible:
		continue_timer += delta
		if continue_timer >= show_continue_after:
			continue_button.show()
	
	if cutscene_paused:
		return
	
	# Handle fade transitions for background
	if fading_out or fading_in:
		fade_timer += delta
		var progress = clamp(fade_timer / fade_duration, 0.0, 1.0)
		
		if fading_out:
			background.modulate.a = 1.0 - progress
			if progress >= 1.0:
				fading_out = false
				# Load new background
				if next_background_path != "":
					var texture = load(next_background_path)
					if texture:
						background.texture = texture
						current_background_path = next_background_path
				# Start fading in
				fading_in = true
				fade_timer = 0.0
		
		elif fading_in:
			background.modulate.a = progress
			if progress >= 1.0:
				fading_in = false
				is_transitioning = false
				background.modulate.a = 1.0
	
	# Handle text delay before showing
	if waiting_for_text_delay:
		text_delay_timer += delta
		if text_delay_timer >= text_delay_duration:
			waiting_for_text_delay = false
			text_delay_timer = 0.0
			# Start showing text container with fade in
			# Make sure to use current_text which was set in show_scene
			_start_text_fade_in()
	
	# Handle fade transitions for text container
	if text_fading_out or text_fading_in:
		text_fade_timer += delta
		var progress = clamp(text_fade_timer / text_fade_duration, 0.0, 1.0)
		
		if text_fading_out:
			text_container.modulate.a = 1.0 - progress
			if progress >= 1.0:
				text_fading_out = false
				text_container.hide()
		
		elif text_fading_in:
			text_container.modulate.a = progress
			if progress >= 1.0:
				text_fading_in = false
				text_container.modulate.a = 1.0
	
	# Handle Enter key to advance
	if Input.is_action_just_pressed("ui_accept") and not cutscene_paused:  # Enter key
		if in_summary:
			if continue_button.visible:
				proceed_to_game()
		else:
			if not is_transitioning and not waiting_for_text_delay:
				complete_current_text()
	
	if is_typing:
		typing_timer += delta
		if typing_timer >= typing_speed:
			typing_timer = 0.0
			# Safety check to prevent index out of bounds
			if displayed_text.length() < current_text.length():
				displayed_text += current_text[displayed_text.length()]
				text_label.text = displayed_text
			
			if displayed_text.length() >= current_text.length():
				is_typing = false
	
	if not in_summary and not skip_button.visible:
		skip_timer += delta
		if skip_timer >= show_skip_after:
			skip_button.show()
	



func start_cutscene(id: String = "") -> void:
	cutscene_id = id
	
	# Check cutscene preference
	var cutscene_pref = SaveManager.get_setting("cutscene_preference")
	
	# If "play_once" mode and cutscene already played, skip it
	if cutscene_pref == "play_once" and cutscene_id != "":
		if SaveManager.has_watched_cutscene(cutscene_id):
			print("[Cutscene] Already watched, skipping...")
			# Emit signal immediately and remove cutscene
			cutscene_finished.emit()
			queue_free()
			return
	
	# Actually play the cutscene
	print("[Cutscene] Starting cutscene playback")
	Global.cutscene_playing = true
	
	# Play cutscene music
	MusicManager.play_song("menu")
	print("Cutscene music started: menu")
	
	# DISCONNECT pause button signal to prevent accidental triggers
	if player and player.has_node("../CanvasLayer"):
		var touch_controls = player.get_node("../CanvasLayer")
		if touch_controls and touch_controls.has_node("Control/Control6/pause"):
			var pause_btn = touch_controls.get_node("Control/Control6/pause")
			if pause_btn.pressed.is_connected(touch_controls._on_pause_pressed):
				pause_btn.pressed.disconnect(touch_controls._on_pause_pressed)
	
	# PAUSE THE GAME
	_pause_player()
	get_tree().paused = true
	
	if cutscene_data.size() > 0:
		show_scene(0, 0)


func _pause_player() -> void:
	"""Disable player controls and physics during cutscene"""
	if player:
		player.set_physics_process(false)
		player.set_process_input(false)
		player.velocity = Vector2.ZERO
		
		# Disable touch controls completely
		if player.has_node("../CanvasLayer"):
			var touch_controls = player.get_node("../CanvasLayer")
			if touch_controls:
				touch_controls.disable_all_controls()


func _unpause_player() -> void:
	"""Re-enable player controls after cutscene"""
	get_tree().paused = false  
	
	if player:
		player.set_physics_process(true)
		player.set_process_input(true)
		
		# Re-enable touch controls
		if player.has_node("../CanvasLayer"):
			var touch_controls = player.get_node("../CanvasLayer")
			if touch_controls:
				touch_controls.enable_pause()  
				touch_controls.visible = true  
				touch_controls.set_process(true)  
				touch_controls.set_block_signals(false)  



func show_scene(scene_index: int, text_index: int) -> void:
	if scene_index >= cutscene_data.size():
		show_summary()
		return
	
	current_scene_index = scene_index
	current_text_index = text_index
	var scene = cutscene_data[scene_index]
	
	# Get the text for this scene/index
	var texts = scene.get("texts", [])
	if text_index >= texts.size():
		# No more texts in this scene, move to next
		show_scene(scene_index + 1, 0)
		return
	
	# Set current text FIRST before any delays or transitions
	current_text = texts[text_index]
	displayed_text = ""
	text_label.text = ""
	
	print("show_scene called - Scene: %d, Text: %d, Content: %s" % [scene_index, text_index, current_text])
	
	# Check if we need to change background (fade transition)
	var new_background = scene.get("background", "")
	var is_first_text_of_scene = (text_index == 0)
	var background_changed = (new_background != current_background_path)
	
	if new_background != "" and background_changed:
		# Different background - need transition
		if current_background_path == "":
			# Very first scene - no fade, just load
			var texture = load(new_background)
			if texture:
				background.texture = texture
				current_background_path = new_background
			background.modulate.a = 1.0
			
			# Delay before showing first text with fade
			waiting_for_text_delay = true
			text_delay_timer = 0.0
		else:
			# Fade out current text first
			_start_text_fade_out()
			
			# Then fade transition to new background
			is_transitioning = true
			fading_out = true
			fading_in = false
			fade_timer = 0.0
			next_background_path = new_background
			
			# Wait for both transitions before showing text
			await get_tree().create_timer(fade_duration * 2).timeout
			
			# Delay before showing first text of new scene with fade
			waiting_for_text_delay = true
			text_delay_timer = 0.0
			return
	else:
		# Same background or not first text - show text immediately
		if is_first_text_of_scene:
			# First text but background didn't change (shouldn't happen normally)
			waiting_for_text_delay = true
			text_delay_timer = 0.0
		else:
			# Not first text - just update text without fade, keep container visible
			text_container.show()
			text_container.modulate.a = 1.0
			is_typing = true
			typing_timer = 0.0


func _start_text_fade_out() -> void:
	"""Start fading out the text container"""
	if text_container.visible:
		text_fading_out = true
		text_fading_in = false
		text_fade_timer = 0.0


func _start_text_fade_in() -> void:
	"""Start fading in the text container and begin typing"""
	text_container.show()
	text_container.modulate.a = 0.0
	text_fading_in = true
	text_fading_out = false
	text_fade_timer = 0.0
	
	# Reset text display before starting typing - use current_text
	displayed_text = ""
	text_label.text = ""
	
	# Start typing animation with the current_text
	is_typing = true
	typing_timer = 0.0
	
	# Debug print
	print("Starting text fade in with text: ", current_text)


func complete_current_text() -> void:
	# Don't allow interaction during transitions
	if is_transitioning or waiting_for_text_delay:
		return
		
	if is_typing:
		# Complete typing instantly
		displayed_text = current_text
		text_label.text = displayed_text
		is_typing = false
	else:
		# Check if next will be a new background
		var scene = cutscene_data[current_scene_index]
		var texts = scene.get("texts", [])
		
		if current_text_index + 1 < texts.size():
			# More texts in this scene - just show next text without fade
			show_scene(current_scene_index, current_text_index + 1)
		else:
			# Moving to next scene - fade out text, then change background
			is_transitioning = true  # Set this BEFORE starting fade
			_start_text_fade_out()
			
			# Wait for fade out
			await get_tree().create_timer(text_fade_duration).timeout
			
			# Move to next scene
			show_scene(current_scene_index + 1, 0)


func show_summary() -> void:
	background.visible = false
	color_rect.visible = false
	bg_2.visible = true
	in_summary = true
	
	# Fade out text container
	_start_text_fade_out()
	skip_button.hide()
	
	await get_tree().create_timer(text_fade_duration).timeout
	
	text_container.visible = false
	
	#summary_title.text = summary_data["title"]
	summary_text.text = summary_data["text"]
	summary_container_2.show()
	
	continue_timer = 0.0 

func proceed_to_game() -> void:
	Global.cutscene_playing = false
	
	var level_node = get_parent()
	if level_node.has_node("player"):
		var player = level_node.get_node("player")
		if player.has_method("reset_level_timer"):
			player.reset_level_timer()
	
	# Mark cutscene as watched if ID is provided
	if cutscene_id != "":
		SaveManager.mark_cutscene_watched(cutscene_id)
	
	# UNPAUSE THE GAME - Make sure this happens
	get_tree().paused = false
	
	# RECONNECT pause button signal
	if player and player.has_node("../CanvasLayer"):
		var touch_controls = player.get_node("../CanvasLayer")
		if touch_controls and touch_controls.has_node("Control/Control6/pause"):
			var pause_btn = touch_controls.get_node("Control/Control6/pause")
			if not pause_btn.pressed.is_connected(touch_controls._on_pause_pressed):
				pause_btn.pressed.connect(touch_controls._on_pause_pressed)
	
	_unpause_player()
	
	# Enable cameras in parent
	if level_node.has_node("player/Camera2D"):
		level_node.get_node("player/Camera2D").enabled = true
	if level_node.has_node("player/Camera2D2"):
		level_node.get_node("player/Camera2D2").enabled = true
	
	# Play level music
	MusicManager.play_song("level1")
	print("Switching to level music: level1")
	
	# **EMIT THE SIGNAL BEFORE REMOVING THE CUTSCENE**
	cutscene_finished.emit()
	
	# Remove cutscene
	queue_free()


func _on_text_container_input(event: InputEvent) -> void:
	"""Handle clicks on text container"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not in_summary and not is_transitioning and not waiting_for_text_delay:
				complete_current_text()


func _on_summary_container_input(event: InputEvent) -> void:
	"""Handle clicks on summary container"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if in_summary and continue_button.visible:
				proceed_to_game()

func delayed_action(delay: float, action: Callable) -> void:
	await get_tree().create_timer(delay).timeout
	action.call()

func _on_skip_pressed() -> void:
	delayed_action(0.2, func():
		#cutscene_paused = true
		background.visible = false
		#text_container.visible = false
		show_summary()
	)


func _on_continue_pressed() -> void:
	proceed_to_game()


func _on_cancel_pressed() -> void:
	delayed_action(0.2, func():
		cutscene_paused = false  
		skip_cutscene.visible = false 
	)


func _on_skip_button_pressed() -> void:
	delayed_action(0.2, func():
		cutscene_paused = true
		skip_cutscene.visible = true
	)
