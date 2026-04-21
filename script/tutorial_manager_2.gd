extends Node

var tutorial_dialogue = null
var touch_controls: CanvasLayer = null
var player: Player = null
var tutorial_active: bool = false
var dash_completed: bool = false
var tutorial_played_this_session: bool = false
enum TutorialStep {
	INTRO,
	DASH,
	COMPLETE
}

var current_step: TutorialStep = TutorialStep.INTRO
var player_frozen: bool = false
var target_positions = {}
var target_indicator: Sprite2D = null
var target_radius: float = 20.0

var dialogues = {
	TutorialStep.INTRO: "Welcome, Challenger. Let me teach you the new ability you got.",
	TutorialStep.DASH: "Try to [color=yellow]DASH[/color] using the dash button or using the shift key.",
	TutorialStep.COMPLETE: "Perfect! You've mastered the Dash ability.\n[color=cyan]Survive and reach the end![/color]"
}

var dialogues_controller = {
	TutorialStep.INTRO: "Welcome, Challenger. Let me teach you the new ability you got.",
	TutorialStep.DASH: "Try to [color=yellow]DASH[/color] using the dash button or using the shift key.",
	TutorialStep.COMPLETE: "Perfect! You've mastered the Dash ability.\n[color=cyan]Survive and reach the end![/color]"
}

func _get_dialogue(step: TutorialStep) -> String:
	if Global.control_type == 2:
		return dialogues_controller.get(step, "")
	return dialogues.get(step, "")

func _ready() -> void:
	print("[Tutorial] TutorialManager _ready() called")
	add_to_group("tutorial_manager")
	_initialize_nodes()
	_create_target_indicator()
	_setup_target_positions()

func _create_target_indicator() -> void:
	target_indicator = Sprite2D.new()
	add_child(target_indicator)
	target_indicator.texture = _create_circle_texture(32, Color(1, 1, 0, 0.7))
	target_indicator.visible = false
	target_indicator.z_index = 10
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
	target_positions[TutorialStep.DASH] = start_pos + Vector2(80, 20)

func check_and_start_tutorial() -> void:
	print("[Tutorial] check_and_start_tutorial called")
	if not tutorial_dialogue or not player:
		print("[Tutorial] Initializing nodes...")
		_initialize_nodes()
	if _should_run_tutorial():
		print("[Tutorial] Starting tutorial now!")
		start_tutorial()
	else:
		print("[Tutorial] Tutorial already completed, skipping")

func _initialize_nodes() -> void:
	var level = get_parent()
	if level.has_node("tutorial_dialogue_2"):
		tutorial_dialogue = level.get_node("tutorial_dialogue_2")
		print("[Tutorial] ✓ TutorialDialogue found")
	else:
		push_error("[Tutorial] ✗ tutorial_dialogue_2 not found!")
	if level.has_node("player"):
		player = level.get_node("player")
		print("[Tutorial] ✓ Player found")
	if level.has_node("TouchControls"):
		touch_controls = level.get_node("TouchControls")
		print("[Tutorial] ✓ TouchControls found")
	else:
		push_error("[Tutorial] ✗ TouchControls not found - make sure it's in the level scene!")

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
	if not tutorial_dialogue:
		push_error("[Tutorial] Cannot start tutorial - missing required nodes")
		return
	
	print("[Tutorial] Starting tutorial...")
	tutorial_active = true
	tutorial_played_this_session = true
	
	# Disable pause during tutorial
	if touch_controls:
		touch_controls.disable_pause()
	
	# Position orb near player
	
	await get_tree().create_timer(0.5).timeout
	_show_step(TutorialStep.INTRO)

func _show_step(step: TutorialStep) -> void:
	current_step = step
	player_frozen = true
	if player:
		player.tutorial_frozen = true
		player.velocity.x = 0
	if target_positions.has(step):
		target_indicator.global_position = target_positions[step]
		target_indicator.visible = true
	#tutorial_dialogue.show_dialogue(dialogues[step])
	tutorial_dialogue.show_dialogue(_get_dialogue(step))
	await tutorial_dialogue.dialogue_finished
	print("[Tutorial] Dialogue finished for step: ", TutorialStep.keys()[step])
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
			_show_step(TutorialStep.DASH)
		TutorialStep.DASH:
			_show_step(TutorialStep.COMPLETE)

func _process(_delta: float) -> void:
	if not tutorial_active or not player or player_frozen:
		return
	if target_positions.has(current_step):
		var distance = player.global_position.distance_to(target_positions[current_step])
		if distance <= target_radius:
			target_indicator.visible = false
			if player.animated_sprite:
				player.animated_sprite.play("idle")
			if current_step == TutorialStep.DASH:
				dash_completed = true
			_next_step()

func _end_tutorial() -> void:
	print("[Tutorial] Ending tutorial...")
	tutorial_active = false
	
	if tutorial_dialogue:
		tutorial_dialogue.hide_dialogue()
	
	if touch_controls:
		touch_controls.enable_pause()
	
	SaveManager.data["tutorial_completed"] = true
	SaveManager._save_local()
	
	print("[Tutorial] Tutorial completed and saved!")
