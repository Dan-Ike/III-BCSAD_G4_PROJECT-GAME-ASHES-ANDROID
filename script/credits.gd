extends CanvasLayer
@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer

func _ready() -> void:
	MusicManager.stop_song()
	video_player.finished.connect(_on_video_finished)
	
	video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	video_player.size = get_viewport().get_visible_rect().size

func _process(delta: float) -> void:
	pass

func _on_video_finished() -> void:
	MusicManager.play_song("menu")
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")
