extends CanvasLayer

@onready var dialogue_panel: Panel = $DialoguePanel
@onready var margin_container: MarginContainer = $DialoguePanel/MarginContainer
@onready var dialogue_label: RichTextLabel = $DialoguePanel/MarginContainer/DialogueLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

signal dialogue_finished

var full_bbcode: String = ""
var is_typing: bool = false
var typing_timer: float = 0.0
var total_chars: int = 0
const TYPING_SPEED: float = 0.03

func _ready() -> void:
	dialogue_panel.visible = false
	if dialogue_label:
		dialogue_label.bbcode_enabled = true

func show_dialogue(text: String) -> void:
	full_bbcode = text
	dialogue_label.text = full_bbcode  # Set full text immediately
	total_chars = dialogue_label.get_total_character_count()  # Count visible chars only
	dialogue_label.visible_characters = 0  # Start with none shown
	dialogue_panel.visible = true
	is_typing = true
	typing_timer = 0.0

func _process(delta: float) -> void:
	if not is_typing:
		return
	
	typing_timer += delta
	if typing_timer >= TYPING_SPEED:
		typing_timer = 0.0
		dialogue_label.visible_characters += 1
		
		if dialogue_label.visible_characters >= total_chars:
			is_typing = false
			_on_typing_finished()

func _on_typing_finished() -> void:
	dialogue_label.visible_characters = -1  # -1 means show all
	await get_tree().create_timer(1.5).timeout
	dialogue_finished.emit()

func _input(event: InputEvent) -> void:
	if not dialogue_panel.visible:
		return
	
	var tapped = event is InputEventScreenTouch and event.pressed
	var pressed_b = event.is_action_pressed("b")
	
	if tapped or pressed_b:
		if is_typing:
			is_typing = false
			dialogue_label.visible_characters = -1
			_on_typing_finished()
		get_viewport().set_input_as_handled()

func hide_dialogue() -> void:
	dialogue_panel.visible = false
	is_typing = false
	dialogue_label.visible_characters = -1

func skip_typing() -> void:
	if is_typing:
		is_typing = false
		dialogue_label.visible_characters = -1
