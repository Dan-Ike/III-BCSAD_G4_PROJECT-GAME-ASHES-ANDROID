extends Node

const SAVE_FILE := "user://savegame.json"

const SUPABASE_URL := "https://fsntwndbknzhmotgphtj.supabase.co"
const SUPABASE_KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZzbnR3bmRia256aG1vdGdwaHRqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk1NjUwMjAsImV4cCI6MjA3NTE0MTAyMH0.ZJESWD5jcH2rmFodnwHpI_cSsQWqnk1Fk-mmcrjP5mE"

var data := {
	"progress": {
		"current_floor": 1,
		"current_level": 1,
		"completed_levels": {},
		"abilities": {
			"double_jump": false,
			"attack": false,
			"dash": false,
			"shine": false
		}
	},
	"collectables": [],
	"settings": {},
	"watched_cutscenes": [],
	"control_layout": {},
	"level_times": {},  
	"best_run_time": 0.0 
}

func save_level_time(floor: int, level: int, time: float) -> void:
	"""Save the completion time for a specific level"""
	var level_key = "%d_%d" % [floor, level]
	
	print("[SaveManager] save_level_time called - Floor: %d, Level: %d, Time: %.2f" % [floor, level, time])
	
	if not data.has("level_times"):
		data["level_times"] = {}
		print("[SaveManager] Created new level_times dictionary")
	
	# Only save if it's a new best time or first completion
	if not data["level_times"].has(level_key):
		data["level_times"][level_key] = time
		print("[SaveManager] First completion! Saved time: %.2f seconds for %s" % [time, level_key])
		_save_local()
		_check_and_update_best_run()
		
		# Push to Supabase if online
		if current_user_id != "":
			push_times_to_supabase()
			
	elif time < data["level_times"][level_key]:
		var old_time = data["level_times"][level_key]
		data["level_times"][level_key] = time
		print("[SaveManager] New best time for %s! Old: %.2f, New: %.2f" % [level_key, old_time, time])
		_save_local()
		_check_and_update_best_run()
		
		# Push to Supabase if online
		if current_user_id != "":
			push_times_to_supabase()
	else:
		print("[SaveManager] Time %.2f not better than existing %.2f for %s" % [time, data["level_times"][level_key], level_key])

func _check_and_update_best_run() -> void:
	"""Calculate total time if all 9 levels are completed and update best run"""
	if not data.has("level_times"):
		return
	
	var total_time = 0.0
	var all_completed = true
	
	# Check all 9 levels (3 floors x 3 levels)
	for floor in range(1, 4):
		for level in range(1, 4):
			var level_key = "%d_%d" % [floor, level]
			if data["level_times"].has(level_key):
				total_time += data["level_times"][level_key]
			else:
				all_completed = false
				break
		if not all_completed:
			break
	
	# Only update best run if all levels completed
	if all_completed:
		if not data.has("best_run_time"):
			data["best_run_time"] = 0.0
		
		if data["best_run_time"] == 0.0 or total_time < data["best_run_time"]:
			data["best_run_time"] = total_time
			print("SaveManager: NEW BEST RUN TIME: %.2f seconds!" % total_time)
			_save_local()
			
			# Push to Supabase if online
			if current_user_id != "":
				push_times_to_supabase()

func get_data() -> Dictionary:
	"""Get the entire save data dictionary"""
	return data

