extends CharacterBody2D
class_name Warlock
# Enemy Type
enum EnemyType { PATROL, PERSISTENT }
@export var enemy_type: EnemyType = EnemyType.PATROL

# Edge Detection
var edge_check_distance: float = 30.0  # How far ahead to check for edges
# Add to variables section:
var edge_check_cooldown: float = 0.0
const EDGE_CHECK_INTERVAL: float = 0.1  # Check edges every 0.1 seconds
# Node references
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var patrol_area: Area2D = $PatrolArea
@onready var attack_area: Area2D = $AttackArea
@onready var deal_damage_area_upward_attack: Area2D = $DealDamageArea_UpwardAttack
@onready var deal_damage_area_downward_attack: Area2D = $DealDamageArea_DownwardAttack
@onready var hitbox: Area2D = $Hitbox
@onready var health_bar: ProgressBar = $HealthBar

# Stats
@export var health: int = 100
@export var health_min: int = 0
@export var health_max: int = 100
@export var damage: int = 10

# Movement
@export var patrol_speed: float = 50.0
@export var chase_speed: float = 120.0
const GRAVITY = 980.0

# Patrol
var patrol_direction: int = 1
var patrol_left_bound: float = 0.0
var patrol_right_bound: float = 0.0
@export var use_navigation_bounds: bool = true  # Auto-detect navigation bounds
@export var manual_patrol_distance: float = 500.0  # Used if not using navigation bounds
var patrol_timer: float = 0.0
const PATROL_WAIT_TIME = 1.0
var is_returning_to_patrol: bool = false
var return_position: Vector2

# States
enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK_READY,
	ATTACKING,
	HURT,
	DEAD
}

var current_state: State = State.PATROL
var previous_state: State = State.PATROL

# Combat
var player: CharacterBody2D = null
var is_player_in_detection: bool = false
var is_player_in_attack_range: bool = false
var facing_direction: int = 1
var can_attack: bool = true
var attack_cooldown: float = 0.0
const ATTACK_COOLDOWN_TIME = 1.5
const ATTACK_TELEGRAPH_TIME = 0.5  # Delay before attack
const ATTACK_RANGE = 60.0

# Damage tracking
var players_hit_this_attack: Array = []
var is_attacking: bool = false
var can_take_damage: bool = true

func _ready() -> void:
	# Set up patrol bounds
	if use_navigation_bounds:
		_setup_navigation_patrol_bounds()
	else:
		# Manual patrol distance from spawn point
		patrol_left_bound = global_position.x - manual_patrol_distance
		patrol_right_bound = global_position.x + manual_patrol_distance
	
	return_position = global_position
	
	# Start patrol randomly
	patrol_direction = 1 if randf() > 0.5 else -1
	change_state(State.PATROL)
	
	# IMPORTANT: Connect detection areas AFTER scene is ready
	await get_tree().process_frame
	
	if detection_area:
		# Set detection area to detect Layer 2 (where player is)
		detection_area.collision_mask = 2  # Layer 2 only
		
		# Make sure it's not already connected
		if not detection_area.body_entered.is_connected(_on_detection_area_entered):
			detection_area.body_entered.connect(_on_detection_area_entered)
		if not detection_area.body_exited.is_connected(_on_detection_area_exited):
			detection_area.body_exited.connect(_on_detection_area_exited)
		#print("[Enemy] Detection area connected - Mask set to Layer 2")
	else:
		pass
		#print("[Enemy] ERROR: No DetectionArea found!")
	
	if attack_area:
		attack_area.collision_mask = 2  # Also set attack area to Layer 2
		if not attack_area.body_entered.is_connected(_on_attack_area_entered):
			attack_area.body_entered.connect(_on_attack_area_entered)
		if not attack_area.body_exited.is_connected(_on_attack_area_exited):
			attack_area.body_exited.connect(_on_attack_area_exited)
	
	if hitbox:
		# Hitbox detects player's damage area
		if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox.area_entered.connect(_on_hitbox_area_entered)
	
	# Disable damage area initially
	_disable_damage_area()
	
	# Register with Global
	Global.slimeDamageZone = hitbox
	
	if health_bar:
		health_bar.max_value = health_max
		health_bar.value = health
	
	#print("[Enemy] Initialized as ", "PATROL" if enemy_type == EnemyType.PATROL else "PERSISTENT")
	#print("[Enemy] Patrol bounds: Left=", patrol_left_bound, " Right=", patrol_right_bound)
	#print("[Enemy] Starting direction: ", "RIGHT" if patrol_direction > 0 else "LEFT")

