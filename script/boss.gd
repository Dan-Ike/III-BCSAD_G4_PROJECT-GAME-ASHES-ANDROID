extends CharacterBody2D
class_name Boss

@onready var deal_damage_area_down_slash: Area2D = $DealDamageArea_DownSlash
@onready var deal_damage_area_jump_down_attack: Area2D = $DealDamageArea_JumpDownAttack
@onready var deal_damage_area_jump_up_attack: Area2D = $DealDamageArea_JumpUpAttack
@onready var deal_damage_area_vertical_slash: Area2D = $DealDamageArea_VerticalSlash

#Animations: dash, dash_attack, death, down_slash, hurt, idle, 
#idle_up_attack, jump, jump_down_attack, jump_up_attack, run, special_dash
#vertical slash

#dealdamagearea:
#$DealDamageArea_VerticalSlash : vertical slash, dash_attack, special_dash
#$DealDamageArea_JumpUpAttack : jump_up_attack, idle_up_attack
#$DealDamageArea_JumpDownAttack : jump_down_attack
#$DealDamageArea_DownSlash : down_slash
@export var navigation_region: NavigationRegion2D

var is_performing_attack: bool
# Enemy Type Configuration
enum EnemyType { ADAPTIVE_AI, MACHINE_LEARNING }
@export var enemy_type: EnemyType = EnemyType.ADAPTIVE_AI

# Stats
@export var health: int = 500
@export var health_max: int = 500
var health_min: int = 0
@export var base_speed: float = 80.0
@export var chase_speed: float = 120.0
@export var damage_to_deal: int = 20

# Knockback settings
const KNOCKBACK_FORCE: float = 300.0
const CHARGE_KNOCKBACK: float = 400.0
const RANGED_KNOCKBACK: float = 150.0

# Patrol Configuration for PATROL_GUARD
@export var patrol_radius: float = 300.0
@export var return_to_patrol_when_far: bool = true
var patrol_center: Vector2
var is_returning_to_patrol: bool = false

# Wandering (when idle)
var wander_direction: int = 1
var wander_time: float = 0.0
var wander_duration: float = 3.0
var edge_check_cooldown: float = 0.0

# AI State
enum State { IDLE, WANDER, CHASE, ATTACK, DASH_ATTACK, VERTICAL_SLASH, SPECIAL_DASH, DOWN_SLASH, JUMP_UP_ATTACK, JUMP_DOWN_ATTACK, IDLE_UP_ATTACK, RETURN_TO_PATROL }
var current_state: State = State.WANDER
var player: CharacterBody2D
var can_see_player: bool = false

# Combat
var dead: bool = false
var taking_damage: bool = false
var can_attack: bool = true
var attack_cooldown: float = 1.5
var last_attack_time: float = 0.0

# Melee attack damage delay
const MELEE_DAMAGE_DELAY: float = 0.1
var melee_damage_timer: float = 0.0
var should_deal_melee_damage: bool = false

# Jump System
var jump_velocity: float = -400.0
var can_jump: bool = true
var jump_cooldown: float = 0.5
var jump_check_distance: float = 50.0

# Jump Attack System
var jump_attack_speed: float = 400.0
var jump_attack_height: float = -500.0
var jump_attack_duration: float = 2.0
var jump_attack_range: float = 300.0
var is_jump_attacking: bool = false
var jump_attack_timer: float = 0.0
var jump_attack_direction: Vector2 = Vector2.ZERO
var jump_attack_cooldown: float = 4.0
var can_jump_attack: bool = true

var combo_system_active: bool = false
var current_combo: Array = []
var combo_step: int = 0
var combo_timer: float = 0.0
var combo_window: float = 1.5

var last_hit_player: bool = false
var combo_hits: int = 0
var combo_misses: int = 0

var all_damage_areas: Dictionary = {}
var active_damage_area: Area2D = null

var dash_attack_cooldown: float = 2.0
var can_dash_attack: bool = true
var vertical_slash_cooldown: float = 1.5
var can_vertical_slash: bool = true
var special_dash_cooldown: float = 4.0
var can_special_dash: bool = true
var down_slash_cooldown: float = 2.5
var can_down_slash: bool = true
var jump_up_attack_cooldown: float = 3.0
var can_jump_up_attack: bool = true
var jump_down_attack_cooldown: float = 3.0
var can_jump_down_attack: bool = true
var idle_up_attack_cooldown: float = 2.0
var can_idle_up_attack: bool = true

@export_group("Attack Damages")
@export var dash_attack_damage: int = 5
@export var vertical_slash_damage: int = 5
@export var special_dash_damage: int = 5
@export var down_slash_damage: int = 5
@export var jump_up_attack_damage: int = 5
@export var jump_down_attack_damage: int = 5
@export var idle_up_attack_damage: int = 5
@export var dash_damage: int = 5

var dash_speed: float = 400.0
var dash_duration: float = 0.3
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var dash_cooldown: float = 1.5
var can_dash: bool = true

var player_detection_timer: float = 0.0
var player_detection_interval: float = 3.0
var last_known_player_position: Vector2 = Vector2.ZERO

var phase1_combos: Array = [
	["dash_attack", "vertical_slash"],
	["dash", "dash_attack"],
	["vertical_slash", "dash_attack"],
	["dash_attack", "dash"]
]

var phase2_combos: Array = [
	["dash_attack", "vertical_slash", "special_dash", "down_slash", "dash"],
	["jump_up_attack", "dash"],
	["dash_attack", "special_dash", "vertical_slash"],
	["special_dash", "down_slash", "vertical_slash"],
	["jump_down_attack", "dash_attack"]
]

# Jump Attack Shockwave
var shockwave_radius: float = 100.0
var shockwave_damage: int = 15
var shockwave_duration: float = 0.3
var is_shockwave_active: bool = false
var shockwave_timer: float = 0.0

# Melee Attack State
var is_attacking_melee: bool = false

# Phase System
enum Phase { PHASE1, PHASE2 }
var current_phase: Phase = Phase.PHASE1
var phase2_threshold: float = 0.6

# Phase 2 - Multi-shot ranged
var phase2_multishot: bool = false
var shots_fired: int = 0

# Attack Recovery
var attack_recovery_time: float = 1.0
var is_recovering: bool = false

