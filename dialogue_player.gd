extends CanvasLayer

@export_file("*.json") var dialogue_file: String = "res://npc.json"

var dialogues = []
var current_dialogue_id = 0
var is_dialogue_active = false

func _ready():
	$NinePatchRect.visible = false

func play():
	if is_dialogue_active:
		return
		
	dialogues = load_dialogue()
	
	is_dialogue_active = true
	$NinePatchRect.visible = true
	current_dialogue_id = -1
	next_line()

func _input(event):
	if !is_dialogue_active:
		return
	if event.is_action_pressed("b"):
		next_line()

func next_line():
	current_dialogue_id += 1
	if current_dialogue_id >= len(dialogues):
		is_dialogue_active = false
		$NinePatchRect.visible = false
		return
	
	$NinePatchRect/Name.text = dialogues[current_dialogue_id]["name"]
	$NinePatchRect/Message.text = dialogues[current_dialogue_id]["text"]

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
