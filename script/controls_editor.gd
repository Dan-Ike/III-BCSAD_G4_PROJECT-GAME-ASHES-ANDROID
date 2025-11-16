extends Control

@onready var top_bar: HBoxContainer = $TopBar
@onready var zoom_in: Button = $TopBar/ZoomIn
@onready var zoom_out: Button = $TopBar/ZoomOut
@onready var rotate_left: Button = $TopBar/RotateLeft
@onready var rotate_right: Button = $TopBar/RotateRight
@onready var reset: Button = $TopBar/Reset
@onready var undo: Button = $TopBar/Undo
@onready var save_btn: Button = $TopBar/Save
@onready var back: Button = $TopBar/Back
@onready var confirm_dialog: ConfirmationDialog = $ConfirmDialog

# The actual control nodes from your scene
@onready var control: Control = $Control
@onready var control_left: Control = $Control/Control
@onready var left: TouchScreenButton = $Control/Control/left
@onready var control_right: Control = $Control/Control2
@onready var right: TouchScreenButton = $Control/Control2/right
@onready var control_jump: Control = $Control/Control3
@onready var jump: TouchScreenButton = $Control/Control3/jump
@onready var control_atk: Control = $Control/Control4
@onready var atk: TouchScreenButton = $Control/Control4/atk
@onready var control_dash: Control = $Control/Control5
@onready var dash: TouchScreenButton = $Control/Control5/dash
@onready var control_shine: Control = $Control/Control7
@onready var shine: TouchScreenButton = $Control/Control7/shine
@onready var control_6: Control = $Control/Control6
@onready var virtual_joystick: VirtualJoystick = $"Control/Virtual Joystick"


var editable_controls: Dictionary = {}
var button_data: Dictionary = {}
var history: Array = []
var dragging_control: Control = null
var drag_offset: Vector2 = Vector2.ZERO
var resizing_control: Control = null
var selected_control: Control = null

const ROTATION_STEP = 15.0

# Default layout - using your actual TouchControls positions
var default_layout = {
	"left": {"x": 52, "y": 516, "rotation": 0, "scale": 1.0},
	"right": {"x": 218, "y": 516, "rotation": 0, "scale": 1.0},
	"jump": {"x": 887, "y": 516, "rotation": 0, "scale": 1.0},
	"atk": {"x": 1031, "y": 446, "rotation": 0, "scale": 1.0},
	"dash": {"x": 746, "y": 446, "rotation": 0, "scale": 1.0},
	"shine": {"x": 887, "y": 343, "rotation": 0, "scale": 1.0},
	"joystick": {"x": 19, "y": 413, "rotation": 0, "scale": 1.0}
}

func _ready() -> void:
	print("[ControlsEditor] Starting _ready()")
	
	# CRITICAL: Hide the actual gameplay TouchControls
	var touch_controls = get_tree().get_first_node_in_group("touch_controls")
	if touch_controls:
		touch_controls.hide_for_editor()
		print("[ControlsEditor] Hid gameplay TouchControls")
	
	# CRITICAL: Set proper pause modes
	process_mode = Node.PROCESS_MODE_ALWAYS
	if top_bar:
		top_bar.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# CRITICAL: Ensure top bar is in front
	if top_bar:
		top_bar.z_index = 1000
		top_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Make sure control doesn't block top bar
	if control:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_setup_signals()
	_load_layout()
	_setup_editable_controls()
	_apply_loaded_layout()
	
	print("[ControlsEditor] Ready complete")

