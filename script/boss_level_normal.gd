extends Node2D

@onready var player_camera = $player/Camera2D
@onready var camera_2d_2 = $player/Camera2D2
@onready var scene_transition_animation = $SceneTransitionAnimation/AnimationPlayer
@onready var advanced_enemy: CharacterBody2D = $AdvancedEnemy
@onready var player: Player = $player
@onready var floor_title: CanvasLayer = $FloorTitle
@onready var before_boss_normal: CanvasLayer = $before_boss_normal
#@onready var bad_ending: CanvasLayer = $bad_ending
#@onready var good_ending: CanvasLayer = $good_ending



var boss_defeated: bool = false
var player_defeated: bool = false

func _ready() -> void:
	Global.reset_game_over_flag()
	Global.set_floor_level(3, 3)
	unlock_attack()
	unlock_dash()
	unlock_double_jump()
	unlock_shine()
	
	# Reset flags on scene load
	boss_defeated = false
	player_defeated = false
	
	# Start fade in animation FIRST
	if scene_transition_animation:
		scene_transition_animation.get_parent().get_node("ColorRect").color.a = 255
		scene_transition_animation.play("fade_out")
	
	# Connect to boss death signal
	if advanced_enemy:
		if advanced_enemy.tree_exited.is_connected(_on_boss_defeated):
			advanced_enemy.tree_exited.disconnect(_on_boss_defeated)
		advanced_enemy.tree_exited.connect(_on_boss_defeated)
		advanced_enemy.set_physics_process(true)
		advanced_enemy.set_process(true)
	
	if player:
		if player.player_died.is_connected(_on_player_died):
			player.player_died.disconnect(_on_player_died)
		player.player_died.connect(_on_player_died)
		player.set_physics_process(true)
		player.set_process_input(true)
	
	# --- CUTSCENE / GAME START LOGIC ---
	var should_play_cutscene = _should_show_cutscene()
	
	if should_play_cutscene:
		print("[Boss Level] Playing before_boss_normal cutscene...")
		
		# Pause scene components that shouldn't move during cutscene
		player_camera.enabled = false
		floor_title.visible = false 
		
		before_boss_normal.visible = true
		before_boss_normal.start_cutscene("floor_3_level_3_prologue")
		
		# Wait for cutscene to finish, then show floor title
		await before_boss_normal.cutscene_finished
		
		# Check if the level state changed while waiting (e.g., player skipped, then quit/died)
		if not boss_defeated and not player_defeated:
			_show_floor_title_then_start()
		else:
			# Cleanup if something happened during the wait (just in case)
			if before_boss_normal and is_instance_valid(before_boss_normal):
				before_boss_normal.queue_free()
	else:
		# No cutscene - show floor title immediately
		_show_floor_title_then_start()
	
	Global.set_retrying(false)

func _should_show_cutscene() -> bool:
	"""Determine if cutscene should play based on user preference and retry status"""
	var cutscene_pref = SaveManager.get_setting("cutscene_preference")
	
	if cutscene_pref == null:
		cutscene_pref = "play_once"
	
	if cutscene_pref == "always":
		# Always play cutscene unless retrying (re-entering after death)
		return not Global.is_retrying_level
	elif cutscene_pref == "play_once":
		# Only play if never watched before
		return not SaveManager.has_watched_cutscene("floor_3_level_3_prologue")
	
	return false

func _show_floor_title_then_start() -> void:
	# Show floor title (pauses game)
	floor_title.show_title()
	await floor_title.title_finished
	
	# Now transition to full gameplay
	_start_gameplay()

func _start_gameplay() -> void:
	"""Handles unpausing, enabling cameras/music, and starting the boss encounter."""
	get_tree().paused = false
	player_camera.enabled = true
	camera_2d_2.enabled = true
	MusicManager.play_song("boss")
	
	# Start player timer AFTER floor title finishes
	if player:
		player.reset_level_timer()
	
	# Show boss health bar after delay
	_show_boss_health_bar()
	
	# Clean up cutscene node if it exists
	if before_boss_normal and is_instance_valid(before_boss_normal):
		before_boss_normal.queue_free()

