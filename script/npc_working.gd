extends Area2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	animated_sprite_2d.play("idle")

func _input(event: InputEvent) -> void:
	if len(get_overlapping_bodies()) == 0:
		return
	
	var tapped = event is InputEventScreenTouch and event.pressed
	var pressed_b = event.is_action_pressed("b")
	
	if tapped or pressed_b:
		face_player()
		find_and_use_dialogue()

func face_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	
	var player = players[0]
	if player.global_position.x < global_position.x:
		animated_sprite_2d.flip_h = true
	else:
		animated_sprite_2d.flip_h = false

func find_and_use_dialogue() -> void:
	var dialogue_player = get_node_or_null("DialoguePlayer")
	if dialogue_player:
		dialogue_player.play()
