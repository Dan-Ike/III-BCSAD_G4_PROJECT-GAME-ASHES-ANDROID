extends CanvasLayer

@export_file("*.json") var dialogue_file: String = "res://npc.json"

var dialogues = []
var current_dialogue_id = 0
var is_dialogue_active = false
var dialogue_completed = false
var player: Player = null
var can_restart_dialogue = true
const RESTART_COOLDOWN = 2.0
var npc_dialogue_finished: bool = false

func _ready():
	$NinePatchRect.visible = false
	
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = Global.playerBody

func play():
	if is_dialogue_active or (dialogue_completed and not can_restart_dialogue):
		return
	
	dialogues = load_dialogue()
	is_dialogue_active = true
	dialogue_completed = false
	$NinePatchRect.visible = true
	current_dialogue_id = -1
	
	if player:
		player.tutorial_frozen = true
		player.velocity.x = 0
	
	next_line()

func _input(event: InputEvent):
	if not is_dialogue_active:
		return
	
	var tapped = event is InputEventScreenTouch and event.pressed
	var pressed_b = event.is_action_pressed("b")
	
	if tapped or pressed_b:
		next_line()
		get_viewport().set_input_as_handled()

func next_line():
	current_dialogue_id += 1
	if current_dialogue_id >= len(dialogues):
		is_dialogue_active = false
		dialogue_completed = true
		$NinePatchRect.visible = false
		
		if player:
			player.tutorial_frozen = false
		
		var tutorial_manager = get_tree().get_first_node_in_group("tutorial_manager")
		if tutorial_manager and tutorial_manager.has_method("on_npc_dialogue_finished"):
			tutorial_manager.on_npc_dialogue_finished()
		
		_start_restart_cooldown()
		return
	
	$NinePatchRect/Name.text = dialogues[current_dialogue_id]["name"]
	$NinePatchRect/Message.text = dialogues[current_dialogue_id]["text"]

func _start_restart_cooldown():
	can_restart_dialogue = false
	await get_tree().create_timer(RESTART_COOLDOWN).timeout
	can_restart_dialogue = true
	print("[NPC Dialogue] Can restart dialogue now")

func load_dialogue():
	if FileAccess.file_exists(dialogue_file):
		var file = FileAccess.open(dialogue_file, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			return json.data
		else:
			push_error("JSON Parse Error: " + json.get_error_message())
			return []
	else:
		push_error("File not found: " + dialogue_file)
		return []

func _on_timer_timeout() -> void:
	is_dialogue_active = false
	if player:
		player.tutorial_frozen = false

func reset_dialogue():
	dialogue_completed = false
	current_dialogue_id = 0
	can_restart_dialogue = true
