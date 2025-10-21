extends Node2D

#@onready var player_camera: Camera2D = $Camera2D
#@onready var player_camera = $Camera2D
@onready var player_camera: Camera2D = $player/Camera2D
@onready var scene_transition_animation = $SceneTransitionAnimation/AnimationPlayer

var current_wave: int
@export var bat_scene: PackedScene
@export var golem_scene: PackedScene

var starting_nodes: int
var current_nodes: int
var wave_spawn_ended
var enemies_alive: int = 0

var wave_timer: SceneTreeTimer
var next_wave_delay: float = 10.0

func _ready():
	scene_transition_animation.get_parent().get_node("ColorRect").color.a = 255
	scene_transition_animation.play("fade_out")
	player_camera.enabled = true
	current_wave = 0
	Global.current_wave = current_wave
	starting_nodes = get_child_count()
	current_nodes = get_child_count()
	position_to_next_wave()

func position_to_next_wave():
	if !Global.playerAlive:
		return   
	if current_wave != 0:
		Global.moving_to_next_wave = true
		scene_transition_animation.play("between_wave")
	wave_spawn_ended = false
	current_wave += 1
	Global.current_wave = current_wave
	await get_tree().create_timer(0.5).timeout
	if !Global.playerAlive:  
		return
	prepare_spawn("bats", 4.0, 4.0)
	prepare_spawn("golems", 1.5, 2.0)
	print("Wave started:", current_wave)
	
	if wave_timer:
		wave_timer.timeout.disconnect(_on_wave_time_expired) 
	wave_timer = get_tree().create_timer(next_wave_delay)
	wave_timer.timeout.connect(_on_wave_time_expired)

func _on_wave_time_expired():
	if enemies_alive > 0:
		print("Wave timed out, starting next wave anyway.")
		position_to_next_wave()
	if next_wave_delay < 30.0:
		next_wave_delay += 10.0


func prepare_spawn(type, multiplier, mob_spawns):
	var mob_amount = float(current_wave) * multiplier
	var mob_wait_time: float = 2.0
	print("mob amount: ", mob_amount)
	var mob_spawn_rounds = mob_amount / mob_spawns
	spawn_type(type, mob_spawn_rounds, mob_wait_time)
	

func spawn_type(type, mob_spawn_rounds, mob_wait_time):
	if type == "bats":
		var bat_spawn1 = $BatSpawnPoint1
		var bat_spawn2 = $BatSpawnPoint2
		var bat_spawn3 = $BatSpawnPoint3
		var bat_spawn4 = $BatSpawnPoint4
		if mob_spawn_rounds >= 1:
			for i in range(int(mob_spawn_rounds)):
				var bat1 = bat_scene.instantiate()
				bat1.global_position = bat_spawn1.global_position
				var bat2 = bat_scene.instantiate()
				bat2.global_position = bat_spawn2.global_position
				var bat3 = bat_scene.instantiate()
				bat3.global_position = bat_spawn3.global_position
				var bat4 = bat_scene.instantiate()
				bat4.global_position = bat_spawn4.global_position
				add_child(bat1)
				enemies_alive += 1
				bat1.tree_exited.connect(_on_enemy_died)
				add_child(bat2)
				enemies_alive += 1
				bat2.tree_exited.connect(_on_enemy_died)
				add_child(bat3)
				enemies_alive += 1
				bat3.tree_exited.connect(_on_enemy_died)
				add_child(bat4)
				enemies_alive += 1
				bat4.tree_exited.connect(_on_enemy_died)
				mob_spawn_rounds -= 1
				await get_tree().create_timer(mob_wait_time).timeout
	elif type == "golems":
		var golem_spawn1 = $GolemSpawnPoint1
		var golem_spawn2 = $GolemSpawnPoint2
		if mob_spawn_rounds >= 1:
			for i in range(int(mob_spawn_rounds)):
				var golem1 = golem_scene.instantiate()
				golem1.global_position = golem_spawn1.global_position
				var golem2 = golem_scene.instantiate()
				golem2.global_position = golem_spawn2.global_position
				add_child(golem1)
				enemies_alive += 1
				golem1.tree_exited.connect(_on_enemy_died)
				add_child(golem2)
				enemies_alive += 1
				golem2.tree_exited.connect(_on_enemy_died)
				mob_spawn_rounds -= 1
				await get_tree().create_timer(mob_wait_time).timeout
	wave_spawn_ended = true

func _on_enemy_died():
	enemies_alive -= 1
	if enemies_alive <= 0 and wave_spawn_ended:
		print("Wave cleared!")
		if wave_timer:
			wave_timer.timeout.disconnect(_on_wave_time_expired)
			wave_timer = null
		position_to_next_wave()

func _process(delta: float) -> void:
	if !Global.playerAlive:
		Global.gameStarted = false
		scene_transition_animation.play("fade_in")
		await  get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scene/lobby_level.tscn")
	current_nodes = get_child_count()
