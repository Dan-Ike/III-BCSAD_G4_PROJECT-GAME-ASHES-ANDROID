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


# Cutscene data structure - Multiple texts per background
var cutscene_data = [
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/7 - 3.3 -20260404T080448Z-3-001/7 - 3.3/3.3 - f01.jpg",
		"texts": [
			"Memories are regained, yet the flame still burns."
		]
	},
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/7 - 3.3 -20260404T080448Z-3-001/7 - 3.3/3.3 - f02.jpg",
		"texts": [
			"Yet strangely, it feels cold."
		]
	},
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/7 - 3.3 -20260404T080448Z-3-001/7 - 3.3/3.3 - f03.jpg",
		"texts": [
			"The end, yes, You feel that the end is within the next challenge."
		]
	},
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/7 - 3.3 -20260404T080448Z-3-001/7 - 3.3/3.3 - f04.jpg",
		"texts": [
			"All the enemies slain, traps and quests completed."
		]
	},
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/7 - 3.3 -20260404T080448Z-3-001/7 - 3.3/3.3 - f05.jpg",
		"texts": [
			"Leads at this end."
		]
	},
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/7 - 3.3 -20260404T080448Z-3-001/7 - 3.3/3.3 - f06.jpg",
		"texts": [
			"Strangely the voice in your head seems to be quiet."
		]
	},
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/7 - 3.3 -20260404T080448Z-3-001/7 - 3.3/3.3 - f07.jpg",
		"texts": [
			"..."
		]
	},
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/7 - 3.3 -20260404T080448Z-3-001/7 - 3.3/3.3 - f08.jpg",
		"texts": [
			"\"The final fight indeed, prove your repentance, defeat your past self and accept who you are, mortal\""
		]
	},
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/7 - 3.3 -20260404T080448Z-3-001/7 - 3.3/3.3 - f09.jpg",
		"texts": [
			"The door opens and you fall."
		]
	}
]

