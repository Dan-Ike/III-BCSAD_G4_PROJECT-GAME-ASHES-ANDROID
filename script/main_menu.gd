extends Control

var pending_deep_link: String = ""
var debug_label: Label = null  


@onready var main_btns: VBoxContainer = $MainBtns
@onready var options: Panel = $Options
@onready var control_choice: OptionButton = $Options/ControlChoice
@onready var google_login: TextureRect = $GoogleLogin
@onready var profile_pic: TextureRect = $ProfilePic
@onready var cutscene_choice: OptionButton = $Options/CutsceneChoice
@onready var start_button: Button = $MainBtns/start
@onready var loading: CanvasLayer = $loading
@onready var newgame: Button = $MainBtns/newgame
@onready var main_menu_4: Sprite2D = $MainBtns/MainMenu4
@onready var unlockall: Button = $unlockall


const SUPABASE_URL = "https://fsntwndbknzhmotgphtj.supabase.co"
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZzbnR3bmRia256aG1vdGdwaHRqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk1NjUwMjAsImV4cCI6MjA3NTE0MTAyMH0.ZJESWD5jcH2rmFodnwHpI_cSsQWqnk1Fk-mmcrjP5mE"

const DESKTOP_CALLBACK_PORT = 54321
const PROFILE_IMAGE_PATH = "user://profile_image.png" 

var internet_connected: bool = false
var checking_internet: bool = false 

@onready var http: HTTPRequest = HTTPRequest.new()
var auth_in_progress: bool = false
var local_server: TCPServer = null
var auth_connection: StreamPeerTCP = null

func _ready() -> void:
	if OS.has_feature("web"):
		var has_tokens = JavaScriptBridge.eval("window.sessionStorage.getItem('oauth_callback_received') === 'true'")
		if has_tokens:
			_log_debug("OAuth tokens found in sessionStorage, deferring callback...")
			add_child(http)  
			call_deferred("_check_web_oauth_callback") 
			return
	
	add_child(http)
	main_btns.visible = true
	options.visible = false
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
	
	google_login.gui_input.connect(_on_google_login_input)
	profile_pic.gui_input.connect(_on_profile_click)
	
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
	profile_pic.material = material
	profile_pic.custom_minimum_size = Vector2(64, 64)
	
# Check internet connectivity first
	_check_internet_connection()
	
	if Global.session_token == "":
		_load_session()
	else:
		google_login.visible = false
		profile_pic.visible = true
		_load_cached_profile_image()  # Load from cache first
		
	if OS.has_feature("Android"):
		_create_debug_label()
	
	if OS.has_feature("Android"):
		_log_debug("Android detected - Setting up deep link handlers")
		call_deferred("_check_for_deep_link")
		
		get_tree().root.connect("focus_entered", _on_app_focus_gained)
	
	_update_start_button_text()
	_update_newgame_button_visibility()

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

func _on_google_login_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check internet first
		if not internet_connected:
			_show_error("No internet connection detected.\n\nPlease connect to the internet to log in with Google.")
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_log_debug("Google Login clicked")
		_log_debug("OS: " + OS.get_name())
		
		if OS.has_feature("Android"):
			auth_in_progress = true
			_log_debug("Starting OAuth flow...")
			_start_google_oauth_flow()
			_show_info("Opening browser for Google login...\n\nAfter selecting your account, you'll be automatically redirected back to the game.")
		elif OS.has_feature("web"):
			auth_in_progress = true
			_log_debug("Starting Web OAuth flow...")
			_start_web_oauth_flow()
		else:
			if _start_local_server():
				auth_in_progress = true
				_start_google_oauth_flow()
				_show_info("Opening browser for Google login...\n\nAfter selecting your account, you'll be automatically logged in!")
			else:
				_show_error("Failed to start local server for OAuth.\nPlease check if port %d is available." % DESKTOP_CALLBACK_PORT)

