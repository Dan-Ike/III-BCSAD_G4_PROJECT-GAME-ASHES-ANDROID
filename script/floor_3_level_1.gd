extends Node2D

@onready var player_camera = $player/Camera2D
@onready var camera_2d_2 = $player/Camera2D2
@onready var scene_transition_animation = $SceneTransitionAnimation/AnimationPlayer
@onready var spike_collision = $spike_collision
@onready var before_3_1: CanvasLayer = $before_3_1

func _ready() -> void:
	Global.set_floor_level(3, 1)
	
	scene_transition_animation.get_parent().get_node("ColorRect").color.a = 255
	scene_transition_animation.play("fade_out")
	player_camera.enabled = false
	camera_2d_2.enabled = true
	#MusicManager.play_song("level1") #change to sa music level1.3 pag may nahanap na bagay
		# Check if cutscene should play
	var should_play_cutscene = _should_show_cutscene()
	
	if should_play_cutscene:
		# Start with cutscene - everything disabled
		player_camera.enabled = false
		camera_2d_2.enabled = true
		# Don't stop or play music here - let cutscene handle it
		
		# Show and start cutscene with unique ID
		before_3_1.visible = true
		before_3_1.start_cutscene("floor_3_level_1_prologue")
	else:
		# Skip cutscene - go straight to gameplay
		get_tree().paused = false 
		player_camera.enabled = true
		camera_2d_2.enabled = true
		MusicManager.play_song("level3")
		
		# Remove cutscene node
		if before_3_1:
			before_3_1.queue_free()
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
		return not SaveManager.has_watched_cutscene("floor_3_level_1_prologue")
	
	return false

func _process(delta: float) -> void:
	pass

func _on_floor_3_lvl_2_body_entered(body: Node2D) -> void:
	if body is Player:
		Global.gameStarted = true
		#unlock_dash()
		#unlock_double_jump()
		#SaveManager.mark_level_completed(3, 1)  
		#SaveManager.advance_to_level(3, 2)      
		#Global.advance_level()
		#Global.advance_floor()
		unlock_attack()
		body.touch_controls.disable_all_controls() 
		scene_transition_animation.play("fade_in")
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/boss_level_normal.tscn")
		

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
