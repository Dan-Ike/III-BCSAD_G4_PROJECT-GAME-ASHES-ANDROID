extends Control

@onready var main_btns: VBoxContainer = $MainBtns
@onready var options: Panel = $Options
@onready var control_choice: OptionButton = $Options/ControlChoice
@onready var google_login: TextureRect = $GoogleLogin
@onready var profile_pic: TextureRect = $ProfilePic

const SUPABASE_URL = "https://fsntwndbknzhmotgphtj.supabase.co"
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZzbnR3bmRia256aG1vdGdwaHRqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk1NjUwMjAsImV4cCI6MjA3NTE0MTAyMH0.ZJESWD5jcH2rmFodnwHpI_cSsQWqnk1Fk-mmcrjP5mE"

@onready var http: HTTPRequest = HTTPRequest.new()

func _ready() -> void:
	add_child(http)
	main_btns.visible = true
	options.visible = false
	MusicManager.play_song("menu")
	control_choice.select(Global.control_type)
	control_choice.item_selected.connect(_on_control_choice_selected)
	google_login.gui_input.connect(_on_google_login_input)
	profile_pic.gui_input.connect(_on_profile_click)
	if Global.get_current_user().size() > 0:
		google_login.visible = false
		_update_google_profile_image(Global.get_avatar_url())
	else:
		google_login.visible = true
		_update_profile_placeholder()
	print("Main menu ready")
	_load_session()
	if OS.has_feature("Android"):
		_check_for_deep_link()
		get_tree().root.focus_entered.connect(_on_app_focus_gained)

func _on_app_focus_gained():
	if OS.has_feature("Android"):
		print("App resumed - checking for deep link")
		_check_for_deep_link()

func _exit_tree():
	if get_tree() and get_tree().root and get_tree().root.focus_entered.is_connected(_on_app_focus_gained):
		get_tree().root.focus_entered.disconnect(_on_app_focus_gained)

#android deep link handler
func _check_for_deep_link():
	"""Check if app was opened via OAuth deep link"""
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		return
	var args = OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with("io.supabase.godot://"):
			print("Deep link detected:", arg)
			_parse_oauth_callback(arg)
			return
	var cmdline_user = OS.get_cmdline_user_args()
	for arg in cmdline_user:
		if typeof(arg) == TYPE_STRING and arg.begins_with("io.supabase.godot://"):
			print("Deep link detected in user args:", arg)
			_parse_oauth_callback(arg)
			return

func _parse_oauth_callback(url: String):
	"""Parse tokens from OAuth callback URL"""
	print("Parsing OAuth URL:", url)
	var tokens_part = ""
	if "#" in url:
		tokens_part = url.split("#")[1] if url.split("#").size() > 1 else ""
	elif "?" in url:
		tokens_part = url.split("?")[1] if url.split("?").size() > 1 else ""
	if tokens_part == "":
		_show_error("Invalid OAuth callback URL - no tokens found")
		return
	var params = tokens_part.split("&")
	var access_token = ""
	var refresh_tok = ""
	for param in params:
		var kv = param.split("=")
		if kv.size() == 2:
			if kv[0] == "access_token":
				access_token = kv[1]
			elif kv[0] == "refresh_token":
				refresh_tok = kv[1]
	if access_token != "":
		print("Tokens extracted from deep link")
		_perform_login(access_token, refresh_tok)
	else:
		_show_error("No access token found in callback")

#google login
func _on_google_login_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("Google Login clicked")
		if OS.has_feature("Android"):
			_start_google_oauth_flow()
			_show_info("Opening browser...\nAfter logging in, return to the app.")
		else:
			_login_with_pasted_token()
			_start_google_oauth_flow()

func _start_google_oauth_flow():
	var redirect_url = ""
	if OS.has_feature("Android"):
		redirect_url = "io.supabase.godot://login-callback/"
	else:
		redirect_url = SUPABASE_URL + "/auth/v1/callback"
	var oauth_url = SUPABASE_URL + "/auth/v1/authorize?provider=google&prompt=select_account&redirect_to=" + redirect_url
	OS.shell_open(oauth_url)

#manual login for desktop
func _login_with_pasted_token():
	if not (OS.get_name() in ["Windows","Linux","macOS"]):
		_show_error("Paste Token login only works on desktop.")
		return
	var dlg := AcceptDialog.new()
	var vbox := VBoxContainer.new()
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)
	var line_access := LineEdit.new()
	line_access.placeholder_text = "Paste access_token here"
	line_access.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line_refresh := LineEdit.new()
	line_refresh.placeholder_text = "Paste refresh_token here"
	line_refresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(line_access)
	vbox.add_child(line_refresh)
	dlg.add_child(vbox)
	dlg.title = "Manual Login (Desktop Only)"
	dlg.get_ok_button().text = "Login"
	dlg.confirmed.connect(func():
		var access = line_access.text.strip_edges()
		var refresh = line_refresh.text.strip_edges()
		if access == "":
			_show_error("Access token is required!")
			return
		if refresh == "":
			print("No refresh token provided - you'll need to re-login after 1 hour")
		_perform_login(access, refresh)
	)
	add_child(dlg)
	dlg.popup_centered()


