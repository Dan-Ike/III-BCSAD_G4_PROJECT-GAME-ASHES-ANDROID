extends Control

@onready var main_btns: VBoxContainer = $MainBtns
@onready var options: Panel = $Options
@onready var control_choice: OptionButton = $Options/ControlChoice
@onready var google_login: TextureRect = $GoogleLogin
@onready var profile_pic: TextureRect = $ProfilePic
@onready var cutscene_choice: OptionButton = $Options/CutsceneChoice
@onready var start_button: Button = $MainBtns/start
@onready var loading: CanvasLayer = $loading

const SUPABASE_URL = "https://fsntwndbknzhmotgphtj.supabase.co"
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZzbnR3bmRia256aG1vdGdwaHRqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk1NjUwMjAsImV4cCI6MjA3NTE0MTAyMH0.ZJESWD5jcH2rmFodnwHpI_cSsQWqnk1Fk-mmcrjP5mE"

const DESKTOP_CALLBACK_PORT = 54321

@onready var http: HTTPRequest = HTTPRequest.new()
var auth_in_progress: bool = false
var local_server: TCPServer = null
var auth_connection: StreamPeerTCP = null

func _ready() -> void:
	
	add_child(http)
	main_btns.visible = true
	options.visible = false
	MusicManager.play_song("menu")
	control_choice.select(Global.control_type)
	control_choice.item_selected.connect(_on_control_choice_selected)
	
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
	
	# Make profile picture circular
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
	
	# Only load session if not already authenticated
# Only load session if not already authenticated
	if Global.session_token == "":
		_load_session()
	else:
		# Already have valid session, just show UI
		google_login.visible = false
		profile_pic.visible = true
		_update_google_profile_image(Global.get_current_user().get("user_metadata", {}).get("avatar_url", ""))
	# For Android: Check for deep link on startup
	if OS.has_feature("Android"):
		print("🤖 Android detected - Setting up deep link handlers")
		_check_for_deep_link()
		
		var intent_timer = Timer.new()
		intent_timer.name = "IntentCheckTimer"
		add_child(intent_timer)
		intent_timer.timeout.connect(_periodic_intent_check)
		intent_timer.start(0.5)
	
	_update_start_button_text()

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
			print("✅ Session restored:", res.get("email", ""))
			# Restore session without showing the welcome dialog again
			Global.set_session(res, access, refresh)
			
			google_login.visible = false
			profile_pic.visible = true
			_update_google_profile_image(res.get("user_metadata", {}).get("avatar_url", ""))
			
			# Silently sync in background
			if res.has("id"):
				var user_id = str(res["id"])
				await SaveManager.sync_from_supabase(user_id)
				print("✅ Save data synced with Supabase")
		else:
			_session_invalid()
	else:
		if response_code == 401 or response_code == 403:
			print("🔄 Token expired, attempting refresh...")
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
	
	print("🔄 Refreshing stored token...")
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_refresh_stored_token_response(result, response_code, headers, body):
	if http.request_completed.is_connected(_on_refresh_stored_token_response):
		http.request_completed.disconnect(_on_refresh_stored_token_response)
	
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
			
			google_login.visible = false
			profile_pic.visible = true
		else:
			_session_invalid()
	else:
		_session_invalid()

func _session_invalid() -> void:
	"""Session is no longer valid, clear and show login"""
	print("❌ Session invalid, clearing...")
	_clear_session_file()
	Global.clear_session()
	google_login.visible = true
	profile_pic.visible = false

func _process(_delta: float) -> void:
	if local_server != null and local_server.is_connection_available():
		auth_connection = local_server.take_connection()
		if auth_connection:
			print("🔔 OAuth callback connection received!")

	if auth_connection != null and auth_connection.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var available = auth_connection.get_available_bytes()
		if available > 0:
			var data = auth_connection.get_string(available)
			_handle_oauth_callback_request(data)
			auth_connection = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		print("🔔 App resumed - checking for OAuth callback")
		if OS.has_feature("Android") and auth_in_progress:
			call_deferred("_check_for_deep_link")

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

func _exit_tree():
	_stop_local_server()
	
	if has_node("IntentCheckTimer"):
		var timer = get_node("IntentCheckTimer")
		if timer.timeout.is_connected(_periodic_intent_check):
			timer.timeout.disconnect(_periodic_intent_check)

# ============================================================================
# DESKTOP LOCAL SERVER
# ============================================================================
func _start_local_server() -> bool:
	if local_server != null:
		return true
	
	local_server = TCPServer.new()
	var err = local_server.listen(DESKTOP_CALLBACK_PORT, "127.0.0.1")
	
	if err != OK:
		push_error("Failed to start local OAuth server on port %d: %s" % [DESKTOP_CALLBACK_PORT, error_string(err)])
		local_server = null
		return false
	
	print("✅ Local OAuth server started on http://127.0.0.1:%d" % DESKTOP_CALLBACK_PORT)
	return true

