extends Node

var tutorial_dialogue = null
var touch_controls: CanvasLayer = null
var player: Player = null
var tutorial_active: bool = false

enum TutorialStep {
	INTRO,
	COMPLETE
}

var current_step: TutorialStep = TutorialStep.INTRO
var player_frozen: bool = false

var dialogues = {
	TutorialStep.INTRO: "Welcome, traveler. Let me teach you the basics of movement.",
	TutorialStep.COMPLETE: "Perfect! You've mastered the basics.\n[color=cyan]Survive and reach the end![/color]"
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
	return true
	#return not SaveManager.get_data().get("tutorial_completed", false)

func start_tutorial() -> void:
	print("[Tutorial] === START TUTORIAL CALLED ===")
	if not tutorial_dialogue:
		push_error("[Tutorial] Cannot start tutorial - missing tutorial_dialogue")
		return
	tutorial_active = true
	# Only freeze the player, don't touch controls
	if player:
		player.tutorial_frozen = true
		player.velocity = Vector2.ZERO
	await get_tree().create_timer(0.5).timeout
	_show_step(TutorialStep.INTRO)

func _end_tutorial() -> void:
	print("[Tutorial] Ending tutorial...")
	tutorial_active = false
	if tutorial_dialogue:
		tutorial_dialogue.hide_dialogue()
	if player:
		player.tutorial_frozen = false
	# No control changes needed since we never disabled them
	SaveManager.get_data()["tutorial_completed"] = true
	SaveManager.save()
	print("[Tutorial] Tutorial completed and saved!")

func _show_step(step: TutorialStep) -> void:
	current_step = step
	player_frozen = true
	if player:
		player.tutorial_frozen = true
		player.velocity.x = 0
	tutorial_dialogue.show_dialogue(dialogues[step])
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
