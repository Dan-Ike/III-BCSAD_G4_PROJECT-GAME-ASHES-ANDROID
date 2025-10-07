extends Node

const SAVE_FILE := "user://savegame.json"

# Supabase REST config
const SUPABASE_URL := "https://fsntwndbknzhmotgphtj.supabase.co"
const SUPABASE_KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZzbnR3bmRia256aG1vdGdwaHRqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk1NjUwMjAsImV4cCI6MjA3NTE0MTAyMH0.ZJESWD5jcH2rmFodnwHpI_cSsQWqnk1Fk-mmcrjP5mE"

# Track completion for each level individually
var data := {
	"progress": {
		"current_floor": 1,  # Where player currently is
		"current_level": 1,
		"completed_levels": {},  # Track which levels are completed: "1_1": true, "1_2": false, etc.
		"abilities": {
			"double_jump": false,
			"attack": false,
			"dash": false
		}
	},
	"collectables": [],
	"settings": {}
}

var current_user_id: String = ""
var http: HTTPRequest
var _pending_request: String = ""

func _ready() -> void:
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(Callable(self, "_on_http_request_completed"))
	_load_local()
	_apply_abilities_to_global()

#local save and load
func save() -> void:
	_save_local()

func load() -> void:
	_load_local()
	_apply_abilities_to_global()

func _save_local() -> void:
	var f = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if not f:
		var error = FileAccess.get_open_error()
		push_error("SaveManager: cannot open save file for writing: " + SAVE_FILE + " Error: " + str(error))
		return
	var json_string = JSON.stringify(data, "\t")
	f.store_string(json_string)
	f.close()
	print("SaveManager: Local save updated - Current: Floor %d Level %d, Completed levels: %s" % [
		data["progress"]["current_floor"], 
		data["progress"]["current_level"],
		data["progress"]["completed_levels"]
	])

func _load_local() -> void:
	print("SaveManager: Checking for save file at: " + SAVE_FILE)
	if FileAccess.file_exists(SAVE_FILE):
		print("SaveManager: Save file exists, loading...")
		var f = FileAccess.open(SAVE_FILE, FileAccess.READ)
		if f:
			var text = f.get_as_text()
			f.close()
			var parsed = JSON.parse_string(text)
			if typeof(parsed) == TYPE_DICTIONARY:
				data = parsed
				# Migrate old save format to new format
				if not data["progress"].has("completed_levels"):
					data["progress"]["completed_levels"] = {}
				if not data["progress"].has("current_floor"):
					data["progress"]["current_floor"] = data["progress"].get("floor", 1)
				if not data["progress"].has("current_level"):
					data["progress"]["current_level"] = data["progress"].get("level", 1)
				if not data["progress"].has("abilities"):
					data["progress"]["abilities"] = {
						"double_jump": false,
						"attack": false,
						"dash": false
					}
				print("SaveManager: Local save loaded - Current: Floor %d Level %d" % [
					data["progress"]["current_floor"], 
					data["progress"]["current_level"]
				])
			else:
				push_error("SaveManager: Failed to parse save file")
		else:
			push_error("SaveManager: Failed to open save file for reading")
	else:
		print("SaveManager: No save file found, creating new one with defaults")
		_save_local()

func _apply_abilities_to_global() -> void:
	if data["progress"].has("abilities"):
		var abilities = data["progress"]["abilities"]
		Global.can_double_jump = abilities.get("double_jump", false)
		Global.touchatk = abilities.get("attack", false)
		Global.touchdash = abilities.get("dash", false)
		print("SaveManager: Applied abilities - DoubleJump: %s, Attack: %s, Dash: %s" % [
			Global.can_double_jump, Global.touchatk, Global.touchdash
		])

#set and get
func set_setting(key: String, value) -> void:
	if not data.has("settings"):
		data["settings"] = {}
	data["settings"][key] = value
	_save_local()

func get_setting(key: String):
	return data["settings"].get(key, null)

func unlock_ability(ability: String) -> void:
	if not data["progress"].has("abilities"):
		data["progress"]["abilities"] = {}
	data["progress"]["abilities"][ability] = true
	_save_local()
	print("SaveManager: Ability unlocked - %s" % ability)
	if current_user_id != "":
		push_all_to_supabase()

func has_ability(ability: String) -> bool:
	return data["progress"].get("abilities", {}).get(ability, false)

func mark_level_completed(floor: int, level: int) -> void:
	var level_key = "%d_%d" % [floor, level]
	data["progress"]["completed_levels"][level_key] = true
	print("SaveManager: Level %s marked as completed" % level_key)
	_save_local()
	if current_user_id != "":
		push_all_to_supabase()

func is_level_completed(floor: int, level: int) -> bool:
	var level_key = "%d_%d" % [floor, level]
	return data["progress"]["completed_levels"].get(level_key, false)

func advance_to_level(floor: int, level: int) -> void:
	var current_floor = data["progress"]["current_floor"]
	var current_level = data["progress"]["current_level"]
	if floor > current_floor or (floor == current_floor and level > current_level):
		data["progress"]["current_floor"] = floor
		data["progress"]["current_level"] = level
		print("SaveManager: Advanced to Floor %d Level %d" % [floor, level])
		_save_local()
		if current_user_id != "":
			push_all_to_supabase()
	else:
		print("SaveManager: Not advancing - already at or past Floor %d Level %d" % [floor, level])

func set_progress(floor: int, level: int, is_completed: bool = false) -> void:
	if is_completed:
		mark_level_completed(floor, level)
	else:
		advance_to_level(floor, level)

func is_floor_unlocked(floor_name: String) -> bool:
	var parts = floor_name.split("_")
	if parts.size() < 2:
		return false
	var n = int(parts[1])
	return data["progress"]["current_floor"] >= n

