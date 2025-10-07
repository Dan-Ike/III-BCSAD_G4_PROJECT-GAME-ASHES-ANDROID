
extends Node2D
class_name Torch

@onready var sprite: Sprite2D = $Sprite2D
@onready var light: PointLight2D = $Light
@onready var ignite_detect: Area2D = $IgniteDetect
@onready var torchlight: Area2D = $TorchLight

enum TorchType { PERMANENT, RESETTABLE, TIMED }
@export var torch_type: TorchType = TorchType.PERMANENT

@export var light_energy: float = 1.8
@export var min_light_energy: float = 0.3
@export var light_color: Color = Color(1.0, 0.85, 0.4)
@export var unlit_color: Color = Color(0.25, 0.25, 0.25)
@export var fade_time: float = 0.4
@export var active_duration: float = 20.0
@export var soul_recover_rate: float = 10.0 # +10 soul/sec near torch
@export var flicker_strength: float = 0.08
@export var flicker_speed: float = 2.5

var is_lit: bool = false
var remaining_time: float = 0.0
var flicker_timer: float = 0.0
var player_inside: bool = false

func _ready() -> void:
	if light:
		light.visible = false
		light.energy = 0.0
		sprite.modulate = unlit_color
	# connect signals with Callables
	if ignite_detect:
		ignite_detect.body_entered.connect(Callable(self, "_on_ignite_enter"))
	if torchlight:
		torchlight.body_entered.connect(Callable(self, "_on_torch_enter"))
		torchlight.body_exited.connect(Callable(self, "_on_torch_exit"))

func _process(delta: float) -> void:
	if not is_lit or not light:
		return

	# Flicker effect
	flicker_timer += delta * flicker_speed
	var flicker := sin(flicker_timer) * flicker_strength
	light.energy = clamp(light_energy + flicker, min_light_energy, light_energy * 1.15)

	match torch_type:
		TorchType.PERMANENT:
			if player_inside:
				_recover_soul(delta)

		TorchType.RESETTABLE:
			# Do not reset remaining_time each frame — only set it when the torch is ignited.
			if player_inside:
				_recover_soul(delta)
			# countdown regardless so it will extinguish after active_duration seconds
			remaining_time -= delta
			if remaining_time <= 0:
				extinguish()
			else:
				_dim_light(remaining_time / active_duration)

		TorchType.TIMED:
			# Timed counts down immediately after ignite; player can recover while inside.
			if player_inside:
				_recover_soul(delta)
			remaining_time -= delta
			if remaining_time <= 0:
				extinguish()
			else:
				_dim_light(remaining_time / active_duration)

func ignite() -> void:
	if is_lit:
		return
	is_lit = true
	remaining_time = active_duration
	light.visible = true
	sprite.modulate = light_color
	var tween = get_tree().create_tween()
	tween.tween_property(light, "energy", light_energy, fade_time)

func extinguish() -> void:
	if not is_lit:
		return
	is_lit = false
	remaining_time = 0.0
	var tween = get_tree().create_tween()
	tween.tween_property(light, "energy", 0.0, fade_time)
	tween.tween_callback(Callable(self, "_hide_light"))

func _hide_light() -> void:
	if light:
		light.visible = false
		sprite.modulate = unlit_color

func _dim_light(strength: float) -> void:
	if light:
		light.energy = lerp(min_light_energy, light_energy, strength)
		sprite.modulate = light_color.lerp(unlit_color, 1.0 - strength)

func _recover_soul(delta: float) -> void:
	if not is_lit:
		return
	# call the player's restore_soul_light method for each overlapping player body
	for body in torchlight.get_overlapping_bodies():
		if body is Player:
			# ensure the player has restore_soul_light defined (it should)
			body.restore_soul_light(soul_recover_rate * delta)

func _on_ignite_enter(body: Node) -> void:
	# player can ignite unlit torch by entering the ignite area
	if body is Player and not is_lit:
		ignite()

func _on_torch_enter(body: Node) -> void:
	if body is Player:
		player_inside = true

func _on_torch_exit(body: Node) -> void:
	if body is Player:
		player_inside = false
