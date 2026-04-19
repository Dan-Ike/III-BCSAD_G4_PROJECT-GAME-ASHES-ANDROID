# tutorial_manager.gd
extends Node

var tutorial_dialogue = null
var tutorial_orb = null
var touch_controls: CanvasLayer = null
var player: Player = null
var tutorial_active: bool = false
var npc_talked: bool = false
var tutorial_played_this_session: bool = false
enum TutorialStep {
	INTRO,
	MOVE_RIGHT,
	MOVE_LEFT,
	JUMP,
	TALK_TO_NPC,
	COMPLETE
}

var current_step: TutorialStep = TutorialStep.INTRO
var move_right_completed: bool = false
var move_left_completed: bool = false
var jump_completed: bool = false

var player_frozen: bool = false
var target_positions = {}
var target_indicator: Sprite2D = null
var target_radius: float = 20.0  # Distance to reach target

var npc_dialogue_finished: bool = false
# Tutorial dialogue texts
var dialogues = {
	TutorialStep.INTRO: "Welcome, traveler. Let me teach you the basics of movement.",
	TutorialStep.MOVE_RIGHT: "First, try moving [color=yellow]RIGHT[/color] using the button or joystick.",
	TutorialStep.MOVE_LEFT: "Good! Now try moving [color=yellow]LEFT[/color].",
	TutorialStep.JUMP: "Excellent! Now try to [color=yellow]JUMP[/color].",
	TutorialStep.TALK_TO_NPC: "Now, approach the NPC and [color=yellow]touch[/color] anywhere on the screen to talk.", 
	TutorialStep.COMPLETE: "Perfect! You've mastered the basics.\n[color=cyan]Survive and reach the end![/color]"
}

func _ready() -> void:
	print("[Tutorial] TutorialManager _ready() called")
	add_to_group("tutorial_manager")  
	_initialize_nodes()
	
	_create_target_indicator()
	_setup_target_positions()

func on_npc_dialogue_finished():
	print("[Tutorial] NPC dialogue completed!")
	npc_dialogue_finished = true

func _create_target_indicator() -> void:
	target_indicator = Sprite2D.new()
	add_child(target_indicator)
	
	var circle_texture = _create_circle_texture(32, Color(1, 1, 0, 0.7))
	target_indicator.texture = circle_texture
	target_indicator.visible = false
	target_indicator.z_index = 100
	
	var tween = create_tween().set_loops()
	tween.tween_property(target_indicator, "scale", Vector2(1.2, 1.2), 0.8)
	tween.tween_property(target_indicator, "scale", Vector2(1.0, 1.0), 0.8)

func _create_circle_texture(radius: int, color: Color) -> ImageTexture:
	var img = Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	for x in range(radius * 2):
		for y in range(radius * 2):
			var dx = x - radius
			var dy = y - radius
			var distance = sqrt(dx * dx + dy * dy)
			if distance <= radius:
				var alpha = color.a * (1.0 - (distance / radius) * 0.3)
				img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return ImageTexture.create_from_image(img)

func _setup_target_positions() -> void:
	if not player:
		return
	var start_pos = player.global_position
	target_positions[TutorialStep.MOVE_RIGHT] = start_pos + Vector2(200, 0)
	target_positions[TutorialStep.MOVE_LEFT] = start_pos + Vector2(-150, 0)
	target_positions[TutorialStep.JUMP] = start_pos + Vector2(100, -80)
	target_positions[TutorialStep.TALK_TO_NPC] = start_pos + Vector2(-200, 0) 

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
	# Never replay if already played this session (e.g. after death/retry)
	if tutorial_played_this_session:
		return false
	
	var preference = SaveManager.get_tutorial_preference()
	
	if preference == "always":
		return true
	
	return not SaveManager.get_data().get("tutorial_completed", false)

