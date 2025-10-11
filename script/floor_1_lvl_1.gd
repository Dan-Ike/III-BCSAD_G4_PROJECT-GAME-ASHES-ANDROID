extends Node2D

@onready var player_camera = $player/Camera2D
@onready var camera_2d_2 = $player/Camera2D2
@onready var scene_transition_animation = $SceneTransitionAnimation/AnimationPlayer
@onready var spike_collision = $spike_collision
@onready var cutscene: CanvasLayer = $Cutscene
@onready var player: Player = $player


func _ready() -> void:
	# Set current floor and level in Global
	Global.set_floor_level(1, 1)
	
	# Start with cutscene - everything disabled
	player_camera.enabled = false
	camera_2d_2.enabled = false
	MusicManager.stop_song()
	
	# Show and start cutscene
	cutscene.visible = true
	cutscene.start_cutscene()


func _process(delta: float) -> void:
	pass


func _on_floor_1_lvl_2_body_entered(body: Node2D) -> void:
	if body is Player:
		Global.gameStarted = true
		unlock_dash()
		SaveManager.mark_level_completed(1, 1) 
		SaveManager.advance_to_level(1, 2)
		
		# Update Global to next level
		Global.advance_level()
		
		body.touch_controls.disable_all_controls() 
		scene_transition_animation.play("fade_in")
		await get_tree().create_timer(0.5).timeout
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
		body.take_damage(Global.spikeDamageAmount)
