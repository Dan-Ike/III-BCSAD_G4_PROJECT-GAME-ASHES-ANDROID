extends Node2D

@onready var player: Player = $player
@onready var canvas_modulate: CanvasModulate = $CanvasModulate

# How dark the world gets when soul light is empty
@export var min_brightness: float = 0.2 # 0.0 = total black, 0.2 = 80% black
# Brightness when soul is full
@export var max_brightness: float = 1.0

# Optional color tint for the darkness
@export var tint_color: Color = Color(1.0, 1.0, 1.0)

func _process(delta: float) -> void:
	var normalized: float = clamp(player.soul_value / player.soul_max, 0.0, 1.0)
	var brightness: float = lerp(min_brightness, max_brightness, normalized)

	# Darker, desaturated tone (reduces blue tint further)
	var darkened_color := Color(
		tint_color.r * brightness * 0.9,
		tint_color.g * brightness * 0.9,
		tint_color.b * brightness * 0.9,
		1.0
	)

	canvas_modulate.color = darkened_color

	# Force Level 1 mode (no soul damage)
	player.soul_mode = player.SoulLightMode.LEVEL1
