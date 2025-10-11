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

@onready var sfx_run: AudioStreamPlayer = $SFX_Run
@onready var sfx_dash: AudioStreamPlayer = $SFX_Dash
@onready var sfx_jump: AudioStreamPlayer = $SFX_Jump
@onready var sfx_fall: AudioStreamPlayer = $SFX_Fall
@onready var sfx_land: AudioStreamPlayer = $SFX_Land
@onready var sfx_atk_1: AudioStreamPlayer = $SFX_Atk1
@onready var sfx_atk_2: AudioStreamPlayer = $SFX_Atk2

# --- Soul Light Settings ---
@export var enable_soul_light_in_scene: bool = true
@export var soul_max: float = 100.0
@export var soul_value: float = 100.0

enum SoulLightMode { LEVEL1, LEVEL2, LEVEL3 }
@export var soul_mode: SoulLightMode = SoulLightMode.LEVEL1

# Soul Light Mode Configuration
const LEVEL1_DRAIN_RATE: float = 2.0
const LEVEL1_MIN_SOUL: float = 10.0
const LEVEL1_DAMAGE_PER_SEC: int = 0
const LEVEL1_RECOVER_RATE: float = 10.0

const LEVEL2_DRAIN_RATE: float = 3.0
const LEVEL2_MIN_SOUL: float = 0.0
const LEVEL2_DAMAGE_PER_SEC: int = 3
const LEVEL2_RECOVER_RATE: float = 8.0

const LEVEL3_DRAIN_RATE: float = 5.0
const LEVEL3_MIN_SOUL: float = 0.0
const LEVEL3_DAMAGE_PER_SEC: int = 5
const LEVEL3_RECOVER_RATE: float = 5.0

var soul_damage_timer: float = 0.0
var flicker_time: float = 0.0
@export var flicker_speed: float = 3.0
@export var flicker_strength: float = 0.1

# Movement
var SPEED: float = 200
const JUMP_VELOCITY := -400.0
var GRAVITY: float = 900

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
var air_dashes_left: int = 1

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

# Track if player is in torch light
var in_torch_light: bool = false

# Track previous air state to prevent sound spam
var was_in_air: bool = false

# Shine Ability
var shine_available: bool = false
var shine_active: bool = false
var shine_on_cooldown: bool = false
var shine_heal_timer: float = 0.0
const SHINE_COOLDOWN: float = 30.0
const SHINE_SOUL_BOOST: float = 500.0
const SHINE_HEAL_PER_SEC: int = 5
const SHINE_DURATION: float = 10.0  # Maximum duration if not interrupted
var shine_time_left: float = 0.0

# Knockback system
var is_being_knocked_back: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_duration: float = 0.3
var knockback_timer: float = 0.0
var knockback_friction: float = 0.9

func _ready() -> void:
	Global.playerBody = self
	Global.playerAlive = true
	#print("Player instance ID:", get_instance_id())
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
	#print("Initialized soul_mode:", get_soul_mode_name(soul_mode))
	if typeof(SaveManager) == TYPE_OBJECT:
		if SaveManager.has_ability("shine"):
			Global.touchshine = true 
	if Global.saved_soul_mode != -1:
		soul_mode = int(Global.saved_soul_mode)
		#print("Restored soul_mode from Global:", soul_mode)
	else:
		Global.saved_soul_mode = int(soul_mode)
		#print("Saved new soul_mode to Global:", soul_mode)
	
	_print_mode_info()

func apply_knockback(force: Vector2) -> void:
	"""Apply knockback force to the player"""
	if dead:
		return
	
	print("[Player] Knockback applied: ", force)
	is_being_knocked_back = true
	knockback_velocity = force
	knockback_timer = knockback_duration
	
	# Cancel current actions
	if dashing:
		_end_dash()
	if current_attack:
		cancel_attack()
	
	# Show hurt reaction
	if animated_sprite:
		animated_sprite.play("idle")  # Use idle since no hurt animation


func play_sfx_once(sfx: AudioStreamPlayer) -> void:
	#"""Play a one-shot sound effect (jump, land, attack, dash)"""
	sfx.stop()
	sfx.play()

func play_sfx_loop(sfx: AudioStreamPlayer) -> void:
	#"""Play a looping sound effect (run, fall)"""
	if not sfx.playing:
		sfx.play()

func stop_looping_sounds() -> void:
	#"""Stop all looping sounds (run, fall)"""
	sfx_run.stop()
	sfx_fall.stop()

func stop_all_sounds() -> void:
	#"""Stop all sound effects"""
	for s in [sfx_run, sfx_fall, sfx_jump, sfx_land, sfx_atk_1, sfx_atk_2, sfx_dash]:
		s.stop()

