extends Control

var pending_deep_link: String = ""
var debug_label: Label = null  

@onready var version: Label = $components/version
@onready var background: Panel = $Background
@onready var bg_2: Panel = $bg2 
@onready var audio_control: HSlider = $Settings/AudioControl
@onready var audio_sound_control_2: HSlider = $Settings/AudioSoundControl2
@onready var control_choice: OptionButton = $Settings/ControlChoice
@onready var cutscene_choice: OptionButton = $Settings/CutsceneChoice
@onready var exit: Control = $Exit 
@onready var exit_game: TouchScreenButton = $Exit/Control2/exit 
@onready var cancel: TouchScreenButton = $Exit/Control/cancel 
@onready var settings: Control = $Settings 
@onready var back: TouchScreenButton = $Settings/Control/back 
@onready var unlock: Control = $Unlock 
@onready var google: TouchScreenButton = $components/Control/google 
@onready var profile: TextureRect = $components/Control2/profile
#@onready var profile: TouchScreenButton = $components/Control2/profile 
@onready var unlockall: TouchScreenButton = $components/Control5/unlockall 
@onready var newgame: TouchScreenButton = $Mainbtn/Control/newgame 
@onready var start_continue: TouchScreenButton = $Mainbtn/Control2/start_continue 
@onready var exit_btn: TouchScreenButton = $Mainbtn/Control3/exit 
@onready var cancel_unlock: TouchScreenButton = $Unlock/Control/cancel
@onready var yes_unlock: TouchScreenButton = $Unlock/Control2/yes
@onready var main_btns: Control = $Mainbtn
@onready var components: Control = $components
@onready var settings_btn: TouchScreenButton = $components/Control3/settings
@onready var title: TextureRect = $title
@onready var credits: Control = $Credits
@onready var play_credits: TouchScreenButton = $Credits/Control/play_credits
@onready var exit_credits: TouchScreenButton = $Credits/Control2/exit_credits

@onready var continue_pop_up: Control = $Continue
@onready var new_game_logged_in: Control = $NewGameLoggedIn
@onready var new_game_confirm: Control = $NewGameConfirm
@onready var okay_newgame: TouchScreenButton = $NewGameConfirm/Control2/okay_newgame
@onready var no_net: Control = $NoNet
@onready var logout: Control = $Logout

#Notice:
@onready var privacy_notice: Control = $PrivacyNotice
@onready var terms_and_condition: Control = $TermsAndCondition
@onready var google_notice: Control = $GoogleNotice
@onready var label_2: Label = $PrivacyNotice/ScrollContainer/Label2
@onready var label_2_2: Label = $TermsAndCondition/Label2
@onready var label_2_3: Label = $GoogleNotice/Label2
@onready var agree_privacy: TouchScreenButton = $PrivacyNotice/Control3/agreePrivacy
@onready var agreeterms: TouchScreenButton = $TermsAndCondition/Control3/agreeterms
@onready var agree_google: TouchScreenButton = $GoogleNotice/Control3/agreeGoogle

const PRIVACY_ACCEPTED_FILE = "user://privacy_accepted.dat"
const TERMS_ACCEPTED_FILE = "user://terms_accepted.dat"
const GOOGLE_NOTICE_ACCEPTED_FILE = "user://google_notice_accepted.dat"

const SUPABASE_URL = "https://fsntwndbknzhmotgphtj.supabase.co"
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZzbnR3bmRia256aG1vdGdwaHRqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk1NjUwMjAsImV4cCI6MjA3NTE0MTAyMH0.ZJESWD5jcH2rmFodnwHpI_cSsQWqnk1Fk-mmcrjP5mE"

const DESKTOP_CALLBACK_PORT = 54321
const PROFILE_IMAGE_PATH = "user://profile_image.png" 

var internet_connected: bool = false
var checking_internet: bool = false 

var is_transitioning := false

@onready var http: HTTPRequest = HTTPRequest.new()
var auth_in_progress: bool = false
var local_server: TCPServer = null
var auth_connection: StreamPeerTCP = null

func delayed_action(delay: float, action: Callable) -> void:
	await get_tree().create_timer(delay).timeout
	action.call()

func _input(event: InputEvent) -> void:
	if profile.visible and (event is InputEventScreenTouch or event is InputEventMouseButton):
		if event.is_pressed():
			var profile_rect = profile.get_global_rect()
			if profile_rect.has_point(event.position):
				_on_profile_pressed()

func _ready() -> void:
	if OS.has_feature("web"):
		var has_tokens = JavaScriptBridge.eval("window.sessionStorage.getItem('oauth_callback_received') === 'true'")
		if has_tokens:
			_log_debug("OAuth tokens found in sessionStorage")
			add_child(http)
			_check_web_oauth_callback() 
			return
	
	add_child(http)
	_setup_scrollable_notice(privacy_notice.get_node("ScrollContainer"), label_2)
	_setup_scrollable_notice(terms_and_condition.get_node("ScrollContainer"), label_2_2)
	_setup_scrollable_notice(google_notice.get_node("ScrollContainer"), label_2_3)
	
	is_transitioning = false
	
	# Hide everything initially
	main_btns.visible = false
	settings.visible = false
	components.visible = false
	bg_2.visible = false
	background.visible = false
	title.visible = false
	unlock.visible = false
	exit.visible = false
	credits.visible = false
	version.visible = false
	continue_pop_up.visible = false
	new_game_confirm.visible = false
	new_game_logged_in.visible = false
	no_net.visible = false
	logout.visible = false
	privacy_notice.visible = false
	terms_and_condition.visible = false
	google_notice.visible = false
	
	# Check if privacy and terms have been accepted
	if not _is_privacy_accepted():
		# Show privacy notice first
		bg_2.visible = true
		privacy_notice.visible = true
		transition_in([bg_2, privacy_notice])
		return
	
	if not _is_terms_accepted():
		# Show terms and condition
		bg_2.visible = true
		terms_and_condition.visible = true
		transition_in([bg_2, terms_and_condition])
		return
	
	# If both accepted, proceed with normal initialization
	_initialize_main_menu()

