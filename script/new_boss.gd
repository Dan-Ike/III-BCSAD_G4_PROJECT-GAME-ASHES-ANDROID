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

# Boss settings
@export var can_attack_through_platforms: bool = false  # Toggle for upward attacks through platforms

# Attack types
var vertical_slash_cooldown: float = 0.0
const VERTICAL_SLASH_COOLDOWN_TIME = 2.0
var down_slash_cooldown: float = 0.0
const DOWN_SLASH_COOLDOWN_TIME = 1.5

# Dash system
const DASH_SPEED = 400.0
const DASH_DURATION = 0.3
const DASH_COOLDOWN = 1.0
const DASH_TRIGGER_DISTANCE = 50.0  # Use dash if player is this far

var dashing: bool = false
var dash_time: float = 0.0
var dash_cooldown_timer: float = 0.0
var can_dash: bool = true

# Pathfinding
var last_player_x: float = 0.0
var direction_lock_timer: float = 0.0
const DIRECTION_LOCK_TIME = 0.3  # Lock direction for smooth movement

# AI Intelligence
var player_jump_count: int = 0  # Track how many times player jumped recently
var player_last_on_ground: bool = true
var anticipate_jump_timer: float = 0.0
const ANTICIPATE_WINDOW = 0.8  # Time to anticipate player jump
var jump_decision_cooldown: float = 0.0
const JUMP_DECISION_COOLDOWN_TIME = 1.5  # Don't spam jump decisions

# Damage tracking to prevent multi-hits
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
const ATTACK_RANGE = 100.0  # Half of attack area, boss stops here
const CHASE_STOP_DISTANCE = 60.0  # Minimum distance before stopping

# Boss properties
var player: CharacterBody2D = null
var facing_direction: int = 1
var is_player_detected: bool = false
var can_jump: bool = true
var jump_cooldown: float = 0.0
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
const DASH_ATTACK_DISTANCE = 80.0  # Match sprite movement
var is_dash_attacking: bool = false

# Phase system
var current_phase: int = 1
var phase_2_triggered: bool = false
var phase_2_health_threshold: float = 0.5  # 50% health

# Knockback and invulnerability
var is_invulnerable: bool = false
const KNOCKBACK_FORCE = 200.0

# Rest/Recovery system
var time_attacking: float = 0.0
var is_resting: bool = false
var rest_timer: float = 0.0
const PHASE1_ATTACK_DURATION = 60.0  # 1 minute
const PHASE2_ATTACK_DURATION = 120.0  # 2 minutes
const REST_DURATION = 5.0
var shockwave_triggered: bool = false

# Smart decision making
var should_retreat: bool = false
var retreat_timer: float = 0.0
const RETREAT_DURATION = 3.0
const RETREAT_DISTANCE = 250.0

# Attack telegraph delays
const ATTACK_TELEGRAPH_TIME = 0.2  # Delay before damage is dealt
var attack_telegraph_timer: float = 0.0
var is_telegraphing: bool = false

func _ready() -> void:
	change_state(State.IDLE)
	_disable_all_damage_areas()
	Global.bossDamageZone = hitbox2
	print("[Boss] Hitbox registered for player damage")
	
	add_to_group("boss")
	
	# Initialize ML system
	ml_system = load("res://ml_boss_data.gd").new()
	add_child(ml_system)
	ml_system.record_encounter()
	print("[Boss] ML System initialized!")

func _check_proactive_aerial_attack() -> bool:
	if not player or not can_jump or not is_on_floor():
		return false
	
	var vertical_distance = player.global_position.y - global_position.y
	var horizontal_distance = abs(player.global_position.x - global_position.x)
	
	# Player is significantly above us and within horizontal range
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
	should_retreat = false  # Stop retreating
	retreat_timer = 0.0
	change_state(State.RESTING)

func _end_rest() -> void:
	# Check if boss still exists before triggering shockwave
	if not is_instance_valid(self):
		return
	
	if not shockwave_triggered:
		_trigger_shockwave()
		
		# Wait for shockwave, but check if boss still exists
		await get_tree().create_timer(0.5).timeout
		if not is_instance_valid(self):
			return
	
	is_resting = false
	is_invulnerable = false  # ADDED: Make sure boss can take damage again
	can_take_damage = true   # ADDED: Double check this is enabled
	print("[Boss] Rest complete! Resuming battle!")
	change_state(State.CHASE)

