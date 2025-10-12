extends Node

@onready var player_a := AudioStreamPlayer.new()
@onready var player_b := AudioStreamPlayer.new()

var current_song: String = ""
var active_player: AudioStreamPlayer
var inactive_player: AudioStreamPlayer

var music_library := {
	"menu": preload("res://audio/mortal-gaming-144000.mp3"),
	"level1": preload("res://audio/we-rollin-shubh-levinho-144001.mp3"),
	"level2": preload("res://audio/vikings-147827.mp3"),
	"level3": preload("res://audio/jonathan-gaming-143999.mp3"),
	"boss": preload("res://audio/victory-awaits-in-the-gaming-universe_astronaut-265184.mp3"),
	"gameover": preload("res://audio/game_defeat-_-game-over-373827.mp3")
}

@export var crossfade_time := 1.5

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  
	add_child(player_a)
	add_child(player_b)
	player_a.bus = "Music"
	player_b.bus = "Music"
	player_a.autoplay = false
	player_b.autoplay = false
	active_player = player_a
	inactive_player = player_b

func play_song(song_name: String):
	if not music_library.has(song_name):
		push_warning("Song not found: %s" % song_name)
		return
	if current_song == song_name:
		return
	var temp = active_player
	active_player = inactive_player
	inactive_player = temp
	var new_stream = music_library[song_name].duplicate()
	new_stream.set_loop(true)
	active_player.stream = new_stream
	active_player.volume_db = -80
	active_player.play()
	var tween = create_tween()
	tween.tween_property(active_player, "volume_db", 0, crossfade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(inactive_player, "volume_db", -80, crossfade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	inactive_player.stop()
	current_song = song_name

func stop_song(immediate: bool = true):
	if active_player and active_player.playing:
		if immediate:
			active_player.stop()
			current_song = ""
		else:
			var tween = create_tween()
			tween.tween_property(active_player, "volume_db", -80, crossfade_time)
			await tween.finished
			active_player.stop()
			current_song = ""

func set_volume(vol: float) -> void:
	# Convert normalized volume (0.0–1.0) into decibels
	var db = linear_to_db(clamp(vol, 0.0, 1.0))
	if active_player:
		active_player.volume_db = db
	if inactive_player:
		inactive_player.volume_db = db
