extends Node2D

#@onready var player_camera: Camera2D = $Camera2D

@onready var player_camera = $player/Camera2D
@onready var scene_transition_animation = $SceneTransitionAnimation/AnimationPlayer

func _ready() -> void:
	scene_transition_animation.get_parent().get_node("ColorRect").color.a = 255
	scene_transition_animation.play("fade_out")
	player_camera.enabled = true

func _process(delta: float) -> void:
	pass

func _on_start_game_detection_body_entered(body: Node2D) -> void:
	if body is Player:
		Global.gameStarted = true
		scene_transition_animation.play("fade_in")
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/floor_1_lvl_1.tscn")
