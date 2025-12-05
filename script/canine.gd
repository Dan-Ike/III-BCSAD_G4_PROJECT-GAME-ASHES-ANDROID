extends CharacterBody2D
class_name Canine
enum EnemyType { PATROL, PERSISTENT }
@export var enemy_type: EnemyType = EnemyType.PATROL

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var patrol_area: Area2D = $PatrolArea
@onready var attack_area: Area2D = $AttackArea
@onready var deal_damage_area_attack: Area2D = $DealDamageArea_Attack
@onready var hitbox: Area2D = $Hitbox
@onready var health_bar: ProgressBar = $HealthBar

@export var health: int = 100
@export var health_min: int = 0
@export var health_max: int = 100
@export var damage: int = 10

@export var patrol_speed: float = 50.0
@export var chase_speed: float = 120.0
const GRAVITY = 980.0

# Navigation system (like AdvancedEnemy)
var navigation_agent: NavigationAgent2D
var patrol_center: Vector2
var patrol_target: Vector2

var patrol_direction: int = 1
var patrol_left_bound: float = 0.0
var patrol_right_bound: float = 0.0
@export var use_navigation_bounds: bool = true
@export var manual_patrol_distance: float = 500.0
var patrol_timer: float = 0.0
const PATROL_WAIT_TIME = 1.0
var is_returning_to_patrol: bool = false
var return_position: Vector2

# Jump system (like AdvancedEnemy)
var jump_velocity: float = -400.0
var can_jump: bool = true
var jump_cooldown: float = 0.5
var jump_check_distance: float = 50.0

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

var player: CharacterBody2D = null
var is_player_in_detection: bool = false
var is_player_in_attack_range: bool = false
var facing_direction: int = 1
var can_attack: bool = true
var attack_cooldown: float = 0.0
const ATTACK_COOLDOWN_TIME = 1.5
const ATTACK_TELEGRAPH_TIME = 0.5
const ATTACK_DURATION_TIME = 0.5
const ATTACK_RANGE = 20.0

var players_hit_this_attack: Array = []
var is_attacking: bool = false
var can_take_damage: bool = true

var player_distance_cache: float = 0.0
var distance_update_timer: float = 0.0
const DISTANCE_UPDATE_INTERVAL: float = 0.15

# Smooth velocity
var target_velocity_x: float = 0.0
var velocity_smoothing: float = 10.0

# Performance optimization
var path_update_timer: float = 0.0
const PATH_UPDATE_INTERVAL: float = 0.25  # Update path 4 times per second instead of 60
var cached_next_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Setup navigation agent (like AdvancedEnemy)
	_setup_navigation()
	
	if use_navigation_bounds:
		_setup_navigation_patrol_bounds()
	else:
		patrol_left_bound = global_position.x - manual_patrol_distance
		patrol_right_bound = global_position.x + manual_patrol_distance
	
	patrol_center = global_position
	return_position = global_position
	patrol_direction = 1 if randf() > 0.5 else -1
	_generate_new_patrol_target()
	change_state(State.PATROL)
	
	await get_tree().process_frame
	
	if detection_area:
		detection_area.collision_mask = 2
		if not detection_area.body_entered.is_connected(_on_detection_area_entered):
			detection_area.body_entered.connect(_on_detection_area_entered)
		if not detection_area.body_exited.is_connected(_on_detection_area_exited):
			detection_area.body_exited.connect(_on_detection_area_exited)
	
	if attack_area:
		attack_area.collision_mask = 2
		if not attack_area.body_entered.is_connected(_on_attack_area_entered):
			attack_area.body_entered.connect(_on_attack_area_entered)
		if not attack_area.body_exited.is_connected(_on_attack_area_exited):
			attack_area.body_exited.connect(_on_attack_area_exited)
	
	if hitbox:
		if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox.area_entered.connect(_on_hitbox_area_entered)
	
	_disable_damage_area()
	
	if health_bar:
		health_bar.max_value = health_max
		health_bar.value = health

func _setup_navigation() -> void:
	navigation_agent = NavigationAgent2D.new()
	add_child(navigation_agent)
	navigation_agent.path_desired_distance = 10.0
	navigation_agent.target_desired_distance = 20.0
	navigation_agent.max_speed = chase_speed
	navigation_agent.avoidance_enabled = false

func _generate_new_patrol_target() -> void:
	# Generate random patrol point within bounds
	var rand_x = randf_range(patrol_left_bound, patrol_right_bound)
	patrol_target = Vector2(rand_x, global_position.y)

func _setup_navigation_patrol_bounds() -> void:
	var nav_region = get_parent()
	
	while nav_region and not nav_region is NavigationRegion2D:
		nav_region = nav_region.get_parent()
	
	if nav_region and nav_region is NavigationRegion2D:
		var nav_poly = nav_region.navigation_polygon
		if nav_poly:
			var bounds = nav_poly.get_bounds()
			patrol_left_bound = nav_region.global_position.x + bounds.position.x + 50
			patrol_right_bound = nav_region.global_position.x + bounds.end.x - 50
		else:
			_use_fallback_patrol()
	else:
		_use_fallback_patrol()

