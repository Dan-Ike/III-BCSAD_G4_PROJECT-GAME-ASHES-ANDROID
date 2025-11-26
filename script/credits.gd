extends CanvasLayer

@onready var video_player: VideoStreamPlayer = $Control/VideoStreamPlayer

func _ready() -> void:
	MusicManager.stop_song()
	video_player.finished.connect(_on_video_finished)

func _on_video_finished() -> void:
	MusicManager.play_song("menu")
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")
