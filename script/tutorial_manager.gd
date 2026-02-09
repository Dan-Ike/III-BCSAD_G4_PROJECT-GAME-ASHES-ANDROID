# tutorial_manager.gd
extends Node

var tutorial_dialogue = null
var tutorial_orb = null
var touch_controls: CanvasLayer = null
var player: Player = null
var tutorial_active: bool = false

enum TutorialStep {
	INTRO,
	MOVE_RIGHT,
	MOVE_LEFT,
	JUMP,
	COMPLETE
}

var current_step: TutorialStep = TutorialStep.INTRO
var move_right_completed: bool = false
var move_left_completed: bool = false
var jump_completed: bool = false

# Tutorial dialogue texts
var dialogues = {
	TutorialStep.INTRO: "Welcome, traveler. Let me teach you the basics of movement.",
	TutorialStep.MOVE_RIGHT: "First, try moving [color=yellow]RIGHT[/color] using the button or joystick.",
	TutorialStep.MOVE_LEFT: "Good! Now try moving [color=yellow]LEFT[/color].",
	TutorialStep.JUMP: "Excellent! Now try to [color=yellow]JUMP[/color].",
	TutorialStep.COMPLETE: "Perfect! You've mastered the basics.\n[color=cyan]Survive and reach the end![/color]"
}

func _ready() -> void:
	print("[Tutorial] TutorialManager _ready() called")
	_initialize_nodes()

func check_and_start_tutorial() -> void:
	print("[Tutorial] check_and_start_tutorial called")
	
	# Initialize nodes if not already done
	if not tutorial_dialogue or not tutorial_orb or not player:
		print("[Tutorial] Initializing nodes...")
		_initialize_nodes()
	
	print("[Tutorial] tutorial_completed: ", SaveManager.get_data().get("tutorial_completed", false))
	
	if _should_run_tutorial():
		print("[Tutorial] Starting tutorial now!")
		start_tutorial()
	else:
		print("[Tutorial] Tutorial already completed, skipping")

func _initialize_nodes() -> void:
	var level = get_parent()
	
	# Get references to tutorial nodes from the level (not as children)
	if level.has_node("tutorial_dialogue"):
		tutorial_dialogue = level.get_node("tutorial_dialogue")
		print("[Tutorial] ✓ TutorialDialogue found")
	else:
		push_error("[Tutorial] ✗ tutorial_dialogue node not found!")

	if level.has_node("tutorial_orb"):
		tutorial_orb = level.get_node("tutorial_orb")
		print("[Tutorial] ✓ TutorialOrb found")
	else:
		push_error("[Tutorial] ✗ tutorial_orb node not found!")
	
	# Get player and touch controls
	if level.has_node("player"):
		player = level.get_node("player")
		print("[Tutorial] ✓ Player found")
	
	if level.has_node("TouchControls"):
		touch_controls = level.get_node("TouchControls")
		print("[Tutorial] ✓ TouchControls found")

func _should_run_tutorial() -> bool:
	# Only run tutorial if it hasn't been completed before
	return not SaveManager.get_data().get("tutorial_completed", false)

func start_tutorial() -> void:
	print("[Tutorial] === START TUTORIAL CALLED ===")
	print("[Tutorial] tutorial_orb: ", tutorial_orb)
	print("[Tutorial] tutorial_dialogue: ", tutorial_dialogue)
	print("[Tutorial] player: ", player)
	if not tutorial_orb or not tutorial_dialogue:
		push_error("[Tutorial] Cannot start tutorial - missing required nodes")
		return
	
	print("[Tutorial] Starting tutorial...")
	tutorial_active = true
	
	# Disable pause during tutorial
	if touch_controls:
		touch_controls.disable_pause()
	
	# Lock all controls except movement
	_lock_controls()
	
	# Position orb near player
	if player:
		tutorial_orb.global_position = player.global_position + Vector2(100, -80)
	
	tutorial_orb.show_orb()
	
	# Start with intro
	await get_tree().create_timer(0.5).timeout
	_show_step(TutorialStep.INTRO)

func _lock_controls() -> void:
	if not touch_controls:
		return
	
	print("[Tutorial] Locking controls...")
	
	# Hide/disable all controls except left, right, jump
	if touch_controls.has_node("Control/Control4/atk"):
		touch_controls.get_node("Control/Control4/atk").visible = false
		touch_controls.get_node("Control/Control4/atk").set_process(false)
	
	if touch_controls.has_node("Control/Control5/dash"):
		touch_controls.get_node("Control/Control5/dash").visible = false
		touch_controls.get_node("Control/Control5/dash").set_process(false)
	
	if touch_controls.has_node("Control/Control7/shine"):
		touch_controls.get_node("Control/Control7/shine").visible = false
		touch_controls.get_node("Control/Control7/shine").set_process(false)
	
	# Initially hide jump until it's needed
	if touch_controls.has_node("Control/Control3/jump"):
		touch_controls.get_node("Control/Control3/jump").visible = false