# Pathfinding
var navigation_agent: NavigationAgent2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var health_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null
@onready var hitbox: Area2D = $Hitbox if has_node("Hitbox") else null

# Physics
var GRAVITY: float = 980.0
var was_on_floor: bool = false

var target_velocity_x: float = 0.0
var velocity_smoothing: float = 10.0

# Machine Learning System
var ml_attack_preference: Dictionary = {}
var ml_observation_timer: float = 0.0
var ml_observation_interval: float = 1.0
var player_last_position: Vector2 = Vector2.ZERO
var player_was_aggressive: bool = false
var player_dodged_recently: bool = false
var ml_difficulty_multiplier: float = 1.0

func _ready() -> void:
	#MlEnemyData.reset_adaptation()
	dead = false
	taking_damage = false
	health = health_max
	
	patrol_center = global_position
	_setup_navigation()
	_setup_detection_areas()
	_setup_hitbox()
	_setup_damage_areas()
	_hide_all_damage_areas()
	
	if has_node("DealDamageArea"):
		Global.batDamageZone = $DealDamageArea
	Global.batDamageAmount = damage_to_deal
	
	if health_bar:
		health_bar.max_value = health_max
		health_bar.value = health
	
	wander_direction = 1 if randf() > 0.5 else -1
	wander_duration = randf_range(2.0, 4.0)
	
	if enemy_type == EnemyType.ADAPTIVE_AI or enemy_type == EnemyType.MACHINE_LEARNING:
		current_state = State.CHASE
	else:
		current_state = State.WANDER
	
	if enemy_type == EnemyType.MACHINE_LEARNING:
		_initialize_ml_system()
	
	print("[Enemy] Initialized as ", _get_type_name(), " at ", global_position)
	print("[Enemy] Patrol center: ", patrol_center)

#FINITE STATE MACHINE -  Controls enemy behavior by transitioning between discrete states based on conditions
func _initialize_ml_system() -> void:
	MlEnemyData.record_encounter()
	ml_difficulty_multiplier = MlEnemyData.get_adaptation_multiplier()
	
	health = health_max  
	
	base_speed *= (1.0 + (ml_difficulty_multiplier - 1.0) * 0.5)
	chase_speed *= (1.0 + (ml_difficulty_multiplier - 1.0) * 0.5)
	damage_to_deal = int(damage_to_deal * ml_difficulty_multiplier)
	
	ml_attack_preference = MlEnemyData.learning_data.attack_success_rates.duplicate()
	
	print("[ML Enemy] Initialized with difficulty: ", ml_difficulty_multiplier)
	print("[ML Enemy] Health: ", health, "/", health_max)
	print("[ML Enemy] Attack preferences: ", ml_attack_preference)
	print("[ML Enemy] Player behavior data: ", MlEnemyData.learning_data.player_behavior_patterns)
	MlEnemyData.record_encounter()
	ml_difficulty_multiplier = MlEnemyData.get_adaptation_multiplier()
	
	health_max = int(health_max * ml_difficulty_multiplier)
	health = health_max
	
	if health_bar:
		health_bar.max_value = health_max
		health_bar.value = health
		
	base_speed *= (1.0 + (ml_difficulty_multiplier - 1.0) * 0.5)
	chase_speed *= (1.0 + (ml_difficulty_multiplier - 1.0) * 0.5)
	damage_to_deal = int(damage_to_deal * ml_difficulty_multiplier)
	
	ml_attack_preference = MlEnemyData.learning_data.attack_success_rates.duplicate()
	
	print("[ML Enemy] Initialized with difficulty: ", ml_difficulty_multiplier)
	print("[ML Enemy] Attack preferences: ", ml_attack_preference)
	print("[ML Enemy] Player behavior data: ", MlEnemyData.learning_data.player_behavior_patterns)

func _setup_damage_areas() -> void:
	# Store all damage areas in dictionary
	if has_node("DealDamageArea_VerticalSlash"):
		all_damage_areas["vertical_slash"] = $DealDamageArea_VerticalSlash
	if has_node("DealDamageArea_JumpUpAttack"):
		all_damage_areas["jump_up_attack"] = $DealDamageArea_JumpUpAttack
	if has_node("DealDamageArea_JumpDownAttack"):
		all_damage_areas["jump_down_attack"] = $DealDamageArea_JumpDownAttack
	if has_node("DealDamageArea_DownSlash"):
		all_damage_areas["down_slash"] = $DealDamageArea_DownSlash
	
	print("[Enemy] Damage areas registered: ", all_damage_areas.keys())

func _hide_all_damage_areas() -> void:
	for area in all_damage_areas.values():
		if area:
			area.monitoring = false
			area.monitorable = false

func _activate_damage_area(attack_name: String) -> void:
	_hide_all_damage_areas()
	
	var area_key = ""
	match attack_name:
		"vertical_slash", "dash_attack", "special_dash":
			area_key = "vertical_slash"
		"jump_up_attack", "idle_up_attack":
			area_key = "jump_up_attack"
		"jump_down_attack":
			area_key = "jump_down_attack"
		"down_slash":
			area_key = "down_slash"
	
	if area_key != "" and all_damage_areas.has(area_key):
		active_damage_area = all_damage_areas[area_key]
		active_damage_area.monitoring = true
		active_damage_area.monitorable = true
		print("[Enemy] Activated damage area: ", area_key)

func _get_attack_damage(attack_name: String) -> int:
	match attack_name:
		"dash_attack": return dash_attack_damage
		"vertical_slash": return vertical_slash_damage
		"special_dash": return special_dash_damage
		"down_slash": return down_slash_damage
		"jump_up_attack": return jump_up_attack_damage
		"jump_down_attack": return jump_down_attack_damage
		"idle_up_attack": return idle_up_attack_damage
		"dash": return dash_damage
		_: return damage_to_deal

