extends Node2D
class_name Torch

@onready var sprite: Sprite2D = $Sprite2D
@onready var light: PointLight2D = $Light
@onready var ignite_detect: Area2D = $IgniteDetect
@onready var torchlight: Area2D = $TorchLight

enum TorchType { PERMANENT, RESETTABLE, TIMED }
@export var torch_type: TorchType = TorchType.PERMANENT

@export var greed_speed_boost: float = 25.0
@export var greed_gravity_increase: float = 15.0
@export var enable_greed_mechanic: bool = true

var greed_applied: bool = false

@export var light_energy: float = 1.8
@export var min_light_energy: float = 0.3
@export var light_color: Color = Color(1.0, 0.85, 0.4)
@export var unlit_color: Color = Color(0.25, 0.25, 0.25)
@export var fade_time: float = 0.4
@export var active_duration: float = 20.0
@export var flicker_strength: float = 0.08
@export var flicker_speed: float = 2.5
@export var soul_recovery_multiplier: float = 2.0  
@export var recovery_light_boost: float = 0.3  

var is_lit: bool = false
var has_been_used: bool = false 
var can_ignite: bool = true  
var remaining_time: float = 0.0
var flicker_timer: float = 0.0
var player_inside: bool = false
var player_in_ignite_area: bool = false  
var dim_strength: float = 1.0
var is_recovering_soul: bool = false  

func _ready() -> void:
	if light:
		light.visible = false
		light.energy = 0.0
		sprite.modulate = unlit_color
	if ignite_detect:
		ignite_detect.body_entered.connect(Callable(self, "_on_ignite_enter"))
		ignite_detect.body_exited.connect(Callable(self, "_on_ignite_exit"))  
	if torchlight:
		torchlight.body_entered.connect(Callable(self, "_on_torch_enter"))
		torchlight.body_exited.connect(Callable(self, "_on_torch_exit"))

func _process(delta: float) -> void:
	if not light:
		return
	if is_lit:
		flicker_timer += delta * flicker_speed
		var flicker: float = sin(flicker_timer) * flicker_strength
		var recovery_boost: float = recovery_light_boost if is_recovering_soul else 0.0
		var base_energy: float = lerp(min_light_energy, light_energy, dim_strength) + recovery_boost
		light.energy = clamp(base_energy + flicker, min_light_energy, light_energy * 1.2)
		if player_inside:
			_recover_soul(delta)
		else:
			is_recovering_soul = false
		match torch_type:
			TorchType.PERMANENT:
				pass
			TorchType.RESETTABLE:
				if not player_inside:
					remaining_time -= delta
					if remaining_time <= 0:
						extinguish()
					else:
						dim_strength = clamp(remaining_time / active_duration, 0.0, 1.0)
						_update_visual()
			TorchType.TIMED:
				remaining_time -= delta
				if remaining_time <= 0:
					extinguish()
				else:
					dim_strength = clamp(remaining_time / active_duration, 0.0, 1.0)
					_update_visual()

func ignite() -> void:
	is_lit = true
	remaining_time = active_duration
	dim_strength = 1.0
	light.visible = true
	sprite.modulate = light_color
	var tween = get_tree().create_tween()
	tween.tween_property(light, "energy", light_energy, fade_time)
	print("[Torch] Ignited - Type: %s" % _get_type_name())
	if torch_type == TorchType.PERMANENT and enable_greed_mechanic and not greed_applied:
		_apply_greed_effect()
		greed_applied = true

func extinguish() -> void:
	if not is_lit:
		return
	#print("[Torch] Extinguishing - Type: %s" % _get_type_name())
	is_lit = false
	remaining_time = 0.0
	dim_strength = 0.0
	is_recovering_soul = false
	if torch_type == TorchType.RESETTABLE or torch_type == TorchType.TIMED:
		has_been_used = true
		#print("[Torch] Marked as permanently used - cannot relight")
	var tween = get_tree().create_tween()
	tween.tween_property(light, "energy", 0.0, fade_time)
	tween.tween_callback(Callable(self, "_hide_light"))

