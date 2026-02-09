extends CharacterBody2D
class_name  Flame_Wizard_Two
@export var player: CharacterBody2D
@export var SPEED: int = 50
@export var CHASE_SPEED: int = 150
@export var ACCELERATION: int = 300
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_cast: RayCast2D = $AnimatedSprite2D/RayCast2D
@onready var timer: Timer = $Timer
@onready var attack_area: Area2D = $AttackArea
@onready var deal_damage_area_attack: Area2D = $DealDamageArea_Attack
@onready var hitbox: Area2D = $Hitbox
@onready var health_bar: ProgressBar = $HealthBar

var last_position: Vector2 = Vector2.ZERO
var stuck_timer: float = 0.0
const STUCK_THRESHOLD: float = 2
const MIN_MOVEMENT: float = 0.2

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var direction: Vector2
var right_bounds: Vector2
var left_bounds: Vector2

@export var health: int = 100
@export var health_min: int = 0
@export var health_max: int = 100
@export var damage: int = 10

enum States{
	WANDER,
	CHASE,
	ATTACK_TELEGRAPH,
	ATTACKING,
	HURT,
	DEAD
}

var current_state = States.WANDER
var can_attack: bool = true
var attack_cooldown: float = 0.0
const ATTACK_COOLDOWN_TIME = 2.0
const ATTACK_TELEGRAPH_TIME = 0.4
#const ATTACK_LUNGE_TIME = 0.3
#const ATTACK_RECOVERY_TIME = 0.3
#const LUNGE_DISTANCE: float = 150.0
#var lunge_target: Vector2 = Vector2.ZERO
var players_hit_this_attack: Array = []
var can_take_damage: bool = true
#const LUNGE_SPEED: float = 300.0

func _ready():
	Global.playerBody = player if player else Global.playerBody
	left_bounds = self.global_position - Vector2(125, 0)
	right_bounds = self.global_position + Vector2(125, 0)
	
	if not player and Global.playerBody:
		player = Global.playerBody
	
	if attack_area:
		attack_area.collision_mask = 2
	
	if hitbox:
		if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox.area_entered.connect(_on_hitbox_area_entered)
	
	_disable_damage_area()
	
	if health_bar:
		health_bar.max_value = health_max
		health_bar.value = health

func _physics_process(delta: float) -> void:
	if current_state == States.DEAD:
		return
	
	if not player and Global.playerBody:
		player = Global.playerBody
	
	if health_bar:
		health_bar.value = health
	
	if attack_cooldown > 0:
		attack_cooldown -= delta
		if attack_cooldown <= 0:
			can_attack = true
	
	handle_gravity(delta)
	
	match current_state:
		States.WANDER:
			handle_movement(delta)
			change_direction()
			look_for_player()
			move_and_slide()
		States.CHASE:
			handle_movement(delta)
			change_direction()
			look_for_player()
			check_attack_range()
			move_and_slide()
		States.ATTACK_TELEGRAPH:
			velocity.x = 0
			move_and_slide()
		States.HURT:
			velocity.x = 0
			move_and_slide()
		States.DEAD:
			velocity.x = 0
			velocity.y = 0

func look_for_player():
	if not player:
		return
	
	if ray_cast.is_colliding():
		var collider = ray_cast.get_collider()
		if collider == player or collider == Global.playerBody:
			chase_player()
		elif current_state == States.CHASE:
			stop_chase()
	elif current_state == States.CHASE:
		stop_chase()

func check_attack_range():
	if not player or not can_attack:
		return
	
	var distance_to_player = abs(player.global_position.x - global_position.x)
	if distance_to_player <= 60.0 and is_on_floor():
		_prepare_attack()

func chase_player() -> void:
	if timer:
		timer.stop()
	if current_state == States.WANDER:
		current_state = States.CHASE

func stop_chase() -> void:
	if timer and timer.time_left <= 0:
		timer.start()

func handle_movement(delta: float) -> void:
	if current_state == States.WANDER:
		velocity = velocity.move_toward(direction * SPEED, ACCELERATION * delta)
		sprite.play("run")
	elif current_state == States.CHASE:
		velocity = velocity.move_toward(direction * CHASE_SPEED, ACCELERATION * delta)
		sprite.play("run")

