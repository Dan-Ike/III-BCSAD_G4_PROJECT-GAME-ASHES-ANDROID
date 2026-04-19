extends Node
var tutorial_dialogue = null
var touch_controls: CanvasLayer = null
var player: Player = null
var kanun: Node = null
var tutorial_active: bool = false
var waiting_for_kill: bool = false
var tutorial_played_this_session: bool = false
enum TutorialStep {
	INTRO,
	KILL_ENEMY,
	COMPLETE
}

var current_step: TutorialStep = TutorialStep.INTRO
var player_frozen: bool = false

var dialogues = {
	TutorialStep.INTRO: "An enemy blocks your path. Defeat it!",
	TutorialStep.KILL_ENEMY: "Use your [color=red]ATTACK[/color]! Defeat the [color=yellow]Kanun[/color] to proceed.",
	TutorialStep.COMPLETE: "Well done, Soldier!\n[color=cyan]Survive and Persist![/color]"
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
	if level.has_node("tutorial_dialogue_6"):
		tutorial_dialogue = level.get_node("tutorial_dialogue_6")
		print("[Tutorial] ✓ TutorialDialogue found")
	else:
		push_error("[Tutorial] ✗ tutorial_dialogue_6 not found!")
	if level.has_node("player"):
		player = level.get_node("player")
		print("[Tutorial] ✓ Player found")
	if level.has_node("TouchControls"):
		touch_controls = level.get_node("TouchControls")
		print("[Tutorial] ✓ TouchControls found in level")
	else:
		push_error("[Tutorial] ✗ TouchControls not found!")
	if level.has_node("Kanun"):
		kanun = level.get_node("Kanun")
		print("[Tutorial] ✓ Kanun found")
	else:
		push_error("[Tutorial] ✗ Kanun not found!")

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
	for path in ["Control/Control3/jump", "Control/Control5/dash", "Control/Control7/shine"]:
		if touch_controls.has_node(path):
			var node = touch_controls.get_node(path)
			node.visible = true
			node.set_process(true)
	# Show attack specifically for this tutorial
	if touch_controls.has_node("Control/Control4/atk"):
		var atk = touch_controls.get_node("Control/Control4/atk")
		atk.visible = true
		atk.set_process(true)

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

	elif step == TutorialStep.KILL_ENEMY:
		# Unfreeze player so they can fight
		player_frozen = false
		if player:
			player.tutorial_frozen = false
		tutorial_dialogue.show_dialogue(dialogues[step])
		waiting_for_kill = true
		print("[Tutorial] Waiting for Kanun to be killed...")

	elif step == TutorialStep.COMPLETE:
		player_frozen = false
		if player:
			player.tutorial_frozen = false
		tutorial_dialogue.show_dialogue(dialogues[step])
		await get_tree().create_timer(2.5).timeout
		_end_tutorial()

func _process(_delta: float) -> void:
	if not tutorial_active or not waiting_for_kill:
		return
	# Check if Kanun is dead (node removed from scene)
	if not is_instance_valid(kanun) or not kanun.is_inside_tree():
		waiting_for_kill = false
		print("[Tutorial] Kanun defeated! Proceeding...")
		_next_step()

func _next_step() -> void:
	if not tutorial_dialogue:
		return
	tutorial_dialogue.hide_dialogue()
	await get_tree().create_timer(0.5).timeout
	match current_step:
		TutorialStep.INTRO:
			_show_step(TutorialStep.KILL_ENEMY)
		TutorialStep.KILL_ENEMY:
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
