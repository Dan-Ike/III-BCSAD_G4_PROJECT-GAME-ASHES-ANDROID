extends PanelContainer

@onready var rank_label: Label = $MarginContainer/HBoxContainer/Label
@onready var profile_pic: TextureRect = $MarginContainer/HBoxContainer/TextureRect
@onready var player_name: Label = $MarginContainer/HBoxContainer/Label2
@onready var time_label: Label = $MarginContainer/HBoxContainer/Label3

var entry_data: Dictionary = {}
const PROFILE_IMAGE_CACHE_DIR = "user://profile_cache/"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Create cache directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(PROFILE_IMAGE_CACHE_DIR):
		DirAccess.make_dir_absolute(PROFILE_IMAGE_CACHE_DIR)
	
	# Set default image
	_set_default_image()
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.4, 0.4)
	add_theme_stylebox_override("panel", style)

func _set_default_image() -> void:
	"""Set the default placeholder image"""
	profile_pic.texture = load("res://art/pause (1).png")
	profile_pic.custom_minimum_size = Vector2(32, 32)
	profile_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	profile_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func setup(rank: int, data: Dictionary) -> void:
	entry_data = data
	rank_label.text = "#%d" % rank
	
	if data.is_empty() or data.get("player_name", "") == "":
		# Empty slot - show blanks
		player_name.text = "___________"
		time_label.text = "__:__.__"
		profile_pic.modulate = Color(0.3, 0.3, 0.3)
		_set_default_image()
	else:
		# Filled slot - show real data
		player_name.text = data["player_name"]
		time_label.text = data["time_formatted"]
		profile_pic.modulate = Color.WHITE
		
		# Load profile picture
		var avatar_url = data.get("avatar_url", "")
		print("PanelContainer setup - Rank: #%d, Name: %s, Avatar URL length: %d" % [
			rank, 
			data["player_name"], 
			avatar_url.length()
		])
		
		if avatar_url != "" and avatar_url != "null":
			print("  Loading avatar from: %s" % avatar_url.substr(0, 50))
			_load_profile_picture(avatar_url, data.get("user_id", ""))
		else:
			print("  No avatar URL - using default image")
			_set_default_image()


func _load_profile_picture(avatar_url: String, user_id: String) -> void:
	"""Load profile picture from cache or download it"""
	if avatar_url == "" or avatar_url == "null":
		print("  Invalid avatar URL, using default")
		_set_default_image()
		return
	
	var cache_path = PROFILE_IMAGE_CACHE_DIR + user_id + ".png"
	
	# Try to load from cache first
	if FileAccess.file_exists(cache_path):
		print("  Found cached image at: %s" % cache_path)
		var img = Image.new()
		var err = img.load(cache_path)
		if err == OK:
			profile_pic.texture = ImageTexture.create_from_image(img)
			print("  ✓ Loaded from cache successfully")
			return
		else:
			print("  ✗ Cache load failed: %d" % err)
	else:
		print("  No cache found, downloading...")
	
	# Download if not in cache
	_download_profile_picture(avatar_url, cache_path)


func _download_profile_picture(avatar_url: String, cache_path: String) -> void:
	"""Download profile picture from URL"""
	if avatar_url == "" or avatar_url == "null":
		print("  Cannot download - invalid URL")
		_set_default_image()
		return
	
	print("  Starting download from: %s" % avatar_url)
	
	var http = HTTPRequest.new()
	add_child(http)
	
	# Add timeout
	http.timeout = 10.0
	
	http.request_completed.connect(func(result, response_code, headers, body):
		print("  Download complete - Result: %d, Code: %d, Size: %d bytes" % [result, response_code, body.size()])
		
		if response_code == 200 and body.size() > 0:
			var img = Image.new()
			var load_result = OK
			
			# Try different image formats
			if avatar_url.ends_with(".jpg") or avatar_url.ends_with(".jpeg"):
				load_result = img.load_jpg_from_buffer(body)
				print("  Tried loading as JPG: %d" % load_result)
			elif avatar_url.ends_with(".png"):
				load_result = img.load_png_from_buffer(body)
				print("  Tried loading as PNG: %d" % load_result)
			else:
				# Try both
				load_result = img.load_jpg_from_buffer(body)
				print("  Tried loading as JPG: %d" % load_result)
				if load_result != OK:
					load_result = img.load_png_from_buffer(body)
					print("  Tried loading as PNG: %d" % load_result)
			
			if load_result == OK:
				# Resize to save space
				img.resize(64, 64, Image.INTERPOLATE_LANCZOS)
				
				# Save to cache
				var save_result = img.save_png(cache_path)
				if save_result == OK:
					print("  ✓ Saved to cache: %s" % cache_path)
				else:
					print("  ✗ Failed to save cache: %d" % save_result)
				
				# Display
				profile_pic.texture = ImageTexture.create_from_image(img)
				print("  ✓ Image displayed successfully")
			else:
				print("  ✗ Failed to load image from buffer")
				_set_default_image()
		else:
			print("  ✗ Download failed - Code: %d" % response_code)
			_set_default_image()
		
		http.queue_free()
	)
	
	var err = http.request(avatar_url)
	if err != OK:
		print("  ✗ HTTP request failed to start: %d" % err)
		_set_default_image()
		http.queue_free()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_clicked()

func _on_clicked() -> void:
	if not entry_data.is_empty() and entry_data.get("player_name", "") != "":
		var popup_text = "Player: %s\nTime: %s" % [entry_data["player_name"], entry_data["time_formatted"]]
		
		var dialog = AcceptDialog.new()
		dialog.dialog_text = popup_text
		dialog.title = "Leaderboard Entry"
		get_tree().root.add_child(dialog)
		dialog.popup_centered()
		dialog.confirmed.connect(dialog.queue_free)

func _mouse_enter() -> void:
	if not entry_data.is_empty() and entry_data.get("player_name", "") != "":
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.3, 0.4, 0.7)
		style.border_width_bottom = 1
		style.border_color = Color(0.6, 0.6, 0.8)
		add_theme_stylebox_override("panel", style)

func _mouse_exit() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.4, 0.4)
	add_theme_stylebox_override("panel", style)
