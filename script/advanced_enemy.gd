extends CharacterBody2D
class_name AdvancedEnemy

@export var navigation_region: NavigationRegion2D

# Enemy Type Configuration
enum EnemyType { PATROL_GUARD, PERSISTENT_HUNTER, ADAPTIVE_AI, MACHINE_LEARNING }
@export var enemy_type: EnemyType = EnemyType.PATROL_GUARD

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
enum State { IDLE, WANDER, CHASE, ATTACK, CHARGE, RANGED_ATTACK, JUMP_ATTACK, RETURN_TO_PATROL} #SPIN_ATTACK }
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

# Charge Attack System
var charge_speed: float = 300.0
var charge_duration: float = 2.0
var charge_cooldown: float = 3.0
var charge_timer: float = 0.0
var is_charging: bool = false
var can_charge: bool = true
var charge_direction: Vector2 = Vector2.ZERO

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

# Jump Attack Shockwave
var shockwave_radius: float = 100.0
var shockwave_damage: int = 15
var shockwave_duration: float = 0.3
var is_shockwave_active: bool = false
var shockwave_timer: float = 0.0

# Ranged Attack System
var ranged_attack_range: float = 400.0
var ranged_cooldown: float = 3.0
var last_ranged_time: float = 0.0
var can_ranged: bool = true
var is_attacking_ranged: bool = false

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

# Spin Attack System
var spin_attack_duration: float = 1.0
var spin_attack_speed: float = 6.0
var spin_attack_move_speed: float = 100.0
var spin_attack_cooldown: float = 3.0
var is_spin_attacking: bool = false
var can_spin_attack: bool = true
var spin_attack_damage: int = 10
var spin_attack_tick_rate: float = 0.3
var spin_attack_timer: float = 0.0
var spin_damage_timer: float = 0.0
var spin_rotation: float = 0.0

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
	
	if has_node("DealDamageArea"):
		Global.batDamageZone = $DealDamageArea
	#Global.batDamageAmount = damage_to_deal
	
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
	
	ml_attack_preference = MlEnemyData.learning_data.attack_success_rates.duplicate()
	
	print("[ML Enemy] Initialized with difficulty: ", ml_difficulty_multiplier)
	print("[ML Enemy] Health: ", health, "/", health_max)
	print("[ML Enemy] Attack preferences: ", ml_attack_preference)
	print("[ML Enemy] Player behavior data: ", MlEnemyData.learning_data.player_behavior_patterns)
	MlEnemyData.record_encounter()
	ml_difficulty_multiplier = MlEnemyData.get_adaptation_multiplier()
	
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
			EnemyType.PATROL_GUARD:
				circle.radius = patrol_radius
			EnemyType.PERSISTENT_HUNTER:
				circle.radius = 600.0
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
		EnemyType.PATROL_GUARD: return "Patrol Guard"
		EnemyType.PERSISTENT_HUNTER: return "Persistent Hunter"
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
	
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		if velocity.y > 0:
			velocity.y = 0
	
	if edge_check_cooldown > 0:
		edge_check_cooldown -= delta
	
	if should_deal_melee_damage:
		melee_damage_timer -= delta
		if melee_damage_timer <= 0.0:
			_apply_melee_damage()
			should_deal_melee_damage = false
	
	if not is_recovering and not taking_damage:
		_update_state(delta)
	
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.WANDER:
			_state_wander(delta)
		State.CHASE:
			_state_chase(delta)
		State.CHARGE:
			_state_charge(delta)
		State.RANGED_ATTACK:
			_state_ranged_attack(delta)
		State.ATTACK:
			_state_attack(delta)
		State.JUMP_ATTACK:
			_state_jump_attack(delta)
		State.RETURN_TO_PATROL:
			_state_return_to_patrol(delta)
		#State.SPIN_ATTACK:
		#	_state_spin_attack(delta)
	
	velocity.x = lerp(velocity.x, target_velocity_x, velocity_smoothing * delta)
	
	was_on_floor = is_on_floor()
	move_and_slide()
	_handle_animation()

