extends Node

const SAVE_PATH := "user://savegame.json"

var data := {
	"settings": {
		"music_volume": 1.0,
		"control_type": 0
	},
	"progress": {
		"floors": {
			"floor_1": {
				"unlocked": true,
				"levels": {
					"floor_1_lvl_1": true, # default unlocked
					"floor_1_lvl_2": false,
					"floor_1_lvl_3": false
				}
			},
			"floor_2": {
				"unlocked": false,
				"levels": {
					"floor_2_lvl_1": false,
					"floor_2_lvl_2": false,
					"floor_2_lvl_3": false
				}
			},
			"floor_3": {
				"unlocked": false,
				"levels": {
					"floor_3_lvl_1": false,
					"floor_3_lvl_2": false,
					"floor_3_lvl_3": false
				}
			}
		},
		"abilities": {
			"double_jump": false,
			"attack": false,
			"dash": false
		}
	}
}

# --- Save / Load ---
func save():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load():
	if not FileAccess.file_exists(SAVE_PATH):
		save()
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var parsed = JSON.parse_string(content)
		if typeof(parsed) == TYPE_DICTIONARY:
			data = parsed
		file.close()

# --- Unlock helpers ---
func unlock_level(floor: String, level: String):
	data["progress"]["floors"][floor]["levels"][level] = true

	# Unlock next floor if the last level is cleared
	if floor == "floor_1" and level == "floor_1_lvl_3":
		unlock_floor("floor_2")
	elif floor == "floor_2" and level == "floor_2_lvl_3":
		unlock_floor("floor_3")

	save()

func unlock_floor(floor: String):
	data["progress"]["floors"][floor]["unlocked"] = true
	save()

func unlock_ability(name: String):
	data["progress"]["abilities"][name] = true
	save()

# --- Settings helpers ---
func set_setting(key: String, value):
	data["settings"][key] = value
	save()

func get_setting(key: String):
	return data["settings"].get(key, null)

# --- Query helpers ---
func is_floor_unlocked(floor: String) -> bool:
	return data["progress"]["floors"].get(floor, {}).get("unlocked", false)

func is_level_unlocked(floor: String, level: String) -> bool:
	return data["progress"]["floors"].get(floor, {}).get("levels", {}).get(level, false)
