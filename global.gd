extends Node

#Player/Game
var playerBody
var playerDamageZone
var playerDamageAmount
var batDamageZone
var batDamageAmount
var playerAlive
var gameStarted
var golemDamageZone
var golemDamageAmount
var playerHitbox
var current_wave
var moving_to_next_wave
var spikeDamageAmount: int = 9999

# Floor and Level Tracking
var current_floor: int = 1
var current_level: int = 1

#Abilities
var can_double_jump: bool = false
var touchleft: bool = true
var touchright: bool = true
var touchjump: bool = true
var touchatk: bool = false
var touchdash: bool = false
var joystick: bool = false

var selected_floor: String = "floor_1"

# Soul Light Control
var soul_light_enabled: bool = false
var saved_soul_mode: int = -1  # Stores the last soul mode (0=LEVEL1, 1=LEVEL2, 2=LEVEL3)
enum SoulLightMode { LEVEL1, LEVEL2, LEVEL3 }


#Controls
signal control_type_changed
var control_type: int = 0: set = set_control_type

#Supabase Auth
var supabase: Node = null
var session: Dictionary = {}

#Supabase Tokens
var session_token: String = ""  
var refresh_token: String = ""   


func _ready() -> void:
	var SupabaseScript = load("res://addons/supabase/Supabase/supabase.gd")
	if SupabaseScript:
		supabase = SupabaseScript.new()
		add_child(supabase)
		if supabase.has_method("load_nodes"):
			supabase.load_nodes()
		print("Global: Supabase node created (if plugin present)")
	if typeof(SaveManager) == TYPE_OBJECT:
		SaveManager.load()
		var ct = SaveManager.get_setting("control_type")
		if ct != null:
			control_type = ct
		var vol = SaveManager.get_setting("music_volume")
		if vol != null and MusicManager and MusicManager.has_method("set_volume"):
			MusicManager.set_volume(vol)
		can_double_jump = SaveManager.has_ability("double_jump")
		touchatk = SaveManager.has_ability("attack")
		touchdash = SaveManager.has_ability("dash")
	var user_id = _get_user_id()
	if user_id != "" and OS.has_feature("network"):
		if SaveManager.has_method("sync_from_supabase"):
			SaveManager.sync_from_supabase(user_id)

func enable_soul_light():
	soul_light_enabled = true
	if playerBody and playerBody.has_node("SoulLight"):
		playerBody.get_node("SoulLight").visible = true

func disable_soul_light():
	soul_light_enabled = false
	if playerBody and playerBody.has_node("SoulLight"):
		playerBody.get_node("SoulLight").visible = false


#session helper
func set_session(user_info: Dictionary, access_token: String = "", refresh: String = "") -> void:
	session = user_info
	if access_token != "":
		session_token = access_token
	if refresh != "":
		refresh_token = refresh

func clear_session() -> void:
	session = {}
	session_token = "" 
	refresh_token = ""  
	print("Global: Session cleared completely")

func get_current_user() -> Dictionary:
	return session

func get_avatar_url() -> String:
	if session.has("user_metadata") and session["user_metadata"].has("avatar_url"):
		return session["user_metadata"]["avatar_url"]
	return ""

func get_full_name() -> String:
	if session.has("user_metadata") and session["user_metadata"].has("full_name"):
		return session["user_metadata"]["full_name"]
	return "Guest"

#supabase auth helper
func get_auth() -> Node:
	if not supabase:
		return null
	if supabase.has_node("auth"):
		return supabase.get_node("auth")
	if supabase.has_method("get_auth"):
		return supabase.get_auth()
	return null

func _get_user_id() -> String:
	if session.has("id"):
		return str(session["id"])
	return ""

#control settings
func set_control_type(value: int) -> void:
	if control_type == value:
		return
	control_type = value
	if typeof(SaveManager) == TYPE_OBJECT:
		SaveManager.set_setting("control_type", value)
	emit_signal("control_type_changed")

func is_button_mode() -> bool:
	return control_type == 0

func is_joystick_mode() -> bool:
	return control_type == 1

#abilities
func unlock_double_jump():
	can_double_jump = true
	if typeof(SaveManager) == TYPE_OBJECT:
		SaveManager.unlock_ability("double_jump")

func unlock_attack():
	touchatk = true
	if typeof(SaveManager) == TYPE_OBJECT:
		SaveManager.unlock_ability("attack")

func unlock_dash():
	touchdash = true
	if typeof(SaveManager) == TYPE_OBJECT:
		SaveManager.unlock_ability("dash")

#music
func set_music_volume(value: float) -> void:
	if typeof(SaveManager) == TYPE_OBJECT:
		SaveManager.set_setting("music_volume", value)
	if MusicManager and MusicManager.has_method("set_volume"):
		MusicManager.set_volume(value)

# Floor/Level Management
func set_floor_level(floor: int, level: int) -> void:
	current_floor = floor
	current_level = level
	print("Global: Set floor %d, level %d" % [floor, level])

func advance_level() -> void:
	current_level += 1
	print("Global: Advanced to level %d" % current_level)

func advance_floor() -> void:
	current_floor += 1
	current_level = 1  # Reset level when advancing floor
	print("Global: Advanced to floor %d, level reset to 1" % current_floor)

func reset_progress() -> void:
	current_floor = 1
	current_level = 1
	print("Global: Progress reset to floor 1, level 1")