func _use_fallback_patrol() -> void:
	patrol_left_bound = global_position.x - manual_patrol_distance
	patrol_right_bound = global_position.x + manual_patrol_distance

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	
	if not player and Global.playerBody:
		player = Global.playerBody
	
	# Cache distance updates
	distance_update_timer -= delta
	if distance_update_timer <= 0.0:
		distance_update_timer = DISTANCE_UPDATE_INTERVAL
		if player and is_instance_valid(player):
			player_distance_cache = global_position.distance_to(player.global_position)
	
	# Cache path updates
	path_update_timer -= delta
	
	if health_bar:
		health_bar.value = health
	
	if attack_cooldown > 0:
		attack_cooldown -= delta
		if attack_cooldown <= 0:
			can_attack = true
	
	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		if velocity.y > 0:
			velocity.y = 0
	
	# Handle returning to patrol
	if is_returning_to_patrol and current_state != State.HURT and current_state != State.DEAD:
		_return_to_patrol(delta)
		velocity.x = lerp(velocity.x, target_velocity_x, velocity_smoothing * delta)
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
	
	# Smooth velocity application
	velocity.x = lerp(velocity.x, target_velocity_x, velocity_smoothing * delta)
	
	move_and_slide()
	_update_sprite_direction()

func _state_idle(delta: float) -> void:
	animated_sprite.play("idle")
	target_velocity_x = 0.0
	
	patrol_timer -= delta
	if patrol_timer <= 0:
		_generate_new_patrol_target()
		change_state(State.PATROL)

func _state_patrol(delta: float) -> void:
	animated_sprite.play("run")
	
	# Only update path periodically, not every frame
	if path_update_timer <= 0.0:
		path_update_timer = PATH_UPDATE_INTERVAL
		navigation_agent.target_position = patrol_target
		
		if not navigation_agent.is_navigation_finished():
			cached_next_position = navigation_agent.get_next_path_position()
	
	if not navigation_agent.is_navigation_finished():
		var direction = (cached_next_position - global_position).normalized()
		
		# Only check for jumps occasionally, not every frame
		if path_update_timer <= 0.0 and is_on_floor() and _should_jump_obstacle(direction):
			_perform_jump()
		
		target_velocity_x = direction.x * patrol_speed
		facing_direction = sign(direction.x) if abs(direction.x) > 0.1 else facing_direction
	else:
		# Reached patrol target, generate new one
		patrol_timer = PATROL_WAIT_TIME
		change_state(State.IDLE)
	
	# Switch to chase if player detected
	if is_player_in_detection and player and not player.dead:
		change_state(State.CHASE)

func _state_chase(delta: float) -> void:
	if not player or not is_instance_valid(player) or (player.has_method("is_dead") and player.is_dead()):
		return_position = global_position
		is_returning_to_patrol = true
		return
	
	if enemy_type == EnemyType.PATROL and not is_player_in_detection:
		return_position = global_position
		is_returning_to_patrol = true
		return
	
	animated_sprite.play("run")
	
	var distance_to_player = player_distance_cache
	
	if distance_to_player <= ATTACK_RANGE and can_attack:
		change_state(State.ATTACK_READY)
		return
	
	# Only update path periodically
	if path_update_timer <= 0.0:
		path_update_timer = PATH_UPDATE_INTERVAL
		navigation_agent.target_position = player.global_position
		
		if not navigation_agent.is_navigation_finished():
			cached_next_position = navigation_agent.get_next_path_position()
	
	if not navigation_agent.is_navigation_finished():
		var direction = (cached_next_position - global_position).normalized()
		
		# Only check jumps occasionally
		if path_update_timer <= 0.0 and is_on_floor() and _should_jump_obstacle(direction):
			_perform_jump()
		
		target_velocity_x = direction.x * chase_speed
		facing_direction = sign(direction.x) if abs(direction.x) > 0.1 else facing_direction
	else:
		# Direct movement if navigation finished
		var direction = (player.global_position - global_position).normalized()
		target_velocity_x = direction.x * chase_speed
		facing_direction = sign(direction.x) if abs(direction.x) > 0.1 else facing_direction

# Jump system from AdvancedEnemy (uses raycasting only when needed)
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

func _state_attack_ready(delta: float) -> void:
	target_velocity_x = 0.0
	
	if not player or not is_instance_valid(player) or (player.has_method("is_dead") and player.is_dead()):
		change_state(State.CHASE)
		return
	
	var distance_to_player = player_distance_cache
	
	if distance_to_player > ATTACK_RANGE + 10:
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
	target_velocity_x = 0.0
	animated_sprite.play("hurt")
	
	await get_tree().create_timer(0.3).timeout
	
	if not is_instance_valid(self):
		return
	
	if current_state == State.HURT:
		can_take_damage = true
		if player and is_instance_valid(player) and not (player.has_method("is_dead") and player.is_dead()):
			change_state(State.CHASE)
		else:
			is_returning_to_patrol = true

