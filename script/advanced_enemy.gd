extends CharacterBody2D
class_name AdvancedEnemy

# Enemy Type Configuration
enum EnemyType { PATROL_GUARD, PERSISTENT_HUNTER, ADAPTIVE_AI }
@export var enemy_type: EnemyType = EnemyType.PATROL_GUARD

# Stats
@export var health: int = 500
@export var health_max: int = 500
var health_min: int = 0
@export var base_speed: float = 80.0
@export var chase_speed: float = 120.0
@export var damage_to_deal: int = 20  # CHANGE THIS IN INSPECTOR FOR DAMAGE

# Knockback settings
const KNOCKBACK_FORCE: float = 300.0
const CHARGE_KNOCKBACK: float = 400.0
const RANGED_KNOCKBACK: float = 150.0

# Patrol Configuration
@export var patrol_radius: float = 300.0
@export var patrol_wait_time: float = 2.0
var patrol_center: Vector2
var patrol_points: Array = []
var current_patrol_index: int = 0

# AI State
enum State { IDLE, PATROL, CHASE, ATTACK, CHARGE, RANGED_ATTACK, JUMP_ATTACK }
var current_state: State = State.PATROL
var player: CharacterBody2D
var is_player_in_patrol_zone: bool = false
var can_see_player: bool = false

# Combat
var dead: bool = false
var taking_damage: bool = false
var can_attack: bool = true
var attack_cooldown: float = 1.5
var last_attack_time: float = 0.0

# Charge Attack System
var charge_speed: float = 300.0
var charge_duration: float = 2.0
var charge_cooldown: float = 3.0
var charge_timer: float = 0.0
var is_charging: bool = false
var can_charge: bool = true
var charge_direction: Vector2 = Vector2.ZERO

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
var phase2_threshold: float = 0.6  # 60%

# Phase 2 - Multi-shot ranged
var phase2_multishot: bool = false
var shots_fired: int = 0

# Attack Recovery (pause after attack)
var attack_recovery_time: float = 1.0  # Changed from 0.5 to 1.0 second
var is_recovering: bool = false

# Pathfinding
var path: Array = []
var path_index: int = 0
var navigation_agent: NavigationAgent2D

# Visuals
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var patrol_area: Area2D = $PatrolArea
@onready var health_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null
@onready var hitbox: Area2D = $Hitbox if has_node("Hitbox") else null

# Physics
var GRAVITY: float = 980.0
var was_on_floor: bool = false

func _ready() -> void:
	patrol_center = global_position
	_setup_navigation()
	_generate_patrol_points()
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
	
	print("[Enemy] Initialized as ", _get_type_name())
	print("[Enemy] Patrol center at: ", patrol_center)

func _setup_hitbox() -> void:
	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered)
		print("[Enemy] Hitbox connected")

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
	
	if enemy_type == EnemyType.PATROL_GUARD:
		if not patrol_area:
			patrol_area = Area2D.new()
			add_child(patrol_area)
			var patrol_shape = CollisionShape2D.new()
			var patrol_circle = CircleShape2D.new()
			patrol_circle.radius = patrol_radius
			patrol_shape.shape = patrol_circle
			patrol_area.add_child(patrol_shape)
		
		if patrol_area:
			patrol_area.body_entered.connect(_on_patrol_area_entered)
			patrol_area.body_exited.connect(_on_patrol_area_exited)

func _generate_patrol_points() -> void:
	var num_points = randi_range(4, 6)
	for i in range(num_points):
		var angle = (TAU / num_points) * i + randf_range(-0.3, 0.3)
		var distance = randf_range(patrol_radius * 0.5, patrol_radius * 0.8)
		var point = patrol_center + Vector2(cos(angle), sin(angle)) * distance
		patrol_points.append(point)
	print("[Enemy] Generated ", patrol_points.size(), " patrol points")

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
	
	# Update AI state
	if not is_recovering:
		_update_state(delta)
	
	# Execute current state behavior
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.PATROL:
			_state_patrol(delta)
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
	
	was_on_floor = is_on_floor()
	move_and_slide()
	_handle_animation()

func _check_phase_transition() -> void:
	var health_percent = float(health) / float(health_max)
	
	if health_percent <= phase2_threshold and current_phase == Phase.PHASE1:
		_enter_phase2()

func _enter_phase2() -> void:
	current_phase = Phase.PHASE2
	print("[Enemy] PHASE 2 ACTIVATED! (60% HP) - Double ranged shots!")
	
	# Speed up cooldowns
	attack_cooldown = max(1.0, attack_cooldown - 0.5)
	charge_cooldown = max(2.5, charge_cooldown - 0.5)
	ranged_cooldown = max(2.5, ranged_cooldown - 0.5)
	jump_attack_cooldown = max(3.5, jump_attack_cooldown - 0.5)
	
	# Increase speed
	base_speed += 50.0
	chase_speed += 50.0
	
	# Enable multi-shot for ranged
	phase2_multishot = true

