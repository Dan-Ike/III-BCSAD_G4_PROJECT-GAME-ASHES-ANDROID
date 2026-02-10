extends Node2D

@export var dialogue_ui_scene: PackedScene

var dialogue_ui
var player_in_range := false

func _ready():
	$Area2D.body_entered.connect(_on_body_entered)
	$Area2D.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		player_in_range = true
		start_dialogue()

func _on_body_exited(body):
	if body.name == "Player":
		player_in_range = false
		if dialogue_ui:
			dialogue_ui.queue_free()
			dialogue_ui = null

func start_dialogue():
	if dialogue_ui:
		return

	dialogue_ui = dialogue_ui_scene.instantiate()
	get_tree().current_scene.add_child(dialogue_ui)

	dialogue_ui.start_dialogue([
		{
			"text": "Hey, traveler! Want to accept my quest?",
			"options": ["Yes", "No"]
		},
		{
			"text": "Great! Come back after you finish it.",
			"options": []
		}
	])
