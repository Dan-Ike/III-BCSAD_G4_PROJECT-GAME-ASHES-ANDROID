extends Node2D
@onready var player_camera = $player/Camera2D
@onready var camera_2d_2 = $player/Camera2D2
@onready var scene_transition_animation = $SceneTransitionAnimation/AnimationPlayer
@onready var before_boss_normal: CanvasLayer = $before_boss_normal
@onready var bad_ending: CanvasLayer = $bad_ending
@onready var good_ending: CanvasLayer = $good_ending
@onready var advanced_enemy: AdvancedEnemy = $AdvancedEnemy
@onready var player: Player = $player


var boss_defeated: bool = false
var player_defeated: bool = false
var ending_playing: bool = false

func _ready() -> void:
	Global.set_floor_level(3, 1)
	
	scene_transition_animation.get_parent().get_node("ColorRect").color.a = 255
	scene_transition_animation.play("fade_out")
	
	# Hide all ending cutscenes initially
	if bad_ending:
		bad_ending.visible = false
	if good_ending:
		good_ending.visible = false
	
	# Connect to boss death signal
	if advanced_enemy:
		advanced_enemy.tree_exited.connect(_on_boss_defeated)
	
	# Connect to player death - override the player's death behavior for this level
	if player:
		player.player_died.connect(_on_player_died)
	
	# Check if cutscene should play
	var should_play_cutscene = _should_show_cutscene()
	
	if should_play_cutscene:
		# Start with cutscene - cameras for cutscene mode
		player_camera.enabled = false
		camera_2d_2.enabled = true
		
		# Show and start cutscene with unique ID
		before_boss_normal.visible = true
		before_boss_normal.start_cutscene("floor_3_level_2_prologue")
	else:
		# Skip cutscene - go straight to gameplay
		player_camera.enabled = true
		camera_2d_2.enabled = true
		get_tree().paused = false
		MusicManager.play_song("boss")
		
		# Remove cutscene node since we're not using it
		if before_boss_normal:
			before_boss_normal.queue_free()
	
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
		return not SaveManager.has_watched_cutscene("floor_3_level_2_prologue")
	
	return false

func _on_boss_defeated() -> void:
	"""Called when boss is defeated/killed"""
	if boss_defeated or ending_playing:
		return
	
	boss_defeated = true
	ending_playing = true
	
	print("[Boss Level] Boss defeated! Playing good ending...")
	
	# Disable player controls
	if player:
		player.set_physics_process(false)
		player.set_process_input(false)
		player.velocity = Vector2.ZERO
		if player.has_node("../CanvasLayer"):
			var touch_controls = player.get_node("../CanvasLayer")
			if touch_controls:
				touch_controls.disable_all_controls()
	
	# Mark level as completed
	SaveManager.mark_level_completed(3, 1)  
	SaveManager.advance_to_level(3, 2)
	
	# Wait a moment for dramatic effect
	#await get_tree().create_timer(1.0).timeout
	
	# Check if we should play the good ending cutscene
	var should_play_ending = _should_show_ending_cutscene("good")
	
	if should_play_ending:
		# Play good ending cutscene
		good_ending.visible = true
		good_ending.start_cutscene("floor_3_level_2_good_ending")
	else:
		# Skip cutscene, go directly to main menu
		_return_to_main_menu()

func _on_player_died() -> void:
	"""Called when player dies to the boss"""
	if player_defeated or ending_playing:
		return
	
	player_defeated = true
	ending_playing = true
	
	print("[Boss Level] Player died! Checking bad ending cutscene...")
	
	# Check if we should play the bad ending cutscene
	var should_play_ending = _should_show_ending_cutscene("bad")
	
	if should_play_ending:
		# Cancel the normal game over screen
		# Stop the player's death animation at a good point
		await get_tree().create_timer(1.5).timeout
		
		# Play bad ending cutscene
		if bad_ending:
			bad_ending.visible = true
			bad_ending.start_cutscene("floor_3_level_2_bad_ending")
	else:
		# Let the normal game over screen play
		# The player's handle_death_animation will continue normally
		ending_playing = false

func _should_show_ending_cutscene(ending_type: String) -> bool:
	"""Determine if ending cutscene should play based on user preference"""
	var cutscene_pref = SaveManager.get_setting("cutscene_preference")
	
	# Default to "play_once" if not set
	if cutscene_pref == null:
		cutscene_pref = "play_once"
	
	var cutscene_id = "floor_3_level_2_" + ending_type + "_ending"
	
	if cutscene_pref == "always":
		# Always play ending cutscenes
		return true
	elif cutscene_pref == "play_once":
		# Only play if never watched before
		return not SaveManager.has_watched_cutscene(cutscene_id)
	
	return false

func _return_to_main_menu() -> void:
	"""Return to main menu after good ending"""
	get_tree().paused = false
	scene_transition_animation.play("fade_in")
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")

func _retry_boss_fight() -> void:
	"""Retry the boss fight after bad ending"""
	Global.is_retrying_level = true
	get_tree().paused = false
	scene_transition_animation.play("fade_in")
	await get_tree().create_timer(0.5).timeout
	get_tree().reload_current_scene()

func _process(delta: float) -> void:
	pass
