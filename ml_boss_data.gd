extends Node

const SAVE_PATH = "user://ml_boss_data.json"

var learning_data = {
	"encounters": 0,
	"player_deaths": 0,
	"boss_deaths": 0,
	"successful_attack_patterns": {},
	"player_behavior_patterns": {
		"avg_distance_kept": 150.0,
		"dodge_frequency": 0.5,
		"aggression_level": 0.5,
		"jump_frequency": 0.3,
		"retreat_frequency": 0.2
	},
	"attack_success_rates": {
		"vertical_slash": 0.5,
		"down_slash": 0.5,
		"dash_attack": 0.5,
		"special_dash": 0.5,
		"jump_up_attack": 0.5,
		"jump_down_attack": 0.5
	},
	"adaptation_level": 1.0,
	"speed_multiplier": 1.0,
	"attack_speed_multiplier": 1.0
}

func _ready():
	load_data()

# Preset difficulty modes
func set_expert_mode():
	learning_data = {
		"encounters": 50,
		"player_deaths": 15,
		"boss_deaths": 5,
		"successful_attack_patterns": {},
		"player_behavior_patterns": {
			"avg_distance_kept": 180.0,
			"dodge_frequency": 0.75,
			"aggression_level": 0.65,
			"jump_frequency": 0.55,
			"retreat_frequency": 0.35
		},
		"attack_success_rates": {
			"vertical_slash": 0.70,
			"down_slash": 0.75,
			"dash_attack": 0.70,
			"special_dash": 0.80,
			"jump_up_attack": 0.65,
			"jump_down_attack": 0.70
		},
		"adaptation_level": 1.3,
		"speed_multiplier": 1.2,
		"attack_speed_multiplier": 1.15
	}
	save_data()
	print("[ML Boss] Set to EXPERT mode!")

func set_godlike_mode():
	learning_data = {
		"encounters": 100,
		"player_deaths": 40,
		"boss_deaths": 2,
		"successful_attack_patterns": {},
		"player_behavior_patterns": {
			"avg_distance_kept": 200.0,
			"dodge_frequency": 0.90,
			"aggression_level": 0.85,
			"jump_frequency": 0.70,
			"retreat_frequency": 0.50
		},
		"attack_success_rates": {
			"vertical_slash": 0.90,
			"down_slash": 0.92,
			"dash_attack": 0.88,
			"special_dash": 0.95,
			"jump_up_attack": 0.85,
			"jump_down_attack": 0.90
		},
		"adaptation_level": 1.8,
		"speed_multiplier": 1.5,
		"attack_speed_multiplier": 1.4
	}
	save_data()
	print("[ML Boss] Set to GODLIKE mode!")

func reset_adaptation():
	learning_data.adaptation_level = 1.0
	learning_data.speed_multiplier = 1.0
	learning_data.attack_speed_multiplier = 1.0
	learning_data.player_deaths = 0
	learning_data.boss_deaths = 0
	save_data()
	print("[ML Boss] Reset adaptation level to 1.0")

func load_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			learning_data = json.data
		file.close()
		print("[ML Boss] Loaded learning data: ", learning_data)
	else:
		print("[ML Boss] No save file found, using defaults")

func save_data():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(learning_data, "\t"))
	file.close()

func record_encounter():
	learning_data.encounters += 1
	save_data()

func record_player_death():
	learning_data.player_deaths += 1
	# Gradually increase adaptation
	learning_data.adaptation_level = min(2.0, 1.0 + (learning_data.player_deaths * 0.05))
	learning_data.speed_multiplier = min(1.5, 1.0 + (learning_data.player_deaths * 0.02))
	learning_data.attack_speed_multiplier = min(1.4, 1.0 + (learning_data.player_deaths * 0.015))
	save_data()
	print("[ML Boss] Player died! Adaptation: %.2f, Speed: %.2f" % [learning_data.adaptation_level, learning_data.speed_multiplier])

func record_boss_death():
	learning_data.boss_deaths += 1
	# Boss learns from losses but gets more cautious
	learning_data.adaptation_level = min(2.0, learning_data.adaptation_level + 0.1)
	learning_data.player_behavior_patterns.retreat_frequency = min(0.8, learning_data.player_behavior_patterns.retreat_frequency + 0.05)
	save_data()
	print("[ML Boss] Boss died! Learning from mistakes. Retreats: %.2f" % [learning_data.player_behavior_patterns.retreat_frequency])

func record_attack_result(attack_type: String, hit: bool):
	if attack_type not in learning_data.attack_success_rates:
		learning_data.attack_success_rates[attack_type] = 0.5
	
	var current_rate = learning_data.attack_success_rates[attack_type]
	var adjustment = 0.03 if hit else -0.02
	learning_data.attack_success_rates[attack_type] = clamp(current_rate + adjustment, 0.2, 0.95)
	save_data()

func record_player_behavior(distance: float, dodged: bool, was_aggressive: bool, jumped: bool):
	var behavior = learning_data.player_behavior_patterns
	behavior.avg_distance_kept = lerp(behavior.avg_distance_kept, distance, 0.08)
	behavior.dodge_frequency = lerp(behavior.dodge_frequency, 1.0 if dodged else 0.0, 0.08)
	behavior.aggression_level = lerp(behavior.aggression_level, 1.0 if was_aggressive else 0.0, 0.08)
	behavior.jump_frequency = lerp(behavior.jump_frequency, 1.0 if jumped else 0.0, 0.08)
	save_data()

func get_best_attack() -> String:
	var best_attack = "vertical_slash"
	var best_rate = 0.0
	for attack in learning_data.attack_success_rates:
		if learning_data.attack_success_rates[attack] > best_rate:
			best_rate = learning_data.attack_success_rates[attack]
			best_attack = attack
	return best_attack

func get_worst_attack() -> String:
	var worst_attack = "vertical_slash"
	var worst_rate = 1.0
	for attack in learning_data.attack_success_rates:
		if learning_data.attack_success_rates[attack] < worst_rate:
			worst_rate = learning_data.attack_success_rates[attack]
			worst_attack = attack
	return worst_attack

func should_prioritize_attack(attack_type: String) -> bool:
	if attack_type not in learning_data.attack_success_rates:
		return false
	return learning_data.attack_success_rates[attack_type] > 0.65

func get_adaptation_multiplier() -> float:
	return learning_data.adaptation_level

func get_speed_multiplier() -> float:
	return learning_data.speed_multiplier

func get_attack_speed_multiplier() -> float:
	return learning_data.attack_speed_multiplier

func should_retreat_more() -> bool:
	return learning_data.player_behavior_patterns.retreat_frequency > 0.6
