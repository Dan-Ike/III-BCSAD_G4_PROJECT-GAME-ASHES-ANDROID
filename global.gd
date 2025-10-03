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
var can_double_jump: bool = false
var touchleft: bool = true
var touchright: bool = true
var touchjump: bool = true
var touchatk: bool = false
var touchdash: bool = false
var joystick: bool = false
signal control_type_changed
var control_type: int = 0: set = set_control_type

func set_control_type(value: int) -> void:
	if control_type == value:
		return
	control_type = value
	emit_signal("control_type_changed")

func is_button_mode() -> bool:
	return control_type == 0

func is_joystick_mode() -> bool:
	return control_type == 1