func _start_web_oauth_flow():
	_log_debug("Starting web OAuth flow...")
	
	var origin = JavaScriptBridge.eval("window.location.origin")
	_log_debug("Origin: " + str(origin))
	
	if origin == null or origin == "":
		_log_debug("Origin is null or empty")
		_show_error("Could not get page origin")
		return
	
	var redirect_url = origin + "/callback.html"
	_log_debug("Redirect: " + redirect_url)
	
	var oauth_url = SUPABASE_URL + "/auth/v1/authorize?provider=google&prompt=select_account&redirect_to=" + redirect_url.uri_encode()
	
	_log_debug("Executing redirect...")
	JavaScriptBridge.eval("window.location.href = '" + oauth_url + "';")
	_log_debug("Redirect sent")

func _start_google_oauth_flow():
	var redirect_url = ""
	
	if OS.has_feature("Android"):
		redirect_url = "io.supabase.godot://login-callback/"
		_log_debug("Android redirect: " + redirect_url)
	else:
		redirect_url = "http://127.0.0.1:%d/callback" % DESKTOP_CALLBACK_PORT
	
	var oauth_url = SUPABASE_URL + "/auth/v1/authorize?provider=google&prompt=select_account&redirect_to=" + redirect_url.uri_encode()
	
	_log_debug("OAuth URL: " + oauth_url)
	_log_debug("Redirect URL: " + redirect_url)
	_log_debug("Opening browser...")
	
	OS.shell_open(oauth_url)

func _on_unlockall_pressed() -> void:
	# Check if user is logged in
	if Global.get_current_user().size() > 0:
		_show_error("Cannot unlock on a logged-in account.\nPlease log out first if you want to use this feature.")
		return
	
	# Show confirmation dialog
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = "Unlock all levels and abilities?\n\nThis is for testing only and will not sync to cloud."
	dlg.confirmed.connect(func():
		_unlock_all_content()
		_show_info("All levels and abilities unlocked!")
	)
	add_child(dlg)
	dlg.popup_centered()

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
	
	# Save locally only
	SaveManager._save_local()
	
	# Apply abilities to Global
	SaveManager._apply_abilities_to_global()
	
	# Update UI
	_update_start_button_text()
	_update_newgame_button_visibility()
	
	print("All content unlocked locally")

func _update_newgame_button_visibility() -> void:
	var has_progress = SaveManager.data["progress"]["completed_levels"].size() > 0
	var current_floor = SaveManager.data["progress"]["current_floor"]
	var current_level = SaveManager.data["progress"]["current_level"]
	var is_past_first_level = (current_floor > 1) or (current_floor == 1 and current_level > 1)
	
	var should_show = has_progress or is_past_first_level
	
	newgame.modulate.a = 1.0 if should_show else 0.0  
	newgame.mouse_filter = Control.MOUSE_FILTER_STOP if should_show else Control.MOUSE_FILTER_IGNORE
	
	main_menu_4.modulate.a = 1.0 if should_show else 0.0

func _on_newgame_pressed() -> void:
	# Check if user is logged in
	if Global.get_current_user().size() > 0:
		_show_error("Cannot reset save progress on a logged-in account.\nPlease log out first if you want to start a new game.")
		return
	
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = "Are you sure you want to start a new game?\n\nThis will erase all your progress."
	dlg.confirmed.connect(func():
		_reset_local_save()
		_show_info("Save progress erased. Starting new game...")
		await get_tree().create_timer(1.0).timeout
		_on_start_pressed()
	)
	add_child(dlg)
	dlg.popup_centered()

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
	if FileAccess.file_exists("user://session.json"):
		var f = FileAccess.open("user://session.json", FileAccess.READ)
		if not f:
			google_login.visible = true
			profile_pic.visible = false
			return
		
		var text = f.get_as_text()
		f.close()
		
		var parsed = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY:
			var access = parsed.get("access_token", "")
			var refresh = parsed.get("refresh_token", "")
			
			if access != "":
				print("💾 Session found, verifying with server...")
				# Don't show UI yet, wait for verification
				_verify_and_restore_session(access, refresh)
				return
	
	# No valid session
	google_login.visible = true
	profile_pic.visible = false

