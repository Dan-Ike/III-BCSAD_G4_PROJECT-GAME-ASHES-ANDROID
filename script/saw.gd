extends Node2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitboxfall: Area2D = $hitboxfall
@onready var collision_polygon_2d: CollisionPolygon2D = $hitboxfall/CollisionPolygon2D
@onready var playerdeetct: Area2D = $playerdeetct
@onready var collision_shape_2d: CollisionShape2D = $playerdeetct/CollisionShape2D

enum Direction { UP, DOWN, LEFT, RIGHT }
enum TrapType { MOVE_ONCE, MOVE_RETURN }

@export var direction: Direction = Direction.UP
@export var trap_type: TrapType = TrapType.MOVE_RETURN
@export var speed: float = 200.0
@export var max_distance: float = 200.0
@export var return_delay: float = 0.5

var initial_position: Vector2
var is_active: bool = false
var is_returning: bool = false
var current_distance: float = 0.0
var player_in_detect_area: bool = false

func _ready() -> void:
	initial_position = position
	
	# Play spinning animation constantly
	animated_sprite_2d.play("anim")
	
	# Connect hitbox for damage
	if not hitboxfall.is_connected("area_entered", _on_hitboxfall_area_entered):
		hitboxfall.connect("area_entered", _on_hitboxfall_area_entered)
	
	# Connect player detection
	if not playerdeetct.is_connected("area_entered", _on_playerdeetct_area_entered):
		playerdeetct.connect("area_entered", _on_playerdeetct_area_entered)
	if not playerdeetct.is_connected("area_exited", _on_playerdeetct_area_exited):
		playerdeetct.connect("area_exited", _on_playerdeetct_area_exited)
	
	hitboxfall.monitoring = true

func _physics_process(delta: float) -> void:
	if is_active:
		move_trap(delta)

func _on_hitboxfall_area_entered(area: Area2D) -> void:
	if area.get_parent() is Player:
		area.get_parent().take_damage(Global.spikeDamageAmount)

func _on_playerdeetct_area_entered(area: Area2D) -> void:
	if area.get_parent() is Player:
		player_in_detect_area = true
		if not is_active and not is_returning:
			trigger_movement()

func _on_playerdeetct_area_exited(area: Area2D) -> void:
	if area.get_parent() is Player:
		player_in_detect_area = false

func trigger_movement() -> void:
	is_active = true
	current_distance = 0.0

func move_trap(delta: float) -> void:
	var move_direction := Vector2.ZERO
	
	# Determine movement direction
	match direction:
		Direction.UP:
			move_direction = Vector2.UP if not is_returning else Vector2.DOWN
		Direction.DOWN:
			move_direction = Vector2.DOWN if not is_returning else Vector2.UP
		Direction.LEFT:
			move_direction = Vector2.LEFT if not is_returning else Vector2.RIGHT
		Direction.RIGHT:
			move_direction = Vector2.RIGHT if not is_returning else Vector2.LEFT
	
	# Move the trap
	var movement = move_direction * speed * delta
	position += movement
	current_distance += movement.length()
	
	# Check if reached max distance
	if current_distance >= max_distance:
		handle_max_distance_reached()

func handle_max_distance_reached() -> void:
	match trap_type:
		TrapType.MOVE_ONCE:
			# Stop and despawn
			is_active = false
			queue_free()
		
		TrapType.MOVE_RETURN:
			if not is_returning:
				# Start returning
				is_returning = true
				current_distance = 0.0
			else:
				# Finished returning
				return_to_initial_position()

func return_to_initial_position() -> void:
	is_active = false
	is_returning = false
	current_distance = 0.0
	position = initial_position
	
	# Check if player still in area to trigger again
	await get_tree().create_timer(return_delay).timeout
	if player_in_detect_area and not is_active:
		trigger_movement()
