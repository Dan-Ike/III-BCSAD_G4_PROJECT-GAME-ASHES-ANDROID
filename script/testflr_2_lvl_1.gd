extends Node2D

@onready var player: Player = $player
@onready var canvas_modulate: CanvasModulate = $CanvasModulate

# How dark the world gets when soul light is empty
@export var min_brightness: float = 0.2  # 0.0 = total black, 0.2 = 80% black
# Brightness when soul is full
@export var max_brightness: float = 1.0

# Optional color tint for the darkness
@export var tint_color: Color = Color(1.0, 1.0, 1.0)

func _ready() -> void:
	_update_soul_light_state()

func _process(delta: float) -> void:
	# Keep updating based on global setting
	_update_soul_light_state()

	if not Global.soul_light_enabled:
		canvas_modulate.color = Color(0, 0, 0, 1)  # completely dark
		return

	var normalized: float = clamp(player.soul_value / player.soul_max, 0.0, 1.0)
	var brightness: float = lerp(min_brightness, max_brightness, normalized)

	var darkened_color := Color(
		tint_color.r * brightness * 0.9,
		tint_color.g * brightness * 0.9,
		tint_color.b * brightness * 0.9,
		1.0
	)

	canvas_modulate.color = darkened_color

func _update_soul_light_state() -> void:
	if not player or not player.soul_light:
		return

	if Global.soul_light_enabled:
		player.soul_light.visible = true
		player.soul_light.energy = 1.5   # ensures light is bright
		player.soul_light.enabled = true
	else:
		player.soul_light.visible = false
		player.soul_light.energy = 0.0
		player.soul_light.enabled = false
