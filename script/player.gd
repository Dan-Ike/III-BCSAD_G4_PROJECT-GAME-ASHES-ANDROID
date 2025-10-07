extends CharacterBody2D
class_name Player

# Nodes
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var deal_damage_zone: Area2D = $DealDamageZone
@onready var damage_shape: CollisionShape2D = $DealDamageZone/CollisionShape2D
@onready var player_hitbox: Area2D = $playerHitbox
@onready var touch_controls: CanvasLayer = $"../Control/TouchControls"
@onready var soul_light: PointLight2D = $SoulLight
@onready var health_bar: ProgressBar = $HealthBar

# --- Soul Light Settings ---
@export var enable_soul_light_in_scene: bool = true
@export var soul_max: float = 100.0
@export var soul_value: float = 100.0
@export var soul_drain_rate: float = 5.0  # per second
@export var lvl2_damage_per_sec: int = 2
@export var lvl3_damage_per_sec: int = 4

enum SoulLightMode { LEVEL1, LEVEL2, LEVEL3 }
@export var soul_mode: SoulLightMode = SoulLightMode.LEVEL3


var soul_damage_timer: float = 0.0
var flicker_time: float = 0.0
@export var flicker_speed: float = 3.0  # slower, calmer flicker
@export var flicker_strength: float = 0.1  # gentle variation

# Movement
const SPEED := 200.0
const JUMP_VELOCITY := -400.0
const GRAVITY := 900.0

# Attack push
const ATTACK_PUSH_SINGLE := 120.0
const ATTACK_PUSH_DOUBLE := 180.0
const ATTACK_PUSH_DURATION_SINGLE := 0.15
const ATTACK_PUSH_DURATION_DOUBLE := 0.25

var attack_push_time: float = 0.0
var attack_push_speed: float = 0.0

# Dash
const DASH_SPEED := 400.0
const DASH_DURATION := 0.2
const DASH_COOLDOWN := 1.0

var dashing: bool = false
var dash_time: float = 0.0
var dash_gravity_backup: float = 0.0
var dash_on_cooldown: bool = false
var ground_dash_used: bool = false
var air_dashes_left: int = 2

# Combat / combo
var attack_type: String = ""
var current_attack: bool = false
var attack_index: int = 0
var combo_timer: Timer

# State
var health: int = 100
var health_max = 100
var health_min = 0
var can_take_damage: bool = true
var dead: bool = false
var jumps_left: int = 1
var facing_dir: int = 1

func _ready() -> void:
	Global.playerBody = self
	Global.playerAlive = true
	print("Player instance ID:", get_instance_id())

	if enable_soul_light_in_scene:
		Global.enable_soul_light()
	else:
		Global.disable_soul_light()

	soul_light.visible = Global.soul_light_enabled

	combo_timer = Timer.new()
	combo_timer.one_shot = true
	combo_timer.wait_time = 0.6
	add_child(combo_timer)
	combo_timer.connect("timeout", Callable(self, "_on_combo_timeout"))

	if damage_shape:
		damage_shape.disabled = true

	print("Initialized soul_mode:", get_soul_mode_name(soul_mode))
	# Restore soul mode if one was saved globally
	if Global.saved_soul_mode != -1:
		soul_mode = int(Global.saved_soul_mode)
		print("Restored soul_mode from Global:", soul_mode)
	else:
		# Save current one if first time
		Global.saved_soul_mode = int(soul_mode)
		print("Saved new soul_mode to Global:", soul_mode)

func get_soul_mode_name(mode: SoulLightMode) -> String:
	match mode:
		SoulLightMode.LEVEL1: return "LEVEL 1"
		SoulLightMode.LEVEL2: return "LEVEL 2"
		SoulLightMode.LEVEL3: return "LEVEL 3"
		_: return "UNKNOWN"

