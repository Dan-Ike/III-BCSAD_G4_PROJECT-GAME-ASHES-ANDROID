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

func _on_leaderboard_data_received(leaderboard_data: Array) -> void:
	print("Received leaderboard data: %d entries" % leaderboard_data.size())
	
	# Always show at least 10 slots
	var entries_to_show = max(10, leaderboard_data.size())
	
	# Create entries
	for i in range(entries_to_show):
		var entry = LEADERBOARD_ENTRY.instantiate()
		leaderboard_container.add_child(entry)
		
		if i < leaderboard_data.size():
			var data = leaderboard_data[i]
			var user_id = data.get("user_id", "")
			var best_time = float(data.get("best_run_time", 0.0))
			
			# Format time
			var minutes = int(best_time) / 60
			var seconds = int(best_time) % 60
			var milliseconds = int((best_time - int(best_time)) * 100)
			var time_formatted = "%02d:%02d.%02d" % [minutes, seconds, milliseconds]
			
			# Fetch user profile (async)
			_fetch_and_setup_entry(entry, i + 1, user_id, time_formatted)
		else:
			# Empty entry
			entry.setup(i + 1, {})
	
	# Enable/disable scrolling based on number of entries
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if entries_to_show <= MAX_VISIBLE_ENTRIES else ScrollContainer.SCROLL_MODE_AUTO
	
	# Update status
	if leaderboard_data.size() > 0:
		status_label.text = "Top Players"
		status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		status_label.text = "No leaderboard entries yet. Complete all 9 levels to appear!"
		status_label.add_theme_color_override("font_color", Color.GRAY)

func _fetch_and_setup_entry(entry: Node, rank: int, user_id: String, time_formatted: String) -> void:
	"""Fetch user profile and setup entry"""
	
	# Check if this is the current logged-in user
	var current_user = Global.get_current_user()
	var is_current_user = (current_user.has("id") and str(current_user["id"]) == user_id)
	
	var username = "Player"
	var avatar_url = ""
	
	if is_current_user:
		# Use local cached data for current user
		username = current_user.get("email", "Player").split("@")[0]
		avatar_url = current_user.get("user_metadata", {}).get("avatar_url", "")
	else:
		# For other users, use generic name (we'll add user table fetch later)
		username = "Player #" + user_id.substr(0, 8)
	
	var entry_data = {
		"player_name": username,
		"time_formatted": time_formatted,
		"avatar_url": avatar_url,
		"user_id": user_id
	}
	entry.setup(rank, entry_data)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")
