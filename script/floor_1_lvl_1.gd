extends Node2D

@onready var player_camera = $player/Camera2D
@onready var camera_2d_2 = $player/Camera2D2
@onready var scene_transition_animation = $SceneTransitionAnimation/AnimationPlayer
@onready var spike_collision = $spike_collision
@onready var cutscene: CanvasLayer = $Cutscene
@onready var player: Player = $player
@onready var loading_screen: CanvasLayer = $loading  
@onready var touch_controls: CanvasLayer = $TouchControls
@onready var floor_title: CanvasLayer = $FloorTitle

@onready var tutorial_manager: Node = $TutorialManager if has_node("TutorialManager") else null


func _ready() -> void:
	#SaveManager.reset_tutorial()
	MusicManager.play_song("level1")
	Global.reset_game_over_flag()
	Global.set_floor_level(1, 1)
	
	if loading_screen:
		loading_screen.visible = false
	
	var should_play_cutscene = _should_show_cutscene()
	
	if should_play_cutscene:
		if player.has_node("../CanvasLayer"):
			var touch_controls_node = player.get_node("../CanvasLayer")
			if touch_controls_node:
				touch_controls_node.disable_all_controls()
		
		player_camera.enabled = false
		camera_2d_2.enabled = true
		cutscene.visible = true
		cutscene.start_cutscene("floor_1_level_1_prologue")
		
		# Wait for cutscene to finish, then show floor title
		await cutscene.cutscene_finished
		_show_floor_title_then_start()
	else:
		# No cutscene - show floor title immediately
		_show_floor_title_then_start()
	
	Global.set_retrying(false)

func _show_floor_title_then_start() -> void:
	# Show floor title (pauses game)
	floor_title.show_title()
	await floor_title.title_finished
	
	# Now start gameplay
	get_tree().paused = false
	player_camera.enabled = true
	camera_2d_2.enabled = true
	MusicManager.play_song("level1")
	
	# Start player timer AFTER floor title finishes
	player.reset_level_timer()
	
	if tutorial_manager:
		print("[Level] Calling tutorial manager...")
		tutorial_manager.check_and_start_tutorial()
	
	if cutscene:
		cutscene.queue_free()

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
		# Get time FIRST before stopping
		var time_cleared = body._get_elapsed_time()
		body.stop_level_timer()
		
		print("[Level] Player completed Floor %d, Level %d in %.2f seconds" % [Global.current_floor, Global.current_level, time_cleared])
		
		# Save progress
		Global.gameStarted = true
		Global.is_retrying_level = false
		unlock_dash()
		SaveManager.mark_level_completed(1, 1)
		SaveManager.advance_to_level(1, 2)
		
		# Disable touch controls
		if touch_controls:
			touch_controls.disable_all_controls()
		
		# Show level completed screen
		var game_over_scene = preload("res://scene/game_over.tscn")
		var game_over = game_over_scene.instantiate()
		get_tree().root.add_child(game_over)
		if game_over.has_method("show_game_over"):
			game_over.show_game_over(Global.current_floor, Global.current_level, time_cleared, true)

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