func _print_mode_info() -> void:
	print("=== Soul Light Mode: ", get_soul_mode_name(soul_mode), " ===")
	match soul_mode:
		SoulLightMode.LEVEL1:
			print("  Drain: ", LEVEL1_DRAIN_RATE, "/sec")
			print("  Min Soul: ", LEVEL1_MIN_SOUL)
			print("  HP Damage: ", LEVEL1_DAMAGE_PER_SEC, "/sec")
			print("  Recovery: ", LEVEL1_RECOVER_RATE, "/sec")
		SoulLightMode.LEVEL2:
			print("  Drain: ", LEVEL2_DRAIN_RATE, "/sec")
			print("  Min Soul: ", LEVEL2_MIN_SOUL)
			print("  HP Damage: ", LEVEL2_DAMAGE_PER_SEC, "/sec")
			print("  Recovery: ", LEVEL2_RECOVER_RATE, "/sec")
		SoulLightMode.LEVEL3:
			print("  Drain: ", LEVEL3_DRAIN_RATE, "/sec")
			print("  Min Soul: ", LEVEL3_MIN_SOUL)
			print("  HP Damage: ", LEVEL3_DAMAGE_PER_SEC, "/sec")
			print("  Recovery: ", LEVEL3_RECOVER_RATE, "/sec")

func get_soul_mode_name(mode: SoulLightMode) -> String:
	match mode:
		SoulLightMode.LEVEL1: return "LEVEL 1 (Easy)"
		SoulLightMode.LEVEL2: return "LEVEL 2 (Normal)"
		SoulLightMode.LEVEL3: return "LEVEL 3 (Hard)"
		_: return "UNKNOWN"

func get_current_drain_rate() -> float:
	match soul_mode:
		SoulLightMode.LEVEL1: return LEVEL1_DRAIN_RATE
		SoulLightMode.LEVEL2: return LEVEL2_DRAIN_RATE
		SoulLightMode.LEVEL3: return LEVEL3_DRAIN_RATE
		_: return 2.0

func get_min_soul_value() -> float:
	match soul_mode:
		SoulLightMode.LEVEL1: return LEVEL1_MIN_SOUL
		SoulLightMode.LEVEL2: return LEVEL2_MIN_SOUL
		SoulLightMode.LEVEL3: return LEVEL3_MIN_SOUL
		_: return 0.0

func get_damage_per_sec() -> int:
	match soul_mode:
		SoulLightMode.LEVEL1: return LEVEL1_DAMAGE_PER_SEC
		SoulLightMode.LEVEL2: return LEVEL2_DAMAGE_PER_SEC
		SoulLightMode.LEVEL3: return LEVEL3_DAMAGE_PER_SEC
		_: return 0

func get_recover_rate() -> float:
	match soul_mode:
		SoulLightMode.LEVEL1: return LEVEL1_RECOVER_RATE
		SoulLightMode.LEVEL2: return LEVEL2_RECOVER_RATE
		SoulLightMode.LEVEL3: return LEVEL3_RECOVER_RATE
		_: return 10.0

func restore_soul_light(amount: float) -> void:
	if dead:
		return
	var prev_value: float = soul_value
	soul_value = clamp(soul_value + amount, get_min_soul_value(), soul_max)
	soul_damage_timer = 0.0
	_update_soul_light_visual()
	if int(prev_value / 10) != int(soul_value / 10):
		print("[Player] Soul: %.1f -> %.1f" % [prev_value, soul_value])


func _process(delta: float) -> void:
	if dead:
		return
	if not in_torch_light:
		var drain_rate = get_current_drain_rate()
		var min_soul = get_min_soul_value()
		soul_value -= drain_rate * delta
		soul_value = clamp(soul_value, min_soul, soul_max)
	
	_update_shine_availability()
	
	# NEW: Handle active shine ability
	if shine_active:
		_handle_shine_active(delta)
	
	_update_soul_light_visual()
	var min_soul = get_min_soul_value()
	if soul_value <= min_soul:
		var damage_per_sec = get_damage_per_sec()
		if damage_per_sec > 0:
			_apply_soul_damage(delta, damage_per_sec)

func _update_soul_light_visual() -> void:
	if not soul_light:
		return
	
	# If shine is active, keep it bright (handled in _handle_shine_active)
	if shine_active:
		return
	
	# Normal soul light behavior
	var min_soul = get_min_soul_value()
	var effective_max = soul_max - min_soul
	var effective_value = soul_value - min_soul
	var normalized = clamp(effective_value / effective_max, 0.0, 1.0)
	flicker_time += get_process_delta_time() * flicker_speed
	var flicker = sin(flicker_time) * flicker_strength * (1.0 - normalized)
	var min_energy = 0.3 if soul_mode == SoulLightMode.LEVEL1 else 0.1
	var min_scale = 0.7 if soul_mode == SoulLightMode.LEVEL1 else 0.5
	soul_light.energy = lerp(min_energy, 1.4, normalized) + flicker
	soul_light.scale = Vector2.ONE * lerp(min_scale, 1.3, normalized)

