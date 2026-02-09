# tutorial_manager.gd
extends Node

@onready var tutorial_dialogue: CanvasLayer = $TutorialDialogue
@onready var tutorial_orb: Node2D = $TutorialOrb
@onready var touch_controls = get_tree().get_first_node_in_group("touch_controls")

enum TutorialStep {
	INTRO,
	MOVE_RIGHT,
	MOVE_LEFT,
	JUMP,
	COMPLETE
}

var current_step: TutorialStep = TutorialStep.INTRO
var player: CharacterBody2D = null
var tutorial_active: bool = false
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
	# Wait for scene to be ready
	await get_tree().process_frame
	
	# Get player reference
	if Global.playerBody:
		player = Global.playerBody
	
	# Start tutorial
	start_tutorial()

func start_tutorial() -> void:
	tutorial_active = true
	
	# Disable pause during tutorial
	if touch_controls:
		touch_controls.disable_pause()
	
	# Lock all controls except movement
	_lock_controls()
	
	# Position orb near player
	if player:
		tutorial_orb.global_position = player.global_position + Vector2(50, -80)
	
	tutorial_orb.show_orb()
	
	# Start with intro
	await get_tree().create_timer(0.5).timeout
	_show_step(TutorialStep.INTRO)

func _lock_controls() -> void:
	if not touch_controls:
		return
	
	# Hide/disable all controls except left, right, jump
	if touch_controls.has_node("Control/Control4/atk"):
		touch_controls.get_node("Control/Control4/atk").visible = false
	if touch_controls.has_node("Control/Control5/dash"):
		touch_controls.get_node("Control/Control5/dash").visible = false
	if touch_controls.has_node("Control/Control7/shine"):
		touch_controls.get_node("Control/Control7/shine").visible = false
	
	# Initially hide jump until it's needed
	if touch_controls.has_node("Control/Control3/jump"):
		touch_controls.get_node("Control/Control3/jump").visible = false

func _unlock_control(control_name: String) -> void:
	if not touch_controls:
		return
	
	match control_name:
		"left":
			if touch_controls.has_node("Control/Control/left"):
				touch_controls.get_node("Control/Control/left").visible = true
		"right":
			if touch_controls.has_node("Control/Control2/right"):
				touch_controls.get_node("Control/Control2/right").visible = true
		"jump":
			if touch_controls.has_node("Control/Control3/jump"):
				touch_controls.get_node("Control/Control3/jump").visible = true
		"joystick":
			if touch_controls.has_node("Control/Virtual Joystick"):
				touch_controls.get_node("Control/Virtual Joystick").visible = true

func _show_step(step: TutorialStep) -> void:
	current_step = step
	
	# Show dialogue for this step
	tutorial_dialogue.show_dialogue(dialogues[step])
	
	# Unlock relevant controls
	match step:
		TutorialStep.MOVE_RIGHT, TutorialStep.MOVE_LEFT:
			_unlock_control("left")
			_unlock_control("right")
			_unlock_control("joystick")
		TutorialStep.JUMP:
			_unlock_control("jump")
	
	# Wait for dialogue to finish
	await tutorial_dialogue.dialogue_finished
	
	# Wait for player action
	if step != TutorialStep.INTRO and step != TutorialStep.COMPLETE:
		_wait_for_action()
	elif step == TutorialStep.INTRO:
		await get_tree().create_timer(1.0).timeout
		_next_step()
	elif step == TutorialStep.COMPLETE:
		await get_tree().create_timer(2.0).timeout
		_end_tutorial()

func _wait_for_action() -> void:
	# This is handled in _process
	pass

func _process(_delta: float) -> void:
	if not tutorial_active or not player:
		return
	
	match current_step:
		TutorialStep.MOVE_RIGHT:
			if Input.is_action_pressed("right") or (player.velocity.x > 10):
				move_right_completed = true
				_next_step()
		
		TutorialStep.MOVE_LEFT:
			if Input.is_action_pressed("left") or (player.velocity.x < -10):
				move_left_completed = true
				_next_step()
		
		TutorialStep.JUMP:
			if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("up"):
				jump_completed = true
				_next_step()

func _next_step() -> void:
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
	tutorial_active = false
	tutorial_dialogue.hide_dialogue()
	tutorial_orb.hide_orb()
	
	# Unlock all controls
	if touch_controls:
		touch_controls.enable_pause()
		if touch_controls.has_node("Control/Control4/atk"):
			touch_controls.get_node("Control/Control4/atk").visible = Global.touchatk
		if touch_controls.has_node("Control/Control5/dash"):
			touch_controls.get_node("Control/Control5/dash").visible = Global.touchdash
		if touch_controls.has_node("Control/Control7/shine"):
			touch_controls.get_node("Control/Control7/shine").visible = Global.touchshine
	
	# Save that tutorial is completed
	SaveManager.data["tutorial_completed"] = true
	SaveManager.save_game()
	
	print("[Tutorial] Tutorial completed!")

func _highlight_control(control_name: String) -> void:
	if not touch_controls:
		return
	
	var control_node = null
	match control_name:
		"right":
			control_node = touch_controls.get_node_or_null("Control/Control2/right")
		"left":
			control_node = touch_controls.get_node_or_null("Control/Control/left")
		"jump":
			control_node = touch_controls.get_node_or_null("Control/Control3/jump")
	
	if control_node:
		# Add a pulsing animation
		var tween = create_tween().set_loops()
		tween.tween_property(control_node, "modulate:a", 0.5, 0.5)
		tween.tween_property(control_node, "modulate:a", 1.0, 0.5)
