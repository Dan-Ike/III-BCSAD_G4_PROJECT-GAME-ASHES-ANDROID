extends CanvasLayer
#@onready var overlay: ColorRect = $Overlay
#@onready var center_container: CenterContainer = $CenterContainer
#@onready var title: Label = $CenterContainer/Panel/MarginContainer/VBox/Title
#@onready var floor_level: Label = $CenterContainer/Panel/MarginContainer/VBox/FloorLevel
#@onready var quote: Label = $CenterContainer/Panel/MarginContainer/VBox/Quote
#@onready var retry: Button = $CenterContainer/Panel/MarginContainer/VBox/ButtonContainer/Retry
#@onready var main_menu: Button = $CenterContainer/Panel/MarginContainer/VBox/ButtonContainer/MainMenu
#@onready var time_cleared: Label = $CenterContainer/Panel/MarginContainer/VBox/TimeCleared

#lvl completed
@onready var level_completed: Control = $level_completed
@onready var floor_level: Label = $level_completed/FloorLevel
@onready var quote: Label = $level_completed/Quote
@onready var time_cleared: Label = $level_completed/TimeCleared
@onready var main_menu: TouchScreenButton = $level_completed/Control2/main_menu
@onready var next: TouchScreenButton = $level_completed/Control3/next

#game over
@onready var game_over: Control = $game_over
@onready var floor_level_2: Label = $game_over/FloorLevel
@onready var quote_2: Label = $game_over/Quote
@onready var time_cleared_2: Label = $game_over/TimeCleared
@onready var main_menu_2: TouchScreenButton = $game_over/Control2/main_menu
@onready var retry: TouchScreenButton = $game_over/Control3/retry


#quotes for game over
var quotes = {
	"1_1": [
		"Failure is the first step to success.",
		"Even the light must flicker before it burns bright again."
	],
	"1_2": [
		"Do not fear the darkness — it teaches you to see the light.",
		"Only by losing everything do we learn what matters most."
	],
	"1_3": [
		"Every fall carves the path for your next climb.",
		"You may stumble today, but the summit still waits for you tomorrow."
	],
	"2_1": [
		"Patience is not waiting — it is enduring without losing focus.",
		"The calm mind sees victory long before it arrives."
	],
	"2_2": [
		"The wise warrior studies the map before stepping into the field.",
		"Awareness turns chaos into opportunity."
	],
	"3_1": [
		"Slow steps still conquer great distances.",
		"Steady hands build what haste will only break."
	],
	"3_2": [
		"The greatest battle is the one fought within yourself.",
		"Master your heart, and the world will follow."
	],
	"default": [
		"Sometimes falling is the only way to rise.",
		"Darkness is not the end — it's where stars are born."
	]
};
#quotes for level completed
var quotes_2 = {
	"1_1": [
		"ggs",
		"ggs"
	],
	"1_2": [
		"ggs2",
		"ggs2"
	],
	"1_3": [
		"ggs3",
		"ggs3"
	],
	"2_1": [
		"ggs4",
		"ggs4"
	],
	"2_2": [
		"ggs5",
		"ggs5"
	],
	"3_1": [
		"ggs6",
		"ggs6"
	],
	"3_2": [
		"ggs7",
		"ggs7"
	],
	"default": [
		"ggs0",
		"ggs0"
	]
};

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Hide initially
	visible = false
	level_completed.visible = false
	game_over.visible = false
	
	# Connect buttons
	retry.pressed.connect(_on_retry_pressed)
	main_menu.pressed.connect(_on_main_menu_pressed)
	main_menu_2.pressed.connect(_on_main_menu_pressed)
	next.pressed.connect(_on_next_pressed)
	

func show_game_over(floor_num: int, level_num: int, time_taken: float = 0.0, is_level_completed: bool = false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	
	print("[GameOver] Showing screen for Floor %d, Level %d, Completed: %s" % [floor_num, level_num, is_level_completed])
	
	if is_level_completed:
		# Show level completed screen
		level_completed.visible = true
		game_over.visible = false
		
		# Update labels for level completed
		floor_level.text = "Floor %d - Level %d" % [floor_num, level_num]
		
		var minutes = int(time_taken) / 60
		var seconds = int(time_taken) % 60
		var milliseconds = int((time_taken - int(time_taken)) * 100)
		time_cleared.text = "Time Cleared: %02d:%02d.%02d" % [minutes, seconds, milliseconds]
		
		# Pick a success quote
		var key: String = "%d_%d" % [floor_num, level_num]
		var pool: Array = quotes_2.get(key, quotes_2["default"])
		if pool.size() == 0:
			pool = quotes_2["default"]
		var chosen_quote: String = str(pool[rng.randi_range(0, pool.size() - 1)])
		quote.text = chosen_quote
		
		# Don't play game over music for level completion
		# Let the level handle its own transition music
	else:
		# Show game over screen
		game_over.visible = true
		level_completed.visible = false
		
		# Play game over music
		MusicManager.play_song("gameover")
		
		# Update labels for game over
		floor_level_2.text = "Floor %d - Level %d" % [floor_num, level_num]
		
		var minutes = int(time_taken) / 60
		var seconds = int(time_taken) % 60
		var milliseconds = int((time_taken - int(time_taken)) * 100)
		time_cleared_2.text = "Time Survived: %02d:%02d.%02d" % [minutes, seconds, milliseconds]
		
		# Pick a failure quote
		var key: String = "%d_%d" % [floor_num, level_num]
		var pool: Array = quotes.get(key, quotes["default"])
		if pool.size() == 0:
			pool = quotes["default"]
		var chosen_quote: String = str(pool[rng.randi_range(0, pool.size() - 1)])
		quote_2.text = chosen_quote
	
	visible = true
	get_tree().paused = true

func _on_next_pressed() -> void:
	delayed_action(0.2, func():
		#print("[GameOver] Next level pressed")
		
		MusicManager.stop_song()
		visible = false
		get_tree().paused = false
		
		# Get current floor and level from Global
		var current_floor = Global.current_floor
		var current_level = Global.current_level
		
		# Determine next level
		var next_floor = current_floor
		var next_level = current_level + 1
		
		# Check if we need to advance to next floor
		var max_levels_per_floor = 3
		if next_level > max_levels_per_floor:
			next_floor += 1
			next_level = 1
		
		# Build the scene path dynamically
		var next_scene_path = "res://scene/floor_%d_level_%d.tscn" % [next_floor, next_level]
		
		#print("[GameOver] Loading next scene: ", next_scene_path)
		
		# Load the next scene directly (no need to call advance_level since we already did it)
		get_tree().change_scene_to_file(next_scene_path)
	)

func delayed_action(delay: float, action: Callable) -> void:
	await get_tree().create_timer(delay).timeout
	action.call()

func _on_retry_pressed() -> void:
	delayed_action(0.2, func():
		#print("[GameOver] Retry pressed")
		
		# Set retry flag BEFORE reloading
		Global.set_retrying(true)
		
		# STOP game over music before reloading
		MusicManager.stop_song()
		
		# Hide the UI
		visible = false
		
		# Unpause and reload
		get_tree().paused = false
		get_tree().reload_current_scene()
	)

func _on_main_menu_pressed() -> void:
	delayed_action(0.2, func():
		#print("[GameOver] Main menu pressed")
		
		# STOP game over music
		MusicManager.stop_song()
		
		# Hide the UI
		visible = false
		
		# Unpause and go to menu
		get_tree().paused = false
		Global.reset_progress()
		
		# Main menu will handle its own music
		get_tree().change_scene_to_file("res://scene/main_menu.tscn")
	)
