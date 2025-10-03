extends Node

var player_scene = preload("res://scene/player.tscn")
var player_ref: Player

func spawn_player(spawn_pos: Vector2):
	if player_ref:
		player_ref.queue_free()
	player_ref = player_scene.instantiate()
	player_ref.global_position = spawn_pos
	get_tree().current_scene.add_child(player_ref)
