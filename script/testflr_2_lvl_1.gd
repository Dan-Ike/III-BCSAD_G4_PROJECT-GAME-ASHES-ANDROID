extends Node2D

@onready var player: Player = $player
@onready var player_camera = $player/Camera2D
@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var scene_transition_animation = $SceneTransitionAnimation/AnimationPlayer
@onready var torch: Torch = $Torch
@onready var torch_2: Torch = $Torch2
@onready var torch_3: Torch = $Torch3
@onready var torch_5: Torch = $Torch5
@onready var torch_6: Torch = $Torch6
@onready var _1: ColorRect = $"1"
@onready var _2: ColorRect = $"2"
@onready var _3: ColorRect = $"3"
@onready var _4: ColorRect = $"4"
@onready var _5: ColorRect = $"5"
@onready var floor_2_lvl_2: Area2D = $floor2lvl2
@export var min_brightness: float = 0.2
@export var max_brightness: float = 1.0
@export var tint_color: Color = Color(1.0, 1.0, 1.0)
#@onready var camera_2d: Camera2D = $Camera2D
@onready var navigation_region_2d: NavigationRegion2D = $NavigationRegion2D
@onready var camera_2d_2: Camera2D = $player/Camera2D2
@onready var before_2_1: CanvasLayer = $before_2_1
@onready var floor_title: CanvasLayer = $FloorTitle

var torch_list: Array[Torch] = []
var indicator_list: Array[ColorRect] = []
var torches_lit: Dictionary = {}
var all_torches_lit: bool = false
var exit_blocked: bool = true
const COLOR_UNLIT = Color(1.0, 1.0, 1.0, 1.0)  
const COLOR_LIT = Color(1.0, 0.9, 0.0, 1.0)   

func _ready() -> void:
	Global.set_floor_level(2, 1)
	player_camera.enabled = false
	camera_2d_2.enabled = true
	
	if scene_transition_animation:
		scene_transition_animation.get_parent().get_node("ColorRect").color.a = 255
		scene_transition_animation.play("fade_out")
	
	_setup_torch_system()
	_update_soul_light_state()
	
	if floor_2_lvl_2:
		floor_2_lvl_2.body_entered.connect(_on_floor_2_lvl_2_body_entered)
	
	var should_play_cutscene = _should_show_cutscene()
	
	if should_play_cutscene:
		if player.has_node("../CanvasLayer"):
			var touch_controls_node = player.get_node("../CanvasLayer")
			if touch_controls_node:
				touch_controls_node.disable_all_controls()
		
		player_camera.enabled = false
		camera_2d_2.enabled = true
		before_2_1.visible = true
		before_2_1.start_cutscene("floor_2_level_1_prologue")
		
		# Wait for cutscene to finish, then show floor title
		await before_2_1.cutscene_finished
		_show_floor_title_then_start()
	else:
		# No cutscene - show floor title immediately
		_show_floor_title_then_start()
	
	Global.set_retrying(false)

func _show_floor_title_then_start() -> void:
	# Show floor title (pauses game)
	floor_title.show_title()
	await floor_title.title_finished
	
	# Now start gameplay
	get_tree().paused = false
	player_camera.enabled = true
	camera_2d_2.enabled = true
	MusicManager.play_song("level2")
	
	# Start player timer AFTER floor title finishes
	player.reset_level_timer()
	
	if before_2_1:
		before_2_1.queue_free()

func _should_show_cutscene() -> bool:
	"""Determine if cutscene should play based on user preference"""
	var cutscene_pref = SaveManager.get_setting("cutscene_preference")
	
	if cutscene_pref == null:
		cutscene_pref = "play_once"
	
	if cutscene_pref == "always":
		return not Global.is_retrying_level
	elif cutscene_pref == "play_once":
		return not SaveManager.has_watched_cutscene("floor_2_level_1_prologue")
	
	return false

func unlock_double_jump():
	Global.can_double_jump = true
	SaveManager.unlock_ability("double_jump")
func unlock_shine():
	Global.unlock_shine()
	print("[Floor 2-1] Shine ability unlocked!")

func _setup_torch_system() -> void:
	#"""Initialize torch tracking and indicators"""
	torch_list = [torch, torch_2, torch_3, torch_5, torch_6]
	indicator_list = [_1, _2, _3, _4, _5]
	for i in range(torch_list.size()):
		var t = torch_list[i]
		if t:
			torches_lit[t] = false
			if indicator_list[i]:
				indicator_list[i].color = COLOR_UNLIT
	#print("[Floor 2-1] Tracking %d torches" % torch_list.size())

