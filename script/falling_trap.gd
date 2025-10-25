extends Node2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var hitboxfall: Area2D = $hitboxfall
@onready var collision_polygon_2d: CollisionPolygon2D = $hitboxfall/CollisionPolygon2D
@onready var hitboxextend: Area2D = $hitboxextend
@onready var collision_polygon_2d2: CollisionPolygon2D = $hitboxextend/CollisionPolygon2D
@onready var playerdeetct: Area2D = $playerdeetct
@onready var collision_shape_2d: CollisionShape2D = $playerdeetct/CollisionShape2D

enum TrapType {
	FALL_ONCE,
	RECOVER_FALL,
	AUTOMATIC_FALL_CYCLE,
	EXTEND_SPIKE,
	AUTOMATIC_EXTEND_CYCLE
}

@export var trap_type: TrapType = TrapType.FALL_ONCE
@export var speed = 160.0
@export var recover_time = 5.0
@export var cycle_fall_duration = 1.0
@export var cycle_delay = 2.0
@export var extend_duration = 2.0
@export var extend_hitbox_delay = 0.5
@export var fall_despawn_time = 2.0

var current_speed = 0.0
var initial_position: Vector2
var is_active = false
var is_recovering = false
var player_in_detect_area = false

func _ready() -> void:
	initial_position = position
	
	if trap_type in [TrapType.EXTEND_SPIKE, TrapType.AUTOMATIC_EXTEND_CYCLE]:
		sprite_2d.visible = false
		animated_sprite_2d.visible = true
		hitboxfall.monitoring = false
		hitboxextend.monitoring = false
	else:
		sprite_2d.visible = true
		animated_sprite_2d.visible = false
		hitboxfall.monitoring = true
		hitboxextend.monitoring = false
	
	if not hitboxfall.is_connected("area_entered", _on_hitboxfall_area_entered):
		hitboxfall.connect("area_entered", _on_hitboxfall_area_entered)
	if not hitboxextend.is_connected("area_entered", _on_hitboxextend_area_entered):
		hitboxextend.connect("area_entered", _on_hitboxextend_area_entered)
	
	if not playerdeetct.is_connected("area_entered", _on_playerdeetct_area_entered):
		playerdeetct.connect("area_entered", _on_playerdeetct_area_entered)
	if not playerdeetct.is_connected("area_exited", _on_playerdeetct_area_exited):
		playerdeetct.connect("area_exited", _on_playerdeetct_area_exited)
	
	if trap_type == TrapType.AUTOMATIC_FALL_CYCLE:
		playerdeetct.monitoring = false
		start_automatic_fall_cycle()
	elif trap_type == TrapType.AUTOMATIC_EXTEND_CYCLE:
		playerdeetct.monitoring = false
		start_automatic_extend_cycle()

func _physics_process(delta: float) -> void:
	if trap_type in [TrapType.FALL_ONCE, TrapType.RECOVER_FALL, TrapType.AUTOMATIC_FALL_CYCLE]:
		position.y += current_speed * delta

func _on_hitboxfall_area_entered(area: Area2D) -> void:
	if area.get_parent() is Player:
		area.get_parent().take_damage(Global.spikeDamageAmount)
		
		if trap_type == TrapType.FALL_ONCE:
			queue_free()

func _on_hitboxextend_area_entered(area: Area2D) -> void:
	if area.get_parent() is Player:
		area.get_parent().take_damage(Global.spikeDamageAmount)

func _on_playerdeetct_area_entered(area: Area2D) -> void:
	if area.get_parent() is Player:
		player_in_detect_area = true
		if not is_active and not is_recovering:
			match trap_type:
				TrapType.FALL_ONCE, TrapType.RECOVER_FALL:
					trigger_fall()
				TrapType.EXTEND_SPIKE:
					trigger_extend()

func _on_playerdeetct_area_exited(area: Area2D) -> void:
	if area.get_parent() is Player:
		player_in_detect_area = false

func trigger_fall() -> void:
	is_active = true
	current_speed = speed
	
	await get_tree().create_timer(fall_despawn_time).timeout
	
	match trap_type:
		TrapType.FALL_ONCE:
			queue_free()
		
		TrapType.RECOVER_FALL:
			recover_fall()
			
			await get_tree().create_timer(0.1).timeout
			if player_in_detect_area and not is_active and not is_recovering:
				trigger_fall()

func recover_fall() -> void:
	is_active = false
	is_recovering = true
	current_speed = 0.0
	
	var tween = create_tween()
	tween.tween_property(sprite_2d, "modulate:a", 0.3, 0.5)
	
	await get_tree().create_timer(0.5).timeout
	position = initial_position
	
	await get_tree().create_timer(recover_time - 0.5).timeout
	
	tween = create_tween()
	tween.tween_property(sprite_2d, "modulate:a", 1.0, 0.5)
	
	is_recovering = false

func trigger_extend() -> void:
	is_active = true
	
	animated_sprite_2d.play("shake")
	await animated_sprite_2d.animation_finished
	
	animated_sprite_2d.play("extend")
	
	await get_tree().create_timer(extend_hitbox_delay).timeout
	hitboxextend.monitoring = true
	
	await animated_sprite_2d.animation_finished
	
	await get_tree().create_timer(extend_duration).timeout
	
	hitboxextend.monitoring = false
	
	animated_sprite_2d.play("back")
	await animated_sprite_2d.animation_finished
	
	is_active = false
	
	if player_in_detect_area and not is_recovering:
		trigger_extend()

func start_automatic_fall_cycle() -> void:
	while true:
		await get_tree().create_timer(cycle_delay).timeout
		
		is_active = true
		current_speed = speed
		
		await get_tree().create_timer(fall_despawn_time).timeout
		
		current_speed = 0.0
		is_active = false
		
		var tween = create_tween()
		tween.tween_property(sprite_2d, "modulate:a", 0.3, 0.3)
		
		await get_tree().create_timer(0.3).timeout
		position = initial_position
		
		tween = create_tween()
		tween.tween_property(sprite_2d, "modulate:a", 1.0, 0.3)

func start_automatic_extend_cycle() -> void:
	while true:
		await get_tree().create_timer(cycle_delay).timeout
		
		animated_sprite_2d.play("shake")
		await animated_sprite_2d.animation_finished
		
		is_active = true
		animated_sprite_2d.play("extend")
		
		await get_tree().create_timer(extend_hitbox_delay).timeout
		hitboxextend.monitoring = true
		
		await animated_sprite_2d.animation_finished
		
		await get_tree().create_timer(cycle_fall_duration).timeout
		
		hitboxextend.monitoring = false
		
		animated_sprite_2d.play("back")
		await animated_sprite_2d.animation_finished
		
		is_active = false