func _state_spin_attack(delta: float) -> void:
	if not is_spin_attacking:
		is_spin_attacking = true
		can_spin_attack = false
		spin_attack_timer = spin_attack_duration
		spin_damage_timer = spin_attack_tick_rate
		spin_rotation = 0.0
		
		print("[Enemy] SPIN ATTACK!")
	
	if player and Global.playerAlive:
		var distance_to_player = global_position.distance_to(player.global_position)
		
		if distance_to_player > 50.0:
			var direction = (player.global_position - global_position).normalized()
			target_velocity_x = direction.x * spin_attack_move_speed
		else:
			target_velocity_x = lerp(target_velocity_x, 0.0, 10.0 * delta)
	else:
		target_velocity_x = 0.0
	
	spin_rotation += spin_attack_speed * TAU * delta
	var normalized_rotation = fmod(spin_rotation, TAU)
	
	if normalized_rotation > PI:
		animated_sprite.flip_h = true
	else:
		animated_sprite.flip_h = false
	
	animated_sprite.rotation = sin(normalized_rotation * 2.0) * 0.4
	
	spin_damage_timer -= delta
	if spin_damage_timer <= 0.0:
		_apply_spin_damage()
		spin_damage_timer = spin_attack_tick_rate
	
	spin_attack_timer -= delta
	if spin_attack_timer <= 0.0:
		is_spin_attacking = false
		animated_sprite.rotation = 0.0
		target_velocity_x = 0.0
		
		if player:
			var final_dir = (player.global_position - global_position).normalized()
			animated_sprite.flip_h = final_dir.x < 0
		
		_start_attack_recovery()
		
		await get_tree().create_timer(spin_attack_cooldown).timeout
		can_spin_attack = true

func _apply_spin_damage() -> void:
	if not player or not Global.playerAlive:
		return
	
	var distance = global_position.distance_to(player.global_position)
	if distance < 90.0:
		if player.has_method("take_damage"):
			player.take_damage(spin_attack_damage)
			print("[Enemy] Spin hit player for ", spin_attack_damage, " damage")
			
			if enemy_type == EnemyType.MACHINE_LEARNING:
				MlEnemyData.record_attack_result("spin_attack", true)
			
			if player.has_method("apply_knockback"):
				var knockback_dir = (player.global_position - global_position).normalized()
				player.apply_knockback(knockback_dir * (KNOCKBACK_FORCE * 0.4))

func _check_phase_transition() -> void:
	var health_percent = float(health) / float(health_max)
	
	if health_percent <= phase2_threshold and current_phase == Phase.PHASE1:
		_enter_phase2()

func _enter_phase2() -> void:
	current_phase = Phase.PHASE2
	print("[Enemy] PHASE 2 ACTIVATED! (60% HP)")
	
	attack_cooldown = max(1.0, attack_cooldown - 0.5)
	charge_cooldown = max(2.5, charge_cooldown - 0.5)
	ranged_cooldown = max(2.5, ranged_cooldown - 0.5)
	jump_attack_cooldown = max(3.5, jump_attack_cooldown - 0.5)
	
	base_speed += 50.0
	chase_speed += 50.0
	
	phase2_multishot = true

func _is_player_in_patrol_zone() -> bool:
	if not player:
		return false
	var distance_from_center = player.global_position.distance_to(patrol_center)
	return distance_from_center <= patrol_radius

func _is_far_from_patrol_center() -> bool:
	var distance_from_center = global_position.distance_to(patrol_center)
	return distance_from_center > patrol_radius * 1.5

func _update_state(delta: float) -> void:
	if is_attacking_melee or is_attacking_ranged or is_jump_attacking or is_spin_attacking:
		return
	
	if is_charging:
		return
	
	var distance_to_player = _get_distance_to_player()
	can_see_player = _has_line_of_sight() and _is_in_detection_range()
	
	match enemy_type:
		EnemyType.PATROL_GUARD:
			_update_patrol_guard_state(distance_to_player)
		EnemyType.PERSISTENT_HUNTER:
			_update_persistent_hunter_state(distance_to_player)
		EnemyType.ADAPTIVE_AI:
			_update_adaptive_ai_state(distance_to_player)
		EnemyType.MACHINE_LEARNING:
			_update_machine_learning_state(distance_to_player)