func _process(delta: float) -> void:
	_update_soul_light_state()
	_check_torch_states()

func _update_soul_light_state() -> void:
	#"""Update player's soul light visibility"""
	if not player or not player.soul_light:
		return
	if Global.soul_light_enabled:
		player.soul_light.visible = true
		player.soul_light.energy = 1.5
		player.soul_light.enabled = true
	else:
		player.soul_light.visible = false
		player.soul_light.energy = 0.0
		player.soul_light.enabled = false

func _update_canvas_darkness() -> void:
	#"""Update world darkness based on soul value"""
	if not Global.soul_light_enabled:
		canvas_modulate.color = Color(0, 0, 0, 1)
		return
	var normalized: float = clamp(player.soul_value / player.soul_max, 0.0, 1.0)
	var brightness: float = lerp(min_brightness, max_brightness, normalized)
	var darkened_color := Color(
		tint_color.r * brightness * 0.9,
		tint_color.g * brightness * 0.9,
		tint_color.b * brightness * 0.9,
		1.0
	)
	canvas_modulate.color = darkened_color

func _check_torch_states() -> void:
	#"""Check if torches are lit and update indicators"""
	var any_changed = false
	for i in range(torch_list.size()):
		var t = torch_list[i]
		if not t:
			continue
		var was_lit = torches_lit[t]
		var is_lit_now = t.is_lit
		if was_lit != is_lit_now:
			torches_lit[t] = is_lit_now
			any_changed = true
			if indicator_list[i]:
				indicator_list[i].color = COLOR_LIT if is_lit_now else COLOR_UNLIT
			#print("[Floor 2-1] Torch %d %s" % [i + 1, "LIT" if is_lit_now else "EXTINGUISHED"])
	if any_changed:
		_check_all_torches_lit()

func _check_all_torches_lit() -> void:
	#"""Check if all torches are lit and update exit availability"""
	var lit_count = 0
	for torch_lit in torches_lit.values():
		if torch_lit:
			lit_count += 1
	var was_complete = all_torches_lit
	all_torches_lit = (lit_count == torch_list.size())
	if all_torches_lit != was_complete:
		if all_torches_lit:
			_on_puzzle_complete()
		else:
			_on_puzzle_incomplete()
	#print("[Floor 2-1] Torches lit: %d/%d" % [lit_count, torch_list.size()])

func _on_puzzle_complete() -> void:
	#"""Called when all torches are lit"""
	exit_blocked = false
	#print("[Floor 2-1] ✓ ALL TORCHES LIT! Exit is now open!")

func _on_puzzle_incomplete() -> void:
	#"""Called when puzzle becomes incomplete again"""
	exit_blocked = true
	#print("[Floor 2-1] ✗ Puzzle incomplete - Exit blocked")

func _on_floor_2_lvl_2_body_entered(body: Node2D) -> void:
	if not (body is Player):
		return
	
	if exit_blocked or not all_torches_lit:
		return
	
	# Get time FIRST before stopping
	var time_cleared = body._get_elapsed_time()
	body.stop_level_timer()
	
	print("[Level] Player completed Floor %d, Level %d in %.2f seconds" % [Global.current_floor, Global.current_level, time_cleared])
	
	# Save progress
	SaveManager.mark_level_completed(2, 1)
	SaveManager.advance_to_level(2, 2)
	unlock_shine()
	
	# Disable touch controls
	if body.touch_controls:
		body.touch_controls.disable_all_controls()
	
	# Show level completed screen
	var game_over_scene = preload("res://scene/game_over.tscn")
	var game_over = game_over_scene.instantiate()
	get_tree().root.add_child(game_over)
	if game_over.has_method("show_game_over"):
		game_over.show_game_over(Global.current_floor, Global.current_level, time_cleared, true)

func _count_lit_torches() -> int:
	#"""Helper to count currently lit torches"""
	var count = 0
	for is_lit in torches_lit.values():
		if is_lit:
			count += 1
	return count

func _on_spike_collision_body_entered(body: Node2D) -> void:
	#if body is Player and body.can_take_damage:
		#body.take_damage(Global.spikeDamageAmount)
	if body is Player and body.can_take_damage:
		Global.is_retrying_level = true
		body.die()
