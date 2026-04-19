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
@export_file("*.tscn") var cutscene_scene_path: String = ""
@export var cutscene_id: String = ""

@export_group("Shine Gate")
## If true, collectable is invisible and untouchable until player uses shine nearby
@export var requires_shine: bool = false
## Radius in pixels the player must be within when shine activates
@export var shine_reveal_radius: float = 300.0
## If true, also requires floor 2-3 to be cleared before shine can reveal this
@export var requires_floor_2_3_cleared: bool = false

@export_group("Visual")
@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer

@export_group("Debug")
@export var dev_reset_collectables: bool = false

var is_collected: bool = false
var player_in_range: bool = false
var is_revealed: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if dev_reset_collectables:
		_dev_reset_all_collectables()
	
	if collectable_id == "":
		collectable_id = generate_default_id()
	
	_check_collection_status()
	
	if not is_collected:
		if requires_shine:
			_set_hidden_state()
		else:
			_play_idle()
	
	print("[Collectable] Ready: %s (Type: %s, Requires Shine: %s, Requires 2-3 Cleared: %s)" % [
		collectable_id, collectable_type, requires_shine, requires_floor_2_3_cleared
	])

func _set_hidden_state() -> void:
	animated_sprite_2d.visible = false
	animated_sprite_2d_2.visible = false
	monitoring = false
	monitorable = false

func _play_idle() -> void:
	animated_sprite_2d.visible = true
	animated_sprite_2d_2.visible = false
	animated_sprite_2d.play("idle")

func _play_burst() -> void:
	animated_sprite_2d.visible = false
	animated_sprite_2d_2.visible = true
	animated_sprite_2d_2.play("burst")

func _process(_delta: float) -> void:
	if not requires_shine or is_revealed or is_collected:
		return
	
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	
	var player = players[0]
	
	if not player.shine_active:
		return
	
	# Check floor 2-3 cleared requirement first — if not met, do nothing
	if requires_floor_2_3_cleared and not SaveManager.is_level_completed(2, 3):
		return
	
	# Check distance
	var distance = global_position.distance_to(player.global_position)
	if distance <= shine_reveal_radius:
		_reveal()

func _reveal() -> void:
	is_revealed = true
	monitoring = true
	monitorable = true
	_play_idle()
	print("[Collectable] Revealed by shine: %s" % collectable_id)

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
	if requires_shine and not is_revealed:
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
	
	var level_node = get_tree().current_scene
	
	get_tree().paused = true
	var touch_controls = level_node.get_node_or_null("TouchControls")
	if touch_controls and touch_controls.has_method("disable_all_controls"):
		touch_controls.disable_all_controls()
	
	var cutscene_instance = cutscene_scene.instantiate()
	cutscene_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	level_node.add_child(cutscene_instance)
	
	if cutscene_instance.has_method("start_cutscene"):
		cutscene_instance.start_cutscene(cutscene_id)
	
	if cutscene_instance.has_signal("cutscene_finished"):
		await cutscene_instance.cutscene_finished
	
	get_tree().paused = false
	if touch_controls and touch_controls.has_method("enable_pause"):
		touch_controls.enable_pause()
		touch_controls.visible = true
	
	print("[Collectable] Cutscene finished for: %s" % collectable_id)
	_hide_collectable()

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

func _dev_reset_all_collectables() -> void:
	var abilities = SaveManager.get_data()["progress"].get("abilities", {})
	var core_keys = ["double_jump", "attack", "dash", "shine"]
	for key in abilities.keys():
		if key not in core_keys:
			abilities.erase(key)
	SaveManager.reset_cutscene_history()
	SaveManager.save()
	print("[DEV] All collectables and cutscene history reset locally. Supabase NOT updated.")