func push_all_to_supabase() -> void:
	if current_user_id == "":
		print("SaveManager: cannot push - no logged-in user")
		return
	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		print("SaveManager: HTTP busy, skipping push")
		return
	
	print("\nPushing to Supabase:")
	print("   Floor: %d, Level: %d" % [data["progress"]["current_floor"], data["progress"]["current_level"]])
	
	# Get user metadata for avatar and username
	var current_user = Global.get_current_user()
	var user_metadata = current_user.get("user_metadata", {})
	var avatar_url = user_metadata.get("avatar_url", "")
	var username = current_user.get("email", "Player").split("@")[0]
	
	print("   User: %s" % username)
	print("   Avatar URL: %s" % (avatar_url.substr(0, 50) if avatar_url != "" else "NONE"))
	
	_pending_request = "update_progress"
	
	# Use POST for INSERT, but check if row exists first
	var url = "%s/rest/v1/progress?user_id=eq.%s" % [SUPABASE_URL, current_user_id]
	
	var headers = [
		"apikey: %s" % SUPABASE_KEY,
		"Authorization: Bearer %s" % Global.session_token,
		"Content-Type: application/json",
		"Prefer: return=minimal,resolution=merge-duplicates"
	]
	
	if OS.has_feature("web"):
		headers.append("Accept-Encoding: identity")
	
	var payload = {
		"user_id": current_user_id,
		"floor_number": int(data["progress"]["current_floor"]),
		"level_number": int(data["progress"]["current_level"]),
		"is_completed": false,
		"abilities": data["progress"].get("abilities", {}),
		"completed_levels": data["progress"].get("completed_levels", {}),
		"level_times": data.get("level_times", {}),
		"best_run_time": data.get("best_run_time", 0.0),
		"last_played_at": "now()",
		"avatar_url": avatar_url,
		"username": username
	}
	
	# Use PATCH instead of POST to update existing rows
	var err = http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(payload))
	if err != OK:
		print("SaveManager: HTTP request failed to start (update_progress):", err)
	else:
		print("SaveManager: PATCH request sent successfully")


func push_times_to_supabase() -> void:
	"""Push level times and best run time to Supabase"""
	if current_user_id == "":
		print("SaveManager: cannot push times - no logged-in user")
		return
	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		print("SaveManager: HTTP busy, skipping times push")
		return
	
	print("\nPushing level times to Supabase:")
	print("   Level times: " + str(data.get("level_times", {})))
	print("   Best run: %.2f" % data.get("best_run_time", 0.0))
	
	_pending_request = "update_times"
	
	# Use PATCH with user_id filter
	var url = "%s/rest/v1/progress?user_id=eq.%s" % [SUPABASE_URL, current_user_id]
	
	var headers = [
		"apikey: %s" % SUPABASE_KEY,
		"Authorization: Bearer %s" % Global.session_token,
		"Content-Type: application/json",
		"Prefer: return=minimal"
	]
	
	if OS.has_feature("web"):
		headers.append("Accept-Encoding: identity")
	
	var payload = {
		"level_times": data.get("level_times", {}),
		"best_run_time": data.get("best_run_time", 0.0),
		"last_played_at": "now()"
	}
	
	# Use PATCH to update
	var err = http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(payload))
	if err != OK:
		print("SaveManager: HTTP request failed to start (update_times):", err)


# ============================================
# Add this new function for initial row creation
# ============================================

func _create_initial_progress_row() -> void:
	"""Create initial progress row for new users"""
	if current_user_id == "":
		return
	
	print("SaveManager: Creating initial progress row for new user")
	_pending_request = "create_progress"
	
	# Get user metadata
	var current_user = Global.get_current_user()
	var user_metadata = current_user.get("user_metadata", {})
	var avatar_url = user_metadata.get("avatar_url", "")
	var username = current_user.get("email", "Player").split("@")[0]
	
	var url = "%s/rest/v1/progress" % SUPABASE_URL
	
	var headers = [
		"apikey: %s" % SUPABASE_KEY,
		"Authorization: Bearer %s" % Global.session_token,
		"Content-Type: application/json",
		"Prefer: return=minimal"
	]
	
	if OS.has_feature("web"):
		headers.append("Accept-Encoding: identity")
	
	var payload = {
		"user_id": current_user_id,
		"floor_number": int(data["progress"]["current_floor"]),
		"level_number": int(data["progress"]["current_level"]),
		"is_completed": false,
		"abilities": data["progress"].get("abilities", {}),
		"completed_levels": data["progress"].get("completed_levels", {}),
		"level_times": data.get("level_times", {}),
		"best_run_time": data.get("best_run_time", 0.0),
		"avatar_url": avatar_url,
		"username": username
	}
	
	# Use POST for INSERT
	var err = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		print("SaveManager: HTTP request failed to start (create_progress):", err)