func _check_edge_ahead() -> bool:
	if not is_on_floor():
		return false
	
	# Raycast downward from ahead of the enemy
	var space_state = get_world_2d().direct_space_state
	var check_position = global_position + Vector2(patrol_direction * edge_check_distance, 0)
	var ray_end = check_position + Vector2(0, 50)  # Check 50 pixels down
	
	var query = PhysicsRayQueryParameters2D.create(check_position, ray_end)
	query.exclude = [self]
	query.collision_mask = 1  # Ground layer
	
	var result = space_state.intersect_ray(query)
	
	# If no ground found ahead, there's an edge
	return result.is_empty()

func _setup_navigation_patrol_bounds() -> void:
	# Find NavigationRegion2D in parent
	var nav_region = get_parent()
	
	while nav_region and not nav_region is NavigationRegion2D:
		nav_region = nav_region.get_parent()
	
	if nav_region and nav_region is NavigationRegion2D:
		# Get the navigation polygon bounds
		var nav_poly = nav_region.navigation_polygon
		if nav_poly:
			var bounds = nav_poly.get_bounds()
			
			# Convert to global coordinates
			patrol_left_bound = nav_region.global_position.x + bounds.position.x + 50  # Add padding
			patrol_right_bound = nav_region.global_position.x + bounds.end.x - 50  # Add padding
			
			#print("[Enemy] Found NavigationRegion2D bounds: ", bounds)
		else:
			#print("[Enemy] WARNING: NavigationRegion2D has no navigation_polygon!")
			_use_fallback_patrol()
	else:
		#print("[Enemy] WARNING: No NavigationRegion2D found! Using fallback patrol.")
		_use_fallback_patrol()

func _use_fallback_patrol() -> void:
	patrol_left_bound = global_position.x - manual_patrol_distance
	patrol_right_bound = global_position.x + manual_patrol_distance

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	
	# Update player reference
	if not player and Global.playerBody:
		player = Global.playerBody
	
	# Update health bar
	if health_bar:
		health_bar.value = health
	
	# Update cooldowns
	if attack_cooldown > 0:
		attack_cooldown -= delta
		if attack_cooldown <= 0:
			can_attack = true
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		if velocity.y > 0:
			velocity.y = 0
	
	# Handle returning to patrol (outside state machine)
	if is_returning_to_patrol and current_state != State.HURT and current_state != State.DEAD:
		_return_to_patrol()
		move_and_slide()
		_update_sprite_direction()
		return
	
	# State machine
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.PATROL:
			_state_patrol(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK_READY:
			_state_attack_ready(delta)
		State.ATTACKING:
			_state_attacking(delta)
		State.HURT:
			_state_hurt(delta)
		State.DEAD:
			_state_dead(delta)
	
	move_and_slide()
	_update_sprite_direction()

func _state_idle(delta: float) -> void:
	animated_sprite.play("idle")
	velocity.x = move_toward(velocity.x, 0, patrol_speed * delta * 5.0)
	
	patrol_timer -= delta
	if patrol_timer <= 0:
		change_state(State.PATROL)

func _state_patrol(delta: float) -> void:
	animated_sprite.play("run")
	
	# Check for edges ahead (with cooldown to reduce lag)
	edge_check_cooldown -= delta
	if edge_check_cooldown <= 0.0:
		edge_check_cooldown = EDGE_CHECK_INTERVAL
		
		if _check_edge_ahead():
			patrol_direction *= -1
			facing_direction = patrol_direction
			patrol_timer = PATROL_WAIT_TIME
			change_state(State.IDLE)
			return
	
	# Check if reached left boundary
	if patrol_direction < 0 and global_position.x <= patrol_left_bound:
		patrol_direction = 1
		facing_direction = 1
		patrol_timer = PATROL_WAIT_TIME
		change_state(State.IDLE)
		return
	
	# Check if reached right boundary
	if patrol_direction > 0 and global_position.x >= patrol_right_bound:
		patrol_direction = -1
		facing_direction = -1
		patrol_timer = PATROL_WAIT_TIME
		change_state(State.IDLE)
		return
	
	# Check for walls
	if is_on_wall():
		patrol_direction *= -1
		facing_direction = patrol_direction
		patrol_timer = PATROL_WAIT_TIME
		change_state(State.IDLE)
		return
	
	# Move in patrol direction
	velocity.x = patrol_direction * patrol_speed
	facing_direction = patrol_direction
	
	# If player detected, chase immediately
	if is_player_in_detection and player and not player.dead:
		change_state(State.CHASE)

func _state_chase(delta: float) -> void:
	# Check if player is valid
	if not player or not is_instance_valid(player) or player.dead:
		#print("[Enemy] Player invalid/dead, returning to patrol")
		return_position = global_position
		is_returning_to_patrol = true
		return
	
	# PATROL type: Return to patrol if player leaves detection
	if enemy_type == EnemyType.PATROL and not is_player_in_detection:
		#print("[Enemy] PATROL type and player left detection, returning")
		return_position = global_position
		is_returning_to_patrol = true
		return
	
	# PERSISTENT type: Always chase until player dies
	
	animated_sprite.play("run")
	
	var direction_to_player = sign(player.global_position.x - global_position.x)
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Check if in attack range
	if distance_to_player <= ATTACK_RANGE and can_attack:
		change_state(State.ATTACK_READY)
		return
	
	# Move toward player
	velocity.x = direction_to_player * chase_speed
	facing_direction = direction_to_player

func _state_attack_ready(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, chase_speed * delta * 10.0)
	
	if not player or player.dead:
		change_state(State.CHASE)
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Player escaped range
	if distance_to_player > ATTACK_RANGE: #+ 20:
		change_state(State.CHASE)
		return
	
	facing_direction = sign(player.global_position.x - global_position.x)
	
	# Attack cooldown check
	if attack_cooldown > 0:
		animated_sprite.play("idle")
		return
	
	# Perform attack
	_perform_attack()

func _state_attacking(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, chase_speed * delta * 10.0)

func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, chase_speed * delta * 10.0)
	animated_sprite.play("hurt")
	
	await get_tree().create_timer(0.3).timeout
	
	if not is_instance_valid(self):
		return
	
	if current_state == State.HURT:
		can_take_damage = true
		if player and not player.dead:
			change_state(State.CHASE)
		else:
			is_returning_to_patrol = true

