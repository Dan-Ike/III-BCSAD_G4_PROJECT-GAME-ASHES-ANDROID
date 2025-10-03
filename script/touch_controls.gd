extends CanvasLayer

@onready var left: TouchScreenButton = $Control/Control/left
@onready var right: TouchScreenButton = $Control/Control2/right
@onready var jump: TouchScreenButton = $Control/Control3/jump
@onready var atk: TouchScreenButton = $Control/Control4/atk
@onready var dash: TouchScreenButton = $Control/Control5/dash
@onready var pause: TouchScreenButton = $Control/Control6/pause
@onready var pause_menu: Control = $PauseMenu
@onready var option: Button = $PauseMenu/Panel/option
@onready var exit: Button = $PauseMenu/Panel/exit
@onready var options: Panel = $Options
@onready var virtual_joystick: VirtualJoystick = $"Control/Virtual Joystick"
@onready var control_choice: OptionButton = $Options/ControlChoice

var is_paused := false

func _ready() -> void:
	_update_controls_visibility()
	Global.control_type_changed.connect(_on_control_type_changed)
	for node in [pause, pause_menu, option, exit, options]:
		node.process_mode = Node.PROCESS_MODE_ALWAYS
	pause.pressed.connect(_on_pause_pressed)
	option.pressed.connect(_on_option_pressed)
	exit.pressed.connect(_on_exit_pressed)
	pause_menu.visible = false
	options.visible = false
	control_choice.clear()
	control_choice.add_item("Button", 0)
	control_choice.add_item("Joystick", 1)
	control_choice.select(Global.control_type)
	control_choice.item_selected.connect(_on_control_mode_selected)
	Global.control_type_changed.connect(_sync_with_global)

func _on_control_mode_selected(index: int) -> void:
	Global.set_control_type(index)

func _sync_with_global() -> void:
	control_choice.select(Global.control_type)

func _update_controls_visibility() -> void:
	if is_paused:
		_hide_all_controls()
		return
	if Global.is_button_mode():
		left.visible = Global.touchleft
		right.visible = Global.touchright
		virtual_joystick.visible = false
	else:
		left.visible = false
		right.visible = false
		virtual_joystick.visible = true   
	jump.visible = Global.touchjump
	atk.visible = Global.touchatk
	dash.visible = Global.touchdash

func _hide_all_controls() -> void:
	left.visible = false
	right.visible = false
	jump.visible = false
	atk.visible = false
	dash.visible = false
	virtual_joystick.visible = false

func _on_control_type_changed() -> void:
	if not is_paused:
		_update_controls_visibility()

func _on_pause_pressed() -> void:
	is_paused = !is_paused
	
	if is_paused:
		get_tree().paused = true
		pause_menu.visible = true
		_hide_all_controls()
	else:
		get_tree().paused = false
		pause_menu.visible = false
		options.visible = false  
		_update_controls_visibility() 

func _on_exit_pressed() -> void:
	get_tree().paused = false 
	MusicManager.stop_song()
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")

func _on_back_pressed() -> void:
	pause_menu.visible = true
	options.visible = false

func _on_option_pressed() -> void:
	pause_menu.visible = false
	options.visible = true
