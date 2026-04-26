extends CharacterBody2D

# ML System
var ml_system: Node = null
var last_player_position: Vector2 = Vector2.ZERO
var player_moved_aggressively: bool = false
var behavior_check_timer: float = 0.0
const BEHAVIOR_CHECK_INTERVAL = 1.0

# Node references
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area2: Area2D = $DetectionArea
@onready var patrol_area: Area2D = $PatrolArea
@onready var attack_area2: Area2D = $AttackArea
@onready var deal_damage_area_vertical_slash: Area2D = $DealDamageArea_VerticalSlash
@onready var deal_damage_area_jump_up_attack: Area2D = $DealDamageArea_JumpUpAttack
@onready var deal_damage_area_jump_down_attack: Area2D = $DealDamageArea_JumpDownAttack
@onready var deal_damage_area_down_slash: Area2D = $DealDamageArea_DownSlash
@onready var hitbox2: Area2D = $Hitbox
var navigation_agent: NavigationAgent2D = null

# Boss settings
@export var can_attack_through_platforms: bool = false

# Attack types
var vertical_slash_cooldown: float = 0.0
const VERTICAL_SLASH_COOLDOWN_TIME = 2.0
var down_slash_cooldown: float = 0.0
const DOWN_SLASH_COOLDOWN_TIME = 1.5

# Dash system
const DASH_SPEED = 400.0
const DASH_DURATION = 0.3
const DASH_COOLDOWN = 1.0
const DASH_TRIGGER_DISTANCE = 50.0

var dashing: bool = false
var dash_time: float = 0.0
var dash_cooldown_timer: float = 0.0
var can_dash: bool = true

# Pathfinding
var last_player_x: float = 0.0
var direction_lock_timer: float = 0.0
const DIRECTION_LOCK_TIME = 0.3

# AI Intelligence
var player_jump_count: int = 0
var player_last_on_ground: bool = true
var anticipate_jump_timer: float = 0.0
const ANTICIPATE_WINDOW = 0.8
var jump_decision_cooldown: float = 0.0
const JUMP_DECISION_COOLDOWN_TIME = 1.5

# Damage tracking
var players_hit_this_attack: Array = []

# States
enum State {
	IDLE,
	CHASE,
	ATTACK_READY,
	JUMPING,
	ATTACKING,
	HURT,
	RESTING,
	DEAD
}

var current_state: State = State.IDLE
var previous_state: State = State.IDLE

# Movement constants
const SPEED = 150.0
const CHASE_SPEED = 200.0
const JUMP_VELOCITY = -400.0
const GRAVITY = 980.0

# Health system
var health: int = 300
var health_max: int = 300
var health_min: int = 0
var can_take_damage: bool = true

# Detection and attack ranges
const DETECTION_RANGE = 500.0
const ATTACK_RANGE = 100.0
const CHASE_STOP_DISTANCE = 60.0

# Boss properties
var player: CharacterBody2D = null
var facing_direction: int = 1
var is_player_detected: bool = false
var can_jump: bool = true
var jump_cooldown: float = 0.0
var jump_count_reset_timer: float = 0.0
const JUMP_COOLDOWN_TIME = 0.5

# Attack properties
var is_attacking: bool = false
var attack_cooldown: float = 0.0
const ATTACK_COOLDOWN_TIME = 1.0

# Dash attack
var dash_attack_cooldown: float = 0.0
const DASH_ATTACK_COOLDOWN_TIME = 4.0
var special_dash_cooldown: float = 0.0
const SPECIAL_DASH_COOLDOWN_TIME = 6.0
const DASH_ATTACK_SPEED = 500.0
const SPECIAL_DASH_SPEED = 600.0
const DASH_ATTACK_DISTANCE = 80.0
var is_dash_attacking: bool = false

# Phase system
var current_phase: int = 1
var phase_2_triggered: bool = false
var phase_2_health_threshold: float = 0.5

