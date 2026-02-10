extends CanvasLayer

var dialogue_box
var dialogue_label
var choice_container
var yes_button
var no_button

var current_dialogue = []
var dialogue_index = 0
var is_showing_choices = false
var current_choice = 0  # 0 = yes, 1 = no
var npc_callback: Callable

signal dialogue_finished(accepted: bool)

func _ready():
	# Get references safely
	dialogue_box = get_node_or_null("DialogueBox")
	if dialogue_box:
		dialogue_label = dialogue_box.get_node_or_null("VBoxContainer/DialogueLabel")
		choice_container = dialogue_box.get_node_or_null("VBoxContainer/ChoiceContainer")
		if choice_container:
			yes_button = choice_container.get_node_or_null("YesLabel")
			no_button = choice_container.get_node_or_null("NoLabel")
	
	hide_dialogue()

func show_dialogue(dialogue_lines: Array, callback: Callable = Callable()):
	if not dialogue_box:
		push_error("DialogueBox not found!")
		return
	
	current_dialogue = dialogue_lines
	dialogue_index = 0
	is_showing_choices = false
	npc_callback = callback
	dialogue_box.visible = true
	if choice_container:
		choice_container.visible = false
	_display_current_line()

func _display_current_line():
	if dialogue_index < current_dialogue.size():
		if dialogue_label:
			dialogue_label.text = current_dialogue[dialogue_index]
	else:
		_show_choices()

func _show_choices():
	if not choice_container:
		hide_dialogue()
		return
	
	is_showing_choices = true
	if dialogue_label:
		dialogue_label.text = "Accept the quest?"
	choice_container.visible = true
	current_choice = 0
	_update_choice_highlight()

func _update_choice_highlight():
	if not yes_button or not no_button:
		return
	
	if current_choice == 0:
		yes_button.modulate = Color.YELLOW
		no_button.modulate = Color.WHITE
	else:
		yes_button.modulate = Color.WHITE
		no_button.modulate = Color.YELLOW

func _input(event):
	if not dialogue_box or not dialogue_box.visible:
		return
	
	if is_showing_choices:
		if Input.is_action_just_pressed("left"):
			current_choice = 0
			_update_choice_highlight()
		elif Input.is_action_just_pressed("right"):
			current_choice = 1
			_update_choice_highlight()
		elif Input.is_action_just_pressed("jump"):
			var accepted = (current_choice == 0)
			hide_dialogue()
			dialogue_finished.emit(accepted)
			if npc_callback.is_valid():
				npc_callback.call(accepted)
	else:
		if Input.is_action_just_pressed("jump"):
			dialogue_index += 1
			_display_current_line()

func hide_dialogue():
	if dialogue_box:
		dialogue_box.visible = false
	if choice_container:
		choice_container.visible = false
	is_showing_choices = false
