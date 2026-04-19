extends Node
var tutorial_dialogue = null
var touch_controls: CanvasLayer = null
var player: Player = null
var tutorial_active: bool = false
var waiting_for_shine: bool = false
var tutorial_played_this_session: bool = false
enum TutorialStep {
	INTRO,
	USE_SHINE,
	COMPLETE
}

var current_step: TutorialStep = TutorialStep.INTRO
var player_frozen: bool = false

var dialogues = {
	TutorialStep.INTRO: "You got a new ability.",
	TutorialStep.USE_SHINE: "Use your [color=yellow]SHINE[/color] ability! Tap the shine button to activate it.",
	TutorialStep.COMPLETE: "Well done! Use it wisely.\n[color=cyan]Survive and reach the end![/color]"
}

func _ready() -> void:
	print("[Tutorial] TutorialManager _ready() called")
	add_to_group("tutorial_manager")
	_initialize_nodes()

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
	if level.has_node("tutorial_dialogue_5"):
		tutorial_dialogue = level.get_node("tutorial_dialogue_5")
		print("[Tutorial] ✓ TutorialDialogue found")
	else:
		push_error("[Tutorial] ✗ tutorial_dialogue_5 not found!")
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
	
	return not SaveManager.get_data().get("tutorial_completed", false)

func _ensure_buttons_visible() -> void:
	if not touch_controls:
		return
	# Always keep these visible
	for path in ["Control/Control3/jump", "Control/Control5/dash"]:
		if touch_controls.has_node(path):
			var node = touch_controls.get_node(path)
			node.visible = true
			node.set_process(true)
	# Show shine specifically for this tutorial
	if touch_controls.has_node("Control/Control7/shine"):
		var shine = touch_controls.get_node("Control/Control7/shine")
		shine.visible = true
		shine.set_process(true)

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
	_ensure_buttons_visible()

	if step == TutorialStep.INTRO:
		player_frozen = true
		if player:
			player.tutorial_frozen = true
			player.velocity.x = 0
		tutorial_dialogue.show_dialogue(dialogues[step])
		await get_tree().create_timer(2.5).timeout
		_next_step()

	elif step == TutorialStep.USE_SHINE:
		# Unfreeze player so they can press shine
		player_frozen = false
		if player:
			player.tutorial_frozen = false
		tutorial_dialogue.show_dialogue(dialogues[step])
		# Wait until player uses shine
		waiting_for_shine = true
		print("[Tutorial] Waiting for player to use shine...")

	elif step == TutorialStep.COMPLETE:
		player_frozen = true
		if player:
			player.tutorial_frozen = true
		tutorial_dialogue.show_dialogue(dialogues[step])
		await get_tree().create_timer(2.5).timeout
		_end_tutorial()

func _process(_delta: float) -> void:
	if not tutorial_active or not waiting_for_shine:
		return
	# Detect shine input — adjust action name to match your InputMap
	if Input.is_action_just_pressed("shine"):
		waiting_for_shine = false
		print("[Tutorial] Shine used! Proceeding...")
		_next_step()

func _next_step() -> void:
	if not tutorial_dialogue:
		return
	tutorial_dialogue.hide_dialogue()
	await get_tree().create_timer(0.5).timeout
	match current_step:
		TutorialStep.INTRO:
			_show_step(TutorialStep.USE_SHINE)
		TutorialStep.USE_SHINE:
			_show_step(TutorialStep.COMPLETE)

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
