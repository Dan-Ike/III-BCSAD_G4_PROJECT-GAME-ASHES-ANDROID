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

var level_titles = {
	"1_1": "The Molten Rift",
	"1_2": "Spined Passage",
	"1_3": "The Ascending Crucible",
	"2_1": "The Ember Trial",
	"2_2": "Trial of Emberlight",
	"2_3": "The Maze of Shadows",
	"3_1": "The Midnight Hunt",
	"3_2": "The Warlock's Verdant Siege",
	"3_3": "The Memory That Hunts You"
}

#quotes for game over
var quotes = {
	"1_1": [
		"The heat of old regret melted the stone beneath you."
	],
	"1_2": [
		"You bled out on the jagged points of self-punishment."
	],
	"1_3": [
		"The intensity  of your failure rose up to claim you."
	],
	"2_1": [
		"Trapped by the gloom, you surrendered to the silence of despair."
	],
	"2_2": [
		"One misstep broke the sacred sequence, and the darkness returned."
	],
	"2_3": [
		"Your inner light dimmed until you were swallowed by the maze."
	],
	"3_1": [
		"The shadows devoured your will, leaving only cold emptiness."
	],
	"3_2": [
		"All that opposed him was reduced to smoke and cunder"
	],
	"3_3": [
		"Your reflection was stronger. You are chained to your history"
	],
	"default": [
		"Sometimes falling is the only way to rise.",
		"Darkness is not the end — it's where stars are born."
	]
};
#quotes for level completed
var quotes_2 = {
	"1_1": [
		"You leaped across the consuming fire of your past."
	],
	"1_2": [
		"The passage demanded perfection, and you passed without scar."
	],
	"1_3": [
		"Against the melting world, your will ascended."
	],
	"2_1": [
		"Breaking the silence, you called forth the light from the deep."
	],
	"2_2": [
		"you deciphered the dark heart and restored the true pattern of flame."
	],
	"2_3": [
		"The labyrinth is complete. Your faint flame guides the exit."
	],
	"3_1": [
		"You proved the light in you is more dangerous than the dark."
	],
	"3_2": [
		"The forbidden spell is broken. The verdant life endures."
	],
	"3_3": [
		"The phantom of who you were is gone. You move forward, unburdened"
	],
	"default": [
		"There's only one way to go if you're at the bottom and that's up."
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
		var title_key = "%d_%d" % [floor_num, level_num]
		var level_title = level_titles.get(title_key, "Unknown Level")
		floor_level.text = "Floor %d - Level %d\n\"%s\"" % [floor_num, level_num, level_title]
		
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
		var title_key = "%d_%d" % [floor_num, level_num]
		var level_title = level_titles.get(title_key, "Unknown Level")
		floor_level_2.text = "Floor %d - Level %d\n\"%s\"" % [floor_num, level_num, level_title]
		
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
		MusicManager.stop_song()
		visible = false
		get_tree().paused = false
		
		# Get current floor and level from Global
		var current_floor = Global.current_floor
		var current_level = Global.current_level
		
		# If boss level (3-3), go to main menu instead of next level
		if current_floor == 3 and current_level == 3:
			Global.reset_progress()
			get_tree().change_scene_to_file("res://scene/main_menu.tscn")
			return
		
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
		
		# Load the next scene
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
