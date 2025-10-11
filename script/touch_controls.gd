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

@onready var synch: Button = $PauseMenu/Panel/synch
@onready var shine: TouchScreenButton = $Control/Control7/shine

var is_paused := false
var pause_enabled: bool = true

func _ready() -> void:
	enable_pause()
	_update_controls_visibility()
	Global.control_type_changed.connect(_on_control_type_changed)
	for node in [pause, pause_menu, option, exit, options]:
		node.process_mode = Node.PROCESS_MODE_ALWAYS
	pause.pressed.connect(_on_pause_pressed)
	option.pressed.connect(_on_option_pressed)
	exit.pressed.connect(_on_exit_pressed)
	synch.pressed.connect(_on_synch_pressed)
	pause_menu.visible = false
	options.visible = false
	control_choice.clear()
	control_choice.add_item("Button", 0)
	control_choice.add_item("Joystick", 1)
	control_choice.select(Global.control_type)
	control_choice.item_selected.connect(_on_control_mode_selected)
	Global.control_type_changed.connect(_sync_with_global)
	_update_synch_button()

func _process(_delta: float) -> void: 
	_update_synch_button() 

func _update_synch_button() -> void: 
	var online = OS.has_feature("network") and SaveManager.current_user_id != "" 
	synch.disabled = not online 

func _on_synch_pressed() -> void: 
	if SaveManager.current_user_id != "": 
		print("🔄 Manual sync triggered") 
		SaveManager.push_all_to_supabase() 
	else: 
		print("⚠️ No logged-in user, cannot sync.")

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
		left.set_process(true)
		right.set_process(true)
		left.set_block_signals(false)
		right.set_block_signals(false)
		virtual_joystick.hide()
		virtual_joystick.set_process(false)
		virtual_joystick.set_block_signals(true)
	else:
		left.visible = false
		right.visible = false
		left.set_process(false)
		right.set_process(false)
		left.set_block_signals(true)
		right.set_block_signals(true)
		virtual_joystick.show()
		virtual_joystick.set_process(true)
		virtual_joystick.set_block_signals(false)
	jump.visible = Global.touchjump
	atk.visible = Global.touchatk
	dash.visible = Global.touchdash
	pause.visible = pause_enabled

func _hide_all_controls() -> void:
	left.visible = false
	right.visible = false
	jump.visible = false
	atk.visible = false
	dash.visible = false
	virtual_joystick.hide()
	virtual_joystick.set_process(false)
	virtual_joystick.set_block_signals(true)

func _on_control_type_changed() -> void:
	if not is_paused:
		_update_controls_visibility()

func _on_pause_pressed() -> void:
	if not pause_enabled:
		return
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

func disable_pause() -> void:
	pause_enabled = false
	pause.set_block_signals(true)
	pause.set_process(false)
	_update_controls_visibility()
	if is_paused:
		_on_pause_pressed()

func enable_pause() -> void:
	pause_enabled = true
	pause.set_block_signals(false)
	pause.set_process(true)
	_update_controls_visibility()

func disable_all_controls() -> void:
	self.visible = false
	set_process(false)
	set_block_signals(true)
	virtual_joystick.hide()
	virtual_joystick.set_process(false)
	virtual_joystick.set_block_signals(true)