func _update_state(delta: float) -> void:
	if taking_damage or is_attacking_melee or is_attacking_ranged or is_jump_attacking:
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
			return distance < 500.0
	
	return false

func _update_patrol_guard_state(distance: float) -> void:
	if not is_player_in_patrol_zone or not can_see_player:
		if current_state != State.PATROL and current_state != State.IDLE:
			print("[Enemy] Player left patrol zone, returning to patrol")
			current_state = State.PATROL
		return
	
	if distance > 150.0 and can_charge:
		current_state = State.CHARGE
	elif distance < 60.0 and can_attack:
		current_state = State.ATTACK
	elif can_see_player:
		current_state = State.CHASE

func _update_persistent_hunter_state(distance: float) -> void:
	if not can_see_player and distance > 800.0:
		current_state = State.PATROL
		return
	
	if distance > 200.0 and distance < ranged_attack_range and can_ranged:
		current_state = State.RANGED_ATTACK
	elif distance < 60.0 and can_attack:
		current_state = State.ATTACK
	elif can_see_player:
		current_state = State.CHASE

func _update_adaptive_ai_state(distance: float) -> void:
	if not player or not Global.playerAlive:
		current_state = State.PATROL
		return
	
	if not can_see_player and distance > 800.0:
		current_state = State.PATROL
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
	elif can_see_player:
		current_state = State.CHASE

func _state_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, base_speed * delta * 5.0)

func _state_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		current_state = State.IDLE
		return
	
	var target_point = patrol_points[current_patrol_index]
	var distance_to_point = global_position.distance_to(target_point)
	
	if distance_to_point > 50.0:
		var direction = (target_point - global_position).normalized()
		velocity.x = direction.x * base_speed
		
		if direction.x != 0:
			animated_sprite.flip_h = direction.x < 0
	else:
		velocity.x = move_toward(velocity.x, 0, base_speed * delta * 5.0)
	
	if distance_to_point < 30.0:
		print("[Enemy] Reached patrol point ", current_patrol_index)
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		current_state = State.IDLE
		await get_tree().create_timer(patrol_wait_time).timeout
		if not dead and not can_see_player:
			current_state = State.PATROL

func _state_chase(delta: float) -> void:
	if not player or not Global.playerAlive:
		current_state = State.PATROL
		return
	
	if enemy_type == EnemyType.PATROL_GUARD and not is_player_in_patrol_zone:
		current_state = State.PATROL
		return
	
	var direction = (player.global_position - global_position).normalized()
	velocity.x = direction.x * chase_speed
	
	if direction.x != 0:
		animated_sprite.flip_h = direction.x < 0

func _state_charge(delta: float) -> void:
	if not is_charging:
		is_charging = true
		can_charge = false
		charge_timer = charge_duration
		
		if player:
			charge_direction = (player.global_position - global_position).normalized()
			animated_sprite.flip_h = charge_direction.x < 0
			print("[Enemy] Starting charge in direction: ", charge_direction)
	
	velocity.x = charge_direction.x * charge_speed
	
	# Check for collision with player or wall
	if is_on_wall() or _check_charge_hit_player():
		print("[Enemy] Charge hit something, stopping!")
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
	print("[Enemy] Charge ready again")

func _check_charge_hit_player() -> bool:
	if not player:
		return false
	
	var distance = global_position.distance_to(player.global_position)
	if distance < 40.0:
		# Apply knockback to player
		if player.has_method("apply_knockback"):
			var knockback_dir = (player.global_position - global_position).normalized()
			player.apply_knockback(knockback_dir * CHARGE_KNOCKBACK)
		_deal_melee_damage()
		return true
	return false

func _state_jump_attack(delta: float) -> void:
	if not is_jump_attacking:
		is_jump_attacking = true
		can_jump_attack = false
		
		if player and is_on_floor():
			# Predict player position
			var player_vel = player.velocity if player else Vector2.ZERO
			jump_attack_target = player.global_position + player_vel * jump_attack_predict_time
			
			# Jump toward target
			var direction = (jump_attack_target - global_position).normalized()
			velocity.y = jump_attack_velocity
			velocity.x = direction.x * chase_speed
			
			animated_sprite.flip_h = direction.x < 0
			print("[Enemy] Jump attack toward: ", jump_attack_target)
	
	# Check for landing
	if was_on_floor == false and is_on_floor():
		print("[Enemy] Jump attack landed!")
		# Deal damage in area
		if player:
			var distance = global_position.distance_to(player.global_position)
			if distance < 80.0:
				_deal_melee_damage()
				if player.has_method("apply_knockback"):
					var knockback_dir = (player.global_position - global_position).normalized()
					player.apply_knockback(knockback_dir * KNOCKBACK_FORCE)
		
		is_jump_attacking = false
		_start_attack_recovery()
		
		await get_tree().create_timer(jump_attack_cooldown).timeout
		can_jump_attack = true
		print("[Enemy] Jump attack ready again")

