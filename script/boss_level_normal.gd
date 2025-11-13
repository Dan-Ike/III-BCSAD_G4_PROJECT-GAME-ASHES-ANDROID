extends Node2D
@onready var player_camera = $player/Camera2D
@onready var camera_2d_2 = $player/Camera2D2
@onready var scene_transition_animation = $SceneTransitionAnimation/AnimationPlayer
@onready var before_boss_normal: CanvasLayer = $before_boss_normal
@onready var bad_ending: CanvasLayer = $bad_ending
@onready var good_ending: CanvasLayer = $good_ending
@onready var advanced_enemy: CharacterBody2D = $AdvancedEnemy
@onready var player: Player = $player

var boss_defeated: bool = false
var player_defeated: bool = false
var ending_playing: bool = false

func _ready() -> void:
	Global.set_floor_level(3, 2)
	unlock_attack()
	unlock_dash()
	unlock_double_jump()
	unlock_shine()
	scene_transition_animation.get_parent().get_node("ColorRect").color.a = 255
	scene_transition_animation.play("fade_out")
	
	# Reset flags on scene load
	boss_defeated = false
	player_defeated = false
	ending_playing = false
	
	# Hide all ending cutscenes initially
	if bad_ending:
		bad_ending.visible = false
	if good_ending:
		good_ending.visible = false
	
	# Connect to boss death signal - make sure to disconnect first if reconnecting
	if advanced_enemy:
		# Disconnect if already connected (safety check for hot reload)
		if advanced_enemy.tree_exited.is_connected(_on_boss_defeated):
			advanced_enemy.tree_exited.disconnect(_on_boss_defeated)
		advanced_enemy.tree_exited.connect(_on_boss_defeated)
		
		# Make sure boss is enabled and can take damage
		advanced_enemy.set_physics_process(true)
		advanced_enemy.set_process(true)
	
	if player:
		# Disconnect if already connected (safety check)
		if player.player_died.is_connected(_on_player_died):
			player.player_died.disconnect(_on_player_died)
		player.player_died.connect(_on_player_died)
		
		# Make sure player is enabled
		player.set_physics_process(true)
		player.set_process_input(true)
	
	# Check if cutscene should play
	var should_play_cutscene = false #_should_show_cutscene()
	
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
		_show_boss_health_bar() 
		
		# Remove cutscene node since we're not using it
		if before_boss_normal:
			before_boss_normal.queue_free()
	
	Global.set_retrying(false)

func _show_boss_health_bar() -> void:
	"""Show the boss health bar after 3 seconds"""
	print("[Boss Level] Attempting to show boss health bar...")
	
	# Wait a frame to ensure everything is loaded
	await get_tree().process_frame
	
	# Find TouchControls in the current scene tree
	var touch_controls = get_tree().get_first_node_in_group("touch_controls")
	
	# If not found by group, try finding by type
	if not touch_controls:
		touch_controls = get_node_or_null("TouchControls")
	
	# Last resort: search through all CanvasLayer nodes
	if not touch_controls:
		for node in get_tree().get_nodes_in_group(""):
			if node.name == "TouchControls" or node.get_script() and node.get_script().resource_path.contains("touch_controls"):
				touch_controls = node
				break
	
	if not touch_controls:
		print("[Boss Level] ERROR: TouchControls not found in scene tree!")
		return
	
	print("[Boss Level] TouchControls found!")
	
	# Access hud_boss and health_bar_boss directly
	if not touch_controls.hud_boss:
		print("[Boss Level] ERROR: hud_boss not found!")
		return
	
	if not touch_controls.health_bar_boss:
		print("[Boss Level] ERROR: health_bar_boss not found!")
		return
	
	print("[Boss Level] Found boss health bar components!")
	
	await get_tree().create_timer(3.0).timeout
	touch_controls.hud_boss.visible = true
	touch_controls.health_bar_boss.visible = true
	print("[Boss Level] Boss health bar now visible!")

func unlock_double_jump():
	Global.can_double_jump = true
	SaveManager.unlock_ability("double_jump")

func unlock_attack():
	Global.touchatk = true
	SaveManager.unlock_ability("attack")
	var controls = get_tree().root.get_node("TouchControls")
	if controls:
		controls.show_attack_button()

func unlock_shine():
	Global.unlock_shine()
	print("[Floor 2-1] Shine ability unlocked!")

func unlock_dash():
	Global.touchdash = true
	SaveManager.unlock_ability("dash")
	var controls = get_tree().root.get_node("TouchControls")
	if controls:
		controls.show_dash_button()

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
		
		# Safety check before continuing
		if not is_inside_tree():
			return
		
		# Make sure other cutscenes are hidden
		if before_boss_normal:
			before_boss_normal.visible = false
			before_boss_normal.set_process(false)
			before_boss_normal.set_process_input(false)
		if good_ending:
			good_ending.visible = false
			good_ending.set_process(false)
			good_ending.set_process_input(false)
		
		# Play bad ending cutscene
		if bad_ending:
			bad_ending.visible = true
			bad_ending.start_cutscene("floor_3_level_2_bad_ending")
	else:
		# Let the normal game over screen play
		ending_playing = false

func _retry_boss_fight() -> void:
	"""Retry the boss fight after bad ending"""
	print("[Boss Level] Retrying boss fight...")
	
	# Reset flags
	boss_defeated = false
	player_defeated = false
	ending_playing = false
	
	# Set retry flag
	Global.is_retrying_level = true
	get_tree().paused = false
	
	# Fade and reload
	scene_transition_animation.play("fade_in")
	await scene_transition_animation.animation_finished
	get_tree().reload_current_scene()

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
	# Safety check for tree
	if not is_inside_tree():
		return
	
	get_tree().paused = false
	scene_transition_animation.play("fade_in")
	await get_tree().create_timer(1.0).timeout
	
	# Check again before changing scene
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scene/main_menu.tscn")

func _process(delta: float) -> void:
	pass