func _initialize_main_menu() -> void:
	"""Initialize the main menu after privacy/terms acceptance"""
	main_btns.visible = true
	settings.visible = false
	components.visible = true
	bg_2.visible = false
	background.visible = true
	title.visible = true
	version.visible = true
	
	MusicManager.play_song("menu")
	control_choice.select(Global.control_type)
	control_choice.item_selected.connect(_on_control_choice_selected)
	
	newgame.pressed.connect(_on_newgame_pressed)
	unlockall.pressed.connect(_on_unlockall_pressed)
	
	var saved_cutscene_pref = SaveManager.get_setting("cutscene_preference")
	if saved_cutscene_pref == null:
		saved_cutscene_pref = "play_once"
		SaveManager.set_setting("cutscene_preference", saved_cutscene_pref)
	
	if saved_cutscene_pref == "play_once":
		cutscene_choice.select(0)
	elif saved_cutscene_pref == "always":
		cutscene_choice.select(1)
	
	cutscene_choice.item_selected.connect(_on_cutscene_choice_selected)
	
	google.pressed.connect(_on_google_pressed)
	
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv);
	
	if (dist > 0.5) {
		discard;
	}
	
	COLOR = texture(TEXTURE, UV);
}
"""
	
	var material = ShaderMaterial.new()
	material.shader = shader
	profile.material = material
	profile.custom_minimum_size = Vector2(64, 64)
	
	# Check internet connectivity FIRST (make it synchronous for initial check)
	_check_internet_connection_sync()
	
	# Then load session
	if Global.session_token == "":
		_load_session()
	else:
		google.visible = false
		google.set_process_input(false)
		profile.visible = true
		_load_cached_profile_image()
		
	if OS.has_feature("Android"):
		_create_debug_label()
	
	if OS.has_feature("Android"):
		_log_debug("Android detected - Setting up deep link handlers")
		call_deferred("_check_for_deep_link")
		
		get_tree().root.connect("focus_entered", _on_app_focus_gained)
	
	_update_start_button_text()
	_update_newgame_button_visibility()

func _check_internet_connection_sync() -> void:
	"""Synchronous internet check for startup"""
	# Simple check - assume we're online initially
	# The async check will update it properly
	internet_connected = true
	_check_internet_connection()  # Do the real check in background

func _is_privacy_accepted() -> bool:
	return FileAccess.file_exists(PRIVACY_ACCEPTED_FILE)

func _is_terms_accepted() -> bool:
	return FileAccess.file_exists(TERMS_ACCEPTED_FILE)

func _is_google_notice_accepted() -> bool:
	return FileAccess.file_exists(GOOGLE_NOTICE_ACCEPTED_FILE)

func _mark_privacy_accepted() -> void:
	var f = FileAccess.open(PRIVACY_ACCEPTED_FILE, FileAccess.WRITE)
	if f:
		f.store_string("accepted")
		f.close()
		print("Privacy notice accepted and saved")

func _mark_terms_accepted() -> void:
	var f = FileAccess.open(TERMS_ACCEPTED_FILE, FileAccess.WRITE)
	if f:
		f.store_string("accepted")
		f.close()
		print("Terms accepted and saved")

func _mark_google_notice_accepted() -> void:
	var f = FileAccess.open(GOOGLE_NOTICE_ACCEPTED_FILE, FileAccess.WRITE)
	if f:
		f.store_string("accepted")
		f.close()
		print("Google notice accepted and saved")

func _on_agree_privacy_pressed() -> void:
	_mark_privacy_accepted()
	
	transition_out(func():
		privacy_notice.visible = false
		
		# Show terms next
		terms_and_condition.visible = true
		transition_in([bg_2, terms_and_condition])
	)

func _on_agreeterms_pressed() -> void:
	_mark_terms_accepted()
	
	transition_out(func():
		terms_and_condition.visible = false
		bg_2.visible = false
		
		# Now proceed to main menu
		_initialize_main_menu()
		transition_in([background, main_btns, components, title, version])
	)

func _on_agree_google_pressed() -> void:
	_mark_google_notice_accepted()
	
	transition_out(func():
		google_notice.visible = false
		bg_2.visible = false
		
		_initialize_main_menu()
		transition_in([background, main_btns, components, title, version])
	)
	
	# Continue with OAuth flow
	_log_debug("Google Notice accepted, starting OAuth...")
	
	if OS.has_feature("Android"):
		auth_in_progress = true
		_log_debug("Starting OAuth flow...")
		_start_google_oauth_flow()
	elif OS.has_feature("web"):
		auth_in_progress = true
		_log_debug("Starting Web OAuth flow...")
		_start_web_oauth_flow()
	else:
		if _start_local_server():
			auth_in_progress = true
			_start_google_oauth_flow()
		else:
			_show_error("Failed to start local server for OAuth.\nPlease check if port %d is available." % DESKTOP_CALLBACK_PORT)

func _setup_scrollable_notice(scroll_container: ScrollContainer, label: Label) -> void:
	if not scroll_container:
		return
	
	# Enable vertical scrolling
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	# Make label wrap text properly
	#label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	#label.custom_minimum_size.x = scroll_container.size.x - 20  # Account for scrollbar
	
	# Optional: Customize scrollbar appearance
	var v_scroll = scroll_container.get_v_scroll_bar()
	if v_scroll:
		v_scroll.custom_minimum_size.x = 10  # Thinner scrollbar

func _on_app_focus_gained() -> void:
	"""Called when app gains focus (returns from browser)"""
	if OS.has_feature("Android") and auth_in_progress:
		_log_debug("🔔 App gained focus - checking for deep link")
		call_deferred("_check_for_deep_link")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		_log_debug("🔔 App resumed - checking for OAuth callback")
		if OS.has_feature("Android") and auth_in_progress:
			call_deferred("_check_for_deep_link")
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_log_debug("🔔 App focus in - checking for OAuth callback")
		if OS.has_feature("Android") and auth_in_progress:
			call_deferred("_check_for_deep_link")

func _check_for_deep_link():
	if not OS.has_feature("Android"):
		return
	
	_log_debug("checking for deep link...")
	
	# Method 1: Check command line args
	var args = OS.get_cmdline_args()
	_log_debug("cmdline_args count: " + str(args.size()))
	for i in range(args.size()):
		var arg = args[i]
		_log_debug("  [" + str(i) + "]: " + str(arg))
		if typeof(arg) == TYPE_STRING and arg.begins_with("io.supabase.godot://"):
			_log_debug("Deep link found in cmdline_args: " + arg)
			_parse_oauth_callback(arg)
			return
	
	# Method 2: Check user args
	var user_args = OS.get_cmdline_user_args()
	_log_debug("user_args count: " + str(user_args.size()))
	for i in range(user_args.size()):
		var arg = user_args[i]
		_log_debug("  [" + str(i) + "]: " + str(arg))
		if typeof(arg) == TYPE_STRING and arg.begins_with("io.supabase.godot://"):
			_log_debug("Deep link found in user_args: " + arg)
			_parse_oauth_callback(arg)
			return
	
	# Method 3: Try to read from a file (workaround)
	var intent_file = "user://pending_intent.txt"
	if FileAccess.file_exists(intent_file):
		var f = FileAccess.open(intent_file, FileAccess.READ)
		if f:
			var intent_data = f.get_as_text().strip_edges()
			f.close()
			
			if intent_data.begins_with("io.supabase.godot://"):
				_log_debug("Deep link found in file: " + intent_data)
				DirAccess.remove_absolute(intent_file)
				_parse_oauth_callback(intent_data)
				return
	
	_log_debug("No deep link found yet")

func _check_internet_connection() -> void:
	if checking_internet:
		return
	
	checking_internet = true
	var test_http = HTTPRequest.new()
	add_child(test_http)
	
	test_http.request_completed.connect(func(result, response_code, _headers, _body):
		internet_connected = (response_code == 200)
		test_http.queue_free()
		checking_internet = false
		
		if internet_connected:
			print("Internet connection detected")
			# If online and logged in, check if profile image needs updating
			if Global.get_current_user().size() > 0:
				var avatar_url = Global.get_current_user().get("user_metadata", {}).get("avatar_url", "")
				if avatar_url != "":
					_update_google_profile_image(avatar_url)
		else:
			print("⚠No internet connection")
	)
	
	test_http.request("https://www.google.com", [], HTTPClient.METHOD_HEAD)
	
	await get_tree().create_timer(3.0).timeout
	if test_http and is_instance_valid(test_http):
		test_http.queue_free()
		checking_internet = false

func _parse_oauth_callback(url: String):
	_log_debug("Parsing Android OAuth callback URL")
	_log_debug("URL: " + url)
	auth_in_progress = false
	
	# Stop the periodic timer
	if has_node("IntentCheckTimer"):
		var timer = get_node("IntentCheckTimer")
		timer.stop()
		timer.queue_free()
	
	# Extract tokens from URL
	var fragment = ""
	
	# Handle both # and ? in URL
	if "#" in url:
		var parts = url.split("#", true, 1)
		fragment = parts[1] if parts.size() > 1 else ""
		_log_debug("Found # in URL, fragment: " + fragment)
	elif "?" in url:
		var parts = url.split("?", true, 1)
		fragment = parts[1] if parts.size() > 1 else ""
		_log_debug("Found ? in URL, fragment: " + fragment)
	
	if fragment == "":
		_log_debug("No tokens found in OAuth callback URL")
		_show_error("No tokens found in OAuth callback URL")
		return
	
	_log_debug("Fragment data: " + fragment)
	
	# Parse parameters
	var params = fragment.split("&")
	_log_debug("Parameters count: " + str(params.size()))
	
	var access_token = ""
	var refresh_token = ""
	
	for param in params:
		var kv = param.split("=", true, 1)
		if kv.size() == 2:
			var key = kv[0]
			var value = kv[1]
			_log_debug("  " + key + " = " + value.substr(0, min(20, value.length())) + "...")
			
			if key == "access_token":
				access_token = value
			elif key == "refresh_token":
				refresh_token = value
	
	if access_token != "":
		_log_debug("Tokens extracted successfully!")
		_perform_login(access_token, refresh_token)
	else:
		_log_debug("No access token found in callback")
		_show_error("No access token found in callback")

func _exit_tree():
	_stop_local_server()
	
	if get_tree() and get_tree().root.is_connected("focus_entered", _on_app_focus_gained):
		get_tree().root.disconnect("focus_entered", _on_app_focus_gained)
	
	if has_node("IntentCheckTimer"):
		var timer = get_node("IntentCheckTimer")
		if timer.timeout.is_connected(_periodic_intent_check):
			timer.timeout.disconnect(_periodic_intent_check)
		timer.queue_free()

func _create_debug_label() -> void:
	"""Create a debug label that shows logs on screen for Android"""
	debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.position = Vector2(10, 10)
	debug_label.size = Vector2(1000, 600)
	debug_label.add_theme_color_override("font_color", Color.YELLOW)
	debug_label.add_theme_font_size_override("font_size", 16)
	debug_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_label.z_index = 1000  
	
	var panel = Panel.new()
	panel.name = "DebugPanel"
	panel.position = Vector2(5, 5)
	panel.size = Vector2(1010, 610)
	panel.z_index = 999
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	panel.add_theme_stylebox_override("panel", style)
	
	add_child(panel)
	add_child(debug_label)
	
	_log_debug("Debug logging initialized")
	_log_debug("OS: " + OS.get_name())
	_log_debug("Distribution: " + OS.get_distribution_name())

func _log_debug(message: String) -> void:
	"""Log message to both console and on-screen label"""
	print(message)
	
	if debug_label:
		var current_text = debug_label.text
		var lines = current_text.split("\n")
		
		# Keep only last 25 lines
		if lines.size() > 25:
			lines = lines.slice(lines.size() - 25, lines.size())
		
		lines.append(message)
		debug_label.text = "\n".join(lines)

func _on_google_pressed() -> void:
	# Check internet first
	if not internet_connected:
		transition_out(func():
			main_btns.visible = false
			background.visible = false
			bg_2.visible = true
			components.visible = false
			no_net.visible = true
			title.visible = false  
			version.visible = false
			
			transition_in([bg_2, no_net])
		)
		return
	
	# Check if Google notice has been accepted
	if not _is_google_notice_accepted():
		transition_out(func():
			main_btns.visible = false
			background.visible = false
			bg_2.visible = true
			components.visible = false
			google_notice.visible = true
			title.visible = false  
			version.visible = false
			
			transition_in([bg_2, google_notice])
		)
		return
	
	# If accepted, proceed with OAuth
	_log_debug("Google Login clicked")
	_log_debug("OS: " + OS.get_name())
	
	if OS.has_feature("Android"):
		auth_in_progress = true
		_log_debug("Starting OAuth flow...")
		_start_google_oauth_flow()
	elif OS.has_feature("web"):
		auth_in_progress = true
		_log_debug("Starting Web OAuth flow...")
		_start_web_oauth_flow()
	else:
		if _start_local_server():
			auth_in_progress = true
			_start_google_oauth_flow()
		else:
			_show_error("Failed to start local server for OAuth.\nPlease check if port %d is available." % DESKTOP_CALLBACK_PORT)

func _start_web_oauth_flow():
	_log_debug("Starting web OAuth flow...")
	
	var origin = JavaScriptBridge.eval("window.location.origin")
	_log_debug("Origin: " + str(origin))
	
	if origin == null or origin == "":
		_log_debug("Origin is null or empty")
		#_show_error("Could not get page origin")
		return
	
	var redirect_url = origin + "/callback.html"
	_log_debug("Redirect: " + redirect_url)
	
	var oauth_url = SUPABASE_URL + "/auth/v1/authorize?provider=google&prompt=select_account&redirect_to=" + redirect_url.uri_encode()
	
	_log_debug("Executing redirect...")
	JavaScriptBridge.eval("window.location.href = '" + oauth_url + "';")

func _start_google_oauth_flow():
	var redirect_url = ""
	
	if OS.has_feature("Android"):
		redirect_url = "io.supabase.godot://login-callback/"
		_log_debug("Android redirect: " + redirect_url)
	else:
		redirect_url = "http://127.0.0.1:%d/callback" % DESKTOP_CALLBACK_PORT
		_log_debug("Desktop redirect: " + redirect_url)
	
	var oauth_url = SUPABASE_URL + "/auth/v1/authorize?provider=google&prompt=select_account&redirect_to=" + redirect_url.uri_encode()
	
	_log_debug("=== OAUTH FLOW DEBUG ===")
	_log_debug("Full OAuth URL: " + oauth_url)
	_log_debug("Redirect URL (encoded): " + redirect_url.uri_encode())
	_log_debug("Opening browser...")
	
	OS.shell_open(oauth_url)
	
	# Add a check to see if we receive callback
	var check_timer = Timer.new()
	check_timer.name = "OAuthCheckTimer"
	check_timer.wait_time = 2.0
	check_timer.one_shot = false
	add_child(check_timer)
	
	var check_count = 0
	check_timer.timeout.connect(func():
		check_count += 1
		_log_debug("Waiting for OAuth callback... (%d seconds)" % (check_count * 2))
		if check_count >= 30:  # Stop after 60 seconds
			_log_debug("OAuth timeout - no callback received")
			check_timer.queue_free()
	)
	check_timer.start()

func _on_unlockall_pressed() -> void:
	# Reset all notice acceptances for testing
	#if FileAccess.file_exists(PRIVACY_ACCEPTED_FILE):
	#	DirAccess.remove_absolute(PRIVACY_ACCEPTED_FILE)
	#	print("Privacy acceptance reset")
	
	#if FileAccess.file_exists(TERMS_ACCEPTED_FILE):
	#	DirAccess.remove_absolute(TERMS_ACCEPTED_FILE)
	#	print("Terms acceptance reset")
	
	#if FileAccess.file_exists(GOOGLE_NOTICE_ACCEPTED_FILE):
	#	DirAccess.remove_absolute(GOOGLE_NOTICE_ACCEPTED_FILE)
	#	print("Google notice acceptance reset")
	
	transition_out(func():
		unlock.visible = true
		main_btns.visible = false
		background.visible = false
		bg_2.visible = true
		components.visible = false
		title.visible = false
		version.visible = false
		
		transition_in([bg_2, unlock])
	)

func _unlock_all_content() -> void:
	# Unlock all abilities
	var all_abilities = ["double_jump", "attack", "dash", "shine"]
	for ability in all_abilities:
		SaveManager.data["progress"]["abilities"][ability] = true
	
	# Unlock all levels (3 floors, 3 levels each)
	for floor in range(1, 4):
		for level in range(1, 4):
			var level_key = "%d_%d" % [floor, level]
			SaveManager.data["progress"]["completed_levels"][level_key] = true
	
	# Set progress to the highest level
	SaveManager.data["progress"]["current_floor"] = 3
	SaveManager.data["progress"]["current_level"] = 3
	
	# Set test high scores for all levels (1:00.00 = 60 seconds)
	if not SaveManager.data.has("level_times"):
		SaveManager.data["level_times"] = {}
	
	for floor in range(1, 4):
		for level in range(1, 4):
			var level_key = "%d_%d" % [floor, level]
			SaveManager.data["level_times"][level_key] = 60.0  # 1:00.00
	
	# Calculate and set best run time (9 levels × 60 seconds = 540 seconds = 9:00.00)
	SaveManager.data["best_run_time"] = 540.0
	
	# Save locally only
	SaveManager._save_local()
	
	# Apply abilities to Global
	SaveManager._apply_abilities_to_global()
	
	# Update UI
	_update_start_button_text()
	_update_newgame_button_visibility()
	
	print("All content unlocked locally with test high scores (1:00.00 for each level)")
func _update_newgame_button_visibility() -> void:
	var current_floor = SaveManager.data["progress"]["current_floor"]
	var current_level = SaveManager.data["progress"]["current_level"]
	var has_progress = (current_floor > 1) or (current_floor == 1 and current_level >= 2)
	
	# Continue button always visible at full opacity
	start_continue.visible = true

func _on_newgame_pressed() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	
	# Small delay to show button press visual feedback
	await get_tree().create_timer(0.15).timeout
	
	# Check if user is logged in
	if Global.get_current_user().size() > 0:
		is_transitioning = false  # Reset flag before showing dialog
		transition_out(func():
			main_btns.visible = false
			background.visible = false
			bg_2.visible = true
			new_game_logged_in.visible = true
			title.visible = false  
			version.visible = false
			transition_in([bg_2, new_game_logged_in])
		)
		return
	
	var current_floor = SaveManager.data["progress"]["current_floor"]
	var current_level = SaveManager.data["progress"]["current_level"]
	var has_progress = (current_floor > 1) or (current_floor == 1 and current_level >= 2)
	
	# If no progress, just start the game directly
	if not has_progress:
		# Reset high scores for new game
		SaveManager.reset_level_times()
		Global.is_retrying_level = false
		slide_in_transition("res://scene/floor.tscn")
	else:
		is_transitioning = false  # Reset flag before showing dialog
		transition_out(func():
			main_btns.visible = false
			background.visible = false
			bg_2.visible = true
			new_game_confirm.visible = true
			title.visible = false  
			version.visible = false
			transition_in([bg_2, new_game_confirm])
		)

func _reset_local_save() -> void:
	# Reset SaveManager data to defaults
	SaveManager.data = {
		"progress": {
			"current_floor": 1,
			"current_level": 1,
			"completed_levels": {},
			"abilities": {
				"double_jump": false,
				"attack": false,
				"dash": false,
				"shine": false
			}
		},
		"collectables": [],
		"settings": {},
		"watched_cutscenes": []
	}
	
	# Clear the save file
	if FileAccess.file_exists(SaveManager.SAVE_FILE):
		DirAccess.remove_absolute(SaveManager.SAVE_FILE)
	
	# Save the reset data locally
	SaveManager._save_local()
	
	# Apply defaults to Global
	SaveManager._apply_abilities_to_global()
	
	# Update UI
	_update_start_button_text()
	_update_newgame_button_visibility()
	
	print("Local save completely reset")

func _load_session() -> void:
	"""Load saved session and auto-login if valid"""
	if not FileAccess.file_exists("user://session.json"):
		print("💾 No session file found")
		google.visible = true
		profile.visible = false
		return
	
	var f = FileAccess.open("user://session.json", FileAccess.READ)
	if not f:
		print("❌ Failed to open session file")
		google.visible = true
		profile.visible = false
		return
	
	var text = f.get_as_text()
	f.close()
	
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		print("❌ Invalid session file format")
		google.visible = true
		profile.visible = false
		return
	
	var access = parsed.get("access_token", "")
	var refresh = parsed.get("refresh_token", "")
	var user_data = parsed.get("user", {})
	
	if access == "" or user_data.size() == 0:
		print("❌ Session file incomplete")
		google.visible = true
		profile.visible = false
		return
	
	# Check if we have internet before trying to verify
	if internet_connected:
		print("💾 Session found, verifying with server...")
		_verify_and_restore_session(access, refresh)
	else:
		print("💾 Offline mode: Restoring session without verification")
		# Restore session directly without verification when offline
		Global.set_session(user_data, access, refresh)
		google.visible = false
		profile.visible = true
		_load_cached_profile_image()
		
		# When internet comes back, verify in background
		if not has_node("OnlineCheckTimer"):
			var timer = Timer.new()
			timer.name = "OnlineCheckTimer"
			timer.wait_time = 30.0  # Check every 30 seconds
			timer.autostart = true
			timer.timeout.connect(_check_and_refresh_when_online.bind(access, refresh))
			add_child(timer)

func _verify_and_restore_session(access: String, refresh: String) -> void:
	"""Verify the token is still valid before showing UI"""
	print("🔍 Verifying session...")
	var verify_start = Time.get_ticks_msec()
	
	if http.request_completed.is_connected(_on_verify_session_completed):
		http.request_completed.disconnect(_on_verify_session_completed)
	
	http.request_completed.connect(_on_verify_session_completed.bind(access, refresh, verify_start), CONNECT_ONE_SHOT)
	
	var url = SUPABASE_URL + "/auth/v1/user"
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access
	]
	
	var err = http.request(url, headers, HTTPClient.METHOD_GET)
	
	# If request fails immediately (no internet), restore session anyway
	if err != OK:
		print("⚠️ Network error, restoring session offline")
		_restore_session_offline(access, refresh)

func _check_and_refresh_when_online(access: String, refresh: String) -> void:
	"""Check if online and refresh token if needed"""
	if not internet_connected:
		return
	
	# We're online now, try to refresh the token
	print("🌐 Internet detected, refreshing token...")
	
	# Stop the timer since we're online
	if has_node("OnlineCheckTimer"):
		var timer = get_node("OnlineCheckTimer")
		timer.stop()
		timer.queue_free()
	
	# Try to refresh the token
	_silent_token_refresh(access, refresh)

func _silent_token_refresh(access: String, refresh: String) -> void:
	"""Silently refresh token in background without disrupting user"""
	var refresh_http = HTTPRequest.new()
	add_child(refresh_http)
	
	refresh_http.request_completed.connect(func(result, response_code, headers, body):
		var text = body.get_string_from_utf8()
		
		if response_code == 200:
			var res = JSON.parse_string(text)
			if typeof(res) == TYPE_DICTIONARY and res.has("access_token"):
				print("✅ Token silently refreshed")
				var new_access = res["access_token"]
				var new_refresh = res.get("refresh_token", refresh)
				var current_user = Global.get_current_user()
				Global.set_session(current_user, new_access, new_refresh)
				_save_session(new_access, new_refresh, current_user)
				
				# Sync save data now that we're online
				if current_user.has("id"):
					_background_sync(str(current_user["id"]))
			else:
				print("⚠️ Refresh token invalid or expired")
				_handle_expired_refresh_token()
		elif response_code == 400 or response_code == 401:
			# Refresh token is expired or invalid
			print("❌ Refresh token expired - user needs to log in again")
			_handle_expired_refresh_token()
		else:
			# Network error or other issue - keep user logged in locally
			print("⚠️ Silent refresh failed (%d), keeping user logged in locally" % response_code)
		
		refresh_http.queue_free()
	)
	
	var url = SUPABASE_URL + "/auth/v1/token?grant_type=refresh_token"
	var headers = ["apikey: " + SUPABASE_KEY, "Content-Type: application/json"]
	var req_body = JSON.stringify({"refresh_token": refresh})
	
	refresh_http.request(url, headers, HTTPClient.METHOD_POST, req_body)

func _handle_expired_refresh_token() -> void:
	"""Handle when refresh token has expired - show friendly message"""
	# Don't immediately log out, show a gentle notification
	var dlg := AcceptDialog.new()
	dlg.dialog_text = "Your session has expired.\n\nYour progress is saved locally. Please log in again to sync with the cloud."
	dlg.title = "Session Expired"
	dlg.confirmed.connect(func():
		# Clear session and show login button
		_clear_session_file()
		Global.clear_session()
		google.visible = true
		profile.visible = false
		_update_profile_placeholder()
	)
	add_child(dlg)
	dlg.popup_centered()
	
	# User can still play, just not synced
	print("🎮 User can continue playing locally until they log in again")

func _on_verify_session_completed(result, response_code, headers, body, access, refresh, verify_start):
	var verify_time = Time.get_ticks_msec() - verify_start
	print("⏱️ Session check completed in %d ms (code: %d)" % [verify_time, response_code])
	
	var text = body.get_string_from_utf8()
	
	if response_code == 200:
		var res = JSON.parse_string(text)
		if typeof(res) == TYPE_DICTIONARY:
			print("✅ Session valid:", res.get("email", ""))
			Global.set_session(res, access, refresh)
			
			google.visible = false
			profile.visible = true
			
			var avatar_url = res.get("user_metadata", {}).get("avatar_url", "")
			if avatar_url != "":
				call_deferred("_update_google_profile_image", avatar_url)
			else:
				_load_cached_profile_image()
			
			if res.has("id"):
				var user_id = str(res["id"])
				_background_sync(user_id)
		else:
			_try_refresh_or_stay_offline(access, refresh)
	elif response_code == 401 or response_code == 403:
		print("🔄 Access token expired, trying refresh token...")
		_refresh_stored_token_with_fallback(refresh)
	elif result == HTTPRequest.RESULT_CANT_CONNECT or result == HTTPRequest.RESULT_CANT_RESOLVE or result == HTTPRequest.RESULT_TIMEOUT:
		# Network error - stay logged in offline
		print("📴 Network error - staying logged in offline")
		_restore_session_offline(access, refresh)
	else:
		print("❌ Unexpected error: result=%d, code=%d" % [result, response_code])
		_try_refresh_or_stay_offline(access, refresh)

func _try_refresh_or_stay_offline(access: String, refresh: String) -> void:
	"""Try to refresh token, or stay logged in offline if that fails"""
	if internet_connected:
		print("🔄 Trying to refresh token...")
		_refresh_stored_token_with_fallback(refresh)
	else:
		print("📴 No internet - staying logged in offline")
		_restore_session_offline(access, refresh)

func _restore_session_offline(access: String, refresh: String) -> void:
	"""Restore session from cache when offline"""
	if FileAccess.file_exists("user://session.json"):
		var f = FileAccess.open("user://session.json", FileAccess.READ)
		if f:
			var session_text = f.get_as_text()
			f.close()
			var parsed = JSON.parse_string(session_text)
			if typeof(parsed) == TYPE_DICTIONARY:
				var user_data = parsed.get("user", {})
				if user_data.size() > 0:
					print("✅ Restored session offline for:", user_data.get("email", "User"))
					Global.set_session(user_data, access, refresh)
					google.visible = false
					profile.visible = true
					_load_cached_profile_image()
					
					# Set up listener for when internet comes back
					if not has_node("OnlineCheckTimer"):
						var timer = Timer.new()
						timer.name = "OnlineCheckTimer"
						timer.wait_time = 30.0
						timer.autostart = true
						timer.timeout.connect(_check_and_refresh_when_online.bind(access, refresh))
						add_child(timer)
					return
	
	# If we can't restore, show login
	_session_invalid()

func _refresh_stored_token_with_fallback(refresh: String) -> void:
	"""Refresh token with fallback to offline mode"""
	if refresh == "":
		_session_invalid()
		return
	
	if http.request_completed.is_connected(_on_refresh_stored_token_response):
		http.request_completed.disconnect(_on_refresh_stored_token_response)
	http.request_completed.connect(_on_refresh_token_with_fallback_response.bind(refresh))
	
	var url = SUPABASE_URL + "/auth/v1/token?grant_type=refresh_token"
	var headers = ["apikey: " + SUPABASE_KEY, "Content-Type: application/json"]
	var body = JSON.stringify({"refresh_token": refresh})
	
	print("🔄 Refreshing token...")
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_refresh_token_with_fallback_response(result, response_code, headers, body, original_refresh):
	if http.request_completed.is_connected(_on_refresh_token_with_fallback_response):
		http.request_completed.disconnect(_on_refresh_token_with_fallback_response)
	
	var text = body.get_string_from_utf8()
	
	if response_code == 200:
		var res = JSON.parse_string(text)
		if typeof(res) == TYPE_DICTIONARY and res.has("access_token"):
			print("✅ Token refreshed successfully")
			var new_access = res["access_token"]
			var new_refresh = res.get("refresh_token", Global.refresh_token)
			var current_user = Global.get_current_user()
			Global.set_session(current_user, new_access, new_refresh)
			_save_session(new_access, new_refresh, current_user)
			
			google.visible = false
			profile.visible = true
			return
	
	# Refresh failed
	if response_code == 400 or response_code == 401:
		# Refresh token expired - user MUST log in again
		print("❌ Refresh token expired - showing friendly message")
		_handle_expired_refresh_token()
	else:
		# Network error or other - stay offline
		print("📴 Refresh failed but staying logged in offline (code: %d)" % response_code)
		_restore_session_offline(Global.session_token, original_refresh)

func _refresh_stored_token(refresh: String) -> void:
	"""Refresh token without showing error dialogs"""
	if refresh == "":
		_session_invalid()
		return
	
	if http.request_completed.is_connected(_on_refresh_stored_token_response):
		http.request_completed.disconnect(_on_refresh_stored_token_response)
	http.request_completed.connect(_on_refresh_stored_token_response)
	
	var url = SUPABASE_URL + "/auth/v1/token?grant_type=refresh_token"
	var headers = ["apikey: " + SUPABASE_KEY, "Content-Type: application/json"]
	var body = JSON.stringify({"refresh_token": refresh})
	
	print("Refreshing stored token...")
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_refresh_stored_token_response(result, response_code, headers, body):
	if http.request_completed.is_connected(_on_refresh_stored_token_response):
		http.request_completed.disconnect(_on_refresh_stored_token_response)
	
	var text = body.get_string_from_utf8()
	
	if response_code == 200:
		var res = JSON.parse_string(text)
		if typeof(res) == TYPE_DICTIONARY and res.has("access_token"):
			print("Token refreshed successfully")
			var new_access = res["access_token"]
			var new_refresh = res.get("refresh_token", Global.refresh_token)
			var current_user = Global.get_current_user()
			Global.set_session(current_user, new_access, new_refresh)
			_save_session(new_access, new_refresh, current_user)
			
			google.visible = false
			profile.visible = true
		else:
			_session_invalid()
	else:
		_session_invalid()

func _session_invalid() -> void:
	"""Session is no longer valid, clear and show login"""
	print("Session invalid, clearing...")
	_clear_session_file()
	Global.clear_session()
	google.visible = true
	google.set_process_input(true)
	profile.visible = false

func _process(_delta: float) -> void:
	# Only handle desktop OAuth callback
	if not OS.has_feature("web") and not OS.has_feature("Android"):
		if local_server != null and local_server.is_connection_available():
			auth_connection = local_server.take_connection()
			if auth_connection:
				print("OAuth callback connection received!")

		if auth_connection != null and auth_connection.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			var available = auth_connection.get_available_bytes()
			if available > 0:
				var data = auth_connection.get_string(available)
				_handle_oauth_callback_request(data)
				auth_connection = null

func _check_web_oauth_callback():
	var callback_received = JavaScriptBridge.eval("window.sessionStorage.getItem('oauth_callback_received')")
	
	if callback_received == "true":
		_log_debug("Web OAuth callback detected")
		
		# Get the tokens from sessionStorage using eval
		var access_token = JavaScriptBridge.eval("window.sessionStorage.getItem('oauth_access_token')")
		var refresh_token = JavaScriptBridge.eval("window.sessionStorage.getItem('oauth_refresh_token')")
		
		# Log token safely
		var token_preview = "null"
		if access_token and access_token != "":
			if access_token.length() > 20:
				token_preview = access_token.substr(0, 20)
			else:
				token_preview = access_token
		_log_debug("Retrieved access token: " + token_preview + "...")
		
		# Clear the sessionStorage using eval
		JavaScriptBridge.eval("window.sessionStorage.removeItem('oauth_callback_received')")
		JavaScriptBridge.eval("window.sessionStorage.removeItem('oauth_access_token')")
		JavaScriptBridge.eval("window.sessionStorage.removeItem('oauth_refresh_token')")
		
		# Perform login
		if access_token and access_token != "":
			if refresh_token and refresh_token != "":
				_perform_login(access_token, refresh_token)
			else:
				_perform_login(access_token, "")
		else:
			_show_error("No access token found in callback")

func _periodic_intent_check() -> void:
	if auth_in_progress and OS.has_feature("Android"):
		_check_for_deep_link()

func _update_start_button_text() -> void:
	if start_continue:
		var has_progress = SaveManager.data["progress"]["completed_levels"].size() > 0
		var current_floor = SaveManager.data["progress"]["current_floor"]
		var current_level = SaveManager.data["progress"]["current_level"]
		var is_past_first_level = (current_floor > 1) or (current_floor == 1 and current_level > 1)
		
		#if has_progress or is_past_first_level:
		#	start_button.text = "Continue"
		#else:
		#	start_button.text = "Start Game"
		
#		_update_newgame_button_visibility()

func _start_local_server() -> bool:
	if local_server != null:
		return true
	
	local_server = TCPServer.new()
	
	# Try the default port first
	var port = DESKTOP_CALLBACK_PORT
	var err = local_server.listen(port, "127.0.0.1")
	
	# If default port fails, try finding an available port
	if err != OK:
		print("Port %d unavailable, trying alternative ports..." % port)
		
		# Try ports in range 54321-54330
		for alt_port in range(DESKTOP_CALLBACK_PORT, DESKTOP_CALLBACK_PORT + 10):
			err = local_server.listen(alt_port, "127.0.0.1")
			if err == OK:
				port = alt_port
				print("✅ Using alternative port: %d" % port)
				break
	
	if err != OK:
		push_error("Failed to start local OAuth server: %s" % error_string(err))
		_show_error("Failed to start OAuth server.\n\nPlease close any programs using port %d and try again.\n\nYou can check with:\nWindows: netstat -ano | findstr :%d\nMac/Linux: lsof -i :%d" % [DESKTOP_CALLBACK_PORT, DESKTOP_CALLBACK_PORT, DESKTOP_CALLBACK_PORT])
		local_server = null
		return false
	
	print("✅ Local OAuth server started on http://127.0.0.1:%d" % port)
	return true

func _stop_local_server() -> void:
	if local_server:
		local_server.stop()
		local_server = null
		print("Local OAuth server stopped")

func _handle_oauth_callback_request(request_data: String) -> void:
	print("Received OAuth callback request")
	
	var lines = request_data.split("\n")
	if lines.size() == 0:
		return
	
	var first_line = lines[0]
	var parts = first_line.split(" ")
	
	if parts.size() < 2:
		return
	
	var url_path = parts[1]
	
	if url_path.begins_with("/callback"):
		var response = "HTTP/1.1 200 OK\r\n"
		response += "Content-Type: text/html\r\n"
		response += "Connection: close\r\n\r\n"
		response += """<html>
