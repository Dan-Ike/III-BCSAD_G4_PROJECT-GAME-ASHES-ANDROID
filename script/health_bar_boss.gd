extends Control
@onready var health_bar: ProgressBar = $HealthBar

var boss: CharacterBody2D = null
var current_phase: int = 1

func _ready() -> void:
	# Start hidden - will be shown by level script
	visible = false
	
	# Wait for boss to be ready
	await get_tree().process_frame
	
	# Find boss in the scene
	boss = get_tree().get_first_node_in_group("boss")
	
	if boss:
		health_bar.max_value = boss.health_max
		health_bar.min_value = boss.health_min
		health_bar.value = boss.health
		print("[BossHealthBar] Boss found and health bar initialized!")
	else:
		print("[BossHealthBar] Warning: Boss not found!")

func _process(delta: float) -> void:
	if not boss or not is_instance_valid(boss):
		# Boss is dead or doesn't exist
		visible = false
		return
	
	# Update health bar smoothly
	if visible:
		health_bar.value = lerp(health_bar.value, float(boss.health), 0.15)
		
		# Update phase indicator if label exists
		if boss.current_phase != current_phase:
			current_phase = boss.current_phase
		
		# Change color based on health percentage
		var health_percent = float(boss.health) / float(boss.health_max)
		if health_percent <= 0.3:
			health_bar.modulate = Color(1.0, 0.3, 0.3)  # Red when low
		elif health_percent <= 0.5:
			health_bar.modulate = Color(1.0, 0.8, 0.2)  # Yellow at half
		else:
			health_bar.modulate = Color(1.0, 1.0, 1.0)  # White when healthy
