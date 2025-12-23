extends Area2D
class_name Collectable

signal collected(collectable_id: String)

## Export variables - set these in the editor for each collectable
@export_group("Identification")
@export var collectable_id: String = ""  # Unique ID like "floor1_level1_coin1"
@export var collectable_type: String = "generic"  # e.g., "coin", "artifact", "ability"

@export_group("Cutscene")
@export var trigger_cutscene: bool = false
@export var cutscene_scene_path: String = ""  # Path to cutscene scene

@export_group("Visual")
@export var sprite: Sprite2D  # Drag your sprite here in editor
@export var animation_player: AnimationPlayer  # Optional, for collect animation

## Internal state
var is_collected: bool = false
var player_in_range: bool = false

func _ready() -> void:
	# Set collision layers - detect player on layer 2
	collision_layer = 0  # Collectable doesn't have a layer
	collision_mask = 2    # Detects player on layer 2
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Generate ID if not set
	if collectable_id == "":
		collectable_id = generate_default_id()
	
	# Check if already collected
	_check_collection_status()
	
	print("[Collectable] Ready: %s (Type: %s)" % [collectable_id, collectable_type])

func generate_default_id() -> String:
	"""Generate a unique ID based on scene path and position"""
	var scene_name = get_tree().current_scene.name
	return "%s_%s_%.0f_%.0f" % [
		scene_name,
		collectable_type,
		global_position.x,
		global_position.y
	]

func _check_collection_status() -> void:
	"""Check if this collectable was already collected"""
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
	
	# Save to SaveManager
	SaveManager.collect_item(collectable_id, collectable_type)
	
	# Emit signal for other systems to use
	collected.emit(collectable_id)
	
	# Play collection animation if available
	if animation_player and animation_player.has_animation("collect"):
		animation_player.play("collect")
		await animation_player.animation_finished
	
	# Trigger cutscene if configured
	if trigger_cutscene and cutscene_scene_path != "":
		_trigger_cutscene()
	else:
		_hide_collectable()

func _trigger_cutscene() -> void:
	"""Load and play the cutscene"""
	var cutscene_scene = load(cutscene_scene_path)
	if not cutscene_scene:
		push_error("[Collectable] Failed to load cutscene: %s" % cutscene_scene_path)
		_hide_collectable()
		return
	
	# Hide collectable before cutscene
	_hide_collectable()
	
	# Get the level node (parent of player and collectable)
	var level_node = get_tree().current_scene
	
	# Instantiate cutscene
	var cutscene_instance = cutscene_scene.instantiate()
	level_node.add_child(cutscene_instance)
	
	# If cutscene has a start method, call it
	if cutscene_instance.has_method("start_cutscene"):
		cutscene_instance.start_cutscene(collectable_id)
	
	# Wait for cutscene to finish
	if cutscene_instance.has_signal("cutscene_finished"):
		await cutscene_instance.cutscene_finished
	
	print("[Collectable] Cutscene finished for: %s" % collectable_id)

func _hide_collectable() -> void:
	"""Hide the collectable after collection"""
	if sprite:
		sprite.visible = false
	
	# Disable collision
	monitoring = false
	monitorable = false
	
	# Optional: queue free after a delay
	await get_tree().create_timer(0.5).timeout
	queue_free()

## Optional: Manual collection trigger (for interactable collectables)
func collect_manually() -> void:
	if not is_collected and player_in_range:
		_collect()
