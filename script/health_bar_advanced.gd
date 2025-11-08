extends Control


#@onready var character_icon: Sprite2D = $CharacterIcon
#@onready var background: ColorRect = $Background

@onready var frame: Sprite2D = $Frame
@onready var health_soul_bar_border: Sprite2D = $Health_Soul_BarBorder
@onready var health_bar: ProgressBar = $HealthBar
@onready var soul_bar: ProgressBar = $SoulBar

var player: CharacterBody2D = null

func _ready() -> void:
	await get_tree().process_frame
	player = Global.playerBody
	
	if player:
		health_bar.max_value = player.health_max
		health_bar.min_value = player.health_min
		health_bar.value = player.health
		
		soul_bar.max_value = player.soul_max
		soul_bar.min_value = 0
		soul_bar.value = player.soul_value
	

func _process(_delta: float) -> void:
	if not player:
		player = Global.playerBody
		return
	
	health_bar.value = lerp(health_bar.value, float(player.health), 0.2)
	soul_bar.value = lerp(soul_bar.value, player.soul_value, 0.2)
	
	# Change soul bar color based on level
	#_update_soul_bar_color()

func _update_soul_bar_color() -> void:
	if not player:
		return
	
	var soul_fg = StyleBoxFlat.new()
	
	# Color based on soul mode
	match player.soul_mode:
		0:  # LEVEL1 - Easy (Cyan/Blue)
			soul_fg.bg_color = Color(0.2, 0.6, 1.0, 1.0)
		1:  # LEVEL2 - Normal (Yellow)
			soul_fg.bg_color = Color(1.0, 0.9, 0.2, 1.0)
		2:  # LEVEL3 - Hard (Purple/Magenta)
			soul_fg.bg_color = Color(0.8, 0.2, 1.0, 1.0)
		_:
			soul_fg.bg_color = Color(0.4, 0.7, 1.0, 1.0)
	
	soul_bar.add_theme_stylebox_override("fill", soul_fg)