func _observe_player_behavior(delta: float) -> void:
	if not player or not Global.playerAlive:
		return
	
	ml_observation_timer += delta
	if ml_observation_timer >= ml_observation_interval:
		ml_observation_timer = 0.0
		
		var distance = global_position.distance_to(player.global_position)
		var player_moved = player.global_position.distance_to(player_last_position) > 100.0
		var player_jumped = not player.is_on_floor() if player.has_method("is_on_floor") else false
		
		var direction_to_player = (player.global_position - global_position).normalized()
		var player_velocity_dir = player.velocity.normalized() if player.velocity.length() > 10 else Vector2.ZERO
		player_was_aggressive = player_velocity_dir.dot(-direction_to_player) > 0.5
		
		MlEnemyData.record_player_behavior(distance, player_moved, player_was_aggressive, player_jumped)
		player_last_position = player.global_position

func _setup_hitbox() -> void:
	if hitbox:
		# Disconnect first if already connected
		if hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox.area_entered.disconnect(_on_hitbox_area_entered)
		hitbox.area_entered.connect(_on_hitbox_area_entered)
		print("[Enemy] Hitbox connected successfully")

func _setup_navigation() -> void:
	navigation_agent = NavigationAgent2D.new()
	add_child(navigation_agent)
	navigation_agent.path_desired_distance = 10.0
	navigation_agent.target_desired_distance = 20.0
	navigation_agent.max_speed = chase_speed
	navigation_agent.avoidance_enabled = false

func _setup_detection_areas() -> void:
	if not detection_area:
		detection_area = Area2D.new()
		add_child(detection_area)
		var detection_shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		
		match enemy_type:
			EnemyType.ADAPTIVE_AI:
				circle.radius = 500.0
			EnemyType.MACHINE_LEARNING:
				circle.radius = 500.0
		
		detection_shape.shape = circle
		detection_area.add_child(detection_shape)
	
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_entered)
		detection_area.body_exited.connect(_on_detection_area_exited)

func _get_type_name() -> String:
	match enemy_type:
		EnemyType.ADAPTIVE_AI: return "Adaptive AI"
		EnemyType.MACHINE_LEARNING: return "Machine Learning AI"
		_: return "Unknown"