func _perform_jump_over_player() -> void:
	# Intelligent jump to position above player for jump down attack
	if not player:
		return
	
	print("[Boss] Jumping over player for aerial attack!")
	change_state(State.JUMPING)
	velocity.y = JUMP_VELOCITY * 1.2  # Higher jump
	
	# Calculate direction to land past player
	var direction_to_player = sign(player.global_position.x - global_position.x)
	facing_direction = direction_to_player
	velocity.x = direction_to_player * CHASE_SPEED * 1.5


func _trigger_shockwave() -> void:
	# Check if boss still exists
	if not is_instance_valid(self):
		return
	
	shockwave_triggered = true
	print("[Boss] SHOCKWAVE!")
	
	# Visual effect
	if animated_sprite_2d and is_instance_valid(animated_sprite_2d):
		var original_modulate = animated_sprite_2d.modulate
		animated_sprite_2d.modulate = Color(2.0, 2.0, 2.0)
		
		await get_tree().create_timer(0.2).timeout
		
		# Check again after await
		if not is_instance_valid(self) or not is_instance_valid(animated_sprite_2d):
			return
		
		animated_sprite_2d.modulate = original_modulate
	
	# Knockback and damage player if close enough
	if player and is_instance_valid(player) and not player.dead:
		var distance = global_position.distance_to(player.global_position)
		if distance < 150:  # Shockwave range
			var direction = sign(player.global_position.x - global_position.x)
			var knockback = Vector2(direction * 300, -200)
			
			if player.has_method("apply_knockback"):
				player.apply_knockback(knockback)
			
			# Phase 2: Deal damage
			if current_phase == 2 and player.has_method("take_damage"):
				player.take_damage(5)
				print("[Boss] Shockwave damaged player!")

func _physics_process(delta: float) -> void:
	# ML: Track player behavior
	if player and ml_system:
		behavior_check_timer += delta
		if behavior_check_timer >= BEHAVIOR_CHECK_INTERVAL:
			behavior_check_timer = 0.0
			var distance = global_position.distance_to(player.global_position)
			var moved_toward_boss = last_player_position.distance_to(global_position) > player.global_position.distance_to(global_position)
			var jumped = not player.is_on_floor()
			ml_system.record_player_behavior(distance, false, moved_toward_boss, jumped)
			last_player_position = player.global_position
	
	# Debug rest system
	if not is_resting:
		var attack_threshold = PHASE2_ATTACK_DURATION if current_phase == 2 else PHASE1_ATTACK_DURATION
		var time_until_rest = attack_threshold - time_attacking
		if int(time_until_rest) % 10 == 0 and int(time_until_rest * 10) % 10 == 0:  # Print every 10 seconds
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
	
	if dashing:
		dash_time -= delta
		if dash_time <= 0:
			_end_dash()
	
	if direction_lock_timer > 0:
		direction_lock_timer -= delta
	
	# Track attack time for rest system - count ALL combat time (not just attacking)
	if current_state != State.IDLE and current_state != State.RESTING and current_state != State.DEAD:
		if not is_resting and is_player_detected:
			time_attacking += delta
			
			var attack_threshold = PHASE2_ATTACK_DURATION if current_phase == 2 else PHASE1_ATTACK_DURATION
			if time_attacking >= attack_threshold:
				_start_rest()
	
	# Handle rest state
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
	
	# Get player reference if not set
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
		State.RESTING:  # Add this
			_state_resting(delta)
		State.DEAD:
			_state_dead(delta)
	
	# Move the boss
	move_and_slide()
	
	# Check if boss is hitting player
	_check_damage_to_player()
	
	# Update sprite direction
	_update_sprite_direction()

