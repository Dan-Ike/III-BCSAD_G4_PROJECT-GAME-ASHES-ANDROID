extends Node2D

@onready var player_camera = $player/Camera2D
@onready var camera_2d_2 = $player/Camera2D2
@onready var scene_transition_animation = $SceneTransitionAnimation/AnimationPlayer
@onready var spike_collision = $spike_collision

func _ready() -> void:
	Global.set_floor_level(1, 2)
	
	scene_transition_animation.get_parent().get_node("ColorRect").color.a = 255
	scene_transition_animation.play("fade_out")
	player_camera.enabled = false
	camera_2d_2.enabled = true
	MusicManager.play_song("level1")

func _process(delta: float) -> void:
	pass

func _on_floor_1_lvl_2_body_entered(body: Node2D) -> void:
	if body is Player:
		Global.gameStarted = true
		unlock_dash()
		unlock_double_jump()
		SaveManager.mark_level_completed(1, 2)  
		SaveManager.advance_to_level(1, 3)      
		Global.advance_level()
		body.touch_controls.disable_all_controls() 
		scene_transition_animation.play("fade_in")
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/floor_1_level_3.tscn")

func _on_floor_2_lvl_1_body_entered(body: Node2D) -> void:
	if body is Player:
		Global.gameStarted = true
		unlock_dash()
		unlock_double_jump()
		SaveManager.mark_level_completed(1, 2)  
		SaveManager.advance_to_level(1, 3)      
		Global.advance_level()
		body.touch_controls.disable_all_controls() 
		scene_transition_animation.play("fade_in")
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/floor_1_level_3.tscn")

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