# Knockback and invulnerability
var is_invulnerable: bool = false
const KNOCKBACK_FORCE = 200.0

# Rest/Recovery system
var time_attacking: float = 0.0
var is_resting: bool = false
var rest_timer: float = 0.0
const PHASE1_ATTACK_DURATION = 60.0
const PHASE2_ATTACK_DURATION = 120.0
const REST_DURATION = 5.0
var shockwave_triggered: bool = false

# Smart decision making
var should_retreat: bool = false
var retreat_timer: float = 0.0
const RETREAT_DURATION = 3.0
const RETREAT_DISTANCE = 250.0

# Attack telegraph delays
const ATTACK_TELEGRAPH_TIME = 0.2
var attack_telegraph_timer: float = 0.0
var is_telegraphing: bool = false

# Hurt state timer (fixed - no await)
var hurt_timer: float = 0.0
const HURT_DURATION: float = 0.3

# Jump air velocity tracking
var jump_air_velocity_x: float = 0.0

func _ready() -> void:
	change_state(State.IDLE)
	_disable_all_damage_areas()
	Global.bossDamageZone = hitbox2
	add_to_group("boss")
	ml_system = load("res://ml_boss_data.gd").new()
	add_child(ml_system)
	ml_system.record_encounter()

	navigation_agent = NavigationAgent2D.new()
	add_child(navigation_agent)
	navigation_agent.path_desired_distance = 10.0
	navigation_agent.target_desired_distance = 20.0
	navigation_agent.max_speed = CHASE_SPEED
	navigation_agent.avoidance_enabled = false

func _check_proactive_aerial_attack() -> bool:
	if not player or not can_jump or not is_on_floor():
		return false
	var vertical_distance = player.global_position.y - global_position.y
	var horizontal_distance = abs(player.global_position.x - global_position.x)
	if vertical_distance < -100 and horizontal_distance < 200:
		print("[Boss] Proactively jumping to attack player above!")
		return true
	return false

func _start_rest() -> void:
	print("[Boss] Resting to recover strength...")
	is_resting = true
	rest_timer = 0.0
	time_attacking = 0.0
	shockwave_triggered = false
	should_retreat = false
	retreat_timer = 0.0
	change_state(State.RESTING)

func _end_rest() -> void:
	if not is_instance_valid(self):
		return
	if not shockwave_triggered:
		_trigger_shockwave()
		await get_tree().create_timer(0.5).timeout
		if not is_instance_valid(self):
			return
	is_resting = false
	is_invulnerable = false
	can_take_damage = true
	print("[Boss] Rest complete! Resuming battle!")
	change_state(State.CHASE)

func _perform_jump_over_player() -> void:
	if not player:
		return
	print("[Boss] Jumping over player for aerial attack!")
	change_state(State.JUMPING)
	velocity.y = JUMP_VELOCITY * 1.2
	var direction_to_player = sign(player.global_position.x - global_position.x)
	facing_direction = direction_to_player
	jump_air_velocity_x = direction_to_player * CHASE_SPEED * 1.5

func _trigger_shockwave() -> void:
	if not is_instance_valid(self):
		return
	shockwave_triggered = true
	print("[Boss] SHOCKWAVE!")
	if animated_sprite_2d and is_instance_valid(animated_sprite_2d):
		var original_modulate = animated_sprite_2d.modulate
		animated_sprite_2d.modulate = Color(2.0, 2.0, 2.0)
		await get_tree().create_timer(0.2).timeout
		if not is_instance_valid(self) or not is_instance_valid(animated_sprite_2d):
			return
		animated_sprite_2d.modulate = original_modulate
	if player and is_instance_valid(player) and not player.dead:
		var distance = global_position.distance_to(player.global_position)
		if distance < 150:
			var direction = sign(player.global_position.x - global_position.x)
			var knockback = Vector2(direction * 300, -200)
			if player.has_method("apply_knockback"):
				player.apply_knockback(knockback)
			if current_phase == 2 and player.has_method("take_damage"):
				player.take_damage(5)
				print("[Boss] Shockwave damaged player!")

