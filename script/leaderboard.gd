extends Control

@onready var status_label: Label = $Panel/MarginContainer/VBoxContainer/status_label
@onready var scroll_container: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer
@onready var leaderboard_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer
@onready var back_button: Button = $Panel/MarginContainer/VBoxContainer/back_button

const LEADERBOARD_ENTRY = preload("res://scene/panel_container.tscn")
const MAX_VISIBLE_ENTRIES = 10

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_load_leaderboard()

func _load_leaderboard() -> void:
	# Clear existing entries
	for child in leaderboard_container.get_children():
		child.queue_free()
	
	status_label.text = "Loading leaderboard..."
	status_label.add_theme_color_override("font_color", Color.YELLOW)
	
	# Fetch leaderboard data from Supabase
	SaveManager.fetch_leaderboard_data(_on_leaderboard_data_received)

func _fetch_and_setup_entry(entry: Node, rank: int, user_id: String, time_formatted: String, avatar_url: String, username: String) -> void:
	"""Setup entry with fetched user data"""
	
	# Use the username and avatar from the database
	var display_name = username if username != "" else "Player"
	
	var entry_data = {
		"player_name": display_name,
		"time_formatted": time_formatted,
		"avatar_url": avatar_url,
		"user_id": user_id
	}
	
	entry.setup(rank, entry_data)


func _on_leaderboard_data_received(leaderboard_data: Array) -> void:
	print("Received leaderboard data: %d entries" % leaderboard_data.size())
	
	var entries_to_show = max(10, leaderboard_data.size())
	
	# Get current user info for fallback
	var current_user = Global.get_current_user()
	var current_user_id = ""
	var current_user_avatar = ""
	var current_user_name = ""
	
	if current_user.has("id"):
		current_user_id = str(current_user["id"])
		current_user_avatar = current_user.get("user_metadata", {}).get("avatar_url", "")
		current_user_name = current_user.get("email", "Player").split("@")[0]
		print("Current user detected: %s (ID: %s)" % [current_user_name, current_user_id.substr(0, 8)])
	
	for i in range(entries_to_show):
		var entry = LEADERBOARD_ENTRY.instantiate()
		leaderboard_container.add_child(entry)
		
		if i < leaderboard_data.size():
			var data = leaderboard_data[i]
			var user_id = str(data.get("user_id", ""))
			var best_time = float(data.get("best_run_time", 0.0))
			
			# Handle null values properly
			var avatar_url = data.get("avatar_url", "")
			if avatar_url == null:
				avatar_url = ""
			
			var username = data.get("username", "")
			if username == null or username == "":
				username = "Player"
			
			# IMPORTANT: If this is the current logged-in user, use their live data
			if user_id == current_user_id and current_user_id != "":
				print("Entry #%d is current user - using live profile data" % (i + 1))
				avatar_url = current_user_avatar
				username = current_user_name
				print("  Avatar URL: %s" % avatar_url.substr(0, 50))
			
			# Format time
			var minutes = int(best_time) / 60
			var seconds = int(best_time) % 60
			var milliseconds = int((best_time - int(best_time)) * 100)
			var time_formatted = "%02d:%02d.%02d" % [minutes, seconds, milliseconds]
			
			print("Setting up entry #%d: %s (Time: %s, Avatar: %s)" % [
				i + 1, 
				username, 
				time_formatted,
				"YES" if avatar_url != "" else "NO"
			])
			
			# Setup entry with all data
			_fetch_and_setup_entry(entry, i + 1, user_id, time_formatted, avatar_url, username)
		else:
			entry.setup(i + 1, {})
	
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if entries_to_show <= MAX_VISIBLE_ENTRIES else ScrollContainer.SCROLL_MODE_AUTO
	
	if leaderboard_data.size() > 0:
		status_label.text = "Top Players"
		status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		status_label.text = "No leaderboard entries yet. Complete all 9 levels to appear!"
		status_label.add_theme_color_override("font_color", Color.GRAY)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")
