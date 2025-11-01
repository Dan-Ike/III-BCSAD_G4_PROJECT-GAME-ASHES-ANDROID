extends Node2D

@onready var player = $player
@onready var rising_lava = $RisingLava
@onready var player_camera = $player/Camera2D
@onready var camera_2d_2 = $player/Camera2D2
@onready var scene_transition_animation = $SceneTransitionAnimation/AnimationPlayer

var lava_started: bool = false

func _ready() -> void:
	Global.set_floor_level(1, 3)
	
	scene_transition_animation.get_parent().get_node("ColorRect").color.a = 255
	scene_transition_animation.play("fade_out")
	player_camera.enabled = false
	camera_2d_2.enabled = true
	MusicManager.play_song("level1")

func _process(delta: float) -> void:
	if not lava_started and Input.is_action_just_pressed("jump"):
		start_lava()

func start_lava() -> void:
	if lava_started:
		return
	
	lava_started = true
	if rising_lava:
		rising_lava.start_rising()
		print("Lava activated by player jump")

func _on_floor_2_lvl_1_body_entered(body: Node2D) -> void:
	if body is Player:
		Global.gameStarted = true
		unlock_dash()
		unlock_double_jump()
		SaveManager.mark_level_completed(1, 3)
		SaveManager.advance_to_level(2, 1)
		Global.advance_level()
		Global.advance_floor()
		body.touch_controls.disable_all_controls()
		scene_transition_animation.play("fade_in")
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/floor_2_level_1.tscn")

func unlock_double_jump():
	Global.can_double_jump = true
	SaveManager.unlock_ability("double_jump")

func unlock_attack():
	Global.touchatk = true
	SaveManager.unlock_ability("attack")

func unlock_dash():
	Global.touchdash = true
	SaveManager.unlock_ability("dash")
