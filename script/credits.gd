extends CanvasLayer

@onready var video_player: VideoStreamPlayer = $TextureRect/VideoStreamPlayer
@onready var texture_rect: TextureRect = $TextureRect
@onready var btn_back: TouchScreenButton = $buttons/Control4/back

var transitioning: bool = false

func _ready():
	MusicManager.stop_song()
	# Assign video texture to display video inside the TextureRect
	texture_rect.texture = video_player.get_video_texture()
	# Start the video
	video_player.finished.connect(_on_video_finished)
	video_player.play()
	# Initially hide the back button
	btn_back.visible = false
	# Wait 3 seconds, then show the back button and connect its signal
	_show_back_button_delayed()

func _input(event: InputEvent) -> void:
	if transitioning:
		get_tree().root.set_input_as_handled()
		return
	
	# Only allow back button clicks after it's visible
	if event is InputEventMouseButton and event.pressed:
		if not btn_back.visible:
			get_tree().root.set_input_as_handled()

func _show_back_button_delayed() -> void:
	await get_tree().create_timer(3).timeout
	btn_back.visible = true
	btn_back.pressed.connect(_on_back_pressed)

func _on_video_finished() -> void:
	if transitioning:
		return
	transitioning = true
	MusicManager.play_song("menu")
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")

func _on_back_pressed() -> void:
	if transitioning:
		return
	transitioning = true
	print("Back pressed!")
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")