func _physics_process(delta: float) -> void:
	if not ml_system or not animated_sprite_2d:
		return

	if player and ml_system:
		behavior_check_timer += delta
		if behavior_check_timer >= BEHAVIOR_CHECK_INTERVAL:
			behavior_check_timer = 0.0
			var distance = global_position.distance_to(player.global_position)
			var moved_toward_boss = last_player_position.distance_to(global_position) > player.global_position.distance_to(global_position)
			var jumped = not player.is_on_floor()
			ml_system.record_player_behavior(distance, false, moved_toward_boss, jumped)
			last_player_position = player.global_position

	if not is_resting:
		var attack_threshold = PHASE2_ATTACK_DURATION if current_phase == 2 else PHASE1_ATTACK_DURATION
		var time_until_rest = attack_threshold - time_attacking
		if int(time_until_rest) % 10 == 0 and int(time_until_rest * 10) % 10 == 0:
			print("[Boss] Time until rest: %.1f seconds (Phase %d)" % [time_until_rest, current_phase])

	# Update cooldowns
	if jump_cooldown > 0:
		jump_cooldown -= delta
		if jump_cooldown <= 0:
			can_jump = true

	if attack_cooldown > 0:
		attack_cooldown -= delta

	if vertical_slash_cooldown > 0:
		vertical_slash_cooldown -= delta

	if down_slash_cooldown > 0:
		down_slash_cooldown -= delta

	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0:
			can_dash = true

	if dash_attack_cooldown > 0:
		dash_attack_cooldown -= delta

	if special_dash_cooldown > 0:
		special_dash_cooldown -= delta

	if direction_lock_timer > 0:
		direction_lock_timer -= delta

	# Handle dash timer
	if dashing:
		dash_time -= delta
		if dash_time <= 0:
			_end_dash()

	# Track attack time
	if current_state != State.IDLE and current_state != State.RESTING and current_state != State.DEAD:
		if not is_resting and is_player_detected:
			time_attacking += delta
			var attack_threshold = PHASE2_ATTACK_DURATION if current_phase == 2 else PHASE1_ATTACK_DURATION
			if time_attacking >= attack_threshold:
				_start_rest()

	# Handle rest timer
	if is_resting:
		rest_timer += delta
		if rest_timer >= REST_DURATION:
			_end_rest()

	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		if current_state == State.JUMPING:
			change_state(State.CHASE)

	# Get player reference
	if not player and Global.playerBody:
		player = Global.playerBody
	if player:
		_track_player_behavior(delta)

	# State machine
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK_READY:
			_state_attack_ready(delta)
		State.JUMPING:
			_state_jumping(delta)
		State.ATTACKING:
			_state_attacking(delta)
		State.HURT:
			_state_hurt(delta)
		State.RESTING:
			_state_resting(delta)
		State.DEAD:
			_state_dead(delta)

	# Move the boss
	move_and_slide()

	# Force velocity after move_and_slide to prevent web zeroing it
	if player and not is_resting:
		var direction_to_player = sign(player.global_position.x - global_position.x)
		if direction_to_player != 0:
			facing_direction = direction_to_player
		var distance_to_player = global_position.distance_to(player.global_position)

		match current_state:
			State.CHASE:
				if dashing:
					velocity.x = facing_direction * DASH_SPEED
				elif distance_to_player > CHASE_STOP_DISTANCE:
					velocity.x = facing_direction * CHASE_SPEED
			State.JUMPING:
				# Force horizontal air movement
				velocity.x = jump_air_velocity_x

	_check_damage_to_player()
	_update_sprite_direction()

func _state_idle(delta: float) -> void:
	animated_sprite_2d.play("idle")
	velocity.x = move_toward(velocity.x, 0, SPEED * delta * 5.0)
	if player and not player.dead:
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player <= DETECTION_RANGE:
			is_player_detected = true
			change_state(State.CHASE)