# Update fetch_leaderboard_data to include avatar_url and username
func fetch_leaderboard_data(callback: Callable) -> void:
	"""Fetch top leaderboard entries from Supabase"""
	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		print("SaveManager: HTTP busy, cannot fetch leaderboard")
		callback.call([])
		return
	
	print("SaveManager: Fetching leaderboard data...")
	_pending_request = "fetch_leaderboard"
	
	set_meta("leaderboard_callback", callback)
	
	# UPDATED: Include avatar_url and username in the query
	var url = "%s/rest/v1/progress?select=user_id,best_run_time,level_times,avatar_url,username&best_run_time=gte.0.1&order=best_run_time.asc" % SUPABASE_URL
	
	var headers = [
		"apikey: %s" % SUPABASE_KEY,
		"Content-Type: application/json"
	]
	
	if OS.has_feature("web"):
		headers.append("Accept-Encoding: identity")
	
	print("SaveManager: Leaderboard URL: ", url)
	
	var err = http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		print("SaveManager: Failed to fetch leaderboard:", err)
		callback.call([])


func get_level_time(floor: int, level: int) -> float:
	"""Get the best time for a specific level (returns 0.0 if not completed)"""
	var level_key = "%d_%d" % [floor, level]
	if not data.has("level_times"):
		return 0.0
	return data["level_times"].get(level_key, 0.0)

func get_best_run_time() -> float:
	"""Get the best full game completion time"""
	if not data.has("best_run_time"):
		return 0.0
	return data["best_run_time"]

func get_leaderboard_entry() -> Dictionary:
	"""Get local player's leaderboard entry"""
	return {
		"player_name": "Player",  
		"profile_pic": "", 
		"time": get_best_run_time(),
		"completed_all": _has_completed_all_levels()
	}

func _has_completed_all_levels() -> bool:
	"""Check if player has completed all 9 levels"""
	if not data.has("level_times"):
		return false
	
	for floor in range(1, 4):
		for level in range(1, 4):
			var level_key = "%d_%d" % [floor, level]
			if not data["level_times"].has(level_key):
				return false
	return true

var current_user_id: String = ""
var http: HTTPRequest
var _pending_request: String = ""

func _ready() -> void:
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(Callable(self, "_on_http_request_completed"))
	
	if OS.has_feature("web"):
		http.accept_gzip = false
	
	_load_local()
	_apply_abilities_to_global()

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
		str(data["progress"]["completed_levels"])
	])

func reset_level_times() -> void:
	"""Reset all level times (high scores) when starting a new game"""
	data["level_times"] = {}
	data["best_run_time"] = 0.0
	_save_local()
	print("SaveManager: All level times (high scores) have been reset")

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
						"dash": false,
						"shine": false
					}
				elif not data["progress"]["abilities"].has("shine"):
					data["progress"]["abilities"]["shine"] = false
				if not data.has("watched_cutscenes"):
					data["watched_cutscenes"] = []
				if not data.has("control_layout"):
					data["control_layout"] = {}
				if not data.has("level_times"):
					data["level_times"] = {}
				if not data.has("best_run_time"):
					data["best_run_time"] = 0.0
				print("SaveManager: Loaded level_times: ", data.get("level_times", {}))
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
		Global.touchshine = abilities.get("shine", false) 
		print("SaveManager: Applied abilities - DoubleJump: %s, Attack: %s, Dash: %s, Shine: %s" % [
			Global.can_double_jump, Global.touchatk, Global.touchdash, Global.touchshine
		])

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

func save_control_layout(layout: Dictionary) -> void:
	if not data.has("control_layout"):
		data["control_layout"] = {}
	
	data["control_layout"] = layout
	_save_local()
	print("SaveManager: Control layout saved locally")
	print("  Layout data: ", layout)
	
	# Uncomment when database is ready
	# if current_user_id != "":
	#     push_layout_to_supabase()