func _state_dead(delta: float) -> void:
	target_velocity_x = 0.0
	velocity.y = 0
	if animated_sprite.animation != "death":
		animated_sprite.play("death")

func _perform_attack() -> void:
	change_state(State.ATTACKING)
	is_attacking = true
	can_attack = false
	attack_cooldown = ATTACK_COOLDOWN_TIME
	players_hit_this_attack.clear()
	
	await get_tree().create_timer(ATTACK_TELEGRAPH_TIME).timeout
	
	if not is_instance_valid(self):
		return
	
	animated_sprite.play("attack")
	
	_enable_damage_area()
	
	await get_tree().create_timer(ATTACK_DURATION_TIME).timeout
	
	_check_damage_to_player()
	
	_disable_damage_area()
	is_attacking = false
	
	if current_state == State.ATTACKING:
		change_state(State.CHASE)

func _enable_damage_area() -> void:
	if deal_damage_area_attack:
		for child in deal_damage_area_attack.get_children():
			if child is CollisionShape2D:
				child.disabled = false

func _disable_damage_area() -> void:
	if deal_damage_area_attack:
		for child in deal_damage_area_attack.get_children():
			if child is CollisionShape2D:
				child.disabled = true

func _check_damage_to_player() -> void:
	if not player or not is_instance_valid(player):
		return
	
	if players_hit_this_attack.has(player):
		return
	
	if deal_damage_area_attack:
		var overlapping = deal_damage_area_attack.get_overlapping_bodies()
		for body in overlapping:
			if body == player or body == Global.playerBody:
				if body.has_method("take_damage"):
					body.take_damage(damage)
					players_hit_this_attack.append(player)
					
					var direction = sign(player.global_position.x - global_position.x)
					var knockback = Vector2(direction * 200, -100)
					if body.has_method("apply_knockback"):
						body.apply_knockback(knockback)
				return

func _return_to_patrol(delta: float) -> void:
	animated_sprite.play("run")
	
	# Only update path periodically
	if path_update_timer <= 0.0:
		path_update_timer = PATH_UPDATE_INTERVAL
		navigation_agent.target_position = return_position
		
		if not navigation_agent.is_navigation_finished():
			cached_next_position = navigation_agent.get_next_path_position()
	
	if not navigation_agent.is_navigation_finished():
		var direction = (cached_next_position - global_position).normalized()
		
		# Only check jumps occasionally
		if path_update_timer <= 0.0 and is_on_floor() and _should_jump_obstacle(direction):
			_perform_jump()
		
		target_velocity_x = direction.x * patrol_speed
		facing_direction = sign(direction.x) if abs(direction.x) > 0.1 else facing_direction
	else:
		# Reached return position
		is_returning_to_patrol = false
		patrol_direction = 1 if randf() > 0.5 else -1
		_generate_new_patrol_target()
		change_state(State.PATROL)

func _update_sprite_direction() -> void:
	if facing_direction != 0:
		animated_sprite.flip_h = facing_direction > 0
		if deal_damage_area_attack:
			deal_damage_area_attack.scale.x = -facing_direction

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	previous_state = current_state
	current_state = new_state

func take_damage(damage_amount: int) -> void:
	if current_state == State.DEAD or not can_take_damage:
		return
	
	health -= damage_amount
	
	if health <= 0:
		die()
	else:
		can_take_damage = false
		change_state(State.HURT)

func die() -> void:
	if current_state == State.DEAD:
		return
	
	change_state(State.DEAD)
	
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true
	
	if detection_area:
		detection_area.monitoring = false
	if attack_area:
		attack_area.monitoring = false
	if hitbox:
		hitbox.monitoring = false
	
	velocity = Vector2.ZERO
	set_process(false)
	set_physics_process(false)
	
	if animated_sprite:
		animated_sprite.play("death")
		await animated_sprite.animation_finished
	else:
		await get_tree().create_timer(1.0).timeout
	
	queue_free()

func _on_detection_area_entered(body: Node2D) -> void:
	var is_player = false
	
	if body.is_in_group("player") or body == Global.playerBody:
		is_player = true
	
	if is_player:
		is_player_in_detection = true
		player = body
		
		if current_state != State.DEAD and current_state != State.ATTACKING and current_state != State.HURT:
			change_state(State.CHASE)

func _on_detection_area_exited(body: Node2D) -> void:
	if body == Global.playerBody:
		is_player_in_detection = false
		
		if enemy_type == EnemyType.PATROL:
			if current_state == State.CHASE or current_state == State.ATTACK_READY or current_state == State.ATTACKING:
				return_position = global_position
				is_returning_to_patrol = true

func _on_attack_area_entered(body: Node2D) -> void:
	if body == Global.playerBody:
		is_player_in_attack_range = true

func _on_attack_area_exited(body: Node2D) -> void:
	if body == Global.playerBody:
		is_player_in_attack_range = false

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area == Global.playerDamageZone:
		var damage_amount = Global.playerDamageAmount if "playerDamageAmount" in Global else 10
		take_damage(damage_amount)
