extends Node2D

@onready var player: Player = $player
@onready var rising_lava = $RisingLava
@onready var player_camera = $player/Camera2D
@onready var camera_2d_2 = $player/Camera2D2
@onready var scene_transition_animation = $SceneTransitionAnimation/AnimationPlayer
@onready var floor_title: CanvasLayer = $FloorTitle
@onready var spike_collision: Area2D = $spike_collision

var lava_started: bool = false

func _ready() -> void:
	Global.reset_game_over_flag()
	Global.set_floor_level(1, 3)
	
	scene_transition_animation.get_parent().get_node("ColorRect").color.a = 255
	scene_transition_animation.play("fade_out")
	player_camera.enabled = false
	camera_2d_2.enabled = true
	MusicManager.play_song("level1")
	_show_floor_title_then_start()

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
		var time_cleared = body._get_elapsed_time()
		body.stop_level_timer()
		
		print("[Level] Player completed Floor %d, Level %d in %.2f seconds" % [Global.current_floor, Global.current_level, time_cleared])
		
		Global.gameStarted = true
		unlock_dash()
		unlock_double_jump()
		SaveManager.mark_level_completed(1, 3)
		SaveManager.advance_to_level(2, 1)
		
		body.touch_controls.disable_all_controls()
		
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

func unlock_dash():
	Global.touchdash = true
	SaveManager.unlock_ability("dash")

func _on_spike_collision_body_entered(body: Node2D) -> void:
	if body is Player and body.can_take_damage:
		body.take_damage(Global.spikeDamageAmount)