func _setup_signals() -> void:
	print("[ControlsEditor] Setting up signals...")
	
	if zoom_in:
		print("  - Connecting zoom_in")
		zoom_in.disabled = false
		zoom_in.mouse_filter = Control.MOUSE_FILTER_STOP
		zoom_in.pressed.connect(_on_zoom_in)
	else:
		print("  - WARNING: zoom_in is null!")
	
	if zoom_out:
		print("  - Connecting zoom_out")
		zoom_out.disabled = false
		zoom_out.mouse_filter = Control.MOUSE_FILTER_STOP
		zoom_out.pressed.connect(_on_zoom_out)
	else:
		print("  - WARNING: zoom_out is null!")
	
	if rotate_left:
		print("  - Connecting rotate_left")
		rotate_left.disabled = false
		rotate_left.mouse_filter = Control.MOUSE_FILTER_STOP
		rotate_left.pressed.connect(_on_rotate_left)
	else:
		print("  - WARNING: rotate_left is null!")
	
	if rotate_right:
		print("  - Connecting rotate_right")
		rotate_right.disabled = false
		rotate_right.mouse_filter = Control.MOUSE_FILTER_STOP
		rotate_right.pressed.connect(_on_rotate_right)
	else:
		print("  - WARNING: rotate_right is null!")
	
	if reset:
		print("  - Connecting reset")
		reset.disabled = false
		reset.mouse_filter = Control.MOUSE_FILTER_STOP
		reset.pressed.connect(_on_reset)
	else:
		print("  - WARNING: reset is null!")
	
	if undo:
		print("  - Connecting undo")
		undo.disabled = false
		undo.mouse_filter = Control.MOUSE_FILTER_STOP
		undo.pressed.connect(_on_undo)
	else:
		print("  - WARNING: undo is null!")
	
	if save_btn:
		print("  - Connecting save_btn")
		save_btn.disabled = false
		save_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		save_btn.pressed.connect(_on_save_pressed)
	else:
		print("  - WARNING: save_btn is null!")
	
	if back:
		print("  - Connecting back")
		back.disabled = false
		back.mouse_filter = Control.MOUSE_FILTER_STOP
		back.pressed.connect(_on_back)
	else:
		print("  - WARNING: back is null!")
	
	if confirm_dialog:
		print("  - Connecting confirm_dialog")
		confirm_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
		confirm_dialog.confirmed.connect(_on_save_confirmed)
	else:
		print("  - WARNING: confirm_dialog is null!")

func _setup_editable_controls() -> void:
	# Hide all controls first and disable their input
	if control_left:
		control_left.visible = false
		control_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if control_right:
		control_right.visible = false
		control_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if control_6:
		control_6.visible = false
		control_6.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if control_jump:
		control_jump.visible = false
		control_jump.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if control_atk:
		control_atk.visible = false
		control_atk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if control_dash:
		control_dash.visible = false
		control_dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if control_shine:
		control_shine.visible = false
		control_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# CRITICAL: Hide virtual joystick explicitly
	if virtual_joystick:
		virtual_joystick.visible = false
		virtual_joystick.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Disable TouchScreenButtons from receiving input
	if left:
		left.process_mode = Node.PROCESS_MODE_DISABLED
	if right:
		right.process_mode = Node.PROCESS_MODE_DISABLED
	if jump:
		jump.process_mode = Node.PROCESS_MODE_DISABLED
	if atk:
		atk.process_mode = Node.PROCESS_MODE_DISABLED
	if dash:
		dash.process_mode = Node.PROCESS_MODE_DISABLED
	if shine:
		shine.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Only show and make editable the enabled controls
	if Global.is_button_mode():
		if Global.touchleft and control_left:
			control_left.visible = true
			editable_controls["left"] = control_left
			_make_control_editable(control_left, "left")
		if Global.touchright and control_right:
			control_right.visible = true
			editable_controls["right"] = control_right
			_make_control_editable(control_right, "right")
		
		# ENSURE joystick stays hidden in button mode
		if virtual_joystick:
			virtual_joystick.visible = false
		if control_6:
			control_6.visible = false
	else:
		# Joystick mode
		if control_6 and virtual_joystick:
			control_6.visible = true
			virtual_joystick.visible = true
			
			# Get joystick's actual size
			var joystick_size = virtual_joystick.size
			if joystick_size == Vector2.ZERO:
				joystick_size = Vector2(150, 150)  # Fallback size
			
			# Force control_6 to be the right size
			control_6.custom_minimum_size = joystick_size
			control_6.size = joystick_size
			
			# Add a transparent clickable panel that covers the entire area
			var click_overlay = ColorRect.new()
			click_overlay.name = "ClickOverlay"
			click_overlay.color = Color(0, 0, 0, 0)  # Fully transparent
			click_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
			click_overlay.size = joystick_size
			click_overlay.position = Vector2.ZERO
			click_overlay.z_index = 5  # Above joystick, below border
			control_6.add_child(click_overlay)
			
			# Put joystick behind and disable its input completely
			virtual_joystick.position = Vector2.ZERO
			virtual_joystick.z_index = -10
			virtual_joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			# Disable all children of joystick too
			for child in virtual_joystick.get_children():
				if child is Control:
					child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			control_6.mouse_filter = Control.MOUSE_FILTER_STOP
			editable_controls["joystick"] = control_6
			_make_control_editable(control_6, "joystick")
	
	if Global.touchjump and control_jump:
		control_jump.visible = true
		editable_controls["jump"] = control_jump
		_make_control_editable(control_jump, "jump")
	if Global.touchatk and control_atk:
		control_atk.visible = true
		editable_controls["atk"] = control_atk
		_make_control_editable(control_atk, "atk")
	if Global.touchdash and control_dash:
		control_dash.visible = true
		editable_controls["dash"] = control_dash
		_make_control_editable(control_dash, "dash")
	if Global.touchshine and control_shine:
		control_shine.visible = true
		editable_controls["shine"] = control_shine
		_make_control_editable(control_shine, "shine")
	
