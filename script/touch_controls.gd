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
#@onready var resume: Button = $PauseMenu/Panel/resume
#@onready var options: Panel = $Options
@onready var virtual_joystick: VirtualJoystick = $"Control/Virtual Joystick"
#@onready var control_choice: OptionButton = $Options/ControlChoice
@onready var edit: Button = $Options/edit
@onready var shine: TouchScreenButton = $Control/Control7/shine
@onready var settings_btn: TouchScreenButton = $Control/Control8/settings

@onready var hud: Control = $HUD
@onready var health_bar_simple: Control = $HUD/HealthBarSimple
@onready var health_bar_advanced: Control = $HUD/HealthBarAdvanced
@onready var hud_boss: Control = $HUDBoss
@onready var health_bar_boss: Control = $HUDBoss/HealthBarBoss

@onready var back_exit: TouchScreenButton = $PauseMenu/Control3/back_exit
@onready var retry: TouchScreenButton = $PauseMenu/Control4/retry
@onready var resume: TouchScreenButton = $PauseMenu/Control5/resume
@onready var main_menu: TouchScreenButton = $PauseMenu/Control6/main_menu

@onready var back: TouchScreenButton = $Settings/Control/back
@onready var settings: Control = $Settings
@onready var control_choice: OptionButton = $Settings/ControlChoice


var is_paused := false
var pause_enabled: bool = true

func delayed_action(delay: float, action: Callable) -> void:
	await get_tree().create_timer(delay).timeout
	action.call()

func _on_control_type_changed() -> void:
	if not is_paused:
		_update_controls_visibility()

func _ready() -> void:
	add_to_group("touch_controls")
	enable_pause()
	_load_custom_layout()
	_update_controls_visibility()
	_setup_health_bars()
	Global.control_type_changed.connect(_on_control_type_changed)
	
	# Always process pause-related nodes
	for node in [pause, settings_btn, pause_menu, option, exit, settings]:
		node.process_mode = Node.PROCESS_MODE_ALWAYS

	#pause.pressed.connect(_on_pause_pressed)
	#settings_btn.pressed.connect(_on_option_pressed)
	back.pressed.connect(_on_back_settings_pressed)
	option.pressed.connect(_on_option_pressed)
	exit.pressed.connect(_on_exit_pressed)
	resume.pressed.connect(_on_resume_pressed)
	edit.pressed.connect(_on_edit_pressed)

	# Connect left/right buttons for haptic
	left.pressed.connect(_on_left_pressed)
	left.released.connect(_on_left_released)
	right.pressed.connect(_on_right_pressed)
	right.released.connect(_on_right_released)

	pause_menu.visible = false
	settings.visible = false
	
	
	control_choice.clear()
	control_choice.add_item("Button", 0)
	control_choice.add_item("Joystick", 1)
	#control_choice.add_item("Controller", 2)
	control_choice.select(Global.control_type)
	control_choice.item_selected.connect(_on_control_mode_selected)
	Global.control_type_changed.connect(_sync_with_global)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed = false
		var pos = Vector2.ZERO
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			pressed = true
			pos = event.position
		elif event is InputEventScreenTouch and event.pressed:
			pressed = true
			pos = event.position
		
		if pressed:
			if pause.visible and pause.get_parent().get_global_rect().has_point(pos):
				_on_pause_pressed()
				return
			if settings_btn.visible and settings_btn.get_parent().get_global_rect().has_point(pos):
				_on_option_pressed()
				return

# ---------------------------
# HAPTIC FEEDBACK FUNCTIONS
# ---------------------------
func _on_left_pressed() -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(20)  # 20 ms vibration
	Input.action_press("left")

func _on_left_released() -> void:
	Input.action_release("left")

func _on_right_pressed() -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(20)  # 20 ms vibration
	Input.action_press("right")

func _on_right_released() -> void:
	Input.action_release("right")

# ---------------------------
# HEALTH BAR SETUP
# ---------------------------
func _setup_health_bars() -> void:
	var reached_floor_2 = _has_reached_floor_2()
	if health_bar_simple and health_bar_advanced:
		if reached_floor_2:
			health_bar_simple.visible = false
			health_bar_advanced.visible = true
		else:
			health_bar_simple.visible = not Global.soul_light_enabled
			health_bar_advanced.visible = Global.soul_light_enabled

func _has_reached_floor_2() -> bool:
	if SaveManager.data["progress"]["current_floor"] >= 2:
		return true
	var completed_levels = SaveManager.data["progress"].get("completed_levels", {})
	for key in completed_levels:
		if completed_levels[key]:
			var parts = key.split("_")
			if parts.size() == 2:
				var floor = int(parts[0])
				if floor >= 2:
					return true
	return false

func switch_health_bar_mode(show_soul_light: bool) -> void:
	if _has_reached_floor_2():
		health_bar_simple.visible = false
		health_bar_advanced.visible = true
	else:
		health_bar_simple.visible = not show_soul_light
		health_bar_advanced.visible = show_soul_light