func _state_idle(delta: float) -> void:
	animated_sprite_2d.play("idle")
	velocity.x = move_toward(velocity.x, 0, SPEED * delta * 5.0)
	
	# Check for player
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
	
	# ML: Adjust chase speed
	var ml_speed_mult = ml_system.get_speed_multiplier() if ml_system else 1.0
	var adjusted_chase_speed = CHASE_SPEED * ml_speed_mult
	
	# Handle retreat behavior (ML aware)
	if should_retreat or (ml_system and ml_system.should_retreat_more() and time_attacking > 30):
		retreat_timer -= delta
		if retreat_timer <= 0:
			should_retreat = false
		
		facing_direction = -direction_to_player
		velocity.x = lerp(velocity.x, facing_direction * adjusted_chase_speed, 0.3)
		
		if distance_to_player > RETREAT_DISTANCE:
			velocity.x = 0
			animated_sprite_2d.play("idle")
		return
	
	# PRIORITY 1: Attack if in close range and on ground
	if distance_to_player <= ATTACK_RANGE and not dashing and is_on_floor() and attack_cooldown <= 0:
		change_state(State.ATTACK_READY)
		return
	
	# PRIORITY 2: Use normal dash for movement if player is far
	if can_dash and distance_to_player > DASH_TRIGGER_DISTANCE and is_on_floor():
		_start_dash()
		return
	
	# PRIORITY 3: Jump if player is above
	if vertical_distance < -80:
		facing_direction = direction_to_player
		
		if can_jump and is_on_floor() and abs(player.global_position.x - global_position.x) < 200:
			change_state(State.JUMPING)
			return
	else:
		facing_direction = direction_to_player
	
	# PRIORITY 4: Jump if player is airborne nearby
	if not player.is_on_floor() and vertical_distance < -50:
		if can_jump and is_on_floor() and distance_to_player < 150:
			change_state(State.JUMPING)
			return
	
	# Move towards player
	if not dashing:
		if distance_to_player > CHASE_STOP_DISTANCE:
			velocity.x = lerp(velocity.x, facing_direction * adjusted_chase_speed, 0.3)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED * delta * 5.0)
	else:
		velocity.x = facing_direction * DASH_SPEED * ml_speed_mult

func _state_attack_ready(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, SPEED * delta * 10.0)
	
	if not player or player.dead or is_resting:
		change_state(State.IDLE)
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	var vertical_distance = player.global_position.y - global_position.y
	
	# Check if should retreat (rest phase coming)
	var attack_threshold = PHASE2_ATTACK_DURATION if current_phase == 2 else PHASE1_ATTACK_DURATION
	var time_until_rest = attack_threshold - time_attacking
	if time_until_rest < 10.0 and not should_retreat:
		should_retreat = true
		retreat_timer = RETREAT_DURATION
		print("[Boss] Need to retreat soon for rest!")
	
	# If retreating, back away
	if should_retreat:
		change_state(State.CHASE)
		return
	
	# Player escaped range (increased threshold to prevent flickering)
	if distance_to_player > ATTACK_RANGE + 80:
		change_state(State.CHASE)
		return
	
	facing_direction = sign(player.global_position.x - global_position.x)
	
	# Attack cooldown check
	if attack_cooldown > 0:
		animated_sprite_2d.play("idle")
		return
	
	# DECISION TREE: Choose best attack based on situation
	
	# Phase 2: Prioritize dash attacks
	if current_phase == 2:
		# Player above? Jump to them
		if vertical_distance < -80 and can_jump:
			change_state(State.JUMPING)
			return
		
		# Player airborne? Jump to intercept
		if not player.is_on_floor() and can_jump and vertical_distance < -30:
			change_state(State.JUMPING)
			return
		
		# Close range: Prioritize dash attacks, then slashes
		if dash_attack_cooldown <= 0 and distance_to_player >= 40:
			_perform_dash_attack()
			return
		elif special_dash_cooldown <= 0 and distance_to_player >= 40:
			_perform_special_dash()
			return
		elif vertical_slash_cooldown <= 0 and down_slash_cooldown <= 0:
			# Both available, alternate randomly
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
			change_state(State.JUMPING)
			return
	
	# Phase 1: Simpler attacks
	else:
		# Player above? Jump
		if vertical_distance < -80 and can_jump:
			change_state(State.JUMPING)
			return
		
		# Player airborne? Jump to meet them
		if not player.is_on_floor() and can_jump and vertical_distance < -30:
			change_state(State.JUMPING)
			return
		
		# Close range: Alternate slashes
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
			change_state(State.JUMPING)
			return
	
	# Nothing available? Chase to reposition
	if attack_cooldown <= 0:
		change_state(State.CHASE)