func _is_in_detection_range() -> bool:
	if not player:
		return false
	
	var distance = global_position.distance_to(player.global_position)
	
	match enemy_type:
		EnemyType.PATROL_GUARD:
			return distance < patrol_radius
		EnemyType.PERSISTENT_HUNTER:
			return distance < 600.0
		EnemyType.ADAPTIVE_AI:
			return true
		EnemyType.MACHINE_LEARNING:
			return true
	
	return false

func _update_patrol_guard_state(distance: float) -> void:
	if return_to_patrol_when_far and _is_far_from_patrol_center():
		if current_state != State.RETURN_TO_PATROL:
			print("[Enemy] Too far from patrol zone, returning...")
			current_state = State.RETURN_TO_PATROL
		return
	
	if not _is_player_in_patrol_zone() or not can_see_player:
		if current_state != State.WANDER and current_state != State.RETURN_TO_PATROL:
			print("[Enemy] Player left patrol zone, wandering")
			current_state = State.WANDER
		return
	
	if distance > 150.0 and can_charge:
		current_state = State.CHARGE
	elif distance < 60.0 and can_attack:
		current_state = State.ATTACK
	elif can_see_player:
		current_state = State.CHASE

func _update_persistent_hunter_state(distance: float) -> void:
	if not can_see_player and distance > 600.0:
		if _is_far_from_patrol_center():
			if current_state != State.RETURN_TO_PATROL:
				print("[Enemy] Returning to patrol zone...")
				current_state = State.RETURN_TO_PATROL
			return
		else:
			if current_state != State.WANDER:
				current_state = State.WANDER
			return
	
	if not Global.playerAlive:
		if _is_far_from_patrol_center():
			if current_state != State.RETURN_TO_PATROL:
				current_state = State.RETURN_TO_PATROL
			return
		else:
			if current_state != State.WANDER:
				current_state = State.WANDER
			return
	
	if distance > 200.0 and distance < ranged_attack_range and can_ranged:
		current_state = State.RANGED_ATTACK
	elif distance < 60.0 and can_attack:
		current_state = State.ATTACK
	else:
		current_state = State.CHASE

func _update_adaptive_ai_state(distance: float) -> void:
	if not player or not Global.playerAlive:
		current_state = State.WANDER
		return
	
	var player_health = player.health if player else 100
	
	if distance > 80.0 and distance < 250.0 and can_jump_attack and is_on_floor():
		current_state = State.JUMP_ATTACK
		return
	
	if player_health < 30 and distance > 150.0 and distance < ranged_attack_range and can_ranged:
		current_state = State.RANGED_ATTACK
		return
	
	if distance > 200.0 and distance < ranged_attack_range and can_ranged:
		current_state = State.RANGED_ATTACK
		return
	elif distance > 150.0 and distance < 400.0 and can_charge:
		current_state = State.CHARGE
		return
	
	#if distance < 60.0 and can_spin_attack and not can_attack:
	#	current_state = State.SPIN_ATTACK
	#	return
	
	if distance < 60.0 and can_attack:
		current_state = State.ATTACK
	else:
		current_state = State.CHASE

