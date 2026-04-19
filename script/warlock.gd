extends CharacterBody2D
class_name Warlock
# Enemy Type
enum EnemyType { PATROL, PERSISTENT }
@export var enemy_type: EnemyType = EnemyType.PATROL
@onready var ray_cast: RayCast2D = $AnimatedSprite2D/RayCast2D
# Navigation system (replaces edge checking)
var navigation_agent: NavigationAgent2D
var patrol_center: Vector2
var patrol_target: Vector2

# Simplified patrol system
var wander_direction: int = 1
var wander_time: float = 0.0
var wander_duration: float = 3.0
var wander_wait_time: float = 0.0
const WANDER_CHANGE_INTERVAL = 3.0  # Change direction every 3 seconds

# Jump system
var jump_velocity: float = -400.0
var can_jump: bool = true
var jump_cooldown: float = 0.5
var jump_check_distance: float = 50.0

# Smooth velocity
var target_velocity_x: float = 0.0
var velocity_smoothing: float = 10.0

# Performance optimization
var path_update_timer: float = 0.0
const PATH_UPDATE_INTERVAL: float = 0.25
var cached_next_position: Vector2 = Vector2.ZERO

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
const ATTACK_TELEGRAPH_TIME = 0.7  # Delay before attack
const ATTACK_RANGE = 100.0

# Damage tracking
var players_hit_this_attack: Array = []
var is_attacking: bool = false
var can_take_damage: bool = true

var player_distance_cache: float = 0.0
var distance_update_timer: float = 0.0
const DISTANCE_UPDATE_INTERVAL: float = 0.15

func _ready() -> void:
	_setup_navigation()
	
	return_position = global_position
	
	# Start with random direction
	wander_direction = 1 if randf() > 0.5 else -1
	wander_duration = randf_range(2.0, 4.0)
	
	change_state(State.PATROL)
	
	# IMPORTANT: Connect detection areas AFTER scene is ready
	await get_tree().process_frame
	
	
	if ray_cast:
		ray_cast.target_position = Vector2(125, 0)
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

# Setup navigation
func _setup_navigation() -> void:
	navigation_agent = NavigationAgent2D.new()
	add_child(navigation_agent)
	navigation_agent.path_desired_distance = 10.0
	navigation_agent.target_desired_distance = 20.0
	navigation_agent.max_speed = chase_speed
	navigation_agent.avoidance_enabled = false

func _generate_new_patrol_target() -> void:
	var rand_x = randf_range(patrol_left_bound, patrol_right_bound)
	patrol_target = Vector2(rand_x, global_position.y)

# Jump system
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
		if is_instance_valid(self):
			can_jump = true

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
	
	# Cache distance calculations
	distance_update_timer -= delta
	path_update_timer -= delta
	if distance_update_timer <= 0.0:
		distance_update_timer = DISTANCE_UPDATE_INTERVAL
		if player:
			player_distance_cache = global_position.distance_to(player.global_position)
	
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
		#_return_to_patrol()
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
	velocity.x = lerp(velocity.x, target_velocity_x, velocity_smoothing * delta)

	
	move_and_slide()
	_update_sprite_direction()

func _state_idle(delta: float) -> void:
	look_for_player()
	animated_sprite.play("idle")
	target_velocity_x = 0.0
	
	wander_wait_time -= delta
	if wander_wait_time <= 0:
		wander_direction = 1 if randf() > 0.5 else -1
		wander_duration = randf_range(2.0, 4.0)
		wander_time = 0.0
		change_state(State.PATROL)

func _state_patrol(delta: float) -> void:
	look_for_player()
	animated_sprite.play("run")
	
	if is_on_wall():
		wander_direction *= -1
		wander_time = 0.0
	
	target_velocity_x = wander_direction * patrol_speed
	facing_direction = wander_direction
	
	wander_time += delta
	if wander_time >= wander_duration:
		wander_wait_time = PATROL_WAIT_TIME
		change_state(State.IDLE)

func _state_chase(delta: float) -> void:
	look_for_player()
	
	if not player or not is_instance_valid(player) or player.dead:
		change_state(State.PATROL)
		return
	
	var horizontal_diff = player.global_position.x - global_position.x
	if abs(horizontal_diff) > 10.0:
		facing_direction = sign(horizontal_diff)
	
	# Use full distance so it triggers before touching player
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player <= ATTACK_RANGE and can_attack and is_on_floor():
		change_state(State.ATTACK_READY)
		return
	
	target_velocity_x = facing_direction * chase_speed
	animated_sprite.play("run")

func _state_attack_ready(delta: float) -> void:
	target_velocity_x = 0.0
	
	if not player or player.dead:
		change_state(State.PATROL)
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player > ATTACK_RANGE + 20:
		change_state(State.CHASE)
		return
	
	facing_direction = sign(player.global_position.x - global_position.x)
	
	if attack_cooldown > 0:
		animated_sprite.play("idle")
		return
	
	_perform_attack()

func _state_attacking(delta: float) -> void:
	target_velocity_x = 0.0

func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, chase_speed * delta * 10.0)
	animated_sprite.play("hurt")
	
	await get_tree().create_timer(0.3).timeout
	
	if not is_instance_valid(self):
		return
	
	if current_state == State.HURT:
		can_take_damage = true
		change_state(State.CHASE)

func _state_dead(delta: float) -> void:
	velocity.x = 0
	velocity.y = 0
	if animated_sprite.animation != "death":
		animated_sprite.play("death")

func _perform_attack() -> void:
	change_state(State.ATTACKING)
	is_attacking = true
	can_attack = false
	players_hit_this_attack.clear()
	
	# Determine attack type before telegraph
	var attack_type = "upward"
	if player:
		var vertical_diff = player.global_position.y - global_position.y
		attack_type = "downward" if vertical_diff > 20 else "upward"
	
	# Small windup
	await get_tree().create_timer(ATTACK_TELEGRAPH_TIME).timeout
	if not is_instance_valid(self):
		return
	
	# Play animation immediately
	if attack_type == "upward":
		animated_sprite.play("upward_attack")
	else:
		animated_sprite.play("downward_attack")
	
	# Enable hitbox right as animation starts
	_enable_damage_area(attack_type)
	
	# Deal damage mid-swing
	await get_tree().create_timer(0.15).timeout
	if not is_instance_valid(self):
		return
	
	_check_damage_to_player(attack_type)
	
	await get_tree().create_timer(0.1).timeout
	_disable_damage_area(attack_type)
	is_attacking = false
	can_attack = true
	
	if current_state == State.ATTACKING:
		change_state(State.CHASE)

func look_for_player() -> void:
	if not player:
		return
	
	if current_state == State.ATTACKING or current_state == State.ATTACK_READY or current_state == State.HURT:
		return
	
	if ray_cast.is_colliding():
		var collider = ray_cast.get_collider()
		if collider == player or collider == Global.playerBody:
			if current_state == State.PATROL or current_state == State.IDLE:
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

func _update_sprite_direction() -> void:
	if facing_direction != 0:
		animated_sprite.flip_h = facing_direction < 0
		if deal_damage_area_upward_attack:
			deal_damage_area_upward_attack.scale.x = facing_direction
		if deal_damage_area_downward_attack:
			deal_damage_area_downward_attack.scale.x = facing_direction
		if ray_cast:
			ray_cast.target_position = Vector2(125 if facing_direction > 0 else -125, 0)

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