func _start_dash() -> void:
	dashing = true
	dash_time = DASH_DURATION
	can_dash = false
	dash_cooldown_timer = DASH_COOLDOWN
	animated_sprite_2d.play("dash")
	velocity.y = 0  # Cancel gravity during dash
	print("[Boss] Dashing toward player!")

func _end_dash() -> void:
	dashing = false
	print("[Boss] Dash ended")
	
	# After dash, check if we should attack
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
	
	# Delay before animation and damage
	await get_tree().create_timer(ATTACK_TELEGRAPH_TIME).timeout
	animated_sprite_2d.play("vertical_slash")
	_enable_damage_area(deal_damage_area_vertical_slash)
	
	await get_tree().create_timer(0.8).timeout
	_disable_all_damage_areas()
	
	if current_state == State.ATTACKING:
		change_state(State.CHASE)

func _perform_down_slash() -> void:
	change_state(State.ATTACKING)
	print("[Boss] Down Slash!")
	down_slash_cooldown = get_down_slash_cooldown()
	attack_cooldown = get_attack_cooldown()
	
	# Delay before animation and damage
	await get_tree().create_timer(ATTACK_TELEGRAPH_TIME).timeout
	animated_sprite_2d.play("down_slash")
	_enable_damage_area(deal_damage_area_down_slash)
	
	await get_tree().create_timer(0.7).timeout
	_disable_all_damage_areas()
	
	if current_state == State.ATTACKING:
		change_state(State.CHASE)

func _perform_dash_attack() -> void:
	change_state(State.ATTACKING)
	is_dash_attacking = true
	is_invulnerable = true
	can_take_damage = false
	animated_sprite_2d.play("dash_attack")
	dash_attack_cooldown = get_dash_attack_cooldown()
	attack_cooldown = get_attack_cooldown()
	print("[Boss] Dash Attack!")
	
	_enable_damage_area(deal_damage_area_vertical_slash)
	
	var dash_direction = facing_direction
	var dash_distance = 0.0
	var target_distance = 80.0  # Match sprite animation distance
	
	while dash_distance < target_distance:
		if not is_instance_valid(self):
			return
		velocity.x = dash_direction * DASH_ATTACK_SPEED
		move_and_slide()
		dash_distance += abs(velocity.x) * get_physics_process_delta_time()
		await get_tree().process_frame
	
	_disable_all_damage_areas()
	is_dash_attacking = false
	is_invulnerable = false
	can_take_damage = true
	
	if current_state == State.ATTACKING:
		change_state(State.CHASE)

func _perform_special_dash() -> void:
	change_state(State.ATTACKING)
	is_dash_attacking = true
	is_invulnerable = true
	can_take_damage = false
	animated_sprite_2d.play("special_dash")
	special_dash_cooldown = get_special_dash_cooldown()
	attack_cooldown = get_attack_cooldown()
	print("[Boss] Special Dash!")
	
	_enable_damage_area(deal_damage_area_vertical_slash)
	
	var dash_direction = facing_direction
	var dash_distance = 0.0
	var target_distance = 80.0  # Match sprite animation distance
	
	while dash_distance < target_distance:
		if not is_instance_valid(self):
			return
		velocity.x = dash_direction * SPECIAL_DASH_SPEED
		move_and_slide()
		dash_distance += abs(velocity.x) * get_physics_process_delta_time()
		await get_tree().process_frame
	
	_disable_all_damage_areas()
	is_dash_attacking = false
	is_invulnerable = false
	can_take_damage = true
	
	if current_state == State.ATTACKING:
		change_state(State.CHASE)

func _perform_jump_up_attack() -> void:
	change_state(State.ATTACKING)
	print("[Boss] Jump Up Attack!")
	attack_cooldown = ATTACK_COOLDOWN_TIME
	
	# Delay before animation and damage
	await get_tree().create_timer(ATTACK_TELEGRAPH_TIME).timeout
	animated_sprite_2d.play("jump_up_attack")
	_enable_damage_area(deal_damage_area_jump_up_attack)
	
	await get_tree().create_timer(0.6).timeout
	_disable_all_damage_areas()
	
	if current_state == State.ATTACKING:
		change_state(State.JUMPING)

