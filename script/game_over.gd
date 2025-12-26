extends CanvasLayer
#@onready var overlay: ColorRect = $Overlay
#@onready var center_container: CenterContainer = $CenterContainer
#@onready var title: Label = $CenterContainer/Panel/MarginContainer/VBox/Title
#@onready var floor_level: Label = $CenterContainer/Panel/MarginContainer/VBox/FloorLevel
#@onready var quote: Label = $CenterContainer/Panel/MarginContainer/VBox/Quote
#@onready var retry: Button = $CenterContainer/Panel/MarginContainer/VBox/ButtonContainer/Retry
#@onready var main_menu: Button = $CenterContainer/Panel/MarginContainer/VBox/ButtonContainer/MainMenu
#@onready var time_cleared: Label = $CenterContainer/Panel/MarginContainer/VBox/TimeCleared

# Preload cutscene scenes
var good_ending_scene = preload("res://scene/good_ending.tscn")
var bad_ending_scene = preload("res://scene/bad_ending.tscn")

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

@onready var game_over_2: Control = $game_over2
@onready var floor_level_3: Label = $game_over2/FloorLevel
@onready var quote_3: Label = $game_over2/Quote
@onready var time_cleared_3: Label = $game_over2/TimeCleared
@onready var main_menu_3: TouchScreenButton = $game_over2/Control2/main_menu
@onready var next_2: TouchScreenButton = $game_over2/Control3/next

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

var is_showing: bool = false  # Prevent double-instantiation

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Hide initially
	visible = false
	level_completed.visible = false
	game_over.visible = false
	game_over_2.visible = false
	
	# Connect buttons
	retry.pressed.connect(_on_retry_pressed)
	main_menu.pressed.connect(_on_main_menu_pressed)
	main_menu_2.pressed.connect(_on_main_menu_pressed)
	main_menu_3.pressed.connect(_on_main_menu_3_pressed)
	next.pressed.connect(_on_next_pressed)
	next_2.pressed.connect(_on_next_2_pressed)

func show_game_over(floor_num: int, level_num: int, time_taken: float = 0.0, is_level_completed: bool = false) -> void:
	# CRITICAL FIX: More lenient double-call protection
	if Global.game_over_active:
		print("[GameOver] Another game over is already showing, waiting...")
		await get_tree().create_timer(0.1).timeout
		# Try again after short delay
		if Global.game_over_active:
			print("[GameOver] Still blocked, destroying duplicate")
			queue_free()
			return
	
	Global.game_over_active = true
	is_showing = true
	
	# Ensure we're in the tree before proceeding
	if not is_inside_tree():
		print("[GameOver] ERROR: Not in scene tree!")
		Global.game_over_active = false
		return
	
	# Wait one frame to ensure scene is fully ready
	await get_tree().process_frame
	
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	
	print("[GameOver] Showing screen for Floor %d, Level %d, Completed: %s" % [floor_num, level_num, is_level_completed])
	
	# Check if this is the boss level (3-3)
	var is_boss_level = (floor_num == 3 and level_num == 3)
	
	if is_level_completed:
		# Show level completed screen
		level_completed.visible = true
		game_over.visible = false
		game_over_2.visible = false
		SaveManager.save_level_time(floor_num, level_num, time_taken)
		print("[GameOver] Called save_level_time with Floor: %d, Level: %d, Time: %.2f" % [floor_num, level_num, time_taken])
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
		
	else:
		# Show appropriate game over screen
		if is_boss_level:
			# Check if bad ending cutscene will play
			var cutscene_pref = SaveManager.get_setting("cutscene_preference")
			if cutscene_pref == null:
				cutscene_pref = "play_once"
			
			var will_play_cutscene = false
			if cutscene_pref == "always":
				will_play_cutscene = true
			elif cutscene_pref == "play_once":
				will_play_cutscene = not SaveManager.has_watched_cutscene("floor_3_level_3_bad_ending")
			
			if will_play_cutscene:
				# Show game_over_2 (with main_menu_3 and next_2 buttons)
				game_over_2.visible = true
				game_over.visible = false
				level_completed.visible = false
				
				# Update labels for game over 2
				var title_key = "%d_%d" % [floor_num, level_num]
				var level_title = level_titles.get(title_key, "Unknown Level")
				floor_level_3.text = "Floor %d - Level %d\n\"%s\"" % [floor_num, level_num, level_title]
				
				var minutes = int(time_taken) / 60
				var seconds = int(time_taken) % 60
				var milliseconds = int((time_taken - int(time_taken)) * 100)
				time_cleared_3.text = "Time Survived: %02d:%02d.%02d" % [minutes, seconds, milliseconds]
				
				# Pick a failure quote
				var key: String = "%d_%d" % [floor_num, level_num]
				var pool: Array = quotes.get(key, quotes["default"])
				if pool.size() == 0:
					pool = quotes["default"]
				var chosen_quote: String = str(pool[rng.randi_range(0, pool.size() - 1)])
				quote_3.text = chosen_quote
			else:
				# Show regular game_over (with main_menu_2 and retry buttons)
				game_over.visible = true
				game_over_2.visible = false
				level_completed.visible = false
				
				# Update labels for regular game over
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
		else:
			# Use regular game_over for non-boss levels
			game_over.visible = true
			game_over_2.visible = false
			level_completed.visible = false
			
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
		
		# Play game over music
		MusicManager.play_song("gameover")
	
	# Make visible and pause AFTER everything is set up
	visible = true
	
	# Wait one more frame before pausing
	await get_tree().process_frame
	get_tree().paused = true
	
	print("[GameOver] Screen now visible and game paused")