func _state_dead(delta: float) -> void:
	velocity.x = 0
	velocity.y = 0
	if animated_sprite.animation != "death":
		animated_sprite.play("death")

func _perform_attack() -> void:
	change_state(State.ATTACKING)
	is_attacking = true
	can_attack = false
	attack_cooldown = ATTACK_COOLDOWN_TIME
	players_hit_this_attack.clear()
	
	#print("[Enemy] Attacking!")
	
	# Telegraph delay before animation and damage
	await get_tree().create_timer(ATTACK_TELEGRAPH_TIME).timeout
	
	if not is_instance_valid(self):
		return
	
	# Determine which attack to use based on player position
	var attack_type = "upward"
	if player:
		var vertical_diff = player.global_position.y - global_position.y
		if vertical_diff > 20:  # Player is below
			attack_type = "downward"
		else:  # Player is above or same level
			attack_type = "upward"
	
	# Play appropriate animation
	if attack_type == "upward":
		animated_sprite.play("upward_attack")
	else:
		animated_sprite.play("downward_attack")
	
	_enable_damage_area(attack_type)
	
	# Check for damage during the attack
	var damage_check_timer = 0.0
	var attack_duration = 0.6
	while damage_check_timer < attack_duration:
		if not is_instance_valid(self):
			return
		_check_damage_to_player(attack_type)
		await get_tree().process_frame
		damage_check_timer += get_physics_process_delta_time()
	
	_disable_damage_area(attack_type)
	is_attacking = false
	
	if current_state == State.ATTACKING:
		change_state(State.CHASE)

func _enable_damage_area(attack_type: String = "upward") -> void:
	var damage_area = deal_damage_area_upward_attack if attack_type == "upward" else deal_damage_area_downward_attack
	if damage_area:
		for child in damage_area.get_children():
			if child is CollisionShape2D:
				child.disabled = false

func _disable_damage_area(attack_type: String = "upward") -> void:
	var damage_area = deal_damage_area_upward_attack if attack_type == "upward" else deal_damage_area_downward_attack
	if damage_area:
		for child in damage_area.get_children():
			if child is CollisionShape2D:
				child.disabled = true

