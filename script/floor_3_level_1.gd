extends Node2D

@onready var player_camera = $player/Camera2D
@onready var camera_2d_2 = $player/Camera2D2
@onready var scene_transition_animation = $SceneTransitionAnimation/AnimationPlayer
@onready var spike_collision = $spike_collision
@onready var before_3_1: CanvasLayer = $before_3_1
@onready var floor_title: CanvasLayer = $FloorTitle
@onready var player: Player = $player

@onready var gate: CollisionShape2D = $StaticBody2D2/gate
@onready var advanced_enemy: AdvancedEnemy = $AdvancedEnemy	
@onready var flr_3_lvl_2: Area2D = $flr3lvl2

var is_transitioning = false

func _ready() -> void:
	Global.reset_game_over_flag()
	Global.set_floor_level(3, 1)
	
	scene_transition_animation.get_parent().get_node("ColorRect").color.a = 255
	scene_transition_animation.play("fade_out")
	player_camera.enabled = false
	camera_2d_2.enabled = true
	
	var should_play_cutscene = _should_show_cutscene()
	
	if should_play_cutscene:
		if player.has_node("../CanvasLayer"):
			var touch_controls_node = player.get_node("../CanvasLayer")
			if touch_controls_node:
				touch_controls_node.disable_all_controls()
		
		player_camera.enabled = false
		camera_2d_2.enabled = true
		before_3_1.visible = true
		before_3_1.start_cutscene("floor_3_level_1_prologue")
		
		# Wait for cutscene to finish, then show floor title
		await before_3_1.cutscene_finished
		_show_floor_title_then_start()
	else:
		# No cutscene - show floor title immediately
		_show_floor_title_then_start()
	
	Global.set_retrying(false)
	if advanced_enemy:
		advanced_enemy.connect("tree_exited", _on_advanced_enemy_died)

func _on_advanced_enemy_died() -> void:
	# Remove the gate collision when enemy dies
	if gate:
		gate.disabled = true
		print("[Level] Gate opened - Advanced Enemy defeated!")

func _show_floor_title_then_start() -> void:
	# Show floor title (pauses game)
	floor_title.show_title()
	await floor_title.title_finished
	
	# Now start gameplay
	get_tree().paused = false
	player_camera.enabled = true
	camera_2d_2.enabled = true
	MusicManager.play_song("level3")
	
	# Start player timer AFTER floor title finishes
	player.reset_level_timer()
	
	if before_3_1:
		before_3_1.queue_free()

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
		return not SaveManager.has_watched_cutscene("floor_3_level_1_prologue")
	
	return false

func _process(delta: float) -> void:
	pass

func _on_floor_3_lvl_2_body_entered(body: Node2D) -> void:
	if body is Player and not is_transitioning:
		is_transitioning = true
		
		# Get time FIRST before stopping
		var time_cleared = body._get_elapsed_time()
		body.stop_level_timer()
		
		print("[Level] Player completed Floor %d, Level %d in %.2f seconds" % [Global.current_floor, Global.current_level, time_cleared])
		
		# Disable player input during transition
		body.set_physics_process(false)
		body.touch_controls.disable_all_controls()
		
		# Play cinematic fade to black
		scene_transition_animation.play("fade_in")
		await scene_transition_animation.animation_finished
		
		# Save progress
		Global.gameStarted = true
		SaveManager.mark_level_completed(3, 1)
		SaveManager.advance_to_level(3, 2)
		unlock_attack()
		
		# Show level completed screen
		var game_over_scene = preload("res://scene/game_over.tscn")
		var game_over = game_over_scene.instantiate()
		get_tree().root.add_child(game_over)
		if game_over.has_method("show_game_over"):
			game_over.show_game_over(Global.current_floor, Global.current_level, time_cleared, true)


func _on_spike_collision_body_entered(body: Node2D) -> void:
	if body is Player and body.can_take_damage:
		body.take_damage(Global.spikeDamageAmount)

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