func _state_chase(delta: float) -> void:
	if not player or player.dead:
		change_state(State.IDLE)
		return

	if not dashing:
		animated_sprite_2d.play("run")

	var distance_to_player = global_position.distance_to(player.global_position)
	var direction_to_player = sign(player.global_position.x - global_position.x)
	var vertical_distance = player.global_position.y - global_position.y
	var ml_speed_mult = ml_system.get_speed_multiplier() if ml_system else 1.0
	var adjusted_chase_speed = CHASE_SPEED * ml_speed_mult

	if direction_to_player != 0:
		facing_direction = direction_to_player

	# Handle retreat
	if should_retreat or (ml_system and ml_system.should_retreat_more() and time_attacking > 30):
		retreat_timer -= delta
		if retreat_timer <= 0:
			should_retreat = false
		facing_direction = -direction_to_player
		if facing_direction == 0:
			facing_direction = 1
		velocity.x = lerp(velocity.x, facing_direction * adjusted_chase_speed, 0.3)
		if distance_to_player > RETREAT_DISTANCE:
			velocity.x = 0
			animated_sprite_2d.play("idle")
		return

	# PRIORITY 1: Attack if in close range
	if distance_to_player <= ATTACK_RANGE and attack_cooldown <= 0 and is_on_floor():
		change_state(State.ATTACK_READY)
		return

	# PRIORITY 2: Dash if available
	if can_dash and distance_to_player > DASH_TRIGGER_DISTANCE and is_on_floor() and not dashing:
		_start_dash()
		return

	# PRIORITY 3: Jump if player is above
	if vertical_distance < -80 and can_jump and is_on_floor():
		if abs(player.global_position.x - global_position.x) < 200:
			jump_air_velocity_x = facing_direction * CHASE_SPEED
			change_state(State.JUMPING)
			return

	# PRIORITY 4: Jump if player airborne nearby
	if not player.is_on_floor() and vertical_distance < -50:
		if can_jump and is_on_floor() and distance_to_player < 150:
			jump_air_velocity_x = facing_direction * CHASE_SPEED
			change_state(State.JUMPING)
			return

	# PRIORITY 5: Normal movement
	if not dashing:
		if distance_to_player > CHASE_STOP_DISTANCE:
			velocity.x = lerp(velocity.x, facing_direction * adjusted_chase_speed, 0.3)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED * delta * 5.0)

func _state_attack_ready(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, SPEED * delta * 10.0)

	if not player or player.dead or is_resting:
		change_state(State.IDLE)
		return

	var distance_to_player = global_position.distance_to(player.global_position)
	var vertical_distance = player.global_position.y - global_position.y

	var attack_threshold = PHASE2_ATTACK_DURATION if current_phase == 2 else PHASE1_ATTACK_DURATION
	var time_until_rest = attack_threshold - time_attacking
	if time_until_rest < 10.0 and not should_retreat:
		should_retreat = true
		retreat_timer = RETREAT_DURATION
		print("[Boss] Need to retreat soon for rest!")

	if should_retreat:
		change_state(State.CHASE)
		return

	if distance_to_player > ATTACK_RANGE + 80:
		change_state(State.CHASE)
		return

	facing_direction = sign(player.global_position.x - global_position.x)

	if attack_cooldown > 0:
		animated_sprite_2d.play("idle")
		return

	if current_phase == 2:
		if vertical_distance < -80 and can_jump:
			jump_air_velocity_x = facing_direction * CHASE_SPEED
			change_state(State.JUMPING)
			return
		if not player.is_on_floor() and can_jump and vertical_distance < -30:
			jump_air_velocity_x = facing_direction * CHASE_SPEED
			change_state(State.JUMPING)
			return
		if vertical_slash_cooldown <= 0 and down_slash_cooldown <= 0:
			if randi() % 2 == 0:
				_perform_vertical_slash()
			else:
				_perform_down_slash()
			return
		elif vertical_slash_cooldown <= 0:
			_perform_vertical_slash()
			return
		elif down_slash_cooldown <= 0:
			_perform_down_slash()
			return
		elif can_jump:
			jump_air_velocity_x = facing_direction * CHASE_SPEED
			change_state(State.JUMPING)
			return
	else:
		if vertical_distance < -80 and can_jump:
			jump_air_velocity_x = facing_direction * CHASE_SPEED
			change_state(State.JUMPING)
			return
		if not player.is_on_floor() and can_jump and vertical_distance < -30:
			jump_air_velocity_x = facing_direction * CHASE_SPEED
			change_state(State.JUMPING)
			return
		if vertical_slash_cooldown <= 0 and down_slash_cooldown <= 0:
			if randi() % 2 == 0:
				_perform_vertical_slash()
			else:
				_perform_down_slash()
			return
		elif vertical_slash_cooldown <= 0:
			_perform_vertical_slash()
			return
		elif down_slash_cooldown <= 0:
			_perform_down_slash()
			return
		elif can_jump:
			jump_air_velocity_x = facing_direction * CHASE_SPEED
			change_state(State.JUMPING)
			return

	if attack_cooldown <= 0:
		change_state(State.CHASE)

