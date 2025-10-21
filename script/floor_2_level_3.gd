extends Node2D

@onready var player: Player = $player
@onready var player_camera = $player/Camera2D
@onready var canvas_modulate: CanvasModulate = $CanvasModulate
#@onready var scene_transition_animation = $SceneTransitionAnimation/AnimationPlayer
@onready var torch: Torch = $Torch
@onready var torch_2: Torch = $Torch2
@onready var torch_5: Torch = $Torch5
@onready var torch_3: Torch = $Torch3
@onready var torch_6: Torch = $Torch6
@onready var torch_7: Torch = $Torch7
@onready var torch_8: Torch = $Torch8
@onready var torch_9: Torch = $Torch9
@onready var _1: ColorRect = $"1"
@onready var _2: ColorRect = $"2"
@onready var _3: ColorRect = $"3"
@onready var _8: ColorRect = $"8"
@onready var _4: ColorRect = $"4"
@onready var _6: ColorRect = $"6"
@onready var _7: ColorRect = $"7"
@onready var _5: ColorRect = $"5"

@onready var floor_3_lvl_1: Area2D = $floor3lvl1
@export var min_brightness: float = 0.2
@export var max_brightness: float = 1.0
@export var tint_color: Color = Color(1.0, 1.0, 1.0)
#@onready var camera_2d: Camera2D = $Camera2D
#@onready var navigation_region_2d: NavigationRegion2D = $NavigationRegion2D
@onready var camera_2d_2: Camera2D = $player/Camera2D2
#@onready var before_2_1: CanvasLayer = $before_2_1

var torch_list: Array[Torch] = []
var indicator_list: Array[ColorRect] = []
var torches_lit: Dictionary = {}
var all_torches_lit: bool = false
var exit_blocked: bool = true
const COLOR_UNLIT = Color(1.0, 1.0, 1.0, 1.0)  
const COLOR_LIT = Color(1.0, 0.9, 0.0, 1.0)   

func _ready() -> void:
	Global.set_floor_level(2, 3)
	player_camera.enabled = false
	camera_2d_2.enabled = true
	#unlock_double_jump()
	#unlock_shine()
	#if scene_transition_animation:
	#	scene_transition_animation.get_parent().get_node("ColorRect").color.a = 255
	#	scene_transition_animation.play("fade_out")
	#MusicManager.play_song("level1") #lvl1 muna 
	_setup_torch_system()
	_update_soul_light_state()
	if floor_3_lvl_1:
		floor_3_lvl_1.body_entered.connect(_on_floor_3_lvl_1_body_entered)
	#print("[Floor 2-1] Torch puzzle initialized - Light all 5 torches to proceed!")
#	var should_play_cutscene = _should_show_cutscene()
	
	#get_tree().paused = false  
	player_camera.enabled = true
	camera_2d_2.enabled = true
	MusicManager.play_song("level2")
	
	Global.set_retrying(false)

func unlock_double_jump():
	Global.can_double_jump = true
	SaveManager.unlock_ability("double_jump")
func unlock_shine():
	Global.unlock_shine()
	print("[Floor 2-1] Shine ability unlocked!")

func _setup_torch_system() -> void:
	#"""Initialize torch tracking and indicators"""
	torch_list = [torch, torch_2, torch_5, torch_3, torch_6, torch_7, torch_8, torch_9]
	indicator_list = [_1, _2, _3, _4, _7, _6, _5, _8]
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

func _on_floor_3_lvl_1_body_entered(body: Node2D) -> void:
	#"""Handle player attempting to exit"""
	if not (body is Player):
		return
	if exit_blocked or not all_torches_lit:
		#print("[Floor 2-1] Cannot proceed - Light all torches first! (%d/5)" % _count_lit_torches())
		return
	#print("[Floor 2-1] Proceeding to Floor 2 Level 2...")
	SaveManager.mark_level_completed(2, 3)
	SaveManager.advance_to_level(3, 1)
	Global.advance_level()
	Global.advance_floor()
	#unlock_shine()
	if body.touch_controls:
		body.touch_controls.disable_all_controls()
	#if scene_transition_animation:
	#	scene_transition_animation.play("fade_in")
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scene/floor_3_level_1.tscn")

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
