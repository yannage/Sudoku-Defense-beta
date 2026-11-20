extends "res://scripts/main.gd"

const DemoGuide = preload("res://demo/demo_guide.gd")
const STORE_PAGE := "https://store.steampowered.com/app/3721150/"

func _ready() -> void:
	tutorial = DemoGuide.new()
	mode_choice = "freeplay"
	pace_choice = "untimed"
	super._ready()
	if "--smoke-test" in OS.get_cmdline_user_args(): print("SUDOKU_DEFENSE_DEMO_READY")

# Rounds are single-session. Device preferences still use the Demo's user:// root.
func _configure_profiles(_status: Dictionary) -> void:
	pass

func _save() -> bool:
	return true

func _new_achievement_run_id() -> String:
	return ""

func _observe_achievements() -> void:
	pass

func _can_replace_saved_run() -> bool:
	return true

func _show_menu(initial: bool = false) -> void:
	if has_active_run and not initial:
		_show_pause_menu()
		return
	var box := _modal(620,600)
	box.add_child(label("Sudoku Defense Demo",32,WHITE))
	var intro := label("Play one board and defend it. Each correct answer grows a tower and helps shape the enemy route.",18,MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)
	var guide := button("Play the guided first wave",_start_demo_guide,true)
	box.add_child(guide)
	box.add_child(button("Play a fresh board without guidance",_start_fresh_board))
	box.add_child(button("Settings",_show_settings.bind(true)))
	box.add_child(button("View the full game on Steam",_view_full_game))
	box.add_child(button("Quit demo",_request_quit))
	guide.grab_focus()

func _start_demo_guide() -> void:
	if tutorial.active: tutorial.restore()
	has_active_run = false
	tutorial.start(self)

func _start_fresh_board() -> void:
	mode_choice = "freeplay"
	_start_run()

func _show_pause_menu() -> void:
	var box := _modal(620,620)
	box.add_child(label("Demo paused",29,WHITE))
	var resume := button("Resume",_close_overlay,true)
	box.add_child(resume)
	if run.phase in ["solve","prep"]:
		box.add_child(button("Wave intel",_show_wave_intel))
	box.add_child(button("Manage gear",func(): _open_management("bag")))
	box.add_child(button("Open chests",func(): _open_management("loot")))
	box.add_child(button("Settings",_show_settings.bind(false)))
	box.add_child(button("Return to demo menu",_leave_round))
	box.add_child(button("Quit demo",_request_quit))
	resume.grab_focus()

func _leave_round() -> void:
	if tutorial.active: tutorial.restore()
	dock.reset_for_run()
	has_active_run = false
	_show_menu(true)

func _show_result() -> void:
	if tutorial.active:
		tutorial.show_step()
		return
	_show_demo_end(run.phase == "won",run.score)

func _show_demo_end(defended: bool, final_score: int) -> void:
	# A back press on the result returns to the demo menu.
	has_active_run = false
	var box := _modal(640,540)
	box.add_child(label("Wave cleared!" if defended else "The core fell",30,MINT if defended else AMBER))
	box.add_child(label("Demo complete   ·   Score %d" % final_score,18,WHITE))
	var description := label("Try another puzzle and see how a different set of towers changes the route. The full campaign carries your gear and upgrades across up to 50 rounds.",17,MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	var replay := button("Play a fresh board",_start_fresh_board,true)
	box.add_child(replay)
	box.add_child(button("Buy or wishlist on Steam",_view_full_game))
	box.add_child(button("Return to demo menu",func(): _show_menu(true)))
	box.add_child(button("Quit demo",_request_quit))
	replay.grab_focus()

func _view_full_game() -> void:
	if OS.shell_open(STORE_PAGE) != OK: _toast("Find Sudoku Defense by Yak Studios on Steam.",false)
