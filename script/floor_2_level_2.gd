extends Node2D

@onready var player: Player = $player
@onready var player_camera = $player/Camera2D
@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var scene_transition_animation = $SceneTransitionAnimation/AnimationPlayer
@onready var torch: Torch = $Torch #colorrect1
@onready var torch_2: Torch = $Torch2 #colorrect2
@onready var torch_5: Torch = $Torch5 #colorrect4
@onready var torch_3: Torch = $Torch3 #colorrect3
@onready var torch_6: Torch = $Torch6 #colorrect5
@onready var _1: ColorRect = $"1"
@onready var _2: ColorRect = $"2"
@onready var _3: ColorRect = $"3"
@onready var _4: ColorRect = $"4"
@onready var _5: ColorRect = $"5"
@onready var floor_2_lvl_2: Area2D = $floor2lvl2
@export var min_brightness: float = 0.2
@export var max_brightness: float = 1.0
@export var tint_color: Color = Color(1.0, 1.0, 1.0)
@onready var navigation_region_2d: NavigationRegion2D = $NavigationRegion2D
@onready var camera_2d_2: Camera2D = $player/Camera2D2

var torch_list: Array[Torch] = []
var indicator_list: Array[ColorRect] = []
var torches_lit: Dictionary = {}
var all_torches_lit: bool = false
var exit_blocked: bool = true
const COLOR_UNLIT = Color(1.0, 1.0, 1.0, 1.0)  
const COLOR_LIT = Color(1.0, 0.9, 0.0, 1.0)

# NEW: Sequence tracking variables
var correct_sequence: Array[int] = [0, 1, 2, 3, 4]  # Indices for torch, torch_2, torch_3, torch_5, torch_6
var current_sequence: Array[int] = []
var is_checking_sequence: bool = false
var extinguish_timer: Timer

func _ready() -> void:
	Global.set_floor_level(2, 2)
	player_camera.enabled = false
	camera_2d_2.enabled = true
	unlock_shine()
	
	if scene_transition_animation:
		scene_transition_animation.get_parent().get_node("ColorRect").color.a = 255
		scene_transition_animation.play("fade_out")
	
	MusicManager.play_song("level2")
	_setup_torch_system()
	_update_soul_light_state()
	
	# NEW: Setup extinguish timer
	extinguish_timer = Timer.new()
	extinguish_timer.one_shot = true
	extinguish_timer.wait_time = 2.0
	extinguish_timer.timeout.connect(_on_extinguish_timeout)
	add_child(extinguish_timer)
	
	print("[Floor 2-1] Torch sequence puzzle initialized - Light torches in order 1→2→3→4→5")

func unlock_double_jump():
	Global.can_double_jump = true
	SaveManager.unlock_ability("double_jump")

func unlock_shine():
	Global.unlock_shine()
	print("[Floor 2-1] Shine ability unlocked!")

func _setup_torch_system() -> void:
	torch_list = [torch, torch_2, torch_3, torch_5, torch_6]
	indicator_list = [_1, _2, _3, _4, _5]
	
	for i in range(torch_list.size()):
		var t = torch_list[i]
		if t:
			torches_lit[t] = false
			if indicator_list[i]:
				indicator_list[i].color = COLOR_UNLIT
	
	print("[Floor 2-1] Tracking %d torches in sequence mode" % torch_list.size())

func _process(delta: float) -> void:
	_update_soul_light_state()
	_check_torch_states()

