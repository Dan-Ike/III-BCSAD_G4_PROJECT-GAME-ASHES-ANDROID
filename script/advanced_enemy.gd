extends CharacterBody2D
class_name AdvancedEnemy

@export var navigation_region: NavigationRegion2D

# Enemy Type Configuration
enum EnemyType { PATROL_GUARD, PERSISTENT_HUNTER, ADAPTIVE_AI }
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
@export var return_to_patrol_when_far: bool = true  # Return to patrol zone if player leaves
var patrol_center: Vector2
var is_returning_to_patrol: bool = false

# Wandering (for when idle)
var wander_direction: int = 1  # 1 = right, -1 = left
var wander_time: float = 0.0
var wander_duration: float = 3.0  # Change direction every 3 seconds
var edge_check_cooldown: float = 0.0  # Prevent rapid edge detection

# AI State
enum State { IDLE, WANDER, CHASE, ATTACK, CHARGE, RANGED_ATTACK, JUMP_ATTACK, RETURN_TO_PATROL }
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

# Jump System (for obstacle navigation)
var jump_velocity: float = -400.0
var can_jump: bool = true
var jump_cooldown: float = 0.5
var jump_check_distance: float = 50.0

# Jump Attack System (Adaptive AI only)
var jump_attack_velocity: float = -350.0
var jump_attack_predict_time: float = 0.4
var is_jump_attacking: bool = false
var jump_attack_target: Vector2
var jump_attack_cooldown: float = 4.0
var can_jump_attack: bool = true

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

# Visuals
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var health_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null
@onready var hitbox: Area2D = $Hitbox if has_node("Hitbox") else null

# Physics
var GRAVITY: float = 980.0
var was_on_floor: bool = false

# Movement smoothing to prevent twitching
var target_velocity_x: float = 0.0
var velocity_smoothing: float = 10.0

func _ready() -> void:
	patrol_center = global_position
	_setup_navigation()
	_setup_detection_areas()
	_setup_hitbox()
	
	# Register with Global
	if has_node("DealDamageArea"):
		Global.batDamageZone = $DealDamageArea
	Global.batDamageAmount = damage_to_deal
	
	# Initialize health bar
	if health_bar:
		health_bar.max_value = health_max
		health_bar.value = health
	
	# Randomize initial wander direction
	wander_direction = 1 if randf() > 0.5 else -1
	wander_duration = randf_range(2.0, 4.0)
	
	# Adaptive AI starts knowing player location
	if enemy_type == EnemyType.ADAPTIVE_AI:
		current_state = State.CHASE
	else:
		current_state = State.WANDER
	
	print("[Enemy] Initialized as ", _get_type_name(), " at ", global_position)
	print("[Enemy] Patrol center: ", patrol_center)

func _setup_hitbox() -> void:
	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered)

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
		_: return "Unknown"

func _physics_process(delta: float) -> void:
	if dead:
		_handle_death(delta)
		return
	
	player = Global.playerBody
	
	# Update health bar
	if health_bar:
		health_bar.value = health
	
	# Check phase transitions
	_check_phase_transition()
	
	# Always apply gravity when not on floor
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		if velocity.y > 0:
			velocity.y = 0
	
	# Update edge check cooldown
	if edge_check_cooldown > 0:
		edge_check_cooldown -= delta
	
	# Handle melee damage delay
	if should_deal_melee_damage:
		melee_damage_timer -= delta
		if melee_damage_timer <= 0.0:
			_apply_melee_damage()
			should_deal_melee_damage = false
	
	# Update AI state
	if not is_recovering and not taking_damage:
		_update_state(delta)
	
	# Execute current state behavior
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
	
	# Smooth velocity to prevent twitching
	velocity.x = lerp(velocity.x, target_velocity_x, velocity_smoothing * delta)
	
	was_on_floor = is_on_floor()
	move_and_slide()
	_handle_animation()

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
	return distance_from_center > patrol_radius * 1.5  # 50% beyond patrol radius

func _update_state(delta: float) -> void:
	if is_attacking_melee or is_attacking_ranged or is_jump_attacking:
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
			return true  # Always knows where player is
	
	return false

func _update_patrol_guard_state(distance: float) -> void:
	# If we're far from patrol center and should return
	if return_to_patrol_when_far and _is_far_from_patrol_center():
		if current_state != State.RETURN_TO_PATROL:
			print("[Enemy] Too far from patrol zone, returning...")
			current_state = State.RETURN_TO_PATROL
		return
	
	# Check if player is in patrol zone
	if not _is_player_in_patrol_zone() or not can_see_player:
		if current_state != State.WANDER and current_state != State.RETURN_TO_PATROL:
			print("[Enemy] Player left patrol zone, wandering")
			current_state = State.WANDER
		return
	
	# Player is in range, engage
	if distance > 150.0 and can_charge:
		current_state = State.CHARGE
	elif distance < 60.0 and can_attack:
		current_state = State.ATTACK
	elif can_see_player:
		current_state = State.CHASE