func _start_dash() -> void:
	if not player:
		return
	var dir = sign(player.global_position.x - global_position.x)
	if dir == 0:
		dir = 1
	facing_direction = dir
	dashing = true
	dash_time = DASH_DURATION
	can_dash = false
	dash_cooldown_timer = DASH_COOLDOWN
	animated_sprite_2d.play("dash")
	if current_phase == 2:
		_enable_damage_area(deal_damage_area_vertical_slash)
	print("[Boss] Dashing toward player! Direction: ", facing_direction)

func _end_dash() -> void:
	dashing = false
	_disable_all_damage_areas()
	print("[Boss] Dash ended")
	if player and not player.dead:
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player <= ATTACK_RANGE and attack_cooldown <= 0:
			change_state(State.ATTACK_READY)
			return
	if current_state == State.CHASE:
		animated_sprite_2d.play("run")

func _perform_vertical_slash() -> void:
	change_state(State.ATTACKING)
	print("[Boss] Vertical Slash!")
	vertical_slash_cooldown = get_vertical_slash_cooldown()
	attack_cooldown = get_attack_cooldown()
	await get_tree().create_timer(ATTACK_TELEGRAPH_TIME).timeout
	if not is_instance_valid(self): return
	animated_sprite_2d.play("vertical_slash")
	_enable_damage_area(deal_damage_area_vertical_slash)
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(self): return
	_disable_all_damage_areas()
	if current_state == State.ATTACKING:
		change_state(State.CHASE)

func _perform_down_slash() -> void:
	change_state(State.ATTACKING)
	print("[Boss] Down Slash!")
	down_slash_cooldown = get_down_slash_cooldown()
	attack_cooldown = get_attack_cooldown()
	await get_tree().create_timer(ATTACK_TELEGRAPH_TIME).timeout
	if not is_instance_valid(self): return
	animated_sprite_2d.play("down_slash")
	_enable_damage_area(deal_damage_area_down_slash)
	await get_tree().create_timer(0.7).timeout
	if not is_instance_valid(self): return
	_disable_all_damage_areas()
	if current_state == State.ATTACKING:
		change_state(State.CHASE)

func _perform_jump_up_attack() -> void:
	change_state(State.ATTACKING)
	print("[Boss] Jump Up Attack!")
	attack_cooldown = ATTACK_COOLDOWN_TIME
	await get_tree().create_timer(ATTACK_TELEGRAPH_TIME).timeout
	if not is_instance_valid(self): return
	animated_sprite_2d.play("jump_up_attack")
	_enable_damage_area(deal_damage_area_jump_up_attack)
	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(self): return
	_disable_all_damage_areas()
	if current_state == State.ATTACKING:
		change_state(State.JUMPING)