func is_level_unlocked(floor_name: String, level_name: String) -> bool:
	var fparts = floor_name.split("_")
	var lparts = level_name.split("_")
	if fparts.size() < 2 or lparts.size() < 4:
		return false
	var fn = int(fparts[1])
	var ln = int(lparts[3])
	if data["progress"]["current_floor"] > fn:
		return true
	if data["progress"]["current_floor"] == fn:
		if data["progress"]["current_level"] >= ln:
			return true
		if ln > 1 and is_level_completed(fn, ln - 1):
			return true
	return false

#supabase sync
func sync_from_supabase(user_id: String) -> void:
	if user_id == "":
		print("SaveManager: sync_from_supabase called with empty user_id")
		return
	current_user_id = user_id
	_pending_request = "fetch_progress"
	var url = "%s/rest/v1/progress?user_id=eq.%s&select=*" % [SUPABASE_URL, user_id]
	var headers = [
		"apikey: %s" % SUPABASE_KEY,
		"Authorization: Bearer %s" % Global.session_token,
		"Content-Type: application/json"
	]
	var err = http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		print("SaveManager: HTTP request failed to start (fetch_progress):", err)

func sync_to_supabase(user_id: String) -> void:
	if user_id == "":
		print("SaveManager: sync_to_supabase called with empty user_id")
		return
	current_user_id = user_id
	push_all_to_supabase()

func push_all_to_supabase() -> void:
	if current_user_id == "":
		print("SaveManager: cannot push - no logged-in user")
		return
	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		print("SaveManager: HTTP busy, skipping push")
		return
	_pending_request = "update_progress"
	var url = "%s/rest/v1/progress?user_id=eq.%s" % [SUPABASE_URL, current_user_id]
	var headers = [
		"apikey: %s" % SUPABASE_KEY,
		"Authorization: Bearer %s" % Global.session_token,
		"Content-Type: application/json",
		"Prefer: return=minimal"
	]
	var payload = {
		"floor_number": int(data["progress"]["current_floor"]),
		"level_number": int(data["progress"]["current_level"]),
		"is_completed": false,  
		"abilities": data["progress"].get("abilities", {}),
		"completed_levels": data["progress"].get("completed_levels", {}),
		"last_played_at": "now()"
	}
	var err = http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(payload))
	if err != OK:
		print("SaveManager: HTTP request failed to start (update_progress):", err)
	else:
		print("SaveManager: Updating progress to Supabase:", payload)

func _merge_completed_levels(local_completed: Dictionary, cloud_completed: Dictionary) -> Dictionary:
	var merged = {}
	for key in local_completed:
		if local_completed[key]:
			merged[key] = true
	for key in cloud_completed:
		if cloud_completed[key]:
			merged[key] = true
	return merged

# compare which is hight, local vs supabase
func _get_highest_completed_level(completed_levels: Dictionary) -> Dictionary:
	var highest = {"floor": 0, "level": 0}
	for key in completed_levels:
		if completed_levels[key]:
			var parts = key.split("_")
			if parts.size() == 2:
				var f = int(parts[0])
				var l = int(parts[1])
				if f > highest["floor"] or (f == highest["floor"] and l > highest["level"]):
					highest["floor"] = f
					highest["level"] = l
	return highest

func _on_http_request_completed(result, response_code, headers, body) -> void:
	var body_text := ""
	if body:
		body_text = body.get_string_from_utf8()
	if _pending_request == "fetch_progress":
		_pending_request = ""
		if response_code == 200:
			var res = JSON.parse_string(body_text)
			if typeof(res) == TYPE_ARRAY and res.size() > 0:
				var row = res[0]
				var cloud_floor = int(row.get("floor_number", 1))
				var cloud_level = int(row.get("level_number", 1))
				var cloud_completed = row.get("completed_levels", {})
				var cloud_abilities = row.get("abilities", {})
				var local_floor = data["progress"]["current_floor"]
				var local_level = data["progress"]["current_level"]
				var local_completed = data["progress"].get("completed_levels", {})
				var merged_completed = _merge_completed_levels(local_completed, cloud_completed)
				data["progress"]["completed_levels"] = merged_completed
				var local_highest = _get_highest_completed_level(local_completed)
				var cloud_highest = _get_highest_completed_level(cloud_completed)
				var use_cloud_position = false
				if cloud_highest["floor"] > local_highest["floor"]:
					use_cloud_position = true
				elif cloud_highest["floor"] == local_highest["floor"] and cloud_highest["level"] > local_highest["level"]:
					use_cloud_position = true
				if use_cloud_position:
					print("SaveManager: Cloud progress is ahead - using cloud position F%d L%d" % [cloud_floor, cloud_level])
					data["progress"]["current_floor"] = cloud_floor
					data["progress"]["current_level"] = cloud_level
				else:
					print("SaveManager: Local progress is ahead/equal - keeping local position F%d L%d" % [local_floor, local_level])
				for ability in cloud_abilities:
					if cloud_abilities[ability]:
						data["progress"]["abilities"][ability] = true
				_save_local()
				_apply_abilities_to_global()
				print("SaveManager: Sync complete - Completed levels: %s" % data["progress"]["completed_levels"])
				push_all_to_supabase()
			else:
				print("SaveManager: No cloud progress found, pushing local to cloud")
				push_all_to_supabase()
		else:
			print("SaveManager: fetch_progress failed:", response_code, body_text)
	elif _pending_request == "update_progress":
		_pending_request = ""
		if response_code in [200, 201, 204]:
			print("SaveManager: update_progress OK - Cloud progress updated")
		else:
			print("SaveManager: update_progress failed:", response_code, body_text)
