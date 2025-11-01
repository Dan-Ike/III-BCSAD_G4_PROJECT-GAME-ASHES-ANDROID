extends Node2D
@onready var player: Player = $player
@onready var tile_map: TileMap = $TileMap
@onready var parallax_background: AnimatedBackground = $ParallaxBackground
@onready var gpu_particles_2d: FallingParticles = $GPUParticles2D
@onready var camera_2d_2: Camera2D = $player/Camera2D2
@onready var player_camera = $player/Camera2D

func _ready() -> void:
	player_camera.enabled = true
	camera_2d_2.enabled = false
	
	# Move particles to CanvasLayer for screen-space rendering
	if gpu_particles_2d:
		# Create a CanvasLayer to keep particles on screen
		var canvas_layer = CanvasLayer.new()
		canvas_layer.layer = -1  # Behind gameplay UI
		canvas_layer.follow_viewport_enabled = false  # CRITICAL: Don't follow camera!
		add_child(canvas_layer)
		
		# Move particles to canvas layer
		gpu_particles_2d.get_parent().remove_child(gpu_particles_2d)
		canvas_layer.add_child(gpu_particles_2d)
		
		# Position at top center of screen (viewport coordinates)
		var viewport_size = get_viewport_rect().size
		gpu_particles_2d.position = Vector2(viewport_size.x / 2, 0)
		
		# CRITICAL: Use local coordinates so particles fall relative to emitter
		gpu_particles_2d.local_coords = true
		
		# Configure particle settings
		gpu_particles_2d.particle_type = FallingParticles.ParticleType.ASH
		gpu_particles_2d.particle_density = 2.0
		gpu_particles_2d.wind_strength = 0.2
		
		# Force setup
		gpu_particles_2d._setup_particle_system()
		gpu_particles_2d.local_coords = true  # Ensure it stays local
		
		print("[Particles] Canvas Layer Follow: ", canvas_layer.follow_viewport_enabled)
		print("[Particles] Position: ", gpu_particles_2d.position)
		print("[Particles] Local Coords: ", gpu_particles_2d.local_coords)
	
	# Fix parallax
	if parallax_background:
		parallax_background.scroll_base_offset = Vector2.ZERO

func _process(delta: float) -> void:
	# Update parallax to follow camera
	if parallax_background and player:
		parallax_background.scroll_offset = -player.global_position
