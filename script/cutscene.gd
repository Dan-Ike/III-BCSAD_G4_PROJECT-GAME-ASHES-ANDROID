extends CanvasLayer

@onready var background: TextureRect = $Background
@onready var click_area: Control = $ClickArea
@onready var text_container: PanelContainer = $TextContainer
@onready var text_margin: MarginContainer = $TextContainer/TextMargin
@onready var text_label: Label = $TextContainer/TextMargin/TextLabel
@onready var summary_container: CenterContainer = $SummaryContainer
@onready var summary_panel: PanelContainer = $SummaryContainer/SummaryPanel
@onready var summary_margin: MarginContainer = $SummaryContainer/SummaryPanel/SummaryMargin
@onready var summary_v_box: VBoxContainer = $SummaryContainer/SummaryPanel/SummaryMargin/SummaryVBox
@onready var summary_title: Label = $SummaryContainer/SummaryPanel/SummaryMargin/SummaryVBox/SummaryTitle
@onready var summary_text: Label = $SummaryContainer/SummaryPanel/SummaryMargin/SummaryVBox/SummaryText
@onready var skip_button: Button = $SkipButton
@onready var continue_button: Button = $ContinueButton

# Cutscene data structure
var cutscene_data = [
	{
		"background": "res://art/hellimg.jpg",
		"text": "ah line line"
	},
	{
		"background": "res://icon.svg",
		"text": "woohoo"
	},
	{
		"background": "res://path/to/background3.png",
		"text": "line"
	}
]

var summary_data = {
	"title": "Story Summary",
	"text": "bat ka nag skip"
}

# State variables
var current_scene_index = 0
var current_text = ""
var displayed_text = ""
var is_typing = false
var typing_speed = 0.05
var typing_timer = 0.0
var skip_timer = 0.0
var show_skip_after = 5.0
var continue_timer = 0.0
var show_continue_after = 5.0
var in_summary = false

func _ready() -> void:
	skip_button.hide()
	continue_button.hide()
	summary_container.hide()
	text_container.hide()
	click_area.gui_input.connect(_on_click_area_input)
	skip_button.pressed.connect(_on_skip_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	start_cutscene()

func _process(delta: float) -> void:
	if is_typing:
		typing_timer += delta
		if typing_timer >= typing_speed:
			typing_timer = 0.0
			displayed_text += current_text[displayed_text.length()]
			text_label.text = displayed_text
			if displayed_text.length() >= current_text.length():
				is_typing = false
	if not in_summary and not skip_button.visible:
		skip_timer += delta
		if skip_timer >= show_skip_after:
			skip_button.show()
	if in_summary and not continue_button.visible:
		continue_timer += delta
		if continue_timer >= show_continue_after:
			continue_button.show()

func start_cutscene() -> void:
	if cutscene_data.size() > 0:
		show_scene(0)

func show_scene(index: int) -> void:
	if index >= cutscene_data.size():
		show_summary()
		return
	current_scene_index = index
	var scene = cutscene_data[index]
	if scene.has("background"):
		var texture = load(scene["background"])
		if texture:
			background.texture = texture
	current_text = scene["text"]
	displayed_text = ""
	text_label.text = ""
	is_typing = true
	typing_timer = 0.0
	text_container.show()

func complete_current_text() -> void:
	if is_typing:
		displayed_text = current_text
		text_label.text = displayed_text
		is_typing = false
	else:
		show_scene(current_scene_index + 1)

func show_summary() -> void:
	in_summary = true
	text_container.hide()
	skip_button.hide()
	summary_title.text = summary_data["title"]
	summary_text.text = summary_data["text"]
	summary_container.show()
	continue_timer = 0.0

func proceed_to_game() -> void:
	queue_free()  
	get_parent().player_camera.enabled = true
	get_parent().camera_2d_2.enabled = true
	MusicManager.play_song("level1")

func _on_click_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not in_summary:
				complete_current_text()

func _on_skip_pressed() -> void:
	show_summary()

func _on_continue_pressed() -> void:
	proceed_to_game()
