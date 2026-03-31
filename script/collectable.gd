extends Area2D
class_name Collectable
@onready var animated_sprite_2d_2: AnimatedSprite2D = $AnimatedSprite2D2
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

signal collected(collectable_id: String)

@export_group("Identification")
@export var collectable_id: String = ""
@export var collectable_type: String = "generic"

@export_group("Cutscene")
@export var trigger_cutscene: bool = false
@export var cutscene_scene_path: String = ""

@export_group("Visual")
@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer

var is_collected: bool = false
var player_in_range: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if collectable_id == "":
		collectable_id = generate_default_id()
	
	_check_collection_status()
	
	# Start with idle animation visible
	_play_idle()
	
	print("[Collectable] Ready: %s (Type: %s)" % [collectable_id, collectable_type])

func _play_idle() -> void:
	animated_sprite_2d.visible = true
	animated_sprite_2d_2.visible = false
	animated_sprite_2d.play("idle")

func _play_burst() -> void:
	animated_sprite_2d.visible = false
	animated_sprite_2d_2.visible = true
	animated_sprite_2d_2.play("burst")

func generate_default_id() -> String:
	var scene_name = get_tree().current_scene.name
	return "%s_%s_%.0f_%.0f" % [
		scene_name,
		collectable_type,
		global_position.x,
		global_position.y
	]

func _check_collection_status() -> void:
	if SaveManager.is_collectable_collected(collectable_id):
		is_collected = true
		_hide_collectable()
		print("[Collectable] Already collected: %s" % collectable_id)

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	if body is Player:
		player_in_range = true
		_collect()

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false

func _collect() -> void:
	if is_collected:
		return
	
	print("[Collectable] Collecting: %s" % collectable_id)
	is_collected = true
	
	SaveManager.collect_item(collectable_id, collectable_type)
	collected.emit(collectable_id)
	
	# Play burst animation, wait for it to finish
	_play_burst()
	await animated_sprite_2d_2.animation_finished
	
	if trigger_cutscene and cutscene_scene_path != "":
		_trigger_cutscene()
	else:
		_hide_collectable()

func _trigger_cutscene() -> void:
	var cutscene_scene = load(cutscene_scene_path)
	if not cutscene_scene:
		push_error("[Collectable] Failed to load cutscene: %s" % cutscene_scene_path)
		_hide_collectable()
		return
	
	_hide_collectable()
	
	var level_node = get_tree().current_scene
	var cutscene_instance = cutscene_scene.instantiate()
	level_node.add_child(cutscene_instance)
	
	if cutscene_instance.has_method("start_cutscene"):
		cutscene_instance.start_cutscene(collectable_id)
	
	if cutscene_instance.has_signal("cutscene_finished"):
		await cutscene_instance.cutscene_finished
	
	print("[Collectable] Cutscene finished for: %s" % collectable_id)

func _hide_collectable() -> void:
	animated_sprite_2d.visible = false
	animated_sprite_2d_2.visible = false
	
	monitoring = false
	monitorable = false
	
	await get_tree().create_timer(0.5).timeout
	queue_free()

func collect_manually() -> void:
	if not is_collected and player_in_range:
		_collect()
