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
@onready var resume: Button = $PauseMenu/Panel/resume
@onready var options: Panel = $Options
@onready var virtual_joystick: VirtualJoystick = $"Control/Virtual Joystick"
@onready var control_choice: OptionButton = $Options/ControlChoice
@onready var edit: Button = $Options/edit

@onready var shine: TouchScreenButton = $Control/Control7/shine

@onready var hud: Control = $HUD
@onready var health_bar_simple: Control = $HUD/HealthBarSimple
@onready var health_bar_advanced: Control = $HUD/HealthBarAdvanced

var is_paused := false
var pause_enabled: bool = true

func _ready() -> void:
	enable_pause()
	_load_custom_layout()
	_update_controls_visibility()
	_setup_health_bars()
	Global.control_type_changed.connect(_on_control_type_changed)
	
	for node in [pause, pause_menu, option, exit, options]:
		node.process_mode = Node.PROCESS_MODE_ALWAYS
	
	pause.pressed.connect(_on_pause_pressed)
	option.pressed.connect(_on_option_pressed)
	exit.pressed.connect(_on_exit_pressed)
	resume.pressed.connect(_on_resume_pressed)
	edit.pressed.connect(_on_edit_pressed)
	
	pause_menu.visible = false
	options.visible = false
	
	control_choice.clear()
	control_choice.add_item("Button", 0)
	control_choice.add_item("Joystick", 1)
	control_choice.select(Global.control_type)
	control_choice.item_selected.connect(_on_control_mode_selected)
	Global.control_type_changed.connect(_sync_with_global)

func _setup_health_bars() -> void:
	# Check if player has reached floor 2 or above
	var reached_floor_2 = _has_reached_floor_2()
	
	if health_bar_simple and health_bar_advanced:
		# If player has reached floor 2, always show advanced bar
		if reached_floor_2:
			health_bar_simple.visible = false
			health_bar_advanced.visible = true
			print("[TouchControls] Player reached Floor 2+ - showing advanced health bar")
		else:
			# Show based on current soul light state
			health_bar_simple.visible = not Global.soul_light_enabled
			health_bar_advanced.visible = Global.soul_light_enabled
			print("[TouchControls] Still on Floor 1 - showing simple health bar")

func _has_reached_floor_2() -> bool:
	# Check if player's highest floor is 2 or above
	if SaveManager.data["progress"]["current_floor"] >= 2:
		return true
	
	# Also check completed levels - if any level from floor 2+ is completed
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
	if health_bar_simple and health_bar_advanced:
		# If player has reached floor 2, always show advanced bar
		if _has_reached_floor_2():
			health_bar_simple.visible = false
			health_bar_advanced.visible = true
		else:
			health_bar_simple.visible = not show_soul_light
			health_bar_advanced.visible = show_soul_light

func _load_custom_layout() -> void:
	var layout = SaveManager.get_control_layout()
	if layout.size() == 0:
		print("[TouchControls] No custom layout found, using defaults")
		return
	
	print("[TouchControls] Loading custom layout")
	
	# Apply layout to the PARENT Control nodes, not the buttons themselves
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

# Fixed: Removed strict type hint - accepts any Node that has position and scale
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
	
	print("[TouchControls] Applied layout to %s: pos=%s, rotation=%s, scale=%s" % [
		control.name, 
		control.position,
		control.rotation_degrees,
		control.scale
	])

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel") and pause_enabled:
		_on_pause_pressed()

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
	shine.visible = Global.touchshine
	pause.visible = pause_enabled

func _hide_all_controls() -> void:
	left.visible = false
	right.visible = false
	jump.visible = false
	atk.visible = false
	dash.visible = false
	shine.visible = false
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

func _on_resume_pressed() -> void:
	_on_pause_pressed()

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

func _on_edit_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/controls_editor.tscn")