func _hide_light() -> void:
	if light:
		light.visible = false
		sprite.modulate = unlit_color

func _update_visual() -> void:
	#"""Update light and sprite based on current dim strength"""
	if light:
		var target_energy = lerp(min_light_energy, light_energy, dim_strength)
		sprite.modulate = light_color.lerp(unlit_color, 1.0 - dim_strength)

func _recover_soul(delta: float) -> void:
	if not player_inside:
		is_recovering_soul = false
		return
	var player = null
	if Global.playerBody and is_instance_valid(Global.playerBody):
		player = Global.playerBody
	else:
		if torchlight:
			var bodies := torchlight.get_overlapping_bodies()
			for body in bodies:
				if body is Player:
					player = body
					break
	if player == null:
		is_recovering_soul = false
		return
	if player.has_method("restore_soul_light") and player.has_method("get_recover_rate"):
		var base_rate: float = player.get_recover_rate()
		var boosted_rate: float = base_rate * soul_recovery_multiplier
		var amount: float = boosted_rate * delta
		player.restore_soul_light(amount)
		is_recovering_soul = true

func _on_ignite_enter(body: Node) -> void:
	if not (body is Player):
		return
	if player_in_ignite_area:
		return
	player_in_ignite_area = true
	match torch_type:
		TorchType.PERMANENT:
			if not is_lit:
				#print("[Torch] PERMANENT: Lighting torch")
				ignite()
		TorchType.RESETTABLE:
			if not has_been_used and not is_lit:
				#print("[Torch] RESETTABLE: First time lighting (one-time use)")
				has_been_used = true 
				ignite()
			#elif has_been_used:
				#print("[Torch] RESETTABLE: Already used - cannot relight")
		TorchType.TIMED:
			if not has_been_used and not is_lit:
				#print("[Torch] TIMED: First time lighting (one-time use)")
				has_been_used = true  
				ignite()
			#elif has_been_used:
				#print("[Torch] TIMED: Already used - cannot relight")

func _on_ignite_exit(body: Node) -> void:
	"""NEW: Track when player leaves ignite area"""
	if not (body is Player):
		return
	player_in_ignite_area = false

func _on_torch_enter(body: Node) -> void:
	if not (body is Player):
		return
	player_inside = true
	if is_lit:
		body.in_torch_light = true
		#print("[Torch] Player entered lit torch - Soul recovery active (%.1fx rate)" % soul_recovery_multiplier)
		if torch_type == TorchType.RESETTABLE:
			remaining_time = active_duration
			dim_strength = 1.0
			#print("[Torch] RESETTABLE: Timer reset to %.1f seconds and PAUSED" % active_duration)
	else:
		body.in_torch_light = false
		#print("[Torch] Player entered unlit torch - no recovery")

func _on_torch_exit(body: Node) -> void:
	if not (body is Player):
		return
	player_inside = false
	is_recovering_soul = false
	body.in_torch_light = false
	#print("[Torch] Player exited torch area")

func _apply_greed_effect() -> void:
	"""Apply PERMANENT greed penalty: faster movement but heavier (lower jumps)"""
	if Global.playerBody and is_instance_valid(Global.playerBody):
		Global.playerBody.SPEED += greed_speed_boost
		Global.playerBody.GRAVITY += greed_gravity_increase
		#print("[Torch - GREED] PERMANENTLY Applied: +%.1f speed, +%.1f gravity" % [greed_speed_boost, greed_gravity_increase])
		#print("[Torch - GREED] New Stats - Speed: %.1f, Gravity: %.1f" % [Global.playerBody.SPEED, Global.playerBody.GRAVITY])

func _get_type_name() -> String:
	match torch_type:
		TorchType.PERMANENT: return "PERMANENT"
		TorchType.RESETTABLE: return "RESETTABLE"
		TorchType.TIMED: return "TIMED"
		_: return "UNKNOWN"