func _stop_local_server() -> void:
	if local_server:
		local_server.stop()
		local_server = null
		print("🛑 Local OAuth server stopped")

func _handle_oauth_callback_request(request_data: String) -> void:
	print("📨 Received OAuth callback request")
	
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
<h1>🔐 Processing login...</h1>
<p>Please wait while we complete your authentication.</p>
<script>
const fragment = window.location.hash.substring(1);
console.log('Fragment:', fragment);

if (fragment) {
	fetch('/auth?' + fragment)
		.then(() => {
			document.body.innerHTML = '<h1>✅ Login Successful!</h1><p>You can close this window and return to the game.</p>';
			setTimeout(() => window.close(), 2000);
		})
		.catch(err => {
			document.body.innerHTML = '<h1>❌ Error</h1><p>Failed to send auth data to game.</p>';
			console.error(err);
		});
} else {
	document.body.innerHTML = '<h1>❌ Error</h1><p>No authentication data found in URL.</p>';
}
</script>
</body>
</html>"""
		
		if auth_connection:
			auth_connection.put_data(response.to_utf8_buffer())
			auth_connection.disconnect_from_host()
		
		auth_connection = null
	
	elif url_path.begins_with("/auth"):
		print("✅ Received tokens from browser JavaScript")
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
	print("🔍 Parsing OAuth URL:", url_path)
	auth_in_progress = false
	
	var fragment = ""
	
	if "#" in url_path:
		var parts = url_path.split("#", true, 1)
		fragment = parts[1] if parts.size() > 1 else ""
	elif "?" in url_path:
		var parts = url_path.split("?", true, 1)
		fragment = parts[1] if parts.size() > 1 else ""
	
	if fragment == "":
		_show_error("❌ No tokens found in OAuth callback")
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
		print("✅ Tokens extracted successfully!")
		_perform_login(access_token, refresh_token)
	else:
		_show_error("❌ No access token found in callback")

# ============================================================================
# ANDROID DEEP LINK HANDLER
# ============================================================================
func _check_for_deep_link():
	if not OS.has_feature("Android"):
		return
	
	var args = OS.get_cmdline_args()
	for arg in args:
		if typeof(arg) == TYPE_STRING and arg.begins_with("io.supabase.godot://"):
			print("✅ Deep link found in cmdline_args:", arg)
			_parse_oauth_callback(arg)
			return
	
	var user_args = OS.get_cmdline_user_args()
	for arg in user_args:
		if typeof(arg) == TYPE_STRING and arg.begins_with("io.supabase.godot://"):
			print("✅ Deep link found in user_args:", arg)
			_parse_oauth_callback(arg)
			return
	
	if OS.has_feature("Android") and Engine.has_singleton("JavaClassWrapper"):
		_check_android_intent()

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
			print("✅ Deep link found via JNI:", data_string)
			_parse_oauth_callback(data_string)

func _parse_oauth_callback(url: String):
	print("🔍 Parsing Android OAuth callback URL...")
	auth_in_progress = false
	
	var fragment = ""
	
	if "#" in url:
		var parts = url.split("#", true, 1)
		fragment = parts[1] if parts.size() > 1 else ""
	elif "?" in url:
		var parts = url.split("?", true, 1)
		fragment = parts[1] if parts.size() > 1 else ""
	
	if fragment == "":
		_show_error("❌ No tokens found in OAuth callback URL")
		return
	
	print("📦 Fragment data:", fragment)
	
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
		print("✅ Tokens extracted successfully!")
		_perform_login(access_token, refresh_token)
	else:
		_show_error("❌ No access token found in callback")

# ============================================================================
# GOOGLE LOGIN
# ============================================================================
func _on_google_login_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("🔐 Google Login clicked")
		
		if OS.has_feature("Android"):
			auth_in_progress = true
			_start_google_oauth_flow()
			_show_info("🌐 Opening browser for Google login...\n\n✅ After selecting your account, you'll be automatically redirected back to the game.")
		else:
			if _start_local_server():
				auth_in_progress = true
				_start_google_oauth_flow()
				_show_info("🌐 Opening browser for Google login...\n\n✅ After selecting your account, you'll be automatically logged in!")
			else:
				_show_error("❌ Failed to start local server for OAuth.\nPlease check if port %d is available." % DESKTOP_CALLBACK_PORT)

func _start_google_oauth_flow():
	var redirect_url = ""
	
	if OS.has_feature("Android"):
		redirect_url = "io.supabase.godot://login-callback/"
	else:
		redirect_url = "http://127.0.0.1:%d/callback" % DESKTOP_CALLBACK_PORT
	
	# ALWAYS ask for account selection with prompt=select_account
	var oauth_url = SUPABASE_URL + "/auth/v1/authorize?provider=google&prompt=select_account&redirect_to=" + redirect_url.uri_encode()
	
	print("🌐 Opening OAuth URL:", oauth_url)
	print("📍 Redirect URL:", redirect_url)
	OS.shell_open(oauth_url)

# ============================================================================
# LOGIN EXECUTION
# ============================================================================
func _perform_login(access_token: String, refresh_tok: String = ""):
	print("🔑 Attempting login with access token...")
	
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
			print("✅ Logged in as:", res.get("email", ""))
			Global.set_session(res, access_token, refresh_tok)
			_save_session(access_token, refresh_tok, res)
			
			# Hide login button, show profile picture
			google_login.visible = false
			profile_pic.visible = true
			_update_google_profile_image(res.get("user_metadata", {}).get("avatar_url", ""))
			
			if res.has("id"):
				var user_id = str(res["id"])
				await SaveManager.sync_from_supabase(user_id)
				print("✅ Save data synced with Supabase")
				_show_info("✅ Login successful!\nWelcome, " + res.get("email", "User"))
		else:
			_show_error("❌ Invalid user data received")
	else:
		if response_code == 403 or (response_code == 401 and text.find("expired") != -1):
			print("🔄 Token expired, attempting refresh...")
			_refresh_access_token()
		else:
			_show_error("❌ Login failed (" + str(response_code) + ")")
			google_login.visible = true
			profile_pic.visible = false

# ============================================================================
# TOKEN REFRESH
# ============================================================================
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
	
	print("🔄 Refreshing access token...")
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_refresh_token_response(result, response_code, headers, body):
	if http.request_completed.is_connected(_on_refresh_token_response):
		http.request_completed.disconnect(_on_refresh_token_response)
	
	var text = body.get_string_from_utf8()
	
	if response_code == 200:
		var res = JSON.parse_string(text)
		if typeof(res) == TYPE_DICTIONARY and res.has("access_token"):
			print("✅ Access token refreshed")
			var new_access = res["access_token"]
			var new_refresh = res.get("refresh_token", Global.refresh_token)
			var current_user = Global.get_current_user()
			Global.set_session(current_user, new_access, new_refresh)
			_save_session(new_access, new_refresh, current_user)
		else:
			_show_error("⚠️ Token refresh failed")
			_handle_refresh_failure()
	else:
		_show_error("❌ Token refresh failed (" + str(response_code) + ")")
		_handle_refresh_failure()

func _handle_refresh_failure():
	google_login.visible = true
	profile_pic.visible = false
	_clear_session_file()
	Global.clear_session()

# ============================================================================
# SESSION PERSISTENCE
# ============================================================================
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
		print("💾 Session saved")
	else:
		push_error("Failed to save session file")

func _clear_session_file() -> void:
	if FileAccess.file_exists("user://session.json"):
		DirAccess.remove_absolute("user://session.json")
		print("🗑️ Session deleted")

# ============================================================================
# PROFILE IMAGE
# ============================================================================
func _update_google_profile_image(avatar_url: String):
	if avatar_url == "":
		_update_profile_placeholder()
		return
	
	var http_avatar = HTTPRequest.new()
	add_child(http_avatar)
	
	http_avatar.request_completed.connect(func(_r, _code, _h, body):
		var img = Image.new()
		if img.load_jpg_from_buffer(body) == OK or img.load_png_from_buffer(body) == OK:
			profile_pic.texture = ImageTexture.create_from_image(img)
			print("🖼️ Profile picture loaded")
		else:
			_update_profile_placeholder()
		http_avatar.queue_free()
	)
	
	http_avatar.request(avatar_url)

func _update_profile_placeholder():
	var img = Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.2, 0.6, 1.0))
	profile_pic.texture = ImageTexture.create_from_image(img)

# ============================================================================
# LOGOUT
# ============================================================================
func _on_profile_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Global.get_current_user().size() > 0:
			var dlg := ConfirmationDialog.new()
			dlg.dialog_text = "Do you want to log out?"
			dlg.confirmed.connect(func():
				# Clear session
				Global.clear_session()
				_clear_session_file()
				
				# Update UI
				google_login.visible = true
				profile_pic.visible = false
				_update_profile_placeholder()
				
				print("🔴 User logged out successfully")
				_show_info("✅ Logged out successfully!")
			)
			add_child(dlg)
			dlg.popup_centered()

# ============================================================================
# UI HANDLERS
# ============================================================================
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
	get_tree().quit()

func _on_back_pressed() -> void:
	_ready()

# ============================================================================
# ERROR/INFO DIALOGS
# ============================================================================
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