func _apply_soul_damage(delta: float, dmg_per_sec: int) -> void:
	soul_damage_timer += delta
	if soul_damage_timer >= 1.0:
		#print("[Soul Damage] Taking ", dmg_per_sec, " HP damage (Soul depleted)")
		take_damage(dmg_per_sec)
		soul_damage_timer = 0.0

func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector2.ZERO
		return
	
	Global.playerDamageZone = deal_damage_zone
	Global.playerHitbox = player_hitbox
	
	var was_on_floor_before = is_on_floor()
	
	# Handle knockback (PRIORITY)
	if is_being_knocked_back:
		knockback_timer -= delta
		
		# Apply knockback velocity
		velocity.x = knockback_velocity.x
		
		# Apply gravity during knockback
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		
		# Reduce knockback over time
		knockback_velocity *= knockback_friction
		
		# End knockback
		if knockback_timer <= 0.0 or is_on_floor():
			is_being_knocked_back = false
			knockback_velocity = Vector2.ZERO
			knockback_timer = 0.0
	else:
		# Normal physics (only when not being knocked back)
		if not is_on_floor():
			if not dashing: 
				velocity.y += GRAVITY * delta
		else:
			if Global.can_double_jump:
				jumps_left = 2
			else:
				jumps_left = 1
			ground_dash_used = false
			air_dashes_left = 1
		
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
	
	move_and_slide()
	
	if not was_on_floor_before and is_on_floor():
		was_in_air = false
		stop_looping_sounds()
		await get_tree().process_frame
		sfx_land.stream_paused = false
		sfx_land.play()
	
	if was_on_floor_before and not is_on_floor():
		was_in_air = true

func _update_shine_availability() -> void:
	if shine_on_cooldown or shine_active:
		shine_available = false
		return
	
	# Shine is available as long as there's at least 1 soul light left
	if soul_value >= 1.0:
		shine_available = true
	else:
		shine_available = false

func handle_input(delta: float) -> void:
	if Input.is_action_just_pressed("shine") and Global.touchshine:
		if shine_available and not shine_active and not shine_on_cooldown:
			_activate_shine()
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
		was_in_air = true
		stop_all_sounds()
		await get_tree().process_frame
		sfx_jump.stream_paused = false
		sfx_jump.play()
		return
	if Input.is_action_just_pressed("jump") and jumps_left > 0 and not current_attack:
		print("[JUMP] Jump button pressed! Playing jump sound...")
		velocity.y = JUMP_VELOCITY
		jumps_left -= 1
		was_in_air = true
		stop_all_sounds()
		await get_tree().process_frame
		sfx_jump.stream_paused = false
		sfx_jump.play()
		#print("[JUMP] Jump sound playing:", sfx_jump.playing)
		#print("[JUMP] Jump sound stream:", sfx_jump.stream)
	if not current_attack and not dashing and Input.is_action_just_pressed("z"):
		start_attack()
	if not dashing and attack_push_time <= 0.0:
		if not is_on_floor() or not current_attack:
			var dirf := Input.get_axis("left", "right")
			if abs(dirf) > 0.01:
				facing_dir = sign(dirf)
				velocity.x = dirf * SPEED
				toggle_split_sprite(facing_dir)
			else:
				velocity.x = move_toward(velocity.x, 0.0, SPEED * delta * 5.0)
		elif is_on_floor() and current_attack:
			velocity.x = 0.0
	if not current_attack and not dashing:
		handle_movement_animation()

func start_dash() -> void:
	if dashing: return
	dashing = true
	dash_time = DASH_DURATION
	animated_sprite.play("dash")
	stop_looping_sounds()
	play_sfx_once(sfx_dash)
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
	sfx_atk_1.stop()
	sfx_atk_2.stop()
	animated_sprite.play("idle")

func _on_combo_timeout() -> void:
	attack_index = 0

func handle_movement_animation() -> void:
	if is_on_floor() and not current_attack:
		if abs(velocity.x) < 10.0:
			animated_sprite.play("idle")
			stop_looping_sounds()
		else:
			animated_sprite.play("run")
			sfx_fall.stop()
			play_sfx_loop(sfx_run)
	elif not is_on_floor() and not current_attack:
		animated_sprite.play("fall")
		sfx_run.stop()
		if velocity.y > 50:
			play_sfx_loop(sfx_fall)

func toggle_split_sprite(dir: int) -> void:
	animated_sprite.flip_h = dir == -1
	deal_damage_zone.scale.x = dir