func _make_control_editable(ctrl: Control, id: String) -> void:
	# Make sure the control can receive input
	ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	ctrl.z_index = 10  # Below top bar but above background
	
	# Add visual border
	var border = Panel.new()
	border.name = "EditBorder"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.z_index = -1  # Put behind content
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.4, 0.6, 1.0, 0.8)
	border.add_theme_stylebox_override("panel", style)
	
	ctrl.add_child(border)
	ctrl.move_child(border, 0)  # Put border behind everything
	
	# Add resize handle
	var resize_handle = Button.new()
	resize_handle.text = "◢"
	resize_handle.custom_minimum_size = Vector2(40, 40)  # Bigger for touch
	resize_handle.name = "ResizeHandle"
	resize_handle.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	resize_handle.offset_left = -40
	resize_handle.offset_top = -40
	resize_handle.z_index = 100
	resize_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# For touch devices, we need both pressed and gui_input
	resize_handle.gui_input.connect(_on_resize_handle_input.bind(ctrl))
	ctrl.add_child(resize_handle)
	
	# Connect input for touch/mouse
	ctrl.gui_input.connect(_on_control_gui_input.bind(ctrl, id))

func _on_control_gui_input(event: InputEvent, ctrl: Control, id: String) -> void:
	# Handle both mouse and touch input
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		var is_pressed = false
		if event is InputEventMouseButton:
			is_pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		elif event is InputEventScreenTouch:
			is_pressed = event.pressed
		
		if is_pressed:
			_save_history()
			dragging_control = ctrl
			selected_control = ctrl
			_highlight_selected(ctrl)
			# Store the offset in parent's coordinate space
			if event is InputEventMouseButton:
				drag_offset = ctrl.get_global_mouse_position() - ctrl.global_position
			elif event is InputEventScreenTouch:
				drag_offset = Vector2(event.position.x, event.position.y) - ctrl.global_position
		else:
			dragging_control = null
	
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if dragging_control == ctrl and not resizing_control:
			# Use global position for smooth dragging regardless of rotation/scale
			var target_pos = ctrl.get_global_mouse_position() - drag_offset
			ctrl.global_position = target_pos

func _on_resize_handle_input(event: InputEvent, ctrl: Control) -> void:
	# Handle both mouse and touch for resizing
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		var is_pressed = false
		if event is InputEventMouseButton:
			is_pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		elif event is InputEventScreenTouch:
			is_pressed = event.pressed
		
		if is_pressed:
			_save_history()
			resizing_control = ctrl
			selected_control = ctrl
			_highlight_selected(ctrl)
		else:
			resizing_control = null
	
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if resizing_control == ctrl:
			var scale_change = event.relative.x * 0.005
			var new_scale = clamp(ctrl.scale.x + scale_change, 0.5, 3.0)
			ctrl.scale = Vector2(new_scale, new_scale)

func _input(event: InputEvent) -> void:
	if resizing_control and event is InputEventMouseMotion:
		var scale_change = event.relative.x * 0.005
		var new_scale = clamp(resizing_control.scale.x + scale_change, 0.5, 3.0)
		resizing_control.scale = Vector2(new_scale, new_scale)
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			resizing_control = null

func _highlight_selected(ctrl: Control) -> void:
	for control in editable_controls.values():
		var border = control.get_node_or_null("EditBorder")
		if border:
			var style = border.get_theme_stylebox("panel").duplicate()
			if control == ctrl:
				style.border_color = Color(1.0, 0.8, 0.0, 1.0)  # Yellow for selected
			else:
				style.border_color = Color(0.4, 0.6, 1.0, 0.8)  # Blue for unselected
			border.add_theme_stylebox_override("panel", style)

