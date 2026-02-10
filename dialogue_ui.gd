extends CanvasLayer

@onready var text_label = $Panel/RichTextLabel
@onready var option_yes = $Panel/OptionYes
@onready var option_no = $Panel/OptionNo

var dialogue_data = []
var dialogue_index := 0
var selected_option := 0

func start_dialogue(data):
	dialogue_data = data
	dialogue_index = 0
	show_dialogue()

func show_dialogue():
	var entry = dialogue_data[dialogue_index]
	text_label.text = entry["text"]

	if entry["options"].size() > 0:
		option_yes.text = "> " + entry["options"][0]
		option_no.text = "  " + entry["options"][1]
		option_yes.visible = true
		option_no.visible = true
		selected_option = 0
	else:
		option_yes.visible = false
		option_no.visible = false

func _input(event):
	if event.is_action_pressed("ui_left"):
		select_option(0)
	elif event.is_action_pressed("ui_right"):
		select_option(1)
	elif event.is_action_pressed("jump"):
		confirm()

func select_option(index):
	selected_option = index
	if index == 0:
		option_yes.text = "> Yes"
		option_no.text = "  No"
	else:
		option_yes.text = "  Yes"
		option_no.text = "> No"

func confirm():
	dialogue_index += 1
	if dialogue_index >= dialogue_data.size():
		queue_free()
	else:
		show_dialogue()