func start_tutorial() -> void:
	print("[Tutorial] === START TUTORIAL CALLED ===")
	if not tutorial_orb or not tutorial_dialogue:
		push_error("[Tutorial] Cannot start tutorial - missing required nodes")
		return
	
	print("[Tutorial] Starting tutorial...")
	tutorial_active = true
	tutorial_played_this_session = true
	
	# Disable pause during tutorial
	if touch_controls:
		touch_controls.disable_pause()
	
	# Position orb near player
	if player:
		tutorial_orb.global_position = player.global_position + Vector2(100, -80)
	
	tutorial_orb.show_orb()
	
	await get_tree().create_timer(0.5).timeout
	_show_step(TutorialStep.INTRO)

func _show_step(step: TutorialStep) -> void:
	current_step = step
	
	# FREEZE PLAYER - Block input but keep physics for gravity
	player_frozen = true
	if player:
		player.tutorial_frozen = true  # This flag blocks input in player script
		player.velocity.x = 0
	
	# Show target indicator if needed
	if target_positions.has(step):
		target_indicator.global_position = target_positions[step]
		target_indicator.visible = true
	
	tutorial_dialogue.show_dialogue(dialogues[step])
	
	# Wait for dialogue to finish
	await tutorial_dialogue.dialogue_finished
	
	print("[Tutorial] Dialogue finished for step: ", TutorialStep.keys()[step])
	
	# UNFREEZE PLAYER
	player_frozen = false
	if player:
		player.tutorial_frozen = false
		player.velocity.x = 0
	
	# Handle special steps
	if step == TutorialStep.INTRO:
		player_frozen = true
		if player:
			player.tutorial_frozen = true
		await get_tree().create_timer(1.0).timeout
		_next_step()
	elif step == TutorialStep.COMPLETE:
		target_indicator.visible = false
		await get_tree().create_timer(2.0).timeout
		_end_tutorial()

func _next_step() -> void:
	if not tutorial_dialogue:
		return
	
	player_frozen = true
	if player:
		player.tutorial_frozen = true
		player.velocity.x = 0
	
	tutorial_dialogue.hide_dialogue()
	await get_tree().create_timer(0.5).timeout
	
	match current_step:
		TutorialStep.INTRO:
			_show_step(TutorialStep.MOVE_RIGHT)
		TutorialStep.MOVE_RIGHT:
			_show_step(TutorialStep.MOVE_LEFT)
		TutorialStep.MOVE_LEFT:
			_show_step(TutorialStep.JUMP)
		TutorialStep.JUMP:
			_show_step(TutorialStep.TALK_TO_NPC)  # NEW
		TutorialStep.TALK_TO_NPC:  # NEW
			_show_step(TutorialStep.COMPLETE)

func _process(_delta: float) -> void:
	if not tutorial_active or not player or player_frozen:
		return
	
	# Check if player reached target position
	if target_positions.has(current_step):
		var distance = player.global_position.distance_to(target_positions[current_step])
		
		# Special handling for NPC talk step
		if current_step == TutorialStep.TALK_TO_NPC:
			# Wait for dialogue to actually finish
			if npc_dialogue_finished:
				target_indicator.visible = false
				npc_dialogue_finished = false  # Reset for future use
				_next_step()
		elif distance <= target_radius:
			target_indicator.visible = false
			
			# NEW: Force idle animation when reaching target
			if player.animated_sprite:
				player.animated_sprite.play("idle")
			
			match current_step:
				TutorialStep.MOVE_RIGHT:
					move_right_completed = true
				TutorialStep.MOVE_LEFT:
					move_left_completed = true
				TutorialStep.JUMP:
					jump_completed = true
			_next_step()

func _end_tutorial() -> void:
	print("[Tutorial] Ending tutorial...")
	tutorial_active = false
	
	if tutorial_dialogue:
		tutorial_dialogue.hide_dialogue()
	
	if tutorial_orb:
		tutorial_orb.hide_orb()
	
	if touch_controls:
		touch_controls.enable_pause()
	
	SaveManager.data["tutorial_completed"] = true
	SaveManager._save_local()
	
	print("[Tutorial] Tutorial completed and saved!")