func _perform_idle_up_attack() -> void:
	change_state(State.ATTACKING)
	print("[Boss] Idle Up Attack!")
	attack_cooldown = ATTACK_COOLDOWN_TIME
	await get_tree().create_timer(ATTACK_TELEGRAPH_TIME).timeout
	if not is_instance_valid(self): return
	animated_sprite_2d.play("idle_up_attack")
	_enable_damage_area(deal_damage_area_jump_up_attack)
	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(self): return
	_disable_all_damage_areas()
	if current_state == State.ATTACKING:
		change_state(State.JUMPING)

func _perform_jump_down_attack() -> void:
	change_state(State.ATTACKING)
	print("[Boss] Jump Down Attack!")
	attack_cooldown = ATTACK_COOLDOWN_TIME
	await get_tree().create_timer(ATTACK_TELEGRAPH_TIME).timeout
	if not is_instance_valid(self): return
	animated_sprite_2d.play("jump_down_attack")
	_enable_damage_area(deal_damage_area_jump_down_attack)
	await get_tree().create_timer(0.7).timeout
	if not is_instance_valid(self): return
	_disable_all_damage_areas()
	if current_state == State.ATTACKING:
		change_state(State.JUMPING)

func _enable_damage_area(damage_area: Area2D) -> void:
	if damage_area:
		for child in damage_area.get_children():
			if child is CollisionShape2D:
				child.disabled = false

func _check_damage_to_player() -> void:
	if not is_attacking or not player:
		return
	if players_hit_this_attack.has(player):
		return
	var active_damage_areas = [
		deal_damage_area_vertical_slash,
		deal_damage_area_down_slash,
		deal_damage_area_jump_up_attack,
		deal_damage_area_jump_down_attack
	]
	for damage_area in active_damage_areas:
		if damage_area:
			var overlapping = damage_area.get_overlapping_areas()
			for area in overlapping:
				if area == Global.playerHitbox:
					var damage = _get_attack_damage()
					if player.has_method("take_damage"):
						player.take_damage(damage)
						players_hit_this_attack.append(player)
						print("[Boss] Hit player for %d damage!" % damage)
						if ml_system:
							var attack_name = animated_sprite_2d.animation
							ml_system.record_attack_result(attack_name, true)
						var direction = sign(player.global_position.x - global_position.x)
						var knockback = Vector2(direction * KNOCKBACK_FORCE, -100)
						if player.has_method("apply_knockback"):
							player.apply_knockback(knockback)
					return

func _get_attack_damage() -> int:
	var anim_name = animated_sprite_2d.animation
	match anim_name:
		"vertical_slash": return 5
		"down_slash": return 6
		"jump_up_attack": return 7
		"jump_down_attack": return 7
		"idle_up_attack": return 6
		"dash_attack": return 7
		"special_dash": return 8
		_: return 5

func _track_player_behavior(delta: float) -> void:
	if anticipate_jump_timer > 0:
		anticipate_jump_timer -= delta
	if jump_decision_cooldown > 0:
		jump_decision_cooldown -= delta
	var player_on_ground = player.is_on_floor()
	if player_last_on_ground and not player_on_ground:
		player_jump_count += 1
		anticipate_jump_timer = ANTICIPATE_WINDOW
	player_last_on_ground = player_on_ground
	if player_on_ground:
		jump_count_reset_timer += delta
		if jump_count_reset_timer >= 2.0:
			jump_count_reset_timer = 0.0
			if player_jump_count > 0:
				player_jump_count = max(0, player_jump_count - 1)
	else:
		jump_count_reset_timer = 0.0

