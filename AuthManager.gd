extends Node

var supabase := Supabase

func login_with_google() -> void:
	var res = await supabase.auth.sign_in_with_oauth("google", {
		"redirect_to": "https://fsntwndbknzhmotgphtj.supabase.co/auth/v1/callback"
	})
	if res.error:
		print("Google login error:", res.error.message)
	else:
		print("Logged in with Google:", res)

func signup_with_email(email: String, password: String) -> void:
	var res = await supabase.auth.sign_up(email, password)
	if res.error:
		print("Signup failed:", res.error.message)
	else:
		print("Signup success:", res.user.email)

func login_with_email(email: String, password: String) -> void:
	var res = await supabase.auth.sign_in_with_password(email, password)
	if res.error:
		print("Login failed:", res.error.message)
	else:
		print("Login success:", res.user.email)
	await SaveManager.sync_from_supabase(res.user.id)

func logout() -> void:
	await SaveManager.sync_to_supabase(Supabase.auth.current_user.id)
	await supabase.auth.sign_out()
	print("Logged out")