func change_direction() -> void:
	if current_state == States.WANDER:
		if abs(global_position.x - last_position.x) < MIN_MOVEMENT:
			stuck_timer += get_physics_process_delta_time()
			if stuck_timer >= STUCK_THRESHOLD:
				sprite.flip_h = !sprite.flip_h
				ray_cast.target_position = Vector2(-125 if sprite.flip_h else 125, 0)
				stuck_timer = 0.0
		else:
			stuck_timer = 0.0
		
		last_position = global_position
		
		if sprite.flip_h:
			# Moving LEFT (inverted for Flame Wizard sprite)
			direction = Vector2(-1, 0)
			if global_position.x <= left_bounds.x:
				sprite.flip_h = false  # Face right
				ray_cast.target_position = Vector2(125, 0)
		else:
			# Moving RIGHT (inverted for Flame Wizard sprite)
			direction = Vector2(1, 0)
			if global_position.x >= right_bounds.x:
				sprite.flip_h = true  # Face left
				ray_cast.target_position = Vector2(-125, 0)
	elif current_state == States.CHASE:
		if not player:
			return
		
		direction = (player.global_position - global_position).normalized()
		
		if direction.x > 0.1:
			# Player is to the right
			sprite.flip_h = false  # Face right (inverted)
			ray_cast.target_position = Vector2(125, 0)
		elif direction.x < -0.1:
			# Player is to the left
			sprite.flip_h = true  # Face left (inverted)
			ray_cast.target_position = Vector2(-125, 0)

func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta  
	else:
		if velocity.y > 0:
			velocity.y = 0

func _prepare_attack() -> void:
	if not can_attack:
		return
	
	current_state = States.ATTACK_TELEGRAPH
	can_attack = false
	attack_cooldown = ATTACK_COOLDOWN_TIME
	players_hit_this_attack.clear()
	
	# Telegraph delay before attack
	await get_tree().create_timer(ATTACK_TELEGRAPH_TIME).timeout
	
	if not is_instance_valid(self) or current_state != States.ATTACK_TELEGRAPH:
		return
	
	# Start attacking
	current_state = States.ATTACKING
	sprite.play("attack")
	_enable_damage_area()
	
	# Check for damage during the attack (3 times over 0.6 seconds)
	var damage_checks = 3
	for i in range(damage_checks):
		if not is_instance_valid(self):
			return
		_check_damage_to_player()
		await get_tree().create_timer(0.2).timeout
	
	_disable_damage_area()
	
	if not is_instance_valid(self) or current_state != States.ATTACKING:
		return
	
	# Return to chase or wander
	if player and is_instance_valid(player):
		current_state = States.CHASE
	else:
		current_state = States.WANDER

func _enable_damage_area() -> void:
	if deal_damage_area_attack:
		deal_damage_area_attack.scale.x = -1 if sprite.flip_h else 1
		
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
					print("[Enemy] Dealt ", damage, " damage to player!")
					
					# Calculate direction FROM enemy TO player (pushes away)
					var knockback_direction = sign(player.global_position.x - global_position.x)
					var knockback = Vector2(knockback_direction * 250, -150)
					if body.has_method("apply_knockback"):
						body.apply_knockback(knockback)
				return

func take_damage(damage_amount: int) -> void:
	if current_state == States.DEAD or not can_take_damage:
		return
	
	health -= damage_amount
	
	if health <= 0:
		die()
	else:
		can_take_damage = false
		current_state = States.HURT
		sprite.play("hurt")
		
		await get_tree().create_timer(0.3).timeout
		
		if not is_instance_valid(self):
			return
		
		can_take_damage = true
		if player and is_instance_valid(player):
			current_state = States.CHASE
		else:
			current_state = States.WANDER

func die() -> void:
	if current_state == States.DEAD:
		return
	
	current_state = States.DEAD
	
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true
	
	if attack_area:
		attack_area.monitoring = false
	if hitbox:
		hitbox.monitoring = false
	if ray_cast:
		ray_cast.enabled = false
	
	velocity = Vector2.ZERO
	sprite.play("death")
	
	await sprite.animation_finished
	queue_free()

func _on_timer_timeout() -> void:
	current_state = States.WANDER

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area == Global.playerDamageZone:
		var damage_amount = Global.playerDamageAmount if "playerDamageAmount" in Global else 10
		take_damage(damage_amount)


func _on_attack_area_body_entered(body: Node2D) -> void:
	pass # Replace with function body.


func _on_attack_area_body_exited(body: Node2D) -> void:
	pass # Replace with function body.