func _update_machine_learning_state(distance: float) -> void:
	if not player or not Global.playerAlive:
		current_state = State.WANDER
		return
	
	var learned_distance = MlEnemyData.learning_data.player_behavior_patterns.avg_distance_kept
	var player_is_dodger = MlEnemyData.learning_data.player_behavior_patterns.dodge_frequency > 0.6
	var player_is_aggressive = MlEnemyData.learning_data.player_behavior_patterns.aggression_level > 0.6
	
	var best_attack = MlEnemyData.get_best_attack()
	
	# Priority 1: Counter dodging players with spin attack
	#if player_is_dodger and distance < 150.0 and can_spin_attack:
	#	current_state = State.SPIN_ATTACK
	#	return
	
	# Priority 2: Counter aggressive players with charge
	if player_is_aggressive and distance > 100.0 and distance < 300.0 and can_charge:
		current_state = State.CHARGE
		return
	
	# Priority 3: Use best learned attack based on success rates
	match best_attack:
		"ranged":
			if distance > 150.0 and distance < ranged_attack_range and can_ranged:
				current_state = State.RANGED_ATTACK
				return
		"charge":
			if distance > 150.0 and distance < 400.0 and can_charge:
				current_state = State.CHARGE
				return
		"jump_attack":
			if distance > 80.0 and distance < 250.0 and can_jump_attack and is_on_floor():
				current_state = State.JUMP_ATTACK
				return
		#"spin_attack":
		#	if distance < 90.0 and can_spin_attack:
		#		current_state = State.SPIN_ATTACK
		#		return
	
	# Fallback 1: Try other available attacks even if not "best"
	if distance > 200.0 and distance < ranged_attack_range and can_ranged:
		current_state = State.RANGED_ATTACK
		return
	elif distance > 150.0 and distance < 400.0 and can_charge:
		current_state = State.CHARGE
		return
	elif distance > 80.0 and distance < 250.0 and can_jump_attack and is_on_floor():
		current_state = State.JUMP_ATTACK
		return
	#elif distance < 90.0 and can_spin_attack:
	#	current_state = State.SPIN_ATTACK
	#	return
	
	# Fallback 2: Melee or chase
	if distance < 60.0 and can_attack:
		current_state = State.ATTACK
	else:
		current_state = State.CHASE
func _state_idle(delta: float) -> void:
	target_velocity_x = 0.0

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
		
		target_velocity_x = direction_to_next.x * base_speed
		
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
			print("[Enemy] Hit wall, turning around")
		elif _check_edge_ahead():
			wander_direction *= -1
			wander_time = 0.0
			edge_check_cooldown = 1.0
			print("[Enemy] Edge detected, turning around")
	
	target_velocity_x = wander_direction * base_speed
	
	if abs(target_velocity_x) > 10.0:
		animated_sprite.flip_h = wander_direction < 0

func _check_edge_ahead() -> bool:
	return false
#PATHFINDING AND A* - Finds optimal paths around obstacles using a cost-based search algorithm
func _state_chase(delta: float) -> void:
	if not player or not Global.playerAlive:
		current_state = State.WANDER
		return
	
	if enemy_type == EnemyType.PATROL_GUARD and not _is_player_in_patrol_zone():
		current_state = State.WANDER
		return
	
	# Set navigation target
	navigation_agent.target_position = player.global_position
	
	# Get next position in path using A* pathfinding
	if not navigation_agent.is_navigation_finished():
		var next_position = navigation_agent.get_next_path_position()
		var direction = (next_position - global_position).normalized()
		
		# Check if we should jump over obstacles
		if is_on_floor() and _should_jump_obstacle(direction):
			_perform_jump()
		
		target_velocity_x = direction.x * chase_speed
		
		if abs(direction.x) > 0.1:
			animated_sprite.flip_h = direction.x < 0
	else:
		# If navigation finished, move directly to player
		var direction = (player.global_position - global_position).normalized()
		target_velocity_x = direction.x * chase_speed
		
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

func _state_charge(delta: float) -> void:
	if not is_charging:
		is_charging = true
		can_charge = false
		charge_timer = charge_duration
		
		if player:
			charge_direction = (player.global_position - global_position).normalized()
			animated_sprite.flip_h = charge_direction.x < 0
			print("[Enemy] Starting charge!")
	
	target_velocity_x = charge_direction.x * charge_speed
	
	if is_on_wall() or _check_charge_hit_player():
		_end_charge()
		return
	
	charge_timer -= delta
	if charge_timer <= 0.0:
		_end_charge()

func _end_charge() -> void:
	is_charging = false
	charge_direction = Vector2.ZERO
	_start_attack_recovery()
	
	await get_tree().create_timer(charge_cooldown).timeout
	can_charge = true

