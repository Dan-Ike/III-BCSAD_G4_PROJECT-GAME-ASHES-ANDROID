extends CharacterBody2D

const speed = 300.0
var current_state = IDLE
var dir = Vector2.RIGHT
var start_pos
var is_roaming = true
var is_chatting = false
var player
var player_in_chat_zone = false

var dialogue_manager
var has_quest = false
var quest_accepted = false

enum {
	IDLE, 
	NEW_DIR,
	MOVE
}

func _ready():
	randomize()
	start_pos = position
	# Get dialogue manager reference
	dialogue_manager = get_node("/root/DialogueManager")
	if not dialogue_manager:
		push_error("DialogueManager not found!")

func _process(delta: float):
	if current_state == 0 or current_state == 1:
		$AnimatedSprite2D.play("idle")
	
	# Check for player interaction
	if player_in_chat_zone and Input.is_action_just_pressed("jump") and !is_chatting:
		start_dialogue()
	
	if is_roaming and !is_chatting:
		match current_state:
			IDLE:
				pass
			NEW_DIR:
				dir = choose([Vector2.LEFT, Vector2.RIGHT])
			MOVE:
				move(delta)

func start_dialogue():
	is_chatting = true
	is_roaming = false
	
	var dialogue_lines = []
	
	if !has_quest:
		dialogue_lines = [
			"Hello, traveler!",
			"I need your help with something.",
			"There are monsters nearby..."
		]
	elif quest_accepted:
		dialogue_lines = ["Good luck on your quest!"]
	else:
		dialogue_lines = ["Changed your mind?"]
	
	if dialogue_manager:
		dialogue_manager.show_dialogue(dialogue_lines, on_dialogue_finished)

func on_dialogue_finished(accepted: bool):
	is_chatting = false
	is_roaming = true
	
	if !has_quest:
		has_quest = true
		quest_accepted = accepted
		
		if accepted:
			print("Quest accepted!")
			# Add quest logic here
		else:
			print("Quest declined!")
	
	# Resume NPC roaming after brief pause
	await get_tree().create_timer(0.5).timeout
	$Timer.start()

func choose(array):
	array.shuffle()
	return array.front()

func move(delta):
	if !is_chatting:
		position += dir * speed * delta

func _on_chat_detection_area_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		player = body
		player_in_chat_zone = true

func _on_chat_detection_area_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		player_in_chat_zone = false

func _on_timer_timeout() -> void:
	$Timer.wait_time = choose([0.5, 1, 1.5])
	current_state = choose([IDLE, NEW_DIR, MOVE])
