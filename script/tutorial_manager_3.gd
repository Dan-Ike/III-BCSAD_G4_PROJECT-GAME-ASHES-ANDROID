extends Node

var tutorial_dialogue = null
var touch_controls: CanvasLayer = null
var player: Player = null
var tutorial_active: bool = false
var double_jump_completed: bool = false
var tutorial_played_this_session: bool = false
enum TutorialStep {
	INTRO,
	DOUBLE_JUMP,
	COMPLETE
}

var current_step: TutorialStep = TutorialStep.INTRO
var player_frozen: bool = false
var target_positions = {}
var target_positions_alt = {}
var target_indicator: Sprite2D = null
var target_indicator_alt: Sprite2D = null
var target_radius: float = 20.0

var dialogues = {
	TutorialStep.INTRO: "Let me teach you your new ability.",
	TutorialStep.DOUBLE_JUMP: "Try to [color=yellow]DOUBLE JUMP[/color]! Jump once, then jump again in mid-air.",
	TutorialStep.COMPLETE: "Perfect! You've mastered your ability.\n[color=cyan]Survive and reach the end![/color]"
}

var dialogues_controller = {
	TutorialStep.INTRO: "Let me teach you your new ability.",
	TutorialStep.DOUBLE_JUMP: "Try to [color=yellow]DOUBLE JUMP[/color]! Jump once, then jump again in mid-air.",
	TutorialStep.COMPLETE: "Perfect! You've mastered your ability.\n[color=cyan]Survive and reach the end![/color]"
}

func _get_dialogue(step: TutorialStep) -> String:
	if Global.control_type == 2:
		return dialogues_controller.get(step, "")
	return dialogues.get(step, "")

func _ready() -> void:
	print("[Tutorial] TutorialManager _ready() called")
	add_to_group("tutorial_manager")
	_initialize_nodes()
	_create_target_indicators()
	_setup_target_positions()

func _create_target_indicators() -> void:
	target_indicator = Sprite2D.new()
	add_child(target_indicator)
	target_indicator.texture = _create_circle_texture(32, Color(1, 1, 0, 0.7))
	target_indicator.visible = false
	target_indicator.z_index = 100
	var tween = create_tween().set_loops()
	tween.tween_property(target_indicator, "scale", Vector2(1.2, 1.2), 0.8)
	tween.tween_property(target_indicator, "scale", Vector2(1.0, 1.0), 0.8)

	target_indicator_alt = Sprite2D.new()
	add_child(target_indicator_alt)
	target_indicator_alt.texture = _create_circle_texture(32, Color(0, 1, 1, 0.7))
	target_indicator_alt.visible = false
	target_indicator_alt.z_index = 100
	var tween2 = create_tween().set_loops()
	tween2.tween_property(target_indicator_alt, "scale", Vector2(1.2, 1.2), 0.8)
	tween2.tween_property(target_indicator_alt, "scale", Vector2(1.0, 1.0), 0.8)

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
	target_positions[TutorialStep.DOUBLE_JUMP] = start_pos + Vector2(100, 0)
	target_positions_alt[TutorialStep.DOUBLE_JUMP] = start_pos + Vector2(250, -150)

func check_and_start_tutorial() -> void:
	print("[Tutorial] check_and_start_tutorial called")
	if not tutorial_dialogue or not player:
		_initialize_nodes()
	if _should_run_tutorial():
		start_tutorial()
	else:
		print("[Tutorial] Tutorial already completed, skipping")

func _initialize_nodes() -> void:
	var level = get_parent()
	if level.has_node("tutorial_dialogue_3"):
		tutorial_dialogue = level.get_node("tutorial_dialogue_3")
		print("[Tutorial] ✓ TutorialDialogue found")
	else:
		push_error("[Tutorial] ✗ tutorial_dialogue_3 not found!")
	if level.has_node("player"):
		player = level.get_node("player")
		print("[Tutorial] ✓ Player found")
	if level.has_node("TouchControls"):
		touch_controls = level.get_node("TouchControls")
		print("[Tutorial] ✓ TouchControls found in level")
	else:
		push_error("[Tutorial] ✗ TouchControls not found!")