func _on_rotate_left() -> void:
	print("[ControlsEditor] Rotate Left clicked!")
	if selected_control:
		_save_history()
		selected_control.rotation_degrees -= ROTATION_STEP
		print("  - Rotated control to: ", selected_control.rotation_degrees)
	else:
		print("  - No control selected")

func _on_rotate_right() -> void:
	print("[ControlsEditor] Rotate Right clicked!")
	if selected_control:
		_save_history()
		selected_control.rotation_degrees += ROTATION_STEP
		print("  - Rotated control to: ", selected_control.rotation_degrees)
	else:
		print("  - No control selected")

func _on_zoom_in() -> void:
	print("[ControlsEditor] Zoom In clicked!")
	if selected_control:
		_save_history()
		var new_scale = clamp(selected_control.scale.x + 0.1, 0.5, 3.0)
		selected_control.scale = Vector2(new_scale, new_scale)
		print("  - Scaled control to: ", new_scale)
	else:
		print("  - No control selected")

func _on_zoom_out() -> void:
	print("[ControlsEditor] Zoom Out clicked!")
	if selected_control:
		_save_history()
		var new_scale = clamp(selected_control.scale.x - 0.1, 0.5, 3.0)
		selected_control.scale = Vector2(new_scale, new_scale)
		print("  - Scaled control to: ", new_scale)
	else:
		print("  - No control selected")

func _on_reset() -> void:
	print("[ControlsEditor] Reset clicked!")
	_save_history()
	for id in editable_controls:
		var ctrl = editable_controls[id]
		var default_data = default_layout.get(id, {})
		if default_data.size() > 0:
			ctrl.position = Vector2(default_data.get("x", 100), default_data.get("y", 100))
			ctrl.rotation_degrees = default_data.get("rotation", 0)
			var scale_val = default_data.get("scale", 1.0)
			ctrl.scale = Vector2(scale_val, scale_val)

func _save_history() -> void:
	var state = {}
	for id in editable_controls:
		var ctrl = editable_controls[id]
		state[id] = {
			"position": ctrl.position,
			"rotation": ctrl.rotation_degrees,
			"scale": ctrl.scale.x
		}
	history.append(state)
	if history.size() > 20:
		history.pop_front()

func _on_undo() -> void:
	print("[ControlsEditor] Undo clicked!")
	if history.size() > 0:
		var state = history.pop_back()
		for id in editable_controls:
			if state.has(id):
				var ctrl = editable_controls[id]
				ctrl.position = state[id]["position"]
				ctrl.rotation_degrees = state[id]["rotation"]
				ctrl.scale = Vector2(state[id]["scale"], state[id]["scale"])
		print("  - Undid to previous state")
	else:
		print("  - No history to undo")

func _on_save_pressed() -> void:
	print("[ControlsEditor] Save clicked!")
	confirm_dialog.popup_centered()

func _on_save_confirmed() -> void:
	print("[ControlsEditor] Save confirmed!")
	_save_layout()
	get_tree().paused = false
	#get_tree().change_scene_to_file("res://path/to/previous/scene.tscn")  

func _on_back() -> void:
	print("[ControlsEditor] Back clicked!")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")  

func _save_layout() -> void:
	var layout = {}
	for id in editable_controls:
		var ctrl = editable_controls[id]
		layout[id] = {
			"x": ctrl.position.x,
			"y": ctrl.position.y,
			"rotation": ctrl.rotation_degrees,
			"scale": ctrl.scale.x
		}
	
	SaveManager.save_control_layout(layout)
	print("[ControlsEditor] Layout saved: ", layout)

func _load_layout() -> void:
	button_data = SaveManager.get_control_layout()
	if button_data.size() == 0:
		print("[ControlsEditor] No saved layout, using defaults")
	else:
		print("[ControlsEditor] Loaded layout: ", button_data)

func _apply_loaded_layout() -> void:
	if confirm_dialog:
		confirm_dialog.dialog_text = "Are you sure you want to save this layout?"
		confirm_dialog.title = "Save Layout"
	for id in editable_controls:
		var ctrl = editable_controls[id]
		var layout_data = button_data.get(id, default_layout.get(id, {}))
		if layout_data.size() > 0:
			ctrl.position = Vector2(layout_data.get("x", 100), layout_data.get("y", 100))
			ctrl.rotation_degrees = layout_data.get("rotation", 0)
			var scale_val = layout_data.get("scale", 1.0)
			ctrl.scale = Vector2(scale_val, scale_val)
