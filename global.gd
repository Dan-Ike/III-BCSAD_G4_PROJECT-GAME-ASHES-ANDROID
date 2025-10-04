extends Node

var playerBody: CharacterBody2D
var playerDamageZone: Area2D
var playerDamageAmount: int
var batDamageZone: Area2D
var batDamageAmount: int
var playerAlive: bool
var gameStarted: bool
var golemDamageZone: Area2D
var golemDamageAmount: int
var playerHitbox: Area2D
var current_wave: int
var moving_to_next_wave: bool
var spikeDamageAmount: int = 9999 

# Abilities
var can_double_jump: bool = false
var touchleft: bool = true
var touchright: bool = true
var touchjump: bool = true
var touchatk: bool = false
var touchdash: bool = false
var joystick: bool = false

var selected_floor: String = "floor_1"


# Controls
signal control_type_changed
var control_type: int = 0: set = set_control_type

func _ready() -> void:
	# Load data from save file
	SaveManager.load()

	# Restore settings
	control_type = SaveManager.get_setting("control_type")
	var vol = SaveManager.get_setting("music_volume")
	if vol != null:
		MusicManager.set_volume(vol)

	# Restore abilities
	can_double_jump = SaveManager.data["progress"]["abilities"]["double_jump"]
	touchatk = SaveManager.data["progress"]["abilities"]["attack"]
	touchdash = SaveManager.data["progress"]["abilities"]["dash"]

func set_control_type(value: int) -> void:
	if control_type == value:
		return
	control_type = value
	SaveManager.set_setting("control_type", value)  # persist change
	emit_signal("control_type_changed")

func is_button_mode() -> bool:
	return control_type == 0

func is_joystick_mode() -> bool:
	return control_type == 1

# -- Ability unlock helpers that also save --
func unlock_double_jump():
	can_double_jump = true
	SaveManager.unlock_ability("double_jump")

func unlock_attack():
	touchatk = true
	SaveManager.unlock_ability("attack")

func unlock_dash():
	touchdash = true
	SaveManager.unlock_ability("dash")

func set_music_volume(value: float) -> void:
	SaveManager.set_setting("music_volume", value)  # save persistently
	MusicManager.set_volume(value)  # apply immediately