func _verify_and_restore_session(access: String, refresh: String) -> void:
	"""Verify the token is still valid before showing UI"""
	if http.request_completed.is_connected(_on_verify_session_completed):
		http.request_completed.disconnect(_on_verify_session_completed)
	
	http.request_completed.connect(_on_verify_session_completed.bind(access, refresh))
	
	var url = SUPABASE_URL + "/auth/v1/user"
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access
	]
	
	http.request(url, headers, HTTPClient.METHOD_GET)

func _on_verify_session_completed(result, response_code, headers, body, access, refresh):
	if http.request_completed.is_connected(_on_verify_session_completed):
		http.request_completed.disconnect(_on_verify_session_completed)
	
	var text = body.get_string_from_utf8()
	
	if response_code == 200:
		var res = JSON.parse_string(text)
		if typeof(res) == TYPE_DICTIONARY:
			print("Session restored:", res.get("email", ""))
			# Restore session without showing the welcome dialog again
			Global.set_session(res, access, refresh)
			
			google_login.visible = false
			profile_pic.visible = true
			_update_google_profile_image(res.get("user_metadata", {}).get("avatar_url", ""))
			
			# Silently sync in background
			if res.has("id"):
				var user_id = str(res["id"])
				await SaveManager.sync_from_supabase(user_id)
				print("Save data synced with Supabase")
		else:
			_session_invalid()
	else:
		if response_code == 401 or response_code == 403:
			print("Token expired, attempting refresh...")
			_refresh_stored_token(refresh)
		else:
			_session_invalid()

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
			
			google_login.visible = false
			profile_pic.visible = true
		else:
			_session_invalid()
	else:
		_session_invalid()

func _session_invalid() -> void:
	"""Session is no longer valid, clear and show login"""
	print("Session invalid, clearing...")
	_clear_session_file()
	Global.clear_session()
	google_login.visible = true
	profile_pic.visible = false

func _process(_delta: float) -> void:
	# Periodic internet check every 5 seconds
	if not checking_internet:
		if not has_node("InternetCheckTimer"):
			var timer = Timer.new()
			timer.name = "InternetCheckTimer"
			timer.wait_time = 5.0
			timer.autostart = true
			timer.timeout.connect(_check_internet_connection)
			add_child(timer)
	
	if not OS.has_feature("web"):
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
	
	# Check for web OAuth callback (only on web)
	if OS.has_feature("web") and auth_in_progress:
		_check_web_oauth_callback()

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
	if start_button:
		var has_progress = SaveManager.data["progress"]["completed_levels"].size() > 0
		var current_floor = SaveManager.data["progress"]["current_floor"]
		var current_level = SaveManager.data["progress"]["current_level"]
		var is_past_first_level = (current_floor > 1) or (current_floor == 1 and current_level > 1)
		
		if has_progress or is_past_first_level:
			start_button.text = "Continue"
		else:
			start_button.text = "Start Game"
		
		_update_newgame_button_visibility()

func _start_local_server() -> bool:
	if local_server != null:
		return true
	
	local_server = TCPServer.new()
	var err = local_server.listen(DESKTOP_CALLBACK_PORT, "127.0.0.1")
	
	if err != OK:
		push_error("Failed to start local OAuth server on port %d: %s" % [DESKTOP_CALLBACK_PORT, error_string(err)])
		local_server = null
		return false
	
	print("Local OAuth server started on http://127.0.0.1:%d" % DESKTOP_CALLBACK_PORT)
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
	print("Attempting login with access token...")
	
	if http.request_completed.is_connected(_on_user_info_request_completed):
		http.request_completed.disconnect(_on_user_info_request_completed)
	
	http.request_completed.connect(_on_user_info_request_completed.bind(access_token, refresh_tok))
	
	var url = SUPABASE_URL + "/auth/v1/user"
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token
	]
	
	http.request(url, headers, HTTPClient.METHOD_GET)

