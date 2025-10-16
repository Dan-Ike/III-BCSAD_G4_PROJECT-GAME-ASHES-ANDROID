extends Node2D

@onready var player_camera = $player/Camera2D
@onready var camera_2d_2 = $player/Camera2D2
@onready var scene_transition_animation = $SceneTransitionAnimation/AnimationPlayer
@onready var spike_collision = $spike_collision
@onready var cutscene: CanvasLayer = $Cutscene
@onready var player: Player = $player
@onready var loading_screen: CanvasLayer = $loading  # Add this node to your scene

func _ready() -> void:
	# Set current floor and level in Global
	Global.set_floor_level(1, 1)
	
	# Hide loading screen initially (it was shown during scene load)
	if loading_screen:
		loading_screen.visible = false
	
	# Check if cutscene should play
	var should_play_cutscene = _should_show_cutscene()
	
	if should_play_cutscene:
		# Start with cutscene - everything disabled
		player_camera.enabled = false
		camera_2d_2.enabled = true
		# Don't stop or play music here - let cutscene handle it
		
		# Show and start cutscene with unique ID
		cutscene.visible = true
		cutscene.start_cutscene("floor_1_level_1_prologue")
	else:
		# Skip cutscene - go straight to gameplay
		get_tree().paused = false 
		player_camera.enabled = true
		camera_2d_2.enabled = true
		MusicManager.play_song("level1")
		
		# Remove cutscene node
		if cutscene:
			cutscene.queue_free()
	
	Global.set_retrying(false)

func _should_show_cutscene() -> bool:
	"""Determine if cutscene should play based on user preference"""
	var cutscene_pref = SaveManager.get_setting("cutscene_preference")
	
	# Default to "play_once" if not set
	if cutscene_pref == null:
		cutscene_pref = "play_once"
	
	if cutscene_pref == "always":
		# Always play cutscene when entering this level (but not on retry/death)
		return not Global.is_retrying_level
	elif cutscene_pref == "play_once":
		# Only play if never watched before
		return not SaveManager.has_watched_cutscene("floor_1_level_1_prologue")
	
	return false

func _process(delta: float) -> void:
	pass

func _on_floor_1_lvl_2_body_entered(body: Node2D) -> void:
	if body is Player:
		Global.gameStarted = true
		Global.is_retrying_level = false  # Reset retry flag when advancing
		unlock_dash()
		SaveManager.mark_level_completed(1, 1) 
		SaveManager.advance_to_level(1, 2)
		
		var user_id = Global.get_current_user().get("id", "")
		if user_id != "":
			await SaveManager.sync_from_supabase(user_id)
		
		# Update Global to next level
		Global.advance_level()
		
		body.touch_controls.disable_all_controls() 
		scene_transition_animation.play("fade_in")
		await get_tree().create_timer(0.5).timeout
		
		# Show loading screen and load next level
		if loading_screen:
			loading_screen.start_loading("res://scene/floor_1_level_2.tscn")
		else:
			get_tree().change_scene_to_file("res://scene/floor_1_level_2.tscn")

func unlock_double_jump():
	Global.can_double_jump = true
	SaveManager.unlock_ability("double_jump")

func unlock_attack():
	Global.touchatk = true
	SaveManager.unlock_ability("attack")
	var controls = get_tree().root.get_node("TouchControls")
	if controls:
		controls.show_attack_button()

func unlock_dash():
	Global.touchdash = true
	SaveManager.unlock_ability("dash")
	var controls = get_tree().root.get_node("TouchControls")
	if controls:
		controls.show_dash_button()

func _on_spike_collision_body_entered(body: Node2D) -> void:
	if body is Player and body.can_take_damage:
		# Mark that player is retrying (died), so cutscene won't replay
		Global.is_retrying_level = true
		body.take_damage(Global.spikeDamageAmount)