func _perform_login(access_token: String, refresh_tok: String = ""):
	if http.request_completed.is_connected(_on_user_info_request_completed):
		http.request_completed.disconnect(_on_user_info_request_completed)
	http.request_completed.connect(_on_user_info_request_completed.bind(access_token, refresh_tok))
	var url = SUPABASE_URL + "/auth/v1/user"
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token
	]
	print("Fetching user info with access token")
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
			google_login.visible = false
			_update_google_profile_image(res.get("user_metadata", {}).get("avatar_url", ""))
			if res.has("id"):
				var user_id = str(res["id"])
				await SaveManager.sync_from_supabase(user_id)
				print("Synced save data with Supabase for user:", user_id)
		else:
			_show_error("Invalid user data received")
	else:
		if response_code == 403 or (response_code == 401 and text.find("expired") != -1):
			print("Token expired, trying refresh…")
			_refresh_access_token()
		else:
			_show_error("Login failed (" + str(response_code) + "): " + text)
			google_login.visible = true
			_update_profile_placeholder()

func _refresh_access_token():
	var stored_refresh = Global.refresh_token
	if stored_refresh == "":
		_show_error("No refresh token stored, please login again.")
		google_login.visible = true
		_update_profile_placeholder()
		_clear_session_file()
		Global.clear_session()
		return
	if http.request_completed.is_connected(_on_refresh_token_response):
		http.request_completed.disconnect(_on_refresh_token_response)
	http.request_completed.connect(_on_refresh_token_response)
	var url = SUPABASE_URL + "/auth/v1/token?grant_type=refresh_token"
	var headers = ["apikey: " + SUPABASE_KEY, "Content-Type: application/json"]
	var body = JSON.stringify({"refresh_token": stored_refresh})
	print("Attempting to refresh access token")
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_refresh_token_response(result, response_code, headers, body):
	if http.request_completed.is_connected(_on_refresh_token_response):
		http.request_completed.disconnect(_on_refresh_token_response)
	var text = body.get_string_from_utf8()
	if response_code == 200:
		var res = JSON.parse_string(text)
		if typeof(res) == TYPE_DICTIONARY and res.has("access_token"):
			print("Successfully refreshed access token")
			var new_access = res["access_token"]
			var new_refresh = res.get("refresh_token", Global.refresh_token)
			var current_user = Global.get_current_user()
			Global.set_session(current_user, new_access, new_refresh)
			_save_session(new_access, new_refresh, current_user)
			print("🔑 Token refreshed successfully!")
		else:
			_show_error("⚠️ Refresh failed: Invalid response")
			_handle_refresh_failure()
	else:
		_show_error("❌ Refresh failed (" + str(response_code) + "): " + text)
		_handle_refresh_failure()

func _handle_refresh_failure():
	"""Handle failed refresh - clear session and show login"""
	google_login.visible = true
	_update_profile_placeholder()
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
		print("Session saved to file")
	else:
		push_error("Failed to save session file")

func _load_session() -> void:
	if FileAccess.file_exists("user://session.json"):
		var f = FileAccess.open("user://session.json", FileAccess.READ)
		if not f:
			print("Could not open session file")
			return
		var text = f.get_as_text()
		f.close()
		var parsed = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY:
			var access = parsed.get("access_token", "")
			var refresh = parsed.get("refresh_token", "")
			if access != "":
				print("Session found, attempting auto-login...")
				_perform_login(access, refresh)
			else:
				print("Session file exists but has no access token")
		else:
			print("Could not parse session file")

func _clear_session_file() -> void:
	"""Delete the session file"""
	if FileAccess.file_exists("user://session.json"):
		DirAccess.remove_absolute("user://session.json")
		print("Session file deleted")

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
			print("Google profile picture loaded.")
		else:
			print("Failed to load profile picture")
			_update_profile_placeholder()
		http_avatar.queue_free()
	)
	http_avatar.request(avatar_url)

func _update_profile_placeholder():
	var img = Image.new()
	img.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.2, 0.6, 1.0))
	profile_pic.texture = ImageTexture.create_from_image(img)
	print("Placeholder profile loaded!")

#logout
func _on_profile_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if Global.get_current_user().size() > 0:
			var dlg := ConfirmationDialog.new()
			dlg.dialog_text = "Do you want to log out?"
			dlg.confirmed.connect(func():
				Global.clear_session()
				_clear_session_file()
				google_login.visible = true
				_update_profile_placeholder()
				print("🔴 User logged out successfully")
			)
			add_child(dlg)
			dlg.popup_centered()

#controls
func _on_control_choice_selected(index: int) -> void:
	Global.control_type = index

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/floor.tscn")

func _on_options_pressed() -> void:
	main_btns.visible = false
	options.visible = true

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_back_pressed() -> void:
	_ready()

#error
func _show_error(msg: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.dialog_text = msg
	add_child(dlg)
	dlg.popup_centered()

func _show_info(msg: String) -> void:
	"""Show info message to user"""
	var dlg := AcceptDialog.new()
	dlg.dialog_text = msg
	dlg.title = "Info"
	add_child(dlg)
	dlg.popup_centered()