func _process(delta: float) -> void:
	if dead:
		return

	# --- Drain soul ---
	soul_value -= soul_drain_rate * delta
	soul_value = clamp(soul_value, 0.0, soul_max)
	var normalized = soul_value / soul_max

	# --- Smooth Flicker ---
	flicker_time += delta * flicker_speed
	var flicker = sin(flicker_time) * flicker_strength * (1.0 - normalized)
	soul_light.energy = lerp(0.1, 1.4, normalized) + flicker
	soul_light.scale = Vector2.ONE * lerp(0.5, 1.3, normalized)

	# --- Soul depletion effects ---
	if soul_value <= 0:
		print("Soul is zero, current mode:", soul_mode)
		print("Zero soul check ID:", get_instance_id())
		match soul_mode:
			SoulLightMode.LEVEL1:
				pass
			SoulLightMode.LEVEL2:
				_apply_soul_damage(delta, lvl2_damage_per_sec)
			SoulLightMode.LEVEL3:
				_apply_soul_damage(delta, lvl3_damage_per_sec)


func _apply_soul_damage(delta: float, dmg_per_sec: int) -> void:
	soul_damage_timer += delta
	if soul_damage_timer >= 1.0:
		print("Applying soul damage: ", dmg_per_sec)
		take_damage(dmg_per_sec)
		soul_damage_timer = 0.0


func restore_soul_light(amount: float) -> void:
	soul_value = clamp(soul_value + amount, 0, soul_max)
	if soul_value > 0:
		can_take_damage = false

func _physics_process(delta: float) -> void:
	if dead:
		return

	Global.playerDamageZone = deal_damage_zone
	Global.playerHitbox = player_hitbox

	if not is_on_floor():
		if not dashing: 
			velocity.y += GRAVITY * delta
	else:
		if Global.can_double_jump:
			jumps_left = 2
		else:
			jumps_left = 1
		ground_dash_used = false
		air_dashes_left = 2

	if dashing:
		velocity.x = facing_dir * DASH_SPEED
		dash_time -= delta
		if dash_time <= 0.0:
			_end_dash()
	else:
		if attack_push_time > 0.0:
			velocity.x = attack_push_speed
			attack_push_time -= delta
			if attack_push_time <= 0.0:
				attack_push_speed = 0.0

	if not dead:
		handle_input(delta)
		check_hitbox()
	else:
		velocity = Vector2.ZERO
		return 

	move_and_slide()

func handle_input(delta: float) -> void:
	if Input.is_action_just_pressed("dash") and not dashing and not dash_on_cooldown:
		if is_on_floor() and not ground_dash_used:
			ground_dash_used = true
			start_dash()
			_start_dash_cooldown()
		elif not is_on_floor() and air_dashes_left > 0:
			air_dashes_left -= 1
			start_dash()

	if current_attack and Input.is_action_just_pressed("jump") and jumps_left > 0:
		cancel_attack()
		velocity.y = JUMP_VELOCITY
		jumps_left -= 1
		return

	if Input.is_action_just_pressed("jump") and jumps_left > 0 and not current_attack:
		velocity.y = JUMP_VELOCITY
		jumps_left -= 1

	if not current_attack and not dashing and Input.is_action_just_pressed("z"):
		start_attack()

	if not dashing and attack_push_time <= 0.0:
		var dirf := Input.get_axis("left", "right")
		if abs(dirf) > 0.01:
			facing_dir = sign(dirf)
			velocity.x = dirf * SPEED
			toggle_split_sprite(facing_dir)
		else:
			velocity.x = move_toward(velocity.x, 0.0, SPEED * delta * 5.0)
	elif is_on_floor() and not dashing and current_attack and attack_push_time <= 0.0:
		velocity.x = 0.0

	if not current_attack and not dashing:
		handle_movement_animation()

func start_dash() -> void:
	if dashing: return
	dashing = true
	dash_time = DASH_DURATION
	animated_sprite.play("dash")
	dash_gravity_backup = velocity.y
	velocity.y = 0

func _end_dash() -> void:
	dashing = false
	velocity.y = dash_gravity_backup
	handle_movement_animation()

func _start_dash_cooldown() -> void:
	dash_on_cooldown = true
	await get_tree().create_timer(DASH_COOLDOWN).timeout
	dash_on_cooldown = false