func _physics_process(delta: float) -> void:
	if dead:
		_handle_death(delta)
		return
	
	player = Global.playerBody
	
	if health_bar:
		health_bar.value = health
	
	_check_phase_transition()
	
	if enemy_type == EnemyType.MACHINE_LEARNING:
		_observe_player_behavior(delta)
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	# Update AI state
	if not taking_damage and not is_performing_attack:
		_update_state(delta)
	
	# Execute state behavior
	match current_state:
		State.IDLE:
			velocity.x = 0
		State.WANDER:
			_state_wander(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK:
			_decide_attack()

	move_and_slide()
	_handle_animation()

func _decide_attack() -> void:
	if is_performing_attack:
		return
	
	if not player or not Global.playerAlive:
		current_state = State.CHASE
		return
	
	var distance = _get_distance_to_player()
	
	# PHASE 2 - More aggressive
	if current_phase == Phase.PHASE2:
		# Jump attacks
		if distance > 120.0 and distance < 280.0 and can_jump_down_attack and is_on_floor():
			_perform_jump_down_attack()
			return
		
		if distance > 100.0 and distance < 250.0 and can_jump_up_attack and is_on_floor():
			_perform_jump_up_attack()
			return
		
		# Special dash for closing distance
		if distance > 150.0 and distance < 400.0 and can_special_dash:
			_perform_special_dash()
			return
	
	# ALL PHASES - Distance-based attacks
	
	# Very close - vertical slash
	if distance < 100.0 and can_vertical_slash:
		_perform_vertical_slash()
		return
	
	# Close-medium - down slash or idle up
	if distance < 120.0:
		var player_above = player.global_position.y < global_position.y - 40
		var player_below = player.global_position.y > global_position.y + 40
		
		if player_above and can_idle_up_attack:
			_perform_idle_up_attack()
			return
		elif player_below and can_down_slash:
			_perform_down_slash()
			return
	
	# Medium range - DASH ATTACK priority
	if distance > 100.0 and distance < 300.0 and can_dash_attack:
		_perform_dash_attack()
		return
	
	# Far range - regular dash to close gap
	if distance > 250.0 and distance < 500.0 and can_dash:
		_perform_dash()
		return
	
	# If no attacks available, CHASE
	current_state = State.CHASE

func _check_phase_transition() -> void:
	var health_percent = float(health) / float(health_max)
	
	# Changed to 50% threshold
	if health_percent <= 0.5 and current_phase == Phase.PHASE1:
		_enter_phase2()

func _enter_phase2() -> void:
	current_phase = Phase.PHASE2
	print("[Enemy] PHASE 2 ACTIVATED! (50% HP)")
	
	# Much faster cooldowns
	dash_attack_cooldown = 1.0  # Was 2.0
	vertical_slash_cooldown = 0.8  # Was 1.5
	special_dash_cooldown = 2.0  # Was 4.0
	down_slash_cooldown = 1.2  # Was 2.5
	jump_up_attack_cooldown = 1.5  # Was 3.0
	jump_down_attack_cooldown = 1.5  # Was 3.0
	dash_cooldown = 0.8  # Was 1.5
	idle_up_attack_cooldown = 1.0  # Was 2.0
	
	base_speed += 50.0
	chase_speed += 70.0  # Even faster
	dash_speed += 150.0  # Much faster dashes
func _is_player_in_patrol_zone() -> bool:
	if not player:
		return false
	var distance_from_center = player.global_position.distance_to(patrol_center)
	return distance_from_center <= patrol_radius

func _is_far_from_patrol_center() -> bool:
	var distance_from_center = global_position.distance_to(patrol_center)
	return distance_from_center > patrol_radius * 1.5

func _update_state(delta: float) -> void:
	if is_attacking_melee or is_jump_attacking:
		return
	
	var distance_to_player = _get_distance_to_player()
	can_see_player = _has_line_of_sight() and _is_in_detection_range()
	
	match enemy_type:
		EnemyType.ADAPTIVE_AI:
			_update_adaptive_ai_state(distance_to_player)
		EnemyType.MACHINE_LEARNING:
			_update_machine_learning_state(distance_to_player)

func _is_in_detection_range() -> bool:
	if not player:
		return false
	
	var distance = global_position.distance_to(player.global_position)
	
	match enemy_type:
		EnemyType.ADAPTIVE_AI:
			return true
		EnemyType.MACHINE_LEARNING:
			return true
	
	return false

func _update_adaptive_ai_state(distance: float) -> void:
	if not player or not Global.playerAlive:
		current_state = State.WANDER
		return
	
	if is_performing_attack:
		return
	
	# ALWAYS be aggressive - constantly try to attack
	if distance < 500.0:  # Huge aggro range
		current_state = State.ATTACK  # This triggers _decide_attack
	else:
		current_state = State.CHASE
func _update_machine_learning_state(distance: float) -> void:
	if not player or not Global.playerAlive:
		current_state = State.WANDER
		return
	
	var player_is_dodger = MlEnemyData.learning_data.player_behavior_patterns.dodge_frequency > 0.6
	var player_is_aggressive = MlEnemyData.learning_data.player_behavior_patterns.aggression_level > 0.6
	
	# Check if we should start a combo
	if not combo_system_active and _should_start_combo():
		_start_combo()
		return
	
	# Continue combo if active
	if combo_system_active:
		return
	
	var best_attack = MlEnemyData.get_best_attack()
	
	# Use best learned attack based on success rates
	match best_attack:
		"dash_attack":
			if distance > 80.0 and distance < 200.0 and can_dash_attack:
				_execute_single_attack("dash_attack")
				return
		"vertical_slash":
			if distance > 60.0 and distance < 120.0 and can_vertical_slash:
				_execute_single_attack("vertical_slash")
				return
		"special_dash":
			if distance > 100.0 and distance < 300.0 and can_special_dash and current_phase == Phase.PHASE2:
				_execute_single_attack("special_dash")
				return
		"down_slash":
			if distance < 100.0 and can_down_slash:
				_execute_single_attack("down_slash")
				return
		"jump_up_attack":
			if distance > 80.0 and distance < 200.0 and can_jump_up_attack and is_on_floor() and current_phase == Phase.PHASE2:
				_execute_single_attack("jump_up_attack")
				return
		"jump_down_attack":
			if distance > 80.0 and distance < 200.0 and can_jump_down_attack and is_on_floor() and current_phase == Phase.PHASE2:
				_execute_single_attack("jump_down_attack")
				return
	
	# Fallback attacks
	if distance > 80.0 and distance < 200.0 and can_dash_attack:
		_execute_single_attack("dash_attack")
		return
	elif distance > 60.0 and distance < 120.0 and can_vertical_slash:
		_execute_single_attack("vertical_slash")
		return
	elif distance > 150.0 and distance < 300.0 and can_dash:
		_execute_single_attack("dash")
		return
	
	# Melee or chase
	if distance < 60.0 and can_attack:
		current_state = State.ATTACK
	else:
		current_state = State.CHASE

func _should_start_combo() -> bool:
	if combo_system_active:
		return false
	
	var distance = _get_distance_to_player()
	
	# Only 25% chance to do combo, and only when close enough
	if distance < 250.0 and randf() < 0.25:
		return true
	
	return false

func _start_combo() -> void:
	combo_system_active = true
	combo_step = 0
	combo_timer = combo_window
	
	# Select combo based on phase
	var available_combos = phase1_combos if current_phase == Phase.PHASE1 else phase2_combos
	current_combo = available_combos[randi() % available_combos.size()]
	
	print("[Enemy] Starting combo: ", current_combo)
	_execute_combo_step()

func _execute_combo_step() -> void:
	if combo_step >= current_combo.size():
		_end_combo()
		return
	
	# Break combo if too many misses
	if combo_misses >= 2:
		print("[Enemy] Too many misses (", combo_misses, "), breaking combo!")
		_end_combo()
		return
	
	# Check if player is in range for next attack
	if player:
		var distance = global_position.distance_to(player.global_position)
		if distance > 350.0:
			print("[Enemy] Player too far (", distance, "), breaking combo!")
			_end_combo()
			return
	
	var attack_name = current_combo[combo_step]
	print("[Enemy] Executing combo step ", combo_step + 1, "/", current_combo.size(), ": ", attack_name)
	
	# Reset hit flag for new attack
	last_hit_player = false
	
	_execute_single_attack(attack_name)

func _end_combo() -> void:
	combo_system_active = false
	current_combo = []
	combo_step = 0
	combo_timer = 0.0
	combo_hits = 0
	combo_misses = 0
	last_hit_player = false
	print("[Enemy] Combo finished!")
	_start_attack_recovery()

func _execute_single_attack(attack_name: String) -> void:
	match attack_name:
		"dash":
			_perform_dash()
		"dash_attack":
			_perform_dash_attack()
		"vertical_slash":
			_perform_vertical_slash()
		"special_dash":
			_perform_special_dash()
		"down_slash":
			_perform_down_slash()
		"jump_up_attack":
			_perform_jump_up_attack()
		"jump_down_attack":
			_perform_jump_down_attack()
		"idle_up_attack":
			_perform_idle_up_attack()

func _perform_dash() -> void:
	if not can_dash or is_performing_attack:
		return
	
	is_performing_attack = true
	can_dash = false
	
	if not player:
		is_performing_attack = false
		return
	
	# Lock direction
	var dash_direction_x = sign(player.global_position.x - global_position.x)
	animated_sprite.flip_h = dash_direction_x < 0
	
	print("[Enemy] DASH! Direction: ", dash_direction_x)
	animated_sprite.play("dash")
	
	# Execute dash
	var dash_timer = 0.0
	
	while dash_timer < dash_duration:
		velocity.x = dash_direction_x * dash_speed
		dash_timer += get_physics_process_delta_time()
		await get_tree().process_frame
	
	velocity.x = 0
	
	await get_tree().create_timer(0.2).timeout
	is_performing_attack = false
	current_state = State.CHASE
	
	await get_tree().create_timer(dash_cooldown).timeout
	can_dash = true

func _perform_dash_attack() -> void:
	if not can_dash_attack or is_performing_attack:
		return
	
	is_performing_attack = true
	can_dash_attack = false
	last_hit_player = false
	
	if not player:
		is_performing_attack = false
		return
	
	# LOCK direction at START - this is the issue!
	var dash_direction_x = sign(player.global_position.x - global_position.x)
	animated_sprite.flip_h = dash_direction_x < 0
	
	_activate_damage_area("dash_attack")
	Global.batDamageAmount = dash_attack_damage
	
	print("[Enemy] DASH ATTACK! Direction: ", dash_direction_x, " Player at: ", player.global_position.x, " Boss at: ", global_position.x)
	animated_sprite.play("dash_attack")
	
	# Brief wind-up
	velocity.x = 0
	await get_tree().create_timer(0.15).timeout
	
	# DASH THROUGH THE PLAYER
	var dash_timer = 0.0
	var dash_length = 0.7  # Longer dash
	var damage_checked = false
	
	while dash_timer < dash_length:
		# Keep moving in LOCKED direction
		velocity.x = dash_direction_x * dash_speed
		
		# Check for hit
		if player and not damage_checked:
			var distance = global_position.distance_to(player.global_position)
			if distance < 120.0:
				_apply_attack_damage("dash_attack")
				damage_checked = true
		
		dash_timer += get_physics_process_delta_time()
		await get_tree().process_frame
	
	velocity.x = 0
	_hide_all_damage_areas()
	
	await get_tree().create_timer(0.2).timeout
	is_performing_attack = false
	current_state = State.CHASE
	
	await get_tree().create_timer(dash_attack_cooldown).timeout
	can_dash_attack = true

func _perform_vertical_slash() -> void:
	if not can_vertical_slash or is_performing_attack:
		return
	
	is_performing_attack = true
	can_vertical_slash = false
	last_hit_player = false  # Reset hit flag
	
	if player:
		animated_sprite.flip_h = player.global_position.x < global_position.x
	
	_activate_damage_area("vertical_slash")
	Global.batDamageAmount = vertical_slash_damage
	
	print("[Enemy] VERTICAL SLASH!")
	animated_sprite.play("vertical_slash")
	
	# Move forward during slash with damage checking
	var move_dir = Vector2.RIGHT if not animated_sprite.flip_h else Vector2.LEFT
	var slash_timer = 0.0
	var slash_duration = 0.5
	var damage_checked = false
	
	while slash_timer < slash_duration:
		velocity.x = move_dir.x * (chase_speed * 0.6)
		
		# Check for hit during active frames
		if player and not damage_checked and slash_timer > 0.2:
			var distance = global_position.distance_to(player.global_position)
			print("[Vertical Slash] Checking distance: ", distance)
			if distance < 100.0:
				_apply_attack_damage("vertical_slash")
				damage_checked = true
		
		slash_timer += get_physics_process_delta_time()
		await get_tree().process_frame
	
	velocity.x = 0
	_hide_all_damage_areas()
	
	await get_tree().create_timer(0.2).timeout
	is_performing_attack = false
	current_state = State.CHASE
	
	await get_tree().create_timer(vertical_slash_cooldown).timeout
	can_vertical_slash = true

func _perform_special_dash() -> void:
	if not can_special_dash or is_performing_attack:
		return
	
	is_performing_attack = true
	can_special_dash = false
	
	# Track player position
	var target_dir = Vector2.RIGHT
	if player:
		target_dir = Vector2.RIGHT if player.global_position.x > global_position.x else Vector2.LEFT
		animated_sprite.flip_h = target_dir.x < 0
	
	_activate_damage_area("special_dash")
	Global.batDamageAmount = special_dash_damage
	
	print("[Enemy] SPECIAL DASH!")
	animated_sprite.play("special_dash")
	
	# Brief charge-up
	await get_tree().create_timer(0.15).timeout
	
	# Longer, faster dash
	var dash_timer = 0.0
	var dash_duration_long = 0.7
	
	while dash_timer < dash_duration_long:
		velocity.x = target_dir.x * (dash_speed * 1.2)
		
		if player:
			var distance = global_position.distance_to(player.global_position)
			if distance < 110.0:
				_apply_attack_damage("special_dash")
		
		dash_timer += get_physics_process_delta_time()
		await get_tree().process_frame
	
	velocity.x = 0
	_hide_all_damage_areas()
	
	await get_tree().create_timer(0.4).timeout
	is_performing_attack = false
	current_state = State.CHASE
	
	await get_tree().create_timer(special_dash_cooldown).timeout
	can_special_dash = true

func _perform_down_slash() -> void:
	if not can_down_slash or is_performing_attack:
		return
	
	is_performing_attack = true
	can_down_slash = false
	
	if player:
		animated_sprite.flip_h = player.global_position.x < global_position.x
	
	_activate_damage_area("down_slash")
	Global.batDamageAmount = down_slash_damage
	
	print("[Enemy] DOWN SLASH!")
	animated_sprite.play("down_slash")
	
	# Slight lunge forward
	var move_dir = Vector2.RIGHT if not animated_sprite.flip_h else Vector2.LEFT
	var attack_timer = 0.0
	var attack_duration = 0.5
	
	while attack_timer < attack_duration:
		velocity.x = move_dir.x * (chase_speed * 0.4)
		
		if player and attack_timer > 0.2:
			var distance = global_position.distance_to(player.global_position)
			if distance < 95.0:
				_apply_attack_damage("down_slash")
		
		attack_timer += get_physics_process_delta_time()
		await get_tree().process_frame
	
	velocity.x = 0
	_hide_all_damage_areas()
	
	await get_tree().create_timer(0.3).timeout
	is_performing_attack = false
	current_state = State.CHASE
	
	await get_tree().create_timer(down_slash_cooldown).timeout
	can_down_slash = true

func _perform_jump_up_attack() -> void:
	if not can_jump_up_attack or not is_on_floor() or is_performing_attack:
		return
	
	is_performing_attack = true
	can_jump_up_attack = false
	
	var jump_dir = Vector2.RIGHT
	if player:
		jump_dir = Vector2.RIGHT if player.global_position.x > global_position.x else Vector2.LEFT
		animated_sprite.flip_h = jump_dir.x < 0
	
	_activate_damage_area("jump_up_attack")
	Global.batDamageAmount = jump_up_attack_damage
	
	print("[Enemy] JUMP UP ATTACK!")
	animated_sprite.play("jump_up_attack")
	
	# Launch into air
	velocity.y = -450.0
	
	# Move towards player during jump
	var air_timer = 0.0
	var hit_applied = false
	
	while not is_on_floor() and air_timer < 1.5:
		velocity.x = jump_dir.x * 200.0
		
		# Check for hit while airborne
		if player and not hit_applied:
			var distance = global_position.distance_to(player.global_position)
			if distance < 110.0:
				_apply_attack_damage("jump_up_attack")
				hit_applied = true
		
		air_timer += get_physics_process_delta_time()
		await get_tree().process_frame
	
	velocity.x = 0
	_hide_all_damage_areas()
	
	# Wait for landing
	while not is_on_floor():
		await get_tree().process_frame
	
	await get_tree().create_timer(0.3).timeout
	is_performing_attack = false
	current_state = State.CHASE
	
	await get_tree().create_timer(jump_up_attack_cooldown).timeout
	can_jump_up_attack = true

func _perform_jump_down_attack() -> void:
	if not can_jump_down_attack or not is_on_floor() or is_performing_attack:
		return
	
	is_performing_attack = true
	can_jump_down_attack = false
	
	var jump_dir = Vector2.RIGHT
	if player:
		jump_dir = Vector2.RIGHT if player.global_position.x > global_position.x else Vector2.LEFT
		animated_sprite.flip_h = jump_dir.x < 0
	
	_activate_damage_area("jump_down_attack")
	Global.batDamageAmount = jump_down_attack_damage
	
	print("[Enemy] JUMP DOWN ATTACK!")
	animated_sprite.play("jump_down_attack")
	
	# High jump
	velocity.y = -500.0
	
	# Rise to peak
	var rise_timer = 0.0
	while velocity.y < 0 and rise_timer < 0.5:
		velocity.x = jump_dir.x * 150.0
		rise_timer += get_physics_process_delta_time()
		await get_tree().process_frame
	
	# Pause at peak
	velocity.x = 0
	await get_tree().create_timer(0.2).timeout
	
	# Fast fall with tracking
	velocity.y = 800.0
	if player:
		var to_player = (player.global_position.x - global_position.x)
		velocity.x = sign(to_player) * 250.0
	
	# Wait for landing
	while not is_on_floor():
		await get_tree().process_frame
	
	# Impact shockwave
	velocity.x = 0
	_create_ground_shockwave()
	
	# Check for direct hit
	if player:
		var distance = global_position.distance_to(player.global_position)
		if distance < 120.0:
			_apply_attack_damage("jump_down_attack")
	
	_hide_all_damage_areas()
	
	await get_tree().create_timer(0.5).timeout
	is_performing_attack = false
	current_state = State.CHASE
	
	await get_tree().create_timer(jump_down_attack_cooldown).timeout
	can_jump_down_attack = true

func _perform_idle_up_attack() -> void:
	if not can_idle_up_attack or is_performing_attack:
		return
	
	is_performing_attack = true
	can_idle_up_attack = false
	
	if player:
		animated_sprite.flip_h = player.global_position.x < global_position.x
	
	_activate_damage_area("idle_up_attack")
	Global.batDamageAmount = idle_up_attack_damage
	
	print("[Enemy] IDLE UP ATTACK!")
	animated_sprite.play("idle_up_attack")
	
	# Very slight movement
	var move_dir = Vector2.RIGHT if not animated_sprite.flip_h else Vector2.LEFT
	var attack_timer = 0.0
	var attack_duration = 0.5
	
	while attack_timer < attack_duration:
		velocity.x = move_dir.x * (chase_speed * 0.25)
		
		if player and attack_timer > 0.15:
			var distance = global_position.distance_to(player.global_position)
			if distance < 85.0:
				_apply_attack_damage("idle_up_attack")
		
		attack_timer += get_physics_process_delta_time()
		await get_tree().process_frame
	
	velocity.x = 0
	_hide_all_damage_areas()
	
	await get_tree().create_timer(0.2).timeout
	is_performing_attack = false
	current_state = State.CHASE
	
	await get_tree().create_timer(idle_up_attack_cooldown).timeout
	can_idle_up_attack = true

func _apply_attack_damage(attack_name: String) -> void:
	if not player or not Global.playerAlive:
		return
	
	# Prevent multiple hits from same attack
	if last_hit_player:
		return
	
	var distance = global_position.distance_to(player.global_position)
	var attack_range = 100.0  # Base range
	
	if attack_name in ["jump_up_attack", "jump_down_attack"]:
		attack_range = 120.0
	elif attack_name in ["dash_attack", "special_dash"]:
		attack_range = 110.0
	
	print("[Enemy] Checking hit for ", attack_name, " - Distance: ", distance, " Range: ", attack_range)
	
	if distance < attack_range:
		var damage = _get_attack_damage(attack_name)
		if player.has_method("take_damage"):
			player.take_damage(damage)
			last_hit_player = true
			print("[Enemy] *** HIT! *** ", attack_name, " dealt ", damage, " damage")
			
			if enemy_type == EnemyType.MACHINE_LEARNING:
				MlEnemyData.record_attack_result(attack_name, true)
			
			if player.has_method("apply_knockback"):
				var knockback_dir = (player.global_position - global_position).normalized()
				var knockback_amount = KNOCKBACK_FORCE * 0.8
				if attack_name in ["special_dash", "jump_down_attack"]:
					knockback_amount = KNOCKBACK_FORCE * 1.2
				player.apply_knockback(knockback_dir * knockback_amount)
	else:
		print("[Enemy] MISSED - Distance ", distance, " > Range ", attack_range)

func _state_idle(delta: float) -> void:
	velocity.x = 0.0

func _state_return_to_patrol(delta: float) -> void:
	var distance_to_center = global_position.distance_to(patrol_center)
	
	if distance_to_center < 50.0:
		print("[Enemy] Reached patrol center, resuming wander")
		current_state = State.WANDER
		return
	
	# Use navigation agent for pathfinding back to patrol center
	navigation_agent.target_position = patrol_center
	
	if not navigation_agent.is_navigation_finished():
		var next_position = navigation_agent.get_next_path_position()
		var direction_to_next = (next_position - global_position).normalized()
		
		velocity.x = direction_to_next.x * base_speed
		
		if abs(direction_to_next.x) > 0.1:
			animated_sprite.flip_h = direction_to_next.x < 0
		
		if is_on_floor() and _should_jump_obstacle(direction_to_next):
			_perform_jump()

func _state_wander(delta: float) -> void:
	if edge_check_cooldown <= 0.0:
		if is_on_wall():
			wander_direction *= -1
			wander_time = 0.0
			edge_check_cooldown = 1.0
		elif _check_edge_ahead():
			wander_direction *= -1
			wander_time = 0.0
			edge_check_cooldown = 1.0
	
	velocity.x = wander_direction * base_speed
	
	if abs(velocity.x) > 10.0:
		animated_sprite.flip_h = wander_direction < 0

func _check_edge_ahead() -> bool:
	return false
#PATHFINDING AND A* - Finds optimal paths around obstacles using a cost-based search algorithm
func _state_chase(delta: float) -> void:
	if not player or not Global.playerAlive:
		current_state = State.WANDER
		return
	
	print("[Enemy] CHASING - Distance: ", _get_distance_to_player())
	
	# Set navigation target
	navigation_agent.target_position = player.global_position
	
	# Get next position in path
	if not navigation_agent.is_navigation_finished():
		var next_position = navigation_agent.get_next_path_position()
		var direction = (next_position - global_position).normalized()
		
		# Jump over obstacles
		if is_on_floor() and _should_jump_obstacle(direction):
			_perform_jump()
		
		velocity.x = direction.x * chase_speed
		
		if abs(direction.x) > 0.1:
			animated_sprite.flip_h = direction.x < 0
	else:
		# Direct movement to player
		var direction = (player.global_position - global_position).normalized()
		velocity.x = direction.x * chase_speed
		
		if abs(direction.x) > 0.1:
			animated_sprite.flip_h = direction.x < 0

#RAYCASTING - Shoots a ray in front of the enemy to check if there's a wall/obstacle. 
#If it hits something, the enemy knows to jump.
func _should_jump_obstacle(direction: Vector2) -> bool:
	if not can_jump or not is_on_floor():
		return false
	
	var space_state = get_world_2d().direct_space_state
	var check_pos = global_position + Vector2(direction.x * jump_check_distance, 0)
	
	var query = PhysicsRayQueryParameters2D.create(global_position, check_pos)
	query.exclude = [self]
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	return not result.is_empty()

func _perform_jump() -> void:
	if can_jump and is_on_floor():
		velocity.y = jump_velocity
		can_jump = false
		
		await get_tree().create_timer(jump_cooldown).timeout
		can_jump = true

func _state_jump_attack(delta: float) -> void:
	if not is_jump_attacking:
		is_jump_attacking = true
		can_jump_attack = false
		jump_attack_timer = jump_attack_duration
		
		if player and is_on_floor():
			var distance_to_player = global_position.distance_to(player.global_position)
			
			if distance_to_player > jump_attack_range:
				print("[Enemy] Player too far for jump attack!")
				is_jump_attacking = false
				can_jump_attack = false
				_start_attack_recovery()
				await get_tree().create_timer(jump_attack_cooldown).timeout
				can_jump_attack = true
				return
			
			var target_position = player.global_position
			var distance_x = target_position.x - global_position.x
			var distance_y = target_position.y - global_position.y
			
			var time_to_peak = abs(jump_attack_height) / GRAVITY
			var total_time = time_to_peak * 2.0
			
			if distance_y < 0:
				total_time *= 0.9
			elif distance_y > 0:
				total_time *= 1.1
			
			var required_velocity_x = distance_x / total_time
			required_velocity_x = clamp(required_velocity_x, -jump_attack_speed, jump_attack_speed)
			
			velocity.y = jump_attack_height
			velocity.x = required_velocity_x
			
			animated_sprite.flip_h = distance_x < 0
			print("[Enemy] Jump attack! Target distance: ", distance_to_player, " Velocity X: ", required_velocity_x)
	
	if was_on_floor == false and is_on_floor():
		_create_ground_shockwave()
		
		if player:
			var distance = global_position.distance_to(player.global_position)
			print("[Enemy] Landed! Distance from player: ", distance)
			
			if distance < 80.0:
				_apply_melee_damage()
				if player.has_method("apply_knockback"):
					var knockback_dir = (player.global_position - global_position).normalized()
					player.apply_knockback(knockback_dir * KNOCKBACK_FORCE * 1.5)
				
				if enemy_type == EnemyType.MACHINE_LEARNING:
					if distance >= 80.0:
						MlEnemyData.record_attack_result("jump_attack", true)
		
		is_jump_attacking = false
		jump_attack_direction = Vector2.ZERO
		velocity.x = 0.0
		_start_attack_recovery()
		
		await get_tree().create_timer(jump_attack_cooldown).timeout
		can_jump_attack = true
		return
	
	jump_attack_timer -= delta
	if jump_attack_timer <= 0.0:
		is_jump_attacking = false
		jump_attack_direction = Vector2.ZERO
		velocity.x = 0.0
		if is_on_floor():
			_start_attack_recovery()
		
		await get_tree().create_timer(jump_attack_cooldown).timeout
		can_jump_attack = true

func _create_ground_shockwave() -> void:
	is_shockwave_active = true
	shockwave_timer = shockwave_duration
	print("[Enemy] GROUND SHOCKWAVE!")
	
	_spawn_shockwave_visual()
	
	if player and Global.playerAlive:
		var distance = global_position.distance_to(player.global_position)
		var player_on_ground = player.is_on_floor() if player.has_method("is_on_floor") else true
		
		if distance <= shockwave_radius and player_on_ground:
			if player.has_method("take_damage"):
				player.take_damage(shockwave_damage)
				print("[Enemy] Shockwave hit player for ", shockwave_damage, " damage")
				
				if enemy_type == EnemyType.MACHINE_LEARNING:
					MlEnemyData.record_attack_result("jump_attack", true)
				
				if player.has_method("apply_knockback"):
					var knockback_dir = (player.global_position - global_position).normalized()
					player.apply_knockback(knockback_dir * KNOCKBACK_FORCE * 0.7)

func _spawn_shockwave_visual() -> void:
	var directions = [-1, 1]
	
	for dir in directions:
		var shockwave_line = Node2D.new()
		get_parent().add_child(shockwave_line)
		shockwave_line.global_position = global_position
		
		for i in range(3):
			var line = Line2D.new()
			shockwave_line.add_child(line)
			line.default_color = Color(1.0, 0.8, 0.2, 0.8 - i * 0.2)
			line.width = 4.0 - i
			
			var points = []
			var wave_length = 100.0
			var segments = 20
			for j in range(segments):
				var x = (j / float(segments)) * wave_length * dir
				var y = sin(j * 0.5) * 5.0 - (i * 3.0)
				points.append(Vector2(x, y))
			line.points = PackedVector2Array(points)
		
		var tween = create_tween()
		tween.set_parallel(true)
		
		for child in shockwave_line.get_children():
			if child is Line2D:
				tween.tween_property(child, "width", 0.0, shockwave_duration)
				tween.tween_property(child, "default_color:a", 0.0, shockwave_duration)
				
				var original_points = child.points
				var extended_points = PackedVector2Array()
				for point in original_points:
					extended_points.append(Vector2(point.x * 2.0, point.y))
				tween.tween_property(child, "points", extended_points, shockwave_duration)
		
		tween.tween_callback(shockwave_line.queue_free).set_delay(shockwave_duration)

func _state_attack(delta: float) -> void:
	if not is_attacking_melee:
		is_attacking_melee = true
		can_attack = false
		
		velocity.x = 0.0
		
		should_deal_melee_damage = true
		melee_damage_timer = MELEE_DAMAGE_DELAY
		
		await get_tree().create_timer(0.8).timeout
		
		is_attacking_melee = false
		should_deal_melee_damage = false
		_start_attack_recovery()
		
		await get_tree().create_timer(attack_cooldown).timeout
		can_attack = true
	else:
		velocity.x = 0.0

func _start_attack_recovery() -> void:
	is_recovering = true
	current_state = State.IDLE
	await get_tree().create_timer(0.3).timeout  # Reduced from 1.0
	is_recovering = false
	if not dead:
		current_state = State.ATTACK  # Go straight back to attacking!

func _apply_melee_damage() -> void:
	if not player or not Global.playerAlive:
		return
	
	var distance = global_position.distance_to(player.global_position)
	if distance < 70.0:
		if player.has_method("take_damage"):
			player.take_damage(damage_to_deal)
			print("[Enemy] Hit player for ", damage_to_deal, " damage")
			
			if enemy_type == EnemyType.MACHINE_LEARNING:
				MlEnemyData.record_attack_result("melee", true)
			
			if player.has_method("apply_knockback"):
				var knockback_dir = (player.global_position - global_position).normalized()
				player.apply_knockback(knockback_dir * KNOCKBACK_FORCE)

func _shoot_projectile(direction: Vector2) -> void:
	var projectile_scene_path = "res://scene/enemy_projectile.tscn"
	
	if ResourceLoader.exists(projectile_scene_path):
		var projectile = load(projectile_scene_path).instantiate()
		get_parent().add_child(projectile)
		projectile.global_position = global_position + direction * 30.0
		
		if projectile.has_method("set_direction"):
			projectile.set_direction(direction, damage_to_deal)
			projectile.knockback_force = RANGED_KNOCKBACK
		
		if enemy_type == EnemyType.MACHINE_LEARNING:
			MlEnemyData.record_attack_result("ranged", true)

#RAYCASTING - Shoots a ray from the enemy to the player. If nothing blocks the ray (result is empty),
#the enemy can see the player. If something blocks it (wall, obstacle), the enemy cannot see the player.
func _has_line_of_sight() -> bool:
	if not player:
		return false
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.exclude = [self]
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func _get_distance_to_player() -> float:
	if not player:
		return 999999.0
	return global_position.distance_to(player.global_position)

func _handle_animation() -> void:
	if not animated_sprite:
		return
	
	if dead:
		animated_sprite.play("death")
		return
	
	if taking_damage:
		animated_sprite.play("hurt")
		return
	
	# Don't override animation if it's currently playing an attack animation
	var current_anim = animated_sprite.animation
	var attack_animations = ["dash_attack", "vertical_slash", "special_dash", "down_slash", 
							  "jump_up_attack", "jump_down_attack", "idle_up_attack"]
	
	# If an attack animation is playing and not finished, don't change it
	if current_anim in attack_animations and animated_sprite.is_playing():
		return
	
	# State-based animations
	if is_dashing:
		if current_anim == "special_dash":
			animated_sprite.play("special_dash")
		else:
			animated_sprite.play("dash")
	elif not is_on_floor():
		animated_sprite.play("jump")
	elif abs(velocity.x) > 10.0:
		animated_sprite.play("run")
	else:
		animated_sprite.play("idle")

func take_damage(damage: int) -> void:
	if dead:
		return
	
	health -= damage
	taking_damage = true
	print("[Enemy] Took ", damage, " damage. Health: ", health, "/", health_max)
	
	if health <= 0:
		health = 0
		dead = true
		animated_sprite.play("death")
		print("[Enemy] DEFEATED!")
	else:
		if animated_sprite:
			animated_sprite.play("hurt")
		
		await get_tree().create_timer(0.3).timeout
		taking_damage = false

func _handle_death(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0
	
	velocity.x = 0.0
	
	if is_on_floor():
		await get_tree().create_timer(2.0).timeout
		queue_free()

func _on_detection_area_entered(body: Node2D) -> void:
	if body is Player:
		print("[Enemy] Player detected!")
		can_see_player = true
		if enemy_type != EnemyType.ADAPTIVE_AI and enemy_type != EnemyType.MACHINE_LEARNING and current_state == State.WANDER:
			current_state = State.CHASE

func _on_detection_area_exited(body: Node2D) -> void:
	if body is Player:
		print("[Enemy] Player lost!")
		can_see_player = false

func _on_hitbox_area_entered(area: Area2D) -> void:
	print("[Enemy] Hitbox entered by: ", area.name if area else "null")
	print("[Enemy] Global.playerDamageZone: ", Global.playerDamageZone)
	print("[Enemy] Are they equal? ", area == Global.playerDamageZone)
	print("[Enemy] Dead status: ", dead)
	
	if area == Global.playerDamageZone:
		var damage = Global.playerDamageAmount
		print("[Enemy] Taking damage: ", damage)
		take_damage(damage)
	else:
		print("[Enemy] Area does not match playerDamageZone")
