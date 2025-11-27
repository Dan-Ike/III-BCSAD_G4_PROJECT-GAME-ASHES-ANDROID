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
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/NEW VERSION/bad ending/f01 - new.png",
		"texts": [
			"\"I reached the edge. I said nothing.\""
		]
	},
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/NEW VERSION/bad ending/f02 - new.png",
		"texts": [
			"\"She didn't ask for forgiveness. She waited. I gave her silence.\""
		]
	},
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/NEW VERSION/bad ending/f03 - new.png",
		"texts": [
			"\"I didn't carry guilt. I buried it.\""
		]
	},
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/NEW VERSION/bad ending/f04 - new.png",
		"texts": [
			"\"There was no heaven. No fire. Just forgetting\""
		]
	},
	{
		"background": "res://CUTSCENES - ASHES-20251012T022412Z-1-001/CUTSCENES - ASHES/NEW VERSION/bad ending/f05 - new.png",
		"texts": [
			"\"The tower didn't punish me. It let me repeat.\""
		]
	}
]

var summary_data = {
	"title": "Story Summary",
	"text": "I arrived at the end without words. She waited, not for forgiveness, but for my silence—and I gave it. I didn't feel guilt; I buried it. There was no salvation or damnation, only oblivion. The tower didn't condemn me—it allowed me to relive it all."
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

# Track cutscene ID for "play once" mode
var cutscene_id: String = ""

func _ready() -> void:
	# Set process mode to work when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	skip_cutscene.visible = false
	bg_2.visible = false
	skip_button.hide()
	continue_button.hide()
	summary_container_2.hide()
	text_container.hide()
	text_container.modulate.a = 0.0
	
	continue_button.pressed.connect(_on_continue_pressed)
	skip_button.pressed.connect(_on_skip_button_pressed)
	cancel.pressed.connect(_on_cancel_pressed)
	exit.pressed.connect(_on_skip_pressed)

func _input(event: InputEvent) -> void:
	"""Handle screen clicks anywhere"""
	if cutscene_paused: 
		return
	
	if event is InputEventScreenTouch and event.pressed:
		# For TouchScreenButtons, we can't easily check if they were clicked
		# So we'll just let them handle their own input via their pressed signals
		# and handle screen taps for advancing text
		
		# Anywhere on screen advances text (buttons will handle themselves via signals)
		if not in_summary and not is_transitioning and not waiting_for_text_delay:
			complete_current_text()
		elif in_summary and continue_button.visible:
			proceed_to_game()
		
		get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Check if clicking on continue button (regular Button, not TouchScreenButton)
			if continue_button.visible and continue_button.get_global_rect().has_point(event.position):
				return
			
			# Anywhere else on screen advances text
			if not in_summary and not is_transitioning and not waiting_for_text_delay:
				complete_current_text()
			elif in_summary and continue_button.visible:
				proceed_to_game()
			
			get_viewport().set_input_as_handled()

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
	if Input.is_action_just_pressed("ui_accept") and not cutscene_paused:
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
			cutscene_finished.emit()
			queue_free()
			return
	
	print("[Cutscene] Starting bad ending cutscene")
	Global.cutscene_playing = true
	
	# Play cutscene music
	MusicManager.play_song("menu")
	print("Cutscene music started: menu")
	
	# DON'T pause the game - let it stay unpaused from game_over
	# get_tree().paused = true  ← REMOVED
	
	if cutscene_data.size() > 0:
		show_scene(0, 0)

func show_scene(scene_index: int, text_index: int) -> void:
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
			
			# Cache tree reference
			var tree = get_tree()
			if tree:
				await tree.create_timer(fade_duration * 2).timeout
			
			waiting_for_text_delay = true
			text_delay_timer = 0.0
			return
	else:
		# Same background - just update text
		if is_first_text_of_scene:
			waiting_for_text_delay = true
			text_delay_timer = 0.0
		else:
				# Not first text - show immediately with typing
			text_container.show()
			text_container.modulate.a = 1.0
			displayed_text = ""  # Reset displayed text
			text_label.text = ""  # Clear label
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
	
	displayed_text = ""
	text_label.text = ""
	
	is_typing = true 
	typing_timer = 0.0
	
	print("Starting text fade in with text: ", current_text)

func complete_current_text() -> void:
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
			
			# Cache tree reference
			var tree = get_tree()
			if tree:
				await tree.create_timer(text_fade_duration).timeout
			
			show_scene(current_scene_index + 1, 0)

func show_summary() -> void:
	background.visible = false
	color_rect.visible = false
	bg_2.visible = true
	in_summary = true
	
	_start_text_fade_out()
	skip_button.hide()
	
	# Cache tree reference
	var tree = get_tree()
	if tree:
		await tree.create_timer(text_fade_duration).timeout
	
	text_container.visible = false
	
	summary_text.text = summary_data["text"]
	summary_container_2.show()
	
	continue_timer = 0.0

# --- Function in bad_ending.gd ---

func proceed_to_game() -> void:
	Global.cutscene_playing = false
	
	if cutscene_id != "":
		SaveManager.mark_cutscene_watched(cutscene_id)
	
	MusicManager.stop_song()
	
	var tree = get_tree()
	if not tree:
		return
	
	# EMIT SIGNAL
	cutscene_finished.emit()
	
	# 🛑 FIX for Redirection Failure: Remove timing delay and free self after scene change.
	Global.reset_progress()
	
	# Request scene change
	var error = tree.change_scene_to_file("res://scene/main_menu.tscn")
	
	if error != OK:
		print("ERROR: Failed to change scene to main_menu.tscn: ", error)
		return
		
	# Queue the Cutscene node for removal immediately after the scene change is initiated
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
	var tree = get_tree()
	if tree:
		await tree.create_timer(delay).timeout
		action.call()

func _on_skip_pressed() -> void:
	delayed_action(0.2, func():
		cutscene_paused = false  # Reset pause state when skipping
		skip_cutscene.visible = false  # Hide the skip dialog
		
		# Fade out text first
		_start_text_fade_out()
		
		# Wait for fade to complete before showing summary
		var tree = get_tree()
		if tree:
			await tree.create_timer(text_fade_duration).timeout
		
		background.visible = false
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