func _should_jump_intelligently() -> bool:
	if not can_jump or not is_on_floor():
		return false
	if jump_decision_cooldown > 0:
		return false
	var vertical_distance = player.global_position.y - global_position.y
	var horizontal_distance = abs(player.global_position.x - global_position.x)
	if player_jump_count >= 3:
		return false
	if vertical_distance < -100 and horizontal_distance < 200:
		jump_decision_cooldown = JUMP_DECISION_COOLDOWN_TIME
		return true
	if anticipate_jump_timer > 0 and not player.is_on_floor() and horizontal_distance < 120:
		jump_decision_cooldown = JUMP_DECISION_COOLDOWN_TIME
		return true
	return false

func _check_platform_between_player() -> bool:
	if not player:
		return false
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.exclude = [self]
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	if result and result.collider != player:
		return true
	return false

func _state_jumping(delta: float) -> void:
	animated_sprite_2d.play("jump")

	if player and not player.dead and not is_attacking and attack_cooldown <= 0:
		var distance_to_player = global_position.distance_to(player.global_position)
		var vertical_distance = player.global_position.y - global_position.y

		# Player below us - jump down attack
		if vertical_distance > 50 and distance_to_player < ATTACK_RANGE * 1.3 and velocity.y > 0:
			jump_air_velocity_x = 0.0
			_perform_jump_down_attack()
			return

		# Player above us - jump up attack
		elif vertical_distance < -30 and distance_to_player < ATTACK_RANGE:
			var has_platform = false
			if not can_attack_through_platforms:
				has_platform = _check_platform_between_player()
			if not has_platform:
				jump_air_velocity_x = 0.0
				if velocity.y < 0:
					_perform_jump_up_attack()
					return
				else:
					_perform_idle_up_attack()
					return

		# Close enough for slash
		elif distance_to_player < ATTACK_RANGE:
			if vertical_slash_cooldown <= 0:
				jump_air_velocity_x = 0.0
				_perform_vertical_slash()
				return
			elif down_slash_cooldown <= 0:
				jump_air_velocity_x = 0.0
				_perform_down_slash()
				return

	# Land and return to chase
	if is_on_floor() and velocity.y >= 0:
		jump_air_velocity_x = 0.0
		change_state(State.CHASE)
		return

	# Update air velocity toward player
	if player and not player.dead:
		var direction_to_player = sign(player.global_position.x - global_position.x)
		if direction_to_player != 0:
			facing_direction = direction_to_player
		jump_air_velocity_x = lerp(jump_air_velocity_x, direction_to_player * CHASE_SPEED * 0.8, 0.25)

func _state_attacking(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, SPEED * delta * 10.0)

func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, SPEED * delta * 10.0)
	animated_sprite_2d.play("hurt")
	hurt_timer += delta
	if hurt_timer >= HURT_DURATION:
		hurt_timer = 0.0
		if current_state == State.HURT:
			change_state(State.CHASE)

func _state_resting(delta: float) -> void:
	velocity.x = 0
	velocity.y = 0
	animated_sprite_2d.play("idle")
	can_take_damage = true
	is_invulnerable = false
	var regen_rate = 15.0 if current_phase == 2 else 10.0
	health = min(health + int(regen_rate * delta), health_max)

func _state_dead(delta: float) -> void:
	velocity.x = 0
	velocity.y = 0
	if animated_sprite_2d.animation != "death":
		animated_sprite_2d.play("death")

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	_exit_state(current_state)
	previous_state = current_state
	current_state = new_state
	_enter_state(new_state)
	print("[Boss] State changed: %s -> %s" % [State.keys()[previous_state], State.keys()[current_state]])

func _enter_state(state: State) -> void:
	match state:
		State.JUMPING:
			var ml_jump_mult = ml_system.get_speed_multiplier() if ml_system else 1.0
			velocity.y = JUMP_VELOCITY * ml_jump_mult
			can_jump = false
			jump_cooldown = JUMP_COOLDOWN_TIME
		State.ATTACKING:
			is_attacking = true
			var ml_attack_mult = ml_system.get_attack_speed_multiplier() if ml_system else 1.0
			attack_cooldown = ATTACK_COOLDOWN_TIME / ml_attack_mult
			players_hit_this_attack.clear()
		State.HURT:
			hurt_timer = 0.0
		State.ATTACK_READY:
			pass