<head><title>Login Success</title></head>
<body>
<h1>Processing login...</h1>
<p>Please wait while we complete your authentication.</p>
<script>
const fragment = window.location.hash.substring(1);
console.log('Fragment:', fragment);

if (fragment) {
	fetch('/auth?' + fragment)
		.then(() => {
			document.body.innerHTML = '<h1>Login Successful!</h1><p>You can close this window and return to the game.</p>';
			setTimeout(() => window.close(), 2000);
		})
		.catch(err => {
			document.body.innerHTML = '<h1>Error</h1><p>Failed to send auth data to game.</p>';
			console.error(err);
		});
} else {
	document.body.innerHTML = '<h1>Error</h1><p>No authentication data found in URL.</p>';
}
</script>
</body>
</html>"""
		
		if auth_connection:
			auth_connection.put_data(response.to_utf8_buffer())
			auth_connection.disconnect_from_host()
		
		auth_connection = null
	
	elif url_path.begins_with("/auth"):
		print("Received tokens from browser JavaScript")
		_parse_oauth_callback_from_url(url_path)
		
		var response = "HTTP/1.1 200 OK\r\n"
		response += "Content-Type: text/plain\r\n"
		response += "Connection: close\r\n\r\n"
		response += "OK"
		
		if auth_connection:
			auth_connection.put_data(response.to_utf8_buffer())
			auth_connection.disconnect_from_host()
		
		auth_connection = null
		_stop_local_server()

func _parse_oauth_callback_from_url(url_path: String) -> void:
	print("Parsing OAuth URL:", url_path)
	auth_in_progress = false
	
	var fragment = ""
	
	if "#" in url_path:
		var parts = url_path.split("#", true, 1)
		fragment = parts[1] if parts.size() > 1 else ""
	elif "?" in url_path:
		var parts = url_path.split("?", true, 1)
		fragment = parts[1] if parts.size() > 1 else ""
	
	if fragment == "":
		_show_error("No tokens found in OAuth callback")
		return
	
	var params = fragment.split("&")
	var access_token = ""
	var refresh_token = ""
	
	for param in params:
		var kv = param.split("=", true, 1)
		if kv.size() == 2:
			var key = kv[0]
			var value = kv[1]
			
			if key == "access_token":
				access_token = value
			elif key == "refresh_token":
				refresh_token = value
	
	if access_token != "":
		print("Tokens extracted successfully!")
		_perform_login(access_token, refresh_token)
	else:
		_show_error("No access token found in callback")

func _check_android_intent():
	if not Engine.has_singleton("JavaClassWrapper"):
		return
	
	var activity = Engine.get_singleton("JavaClassWrapper")
	if activity == null:
		return
	
	var intent_data = activity.call("getIntent")
	if intent_data:
		var data_string = intent_data.call("getDataString")
		if data_string and data_string.begins_with("io.supabase.godot://"):
			print("Deep link found via JNI:", data_string)
			_parse_oauth_callback(data_string)

func _perform_login(access_token: String, refresh_tok: String = ""):
	print("⚡ Fast login starting...")
	var start_time = Time.get_ticks_msec()
	
	# Immediately show as logged in for better UX
	google.visible = false
	profile.visible = true
	_update_profile_placeholder()
	
	# Disconnect any existing signals first
	if http.request_completed.is_connected(_on_user_info_request_completed):
		http.request_completed.disconnect(_on_user_info_request_completed)
	
	http.request_completed.connect(_on_user_info_request_completed.bind(access_token, refresh_tok, start_time), CONNECT_ONE_SHOT)
	
	var url = SUPABASE_URL + "/auth/v1/user"
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token
	]
	
	var err = http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		print("❌ HTTP request failed immediately:", err)
		_show_error("Network request failed")

func _on_user_info_request_completed(result, response_code, headers, body, access_token, refresh_tok, start_time):
	var elapsed = Time.get_ticks_msec() - start_time
	print("⏱️ User info received in %d ms" % elapsed)
	
	var text = body.get_string_from_utf8()
	
	_log_debug("=== USER INFO RESPONSE ===")
	_log_debug("Response code: " + str(response_code))
	_log_debug("Result: " + str(result))
	_log_debug("Body preview: " + text.substr(0, min(200, text.length())))
	
	if response_code == 200:
		var res = JSON.parse_string(text)
		if typeof(res) == TYPE_DICTIONARY:
			print("✅ Logged in as:", res.get("email", ""))
			Global.set_session(res, access_token, refresh_tok)
			_save_session(access_token, refresh_tok, res)
			
			# Update profile image in background (non-blocking)
			var avatar_url = res.get("user_metadata", {}).get("avatar_url", "")
			if avatar_url != "":
				call_deferred("_update_google_profile_image", avatar_url)
			
			# Sync in background without blocking UI
			if res.has("id"):
				var user_id = str(res["id"])
				_background_sync(user_id)
			
			print("⚡ Total login time: %d ms" % (Time.get_ticks_msec() - start_time))
		else:
			_log_debug("❌ Invalid JSON response")
			_show_error("Invalid user data received")
			_handle_login_failure()
	else:
		_log_debug("❌ Failed response code: " + str(response_code))
		_log_debug("Full error body: " + text)
		
		if response_code == 403 or response_code == 401:
			print("🔄 Token expired, refreshing...")
			_refresh_access_token()
		else:
			_show_error("Login failed (Code: " + str(response_code) + ")\n\nError: " + text.substr(0, 100))
			_handle_login_failure()
func _background_sync(user_id: String) -> void:
	"""Sync data in background without blocking"""
	print("🔄 Background sync starting...")
	var sync_start = Time.get_ticks_msec()
	
	await SaveManager.sync_from_supabase(user_id)
	
	var sync_time = Time.get_ticks_msec() - sync_start
	print("✅ Background sync completed in %d ms" % sync_time)
	
	SaveManager.debug_check_cloud_data()

func _handle_login_failure() -> void:
	google.visible = true
	google.set_process_input(true)
	profile.visible = false
	_update_profile_placeholder()

func _refresh_access_token():
	var stored_refresh = Global.refresh_token
	if stored_refresh == "":
		_show_error("No refresh token stored. Please login again.")
		_handle_refresh_failure()
		return
	
	if http.request_completed.is_connected(_on_refresh_token_response):
		http.request_completed.disconnect(_on_refresh_token_response)
	http.request_completed.connect(_on_refresh_token_response)
	
	var url = SUPABASE_URL + "/auth/v1/token?grant_type=refresh_token"
	var headers = ["apikey: " + SUPABASE_KEY, "Content-Type: application/json"]
	var body = JSON.stringify({"refresh_token": stored_refresh})
	
	print("Refreshing access token...")
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_refresh_token_response(result, response_code, headers, body):
	if http.request_completed.is_connected(_on_refresh_token_response):
		http.request_completed.disconnect(_on_refresh_token_response)
	
	var text = body.get_string_from_utf8()
	
	if response_code == 200:
		var res = JSON.parse_string(text)
		if typeof(res) == TYPE_DICTIONARY and res.has("access_token"):
			print("Access token refreshed")
			var new_access = res["access_token"]
			var new_refresh = res.get("refresh_token", Global.refresh_token)
			var current_user = Global.get_current_user()
			Global.set_session(current_user, new_access, new_refresh)
			_save_session(new_access, new_refresh, current_user)
		else:
			_show_error("Token refresh failed")
			_handle_refresh_failure()
	else:
		_show_error("Token refresh failed (" + str(response_code) + ")")
		_handle_refresh_failure()

func _handle_refresh_failure():
	google.visible = true
	google.set_process_input(true)
	profile.visible = false
	_clear_session_file()
	Global.clear_session()

func _save_session(token: String, refresh: String, user_data: Dictionary) -> void:
	var session = {
		"access_token": token,
		"refresh_token": refresh,
		"user": user_data
	}
	var f = FileAccess.open("user://session.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(session, "\t"))
		f.close()
		print("Session saved")
	else:
		push_error("Failed to save session file")

func _clear_session_file() -> void:
	if FileAccess.file_exists("user://session.json"):
		DirAccess.remove_absolute("user://session.json")
		print("Session deleted")

func _update_google_profile_image(avatar_url: String):
	if avatar_url == "":
		_load_cached_profile_image()  # Try to load from cache first
		if profile.texture == null:
			_update_profile_placeholder()
		return
	
	if not internet_connected:
		print("No internet - using cached profile image")
		_load_cached_profile_image()
		if profile.texture == null:
			_update_profile_placeholder()
		return
	
	var http_avatar = HTTPRequest.new()
	add_child(http_avatar)
	
	http_avatar.request_completed.connect(func(_r, code, _h, body):
		if code == 200:
			var img = Image.new()
			if img.load_jpg_from_buffer(body) == OK or img.load_png_from_buffer(body) == OK:
				profile.texture = ImageTexture.create_from_image(img)
				_save_profile_image_locally(img)  # Save to cache
				print("Profile picture loaded and cached")
			else:
				_load_cached_profile_image()  # Fallback to cache
				if profile.texture == null:
					_update_profile_placeholder()
		else:
			print("Failed to download profile image, using cache")
			_load_cached_profile_image()
			if profile.texture == null:
				_update_profile_placeholder()
		http_avatar.queue_free()
	)
	
	http_avatar.request(avatar_url)

func _save_profile_image_locally(img: Image) -> void:
	var err = img.save_png(PROFILE_IMAGE_PATH)
	if err == OK:
		print("Profile image saved locally")
	else:
		print("Failed to save profile image locally:", err)

func _load_cached_profile_image() -> void:
	if FileAccess.file_exists(PROFILE_IMAGE_PATH):
		var img = Image.new()
		var err = img.load(PROFILE_IMAGE_PATH)
		if err == OK:
			profile.texture = ImageTexture.create_from_image(img)
			print("Loaded cached profile image")
		else:
			print("Failed to load cached profile image:", err)
	else:
		print("No cached profile image found")

func _update_profile_placeholder():
	var img = Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.2, 0.6, 1.0))
	profile.texture = ImageTexture.create_from_image(img)

func _on_profile_pressed() -> void:
	if Global.get_current_user().size() > 0:
		transition_out(func():
			main_btns.visible = false
			background.visible = false
			bg_2.visible = true
			components.visible = false
			logout.visible = true
			title.visible = false  
			version.visible = false
			
			transition_in([bg_2, logout])
		)
			#var dlg := ConfirmationDialog.new()
			#dlg.dialog_text = "Do you want to log out?"
			#dlg.confirmed.connect(func():
			#	Global.clear_session()
			#	_clear_session_file()
				
			#	if FileAccess.file_exists(PROFILE_IMAGE_PATH):
			#		DirAccess.remove_absolute(PROFILE_IMAGE_PATH)
			#		print("Cached profile image deleted")
				
			#	google.visible = true
			#	google.set_process_input(true)
			#	profile.visible = false
			#	_update_profile_placeholder()
				
			#	print("User logged out successfully")
			#	_show_info("Logged out successfully!")
			#)
			#add_child(dlg)
			#dlg.popup_centered()

func _on_control_choice_selected(index: int) -> void:
	Global.control_type = index

func _on_cutscene_choice_selected(index: int) -> void:
	var preference = "play_once" if index == 0 else "always"
	SaveManager.set_setting("cutscene_preference", preference)
	print("Cutscene preference:", preference)

func _on_start_pressed() -> void:
	Global.is_retrying_level = false
	
	if has_node("LoadingScreen"):
		get_node("LoadingScreen").start_loading("res://scene/floor.tscn")
	else:
		get_tree().change_scene_to_file("res://scene/floor.tscn")

func _on_options_pressed() -> void:
	main_btns.visible = false
	settings.visible = true

func _on_exit_pressed() -> void:
		get_tree().quit()

func _on_back_pressed() -> void:
	transition_out(func():
		_ready()
		
		transition_in([background, main_btns, components, title, version])
	)

func _show_error(msg: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.dialog_text = msg
	dlg.title = "Error"
	add_child(dlg)
	dlg.popup_centered()

func _show_info(msg: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.dialog_text = msg
	dlg.title = "Info"
	add_child(dlg)
	dlg.popup_centered()


func _on_settings_pressed() -> void:
	transition_out(func():
		main_btns.visible = false
		background.visible = false
		bg_2.visible = true
		components.visible = false
		settings.visible = true
		title.visible = false
		credits.visible = false
		version.visible = false
		
		transition_in([bg_2, settings])
	)


func _on_cancel_pressed() -> void:
	transition_out(func():
		_ready()
		
		transition_in([background, main_btns, components, title, version])
	)


func _on_yes_pressed() -> void:
	transition_out(func():
		_ready()
		_unlock_all_content()
		
		transition_in([background, main_btns, components, title, version])
	)


func _on_cancel_unlock_pressed() -> void:
	transition_out(func():
		_ready()
		
		transition_in([background, main_btns, components, title, version])
	)


func _on_exit_btn_pressed() -> void:
	transition_out(func():
		main_btns.visible = false
		background.visible = false
		bg_2.visible = true
		components.visible = false
		exit.visible = true
		title.visible = false  
		credits.visible = false
		version.visible = false
		
		transition_in([bg_2, exit])
	)


func _on_back_settings_pressed() -> void:
	transition_out(func():
		_ready()
		
		transition_in([background, main_btns, components, title, version])
	)

func _on_start_continue_pressed() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	# Small delay to show button press visual feedback
	await get_tree().create_timer(0.15).timeout
	
	var current_floor = SaveManager.data["progress"]["current_floor"]
	var current_level = SaveManager.data["progress"]["current_level"]
	var has_progress = (current_floor > 1) or (current_floor == 1 and current_level >= 2)
	
	# Only allow continue if there's actual progress
	if not has_progress:
		transition_out(func():
			main_btns.visible = false
			background.visible = false
			bg_2.visible = true
			continue_pop_up.visible = true
			title.visible = false  
			version.visible = false
		
			transition_in([bg_2, continue_pop_up])
		)
		#var dlg := AcceptDialog.new()
		#dlg.dialog_text = "No progress to continue.\nPlease start a new game first!"
		#dlg.title = "Info"
		
		# Force button back to normal state when dialog closes
		#var reset_button = func():
		#	start_continue.visible = false
		#	await get_tree().process_frame
		#	start_continue.visible = true
		
		#dlg.confirmed.connect(reset_button)
		#dlg.close_requested.connect(reset_button)
		
		#add_child(dlg)
		#dlg.popup_centered()
		return
	
	Global.is_retrying_level = false
	slide_in_transition("res://scene/floor.tscn")

func _on_credits_pressed() -> void:
	transition_out(func():
		main_btns.visible = false
		background.visible = false
		bg_2.visible = true
		components.visible = false
		credits.visible = true
		title.visible = false  
		version.visible = false
		
		transition_in([bg_2, credits])
	)


func _on_exit_credits_pressed() -> void:
	transition_out(func():
		_ready()
		
		transition_in([background, main_btns, components, title, version])
	)

func transition_out(callback: Callable) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Fade out current visible elements
	if main_btns.visible:
		tween.parallel().tween_property(main_btns, "modulate:a", 0.0, 0.3)
	if components.visible:
		tween.parallel().tween_property(components, "modulate:a", 0.0, 0.3)
	if background.visible:
		tween.parallel().tween_property(background, "modulate:a", 0.0, 0.3)
	if title.visible:
		tween.parallel().tween_property(title, "modulate:a", 0.0, 0.3)
	
	tween.tween_callback(callback)

func transition_in(nodes: Array) -> void:
	for node in nodes:
		node.modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	for node in nodes:
		tween.parallel().tween_property(node, "modulate:a", 1.0, 0.3)

func slide_in_transition(scene_path: String) -> void:
	# Preload the next scene
	var next_scene = load(scene_path).instantiate()
	
	# Position it off-screen to the right
	next_scene.position.x = get_viewport_rect().size.x
	next_scene.z_index = 100  # Make sure it's on top
	get_tree().root.add_child(next_scene)
	
	# Create the slide animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Slide next scene in from the right (current scene stays in place)
	tween.tween_property(next_scene, "position:x", 0.0, 0.5)
	
	await tween.finished
	
	# Clean up and switch scenes properly
	get_tree().current_scene = next_scene
	queue_free()


func _on_okay_newgame_pressed() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	# Small delay for visual feedback
	await get_tree().create_timer(0.15).timeout
	
	_reset_local_save()
	#_show_info("Save progress erased. Starting new game...")
	await get_tree().create_timer(1.0).timeout
	Global.is_retrying_level = false
	slide_in_transition("res://scene/floor.tscn")


func _on_logout_pressed() -> void:
	_ready()
	transition_in([background, main_btns, components, title, version])
	Global.clear_session()
	_clear_session_file()
	
	if FileAccess.file_exists(PROFILE_IMAGE_PATH):
		DirAccess.remove_absolute(PROFILE_IMAGE_PATH)
		# print("Cached profile image deleted")
	
	google.visible = true
	google.set_process_input(true)
	profile.visible = false
	_update_profile_placeholder()
	
	# print("User logged out successfully")
	# _show_info("Logged out successfully!")


func _on_play_credits_pressed() -> void:
	# Small delay to show button press visual feedback
	await get_tree().create_timer(0.15).timeout
	
	transition_out(func():
		credits.visible = false
		bg_2.visible = false
		
		# Change to the credits video scene
		get_tree().change_scene_to_file("res://scene/credits.tscn")
	)


func _on_leaderboard_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/leaderboard.tscn")
