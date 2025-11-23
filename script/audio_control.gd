extends HSlider
@export var audio_bus_name: String
@export var grabber_size: Vector2 = Vector2(30, 30)  # Adjust size here
@export var grabber_color: Color = Color("#FF4500")
@export var grabber_pressed_color: Color = Color("#000000")

var audio_bus_id
var custom_theme: Theme

func _ready() -> void:
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)
	
	# Create custom theme
	_setup_custom_theme()
	
	var setting_key = ""
	if audio_bus_name == "Music":
		setting_key = "music_volume"
	elif audio_bus_name == "SFX" or audio_bus_name == "sfx":
		setting_key = "sfx_volume"
	
	var saved_vol = SaveManager.get_setting(setting_key)
	if saved_vol != null:
		value = saved_vol
		AudioServer.set_bus_volume_db(audio_bus_id, linear_to_db(saved_vol))
	else:
		var db = AudioServer.get_bus_volume_db(audio_bus_id)
		value = db_to_linear(db)
	
	value_changed.connect(_on_value_changed)

func _setup_custom_theme() -> void:
	custom_theme = Theme.new()
	
	# Create grabber textures
	var grabber_normal = _create_circle_texture(grabber_size, grabber_color)
	var grabber_highlight = _create_circle_texture(grabber_size, grabber_color.lightened(0.2))
	
	# Apply textures to theme
	custom_theme.set_icon("grabber", "HSlider", grabber_normal)
	custom_theme.set_icon("grabber_highlight", "HSlider", grabber_highlight)
	custom_theme.set_icon("grabber_disabled", "HSlider", grabber_normal)
	
	# Create slider background with rounded corners (black background)
	var slider_style = StyleBoxFlat.new()
	slider_style.bg_color = Color("#000000")  # Black background
	slider_style.corner_radius_top_left = 10
	slider_style.corner_radius_top_right = 10
	slider_style.corner_radius_bottom_left = 10
	slider_style.corner_radius_bottom_right = 10
	slider_style.expand_margin_top = 5
	slider_style.expand_margin_bottom = 5
	custom_theme.set_stylebox("slider", "HSlider", slider_style)
	
	# Create grabber area with rounded corners (orange filled part)
	var grabber_area_style = StyleBoxFlat.new()
	grabber_area_style.bg_color = grabber_color  # Orange color (same as grabber)
	grabber_area_style.corner_radius_top_left = 10
	grabber_area_style.corner_radius_top_right = 10
	grabber_area_style.corner_radius_bottom_left = 10
	grabber_area_style.corner_radius_bottom_right = 10
	grabber_area_style.expand_margin_top = 5
	grabber_area_style.expand_margin_bottom = 5
	custom_theme.set_stylebox("grabber_area", "HSlider", grabber_area_style)
	
	# Create highlighted grabber area (orange when pressed)
	var grabber_area_highlight_style = StyleBoxFlat.new()
	grabber_area_highlight_style.bg_color = grabber_color  # Keep orange when pressed
	grabber_area_highlight_style.corner_radius_top_left = 10
	grabber_area_highlight_style.corner_radius_top_right = 10
	grabber_area_highlight_style.corner_radius_bottom_left = 10
	grabber_area_highlight_style.corner_radius_bottom_right = 10
	grabber_area_highlight_style.expand_margin_top = 5
	grabber_area_highlight_style.expand_margin_bottom = 5
	custom_theme.set_stylebox("grabber_area_highlight", "HSlider", grabber_area_highlight_style)
	
	self.theme = custom_theme

func _create_circle_texture(size: Vector2, color: Color) -> ImageTexture:
	var img = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	
	var center = size / 2
	var radius = min(size.x, size.y) / 2
	
	for x in range(int(size.x)):
		for y in range(int(size.y)):
			var distance = Vector2(x, y).distance_to(center)
			if distance <= radius:
				img.set_pixel(x, y, color)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	
	return ImageTexture.create_from_image(img)

#func _gui_input(event: InputEvent) -> void:
#	if event is InputEventMouseButton:
#		if event.pressed:
#			# Create pressed grabber
#			var grabber_pressed = _create_circle_texture(grabber_size, grabber_pressed_color)
#			custom_theme.set_icon("grabber_highlight", "HSlider", grabber_pressed)
#		else:
#			# Restore normal grabber
#			var grabber_normal = _create_circle_texture(grabber_size, grabber_color)
#			custom_theme.set_icon("grabber_highlight", "HSlider", grabber_normal)

func _on_value_changed(new_value: float) -> void:
	var db = linear_to_db(new_value)
	AudioServer.set_bus_volume_db(audio_bus_id, db)
	
	if audio_bus_name == "Music":
		SaveManager.set_setting("music_volume", new_value)
	elif audio_bus_name == "SFX" or audio_bus_name == "sfx":
		SaveManager.set_setting("sfx_volume", new_value)