func _exit_state(state: State) -> void:
	match state:
		State.ATTACKING:
			is_attacking = false
			_disable_all_damage_areas()

func _update_sprite_direction() -> void:
	if facing_direction != 0:
		animated_sprite_2d.flip_h = facing_direction < 0
		deal_damage_area_vertical_slash.scale.x = facing_direction
		deal_damage_area_jump_up_attack.scale.x = facing_direction
		deal_damage_area_jump_down_attack.scale.x = facing_direction
		deal_damage_area_down_slash.scale.x = facing_direction

func _disable_all_damage_areas() -> void:
	if deal_damage_area_vertical_slash:
		for child in deal_damage_area_vertical_slash.get_children():
			if child is CollisionShape2D:
				child.disabled = true
	if deal_damage_area_jump_up_attack:
		for child in deal_damage_area_jump_up_attack.get_children():
			if child is CollisionShape2D:
				child.disabled = true
	if deal_damage_area_jump_down_attack:
		for child in deal_damage_area_jump_down_attack.get_children():
			if child is CollisionShape2D:
				child.disabled = true
	if deal_damage_area_down_slash:
		for child in deal_damage_area_down_slash.get_children():
			if child is CollisionShape2D:
				child.disabled = true

func take_damage(damage: int) -> void:
	if current_state == State.DEAD or not can_take_damage or is_invulnerable:
		return
	health -= damage
	print("[Boss] Took %d damage. Health: %d/%d" % [damage, health, health_max])
	var health_percentage = float(health) / float(health_max)
	if not phase_2_triggered and health_percentage <= phase_2_health_threshold:
		_trigger_phase_2()
		return
	if current_state != State.HURT and health > 0:
		can_take_damage = false
		change_state(State.HURT)
		await get_tree().create_timer(0.3).timeout
		if not is_instance_valid(self):
			return
		can_take_damage = true
		if current_state == State.HURT:
			change_state(State.CHASE)
	if health <= 0:
		die()

func _trigger_phase_2() -> void:
	phase_2_triggered = true
	current_phase = 2
	print("[Boss] ===== PHASE 2 ACTIVATED! =====")
	time_attacking = 0.0
	is_resting = false
	rest_timer = 0.0
	should_retreat = false
	retreat_timer = 0.0
	if animated_sprite_2d:
		var original_modulate = animated_sprite_2d.modulate
		animated_sprite_2d.modulate = Color(1.5, 0.5, 0.5)
		await get_tree().create_timer(0.3).timeout
		if not is_instance_valid(self): return
		animated_sprite_2d.modulate = original_modulate
	vertical_slash_cooldown = 0.0
	down_slash_cooldown = 0.0
	dash_attack_cooldown = 0.0
	special_dash_cooldown = 0.0
	attack_cooldown = 0.0

func get_vertical_slash_cooldown() -> float:
	return VERTICAL_SLASH_COOLDOWN_TIME * (0.5 if current_phase == 2 else 1.0)

func get_down_slash_cooldown() -> float:
	return DOWN_SLASH_COOLDOWN_TIME * (0.5 if current_phase == 2 else 1.0)

func get_dash_attack_cooldown() -> float:
	return DASH_ATTACK_COOLDOWN_TIME * (0.5 if current_phase == 2 else 1.0)

func get_special_dash_cooldown() -> float:
	return SPECIAL_DASH_COOLDOWN_TIME * (0.5 if current_phase == 2 else 1.0)

func get_attack_cooldown() -> float:
	return ATTACK_COOLDOWN_TIME * (0.5 if current_phase == 2 else 1.0)

func die() -> void:
	if ml_system:
		ml_system.record_boss_death()
	change_state(State.DEAD)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true
	await get_tree().create_timer(1.5).timeout
	queue_free()
