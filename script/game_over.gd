extends CanvasLayer
@onready var overlay: ColorRect = $Overlay
@onready var center_container: CenterContainer = $CenterContainer
@onready var title: Label = $CenterContainer/Panel/MarginContainer/VBox/Title
@onready var floor_level: Label = $CenterContainer/Panel/MarginContainer/VBox/FloorLevel
@onready var quote: Label = $CenterContainer/Panel/MarginContainer/VBox/Quote
@onready var retry: Button = $CenterContainer/Panel/MarginContainer/VBox/ButtonContainer/Retry
@onready var main_menu: Button = $CenterContainer/Panel/MarginContainer/VBox/ButtonContainer/MainMenu

# Quotes organized by floor/level
var quotes: Dictionary = {
	"1_1": [
		"Failure is the first step to success.",
		"Even the light must flicker before it burns bright again."
	],
	"1_2": [
		"Do not fear the darkness — it teaches you to see the light.",
		"Only by losing everything do we learn what matters most."
	],
	"1_3": [
		"git gud",
		"ah nahulog"
	],
	"2_1": [
		"dilim ba",
		"sakit"
	],
	"2_2": [
		"ubos ba pasensya",
		"inner peace"
	],
	"3_1": [
		"weeak",
		"hina."
	],
	"3_2": [
		"paayos",
		"fsdfds"
	],
	"default": [
		"Sometimes falling is the only way to rise.",
		"Darkness is not the end — it's where stars are born."
	]
}

func _ready() -> void:
	# CRITICAL: Process even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Hide initially
	visible = false
	
	# Connect buttons
	retry.pressed.connect(_on_retry_pressed)
	main_menu.pressed.connect(_on_main_menu_pressed)
	
	# DON'T play music here - wait until show_game_over is called

func show_game_over(floor_num: int, level_num: int) -> void:
	# Seed RNG for varied quotes
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	
	print("[GameOver] Showing game over for Floor %d, Level %d" % [floor_num, level_num])
	
	# Play game over music ONLY when actually showing game over
	MusicManager.play_song("gameover")
	
	# Update floor/level label
	floor_level.text = "Floor %d - Level %d" % [floor_num, level_num]
	
	# Pick a quote for this floor/level
	var key: String = "%d_%d" % [floor_num, level_num]
	print("[GameOver] Looking for quotes with key: ", key)
	
	var pool: Array = quotes.get(key, quotes["default"])
	print("[GameOver] Found %d quotes for this level" % pool.size())
	
	# Safe guard if pool is empty
	if pool.size() == 0:
		pool = quotes["default"]
	
	var chosen_index: int = rng.randi_range(0, pool.size() - 1)
	var chosen_quote: String = str(pool[chosen_index])
	quote.text = chosen_quote
	print("[GameOver] Selected quote: ", chosen_quote)
	
	# Make visible
	visible = true
	
	# Fade in overlay
	if overlay:
		overlay.modulate.a = 0.0
		var tween_overlay = create_tween()
		tween_overlay.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween_overlay.tween_property(overlay, "modulate:a", 1.0, 0.3)
	
	# Fade in center container
	if center_container:
		center_container.modulate.a = 0.0
		var tween_center = create_tween()
		tween_center.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween_center.tween_property(center_container, "modulate:a", 1.0, 0.5)
	
	# Pause the game
	get_tree().paused = true

func _on_retry_pressed() -> void:
	print("[GameOver] Retry pressed")
	
	# Set retry flag BEFORE reloading
	Global.set_retrying(true)
	
	# STOP game over music before reloading
	MusicManager.stop_song()
	
	# Hide the UI
	visible = false
	
	# Unpause and reload
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	print("[GameOver] Main menu pressed")
	
	# STOP game over music
	MusicManager.stop_music()
	
	# Hide the UI
	visible = false
	
	# Unpause and go to menu
	get_tree().paused = false
	Global.reset_progress()
	
	# Main menu will handle its own music
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")