func _perform_idle_up_attack() -> void:
	change_state(State.ATTACKING)
	print("[Boss] Idle Up Attack!")
	attack_cooldown = ATTACK_COOLDOWN_TIME
	
	# Delay before animation and damage
	await get_tree().create_timer(ATTACK_TELEGRAPH_TIME).timeout
	animated_sprite_2d.play("idle_up_attack")
	_enable_damage_area(deal_damage_area_jump_up_attack)
	
	await get_tree().create_timer(0.6).timeout
	_disable_all_damage_areas()
	
	if current_state == State.ATTACKING:
		change_state(State.JUMPING)

func _perform_jump_down_attack() -> void:
	change_state(State.ATTACKING)
	print("[Boss] Jump Down Attack!")
	attack_cooldown = ATTACK_COOLDOWN_TIME
	
	# Delay before animation and damage
	await get_tree().create_timer(ATTACK_TELEGRAPH_TIME).timeout
	animated_sprite_2d.play("jump_down_attack")
	_enable_damage_area(deal_damage_area_jump_down_attack)
	
	await get_tree().create_timer(0.7).timeout
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
						
						# ML: Record successful hit
						if ml_system:
							var attack_name = animated_sprite_2d.animation
							ml_system.record_attack_result(attack_name, true)
						
						# Apply knockback
						var direction = sign(player.global_position.x - global_position.x)
						var knockback = Vector2(direction * KNOCKBACK_FORCE, -100)
						if player.has_method("apply_knockback"):
							player.apply_knockback(knockback)
					return

func _get_attack_damage() -> int:
	var anim_name = animated_sprite_2d.animation
	match anim_name:
		"vertical_slash":
			return 5
		"down_slash":
			return 6
		"jump_up_attack":
			return 7
		"jump_down_attack":
			return 7
		"idle_up_attack":
			return 6
		"dash_attack":
			return 7
		"special_dash":
			return 8
		_:
			return 5

func _track_player_behavior(delta: float) -> void:
	if anticipate_jump_timer > 0:
		anticipate_jump_timer -= delta
	
	if jump_decision_cooldown > 0:
		jump_decision_cooldown -= delta
	
	# Detect when player jumps
	var player_on_ground = player.is_on_floor()
	if player_last_on_ground and not player_on_ground:
		player_jump_count += 1
		anticipate_jump_timer = ANTICIPATE_WINDOW
	
	player_last_on_ground = player_on_ground
	
	# Reset jump count periodically
	if player_on_ground:
		await get_tree().create_timer(2.0).timeout
		if player_jump_count > 0:
			player_jump_count = max(0, player_jump_count - 1)

func _should_jump_intelligently() -> bool:
	if not can_jump or not is_on_floor():
		return false
	
	if jump_decision_cooldown > 0:
		return false
	
	var vertical_distance = player.global_position.y - global_position.y
	var horizontal_distance = abs(player.global_position.x - global_position.x)
	
	# Don't jump if player is jumping frequently (they're trying to bait us)
	if player_jump_count >= 3:
		return false
	
	# Jump if player is high above and we can't reach them
	if vertical_distance < -100 and horizontal_distance < 200:
		jump_decision_cooldown = JUMP_DECISION_COOLDOWN_TIME
		return true
	
	# Jump if we anticipate player will jump-attack (they're in air moving toward us)
	if anticipate_jump_timer > 0 and not player.is_on_floor() and horizontal_distance < 120:
		jump_decision_cooldown = JUMP_DECISION_COOLDOWN_TIME
		return true
	
	return false

func _check_platform_between_player() -> bool:
	if not player:
		return false
	
	# Raycast from boss to player to detect platforms
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.exclude = [self]  # Don't hit ourselves
	query.collision_mask = 1  # Check collision layer 1 (platforms/walls)
	
	var result = space_state.intersect_ray(query)
	
	# If we hit something that's not the player, there's a platform between
	if result and result.collider != player:
		return true
	
	return false