func _update_soul_light_state() -> void:
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
	# Check for newly lit torches
	for i in range(torch_list.size()):
		var t = torch_list[i]
		if not t:
			continue
		
		var was_lit = torches_lit[t]
		var is_lit_now = t.is_lit
		
		# Torch just got lit
		if not was_lit and is_lit_now:
			torches_lit[t] = true
			if indicator_list[i]:
				indicator_list[i].color = COLOR_LIT
			
			# Add to sequence
			current_sequence.append(i)
			print("[Floor 2-1] Torch %d lit - Sequence: %s" % [i + 1, _get_sequence_string()])
			
			# Check if all torches are now lit
			if _count_lit_torches() == torch_list.size():
				_validate_complete_sequence()
		
		# Torch got extinguished (manual or by player)
		elif was_lit and not is_lit_now:
			torches_lit[t] = false
			if indicator_list[i]:
				indicator_list[i].color = COLOR_UNLIT
			
			# Remove from sequence if it exists
			var idx = current_sequence.find(i)
			if idx != -1:
				current_sequence.remove_at(idx)

func _validate_complete_sequence() -> void:
	if is_checking_sequence:
		return
	
	is_checking_sequence = true
	var lit_count = _count_lit_torches()
	
	print("[Floor 2-1] All torches lit! Checking sequence...")
	
	# Check if sequence matches
	if _is_sequence_correct():
		print("[Floor 2-1] ✓ CORRECT SEQUENCE! Exit is now open!")
		all_torches_lit = true
		exit_blocked = false
	else:
		print("[Floor 2-1] ✗ WRONG SEQUENCE! Extinguishing in 2 seconds...")
		print("[Floor 2-1] Your sequence: %s | Correct: 1→2→3→4→5" % _get_sequence_string())
		extinguish_timer.start()

func _is_sequence_correct() -> bool:
	if current_sequence.size() != correct_sequence.size():
		return false
	
	for i in range(current_sequence.size()):
		if current_sequence[i] != correct_sequence[i]:
			return false
	
	return true

func _get_sequence_string() -> String:
	var seq_str = ""
	for i in current_sequence:
		seq_str += str(i + 1)
		if i != current_sequence[current_sequence.size() - 1]:
			seq_str += "→"
	return seq_str

func _on_extinguish_timeout() -> void:
	print("[Floor 2-1] Extinguishing all torches...")
	
	# Extinguish all torches
	for i in range(torch_list.size()):
		var t = torch_list[i]
		if t and t.is_lit:
			t.extinguish()  # You may need to implement this method in your Torch script
			torches_lit[t] = false
			if indicator_list[i]:
				indicator_list[i].color = COLOR_UNLIT
	
	# Reset sequence
	current_sequence.clear()
	all_torches_lit = false
	exit_blocked = true
	is_checking_sequence = false
	
	print("[Floor 2-1] Try again! Light torches in order: 1→2→3→4→5")

func _count_lit_torches() -> int:
	var count = 0
	for is_lit in torches_lit.values():
		if is_lit:
			count += 1
	return count

func _on_spike_collision_body_entered(body: Node2D) -> void:
	#if body is Player and body.can_take_damage:
		#body.take_damage(Global.spikeDamageAmount)
	if body is Player and body.can_take_damage:
		# Mark that player is retrying (died), so cutscene won't replay
		Global.is_retrying_level = true
		
		# Kill the player and reset the scene
		body.die()

func _on_floor_3_level_1_body_entered(body: Node2D) -> void:
	if not (body is Player):
		return
	
	if exit_blocked or not all_torches_lit:
		print("[Floor 2-1] Cannot proceed - Complete the sequence first!")
		return
	
	print("[Floor 2-1] Proceeding to Floor 3 Level 1...")
	SaveManager.mark_level_completed(2, 2)
	SaveManager.advance_to_level(3, 1)
	Global.advance_level()
	unlock_shine()
	unlock_attack()
	
	if body.touch_controls:
		body.touch_controls.disable_all_controls()
	
	if scene_transition_animation:
		scene_transition_animation.play("fade_in")
	
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scene/floor_3_level_1.tscn")

func unlock_attack():
	Global.touchatk = true
	SaveManager.unlock_ability("attack")
	var controls = get_tree().root.get_node("TouchControls")
	if controls:
		controls.show_attack_button()