var summary_data = {
	"title": "Story Summary",
	"text": "With his memories restored, Dante nears the end. The guiding voice falls silent until it declares his final trial: to defeat his past self and accept who he truly is. He steps forward into the final confrontation."
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
	# Use PROCESS_MODE_ALWAYS so the script continues even if game is paused by get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS 
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
	exit.pressed.connect(_on_skip_pressed) # Connect the Exit button in the skip menu
	skip_button.pressed.connect(_on_skip_button_pressed) # Connect the initial Skip button


func _input(event: InputEvent) -> void:
	"""Handle screen clicks anywhere"""
	if cutscene_paused:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Only allow advancement if we are not in the summary or skip mode
			if not in_summary and not is_transitioning and not waiting_for_text_delay:
				complete_current_text()
			elif in_summary and continue_button.visible:
				# This handles click-to-continue in the summary screen
				proceed_to_game()
			
			get_tree().root.set_input_as_handled()

func _process(delta: float) -> void:
	# If we are in the summary screen, handle the continue button timer
	if in_summary:
		if not continue_button.visible:
			continue_timer += delta
			if continue_timer >= show_continue_after:
				continue_button.show()
		return # EXIT _process if in_summary or paused
	
	if cutscene_paused:
		return # EXIT _process if paused
	
	# --- Background Fade Logic ---
	if fading_out or fading_in:
		fade_timer += delta
		var progress = clamp(fade_timer / fade_duration, 0.0, 1.0)
		
		if fading_out:
			background.modulate.a = 1.0 - progress
			if progress >= 1.0:
				fading_out = false
				if next_background_path != "":
					var texture = load(next_background_path)
					if texture:
						background.texture = texture
						current_background_path = next_background_path
				fading_in = true
				fade_timer = 0.0
		
		elif fading_in:
			background.modulate.a = progress
			if progress >= 1.0:
				fading_in = false
				is_transitioning = false
				background.modulate.a = 1.0
	
	# --- Text Delay Logic ---
	if waiting_for_text_delay:
		text_delay_timer += delta
		if text_delay_timer >= text_delay_duration:
			waiting_for_text_delay = false
			text_delay_timer = 0.0
			_start_text_fade_in()
	
	# --- Text Fade Logic ---
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
	
	# --- MANUAL ADVANCE (ui_accept) ---
	if Input.is_action_just_pressed("ui_accept") and not cutscene_paused:
		if in_summary:
			if continue_button.visible:
				proceed_to_game()
		else:
			if not is_transitioning and not waiting_for_text_delay:
				complete_current_text()
	
	# --- Typing Logic ---
	if is_typing:
		typing_timer += delta
		if typing_timer >= typing_speed:
			typing_timer = 0.0
			if displayed_text.length() < current_text.length():
				displayed_text += current_text[displayed_text.length()]
				text_label.text = displayed_text
			
			if displayed_text.length() >= current_text.length():
				is_typing = false
	
	# --- Skip Button Timer ---
	if not in_summary and not skip_button.visible:
		skip_timer += delta
		if skip_timer >= show_skip_after:
			skip_button.show()
	


func start_cutscene(id: String = "") -> void:
	cutscene_id = id
	
	var cutscene_pref = SaveManager.get_setting("cutscene_preference")
	
	if cutscene_pref == "play_once" and cutscene_id != "":
		if SaveManager.has_watched_cutscene(cutscene_id):
			print("[Cutscene] Already watched, skipping...")
			cutscene_finished.emit()
			queue_free()
			return
	
	print("[Cutscene] Starting cutscene playback")
	Global.cutscene_playing = true
	
	MusicManager.play_song("menu")
	print("Cutscene music started: menu")
	
	# PAUSE THE GAME AND DISABLE INPUTS
	if player and player.has_node("../CanvasLayer"):
		var touch_controls = player.get_node("../CanvasLayer")
		if touch_controls and touch_controls.has_node("Control/Control6/pause"):
			var pause_btn = touch_controls.get_node("Control/Control6/pause")
			if pause_btn.pressed.is_connected(touch_controls._on_pause_pressed):
				pause_btn.pressed.disconnect(touch_controls._on_pause_pressed)
	
	_pause_player()
	get_tree().paused = true # This pauses the rest of the game scene
	
	if cutscene_data.size() > 0:
		show_scene(0, 0)


func _pause_player() -> void:
	if player:
		player.set_physics_process(false)
		player.set_process_input(false)
		player.velocity = Vector2.ZERO
		
		if player.has_node("../CanvasLayer"):
			var touch_controls = player.get_node("../CanvasLayer")
			if touch_controls:
				touch_controls.disable_all_controls()


func _unpause_player() -> void:
	get_tree().paused = false
	
	if player:
		player.set_physics_process(true)
		player.set_process_input(true)
		
		if player.has_node("../CanvasLayer"):
			var touch_controls = player.get_node("../CanvasLayer")
			if touch_controls:
				touch_controls.enable_pause()
				touch_controls.visible = true
				touch_controls.set_process(true)
				touch_controls.set_block_signals(false)


func show_scene(scene_index: int, text_index: int) -> void:
	if in_summary: # Prevent running scene logic if skip was initiated
		return

	if scene_index >= cutscene_data.size():
		show_summary()
		return
	
	current_scene_index = scene_index
	current_text_index = text_index
	var scene = cutscene_data[scene_index]
	
	var texts = scene.get("texts", [])
	if text_index >= texts.size():
		show_scene(scene_index + 1, 0)
		return
	
	current_text = texts[text_index]
	displayed_text = ""
	text_label.text = ""
	
	print("show_scene called - Scene: %d, Text: %d, Content: %s" % [scene_index, text_index, current_text])
	
	var new_background = scene.get("background", "")
	var is_first_text_of_scene = (text_index == 0)
	var background_changed = (new_background != current_background_path)
	
	if new_background != "" and background_changed:
		if current_background_path == "":
			var texture = load(new_background)
			if texture:
				background.texture = texture
				current_background_path = new_background
			background.modulate.a = 1.0
			
			waiting_for_text_delay = true
			text_delay_timer = 0.0
		else:
			_start_text_fade_out()
			
			is_transitioning = true
			fading_out = true
			fading_in = false
			fade_timer = 0.0
			next_background_path = new_background
			
			await get_tree().create_timer(fade_duration * 2).timeout
			
			if in_summary: # CRITICAL CHECK AFTER AWAIT
				return
			
			waiting_for_text_delay = true
			text_delay_timer = 0.0
			return
	else:
		if is_first_text_of_scene:
			waiting_for_text_delay = true
			text_delay_timer = 0.0
		else:
			text_container.show()
			text_container.modulate.a = 1.0
			is_typing = true
			typing_timer = 0.0


func _start_text_fade_out() -> void:
	if text_container.visible:
		text_fading_out = true
		text_fading_in = false
		text_fade_timer = 0.0


func _start_text_fade_in() -> void:
	if in_summary:
		return
		
	text_container.show()
	text_container.modulate.a = 0.0
	text_fading_in = true
	text_fading_out = false
	text_fade_timer = 0.0
	
	displayed_text = ""
	text_label.text = ""
	
	is_typing = true
	typing_timer = 0.0
	
	print("Starting text fade in with text: ", current_text)


func complete_current_text() -> void:
	if in_summary or cutscene_paused:
		return
	
	if is_transitioning or waiting_for_text_delay:
		return
		
	if is_typing:
		displayed_text = current_text
		text_label.text = displayed_text
		is_typing = false
	else:
		var scene = cutscene_data[current_scene_index]
		var texts = scene.get("texts", [])
		
		if current_text_index + 1 < texts.size():
			show_scene(current_scene_index, current_text_index + 1)
		else:
			is_transitioning = true
			_start_text_fade_out()
			
			await get_tree().create_timer(text_fade_duration).timeout
			
			if in_summary: # CRITICAL CHECK AFTER AWAIT
				return
			
			show_scene(current_scene_index + 1, 0)


func show_summary() -> void:
	if in_summary:
		return
		
	in_summary = true # Set the summary flag immediately
	
	# Stop all active transitions and flags
	is_typing = false
	is_transitioning = false
	waiting_for_text_delay = false
	fading_out = false
	fading_in = false
	text_fading_out = false
	text_fading_in = false
	
	background.visible = false
	color_rect.visible = false
	bg_2.visible = true
	
	_start_text_fade_out()
	skip_button.hide()
	
	await get_tree().create_timer(text_fade_duration).timeout
	
	if not in_summary:
		return

	text_container.visible = false
	
	summary_text.text = summary_data["text"]
	summary_container_2.show()
	
	# Reset timer for continue button display
	continue_timer = 0.0

func proceed_to_game() -> void:
	# Halt this script's processing loop completely
	set_process(false) 
	
	Global.cutscene_playing = false
	
	var level_node = get_parent()
	if level_node.has_node("player"):
		var player = level_node.get_node("player")
		if player.has_method("reset_level_timer"):
			player.reset_level_timer()
	
	if cutscene_id != "":
		SaveManager.mark_cutscene_watched(cutscene_id)
	
	_unpause_player()
	
	# Handle enabling cameras/music
	if level_node.has_node("player/Camera2D"):
		level_node.get_node("player/Camera2D").enabled = true
	if level_node.has_node("player/Camera2D2"):
		level_node.get_node("player/Camera2D2").enabled = true
	
	MusicManager.play_song("level1")
	print("Switching to level music: level1")
	
	cutscene_finished.emit()
	
	queue_free()


func _on_text_container_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not in_summary and not is_transitioning and not waiting_for_text_delay:
				complete_current_text()


func _on_summary_container_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if in_summary and continue_button.visible:
				proceed_to_game()

func delayed_action(delay: float, action: Callable) -> void:
	await get_tree().create_timer(delay).timeout
	action.call()

func _on_skip_pressed() -> void:
	"""
	Called when pressing the Exit button in the skip confirmation menu.
	The cascade is controlled by the 'in_summary' flag and 'await' checks.
	We must NOT stop the process here, otherwise the continue timer won't run.
	"""
	print("========== _ON_SKIP_PRESSED CALLED (Finalizing) ==========")
	
	# 1. Show the summary. This sets in_summary = true.
	show_summary()
	
	# 2. Hide the skip menu.
	cutscene_paused = false
	skip_cutscene.visible = false


func _on_continue_pressed() -> void:
	proceed_to_game()


func _on_cancel_pressed() -> void:
	delayed_action(0.2, func():
		cutscene_paused = false
		skip_cutscene.visible = false
	)


func _on_skip_button_pressed() -> void:
	delayed_action(0.2, func():
		print("========== _ON_SKIP_PRESSED CALLED ==========")
		cutscene_paused = true
		skip_cutscene.visible = true
	)