func get_control_layout() -> Dictionary:
	var layout = data.get("control_layout", {})
	if layout.size() > 0:
		print("SaveManager: Loaded control layout with %d buttons" % layout.size())
	return layout

func reset_control_layout() -> void:
	data["control_layout"] = {}
	_save_local()
	print("SaveManager: Control layout reset to defaults")
	
	# Uncomment when database is ready
	# if current_user_id != "":
	#     push_layout_to_supabase()

func mark_cutscene_watched(cutscene_id: String) -> void:
	if not data.has("watched_cutscenes"):
		data["watched_cutscenes"] = []
	
	if cutscene_id not in data["watched_cutscenes"]:
		data["watched_cutscenes"].append(cutscene_id)
		_save_local()
		print("SaveManager: Cutscene '%s' marked as watched (local only)" % cutscene_id)

func has_watched_cutscene(cutscene_id: String) -> bool:
	if not data.has("watched_cutscenes"):
		data["watched_cutscenes"] = []
		return false
	
	return cutscene_id in data["watched_cutscenes"]

func reset_cutscene_history() -> void:
	data["watched_cutscenes"] = []
	_save_local()
	print("SaveManager: All cutscene history reset (local only)")

func sync_from_supabase(user_id: String) -> void:
	if user_id == "":
		print("SaveManager: sync_from_supabase called with empty user_id")
		return
	
	print("\nSTARTING SUPABASE SYNC")
	print("   Local Progress BEFORE sync:")
	print("   Floor: %d, Level: %d" % [data["progress"]["current_floor"], data["progress"]["current_level"]])
	print("   Completed Levels: " + str(data["progress"]["completed_levels"]))
	print("   Abilities: " + str(data["progress"]["abilities"]))
	
	current_user_id = user_id
	_pending_request = "fetch_progress"
	var url = "%s/rest/v1/progress?user_id=eq.%s&select=*" % [SUPABASE_URL, user_id]
	
	var headers = [
		"apikey: %s" % SUPABASE_KEY,
		"Authorization: Bearer %s" % Global.session_token,
		"Content-Type: application/json"
	]
	
	if OS.has_feature("web"):
		headers.append("Accept-Encoding: identity")
	
	var err = http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		print("SaveManager: HTTP request failed to start (fetch_progress):", err)

func sync_to_supabase(user_id: String) -> void:
	if user_id == "":
		print("SaveManager: sync_to_supabase called with empty user_id")
		return
	current_user_id = user_id
	push_all_to_supabase()

func _merge_completed_levels(local_completed: Dictionary, cloud_completed: Dictionary) -> Dictionary:
	var merged = {}
	for key in local_completed:
		if local_completed[key]:
			merged[key] = true
	for key in cloud_completed:
		if cloud_completed[key]:
			merged[key] = true
	return merged

func _merge_abilities(local_abilities: Dictionary, cloud_abilities: Dictionary) -> Dictionary:
	var merged = {}
	var all_keys = {}
	
	for key in local_abilities:
		all_keys[key] = true
	for key in cloud_abilities:
		all_keys[key] = true
	
	for key in all_keys:
		var local_val = local_abilities.get(key, false)
		var cloud_val = cloud_abilities.get(key, false)
		merged[key] = local_val or cloud_val
	
	return merged

func _merge_watched_cutscenes(local_watched: Array, cloud_watched: Array) -> Array:
	var merged = []
	
	for cutscene in local_watched:
		if cutscene not in merged:
			merged.append(cutscene)
	
	for cutscene in cloud_watched:
		if cutscene not in merged:
			merged.append(cutscene)
	
	return merged

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

func _compare_progress(floor1: int, level1: int, floor2: int, level2: int) -> int:
	if floor1 > floor2:
		return 1
	elif floor1 < floor2:
		return -1
	else:
		if level1 > level2:
			return 1
		elif level1 < level2:
			return -1
		else:
			return 0