func _on_next_pressed() -> void:
	delayed_action(0.2, func():
		# Check if still in tree
		if not is_inside_tree():
			return
			
		# Get current floor and level from Global
		var current_floor = Global.current_floor
		var current_level = Global.current_level
		
		# If boss level (3-3), play good ending cutscene then go to credits
		# If boss level (3-3), play good ending cutscene then go to credits
		if current_floor == 3 and current_level == 3:
			# Hide game over UI
			visible = false
			level_completed.visible = false
			
			# UNPAUSE THE GAME
			get_tree().paused = false
			
			# Check if we should play the cutscene
			var cutscene_pref = SaveManager.get_setting("cutscene_preference")
			if cutscene_pref == null:
				cutscene_pref = "play_once"
			
			var should_play = false
			if cutscene_pref == "always":
				should_play = true
			elif cutscene_pref == "play_once":
				should_play = not SaveManager.has_watched_cutscene("floor_3_level_3_good_ending")
			
			if should_play:
				MusicManager.stop_song()
				
				# Instance the cutscene
				var good_ending = good_ending_scene.instantiate()
				get_tree().root.add_child(good_ending)
				
				good_ending.visible = true
				good_ending.start_cutscene("floor_3_level_3_good_ending")
				await good_ending.cutscene_finished
				# Cutscene handles going to credits
				return
			
			# If no cutscene played, go to credits directly
			if is_inside_tree():
				MusicManager.stop_song()
				Global.reset_progress()
				get_tree().change_scene_to_file("res://scene/credits.tscn")
			return
		# For non-boss levels, proceed to next level normally
		if not is_inside_tree():
			return
		
		visible = false
		get_tree().paused = false
		MusicManager.stop_song()
		
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
		Global.game_over_active = false
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

func _disable_final_buttons() -> void:
	"""Disables both buttons on the game_over_2 screen to prevent double-press."""
	# 🛑 FIX: Use mouse_filter to block input on TouchScreenButtons
	if is_instance_valid(next_2):
		# Block all mouse/touch input events from reaching this button
		next_2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(main_menu_3):
		main_menu_3.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_next_2_pressed() -> void:
	"""Handles next_2 button press - plays bad ending cutscene for boss level"""
	#_disable_final_buttons()
	delayed_action(0.2, func():
		Global.game_over_active = false
		# Check if still in tree
		if not is_inside_tree():
			return
		
		# Hide game over UI
		visible = false
		game_over_2.visible = false
		
		# UNPAUSE THE GAME
		get_tree().paused = false
		
		# Check if we should play the cutscene
		var cutscene_pref = SaveManager.get_setting("cutscene_preference")
		if cutscene_pref == null:
			cutscene_pref = "play_once"
		
		var should_play = false
		if cutscene_pref == "always":
			should_play = true
		elif cutscene_pref == "play_once":
			should_play = not SaveManager.has_watched_cutscene("floor_3_level_3_bad_ending")
		
		if should_play:
			MusicManager.stop_song()
			
			# Instance the cutscene
			var bad_ending = bad_ending_scene.instantiate()
			get_tree().root.add_child(bad_ending)
			
			bad_ending.visible = true
			bad_ending.start_cutscene("floor_3_level_3_bad_ending")
			await bad_ending.cutscene_finished
			# Cutscene handles scene change
			return
		
		# If no cutscene, go to main menu directly
		if is_inside_tree():
			MusicManager.stop_song()
			Global.reset_progress()
			get_tree().change_scene_to_file("res://scene/main_menu.tscn")
	)

func _on_main_menu_3_pressed() -> void:
	"""Handles main_menu_3 button press - goes directly to main menu"""
	#_disable_final_buttons()
	delayed_action(0.2, func():
		Global.game_over_active = false
		if not is_inside_tree():
			return
		
		visible = false
		game_over_2.visible = false
		get_tree().paused = false
		MusicManager.stop_song()
		Global.reset_progress()
		get_tree().change_scene_to_file("res://scene/main_menu.tscn")
	)

func _on_main_menu_pressed() -> void:
	delayed_action(0.2, func():
		Global.game_over_active = false
		# Get current floor and level from Global
		var current_floor = Global.current_floor
		var current_level = Global.current_level
		
		# If boss level (3-3), check if we should play good ending cutscene
		# If boss level (3-3), check if we should play good ending cutscene
		if current_floor == 3 and current_level == 3:
			# Hide game over UI
			visible = false
			level_completed.visible = false
			
			# UNPAUSE THE GAME
			get_tree().paused = false
			
			# Check if we should play the cutscene
			var cutscene_pref = SaveManager.get_setting("cutscene_preference")
			if cutscene_pref == null:
				cutscene_pref = "play_once"
			
			var should_play = false
			if cutscene_pref == "always":
				should_play = true
			elif cutscene_pref == "play_once":
				should_play = not SaveManager.has_watched_cutscene("floor_3_level_3_good_ending")
			
			if should_play:
				MusicManager.stop_song()
				
				# Instance the cutscene
				var good_ending = good_ending_scene.instantiate()
				get_tree().root.add_child(good_ending)
				
				good_ending.visible = true
				good_ending.start_cutscene("floor_3_level_3_good_ending")
				await good_ending.cutscene_finished
			
			# After cutscene, go to main menu
			MusicManager.stop_song()
			Global.reset_progress()
			get_tree().change_scene_to_file("res://scene/main_menu.tscn")
			return
		# For non-boss levels, go directly to main menu
		visible = false
		MusicManager.stop_song()
		get_tree().paused = false
		Global.reset_progress()
		get_tree().change_scene_to_file("res://scene/main_menu.tscn")
	)