func _unlock_control(control_name: String) -> void:
	if not touch_controls:
		return
	
	print("[Tutorial] Unlocking control: ", control_name)
	
	match control_name:
		"movement":
			# Show left/right buttons or joystick based on control type
			if Global.is_button_mode():
				if touch_controls.has_node("Control/Control/left"):
					touch_controls.get_node("Control/Control/left").visible = true
					touch_controls.get_node("Control/Control/left").set_process(true)
				if touch_controls.has_node("Control/Control2/right"):
					touch_controls.get_node("Control/Control2/right").visible = true
					touch_controls.get_node("Control/Control2/right").set_process(true)
			else:
				if touch_controls.has_node("Control/Virtual Joystick"):
					var joystick = touch_controls.get_node("Control/Virtual Joystick")
					joystick.visible = true
					joystick.set_process(true)
		
		"jump":
			if touch_controls.has_node("Control/Control3/jump"):
				touch_controls.get_node("Control/Control3/jump").visible = true
				touch_controls.get_node("Control/Control3/jump").set_process(true)

func _show_step(step: TutorialStep) -> void:
	if not tutorial_dialogue:
		return
	
	current_step = step
	
	print("[Tutorial] Showing step: ", TutorialStep.keys()[step])
	
	# Show dialogue for this step
	tutorial_dialogue.show_dialogue(dialogues[step])
	
	# Unlock relevant controls
	match step:
		TutorialStep.MOVE_RIGHT, TutorialStep.MOVE_LEFT:
			_unlock_control("movement")
		TutorialStep.JUMP:
			_unlock_control("jump")
	
	# Wait for dialogue to finish
	await tutorial_dialogue.dialogue_finished
	
	# Handle next action
	if step == TutorialStep.INTRO:
		await get_tree().create_timer(0.5).timeout
		_next_step()
	elif step == TutorialStep.COMPLETE:
		await get_tree().create_timer(2.0).timeout
		_end_tutorial()
	# For other steps, _process will handle advancement

func _process(_delta: float) -> void:
	if not tutorial_active or not player or not tutorial_orb:
		return
	
	# Update orb position to follow player
	if tutorial_orb.visible:
		var target_pos = player.global_position + Vector2(100, -80)
		tutorial_orb.global_position = tutorial_orb.global_position.lerp(target_pos, 0.05)
	
	# Check for step completion
	match current_step:
		TutorialStep.MOVE_RIGHT:
			if Input.is_action_pressed("right") or player.velocity.x > 10:
				if not move_right_completed:
					move_right_completed = true
					print("[Tutorial] Move right completed!")
					_next_step()
		
		TutorialStep.MOVE_LEFT:
			if Input.is_action_pressed("left") or player.velocity.x < -10:
				if not move_left_completed:
					move_left_completed = true
					print("[Tutorial] Move left completed!")
					_next_step()
		
		TutorialStep.JUMP:
			if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("up"):
				if not jump_completed:
					jump_completed = true
					print("[Tutorial] Jump completed!")
					_next_step()

func _next_step() -> void:
	if not tutorial_dialogue:
		return
	
	tutorial_dialogue.hide_dialogue()
	
	match current_step:
		TutorialStep.INTRO:
			await get_tree().create_timer(0.5).timeout
			_show_step(TutorialStep.MOVE_RIGHT)
		TutorialStep.MOVE_RIGHT:
			await get_tree().create_timer(0.5).timeout
			_show_step(TutorialStep.MOVE_LEFT)
		TutorialStep.MOVE_LEFT:
			await get_tree().create_timer(0.5).timeout
			_show_step(TutorialStep.JUMP)
		TutorialStep.JUMP:
			await get_tree().create_timer(0.5).timeout
			_show_step(TutorialStep.COMPLETE)

func _end_tutorial() -> void:
	print("[Tutorial] Ending tutorial...")
	tutorial_active = false
	
	if tutorial_dialogue:
		tutorial_dialogue.hide_dialogue()
	
	if tutorial_orb:
		tutorial_orb.hide_orb()
	
	# Unlock all controls
	if touch_controls:
		touch_controls.enable_pause()
		
		# Re-enable all controls based on Global settings
		if touch_controls.has_node("Control/Control4/atk"):
			touch_controls.get_node("Control/Control4/atk").visible = Global.touchatk
			touch_controls.get_node("Control/Control4/atk").set_process(Global.touchatk)
		
		if touch_controls.has_node("Control/Control5/dash"):
			touch_controls.get_node("Control/Control5/dash").visible = Global.touchdash
			touch_controls.get_node("Control/Control5/dash").set_process(Global.touchdash)
		
		if touch_controls.has_node("Control/Control7/shine"):
			touch_controls.get_node("Control/Control7/shine").visible = Global.touchshine
			touch_controls.get_node("Control/Control7/shine").set_process(Global.touchshine)
	
	# Save that tutorial is completed
	SaveManager.get_data()["tutorial_completed"] = true
	SaveManager.save()
	
	print("[Tutorial] Tutorial completed and saved!")
