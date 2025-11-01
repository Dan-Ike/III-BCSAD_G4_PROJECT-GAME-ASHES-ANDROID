extends GPUParticles2D
class_name FallingParticles

enum ParticleType { SNOW, ASH, RAIN, EMBERS, LEAVES }

@export var particle_type: ParticleType = ParticleType.SNOW
@export var particle_density: float = 1.0  # 0.5 = half, 2.0 = double
@export var wind_strength: float = 0.0  # Horizontal drift (-1 to 1)

func _ready() -> void:
	_setup_particle_system()

func _setup_particle_system() -> void:
	# Basic settings
	amount = int(100 * particle_density)
	lifetime = 10.0
	preprocess = 2.0
	explosiveness = 0.0
	randomness = 0.5
	fixed_fps = 0
	
	# CRITICAL: Large visibility rect and world coordinates
	visibility_rect = Rect2(-2000, -1000, 4000, 3000)
	local_coords = false  # Use world space!
	emitting = true
	
	# Create process material
	var material = ParticleProcessMaterial.new()
	process_material = material
	
	# Emission shape - emit from a wide horizontal line
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(1000, 10, 0)  # Wide emission
	
	# CRITICAL: Set gravity to pull DOWN (positive Y in Godot)
	material.gravity = Vector3(wind_strength * 20, 98, 0)  # Y=98 for downward gravity
	material.direction = Vector3(0, 1, 0)  # Point downward
	material.spread = 0.0  # No spread, straight down
	material.initial_velocity_min = 50.0
	material.initial_velocity_max = 100.0
	
	match particle_type:
		ParticleType.SNOW:
			_setup_snow(material)
		ParticleType.ASH:
			_setup_ash(material)
		ParticleType.RAIN:
			_setup_rain(material)
		ParticleType.EMBERS:
			_setup_embers(material)
		ParticleType.LEAVES:
			_setup_leaves(material)
	
	# Create texture (simple circle)
	var texture = _create_particle_texture()
	self.texture = texture

func _setup_snow(material: ParticleProcessMaterial) -> void:
	# Falling speed
	material.initial_velocity_min = 30.0
	material.initial_velocity_max = 60.0
	
	# Rotation while falling
	material.angular_velocity_min = -45.0
	material.angular_velocity_max = 45.0
	
	# Size variation
	material.scale_min = 0.3
	material.scale_max = 1.0
	material.color = Color(1.0, 1.0, 1.0, 0.8)
	
	# Gentle swaying motion
	material.turbulence_enabled = true
	material.turbulence_noise_strength = 2.0
	material.turbulence_noise_scale = 5.0
	material.turbulence_noise_speed = Vector3(0.5, 0.5, 0.5)

func _setup_ash(material: ParticleProcessMaterial) -> void:
	# Slower falling
	material.initial_velocity_min = 15.0
	material.initial_velocity_max = 40.0
	
	# More rotation
	material.angular_velocity_min = -90.0
	material.angular_velocity_max = 90.0
	
	# Smaller particles
	material.scale_min = 0.2
	material.scale_max = 0.6
	material.color = Color(0.3, 0.3, 0.3, 0.6)
	
	# More chaotic movement
	material.turbulence_enabled = true
	material.turbulence_noise_strength = 5.0
	material.turbulence_noise_scale = 3.0
	material.turbulence_noise_speed = Vector3(1.0, 0.5, 0.5)
	
	# Fade out as they fall
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 1))
	gradient.add_point(1.0, Color(1, 1, 1, 0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture

func _setup_rain(material: ParticleProcessMaterial) -> void:
	material.initial_velocity_min = 200.0
	material.initial_velocity_max = 300.0
	material.scale_min = 0.5
	material.scale_max = 1.5
	material.color = Color(0.7, 0.8, 1.0, 0.6)
	
	# Stretch particles for rain streak effect
	var curve_x = Curve.new()
	curve_x.add_point(Vector2(0, 0.1))
	curve_x.add_point(Vector2(1, 0.1))
	var curve_y = Curve.new()
	curve_y.add_point(Vector2(0, 3.0))
	curve_y.add_point(Vector2(1, 3.0))
	
	var curve_texture_x = CurveTexture.new()
	curve_texture_x.curve = curve_x
	var curve_texture_y = CurveTexture.new()
	curve_texture_y.curve = curve_y
	
	material.scale_curve_x = curve_texture_x
	material.scale_curve_y = curve_texture_y

func _setup_embers(material: ParticleProcessMaterial) -> void:
	material.direction = Vector3(0, -1, 0)  # Float upward
	material.initial_velocity_min = 15.0
	material.initial_velocity_max = 40.0
	material.angular_velocity_min = -180.0
	material.angular_velocity_max = 180.0
	material.scale_min = 0.3
	material.scale_max = 0.8
	
	# Orange/red glow
	material.color = Color(1.0, 0.5, 0.2, 1.0)
	
	# Turbulent rising
	material.turbulence_enabled = true
	material.turbulence_noise_strength = 3.0
	
	# Fade and shrink
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 1))
	gradient.add_point(0.7, Color(1, 0.5, 0, 0.8))
	gradient.add_point(1.0, Color(0.5, 0, 0, 0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture

func _setup_leaves(material: ParticleProcessMaterial) -> void:
	material.initial_velocity_min = 30.0
	material.initial_velocity_max = 60.0
	material.angular_velocity_min = -120.0
	material.angular_velocity_max = 120.0
	material.scale_min = 0.5
	material.scale_max = 1.2
	material.color = Color(0.8, 0.6, 0.2, 0.9)
	
	# Swirling motion
	material.turbulence_enabled = true
	material.turbulence_noise_strength = 8.0
	material.turbulence_noise_scale = 2.0

func _create_particle_texture() -> Texture2D:
	var size = 32
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	var center = Vector2(size / 2, size / 2)
	var radius = size / 2
	
	# Draw a soft circle
	for x in range(size):
		for y in range(size):
			var dist = Vector2(x, y).distance_to(center)
			var alpha = 1.0 - (dist / radius)
			alpha = clamp(alpha, 0.0, 1.0)
			alpha = pow(alpha, 2)  # Softer edges
			
			if particle_type == ParticleType.RAIN:
				# Elongated shape for rain
				if abs(y - center.y) < size * 0.4:
					image.set_pixel(x, y, Color(1, 1, 1, alpha))
			else:
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
	
	return ImageTexture.create_from_image(image)

# Dynamic control functions
func set_intensity(intensity: float) -> void:
	"""Adjust particle density in real-time (0.0 to 2.0)"""
	particle_density = intensity
	amount = int(100 * particle_density)

func set_wind(wind: float) -> void:
	"""Adjust wind direction (-1.0 to 1.0)"""
	wind_strength = wind
	if process_material is ParticleProcessMaterial:
		process_material.gravity = Vector3(wind_strength * 20, 98, 0)  # Keep Y gravity