func _state_ranged_attack(delta: float) -> void:
	if not is_attacking_ranged:
		is_attacking_ranged = true
		can_ranged = false
		shots_fired = 0
		
		velocity.x = move_toward(velocity.x, 0, base_speed * delta * 10.0)
		
		if player:
			var dir = (player.global_position - global_position).normalized()
			animated_sprite.flip_h = dir.x < 0
			
			await get_tree().create_timer(0.5).timeout
			
			if not dead and player:
				# Fire first shot at current player position
				_shoot_projectile(dir)
				shots_fired += 1
				print("[Enemy] Fired ranged attack #1")
				
				# In Phase 2, fire second shot with prediction
				if phase2_multishot and current_phase == Phase.PHASE2:
					await get_tree().create_timer(0.3).timeout
					
					if not dead and player:
						# Predict player movement
						var player_vel = player.velocity if player else Vector2.ZERO
						var prediction_time = 0.5
						var predicted_pos = player.global_position + player_vel * prediction_time
						var predicted_dir = (predicted_pos - global_position).normalized()
						
						_shoot_projectile(predicted_dir)
						shots_fired += 1
						print("[Enemy] Fired ranged attack #2 (PREDICTED)")
		
		await get_tree().create_timer(0.8).timeout
		
		is_attacking_ranged = false
		_start_attack_recovery()
		
		await get_tree().create_timer(ranged_cooldown).timeout
		can_ranged = true
		print("[Enemy] Ranged attack ready again")
	else:
		velocity.x = move_toward(velocity.x, 0, base_speed * delta * 10.0)

func _state_attack(delta: float) -> void:
	if not is_attacking_melee:
		is_attacking_melee = true
		can_attack = false
		
		velocity.x = move_toward(velocity.x, 0, base_speed * delta * 10.0)
		
		_deal_melee_damage()
		
		# Apply knockback to player
		if player and player.has_method("apply_knockback"):
			var knockback_dir = (player.global_position - global_position).normalized()
			player.apply_knockback(knockback_dir * KNOCKBACK_FORCE)
		
		await get_tree().create_timer(0.8).timeout
		
		is_attacking_melee = false
		_start_attack_recovery()
		
		await get_tree().create_timer(attack_cooldown).timeout
		can_attack = true
		print("[Enemy] Melee attack ready again")
	else:
		velocity.x = move_toward(velocity.x, 0, base_speed * delta * 10.0)

func _start_attack_recovery() -> void:
	is_recovering = true
	current_state = State.IDLE
	await get_tree().create_timer(attack_recovery_time).timeout
	is_recovering = false
	if not dead:
		current_state = State.CHASE

func _deal_melee_damage() -> void:
	if not player or not Global.playerAlive:
		return
	
	var distance = global_position.distance_to(player.global_position)
	if distance < 70.0:
		if player.has_method("take_damage"):
			player.take_damage(damage_to_deal)
			print("[Enemy] Hit player with melee for ", damage_to_deal, " damage")

func _shoot_projectile(direction: Vector2) -> void:
	var projectile_scene_path = "res://scene/enemy_projectile.tscn"
	
	if ResourceLoader.exists(projectile_scene_path):
		var projectile = load(projectile_scene_path).instantiate()
		get_parent().add_child(projectile)
		projectile.global_position = global_position + direction * 30.0
		
		if projectile.has_method("set_direction"):
			projectile.set_direction(direction, damage_to_deal)
			projectile.knockback_force = RANGED_KNOCKBACK
	else:
		print("[Enemy] WARNING: Projectile scene not found at ", projectile_scene_path)

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
		print("[Enemy] DEFEATED!")
	else:
		# Show hurt animation immediately
		if animated_sprite:
			animated_sprite.play("hurt")
		
		# Shorter damage animation time
		await get_tree().create_timer(0.3).timeout
		taking_damage = false

func _handle_death(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0
	
	velocity.x = 0
	
	if is_on_floor():
		await get_tree().create_timer(2.0).timeout
		queue_free()

func _on_detection_area_entered(body: Node2D) -> void:
	if body is Player:
		print("[Enemy] Player detected!")
		can_see_player = true

func _on_detection_area_exited(body: Node2D) -> void:
	if body is Player:
		print("[Enemy] Player lost!")
		can_see_player = false

func _on_patrol_area_entered(body: Node2D) -> void:
	if body is Player:
		print("[Enemy] Player entered patrol zone!")
		is_player_in_patrol_zone = true

func _on_patrol_area_exited(body: Node2D) -> void:
	if body is Player:
		print("[Enemy] Player left patrol zone!")
		is_player_in_patrol_zone = false
		if enemy_type == EnemyType.PATROL_GUARD:
			current_state = State.PATROL

func _on_hitbox_area_entered(area: Area2D) -> void:
	print("[Enemy] Hitbox hit by: ", area.name, " from ", area.get_parent().name if area.get_parent() else "unknown")
	
	if area == Global.playerDamageZone:
		var damage = Global.playerDamageAmount
		print("[Enemy] Taking ", damage, " damage from player attack!")
		take_damage(damage)
