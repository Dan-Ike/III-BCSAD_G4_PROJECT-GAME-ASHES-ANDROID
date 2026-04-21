extends Node

var tutorial_dialogue = null
var touch_controls: CanvasLayer = null
var player: Player = null
var tutorial_active: bool = false
var tutorial_played_this_session: bool = false
enum TutorialStep {
	INTRO,
	COMPLETE
}

var current_step: TutorialStep = TutorialStep.INTRO
var player_frozen: bool = false

var dialogues = {
	TutorialStep.INTRO: "Welcome to the 2nd Floor.",
	TutorialStep.COMPLETE: "In this floor, the light is your way out\n[color=cyan]Talk to the npc to find out more.[/color]"
}

var dialogues_controller = {
	TutorialStep.INTRO: "Welcome to the 2nd Floor.",
	TutorialStep.COMPLETE: "In this floor, the light is your way out\n[color=cyan]Talk to the npc to find out more.[/color]"
}

func _get_dialogue(step: TutorialStep) -> String:
	if Global.control_type == 2:
		return dialogues_controller.get(step, "")
	return dialogues.get(step, "")

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
	if level.has_node("tutorial_dialogue_4"):
		tutorial_dialogue = level.get_node("tutorial_dialogue_4")
		print("[Tutorial] ✓ TutorialDialogue found")
	else:
		push_error("[Tutorial] ✗ tutorial_dialogue_4 not found!")
	if level.has_node("player"):
		player = level.get_node("player")
		print("[Tutorial] ✓ Player found")
	# Fixed path to match your level scene
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

func _show_step(step: TutorialStep) -> void:
	current_step = step
	player_frozen = true
	if player:
		player.tutorial_frozen = true
		player.velocity.x = 0
	#tutorial_dialogue.show_dialogue(dialogues[step])
	tutorial_dialogue.show_dialogue(_get_dialogue(step))
	await get_tree().create_timer(2.5).timeout
	print("[Tutorial] Dialogue finished for step: ", TutorialStep.keys()[step])
	if step == TutorialStep.INTRO:
		_next_step()
	elif step == TutorialStep.COMPLETE:
		await get_tree().create_timer(2.0).timeout
		_end_tutorial()

func _next_step() -> void:
	if not tutorial_dialogue:
		return
	tutorial_dialogue.hide_dialogue()
	await get_tree().create_timer(0.5).timeout
	match current_step:
		TutorialStep.INTRO:
			_show_step(TutorialStep.COMPLETE)