func _check_charge_hit_player() -> bool:
	if not player:
		return false
	
	var distance = global_position.distance_to(player.global_position)
	if distance < 40.0:
		if player.has_method("apply_knockback"):
			var knockback_dir = (player.global_position - global_position).normalized()
			player.apply_knockback(knockback_dir * CHARGE_KNOCKBACK)
		_apply_melee_damage()
		
		if enemy_type == EnemyType.MACHINE_LEARNING:
			MlEnemyData.record_attack_result("charge", true)
		
		return true
	return false

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
			target_velocity_x = required_velocity_x
			
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
		target_velocity_x = 0.0
		_start_attack_recovery()
		
		await get_tree().create_timer(jump_attack_cooldown).timeout
		can_jump_attack = true
		return
	
	jump_attack_timer -= delta
	if jump_attack_timer <= 0.0:
		is_jump_attacking = false
		jump_attack_direction = Vector2.ZERO
		target_velocity_x = 0.0
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

func _state_ranged_attack(delta: float) -> void:
	if not is_attacking_ranged:
		is_attacking_ranged = true
		can_ranged = false
		shots_fired = 0
		
		target_velocity_x = 0.0
		
		if player:
			var dir = (player.global_position - global_position).normalized()
			animated_sprite.flip_h = dir.x < 0
			
			await get_tree().create_timer(0.5).timeout
			
			if not dead and player:
				_shoot_projectile(dir)
				shots_fired += 1
				
				if phase2_multishot and current_phase == Phase.PHASE2:
					await get_tree().create_timer(0.3).timeout
					
					if not dead and player:
						var player_vel = player.velocity if player else Vector2.ZERO
						var prediction_time = 0.5
						var predicted_pos = player.global_position + player_vel * prediction_time
						var predicted_dir = (predicted_pos - global_position).normalized()
						
						_shoot_projectile(predicted_dir)
						shots_fired += 1
		
		await get_tree().create_timer(0.8).timeout
		
		is_attacking_ranged = false
		_start_attack_recovery()
		
		await get_tree().create_timer(ranged_cooldown).timeout
		can_ranged = true
	else:
		target_velocity_x = 0.0

func _state_attack(delta: float) -> void:
	if not is_attacking_melee:
		is_attacking_melee = true
		can_attack = false
		target_velocity_x = 0.0
		
		# Telegraph pause before swinging
		await get_tree().create_timer(0.3).timeout
		if not is_instance_valid(self) or dead:
			return
		
		# This is the actual swing moment — sync this with your attack animation's hit frame
		_apply_melee_damage()
		
		await get_tree().create_timer(0.5).timeout
		
		is_attacking_melee = false
		_start_attack_recovery()
		
		await get_tree().create_timer(attack_cooldown).timeout
		can_attack = true
	else:
		target_velocity_x = 0.0

func _start_attack_recovery() -> void:
	is_recovering = true
	current_state = State.IDLE
	await get_tree().create_timer(attack_recovery_time).timeout
	is_recovering = false
	if not dead:
		if enemy_type == EnemyType.ADAPTIVE_AI or enemy_type == EnemyType.MACHINE_LEARNING or (player and can_see_player):
			current_state = State.CHASE
		else:
			current_state = State.WANDER

func _apply_melee_damage() -> void:
	if not player or not Global.playerAlive:
		return
	
	if attack_area:
		var overlapping = attack_area.get_overlapping_bodies()
		for body in overlapping:
			if body == player or body == Global.playerBody:
				if player.has_method("take_damage"):
					player.take_damage(damage_to_deal)
					print("[Enemy] Hit player for ", damage_to_deal, " damage")
					
					if enemy_type == EnemyType.MACHINE_LEARNING:
						MlEnemyData.record_attack_result("melee", true)
					
					if player.has_method("apply_knockback"):
						var knockback_dir = (player.global_position - global_position).normalized()
						player.apply_knockback(knockback_dir * KNOCKBACK_FORCE)
				return

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
	elif is_charging:
		animated_sprite.play("charge")
	elif is_jump_attacking:
		animated_sprite.play("jump" if animated_sprite.sprite_frames.has_animation("jump") else "run")
	elif is_attacking_ranged:
		animated_sprite.play("ranged")
	elif is_attacking_melee:
		animated_sprite.play("attack")
	elif is_spin_attacking:
		animated_sprite.play("attack")
	elif taking_damage:
		animated_sprite.play("hurt")
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
		MlEnemyData.record_boss_death()
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
	
	target_velocity_x = 0.0
	
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
