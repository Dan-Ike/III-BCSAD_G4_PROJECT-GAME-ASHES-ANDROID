extends CanvasLayer
@onready var nine_patch_rect: NinePatchRect = $NinePatchRect
@onready var npc_name: RichTextLabel = $NinePatchRect/Name
@onready var message: RichTextLabel = $NinePatchRect/Message

@onready var nine_patch_rect_2: NinePatchRect = $NinePatchRect2
@onready var npc_name_2: RichTextLabel = $NinePatchRect2/Name
@onready var message_2: RichTextLabel = $NinePatchRect2/Message

@export_file("*.json") var dialogue_file: String = "res://npc.json"
## Set this in the inspector to match the section in npc.json e.g. "npc_1", "npc_2", "npc_3"
@export var npc_id: String = "npc_1"

var dialogues = []
var current_dialogue_id = 0
var is_dialogue_active = false
var dialogue_completed = false
var player: Player = null
var can_restart_dialogue = true
const RESTART_COOLDOWN = 2.0
var npc_dialogue_finished: bool = false

# Typewriter
var full_text: String = ""
var is_typing: bool = false
var typewriter_speed: float = 0.03
var typewriter_timer: float = 0.0
var displayed_chars: int = 0
var _is_player_line: bool = false

func _ready():
	$NinePatchRect.visible = false
	$NinePatchRect2.visible = false

	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = Global.playerBody

func play():
	if is_dialogue_active or (dialogue_completed and not can_restart_dialogue):
		return

	dialogues = load_dialogue()
	if dialogues.is_empty():
		push_error("[NPC Dialogue] No dialogues loaded for npc_id: %s" % npc_id)
		return

	is_dialogue_active = true
	dialogue_completed = false
	$NinePatchRect.visible = false
	$NinePatchRect2.visible = false
	current_dialogue_id = -1

	if player:
		player.tutorial_frozen = true
		player.velocity.x = 0

	next_line()

func _process(delta: float) -> void:
	if not is_typing:
		return

	typewriter_timer += delta
	if typewriter_timer >= typewriter_speed:
		typewriter_timer = 0.0
		displayed_chars += 1
		var target = $NinePatchRect2/Message if _is_player_line else $NinePatchRect/Message
		target.text = full_text.substr(0, displayed_chars)

		if displayed_chars >= full_text.length():
			is_typing = false

func _input(event: InputEvent):
	if not is_dialogue_active:
		return

	var tapped = event is InputEventScreenTouch and event.pressed
	var pressed_b = event.is_action_pressed("b")

	if tapped or pressed_b:
		if is_typing:
			_finish_typing()
		else:
			next_line()
		get_viewport().set_input_as_handled()

func _finish_typing() -> void:
	is_typing = false
	displayed_chars = full_text.length()
	if _is_player_line:
		$NinePatchRect2/Message.text = full_text
	else:
		$NinePatchRect/Message.text = full_text

func _start_typewriter(text: String, is_player_line: bool) -> void:
	_is_player_line = is_player_line
	full_text = text
	displayed_chars = 0
	is_typing = true
	typewriter_timer = 0.0
	if is_player_line:
		$NinePatchRect2/Message.text = ""
	else:
		$NinePatchRect/Message.text = ""

func next_line():
	current_dialogue_id += 1
	if current_dialogue_id >= len(dialogues):
		is_dialogue_active = false
		dialogue_completed = true
		is_typing = false
		$NinePatchRect.visible = false
		$NinePatchRect2.visible = false

		if player:
			player.tutorial_frozen = false

		var tutorial_manager = get_tree().get_first_node_in_group("tutorial_manager")
		if tutorial_manager and tutorial_manager.has_method("on_npc_dialogue_finished"):
			tutorial_manager.on_npc_dialogue_finished()

		_start_restart_cooldown()
		return

	var line = dialogues[current_dialogue_id]
	var is_player = line["name"] == "Player"

	$NinePatchRect.visible  = not is_player
	$NinePatchRect2.visible = is_player

	if is_player:
		npc_name_2.text = line["name"]
		_start_typewriter(line["text"], true)
	else:
		npc_name.text = line["name"]
		_start_typewriter(line["text"], false)

func _start_restart_cooldown():
	can_restart_dialogue = false
	await get_tree().create_timer(RESTART_COOLDOWN).timeout
	can_restart_dialogue = true
	print("[NPC Dialogue] Can restart dialogue now")

func load_dialogue():
	if not FileAccess.file_exists(dialogue_file):
		push_error("[NPC Dialogue] File not found: %s" % dialogue_file)
		return []

	var file = FileAccess.open(dialogue_file, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("[NPC Dialogue] JSON Parse Error: " + json.get_error_message())
		return []

	var all_data = json.data
	if not all_data.has(npc_id):
		push_error("[NPC Dialogue] npc_id '%s' not found in JSON" % npc_id)
		return []

	return all_data[npc_id]

func _on_timer_timeout() -> void:
	is_dialogue_active = false
	is_typing = false
	if player:
		player.tutorial_frozen = false

func reset_dialogue():
	dialogue_completed = false
	current_dialogue_id = 0
	can_restart_dialogue = true
	is_typing = false