func _update_persistent_hunter_state(distance: float) -> void:
	# If no player detected and far away, wander
	if not can_see_player and distance > 600.0:  # 600 is detection radius
		# Check if far from patrol center, return if needed
		if _is_far_from_patrol_center():
			if current_state != State.RETURN_TO_PATROL:
				print("[Enemy] Returning to patrol zone...")
				current_state = State.RETURN_TO_PATROL
			return  # Stay in return state
		else:
			# Close to patrol center, wander
			if current_state != State.WANDER:
				current_state = State.WANDER
			return
	
	# Once player is detected (can_see_player = true), chase forever until player or enemy dies
	if not Global.playerAlive:
		# Player is dead, return to patrol
		if _is_far_from_patrol_center():
			if current_state != State.RETURN_TO_PATROL:
				current_state = State.RETURN_TO_PATROL
			return
		else:
			if current_state != State.WANDER:
				current_state = State.WANDER
			return
	
	# Combat logic - will continue even if player leaves detection area after first detection
	if distance > 200.0 and distance < ranged_attack_range and can_ranged:
		current_state = State.RANGED_ATTACK
	elif distance < 60.0 and can_attack:
		current_state = State.ATTACK
	else:
		current_state = State.CHASE  # Always chase once detected

func _update_adaptive_ai_state(distance: float) -> void:
	if not player or not Global.playerAlive:
		current_state = State.WANDER
		return
	
	var player_health = player.health if player else 100
	
	# Jump attack if conditions are right
	if distance > 100.0 and distance < 300.0 and can_jump_attack and is_on_floor():
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
	
	if distance < 60.0 and can_attack:
		current_state = State.ATTACK
	else:
		current_state = State.CHASE

func _state_idle(delta: float) -> void:
	target_velocity_x = 0.0

func _state_return_to_patrol(delta: float) -> void:
	var direction_to_center = (patrol_center - global_position).normalized()
	var distance_to_center = global_position.distance_to(patrol_center)
	
	# If close enough to patrol center, resume wandering
	if distance_to_center < 50.0:
		print("[Enemy] Reached patrol center, resuming wander")
		current_state = State.WANDER
		return
	
	# Move toward patrol center
	target_velocity_x = direction_to_center.x * base_speed
	
	# Update sprite direction (only when direction is significant)
	if abs(direction_to_center.x) > 0.1:
		animated_sprite.flip_h = direction_to_center.x < 0
	
	# Jump over obstacles if needed
	if is_on_floor() and _should_jump_obstacle(direction_to_center):
		_perform_jump()

func _state_wander(delta: float) -> void:
	# Check for walls or edges (with cooldown to prevent rapid changes)
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
	
	# Move in wander direction
	target_velocity_x = wander_direction * base_speed
	
	# Only flip sprite if direction is meaningful
	if abs(target_velocity_x) > 10.0:
		animated_sprite.flip_h = wander_direction < 0

func _check_edge_ahead() -> bool:
	# Don't check edges - let them wander freely within navigation mesh
	# They'll naturally stay in bounds or hit walls
	return false

func _state_chase(delta: float) -> void:
	if not player or not Global.playerAlive:
		current_state = State.WANDER
		return
	
	# For Patrol Guard, check if still in patrol zone
	if enemy_type == EnemyType.PATROL_GUARD and not _is_player_in_patrol_zone():
		current_state = State.WANDER
		return
	
	var direction = (player.global_position - global_position).normalized()
	
	# Check for obstacles and jump if needed
	if is_on_floor() and _should_jump_obstacle(direction):
		_perform_jump()
	
	target_velocity_x = direction.x * chase_speed
	
	# Only flip sprite if direction is meaningful
	if abs(direction.x) > 0.1:
		animated_sprite.flip_h = direction.x < 0

func _should_jump_obstacle(direction: Vector2) -> bool:
	if not can_jump or not is_on_floor():
		return false
	
	# Check if there's a wall ahead
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
	
	# Check for collision with player or wall
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
		return true
	return false

func _state_jump_attack(delta: float) -> void:
	if not is_jump_attacking:
		is_jump_attacking = true
		can_jump_attack = false
		
		if player and is_on_floor():
			var player_vel = player.velocity if player else Vector2.ZERO
			jump_attack_target = player.global_position + player_vel * jump_attack_predict_time
			
			var direction = (jump_attack_target - global_position).normalized()
			velocity.y = jump_attack_velocity
			target_velocity_x = direction.x * chase_speed
			
			animated_sprite.flip_h = direction.x < 0
			print("[Enemy] Jump attack!")
	
	# Check for landing
	if was_on_floor == false and is_on_floor():
		if player:
			var distance = global_position.distance_to(player.global_position)
			if distance < 80.0:
				_apply_melee_damage()
				if player.has_method("apply_knockback"):
					var knockback_dir = (player.global_position - global_position).normalized()
					player.apply_knockback(knockback_dir * KNOCKBACK_FORCE)
		
		is_jump_attacking = false
		_start_attack_recovery()
		
		await get_tree().create_timer(jump_attack_cooldown).timeout
		can_jump_attack = true

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
		
		# Setup delayed damage
		should_deal_melee_damage = true
		melee_damage_timer = MELEE_DAMAGE_DELAY
		
		await get_tree().create_timer(0.8).timeout
		
		is_attacking_melee = false
		should_deal_melee_damage = false
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
		if enemy_type == EnemyType.ADAPTIVE_AI or (player and can_see_player):
			current_state = State.CHASE
		else:
			current_state = State.WANDER

func _apply_melee_damage() -> void:
	if not player or not Global.playerAlive:
		return
	
	var distance = global_position.distance_to(player.global_position)
	if distance < 70.0:
		if player.has_method("take_damage"):
			player.take_damage(damage_to_deal)
			print("[Enemy] Hit player for ", damage_to_deal, " damage")
			
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
		if enemy_type != EnemyType.ADAPTIVE_AI and current_state == State.WANDER:
			current_state = State.CHASE

func _on_detection_area_exited(body: Node2D) -> void:
	if body is Player:
		print("[Enemy] Player lost!")
		can_see_player = false

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area == Global.playerDamageZone:
		var damage = Global.playerDamageAmount
		take_damage(damage)