func _on_user_info_request_completed(result, response_code, headers, body, access_token, refresh_tok):
	if http.request_completed.is_connected(_on_user_info_request_completed):
		http.request_completed.disconnect(_on_user_info_request_completed)
	
	var text = body.get_string_from_utf8()
	
	if response_code == 200:
		var res = JSON.parse_string(text)
		if typeof(res) == TYPE_DICTIONARY:
			print("Logged in as:", res.get("email", ""))
			Global.set_session(res, access_token, refresh_tok)
			_save_session(access_token, refresh_tok, res)
			
			# Hide login button, show profile picture
			google_login.visible = false
			profile_pic.visible = true
			_update_google_profile_image(res.get("user_metadata", {}).get("avatar_url", ""))
			
			if res.has("id"):
				var user_id = str(res["id"])
				await SaveManager.sync_from_supabase(user_id)
				print("Save data synced with Supabase")
				_show_info("Login successful!\nWelcome, " + res.get("email", "User"))
		else:
			_show_error("Invalid user data received")
	else:
		if response_code == 403 or (response_code == 401 and text.find("expired") != -1):
			print("Token expired, attempting refresh...")
			_refresh_access_token()
		else:
			_show_error("Login failed (" + str(response_code) + ")")
			google_login.visible = true
			profile_pic.visible = false

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
	google_login.visible = true
	profile_pic.visible = false
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
		if profile_pic.texture == null:
			_update_profile_placeholder()
		return
	
	if not internet_connected:
		print("No internet - using cached profile image")
		_load_cached_profile_image()
		if profile_pic.texture == null:
			_update_profile_placeholder()
		return
	
	var http_avatar = HTTPRequest.new()
	add_child(http_avatar)
	
	http_avatar.request_completed.connect(func(_r, code, _h, body):
		if code == 200:
			var img = Image.new()
			if img.load_jpg_from_buffer(body) == OK or img.load_png_from_buffer(body) == OK:
				profile_pic.texture = ImageTexture.create_from_image(img)
				_save_profile_image_locally(img)  # Save to cache
				print("Profile picture loaded and cached")
			else:
				_load_cached_profile_image()  # Fallback to cache
				if profile_pic.texture == null:
					_update_profile_placeholder()
		else:
			print("Failed to download profile image, using cache")
			_load_cached_profile_image()
			if profile_pic.texture == null:
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
			profile_pic.texture = ImageTexture.create_from_image(img)
			print("Loaded cached profile image")
		else:
			print("Failed to load cached profile image:", err)
	else:
		print("No cached profile image found")

func _update_profile_placeholder():
	var img = Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.2, 0.6, 1.0))
	profile_pic.texture = ImageTexture.create_from_image(img)

func _on_profile_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Global.get_current_user().size() > 0:
			var dlg := ConfirmationDialog.new()
			dlg.dialog_text = "Do you want to log out?"
			dlg.confirmed.connect(func():
				Global.clear_session()
				_clear_session_file()
				
				if FileAccess.file_exists(PROFILE_IMAGE_PATH):
					DirAccess.remove_absolute(PROFILE_IMAGE_PATH)
					print("Cached profile image deleted")
				
				google_login.visible = true
				profile_pic.visible = false
				_update_profile_placeholder()
				
				print("User logged out successfully")
				_show_info("Logged out successfully!")
			)
			add_child(dlg)
			dlg.popup_centered()

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
	options.visible = true

func _on_exit_pressed() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = "Are you sure you want to exit the game?"
	dlg.title = "Exit Game"
	dlg.confirmed.connect(func():
		get_tree().quit()
	)
	add_child(dlg)
	dlg.popup_centered()

func _on_back_pressed() -> void:
	_ready()

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
