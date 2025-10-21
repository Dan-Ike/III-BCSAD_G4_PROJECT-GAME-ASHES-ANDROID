extends CanvasLayer

@onready var label: Label = $Panel/Label

var dot_count: int = 0
var dot_timer: float = 0.0
var dot_interval: float = 0.5 
var base_text: String = "Loading"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	label.text = base_text

func _process(delta: float) -> void:
	dot_timer += delta
	if dot_timer >= dot_interval:
		dot_timer = 0.0
		dot_count = (dot_count + 1) % 4  
		
		var dots = ""
		for i in range(dot_count):
			dots += "."
		label.text = base_text + dots

func start_loading(target_scene: String) -> void:
	"""Start loading a scene"""
	visible = true
	
	await get_tree().process_frame
	
	var min_load_time = 0.5
	var start_time = Time.get_ticks_msec() / 1000.0
	
	var loader = ResourceLoader.load_threaded_request(target_scene)
	
	while true:
		var status = ResourceLoader.load_threaded_get_status(target_scene)
		
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Failed to load scene: " + target_scene)
			return
		
		await get_tree().process_frame
	
	var elapsed = (Time.get_ticks_msec() / 1000.0) - start_time
	if elapsed < min_load_time:
		await get_tree().create_timer(min_load_time - elapsed).timeout
	
	var scene = ResourceLoader.load_threaded_get(target_scene)
	get_tree().change_scene_to_packed(scene)