# ---------------------------
# CUSTOM CONTROL LAYOUT
# ---------------------------
func _load_custom_layout() -> void:
	var layout = SaveManager.get_control_layout()
	if layout.size() == 0:
		return
	if layout.has("left"):
		_apply_layout_to_control(left.get_parent(), layout.get("left", {}))
	if layout.has("right"):
		_apply_layout_to_control(right.get_parent(), layout.get("right", {}))
	if layout.has("jump"):
		_apply_layout_to_control(jump.get_parent(), layout.get("jump", {}))
	if layout.has("atk"):
		_apply_layout_to_control(atk.get_parent(), layout.get("atk", {}))
	if layout.has("dash"):
		_apply_layout_to_control(dash.get_parent(), layout.get("dash", {}))
	if layout.has("shine"):
		_apply_layout_to_control(shine.get_parent(), layout.get("shine", {}))
	if layout.has("joystick"):
		_apply_layout_to_control(virtual_joystick, layout.get("joystick", {}))

func _apply_layout_to_control(control, layout_data: Dictionary) -> void:
	if not control or layout_data.size() == 0:
		return
	if layout_data.has("x") and layout_data.has("y"):
		control.position = Vector2(layout_data["x"], layout_data["y"])
	if layout_data.has("rotation"):
		control.rotation_degrees = layout_data["rotation"]
	if layout_data.has("scale"):
		var scale_val = layout_data["scale"]
		control.scale = Vector2(scale_val, scale_val)

# ---------------------------
# PROCESS & INPUT
# ---------------------------
func _process(_delta: float) -> void:
	if settings.visible:
		return
	if is_paused:
		return
	if Input.is_action_just_pressed("ui_cancel") and pause_enabled:
		_on_pause_pressed()
	if Input.is_action_just_pressed("pause") and pause_enabled:
		_on_pause_pressed()
	if Input.is_action_just_pressed("settings") and pause_enabled and not is_paused:
		_on_option_pressed()

func _on_back_settings_pressed() -> void:
	delayed_action(0.2, func():
		is_paused = false
		get_tree().paused = false
		settings.visible = false
		pause_menu.visible = false
		_update_controls_visibility()
	)

func _on_control_mode_selected(index: int) -> void:
	Global.set_control_type(index)

func _sync_with_global() -> void:
	control_choice.select(Global.control_type)

func _update_controls_visibility() -> void:
	if is_paused:
		_hide_all_controls()
		return
	if Global.control_type == 2:
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
	shine.visible = Global.touchshine
	pause.visible = pause_enabled
	settings_btn.visible = pause_enabled
	settings.visible = false

func hide_for_editor() -> void:
	self.visible = false
	virtual_joystick.visible = false
	virtual_joystick.set_process(false)

func _hide_all_controls() -> void:
	for node in [left, right, jump, atk, dash, shine]:
		node.visible = false
	virtual_joystick.hide()
	virtual_joystick.set_process(false)
	virtual_joystick.set_block_signals(true)
	pause.visible = false
	settings_btn.visible = false

# ---------------------------
# PAUSE MENU HANDLERS
# ---------------------------
func _on_pause_pressed() -> void:
	delayed_action(0.2, func():
		if Global.cutscene_playing:
			return
		if not pause_enabled:
			return
		is_paused = !is_paused
		get_tree().paused = is_paused
		pause_menu.visible = is_paused
		settings.visible = false
		if is_paused:
			_hide_all_controls()
		else:
			_update_controls_visibility()
	)
func _on_resume_pressed() -> void:
	delayed_action(0.2, func():
		_on_pause_pressed()
	)

func _on_exit_pressed() -> void:
	delayed_action(0.2, func():
		get_tree().paused = false 
		MusicManager.stop_song()
		get_tree().change_scene_to_file("res://scene/main_menu.tscn")
	)

func _on_option_pressed() -> void:
	if Global.cutscene_playing:
		return
	if not pause_enabled:
		return
	if is_paused:
		return
	is_paused = true
	delayed_action(0.2, func():
		get_tree().paused = true
		settings.visible = true
		pause_menu.visible = false
		_hide_all_controls()
		pause.visible = false
		settings_btn.visible = false
	)

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
	
	# Also hide pause menu and disable pause button
	pause_menu.visible = false
	settings.visible = false
	pause.visible = false
	pause.set_process(false)
	pause.set_block_signals(true)
	pause_enabled = false

func _on_edit_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/controls_editor.tscn")


func _on_retry_pressed() -> void:
	delayed_action(0.2, func():
	
		# Set retry flag BEFORE reloading
		Global.set_retrying(true)
		Global.is_retrying_level = true
		
		# Unpause and reload current scene
		get_tree().paused = false
		is_paused = false
		pause_menu.visible = false
		settings.visible = false
		
		# Reload the current scene (this will reset everything including timer)
		get_tree().reload_current_scene()
	)