func _should_run_tutorial() -> bool:
	# Never replay if already played this session (e.g. after death/retry)
	if tutorial_played_this_session:
		return false
	
	var preference = SaveManager.get_tutorial_preference()
	
	if preference == "always":
		return true
	
	return not SaveManager.get_data().get("tutorial_completed_3", false)

func start_tutorial() -> void:
	print("[Tutorial] === START TUTORIAL CALLED ===")
	if not tutorial_dialogue:
		push_error("[Tutorial] Cannot start tutorial - missing required nodes")
		return
	
	print("[Tutorial] Starting tutorial...")
	tutorial_active = true
	tutorial_played_this_session = true
	
	# Disable pause during tutorial
	if touch_controls:
		touch_controls.disable_pause()
	
	await get_tree().create_timer(0.5).timeout
	_show_step(TutorialStep.INTRO)

func _show_step(step: TutorialStep) -> void:
	current_step = step
	
	# Don't freeze player on COMPLETE — lava is rising!
	if step != TutorialStep.COMPLETE:
		player_frozen = true
		if player:
			player.tutorial_frozen = true
			player.velocity.x = 0
	
	if step == TutorialStep.DOUBLE_JUMP:
		target_indicator.global_position = target_positions[step]
		target_indicator.visible = true
		target_indicator_alt.global_position = target_positions_alt[step]
		target_indicator_alt.visible = true
	
	#tutorial_dialogue.show_dialogue(dialogues[step])
	tutorial_dialogue.show_dialogue(_get_dialogue(step))
	await tutorial_dialogue.dialogue_finished
	print("[Tutorial] Dialogue finished for step: ", TutorialStep.keys()[step])
	
	# Only unfreeze if we froze in the first place
	if step != TutorialStep.COMPLETE:
		player_frozen = false
		if player:
			player.tutorial_frozen = false
			player.velocity.x = 0
	
	if step == TutorialStep.INTRO:
		player_frozen = true
		if player:
			player.tutorial_frozen = true
		await get_tree().create_timer(1.0).timeout
		_next_step()
	elif step == TutorialStep.COMPLETE:
		target_indicator.visible = false
		target_indicator_alt.visible = false
		await get_tree().create_timer(2.0).timeout
		_end_tutorial()

func _next_step() -> void:
	if not tutorial_dialogue:
		return
	
	# Don't freeze if we're about to show COMPLETE
	var next_is_complete = (current_step == TutorialStep.DOUBLE_JUMP)
	if not next_is_complete:
		player_frozen = true
		if player:
			player.tutorial_frozen = true
			player.velocity.x = 0
			player.stop_looping_sounds()
	
	tutorial_dialogue.hide_dialogue()
	await get_tree().create_timer(0.5).timeout
	match current_step:
		TutorialStep.INTRO:
			_show_step(TutorialStep.DOUBLE_JUMP)
		TutorialStep.DOUBLE_JUMP:
			_show_step(TutorialStep.COMPLETE)

func _process(_delta: float) -> void:
	if not tutorial_active or not player or player_frozen:
		return
	if current_step == TutorialStep.DOUBLE_JUMP:
		# Only check the alt (upper) target — 1st target is visual guide only
		var dist_alt = player.global_position.distance_to(target_positions_alt[current_step])
		if dist_alt <= target_radius:
			target_indicator.visible = false
			target_indicator_alt.visible = false
			double_jump_completed = true
			_next_step()

func _end_tutorial() -> void:
	print("[Tutorial] Ending tutorial...")
	tutorial_active = false
	
	player_frozen = false
	if player:
		player.tutorial_frozen = false
	
	if tutorial_dialogue:
		tutorial_dialogue.hide_dialogue()
	
	
	if touch_controls:
		touch_controls.enable_pause()
	
	SaveManager.data["tutorial_completed_3"] = true
	SaveManager._save_local()
	
	print("[Tutorial] Tutorial completed and saved!")
