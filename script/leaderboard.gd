extends Control

@onready var status_label: Label = $Panel/MarginContainer/VBoxContainer/status_label
@onready var profile_circle: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/profile_circle
@onready var player_name: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/player_name
@onready var time_label: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/time_label
@onready var back_button: Button = $Panel/MarginContainer/VBoxContainer/back_button

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_load_leaderboard()

func _load_leaderboard() -> void:
	var entry = SaveManager.get_leaderboard_entry()
	
	print("\n[Leaderboard] ===== DEBUG INFO =====")
	print("  Completed all levels: ", entry["completed_all"])
	print("  Best run time: ", entry["time"])
	print("  All level times: ", SaveManager.data.get("level_times", {}))
	print("  Level times count: ", SaveManager.data.get("level_times", {}).size())
	print("================================\n")
	
	if entry["completed_all"]:
		var total_time = entry["time"]
		var minutes = int(total_time) / 60
		var seconds = int(total_time) % 60
		var milliseconds = int((total_time - int(total_time)) * 100)
		
		player_name.text = entry["player_name"]
		time_label.text = "%02d:%02d.%02d" % [minutes, seconds, milliseconds]
		status_label.text = "Full Game Completed!"
		status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		player_name.text = "---"
		time_label.text = "00:00.00"
		status_label.text = "Complete all 9 levels to appear on the leaderboard"
		status_label.add_theme_color_override("font_color", Color.GRAY)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")
