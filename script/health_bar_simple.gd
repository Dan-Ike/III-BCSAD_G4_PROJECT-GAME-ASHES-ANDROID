extends Control

@onready var health_bar: ProgressBar = $HealthBar
@onready var character_icon: Sprite2D = $CharacterIcon
@onready var background: ColorRect = $Background

var player: CharacterBody2D = null

func _ready() -> void:
	# Wait for player to be ready
	await get_tree().process_frame
	player = Global.playerBody
	
	if player:
		health_bar.max_value = player.health_max
		health_bar.min_value = player.health_min
		health_bar.value = player.health
	

func _process(_delta: float) -> void:
	if not player:
		player = Global.playerBody
		return
	
	# Smooth health bar animation
	health_bar.value = lerp(health_bar.value, float(player.health), 0.2)
