# tutorial_orb.gd
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var particles: CPUParticles2D = $CPUParticles2D

var float_offset: float = 0.0
var float_speed: float = 2.0
var float_amplitude: float = 10.0
var initial_y: float = 0.0

func _ready() -> void:
	initial_y = position.y
	_create_orb_visual()
	_setup_particles()

func _create_orb_visual() -> void:
	# Create a simple circle texture if no sprite is set
	if not sprite.texture:
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		var center = Vector2(32, 32)
		var radius = 28.0
		
		for x in range(64):
			for y in range(64):
				var dist = Vector2(x, y).distance_to(center)
				if dist <= radius:
					# Create a gradient from center to edge
					var alpha = 1.0 - (dist / radius) * 0.3
					var color = Color(0.5, 0.8, 1.0, alpha)  # Cyan glow
					img.set_pixel(x, y, color)
		
		var texture = ImageTexture.create_from_image(img)
		sprite.texture = texture
		sprite.modulate = Color(1, 1, 1, 0.9)

# Add this to your tutorial_orb.gd _ready() function after _create_orb_visual()

func _setup_particles() -> void:
	if has_node("CPUParticles2D"):
		var particles = $CPUParticles2D
		particles.emitting = true
		particles.amount = 20
		particles.lifetime = 1.5
		particles.explosiveness = 0.0
		particles.randomness = 0.5
		
		# Visual settings
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 15.0
		
		# Movement
		particles.direction = Vector2(0, -1)
		particles.spread = 180.0
		particles.gravity = Vector2(0, -20)
		particles.initial_velocity_min = 10.0
		particles.initial_velocity_max = 20.0
		
		# Appearance
		particles.scale_amount_min = 0.3
		particles.scale_amount_max = 0.8
		particles.color = Color(0.5, 0.8, 1.0, 0.6)  # Cyan

func _process(delta: float) -> void:
	# Floating animation
	float_offset += delta * float_speed
	position.y = initial_y + sin(float_offset) * float_amplitude
	
	# Gentle rotation
	rotation = sin(float_offset * 0.5) * 0.1
	
	# Pulsing glow effect
	var pulse = (sin(float_offset * 3.0) + 1.0) / 2.0
	sprite.modulate.a = 0.7 + (pulse * 0.3)

func show_orb() -> void:
	visible = true

func hide_orb() -> void:
	visible = false
