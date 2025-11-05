extends Node

const SAVE_PATH = "user://ml_enemy_data.json"

var learning_data = {
	"encounters": 0,
	"player_deaths": 0,
	"successful_attack_patterns": {},
	"player_behavior_patterns": {
		"avg_distance_kept": 150.0,
		"dodge_frequency": 0.5,
		"aggression_level": 0.5,
		"jump_frequency": 0.3
	},
	"attack_success_rates": {
		"melee": 0.3,
		"ranged": 0.3,
		"charge": 0.3,
		"jump_attack": 0.3,
		"spin_attack": 0.3
	},
	"adaptation_level": 1.0
}

#experienced
func set_expert_mode():
	learning_data = {
		"encounters": 50,
		"player_deaths": 15,
		"successful_attack_patterns": {},
		"player_behavior_patterns": {
			"avg_distance_kept": 180.0,
			"dodge_frequency": 0.75,
			"aggression_level": 0.65,
			"jump_frequency": 0.55
		},
		"attack_success_rates": {
			"melee": 0.75,
			"ranged": 0.80,
			"charge": 0.70,
			"jump_attack": 0.65,
			"spin_attack": 0.85
		},
		"adaptation_level": 1.0
	}
	save_data()
	print("[ML] Set to EXPERT mode!")

# GODLIKE
func set_godlike_mode():
	learning_data = {
		"encounters": 100,
		"player_deaths": 40,
		"successful_attack_patterns": {},
		"player_behavior_patterns": {
			"avg_distance_kept": 200.0,
			"dodge_frequency": 0.90,
			"aggression_level": 0.85,
			"jump_frequency": 0.70
		},
		"attack_success_rates": {
			"melee": 0.90,
			"ranged": 0.95,
			"charge": 0.88,
			"jump_attack": 0.85,
			"spin_attack": 0.92
		},
		"adaptation_level": 1.0
	}
	save_data()
	print("[ML] Set to GODLIKE mode!")


func _ready():
	load_data()
	#set_godlike_mode()

func reset_adaptation():
	learning_data.adaptation_level = 1.0
	learning_data.player_deaths = 0
	save_data()
	print("[ML] Reset adaptation level to 1.0")

func load_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			learning_data = json.data
		file.close()
		print("[ML] Loaded learning data: ", learning_data)

func save_data():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(learning_data, "\t"))
	file.close()
	print("[ML] Saved learning data")

func record_encounter():
	learning_data.encounters += 1
	save_data()

func record_player_death():
	learning_data.player_deaths += 1
	learning_data.adaptation_level = min(3.0, 1.0 + (learning_data.player_deaths * 0.1))
	save_data()

func record_attack_result(attack_type: String, hit: bool):
	if attack_type not in learning_data.attack_success_rates:
		learning_data.attack_success_rates[attack_type] = 0.5
	
	var current_rate = learning_data.attack_success_rates[attack_type]
	var adjustment = 0.05 if hit else -0.03
	learning_data.attack_success_rates[attack_type] = clamp(current_rate + adjustment, 0.1, 0.9)
	save_data()

func record_player_behavior(distance: float, dodged: bool, was_aggressive: bool, jumped: bool):
	var behavior = learning_data.player_behavior_patterns
	behavior.avg_distance_kept = lerp(behavior.avg_distance_kept, distance, 0.1)
	behavior.dodge_frequency = lerp(behavior.dodge_frequency, 1.0 if dodged else 0.0, 0.1)
	behavior.aggression_level = lerp(behavior.aggression_level, 1.0 if was_aggressive else 0.0, 0.1)
	behavior.jump_frequency = lerp(behavior.jump_frequency, 1.0 if jumped else 0.0, 0.1)
	save_data()

func get_best_attack() -> String:
	var best_attack = "melee"
	var best_rate = 0.0
	for attack in learning_data.attack_success_rates:
		if learning_data.attack_success_rates[attack] > best_rate:
			best_rate = learning_data.attack_success_rates[attack]
			best_attack = attack
	return best_attack

func get_adaptation_multiplier() -> float:
	return learning_data.adaptation_level
