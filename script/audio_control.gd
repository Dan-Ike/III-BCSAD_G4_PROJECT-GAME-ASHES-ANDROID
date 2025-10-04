extends HSlider

@export var audio_bus_name: String
var audio_bus_id

func _ready() -> void:
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)

	# Load saved volume if it exists
	var saved_vol = SaveManager.get_setting("music_volume")
	if saved_vol != null and audio_bus_name == "Music":
		value = saved_vol
		AudioServer.set_bus_volume_db(audio_bus_id, linear_to_db(saved_vol))
	else:
		# Default: load current bus value
		var db = AudioServer.get_bus_volume_db(audio_bus_id)
		value = db_to_linear(db)

	value_changed.connect(_on_value_changed)


func _on_value_changed(new_value: float) -> void:
	var db = linear_to_db(new_value)
	AudioServer.set_bus_volume_db(audio_bus_id, db)

	# Save if this is the music bus
	if audio_bus_name == "Music":
		SaveManager.set_setting("music_volume", new_value)
