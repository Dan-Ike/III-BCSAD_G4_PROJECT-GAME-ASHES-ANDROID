extends Node2D
class_name RisingLava

@onready var tilemap: TileMap = $TileMap
@onready var killzone: Area2D = $Killzone
@onready var collision_shape: CollisionShape2D = $Killzone/CollisionShape2D

@export var rise_speed: float = 50.0
@export var start_delay: float = 1.0

var is_rising: bool = false
var has_started: bool = false

func _ready() -> void:
	if not killzone.is_connected("body_entered", _on_killzone_body_entered):
		killzone.connect("body_entered", _on_killzone_body_entered)

func _physics_process(delta: float) -> void:
	if is_rising:
		position.y -= rise_speed * delta

func start_rising() -> void:
	if has_started:
		return
	
	has_started = true
	await get_tree().create_timer(start_delay).timeout
	is_rising = true
	print("[RisingLava] Started rising!")

func stop_rising() -> void:
	is_rising = false

func _on_killzone_body_entered(body: Node) -> void:
	if body is Player:
		body.take_damage(Global.spikeDamageAmount)
		print("[RisingLava] Player touched lava!")