func _on_http_request_completed(result, response_code, headers, body) -> void:
	var body_text := ""
	if body and body.size() > 0:
		body_text = body.get_string_from_utf8()
		
		if body_text == "" or body_text == "null":
			print("Empty response received from Supabase")
			if _pending_request == "fetch_progress":
				_pending_request = ""
				print("\nNo cloud progress found - Creating initial cloud save")
				_create_initial_progress_row()  # CHANGED: Use new function
			return
	
	print("Response Code: %d" % response_code)
	print("Response Body Length: %d" % body_text.length())
	
	if _pending_request == "fetch_progress":
		_pending_request = ""
		
		if response_code == 200:
			var res = JSON.parse_string(body_text)
			
			if res == null:
				print("Failed to parse JSON response")
				print("\nNo valid cloud progress - Creating initial cloud save")
				_create_initial_progress_row()  # CHANGED: Use new function
				return
			
			if typeof(res) == TYPE_ARRAY and res.size() > 0:
				# ... existing sync code stays the same ...
				var row = res[0]
				
				var cloud_times = row.get("level_times", {})
				if cloud_times == null:
					cloud_times = {}
				
				var local_times = data.get("level_times", {})
				var merged_times = _merge_level_times(local_times, cloud_times)
				data["level_times"] = merged_times
				print("Merged level times: " + str(merged_times))
				
				var cloud_best = float(row.get("best_run_time", 0.0)) if row.get("best_run_time") != null else 0.0
				var local_best = float(data.get("best_run_time", 0.0))
				if cloud_best > 0.0 and local_best > 0.0:
					data["best_run_time"] = min(cloud_best, local_best)
				elif cloud_best > 0.0:
					data["best_run_time"] = cloud_best
				elif local_best > 0.0:
					data["best_run_time"] = local_best
				print("Best run time: %.2f" % data.get("best_run_time", 0.0))
				
				var cloud_floor = int(row.get("floor_number", 1))
				var cloud_level = int(row.get("level_number", 1))
				
				var cloud_completed = row.get("completed_levels", {})
				if cloud_completed == null:
					cloud_completed = {}
				
				var cloud_abilities = row.get("abilities", {})
				if cloud_abilities == null:
					cloud_abilities = {}
				
				var cloud_watched = row.get("watched_cutscenes", [])
				if cloud_watched == null:
					cloud_watched = []
				
				print("\nCloud Progress:")
				print("   Floor: %d, Level: %d" % [cloud_floor, cloud_level])
				print("   Completed Levels: " + str(cloud_completed))
				print("   Abilities: " + str(cloud_abilities))
				
				var local_floor = data["progress"]["current_floor"]
				var local_level = data["progress"]["current_level"]
				var local_completed = data["progress"].get("completed_levels", {})
				var local_abilities = data["progress"].get("abilities", {})
				var local_watched = data.get("watched_cutscenes", [])
				
				var merged_completed = _merge_completed_levels(local_completed, cloud_completed)
				data["progress"]["completed_levels"] = merged_completed
				print("\nMerged completed levels: " + str(merged_completed))
				
				var merged_abilities = _merge_abilities(local_abilities, cloud_abilities)
				data["progress"]["abilities"] = merged_abilities
				print("Merged abilities: " + str(merged_abilities))
				
				var merged_watched = _merge_watched_cutscenes(local_watched, cloud_watched)
				data["watched_cutscenes"] = merged_watched
				
				var local_highest = _get_highest_completed_level(local_completed)
				var cloud_highest = _get_highest_completed_level(cloud_completed)
				
				print("\nHighest Completed Levels:")
				print("   Local: Floor %d Level %d" % [local_highest["floor"], local_highest["level"]])
				print("   Cloud: Floor %d Level %d" % [cloud_highest["floor"], cloud_highest["level"]])
				
				var final_floor = local_floor
				var final_level = local_level
				
				var completed_comparison = _compare_progress(
					local_highest["floor"], local_highest["level"],
					cloud_highest["floor"], cloud_highest["level"]
				)
				
				if completed_comparison >= 0:
					if _compare_progress(cloud_floor, cloud_level, local_floor, local_level) > 0:
						final_floor = cloud_floor
						final_level = cloud_level
						print("Using cloud's current position (ahead of local)")
					else:
						print("Using local's current position (ahead or equal)")
				else:
					final_floor = cloud_floor
					final_level = cloud_level
					print("Using cloud's position (more progress)")
				
				data["progress"]["current_floor"] = final_floor
				data["progress"]["current_level"] = final_level
				
				print("\nFinal Progress:")
				print("   Floor: %d, Level: %d" % [final_floor, final_level])
				print("   Completed Levels: " + str(merged_completed))
				print("   Abilities: " + str(merged_abilities))
				print("SYNC COMPLETE\n")
				
				_save_local()
				_apply_abilities_to_global()
				
				await get_tree().create_timer(0.5).timeout
				push_all_to_supabase()
				
			else:
				print("\nNo cloud progress found - Creating initial cloud save")
				_create_initial_progress_row()  # CHANGED: Use new function
		else:
			print("SaveManager: fetch_progress failed:", response_code, body_text.substr(0, min(200, body_text.length())))
			
			if response_code == 406:
				print("No cloud data exists yet - will create on first save")
	
	elif _pending_request == "create_progress":  # NEW HANDLER
		_pending_request = ""
		if response_code in [200, 201, 204]:
			print("✅ Initial progress row created successfully")
			# Now do a regular update to ensure everything is synced
			await get_tree().create_timer(0.3).timeout
			push_all_to_supabase()
		else:
			print("❌ Failed to create initial progress row:", response_code, body_text.substr(0, min(200, body_text.length())))
	
	elif _pending_request == "update_progress":
		_pending_request = ""
		if response_code in [200, 201, 204]:
			print("✅ Cloud save updated successfully")
		else:
			print("❌ Cloud save failed:", response_code, body_text.substr(0, min(200, body_text.length())))
			
			# If PATCH fails because row doesn't exist, create it
			if response_code == 406 or response_code == 404:
				print("   Row doesn't exist, creating initial row...")
				_create_initial_progress_row()
			
	elif _pending_request == "fetch_leaderboard":
		_pending_request = ""
		var callback = get_meta("leaderboard_callback") if has_meta("leaderboard_callback") else null
		
		print("SaveManager: Leaderboard response - Code:", response_code, "Body preview:", body_text.substr(0, 200))
		
		if response_code == 200:
			var res = JSON.parse_string(body_text)
			
			if typeof(res) == TYPE_ARRAY:
				print("SaveManager: Raw leaderboard data count:", res.size())
				
				var valid_entries = []
				for entry in res:
					var time = entry.get("best_run_time", 0)
					var time_float = float(time)
					
					if time_float > 0.0:
						var cleaned_entry = {
							"user_id": str(entry.get("user_id", "")),
							"best_run_time": time_float,
							"level_times": entry.get("level_times", {}),
							"avatar_url": entry.get("avatar_url", "") if entry.get("avatar_url") != null else "",
							"username": entry.get("username", "Player") if entry.get("username") != null else "Player"
						}
						valid_entries.append(cleaned_entry)
						
						print("  Added entry - User:", cleaned_entry["username"], "Time:", time_float)
				
				print("SaveManager: Fetched %d valid leaderboard entries (out of %d total)" % [valid_entries.size(), res.size()])
				if callback:
					callback.call(valid_entries)
			else:
				print("SaveManager: Invalid leaderboard response type:", typeof(res))
				if callback:
					callback.call([])
		else:
			print("SaveManager: Leaderboard fetch failed:", response_code)
			print("Error details: ", body_text.substr(0, 200))
			if callback:
				callback.call([])
				
	elif _pending_request == "update_times":
		_pending_request = ""
		if response_code in [200, 201, 204]:
			print("✅ Level times pushed to cloud successfully")
		else:
			print("❌ Level times push failed:", response_code, body_text.substr(0, min(200, body_text.length())))
			
	elif _pending_request == "debug_check":
		_pending_request = ""
		print("\n=== DEBUG CLOUD DATA ===")
		print("Response code:", response_code)
		print("Full response:", body_text)
		print("========================\n")