func _show_boss_health_bar() -> void:
	"""Show the boss health bar after 3 seconds"""
	print("[Boss Level] Attempting to show boss health bar...")
	
	# Wait for scene to be ready
	if is_inside_tree():
		await get_tree().process_frame
	else:
		return
	
	# Find TouchControls
	var touch_controls = get_tree().get_first_node_in_group("touch_controls")
	
	if not touch_controls:
		touch_controls = get_node_or_null("TouchControls")
	
	if not touch_controls:
		for node in get_tree().get_nodes_in_group(""):
			if node.name == "TouchControls":
				touch_controls = node
				break
	
	if not touch_controls:
		print("[Boss Level] ERROR: TouchControls not found!")
		return
	
	print("[Boss Level] TouchControls found!")
	
	if not touch_controls.hud_boss or not touch_controls.health_bar_boss:
		print("[Boss Level] ERROR: Boss health bar components not found!")
		return
	
	print("[Boss Level] Found boss health bar components!")
	
	# Wait 3 seconds then show
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
	var controls = get_tree().root.get_node_or_null("TouchControls")
	if controls:
		controls.show_attack_button()

func unlock_shine():
	Global.unlock_shine()
	print("[Boss Level] Shine ability unlocked!")

func unlock_dash():
	Global.touchdash = true
	SaveManager.unlock_ability("dash")
	var controls = get_tree().root.get_node_or_null("TouchControls")
	if controls:
		controls.show_dash_button()

var game_over_shown: bool = false

func _on_boss_defeated() -> void:
	"""Called when boss is defeated/killed"""
	if boss_defeated or game_over_shown:  # ← ADD game_over_shown check
		return
	
	boss_defeated = true
	game_over_shown = true  # ← ADD this line
	
	print("[Boss Level] Boss defeated!")

	# GET TIME FIRST before stopping timer
	var time_cleared = 0.0
	if player and player.has_method("get_level_time"):
		time_cleared = player.get_level_time()

	# THEN disable player controls
	if player:
		player.stop_level_timer()
		player.set_physics_process(false)
		player.set_process_input(false)
		player.velocity = Vector2.ZERO

	# Mark level as completed
	SaveManager.mark_level_completed(3, 3)
	
	# Cache the tree reference before any awaits
	var tree = get_tree()
	if not tree:
		return
	
	# Show level completed screen immediately (no cutscene before)
	await tree.process_frame
	
	# Check again if still valid
	if not is_inside_tree() or not tree:
		return
	
	var game_over_scene = preload("res://scene/game_over.tscn")
	var game_over_screen = game_over_scene.instantiate()
	tree.root.add_child(game_over_screen)
	
	if game_over_screen.has_method("show_game_over"):
		game_over_screen.show_game_over(3, 3, time_cleared, true)

func _on_player_died() -> void:
	"""Called when player dies to the boss"""
	if player_defeated or game_over_shown:  # ← ADD game_over_shown check
		return
	
	player_defeated = true
	game_over_shown = true  # ← ADD this line
	
	print("[Boss Level] Player died!")

	# GET TIME FIRST before waiting
	var time_survived = 0.0
	if player and player.has_method("get_level_time"):
		time_survived = player.get_level_time()

	# Cache the tree reference before any awaits
	var tree = get_tree()
	if not tree:
		return

	# Wait for death animation
	await tree.create_timer(1.5).timeout

	if not is_inside_tree() or not tree:
		return
	
	# Show game over screen immediately (no cutscene before)
	await tree.process_frame
	
	# Check again if still valid
	if not is_inside_tree() or not tree:
		return
	
	var game_over_scene = preload("res://scene/game_over.tscn")
	var game_over_screen = game_over_scene.instantiate()
	tree.root.add_child(game_over_screen)
	
	if game_over_screen.has_method("show_game_over"):
		game_over_screen.show_game_over(3, 3, time_survived, false)

func _process(delta: float) -> void:
	pass