func _check_damage_to_player(attack_type: String = "upward") -> void:
	if not is_attacking or not player:
		return
	
	if players_hit_this_attack.has(player):
		return
	
	var damage_area = deal_damage_area_upward_attack if attack_type == "upward" else deal_damage_area_downward_attack
	if damage_area:
		var overlapping = damage_area.get_overlapping_bodies()
		for body in overlapping:
			if body == player or body == Global.playerBody:
				if player.has_method("take_damage"):
					player.take_damage(damage)
					players_hit_this_attack.append(player)
					#print("[Enemy] Hit player for %d damage!" % damage)
					
					# Apply knockback
					var direction = sign(player.global_position.x - global_position.x)
					var knockback = Vector2(direction * 200, -100)
					if player.has_method("apply_knockback"):
						player.apply_knockback(knockback)
				return

func _return_to_patrol() -> void:
	animated_sprite.play("run")
	
	# Calculate distance to return position
	var distance_to_return = global_position.distance_to(return_position)
	
	# If close enough to return position, resume patrol
	if distance_to_return < 50:
		is_returning_to_patrol = false
		patrol_direction = 1 if randf() > 0.5 else -1  # Random direction
		change_state(State.PATROL)
		#print("[Enemy] Reached return position, resuming patrol")
		return
	
	# Move toward return position
	var direction_to_return = sign(return_position.x - global_position.x)
	velocity.x = direction_to_return * patrol_speed
	facing_direction = direction_to_return

func _update_sprite_direction() -> void:
	if facing_direction != 0:
		animated_sprite.flip_h = facing_direction < 0
		if deal_damage_area_upward_attack:
			deal_damage_area_upward_attack.scale.x = facing_direction
		if deal_damage_area_downward_attack:
			deal_damage_area_downward_attack.scale.x = facing_direction

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	previous_state = current_state
	current_state = new_state
	
	# Only print important state changes
	if new_state == State.CHASE or new_state == State.ATTACKING or new_state == State.DEAD:
		#print("[Enemy] State: %s -> %s" % [State.keys()[previous_state], State.keys()[current_state]])
		pass

func take_damage(damage_amount: int) -> void:
	if current_state == State.DEAD or not can_take_damage:
		return
	
	health -= damage_amount
	#print("[Enemy] Took %d damage. Health: %d/%d" % [damage_amount, health, health_max])
	
	if health <= 0:
		die()
	else:
		can_take_damage = false
		change_state(State.HURT)

func die() -> void:
	if current_state == State.DEAD:
		return  # Prevent multiple death calls
	
	#print("[Enemy] Died!")
	change_state(State.DEAD)
	
	# Disable collision immediately
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true
	
	# Disable all areas
	if detection_area:
		detection_area.monitoring = false
	if attack_area:
		attack_area.monitoring = false
	if hitbox:
		hitbox.monitoring = false
	
	# Stop movement
	velocity = Vector2.ZERO
	
	# Play death animation
	if animated_sprite:
		animated_sprite.play("death")
		# Wait for animation to finish
		await animated_sprite.animation_finished
	else:
		# Fallback if no animation
		await get_tree().create_timer(1.0).timeout
	
	# Fade out (optional)
	#var tween = create_tween()
	#tween.tween_property(self, "modulate:a", 0.0, 0.5)
	#await tween.finished
	
	queue_free()

func _on_detection_area_entered(body: Node2D) -> void:
	# Check multiple ways to identify player
	var is_player = false
	
	if body is Player:
		is_player = true
	elif body == Global.playerBody:
		is_player = true
	elif body.is_in_group("player"):
		is_player = true
	
	if is_player:
		#print("[Enemy] ✓ Player detected! Starting chase!")
		is_player_in_detection = true
		player = body
		
		# Immediately chase if not dead or attacking
		if current_state != State.DEAD and current_state != State.ATTACKING:
			change_state(State.CHASE)

func _on_detection_area_exited(body: Node2D) -> void:
	if body == Global.playerBody:
		#print("[Enemy] Player left detection area!")
		is_player_in_detection = false
		
		# Only return to patrol if PATROL type
		if enemy_type == EnemyType.PATROL:
			if current_state == State.CHASE or current_state == State.ATTACK_READY:
				#print("[Enemy] PATROL type - returning to patrol")
				return_position = global_position
				is_returning_to_patrol = true
		else:
			#print("[Enemy] PERSISTENT type - continuing chase")
			pass

func _on_attack_area_entered(body: Node2D) -> void:
	if body == Global.playerBody:
		is_player_in_attack_range = true

func _on_attack_area_exited(body: Node2D) -> void:
	if body == Global.playerBody:
		is_player_in_attack_range = false

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area == Global.playerDamageZone:
		var damage_amount = Global.playerDamageAmount
		take_damage(damage_amount)