func start_attack() -> void:
	if dashing:
		_end_dash()
	current_attack = true
	if not is_on_floor():
		attack_type = "air"
	else:
		if attack_index == 0:
			attack_type = "single"
			attack_index = 1
			combo_timer.start()
		elif attack_index == 1:
			attack_type = "double"
			attack_index = 0
			combo_timer.stop()
		else:
			attack_type = "single"
			attack_index = 1
			combo_timer.start()
	set_damage(attack_type)
	handle_attack_animation(attack_type)
	if attack_type == "single":
		attack_push_speed = facing_dir * ATTACK_PUSH_SINGLE
		attack_push_time = ATTACK_PUSH_DURATION_SINGLE
	elif attack_type == "double":
		attack_push_speed = facing_dir * ATTACK_PUSH_DOUBLE
		attack_push_time = ATTACK_PUSH_DURATION_DOUBLE
	elif attack_type == "air":
		attack_push_speed = facing_dir * ATTACK_PUSH_SINGLE
		attack_push_time = ATTACK_PUSH_DURATION_SINGLE

func cancel_attack() -> void:
	current_attack = false
	attack_index = 0
	attack_push_time = 0.0
	attack_push_speed = 0.0
	if damage_shape:
		damage_shape.disabled = true
	animated_sprite.play("idle")

func _on_combo_timeout() -> void:
	attack_index = 0

func handle_movement_animation() -> void:
	if is_on_floor() and not current_attack:
		if abs(velocity.x) < 10.0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("run")
	elif not is_on_floor() and not current_attack:
		animated_sprite.play("fall")

func toggle_split_sprite(dir: int) -> void:
	animated_sprite.flip_h = dir == -1
	deal_damage_zone.scale.x = dir

func handle_attack_animation(a_type: String) -> void:
	var animation_name := "%s_atk" % a_type
	animated_sprite.play(animation_name)
	toggle_damage_collision(a_type)

func toggle_damage_collision(a_type: String) -> void:
	var wait_time := 0.5
	if a_type == "air":
		wait_time = 0.6
	elif a_type == "single":
		wait_time = 0.4
	elif a_type == "double":
		wait_time = 0.8
	if damage_shape:
		damage_shape.disabled = false
	await get_tree().create_timer(wait_time).timeout
	if damage_shape:
		damage_shape.disabled = true
	current_attack = false

func check_hitbox() -> void:
	var damage: int = 0
	if player_hitbox:
		var hitbox_areas := player_hitbox.get_overlapping_areas()
		if hitbox_areas.size() > 0:
			var hitbox = hitbox_areas.front()
			if hitbox:
				var parent = hitbox.get_parent()

				# Enemy checks
				if parent is BatEnemy:
					damage = Global.batDamageAmount
				elif parent is Golem:
					damage = Global.golemDamageAmount

				# Torch check
				elif parent is Torch:
					parent.ignite()

	if can_take_damage and damage != 0:
		take_damage(damage)

func take_damage(damage: int) -> void:
	if damage == 0 or dead:
		return
	if health > 0:
		health -= damage
		print("player health: ", health)
		health_bar.value = health
		if health <= 0:
			health = 0
			die()
		else:
			take_damage_cooldown(1.0)


func die() -> void:
	if dead:
		return 
	dead = true
	current_attack = false
	dashing = false
	attack_push_time = 0.0
	velocity = Vector2.ZERO
	animated_sprite.stop()

	if touch_controls:
		touch_controls.disable_all_controls()

	handle_death_animation()

func handle_death_animation() -> void:
	$CollisionShape2D.position.y = 5
	animated_sprite.play("death")
	await get_tree().create_timer(0.5).timeout
	$Camera2D.zoom = Vector2(4, 4)
	await get_tree().create_timer(1.0).timeout
	Global.playerAlive = false
	get_tree().reload_current_scene()

func take_damage_cooldown(wait_time: float) -> void:
	can_take_damage = false
	await get_tree().create_timer(wait_time).timeout
	can_take_damage = true

func set_damage(a_type: String) -> void:
	var dmg := 5
	if a_type == "single":
		dmg = 10
	elif a_type == "double":
		dmg = 15
	elif a_type == "air":
		dmg = 20
	Global.playerDamageAmount = dmg
