extends ParallaxBackground
class_name AnimatedBackground

# Parallax layer speeds (closer = faster)
@export var layer_speeds: Array[float] = [0.1, 0.3, 0.5, 0.7]
@export var auto_scroll_speed: Vector2 = Vector2(-20, 0)  # Negative X = scroll left
@export var enable_auto_scroll: bool = true

# Cloud/fog movement
@export var cloud_drift_speed: float = 10.0
@export var cloud_wave_amplitude: float = 5.0
@export var cloud_wave_frequency: float = 0.5

var time_passed: float = 0.0

func _ready() -> void:
	# Set up each parallax layer with different speeds
	var layers = get_children()
	for i in range(layers.size()):
		if layers[i] is ParallaxLayer:
			var layer = layers[i] as ParallaxLayer
			
			# Set motion scale based on depth
			if i < layer_speeds.size():
				layer.motion_scale = Vector2(layer_speeds[i], layer_speeds[i])
			
			# Enable mirroring for infinite scrolling
			layer.motion_mirroring = Vector2(1920, 1080)  # Adjust to your screen size

func _process(delta: float) -> void:
	time_passed += delta
	
	if enable_auto_scroll:
		# Smooth automatic scrolling
		scroll_offset += auto_scroll_speed * delta
		
		# Add subtle wave motion to background
		var wave_offset = sin(time_passed * cloud_wave_frequency) * cloud_wave_amplitude
		scroll_offset.y = wave_offset
	
	# Animate individual cloud layers with sine wave
	_animate_clouds(delta)

func _animate_clouds(delta: float) -> void:
	var layers = get_children()
	for i in range(layers.size()):
		if layers[i] is ParallaxLayer:
			var layer = layers[i] as ParallaxLayer
			
			# Different layers move at different speeds
			var speed_multiplier = 1.0 + (i * 0.2)
			var wave = sin(time_passed * speed_multiplier + i) * cloud_wave_amplitude
			
			# Apply subtle floating motion to each layer
			layer.motion_offset.y = wave
