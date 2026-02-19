# tutorial_dialogue.gd
extends CanvasLayer

#@onready var dialogue_panel: Panel = $DialoguePanel
#@onready var dialogue_label: RichTextLabel = $DialoguePanel/MarginContainer/DialogueLabel
#@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var dialogue_panel: Panel = $DialoguePanel
@onready var margin_container: MarginContainer = $DialoguePanel/MarginContainer
@onready var dialogue_label: RichTextLabel = $DialoguePanel/MarginContainer/DialogueLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

signal dialogue_finished

var current_text: String = ""
var is_typing: bool = false
var char_index: int = 0
const TYPING_SPEED: float = 0.05

func _ready() -> void:
	dialogue_panel.visible = false
	if dialogue_label:
		dialogue_label.bbcode_enabled = true

func show_dialogue(text: String) -> void:
	current_text = text
	char_index = 0
	dialogue_panel.visible = true
	dialogue_label.text = ""
	is_typing = true
	_type_text()

func _type_text() -> void:
	while char_index < current_text.length():
		if not is_typing:
			return
		
		dialogue_label.text += current_text[char_index]
		char_index += 1
		await get_tree().create_timer(TYPING_SPEED).timeout
	
	is_typing = false
	await get_tree().create_timer(1.0).timeout
	dialogue_finished.emit()

func hide_dialogue() -> void:
	dialogue_panel.visible = false
	is_typing = false

func skip_typing() -> void:
	if is_typing:
		dialogue_label.text = current_text
		is_typing = false
