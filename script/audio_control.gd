extends HSlider

@export var audio_bus_name: String

var audio_bus_id

func _ready() -> void:
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)
	
	# Determine which setting key to use based on bus name
	var setting_key = ""
	if audio_bus_name == "Music":
		setting_key = "music_volume"
	elif audio_bus_name == "SFX" or audio_bus_name == "sfx":
		setting_key = "sfx_volume"
	
	# Load saved volume or use current bus volume
	var saved_vol = SaveManager.get_setting(setting_key)
	if saved_vol != null:
		value = saved_vol
		AudioServer.set_bus_volume_db(audio_bus_id, linear_to_db(saved_vol))
	else:
		var db = AudioServer.get_bus_volume_db(audio_bus_id)
		value = db_to_linear(db)
	
	value_changed.connect(_on_value_changed)

func _on_value_changed(new_value: float) -> void:
	var db = linear_to_db(new_value)
	AudioServer.set_bus_volume_db(audio_bus_id, db)
	
	# Save based on bus name
	if audio_bus_name == "Music":
		SaveManager.set_setting("music_volume", new_value)
	elif audio_bus_name == "SFX" or audio_bus_name == "sfx":
		SaveManager.set_setting("sfx_volume", new_value)