func debug_check_cloud_data() -> void:
	"""Debug function to check what's in the cloud"""
	if current_user_id == "":
		print("DEBUG: Not logged in")
		return
	
	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		print("DEBUG: HTTP busy")
		return
	
	_pending_request = "debug_check"
	var url = "%s/rest/v1/progress?user_id=eq.%s&select=*" % [SUPABASE_URL, current_user_id]
	
	var headers = [
		"apikey: %s" % SUPABASE_KEY,
		"Authorization: Bearer %s" % Global.session_token,
		"Content-Type: application/json"
	]
	
	http.request(url, headers, HTTPClient.METHOD_GET)


func get_username_from_user_id(user_id: String) -> String:
	"""Get username from current user or return generic name"""
	var current_user = Global.get_current_user()
	
	if current_user.has("id") and str(current_user["id"]) == user_id:
		# It's the current user
		return current_user.get("email", "Player").split("@")[0]
	else:
		# Different user - return generic name for now
		# TODO: Fetch from user table when available
		return "Player"

func _merge_level_times(local_times: Dictionary, cloud_times: Dictionary) -> Dictionary:
	"""Merge level times, keeping the best (lowest) time for each level"""
	var merged = {}
	
	# Add all local times
	for key in local_times:
		merged[key] = local_times[key]
	
	# Compare with cloud times and keep the better ones
	for key in cloud_times:
		if not merged.has(key):
			# Cloud has a time we don't have locally
			merged[key] = cloud_times[key]
		else:
			# Keep the better (lower) time
			merged[key] = min(merged[key], cloud_times[key])
	
	return merged