func _state_jumping(delta: float) -> void:
	animated_sprite_2d.play("jump")
	
	# Always try to attack in air if player is close
	if player and not player.dead and not is_attacking and attack_cooldown <= 0:
		var distance_to_player = global_position.distance_to(player.global_position)
		var vertical_distance = player.global_position.y - global_position.y
		
		# Player below us? Jump down attack
		if vertical_distance > 50 and distance_to_player < ATTACK_RANGE * 1.3 and velocity.y > 0:
			_perform_jump_down_attack()
			return
		
		# Player above us? Jump up attack
		elif vertical_distance < -30 and distance_to_player < ATTACK_RANGE:
			var has_platform = false
			if not can_attack_through_platforms:
				has_platform = _check_platform_between_player()
			
			if not has_platform:
				if velocity.y < 0:
					_perform_jump_up_attack()
					return
				else:
					_perform_idle_up_attack()
					return
		
		# Close enough for slash?
		elif distance_to_player < ATTACK_RANGE:
			if vertical_slash_cooldown <= 0:
				_perform_vertical_slash()
				return
			elif down_slash_cooldown <= 0:
				_perform_down_slash()
				return
	
	# Land and return to chase
	if is_on_floor() and velocity.y >= 0:
		change_state(State.CHASE)
		return
	
	# Move toward player in air
	if player and not player.dead:
		var direction_to_player = sign(player.global_position.x - global_position.x)
		facing_direction = direction_to_player
		velocity.x = lerp(velocity.x, direction_to_player * CHASE_SPEED * 0.8, 0.25)

func _state_attacking(delta: float) -> void:
	# Keep velocity during dash attacks, stop for others
	if not is_dash_attacking:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 10.0)

func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, SPEED * delta * 10.0)
	animated_sprite_2d.play("hurt")
	await get_tree().process_frame
	
	if current_state == State.HURT:
		change_state(State.CHASE)

func _state_resting(delta: float) -> void:
	velocity.x = 0
	velocity.y = 0  # Stop all movement including gravity
	animated_sprite_2d.play("idle")
	can_take_damage = true  # CHANGED: Allow damage during rest
	is_invulnerable = false  # CHANGED: Not invulnerable during rest
	
	# Regenerate health
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
	
	# Exit current state
	_exit_state(current_state)
	
	previous_state = current_state
	current_state = new_state
	
	# Enter new state
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
		# Flip damage areas too
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

# Called when boss takes damage (from parent class or other system)
func take_damage(damage: int) -> void:
	if current_state == State.DEAD or not can_take_damage or is_invulnerable:
		return
	
	health -= damage
	print("[Boss] Took %d damage. Health: %d/%d" % [damage, health, health_max])
	
	# Check for Phase 2 transition - ONLY trigger once
	var health_percentage = float(health) / float(health_max)
	if not phase_2_triggered and health_percentage <= phase_2_health_threshold:
		_trigger_phase_2()
		return  # ADDED: Don't continue to hurt state during phase transition
	
	# Change to hurt state briefly
	if current_state != State.HURT and health > 0:
		can_take_damage = false
		change_state(State.HURT)
		await get_tree().create_timer(0.3).timeout
		
		# Check if boss still exists after await
		if not is_instance_valid(self):
			return
		
		can_take_damage = true
		if current_state == State.HURT:
			change_state(State.CHASE)
	
	# Check if dead
	if health <= 0:
		die()

func _trigger_phase_2() -> void:
	phase_2_triggered = true
	current_phase = 2
	print("[Boss] ===== PHASE 2 ACTIVATED! =====")
	
	# RESET ATTACK TIMER - Phase 2 starts fresh
	time_attacking = 0.0
	is_resting = false
	rest_timer = 0.0
	should_retreat = false
	retreat_timer = 0.0
	
	# Visual feedback - flash or animation
	if animated_sprite_2d:
		var original_modulate = animated_sprite_2d.modulate
		animated_sprite_2d.modulate = Color(1.5, 0.5, 0.5)  # Red flash
		await get_tree().create_timer(0.3).timeout
		animated_sprite_2d.modulate = original_modulate
	
	# Reset cooldowns to allow immediate use
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
	# ML: Record boss death
	if ml_system:
		ml_system.record_boss_death()
	
	change_state(State.DEAD)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true
	await get_tree().create_timer(1.5).timeout
	queue_free()