func handle_attack_animation(a_type: String) -> void:
	stop_looping_sounds()
	var animation_name := "%s_atk" % a_type
	animated_sprite.play(animation_name)
	toggle_damage_collision(a_type)
	match a_type:
		"single", "air":
			play_sfx_once(sfx_atk_1)
		"double":
			play_sfx_once(sfx_atk_2)

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

# Replace your check_hitbox() function with this:

# Replace your check_hitbox() function with this (Godot 4 compatible):

func check_hitbox() -> void:
	var damage: int = 0
	if player_hitbox:
		var hitbox_areas := player_hitbox.get_overlapping_areas()
		if hitbox_areas.size() > 0:
			for hitbox in hitbox_areas:
				if hitbox:
					var parent = hitbox.get_parent()
					
					# Check if parent is BatEnemy (using is keyword if class exists)
					if parent is BatEnemy:
						damage = Global.batDamageAmount
						break
					
					# Check if parent is Golem
					elif parent is Golem:
						damage = Global.golemDamageAmount
						break
					
					# Check if it's an AdvancedEnemy (by checking properties - Godot 4 syntax)
					elif "damage_to_deal" in parent and "enemy_type" in parent:
						# This is likely an AdvancedEnemy
						damage = parent.damage_to_deal
						break
					
					# Fallback: check if parent has damage_to_deal property
					elif "damage_to_deal" in parent:
						damage = parent.damage_to_deal
						break
	
	if can_take_damage and damage != 0:
		take_damage(damage)

func _activate_shine() -> void:
	print("[Shine] Ability activated!")
	shine_active = true
	shine_available = false
	shine_time_left = SHINE_DURATION
	shine_heal_timer = 0.0
	
	# Boost soul light energy temporarily
	if soul_light:
		soul_light.energy = SHINE_SOUL_BOOST / 100.0  # Scale for visual effect
		soul_light.scale = Vector2.ONE * 2.0
	
	# Play activation sound (if you have one)
	# play_sfx_once(sfx_shine)

func _handle_shine_active(delta: float) -> void:
	shine_time_left -= delta
	shine_heal_timer += delta
	
	# Heal 5 HP per second
	if shine_heal_timer >= 1.0:
		if health < health_max:
			health += SHINE_HEAL_PER_SEC
			health = min(health, health_max)
			health_bar.value = health
			print("[Shine] Healed 5 HP. Current health: ", health)
		shine_heal_timer = 0.0
	
	# Keep soul light at max while shining
	soul_value = soul_max
	
	# Maintain bright visual effect
	if soul_light:
		soul_light.energy = SHINE_SOUL_BOOST / 100.0
		soul_light.scale = Vector2.ONE * 2.0
	
	# End shine if duration expires
	if shine_time_left <= 0.0:
		_end_shine(false)

func _start_shine_cooldown() -> void:
	shine_on_cooldown = true
	print("[Shine] Cooldown started (30 seconds)")
	await get_tree().create_timer(SHINE_COOLDOWN).timeout
	shine_on_cooldown = false
	print("[Shine] Cooldown finished! Ability ready.")

func _end_shine(interrupted: bool) -> void:
	if not shine_active:
		return
	
	shine_active = false
	shine_time_left = 0.0
	
	if interrupted:
		print("[Shine] Ability interrupted!")
	else:
		print("[Shine] Ability completed!")
	
	# Start cooldown
	_start_shine_cooldown()
	
	# Reset soul light visual to normal
	_update_soul_light_visual()

func take_damage(damage: int) -> void:
	if damage == 0 or dead:
		return
	
	if shine_active:
		_end_shine(true)
	
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
	attack_push_speed = 0.0
	velocity = Vector2.ZERO
	animated_sprite.stop()
	stop_all_sounds()
	if touch_controls:
		touch_controls.disable_all_controls()
	Input.action_release("left")
	Input.action_release("right")
	Input.action_release("jump")
	Input.action_release("z")
	Input.action_release("dash")
	handle_death_animation()

func handle_death_animation() -> void:
	$CollisionShape2D.position.y = 5
	animated_sprite.play("death")
	await get_tree().create_timer(0.5).timeout
	$Camera2D.zoom = Vector2(4, 4)
	await get_tree().create_timer(1.0).timeout
	Global.playerAlive = false
	var died_on_floor = Global.current_floor
	var died_on_level = Global.current_level
	print("[Player] Died on Floor %d, Level %d" % [died_on_floor, died_on_level])
	var game_over_scene = preload("res://scene/game_over.tscn")
	var game_over = game_over_scene.instantiate()
	get_tree().root.add_child(game_over)
	if game_over.has_method("show_game_over"):
		game_over.show_game_over(died_on_floor, died_on_level)

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