# Collectable Management Functions
func collect_item(collectable_id: String, collectable_type: String = "generic") -> void:
	"""Record a collected item"""
	if not data.has("collectables"):
		data["collectables"] = []
	
	# Check if already collected
	for item in data["collectables"]:
		if item.get("id") == collectable_id:
			print("SaveManager: Item already collected: %s" % collectable_id)
			return
	
	# Add new collectable
	var collectable_data = {
		"id": collectable_id,
		"type": collectable_type,
		"floor": Global.current_floor,
		"level": Global.current_level,
		"collected_at": Time.get_datetime_string_from_system()
	}
	
	data["collectables"].append(collectable_data)
	_save_local()
	
	print("SaveManager: Collected item - %s (Type: %s) at Floor %d Level %d" % [
		collectable_id,
		collectable_type,
		Global.current_floor,
		Global.current_level
	])
	
	# Sync to cloud if logged in
	if current_user_id != "":
		push_all_to_supabase()

func is_collectable_collected(collectable_id: String) -> bool:
	"""Check if a collectable has been collected"""
	if not data.has("collectables"):
		return false
	
	for item in data["collectables"]:
		if item.get("id") == collectable_id:
			return true
	
	return false

func get_collected_items_by_type(collectable_type: String) -> Array:
	"""Get all collected items of a specific type"""
	var items = []
	
	if not data.has("collectables"):
		return items
	
	for item in data["collectables"]:
		if item.get("type") == collectable_type:
			items.append(item)
	
	return items

func get_collected_items_in_level(floor: int, level: int) -> Array:
	"""Get all collectables collected in a specific level"""
	var items = []
	
	if not data.has("collectables"):
		return items
	
	for item in data["collectables"]:
		if item.get("floor") == floor and item.get("level") == level:
			items.append(item)
	
	return items

func get_total_collected_count() -> int:
	"""Get total number of collected items"""
	if not data.has("collectables"):
		return 0
	return data["collectables"].size()

func get_collected_count_by_type(collectable_type: String) -> int:
	"""Get count of collected items by type"""
	return get_collected_items_by_type(collectable_type).size()

func reset_collectables() -> void:
	"""Reset all collectables (useful for testing)"""
	data["collectables"] = []
	_save_local()
	print("SaveManager: All collectables reset")
