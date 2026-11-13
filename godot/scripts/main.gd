extends Node3D

const RunScript = preload("res://scripts/run.gd")
const BoardScript = preload("res://scripts/board.gd")
const CanvasBoardScript = preload("res://scripts/board_canvas.gd")
const RenderProfile = preload("res://scripts/render_profile.gd")
const DockScript = preload("res://scripts/dock.gd")
const SoundScript = preload("res://scripts/sound.gd")
const DropScript = preload("res://scripts/board_drop.gd")
const ControllerScript = preload("res://scripts/controller_input.gd")
const ControllerCursorScript = preload("res://scripts/controller_cursor.gd")
const SeedPointerScript = preload("res://scripts/seed_pointer.gd")
const QuickIconScript = preload("res://scripts/quick_icon.gd")
const GearFeedbackScript = preload("res://scripts/gear_feedback.gd")
const WrongGuessFeedbackScript = preload("res://scripts/wrong_guess_feedback.gd")
const UISkin = preload("res://scripts/ui_skin.gd")
const MenuChoice = preload("res://scripts/menu_choice.gd")
const MenuArt = preload("res://scripts/menu_diorama.gd")
const PreferencesScript = preload("res://scripts/preferences.gd")
const FirstRoundGuide = preload("res://scripts/first_round_guide.gd")
const RunSaveScript = preload("res://scripts/run_save.gd")
const StrategyFeedback = preload("res://scripts/strategy_feedback.gd")
const SteamPlatform = preload("res://scripts/steam_platform.gd")
const CloudProfile = preload("res://scripts/cloud_profile.gd")
const AchievementProfile = preload("res://scripts/achievement_profile.gd")
const PlatformUI = preload("res://scripts/platform_ui.gd")
const INK := Color("0a1722")
const PANEL := Color("112634")
const MINT := Color("83e7c1")
const AMBER := Color("ffb577")
const WHITE := Color("eef6ec")
const MUTED := Color("89a5ae")
const COLORS := [Color("6de8ff"), Color("a4c7ff"), Color("c6a0ff"), Color("ffae68"), Color("fb86c3"), Color("9be878"), Color("ffe188"), Color("bb9bff"), Color("dec3ed")]

var run = RunScript.new()
var world
var sound
var dock
var ui: Control
var overlay: Control
var notice: Label
var notice_time := 0.0
var selected_cell := -1
var selected_number := 0
var armed_item := ""
var menu_open := true
var has_active_run := false
var manual_pause := false
var muted := false
var master_volume := 0.85
var music_volume := 1.0
var effects_volume := 1.0
var reduced_motion := false
var board_notes := true
var auto_open_chests := false
var reserve_mode := false
var preferences = PreferencesScript.new()
var tutorial = FirstRoundGuide.new()
var run_save = RunSaveScript.new()
var steam_platform
var cloud_profile = CloudProfile.new()
var achievements = AchievementProfile.new()
var platform_ui = PlatformUI.new()
var cloud_profile_status: Dictionary = {}
var achievement_save_failed := false
var _profile_base := "user://"
var _injected_run_path := ""
var save_failed := false
var save_recovered := false
var game_speed := 1.0
var cleanup_fast := false
var last_phase := ""
var ui_elapsed := 0.0
var controller_used := false
var _pointer_hint_owner := -2 # -1 mouse, >=0 native touch, -2 no pending handoff
var controller
const FeedbackUIScript = preload("res://scripts/feedback_ui.gd")
var feedback_ui = FeedbackUIScript.new()
const ControllerBindings = preload("res://scripts/controller_bindings.gd")
var _bindings_draft: Dictionary = {}
var _binding_target := ""
var _binding_message := ""
var controller_cursor
var _cursor_gesture_canceled := false
var _controller_number_cell := -1
var _controller_number_phase := ""
var seed_pointer
var board_input
var gear_feedback
var wrong_guess_feedback
var penalty_notice_remaining := 0.0
var _seed_text := ""
var _seed_editing := false
var _seed_return_initial := true
var save_elapsed := 0.0
var header: Label
var resources: Label
var phase_label: Label
var phase_detail: Label
var progress: ProgressBar
var next_button: Button
var bag_button: Button
var loot_button: Button
var selected_label: Label
var candidate_label: Label
var pause_label: Label
var controls_label: Label
var reserve_button: Button
var number_buttons: Array[Button] = []
var phase_badges: Array[Label] = []
var mode_choice := "campaign"
var puzzle_choice := "easy"
var combat_choice := "easy"
var seed_input: LineEdit
var hud_nodes: Dictionary = {}
var portrait_layout := false
var tools_open := false
var board_rect := Rect2(246,118,838,562)
var layout_size := Vector2.ZERO
var _layout_queued := false
var _dock_was_open := false
var _notice_replaces_context := false
var camera_mode := false
var _camera_axis := Vector2.ZERO
var _camera_keys: Dictionary = {}
var _camera_window_focused := true
var _steam_overlay_active := false
const CAMERA_SPEED := 1.65

func _ready() -> void:
	get_tree().auto_accept_quit = false
	# Existing scene tests explicitly inject a run path before entering the
	# tree. Keep every new platform file inside that same isolated fixture.
	if run_save.file_path != "user://sudoku-defense-run.json":
		_injected_run_path = run_save.file_path
		_profile_base = _injected_run_path + ".profile"
		DirAccess.make_dir_recursive_absolute(_profile_base)
	steam_platform = SteamPlatform.new()
	add_child(steam_platform)
	steam_platform.overlay_changed.connect(_steam_overlay_changed)
	var platform_status: Dictionary = steam_platform.initialize()
	_configure_profiles(platform_status)
	platform_ui.host = self
	feedback_ui.host = self
	var settings: Dictionary = preferences.read_settings()
	muted = settings.muted
	master_volume = settings.master_volume
	music_volume = settings.music_volume
	effects_volume = settings.effects_volume
	reduced_motion = settings.reduced_motion
	board_notes = settings.board_notes
	auto_open_chests = settings.auto_open_chests
	run.new_run(784217, {"mode":"campaign", "puzzle_difficulty":"easy", "combat_difficulty":"easy"})
	get_viewport().disable_3d = RenderProfile.uses_canvas()
	world = CanvasBoardScript.new() if RenderProfile.uses_canvas() else BoardScript.new()
	add_child(world)
	world.setup(run)
	world.set_reduced_motion(reduced_motion)
	sound = SoundScript.new()
	add_child(sound)
	sound.set_muted(muted)
	sound.set_volume(master_volume)
	sound.set_music_volume(music_volume)
	sound.set_effects_volume(effects_volume)
	_build_ui()
	controller = ControllerScript.new()
	controller.set_bindings(settings.controller_bindings)
	controller.binding_captured.connect(_controller_binding_captured)
	controller.capture_canceled.connect(_controller_capture_canceled)
	controller.activity.connect(_controller_activity)
	controller.action_pressed.connect(_controller_action)
	controller.navigated.connect(_controller_navigate)
	controller.controller_lost.connect(_controller_disconnected)
	controller.pointer_activity.connect(_controller_pointer_activity)
	controller.pointer_axis_changed.connect(_controller_pointer_axis)
	controller.pointer_button_changed.connect(_controller_pointer_button)
	controller.pointer_precision_changed.connect(_controller_pointer_precision)
	controller.pointer_reset.connect(_controller_pointer_reset)
	add_child(controller)
	controller_used = not Input.get_connected_joypads().is_empty()
	dock.controller_hint = _controller_hint
	dock.set_controller_mode(controller_used)
	get_viewport().size_changed.connect(_queue_layout)
	_update_canvas_scale()
	_layout_ui()
	_show_menu(true)
	_refresh()
	if "--smoke-test" in OS.get_cmdline_user_args(): print("SUDOKU_DEFENSE_READY version=" + str(ProjectSettings.get_setting("application/config/version")))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cleanup_fast = false
		_camera_window_focused = false
		_close_controller_numbers()
		_cancel_camera_controls()
		_pause_for_background()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_camera_window_focused = true
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and seed_pointer != null:
		if controller_cursor != null: controller_cursor.deactivate()
		seed_pointer.cancel()
		_finish_pointer_activity.call_deferred()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_quit()

func _background_active() -> bool:
	return not _camera_window_focused or _steam_overlay_active

func _steam_overlay_changed(active: bool) -> void:
	_steam_overlay_active = active
	if controller != null: controller.set_overlay_active(active)
	if active: _pause_for_background()

func _pause_for_background() -> void:
	cleanup_fast = false
	_close_controller_numbers()
	_cancel_camera_controls()
	if controller_cursor != null: controller_cursor.deactivate()
	if seed_pointer != null: seed_pointer.cancel()
	if board_input != null: board_input.cancel_pointer()
	if not has_active_run: return
	_save()
	# Preserve open menus/workshops and their focused controls. An active board
	# gets a pause menu that remains open when focus or the Steam overlay returns.
	if not menu_open and not manual_pause and not dock.is_open() and armed_item.is_empty():
		_show_pause_menu()

func _request_quit() -> void:
	if tutorial.active: tutorial.restore()
	if _save(): get_tree().quit()
	else: _show_unsaved_quit()

func style(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 8) -> StyleBoxFlat:
	return UISkin.panel(bg,border,mini(radius,8),14,border.a > 0)

func label(text: String, size_px: int, color: Color = WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func button(text: String, fn: Callable, accent: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 46
	b.add_theme_font_size_override("font_size",17)
	UISkin.button(b,accent)
	b.pressed.connect(func(): sound.click(); fn.call())
	return b

func hud(id: String, node: Control) -> Control:
	hud_nodes[id] = node
	return node

func _place(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size

func _font(node: Control, pixels: int) -> void:
	node.add_theme_font_size_override("font_size", pixels)

func positioned(node: Control, rect: Rect2, parent: Node = null) -> void:
	(parent if parent != null else ui).add_child(node)
	node.position = rect.position
	node.size = rect.size

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	var drop = DropScript.new()
	board_input = drop
	drop.host = self
	drop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(drop)
	var top: Panel = hud("top", Panel.new())
	top.add_theme_stylebox_override("panel", style(Color("0a1722ed"), Color("28414c"), 0))
	positioned(top, Rect2(0,0,1280,78))
	var icon: TextureRect = hud("logo", TextureRect.new())
	icon.texture = preload("res://assets/icon.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	positioned(icon, Rect2(24,18,42,42))
	header = label("SUDOKU DEFENSE",24)
	positioned(header, Rect2(80,14,325,32))
	positioned(hud("brand",label("Y A K   S T U D I O S",10,MUTED)), Rect2(82,47,350,18))
	resources = label("",19)
	resources.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	positioned(resources,Rect2(470,22,540,32))
	var help_btn: Button = hud("help", button("?",_help))
	help_btn.tooltip_text = "How to play / controller controls"
	positioned(help_btn,Rect2(1030,17,46,44))
	var mute_btn: Button = hud("mute", button("Sound",_toggle_sound))
	mute_btn.tooltip_text = "Toggle sound (M)"
	positioned(mute_btn,Rect2(1084,17,46,44))
	var pause_btn: Button = hud("pause", button("Pause",_toggle_pause))
	pause_btn.tooltip_text = "Pause (P)"
	positioned(pause_btn,Rect2(1138,17,46,44))
	var menu_btn: Button = hud("menu", button("Menu",func(): _show_menu(false)))
	menu_btn.tooltip_text = "Run settings / main menu (Escape)"
	positioned(menu_btn,Rect2(1192,17,64,44))
	var journey: HBoxContainer = hud("journey", HBoxContainer.new())
	journey.add_theme_constant_override("separation",10)
	positioned(journey,Rect2(28,93,480,28))
	for title in ["01 SOLVE", "02 PREPARE", "03 DEFEND", "04 LOOT"]:
		var badge := label(title,12,MUTED)
		journey.add_child(badge)
		phase_badges.append(badge)
	phase_label = label("",31)
	positioned(phase_label,Rect2(28,135,240,44))
	phase_detail = label("",15,MUTED)
	phase_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	positioned(phase_detail,Rect2(30,184,216,115))
	var intel: Button = hud("intel",button("Wave intel",_show_wave_intel))
	intel.tooltip_text = "Inspect the incoming wave (I). Controller: Start → Wave intel."
	positioned(intel,Rect2(30,260,174,44))
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background",style(Color("1a333f"),Color.TRANSPARENT,3))
	progress.add_theme_stylebox_override("fill",style(MINT,Color.TRANSPARENT,3))
	positioned(progress,Rect2(30,313,174,5))
	selected_label = label("SELECT A SQUARE",13,MINT)
	positioned(selected_label,Rect2(30,352,200,24))
	candidate_label = label("",17)
	candidate_label.mouse_filter = Control.MOUSE_FILTER_PASS
	candidate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	positioned(candidate_label,Rect2(30,383,193,100))
	var notes_btn: Button = hud("notes", button("Notes ON",_toggle_notes))
	positioned(notes_btn,Rect2(30,509,174,44))
	var hint_btn: Button = hud("hint", button("Reveal / 6",func(): _action(run.hint(selected_cell))))
	hint_btn.tooltip_text = "Reveal selected square, costs credits (H)"
	positioned(hint_btn,Rect2(30,563,174,44))
	reserve_button = button("Buy reserve  ·  6",func(): _action(run.buy_seed(selected_number if selected_number>0 else 1)))
	reserve_button.tooltip_text = "Buy one emergency seed of the selected number"
	positioned(reserve_button,Rect2(30,617,174,44))
	bag_button = button("Gear",func(): _toggle_dock("bag"))
	bag_button.tooltip_text = "Equip modules and use boosts (X)."
	positioned(bag_button,Rect2(1092,94,164,46))
	_add_quick_icon(bag_button,"gear")
	loot_button = button("Chests",func(): _toggle_dock("loot"))
	loot_button.tooltip_text = _controller_hint("%d unopened - use fragments to open. Start / Menu: Chests." % run.chests.size())
	positioned(loot_button,Rect2(1092,149,164,46))
	_add_quick_icon(loot_button,"chest")
	var camp: Button = hud("camp", button("Camp",func(): _toggle_dock("camp")))
	camp.tooltip_text = "Passives and salvage slots, available between battles"
	positioned(camp,Rect2(1092,204,164,46))
	_add_quick_icon(camp,"camp")
	var camera_button: Button = hud("camera",button("Camera",_toggle_camera_mode))
	camera_button.tooltip_text = "Rotate the board: right-drag, Q / E, or L3 camera mode. Home resets the view."
	positioned(camera_button,Rect2(1092,259,164,46))
	var camera_reset: Button = hud("camera_reset",button("Reset view",_reset_camera_view))
	camera_reset.tooltip_text = "Return to the default camera angle (Home / R3 in camera mode)"
	positioned(camera_reset,Rect2(1092,314,164,46))
	pause_label = label("TACTICAL PAUSE",14,AMBER)
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	positioned(pause_label,Rect2(430,85,420,32))
	var bottom: Panel = hud("bottom", Panel.new())
	bottom.add_theme_stylebox_override("panel",style(Color("0a1722f5"),Color("28414c"),0))
	positioned(bottom,Rect2(0,696,1280,104))
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.move_child(bottom,1) # Background must stay behind the quick tabs moved here on phones.
	positioned(hud("plant_caption",label("PLANT A NUMBER",11,MUTED)),Rect2(26,710,170,22))
	var reserves := hud("reserve_mode",button("Reserve seeds",_toggle_reserve_mode))
	reserves.tooltip_text = "Show emergency seeds during battle. Start / Menu also opens this action."
	positioned(reserves,Rect2(215,709,210,53))
	for n in range(1,10):
		var b := button(str(n),func(): _choose_number(n))
		b.add_theme_font_size_override("font_size",25)
		b.add_theme_color_override("font_color",COLORS[n-1])
		b.tooltip_text = "Seed %d · select a square then plant" % n
		positioned(b,Rect2(215+(n-1)*61,709,54,53))
		number_buttons.append(b)
	controls_label = label("",11,MUTED)
	positioned(controls_label,Rect2(215,772,635,19))
	next_button = button("Prepare defense",_advance,true)
	positioned(next_button,Rect2(944,715,312,56))
	var speed: Button = hud("speed", button("1x",_cycle_speed))
	speed.tooltip_text = "Battle speed: 1x / 2x / 4x. Sudoku time stays normal."
	positioned(speed,Rect2(848,715,74,56))
	notice = label("",18,WHITE)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_stylebox_override("normal",style(Color("173c42ed"),MINT))
	positioned(notice,Rect2(300,640,680,44))
	notice.hide()
	dock = DockScript.new()
	dock.focus_allowed = func(): return not menu_open
	ui.add_child(dock)
	dock.setup(run)
	dock.set_reduced_motion(reduced_motion)
	dock.changed.connect(_action)
	dock.closed.connect(func(): armed_item = ""; _release_ui_focus(); _refresh())
	dock.cell_requested.connect(_inspect_tower)
	dock.family_preview_requested.connect(_update_family_focus)
	dock.controller_module_equipped.connect(_controller_module_equipped)
	dock.item_armed.connect(func(item_id):
		if str(item_id).is_empty():
			armed_item = ""
			_update_attachment_preview()
			_refresh()
			return
		if controller_used and not _controller_pointer_active():
			dock.close_panel(true)
			armed_item = str(item_id)
			_toast("Choose a tower · A attach · B cancel")
		else:
			armed_item = str(item_id)
			_toast("Choose a tower to attach this module")
	)
	var tools: Button = hud("tools",button("Tools",func(): tools_open = not tools_open; _layout_ui()))
	positioned(tools,Rect2(0,0,100,72))
	for child in ui.get_children():
		if child is Button: child.focus_mode = Control.FOCUS_NONE
	for b in number_buttons: b.focus_mode = Control.FOCUS_NONE
	# Control hit testing follows scene order, not CanvasItem z_index. Keep the
	# sheet after every HUD button so covered Tools/number controls cannot steal taps.
	ui.move_child(dock,ui.get_child_count()-1)
	seed_pointer = SeedPointerScript.new()
	seed_pointer.host = self
	seed_pointer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(seed_pointer)
	gear_feedback = GearFeedbackScript.new()
	gear_feedback.host = self
	gear_feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(gear_feedback)
	wrong_guess_feedback = WrongGuessFeedbackScript.new()
	wrong_guess_feedback.host = self
	wrong_guess_feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(wrong_guess_feedback)
	controller_cursor = ControllerCursorScript.new()
	ui.add_child(controller_cursor)
	controller_cursor.setup(self)

func _add_quick_icon(quick: Button, kind: String) -> void:
	var icon := QuickIconScript.new()
	icon.icon_kind = kind
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quick.add_child(icon)
	quick.set_meta("quick_icon",icon)

func _layout_quick_icons() -> void:
	for quick: Button in [bag_button,loot_button,hud_nodes.camp]:
		var icon: Control = quick.get_meta("quick_icon")
		icon.size = Vector2(30,30)
		icon.position = Vector2((quick.size.x-30)*0.5,6) if portrait_layout else Vector2(12,(quick.size.y-30)*0.5)
		# Phone tabs stack the glyph above the short label; wide screens keep a
		# compact horizontal row. Both retain the entire original button target.
		for state in ["normal","hover","pressed","disabled","focus"]:
			var box: StyleBoxFlat = quick.get_theme_stylebox(state)
			box.content_margin_left = 5 if portrait_layout else 50
			box.content_margin_right = 5 if portrait_layout else 12
			box.content_margin_top = 36 if portrait_layout else 8
			box.content_margin_bottom = 8
		if portrait_layout: _font(quick,20)
		quick.clip_text = portrait_layout

func _queue_layout() -> void:
	if _layout_queued: return
	_layout_queued = true
	_apply_resize.call_deferred()

func _apply_resize() -> void:
	_layout_queued = false
	_update_canvas_scale()
	_layout_ui()

func _update_canvas_scale() -> void:
	# A portrait phone needs its own logical canvas, not a tiny letterboxed Deck.
	var window := get_window()
	var portrait: bool = window.size.y > window.size.x
	var wide_handheld: bool = not portrait and float(window.size.x)/maxi(1,window.size.y) > 1.9
	var target := Vector2i(600,1066) if portrait else Vector2i(960,600) if wide_handheld else Vector2i(1280,800)
	if window.content_scale_size != target:
		window.content_scale_size = target
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

func _layout_ui() -> void:
	if ui == null or hud_nodes.is_empty(): return
	layout_size = get_viewport().get_visible_rect().size
	var w := layout_size.x
	var h := layout_size.y
	portrait_layout = h > w
	var open: bool = dock != null and dock.is_open()
	for key in ["brand","journey","mute","pause","plant_caption"]:
		hud_nodes[key].visible = not portrait_layout
	hud_nodes.tools.visible = portrait_layout and not camera_mode
	hud_nodes.camera_reset.visible = not portrait_layout or camera_mode
	controls_label.visible = not portrait_layout
	phase_detail.visible = true
	selected_label.visible = not (portrait_layout and tools_open)
	candidate_label.visible = not (portrait_layout and tools_open)
	for node in [hud_nodes.notes,hud_nodes.hint,reserve_button]:
		node.visible = not portrait_layout or tools_open
	if portrait_layout:
		_place(hud_nodes.top,Rect2(0,0,w,142))
		_place(hud_nodes.logo,Rect2(20,22,48,48))
		_place(header,Rect2(82,20,w-280,50)); _font(header,29)
		_place(hud_nodes.help,Rect2(w-180,14,68,72)); _font(hud_nodes.help,29)
		_place(hud_nodes.menu,Rect2(w-100,14,80,72)); _font(hud_nodes.menu,22)
		_place(resources,Rect2(20,98,w-40,32)); _font(resources,22)
		resources.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_place(phase_label,Rect2(20,156,260,42)); _font(phase_label,27)
		_place(phase_detail,Rect2(292,153,w-312,50)); _font(phase_detail,24)
		_place(hud_nodes.intel,Rect2(292,133,w-312,72)); _font(hud_nodes.intel,22)
		_place(progress,Rect2(20,207,w-40,5))
		board_rect = Rect2(16,228,w-32,minf(w-32,h-600))
		var info_y := board_rect.end.y+10
		_place(selected_label,Rect2(22,info_y,w-44,26)); _font(selected_label,19)
		_place(candidate_label,Rect2(22,info_y+29,w-44,38)); _font(candidate_label,25)
		var tool_w := (w-64)/3.0
		_place(hud_nodes.notes,Rect2(20,info_y,tool_w,72)); _font(hud_nodes.notes,23)
		_place(hud_nodes.hint,Rect2(32+tool_w,info_y,tool_w,72)); _font(hud_nodes.hint,23)
		_place(reserve_button,Rect2(44+2*tool_w,info_y,tool_w,72)); _font(reserve_button,22)
		_place(hud_nodes.bottom,Rect2(0,h-292,w,292))
		# Camera controls share the phone's existing quick row, keeping the grid
		# full-sized. In camera mode Done / Reset replace Camera / Tools.
		var quick_w := (w-72)/5.0
		var quick_buttons: Array = [bag_button,loot_button,hud_nodes.camp,hud_nodes.camera_reset if camera_mode else hud_nodes.tools,hud_nodes.camera]
		for i in range(quick_buttons.size()):
			var quick: Button = quick_buttons[i]
			# Set font and clipping before assigning the rectangle: a larger old
			# minimum size otherwise survives after the phone style is applied.
			_font(quick,20)
			quick.clip_text = true
			_place(quick,Rect2(20+i*(quick_w+8),h-276,quick_w,72))
		var number_w := (w-56)/9.0
		for i in range(9):
			var b := number_buttons[i]
			_place(b,Rect2(20+i*(number_w+2),h-190,number_w,76)); _font(b,34)
		_place(hud_nodes.speed,Rect2(20,h-96,88,76)); _font(hud_nodes.speed,26)
		_place(next_button,Rect2(120,h-96,w-140,76)); _font(next_button,27)
		_place(pause_label,Rect2(20,board_rect.end.y-42,w-40,32)); _font(pause_label,20)
		var notice_y := info_y+80
		_notice_replaces_context = notice_y+72 > h-288
		if _notice_replaces_context: notice_y = info_y
		_place(notice,Rect2(24,notice_y,w-48,72)); _font(notice,23)
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hud_nodes.tools.text = "Done" if tools_open else "Tools"
	else:
		hud_nodes.camera.clip_text = false
		hud_nodes.camera_reset.clip_text = false
		hud_nodes.tools.clip_text = false
		_place(hud_nodes.top,Rect2(0,0,w,78))
		_place(hud_nodes.logo,Rect2(24,18,42,42))
		_place(header,Rect2(80,14,325,32)); _font(header,24)
		_place(hud_nodes.brand,Rect2(82,47,350,18))
		_place(resources,Rect2(w-810,22,440,32)); _font(resources,17)
		resources.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_place(hud_nodes.help,Rect2(w-348,17,46,46)); _font(hud_nodes.help,17)
		_place(hud_nodes.mute,Rect2(w-294,17,84,46)); _font(hud_nodes.mute,15)
		_place(hud_nodes.pause,Rect2(w-202,17,84,46)); _font(hud_nodes.pause,15)
		_place(hud_nodes.menu,Rect2(w-110,17,86,46)); _font(hud_nodes.menu,15)
		_place(hud_nodes.journey,Rect2(28,93,480,28))
		_place(phase_label,Rect2(28,135,240,44)); _font(phase_label,31)
		_place(phase_detail,Rect2(30,184,216,115)); _font(phase_detail,15)
		_place(hud_nodes.intel,Rect2(30,260,174,46)); _font(hud_nodes.intel,17)
		_place(progress,Rect2(30,313,174,5))
		_place(selected_label,Rect2(30,352,200,24)); _font(selected_label,13)
		_place(candidate_label,Rect2(30,383,193,100)); _font(candidate_label,17)
		_place(hud_nodes.notes,Rect2(30,509,174,46)); _font(hud_nodes.notes,17)
		_place(hud_nodes.hint,Rect2(30,563,174,46)); _font(hud_nodes.hint,17)
		_place(reserve_button,Rect2(30,617,174,46)); _font(reserve_button,17)
		_place(bag_button,Rect2(w-188,94,164,46)); _font(bag_button,17)
		_place(loot_button,Rect2(w-188,149,164,46)); _font(loot_button,17)
		_place(hud_nodes.camp,Rect2(w-188,204,164,46)); _font(hud_nodes.camp,17)
		_place(hud_nodes.camera,Rect2(w-188,259,164,46)); _font(hud_nodes.camera,17)
		_place(hud_nodes.camera_reset,Rect2(w-188,314,164,46)); _font(hud_nodes.camera_reset,17)
		_place(hud_nodes.bottom,Rect2(0,h-104,w,104))
		_place(hud_nodes.plant_caption,Rect2(26,h-90,170,22))
		for i in range(9):
			var b := number_buttons[i]
			_place(b,Rect2(215+i*61,h-91,54,53)); _font(b,25)
		_place(controls_label,Rect2(215,h-28,635,19))
		_place(hud_nodes.speed,Rect2(w-432,h-85,74,56)); _font(hud_nodes.speed,17)
		_place(next_button,Rect2(w-336,h-85,312,56)); _font(next_button,17)
		_place(pause_label,Rect2(430,85,420,32)); _font(pause_label,14)
		_place(notice,Rect2(26,352,202,142)); _font(notice,17)
		_notice_replaces_context = true
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		board_rect = Rect2(246,118,w-(606 if open else 442),h-238)
		if h < 700:
			# Wide phones use a shorter HUD with tools tucked away, keeping the
			# battlefield readable instead of retaining desktop-sized sidebars.
			for key in ["brand","journey","help","mute","plant_caption"]: hud_nodes[key].hide()
			hud_nodes.tools.show()
			hud_nodes.tools.text = "Done" if tools_open else "Tools"
			_place(hud_nodes.top,Rect2(0,0,w,64))
			_place(hud_nodes.logo,Rect2(20,15,34,34))
			_place(header,Rect2(66,15,300,34)); _font(header,24)
			_place(resources,Rect2(w-690,19,450,30)); _font(resources,19)
			_place(hud_nodes.pause,Rect2(w-216,9,92,46)); _font(hud_nodes.pause,19)
			_place(hud_nodes.menu,Rect2(w-114,9,92,46)); _font(hud_nodes.menu,19)
			_place(phase_label,Rect2(20,86,192,34)); _font(phase_label,24)
			_place(phase_detail,Rect2(20,128,184,105)); _font(phase_detail,17)
			_place(hud_nodes.intel,Rect2(20,196,174,46)); _font(hud_nodes.intel,17)
			_place(progress,Rect2(20,248,174,5))
			_place(selected_label,Rect2(20,270,184,26)); _font(selected_label,14)
			_place(candidate_label,Rect2(20,307,184,96)); _font(candidate_label,19)
			selected_label.visible = not tools_open
			candidate_label.visible = not tools_open
			for node in [hud_nodes.notes,hud_nodes.hint,reserve_button]: node.visible = tools_open
			_place(hud_nodes.notes,Rect2(20,266,174,48)); _font(hud_nodes.notes,19)
			_place(hud_nodes.hint,Rect2(20,322,174,48)); _font(hud_nodes.hint,19)
			_place(reserve_button,Rect2(20,378,174,48)); _font(reserve_button,18)
			_place(hud_nodes.tools,Rect2(20,442,174,54)); _font(hud_nodes.tools,21)
			_place(bag_button,Rect2(w-180,80,160,50)); _font(bag_button,21)
			_place(loot_button,Rect2(w-180,140,160,50)); _font(loot_button,21)
			_place(hud_nodes.camp,Rect2(w-180,200,160,50)); _font(hud_nodes.camp,21)
			_place(hud_nodes.camera,Rect2(w-180,260,160,50)); _font(hud_nodes.camera,21)
			_place(hud_nodes.camera_reset,Rect2(w-180,320,160,50)); _font(hud_nodes.camera_reset,21)
			# The 29px number font needs 61px with the button's vertical padding.
			# Reserve a separate hint row instead of letting that minimum height
			# grow into it when the requested button height is only 50px.
			_place(hud_nodes.bottom,Rect2(0,h-96,w,96))
			for i in range(9):
				_font(number_buttons[i],29); _place(number_buttons[i],Rect2(20+i*61,h-86,54,62))
			_font(hud_nodes.speed,22); _place(hud_nodes.speed,Rect2(w-418,h-86,74,62))
			_font(next_button,21); _place(next_button,Rect2(w-326,h-86,304,62))
			_place(controls_label,Rect2(20,h-19,680,17))
			_place(pause_label,Rect2(260,68,w-480,28)); _font(pause_label,16)
			_place(notice,Rect2(18,270,188,158)); _font(notice,18)
			board_rect = Rect2(218,80,w-(578 if open else 406),h-186)
	if world.has_method("set_board_rect"): world.set_board_rect(board_rect)
	var reserve_rect: Rect2 = number_buttons[0].get_rect()
	reserve_rect.size.x = 210 if not portrait_layout else minf(330,layout_size.x-40)
	_place(hud_nodes.reserve_mode,reserve_rect)
	_font(hud_nodes.reserve_mode,23 if portrait_layout else 17)
	if dock != null and dock.has_method("set_layout"):
		dock.set_layout(layout_size,portrait_layout,board_rect.end.y)
		dock.z_index = 10
	_layout_quick_icons()
	_layout_modal()
	_update_context_visibility()
	_refresh()

func _update_context_visibility() -> void:
	var tools_cover_context: bool = tools_open and (portrait_layout or layout_size.y < 700)
	var notice_covers_context: bool = notice.visible and _notice_replaces_context
	selected_label.visible = not tools_cover_context and not notice_covers_context
	candidate_label.visible = not tools_cover_context and not notice_covers_context

func _refresh_portrait_text() -> void:
	phase_label.text = "ROUND %02d / %02d" % [run.round_no,run.max_rounds]
	match run.phase:
		"solve": phase_detail.text = "SOLVE  %02d:%02d" % [int(run.timer)/60,int(run.timer)%60]
		"prep": phase_detail.text = "PREPARE"
		"battle": phase_detail.text = "CLEANUP 8x · %d left" % _wave_enemies_remaining() if cleanup_fast else "DEFEND · %d %s left" % [_wave_enemies_remaining(),"enemy" if _wave_enemies_remaining() == 1 else "enemies"]
		"loot": phase_detail.text = "LOOT"
		_: phase_detail.text = "RUN COMPLETE"
	if selected_cell >= 0:
		selected_label.text = "ROW %d / COL %d" % [selected_cell/9+1,selected_cell%9+1]
		if run.towers.has(selected_cell):
			var t: Dictionary = run.towers[selected_cell]
			candidate_label.text = "Tower %d  /  Lv %d  /  %d of 5 modules" % [t.number,run.tower_stats(selected_cell).level,t.attachments.size()]
		elif run.givens[selected_cell]: candidate_label.text = "Fixed clue. Choose an empty square."
		elif board_notes: candidate_label.text = "Candidates  " + "  ".join(run.candidates(selected_cell).map(func(v): return str(v)))
		else: candidate_label.text = "Tap a number to plant here."
	else:
		selected_label.text = "SELECT A SQUARE"
		candidate_label.text = "Tap an empty square, then a number."
	reserve_button.text = "Seed %d / 6" % (selected_number if selected_number>0 else 1)
	pause_label.text = "TACTICAL PAUSE" if dock.is_open() else "PAUSED"

func _layout_modal() -> void:
	if not is_instance_valid(overlay): return
	overlay.z_index = 20
	for panel in overlay.get_children():
		if not panel is PanelContainer: continue
		for hero in panel.find_children("*","Control",true,false):
			if hero.has_meta("menu_hero"): hero.visible = not portrait_layout and layout_size.x >= 1000
		_style_modal_tree(panel)
		_fit_modal_panel(panel)
		# Hidden artwork and portrait fonts change container minima this frame.
		# Fit again after that propagation so an old wide minimum cannot persist.
		_fit_modal_panel.call_deferred(panel)

func _fit_modal_panel(panel: PanelContainer) -> void:
	if not is_instance_valid(panel) or panel.is_queued_for_deletion(): return
	var requested: Vector2 = panel.get_meta("requested_size",Vector2(650,640))
	var wanted := Vector2(minf(requested.x,layout_size.x-32),minf(requested.y,layout_size.y-32))
	if portrait_layout: wanted = Vector2(layout_size.x-32,minf(float(panel.get_meta("portrait_height",requested.y*1.7)),layout_size.y-48))
	_place(panel,Rect2((layout_size-wanted)/2,wanted))

func _style_modal_tree(node: Node) -> void:
	if node is Label or node is Button or node is LineEdit:
		if not node.has_meta("base_font"): node.set_meta("base_font",node.get_theme_font_size("font_size"))
		var base: int = node.get_meta("base_font")
		_font(node,maxi(21,int(base*1.35)) if portrait_layout else base)
		if node is Label: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if node is Button:
			var base_height: float = float(node.get_meta("menu_height",46))
			node.custom_minimum_size.y = maxf(64,base_height) if portrait_layout else base_height
			if node.has_meta("menu_keypad"): node.custom_minimum_size.x = 128 if portrait_layout else 88
			node.clip_text = true
		if node is LineEdit: node.custom_minimum_size.y = 60 if portrait_layout else 36
	for child in node.get_children(): _style_modal_tree(child)

func _process(dt: float) -> void:
	penalty_notice_remaining = maxf(0.0,penalty_notice_remaining-dt)
	steam_platform.pump(dt)
	achievements.pump(dt)
	if dock.controller_workshop_cell >= 0: dock.validate_controller_context()
	_tick_camera_controls(minf(dt,0.05))
	# Switching hint styles rebuilds the dock. Defer it until a cursor click or
	# drag has finished so its pressed Control survives through release.
	if _controller_pointer_active() and not controller_cursor.button_down and not get_viewport().gui_is_dragging():
		if dock.controller_mode != controller_used: dock.set_controller_mode(controller_used)
	if dock.is_open() != _dock_was_open:
		_dock_was_open = dock.is_open()
		_layout_ui()
	var blocked: bool = _background_active() or menu_open or manual_pause or dock.is_open() or not armed_item.is_empty()
	if cleanup_fast and not _cleanup_controls_available(): cleanup_fast = false
	if not blocked and not (tutorial.active and run.phase == "solve"):
		_advance_gameplay(dt)
	if world.has_method("set_panel_open"): world.set_panel_open(dock.is_open())
	_update_attachment_preview()
	world.tick(minf(dt,0.05))
	for event in run.drain_events():
		tutorial.event_seen(event)
		world.play_event(event)
		sound.play_event(event)
		wrong_guess_feedback.play_event(event)
		if str(event.get("type", "")) == "loot": gear_feedback.chest_recovered(event)
	tutorial.observe()
	if notice_time > 0:
		notice_time -= dt
		notice.modulate.a = minf(1,notice_time*2)
		if notice_time <= 0:
			notice.hide()
			_update_context_visibility()
	ui_elapsed += dt
	if ui_elapsed > .15:
		ui_elapsed = 0
		_observe_achievements()
		_refresh()
	if run.phase != last_phase:
		last_phase = run.phase
		reserve_mode = false
		_close_controller_numbers()
		_refresh()
		_save()
		if run.phase == "loot" and not menu_open and not tutorial.active:
			_toast("WAVE CLEAR  ·  Open your chests and prepare for the next round.")
			dock.open_panel("loot",selected_cell)
		elif run.phase in ["won","lost"] and not menu_open and not tutorial.active:
			_show_result()
	_maybe_auto_open_chests()
	save_elapsed += dt
	if save_elapsed > 15 and not menu_open:
		save_elapsed = 0
		_save()

func _cleanup_available() -> bool:
	# A long wave with no reinforcements left. This is not a promise of safety:
	# control builds can still hold a large, dangerous group on the route.
	return not tutorial.active and run.phase == "battle" and run.spawn_total > 0 and run.spawned >= run.spawn_total and not run.enemies.is_empty() and run.battle_time >= 45.0

func _cleanup_controls_available() -> bool:
	return _cleanup_available() and not menu_open and not manual_pause and not dock.is_open() and armed_item.is_empty() and not camera_mode and not reserve_mode and _controller_number_cell < 0

func _toggle_cleanup() -> void:
	if cleanup_fast: cleanup_fast = false
	elif _cleanup_controls_available(): cleanup_fast = true
	_refresh()

func _advance_gameplay(dt: float) -> void:
	if _background_active() or menu_open or manual_pause or dock.is_open() or not armed_item.is_empty() or (tutorial.active and run.phase == "solve"): return
	if cleanup_fast and not _cleanup_controls_available(): cleanup_fast = false
	var frame_step: float = minf(dt,0.05)
	if not cleanup_fast:
		run.update(frame_step*game_speed if run.phase == "battle" else frame_step)
		return
	# Repeat the ordinary selected-speed update, including its substep pattern.
	# Multiplying dt by 8 instead would change targeting/physics boundaries at
	# common frame rates. No combat, RNG, reward or control values change here.
	for repeat in range(8 / int(game_speed)):
		var health_before: float = run.health
		run.update(frame_step*game_speed)
		if run.phase != "battle" or run.health < health_before or not _cleanup_available():
			cleanup_fast = false
			break

func _cycle_speed() -> void:
	cleanup_fast = false
	game_speed = 2.0 if game_speed == 1.0 else 4.0 if game_speed == 2.0 else 1.0
	_refresh()

func _refresh() -> void:
	phase_detail.add_theme_color_override("font_color",Color("ff9aa9") if penalty_notice_remaining > 0.0 else MUTED)
	progress.modulate = Color("ff7289") if penalty_notice_remaining > 0.0 else Color.WHITE
	if cleanup_fast and not _cleanup_controls_available(): cleanup_fast = false
	# Keep a compact warning reachable at every layout without occupying the
	# selected-square/candidate area or suppressing ordinary action feedback.
	var any_save_failed := save_failed or achievement_save_failed
	hud_nodes.menu.text = "Save!" if any_save_failed else _controller_hint("Start") if controller_used else "Menu"
	hud_nodes.menu.tooltip_text = "Latest progress is not saved. Open to retry saving." if any_save_failed else _controller_hint("Start / Menu: Gear, Chests, Camp and settings")
	hud_nodes.menu.add_theme_color_override("font_color",AMBER if any_save_failed else WHITE)
	if _controller_number_cell >= 0 and (not _number_placement_allowed() or run.phase != _controller_number_phase or selected_cell != _controller_number_cell or run.board[_controller_number_cell] != 0):
		_close_controller_numbers()
	hud_nodes.notes.text = "Notes  ON" if board_notes else "Notes  OFF"
	hud_nodes.speed.text = "%dx" % (8 if cleanup_fast else int(game_speed))
	hud_nodes.speed.tooltip_text = "Fast-forward: all enemies and towers run at 8x. Y / Enter or Stop fast-forward returns to %dx. Core hits and opening controls stop it." % int(game_speed) if cleanup_fast else "Battle speed: 1x / 2x / 4x. Sudoku time stays normal."
	resources.text = "CORE %d/%d   CREDITS %d   FRAGMENTS %d" % [int(run.health),int(run.max_health),run.credits,run.fragments]
	var phases := ["solve","prep","battle","loot"]
	for i in range(4): phase_badges[i].modulate = MINT if run.phase == phases[i] else Color("647d85")
	phase_label.text = "ROUND %02d / %02d" % [run.round_no,run.max_rounds]
	var count: int = run.towers.size()
	match run.phase:
		"solve":
			phase_detail.text = "PLANT YOUR DEFENSE\n\n%d %s grown\n%02d:%02d remaining" % [count,"tower" if count == 1 else "towers",int(run.timer)/60,int(run.timer)%60]
			progress.value = 100.0*run.timer/maxf(1,run.solve_duration)
			next_button.text = "Prepare defense"
		"prep":
			var forecast: Dictionary = run.wave_forecast()
			phase_detail.text = "%d ENEMIES NEXT\n%s" % [int(forecast.count),"BOSS IN THIS WAVE" if bool(forecast.boss) else "Choose tower targets."]
			progress.value = 100
			next_button.text = "Launch wave"
		"battle":
			phase_detail.text = "HOLD THE LINE\n\n%d / %d %s left\n%d %s active\n%d corruption" % [_wave_enemies_remaining(),run.spawn_total,"enemy" if _wave_enemies_remaining() == 1 else "enemies",count,"tower" if count == 1 else "towers",run.corruption]
			if _cleanup_available():
				phase_detail.text = "WAVE CLEANUP\n\n%d %s on route\n%s\nAll enemies speed up." % [run.enemies.size(),"enemy" if run.enemies.size() == 1 else "enemies","Fast-forward active: 8x" if cleanup_fast else "Optional fast-forward: 8x"]
			progress.value = 100.0*(run.spawn_total-_wave_enemies_remaining())/maxi(1,run.spawn_total)
			next_button.text = ("Stop fast-forward" if cleanup_fast else "Fast-forward 8x") if _cleanup_available() else "Wave in progress"
		"loot":
			phase_detail.text = "WAVE CLEAR\n\nOpen your chests.\nVisit Camp for upgrades.\nStart the next round."
			progress.value = 100
			next_button.text = "Next round"
		_:
			phase_detail.text = "RUN COMPLETE"
			next_button.text = "Run results"
	next_button.disabled = run.phase == "battle" and not _cleanup_controls_available()
	next_button.tooltip_text = "Optional 8x after 45 battle seconds and the final spawn. All enemies also speed up. Y / Enter toggles; B stops. Menus, tower inspection and core hits return to your normal speed." if _cleanup_available() else ""
	hud_nodes.intel.visible = run.phase == "prep"
	phase_detail.visible = not (portrait_layout and run.phase == "prep")
	phase_detail.size.y = 50 if portrait_layout else 64 if run.phase == "prep" else 105 if layout_size.y < 700 else 115
	if run.phase == "prep":
		var forecast: Dictionary = run.wave_forecast()
		hud_nodes.intel.text = ("%d incoming%s\nWave intel" % [int(forecast.count)," · BOSS" if bool(forecast.boss) else ""]) if portrait_layout else "Wave intel"
		hud_nodes.intel.add_theme_color_override("font_color",AMBER if bool(forecast.boss) else WHITE)
	reserve_button.text = "Seed %d  +1  ·  6" % selected_number if selected_number>0 else "Buy seed 1  ·  6"
	reserve_button.disabled = run.credits<6
	bag_button.text = _controller_hint("X Gear") if controller_used else "Gear"
	loot_button.text = "Chests"
	loot_button.tooltip_text = _controller_hint("%d unopened - use fragments to open. Start / Menu: Chests." % run.chests.size())
	hud_nodes.camp.text = "Camp / Slots" if not portrait_layout and layout_size.y >= 700 else "Camp"
	pause_label.visible = (manual_pause or dock.is_open() or not armed_item.is_empty()) and not menu_open
	pause_label.text = "TACTICAL PAUSE  ·  Choose a tower · A attach · B cancel" if not armed_item.is_empty() else ("TACTICAL PAUSE  ·  Manage your loadout" if dock.is_open() else "PAUSED  ·  P / Start to resume")
	if selected_cell >= 0:
		selected_label.text = "ROW %d  /  COLUMN %d" % [selected_cell/9+1,selected_cell%9+1]
		if run.towers.has(selected_cell):
			var t: Dictionary = run.towers[selected_cell]
			candidate_label.text = "Tower %d · Level %d\n%d / 5 modules\n%s" % [t.number,run.tower_stats(selected_cell).level,t.attachments.size(),_controller_hint("A customize") if controller_used else "Click to customize"]
		elif run.givens[selected_cell]:
			candidate_label.text = "Fixed clue.\nPlant towers in\nempty squares."
		elif board_notes:
			var options: Array = run.candidates(selected_cell)
			candidate_label.text = "Possible numbers\n" + "  ".join(options.map(func(v): return str(v)))
		else: candidate_label.text = "Choose a number\nto plant here."
	else:
		selected_label.text = "SELECT A SQUARE"
		candidate_label.text = "Select a square.\nChoose a number.\nGrow a tower."
	var correct_counts: PackedInt32Array = _number_correct_counts()
	for i in range(9):
		var b: Button = number_buttons[i]
		b.visible = run.phase == "solve" or (run.phase == "battle" and (reserve_mode or _controller_number_cell >= 0))
		var complete: bool = correct_counts[i+1] == 9
		var tint: Color = Color("82939a") if complete else COLORS[i]
		b.tooltip_text = "9 / 9 complete. Tap to highlight. %d emergency reserves for battle." % run.inventory[i+1] if complete else "%d / 9 placed. Tap a square, then %d — or drag %d onto the grid. %d emergency reserves." % [correct_counts[i+1],i+1,i+1,run.inventory[i+1]]
		# Completed families remain selectable for matching-number highlights,
		# and their reserve seeds still work during the defense phase.
		b.disabled = not _number_input_allowed()
		b.focus_mode = Control.FOCUS_ALL if _controller_number_cell >= 0 else Control.FOCUS_NONE
		b.add_theme_color_override("font_color",tint)
		b.add_theme_color_override("font_hover_color",tint.lightened(0.15))
		b.add_theme_color_override("font_pressed_color",tint)
		var selected_bg: Color = Color("253740") if complete else Color("315950")
		b.add_theme_stylebox_override("normal",style(selected_bg if selected_number==i+1 else PANEL, tint if selected_number==i+1 else Color("35505a")))
	if portrait_layout: _refresh_portrait_text()
	_refresh_strategy_preview()
	controls_label.text = "D-PAD grid   A choose   LB/RB number   X gear   Start menu" if controller_used else "TAP / DRAG to plant   RIGHT-DRAG / Q E rotate   HOME reset   ESC menu"
	if controller_used and _tower_navigation_active(): controls_label.text = "D-PAD towers   A customize   LB/RB tower   X gear   Start menu"
	if controller_used and not _controller_pointer_active():
		if dock.controller_context_active(): controls_label.text = "A choose / equip module   B back   LB / RB tower"
		elif run.phase == "prep" and run.towers.has(selected_cell) and not dock.is_open(): controls_label.text = "A open module slot   LB / RB tower   X gear   Y launch"
		elif _cleanup_controls_available(): controls_label.text = "Y stop fast-forward   B stop   A inspect   X gear" if cleanup_fast else "Y fast-forward 8x (enemies too)   A inspect   X gear"
	if controller_used and not armed_item.is_empty(): controls_label.text = "D-PAD / STICK choose tower     A attach module     B cancel"
	if _controller_pointer_active(): controls_label.text = "RS cursor   R3 click   RT drag   LT precision   L3 camera   D-PAD grid"
	if controller_used: controls_label.text = _controller_hint(controls_label.text)
	hud_nodes.plant_caption.text = "CHOOSE A NUMBER" if _controller_number_cell >= 0 else "PLANT A NUMBER"
	hud_nodes.plant_caption.visible = not portrait_layout and layout_size.y >= 700 and run.phase == "solve"
	hud_nodes.reserve_mode.visible = run.phase == "battle" and _controller_number_cell < 0
	hud_nodes.reserve_mode.text = ("Done" if portrait_layout else "Done planting") if reserve_mode else "Reserve seeds"
	var reserve_rect: Rect2 = number_buttons[0].get_rect()
	reserve_rect.size.x = 210 if not portrait_layout else minf(330,layout_size.x-40)
	if reserve_mode: reserve_rect = hud_nodes.tools.get_rect() if portrait_layout else hud_nodes.camera_reset.get_rect()
	_place(hud_nodes.reserve_mode,reserve_rect)
	if _controller_number_cell >= 0:
		controls_label.text = _controller_hint("D-PAD / STICK number   LB / RB number   A place   B back to square")
	hud_nodes.camera.text = "Done" if camera_mode else "Camera"
	hud_nodes.camera.disabled = not camera_mode and not _camera_available()
	hud_nodes.camera_reset.disabled = not _camera_available() or not world.camera_is_rotated()
	hud_nodes.camera_reset.text = "Reset" if portrait_layout else "Reset view"
	hud_nodes.tools.disabled = camera_mode
	if reserve_mode:
		if portrait_layout: hud_nodes.tools.hide()
		else: hud_nodes.camera_reset.hide()
	else:
		hud_nodes.tools.visible = (portrait_layout or layout_size.y < 700) and not camera_mode
		hud_nodes.camera_reset.visible = not portrait_layout or camera_mode
	if portrait_layout: _font(hud_nodes.camera_reset,20)
	if camera_mode:
		selected_label.text = "ROTATE THE BOARD"
		candidate_label.text = _controller_hint("Right stick to rotate
R3 reset · B done") if controller_used else "Drag left / right
Done to return to planting"
		if portrait_layout:
			candidate_label.text = _controller_hint("RS rotate · R3 reset · B done") if controller_used else "Drag sideways · Done to plant"
			_font(candidate_label,22)
		controls_label.text = _controller_hint("CAMERA   Right stick rotate   R3 reset view   B / L3 done") if controller_used else "CAMERA   Drag left / right   Q / E rotate   HOME reset   ESC done"
	if portrait_layout:
		for quick: Button in [bag_button,loot_button,hud_nodes.camp,hud_nodes.tools,hud_nodes.camera,hud_nodes.camera_reset]:
			_fit_quick_label(quick)
	_update_family_focus()
	tutorial.apply_hud()

func _refresh_strategy_preview() -> void:
	candidate_label.tooltip_text = ""
	var preview: Dictionary = StrategyFeedback.placement(run,selected_cell,maxi(1,selected_number))
	if preview.is_empty(): return
	var route_text: String = "If correct: route %+.1f" % float(preview.delta)
	if portrait_layout:
		selected_label.text += "  /  " + route_text
	else:
		var candidates_text: String = "  ".join(run.candidates(selected_cell).map(func(v): return str(v))) if board_notes else "Choose a number"
		candidate_label.text = "%s\n%s\n%.1f tiles in range" % [candidates_text,route_text,float(preview.coverage)]
	candidate_label.tooltip_text = "%s. The new tower reaches %.1f tiles of the proposed route. Other towers may gain or lose coverage. This preview does not confirm the answer." % [route_text,float(preview.coverage)]
	if selected_number > 0: candidate_label.tooltip_text += " Number %d: %.1f damage per hit, %.1f range." % [selected_number,float(preview.damage),float(preview.range)]

func _fit_quick_label(quick: Button) -> void:
	# Keep ordinary phone labels at 20 px; only long counters need less space.
	var surface: StyleBox = quick.get_theme_stylebox("normal")
	var room: float = quick.size.x-surface.get_content_margin(SIDE_LEFT)-surface.get_content_margin(SIDE_RIGHT)
	var font: Font = quick.get_theme_font("font")
	var pixels := 20
	while pixels > 16 and font.get_string_size(quick.text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x > room:
		pixels -= 1
	_font(quick,pixels)

func _wave_enemies_remaining() -> int:
	# Kills is a run total. Wave progress also includes enemies that hit the core.
	return maxi(0,run.spawn_total-run.spawned+run.enemies.size())

func _number_correct_counts() -> PackedInt32Array:
	# Derive from this puzzle each refresh; illegal emergency duplicates do not
	# complete a family, and a new board cannot retain the previous gray state.
	var counts := PackedInt32Array()
	counts.resize(10)
	for cell in range(mini(run.board.size(),run.solution.size())):
		var number: int = run.board[cell]
		if number >= 1 and number <= 9 and number == run.solution[cell]: counts[number] += 1
	return counts

func _number_complete(number: int) -> bool:
	return number >= 1 and number <= 9 and _number_correct_counts()[number] == 9

func _number_input_allowed() -> bool:
	return has_active_run and not menu_open and not manual_pause and not camera_mode and armed_item.is_empty() and run.phase in ["solve","prep","battle","loot"]

func _number_placement_allowed() -> bool:
	return _number_input_allowed() and not dock.is_open() and run.phase in ["solve","battle"]

func _pointer_activity(pointer_owner: int = -2) -> void:
	if controller_cursor != null and controller_cursor.is_dispatching(): return
	# Clear targeting immediately, but retain the pressed Control until release.
	# The normal pointer handoff below rebuilds the sheet after the gesture.
	if dock != null and dock.controller_workshop_cell >= 0: dock.cancel_controller_context()
	_close_controller_numbers()
	if _controller_pointer_active(): controller_cursor.deactivate()
	if pointer_owner == -2 and _pointer_hint_owner != -2: _finish_pointer_activity.call_deferred()
	if controller_used:
		controller_used = false
		_camera_axis = Vector2.ZERO
		if controller != null:
			controller.reset_navigation()
			if camera_mode: controller.reset_pointer()
		_pointer_hint_owner = pointer_owner
		if pointer_owner == -2: dock.set_controller_mode.call_deferred(false)
		_refresh()

func _finish_pointer_activity() -> void:
	if _pointer_hint_owner == -2: return
	_pointer_hint_owner = -2
	# Rebuilding the dock between a pointer press and release discards the
	# pressed control. Update its hints only after the GUI finishes that click.
	if not controller_used: dock.set_controller_mode(false)

func _tap_board(cell: int) -> void:
	if camera_mode or menu_open or manual_pause or (seed_pointer != null and seed_pointer.is_active()): return
	# Pointer taps choose an empty square; only a number tap/drop commits it.
	# Controller A has a separate board -> number tray -> board focus flow.
	_select(cell,run.towers.has(cell),true)

func _drop_number(cell: int, number: int) -> void:
	if not _number_placement_allowed() or cell < 0 or cell >= 81: return
	if run.phase == "solve" and _number_complete(number): return
	if run.board[cell] != 0:
		_toast("Printed clues stay fixed." if run.givens[cell] else "Tap this tower to upgrade it.",false)
		return
	_select(cell,false,false)
	_choose_number(number)

func _choose_number(number: int) -> void:
	if not _number_input_allowed(): return
	selected_number = number
	world.set_selected(selected_cell,selected_number)
	if _number_placement_allowed() and not (run.phase == "solve" and _number_complete(number)) and selected_cell >= 0 and not run.givens[selected_cell] and not run.towers.has(selected_cell):
		var result: Dictionary = run.place(selected_cell,number)
		if bool(result.get("ok",false)): _close_controller_numbers()
		_action(result)
	_refresh()

func _controller_number_choices() -> Array[int]:
	var choices: Array[int] = []
	for number in range(1,10):
		# Availability is separate from Sudoku legality: keep wrong-answer feedback.
		if run.phase == "solve" and not _number_complete(number): choices.append(number)
		elif run.phase == "battle" and run.inventory[number] > 0: choices.append(number)
	return choices

func _open_controller_numbers(cell: int) -> bool:
	if not _number_placement_allowed() or cell < 0 or cell >= 81 or run.board[cell] != 0: return false
	var choices: Array[int] = _controller_number_choices()
	if choices.is_empty():
		_toast("No reserve numbers available. Buy a reserve first." if run.phase == "battle" else "All numbers are complete.",false)
		return false
	_controller_number_cell = cell
	cleanup_fast = false
	_controller_number_phase = run.phase
	selected_cell = cell
	if not choices.has(selected_number): selected_number = choices[0]
	controller.reset_navigation()
	world.set_selected(cell,selected_number)
	_refresh()
	number_buttons[selected_number-1].grab_focus()
	return true

func _close_controller_numbers() -> void:
	if _controller_number_cell < 0: return
	_controller_number_cell = -1
	_controller_number_phase = ""
	var focused: Control = get_viewport().gui_get_focus_owner()
	if number_buttons.has(focused): focused.release_focus()
	for b in number_buttons: b.focus_mode = Control.FOCUS_NONE
	if controller != null: controller.reset_navigation()

func _cycle_controller_number(step: int) -> void:
	var choices: Array[int] = _controller_number_choices()
	if choices.is_empty():
		_close_controller_numbers()
		_refresh()
		return
	var index: int = choices.find(selected_number)
	selected_number = choices[posmod(index+step,choices.size())] if index >= 0 else choices[0]
	world.set_selected(_controller_number_cell,selected_number)
	_refresh()
	if _controller_number_cell >= 0: number_buttons[selected_number-1].grab_focus()

func _inspect_tower(cell: int) -> void:
	# Workshop mini-grid selection is explicit inspection, unlike moving the
	# controller cursor across the battlefield on the way to an empty square.
	if run.towers.has(cell): selected_number = int(run.towers[cell].number)
	_select(cell,false)
	if dock.controller_workshop_cell >= 0: dock.cancel_controller_context(true)

func _eligible_upgrade_towers() -> Array[int]:
	var result: Array[int] = []
	if not run._gear_phase() or not run.items.any(func(item): return str(item.get("type","")) == "attachment"): return result
	for cell in run.towers:
		if run.towers[cell].attachments.size() < 5: result.append(int(cell))
	result.sort()
	return result

func _cycle_upgrade_tower(direction: int) -> void:
	var candidates := _eligible_upgrade_towers()
	if candidates.is_empty():
		_toast("No available modules." if not run.items.any(func(item): return str(item.get("type","")) == "attachment") else "Every tower's module slots are full.",false)
		return
	var workshop: bool = dock.controller_context_active()
	var index := candidates.find(selected_cell)
	var target: int = candidates[0] if direction > 0 else candidates.back()
	if index >= 0: target = candidates[posmod(index+direction,candidates.size())]
	else:
		# A full selected tower is absent from the eligible list. Continue from its
		# board position rather than jumping arbitrarily to the list's beginning.
		for candidate: int in candidates:
			if direction > 0 and candidate > selected_cell:
				target = candidate
				break
			if direction < 0 and candidate < selected_cell: target = candidate
	selected_number = int(run.towers[target].number)
	_select(target,false,false)
	if workshop: dock.open_controller_workshop(target)
	_refresh()

func _controller_module_equipped(origin_cell: int) -> void:
	# A deliberate fit stays on the selected tower; only the player changes it.
	if not run.towers.has(origin_cell):
		dock.close_panel()
		return
	selected_number = int(run.towers[origin_cell].number)
	_select(origin_cell,false,false)
	dock.open_controller_workshop(origin_cell)
	# Preserve any warning from the save attempted by _action.
	if not save_failed:
		if run.towers[origin_cell].attachments.size() >= 5: _toast("Module fitted. This tower's five slots are full.")
		elif not run.items.any(func(item): return str(item.get("type","")) == "attachment"): _toast("Module fitted. No modules remaining in Gear.")
		else: _toast("Module fitted. This tower's next empty slot is selected.")
	_refresh()

func _attachment_item(item_id: String) -> Dictionary:
	for item: Dictionary in run.items:
		if str(item.get("id", "")) == item_id and str(item.get("type", "")) == "attachment": return item
	return {}

func _can_attach_module(cell: int, item_id: String) -> bool:
	return not menu_open and not manual_pause and run._gear_phase() and run.towers.has(cell) and run.towers[cell].attachments.size() < 5 and not _attachment_item(item_id).is_empty()

func _update_attachment_preview() -> void:
	if gear_feedback == null: return
	var dragging: bool = get_viewport().gui_is_dragging()
	var data: Variant = get_viewport().gui_get_drag_data() if dragging else null
	var item_id: String = armed_item
	if data is Dictionary and str(data.get("type", "")) == "attachment": item_id = str(data.get("item_id", ""))
	elif dragging: item_id = ""
	var item: Dictionary = _attachment_item(item_id) if not item_id.is_empty() else {}
	var active: bool = not item.is_empty() and not menu_open and not manual_pause and not (dock.is_open() and dock.current_panel == "loot")
	if world.has_method("set_attachment_targets"): world.set_attachment_targets(active)
	var cell: int = -1
	var pointer: Vector2 = controller_cursor.cursor_position if _controller_pointer_active() else get_viewport().get_mouse_position()
	if active:
		if controller_used and not _controller_pointer_active() and not dragging: cell = selected_cell
		elif not (dock.is_open() and dock._shell.get_global_rect().has_point(pointer)): cell = world.cell_at_screen(pointer)
	if not run.towers.has(cell): cell = -1
	var allowed: bool = cell >= 0 and _can_attach_module(cell,item_id)
	var kind: String = str(item.get("kind", "")) if active else ""
	if world.has_method("set_attachment_preview"): world.set_attachment_preview(cell,kind,allowed)
	var point: Vector2 = world.cell_screen_position(cell) if cell >= 0 else Vector2.ZERO
	var color: Color = Color(str(item.get("color", "83e7c1")))
	var slots: int = run.towers[cell].attachments.size() if cell >= 0 else 0
	gear_feedback.set_target(cell,point,pointer,color,slots,allowed,dragging)

func _update_family_focus(number: int = 0) -> void:
	var family: int = number
	if family == 0 and dock.is_open() and dock.current_panel == "tower" and run.towers.has(selected_cell):
		family = int(run.towers[selected_cell].number)
	if not dock.is_open(): family = 0
	if world.has_method("set_family_focus"): world.set_family_focus(family)

func _select(cell: int, place_now: bool = true, equip_armed: bool = true) -> void:
	if cell < 0 or cell >= 81: return
	if (place_now or _tower_navigation_active()) and run.towers.has(cell): selected_number = int(run.towers[cell].number)
	selected_cell = cell
	world.set_selected(cell,selected_number)
	dock.set_selected(cell)
	if not armed_item.is_empty() and equip_armed:
		if run.towers.has(cell):
			var result: Dictionary = run.equip_item(cell,armed_item)
			_action(result)
			if result.get("ok",false):
				armed_item = ""
				dock.clear_armed()
				if controller_used and not _controller_pointer_active(): dock.open_panel("tower",cell)
		else: _toast("Choose a planted tower for this module.",false)
	elif place_now and run.towers.has(cell):
		dock.open_panel("tower",cell)
	elif place_now and selected_number > 0 and not run.givens[cell] and not (run.phase == "solve" and _number_complete(selected_number)):
		_action(run.place(cell,selected_number))
	_refresh()

func _screen_grid_direction(direction: Vector2i) -> Vector2i:
	# Choose one projected horizontal axis, then its perpendicular grid axis.
	# A consistent pair keeps all four neighbors reachable at diagonal views,
	# where independently choosing the nearest direction can tie twice.
	var origin: Vector2 = world.cell_screen_position(40)
	var right := Vector2i.RIGHT
	var score := -INF
	for candidate: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
		var projected: Vector2 = world.cell_screen_position(40+candidate.x+candidate.y*9)-origin
		var alignment: float = projected.normalized().x
		if alignment > score+0.000001:
			score = alignment
			right = candidate
	if direction.x != 0: return right*direction.x
	var down := Vector2i(-right.y,right.x)
	var projected_down: Vector2 = world.cell_screen_position(40+down.x+down.y*9)-origin
	if projected_down.y < 0.0: down = -down
	return down*direction.y

func _move_selection(direction: Vector2i) -> void:
	if _tower_navigation_active():
		_move_tower_selection(direction)
		return
	direction = _screen_grid_direction(direction)
	if selected_cell < 0: selected_cell = 40
	else:
		var x: int = posmod(selected_cell%9+direction.x,9)
		var y: int = posmod(selected_cell/9+direction.y,9)
		selected_cell = y*9+x
	_select(selected_cell,false,false)

func _tower_navigation_active() -> bool:
	return (not armed_item.is_empty() or run.phase in ["prep","battle","loot"]) and not reserve_mode

func _tower_cells() -> Array[int]:
	var cells: Array[int] = []
	for cell in run.towers: cells.append(int(cell))
	cells.sort()
	return cells

func _move_tower_selection(direction: Vector2i) -> void:
	var cells := _tower_cells()
	if cells.is_empty():
		_toast("No towers yet. Use reserve seeds during battle." if run.phase == "battle" else "No planted towers on this board.",false)
		return
	if not cells.has(selected_cell):
		_select(cells[0],false,false)
		return
	# Use projected positions, so navigation still follows the screen after orbiting.
	var origin: Vector2 = world.cell_screen_position(selected_cell)
	var target := selected_cell
	var best := INF
	for cell in cells:
		if cell == selected_cell: continue
		var offset: Vector2 = world.cell_screen_position(cell)-origin
		var forward: float = offset.dot(Vector2(direction))
		if forward <= 0.5: continue
		var lateral: float = absf(offset.cross(Vector2(direction)))
		var score: float = offset.length()+lateral*2.0
		if score < best:
			best = score
			target = cell
	_select(target,false,false)

func _cycle_tower(step: int) -> void:
	var cells := _tower_cells()
	if cells.is_empty(): return
	var index: int = cells.find(selected_cell)
	var target: int = cells[posmod(index+step,cells.size())] if index >= 0 else cells[0]
	_select(target,false,false)
	if dock.is_open(): dock.open_panel("tower",target)

func _toggle_reserve_mode() -> void:
	if run.phase != "battle": return
	if dock.is_open(): dock.close_panel()
	_cancel_camera_controls()
	reserve_mode = not reserve_mode
	_close_controller_numbers()
	if reserve_mode:
		# Entering planting cancels targeting, without equipping or losing gear.
		cleanup_fast = false
		armed_item = ""
		dock.clear_armed()
		for cell in range(81):
			if run.board[cell] == 0:
				_select(cell,false,false)
				break
		_toast("Reserve seeds · choose an empty square, then a number. B finishes planting.")
	_refresh()

func _action(result: Dictionary) -> void:
	if result.has("message"): _toast(str(result.message),bool(result.get("ok",false)))
	# A rejected Solve guess changes durable progress. Use the existing guarded
	# save path, including practice exclusion and unresolved-profile protection.
	if str(result.get("reason","")) == "wrong_answer":
		penalty_notice_remaining = 2.0
		_save()
	if result.get("ok",false):
		_save()
		if not armed_item.is_empty() and not run.items.any(func(item): return str(item.id)==armed_item):
			armed_item = ""
			dock.clear_armed()
	dock.refresh()
	_refresh()

func _advance() -> void:
	if not tutorial.can_advance(): return
	if run.phase == "battle":
		_toggle_cleanup()
		return
	_close_controller_numbers()
	if run.phase == "loot":
		dock.close_panel()
		_show_next_round()
	elif run.phase in ["won","lost"]: _show_result()
	elif run.phase != "battle":
		dock.close_panel()
		_action(run.advance_phase())

func _toggle_dock(kind: String) -> void:
	if menu_open: return
	cleanup_fast = false
	_close_controller_numbers()
	_cancel_camera_controls()
	if dock.is_open() and dock.current_panel == kind: dock.close_panel()
	else: dock.open_panel(kind,selected_cell)
	_refresh()

func _open_management(kind: String) -> void:
	cleanup_fast = false
	_close_overlay()
	_close_controller_numbers()
	_cancel_camera_controls()
	dock.open_panel(kind,selected_cell)
	_refresh()

func _toggle_sound() -> void:
	muted = not muted
	sound.set_muted(muted)
	_toast("Sound off" if muted else "Sound on")
	_save_preferences()

func _toggle_reduced_motion() -> void:
	reduced_motion = not reduced_motion
	world.set_reduced_motion(reduced_motion)
	dock.set_reduced_motion(reduced_motion)
	_save_preferences()

func _toggle_notes() -> void:
	board_notes = not board_notes
	_refresh()
	_save_preferences()

func _toggle_auto_open_chests() -> void:
	auto_open_chests = not auto_open_chests
	_save_preferences()

func _maybe_auto_open_chests() -> void:
	# Wait for a safe management moment; never interrupt combat, a dialog,
	# gear selection, an existing reward reveal, or a held pointer gesture.
	if not auto_open_chests or not has_active_run or menu_open or manual_pause or tutorial.active: return
	if run.phase not in ["solve","prep","loot","won"] or not armed_item.is_empty(): return
	if camera_mode or _controller_number_cell >= 0 or get_viewport().gui_is_dragging(): return
	if controller_cursor != null and controller_cursor.button_down: return
	if seed_pointer != null and seed_pointer.is_active(): return
	if board_input != null and (board_input.mouse_down or board_input.active_touch >= 0 or board_input.camera_pointer_active()): return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): return
	if dock.is_open() and dock.current_panel != "loot": return
	if is_instance_valid(dock._loot_table) and (dock._loot_table.opening or not dock._loot_table.reward.is_empty()): return
	if int(run.chest_open_plan().count) == 0: return
	var result: Dictionary = run.open_all_chests()
	if not bool(result.get("ok",false)): return
	_action(result)
	dock.open_panel("loot",selected_cell)
	dock._loot_table.present_rewards(result)

func _save_preferences() -> void:
	if not preferences.write_settings({"muted": muted, "reduced_motion": reduced_motion, "board_notes": board_notes, "auto_open_chests": auto_open_chests,
		"master_volume": master_volume, "music_volume": music_volume, "effects_volume": effects_volume, "controller_bindings": controller.bindings}):
		_toast("Settings apply now, but could not be saved on this device.",false)

func _set_audio_level(channel: String, value: float) -> void:
	value = clampf(snappedf(value, 0.05), 0.0, 1.0)
	match channel:
		"master": master_volume = value; sound.set_volume(value)
		"music": music_volume = value; sound.set_music_volume(value)
		"effects": effects_volume = value; sound.set_effects_volume(value)
	_save_preferences()

func _audio_level(channel: String) -> float:
	return master_volume if channel == "master" else (music_volume if channel == "music" else effects_volume)

func _show_controller_settings() -> void:
	_bindings_draft = controller.bindings.duplicate()
	_binding_target = ""
	_binding_message = "Changes apply only after Save. Already assigned inputs swap actions."
	_render_controller_settings()

func _render_controller_settings(focus_action: String = "") -> void:
	var box := _modal(690,690)
	overlay.set_meta("controller_settings",true)
	controller.set_settings_mode(true)
	box.add_child(label("CONTROLLER MAPPING",25,MINT))
	var note := label("In this panel: D-pad / left stick to navigate, A to choose, B / Start or Escape to leave. These controls stay fixed.\nRight stick and D-pad axes are fixed; mappings below apply to gameplay and other menus.",15,MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var status := label(_binding_message,15,AMBER)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	var done := button("Save and return",_save_controller_settings,true)
	done.set_meta("focus_id","mapping:save")
	box.add_child(done)
	var cancel := button("Cancel / discard changes",_close_overlay)
	box.add_child(cancel)
	box.add_child(button("Reset to defaults (then Save)",func():
		_bindings_draft = ControllerBindings.DEFAULTS.duplicate()
		_binding_message = "Defaults ready. Save to apply or Cancel to keep your previous mapping."
		_render_controller_settings()
	))
	var focus_button: Button = done
	for action: String in ControllerBindings.DEFAULTS:
		var key := action
		var choice := button(ControllerBindings.TITLES[key] + "  :  " + ControllerBindings.display(_bindings_draft,key),func(): _capture_controller_binding(key))
		choice.set_meta("focus_id","mapping:"+key)
		box.add_child(choice)
		if key == focus_action: focus_button = choice
	focus_button.grab_focus()

func _capture_controller_binding(action: String) -> void:
	if controller.capturing: return
	_binding_target = action
	var box := _modal(620,380)
	# _modal cancels any prior input mode; this new panel owns all capture input.
	_binding_target = action
	overlay.set_meta("controller_settings",true)
	controller.set_settings_mode(true)
	box.add_child(label("PRESS AN INPUT",25,MINT))
	var prompt := label("Assign " + ControllerBindings.TITLES[action] + ".\nPress a face button, shoulder, stick click, View, Start or trigger. B and Start can be assigned here.\nD-pad Left, Escape or the Cancel button below cancels. Stick movement and other D-pad directions are ignored.",16,WHITE)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(prompt)
	var cancel := button("Cancel capture",func(): controller.cancel_capture())
	box.add_child(cancel)
	cancel.grab_focus()
	controller.begin_capture()

func _controller_binding_captured(token: String) -> void:
	if _binding_target.is_empty(): return
	var action := _binding_target
	_binding_target = ""
	_bindings_draft = ControllerBindings.swap_binding(_bindings_draft,action,token)
	_binding_message = ControllerBindings.TITLES[action] + " assigned to " + ControllerBindings.display(_bindings_draft,action) + ". Conflicting action swapped. Save to apply."
	_render_controller_settings(action)

func _controller_capture_canceled() -> void:
	if _binding_target.is_empty(): return
	var action := _binding_target
	_binding_target = ""
	_binding_message = "Capture canceled. No binding changed."
	_resume_controller_settings.call_deferred(action)

func _resume_controller_settings(action: String) -> void:
	if controller.settings_mode and is_instance_valid(overlay) and overlay.get_meta("controller_settings",false):
		_render_controller_settings(action)

func _save_controller_settings() -> void:
	var data := {"muted":muted,"reduced_motion":reduced_motion,"board_notes":board_notes,"auto_open_chests":auto_open_chests,
		"master_volume":master_volume,"music_volume":music_volume,"effects_volume":effects_volume,
		"controller_bindings":_bindings_draft}
	if not preferences.write_settings(data):
		_binding_message = "Could not save. Your previous mapping is still active. Retry Save or Cancel."
		_render_controller_settings()
		return
	controller.set_bindings(_bindings_draft)
	dock.refresh(false)
	_close_overlay()
	_toast("Controller mapping saved on this device.")

func _controller_hint(text: String) -> String:
	if controller == null: return text
	var pattern := RegEx.new()
	pattern.compile("\\b(A|B|X|Y|LB|RB|L3|R3|LT|RT|Start|View)\\b")
	var result := ""
	var offset := 0
	var actions := {"A":"confirm","B":"cancel","X":"gear","Y":"advance","LB":"previous","RB":"next","L3":"camera","R3":"click","LT":"precision","RT":"drag","Start":"pause","View":"help"}
	for match_result in pattern.search_all(text):
		result += text.substr(offset,match_result.get_start()-offset)
		result += ControllerBindings.display(controller.bindings,actions[match_result.get_string()])
		offset = match_result.get_end()
	return result + text.substr(offset)

func _show_audio_settings() -> void:
	var box := _modal(540,568)
	overlay.set_meta("audio_settings",true)
	box.add_child(label("AUDIO",26,MINT))
	box.add_child(label("Changes are saved on this device.",15,MUTED))
	var first_control: Button
	for channel in ["master","music","effects"]:
		var key: String = channel
		box.add_child(label(key.capitalize(),18,WHITE))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		box.add_child(row)
		var value_label := label("%d%%" % roundi(_audio_level(key)*100.0),22,MINT)
		value_label.set_meta("audio_value",key)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lower := button("- 5%",func():
			_set_audio_level(key,_audio_level(key)-0.05)
			value_label.text = "%d%%" % roundi(_audio_level(key)*100.0)
		)
		lower.set_meta("focus_id","audio:" + key + ":lower")
		lower.custom_minimum_size.x = 90
		if key == "master": first_control = lower
		row.add_child(lower)
		row.add_child(value_label)
		var higher := button("+ 5%",func():
			_set_audio_level(key,_audio_level(key)+0.05)
			value_label.text = "%d%%" % roundi(_audio_level(key)*100.0)
		)
		higher.set_meta("focus_id","audio:" + key + ":higher")
		higher.custom_minimum_size.x = 90
		row.add_child(higher)
		# Full-width rows below can win Godot's geometric focus heuristic.
		# Keep left/right explicitly within the current volume control.
		lower.focus_neighbor_right = lower.get_path_to(higher)
		higher.focus_neighbor_left = higher.get_path_to(lower)
	var mute := button("Sound: " + ("OFF" if muted else "ON"),func(): _toggle_sound())
	mute.set_meta("focus_id","audio:mute")
	mute.pressed.connect(func(): mute.text = "Sound: " + ("OFF" if muted else "ON"))
	box.add_child(mute)
	box.add_child(label("Mute keeps your volume choices. 0% is silent.",14,MUTED))
	var back := button("Done",_close_overlay,true)
	back.set_meta("focus_id","audio:done")
	box.add_child(back)
	first_control.grab_focus()

func _toggle_pause() -> void:
	if menu_open: return
	_close_controller_numbers()
	_cancel_camera_controls()
	manual_pause = not manual_pause
	_refresh()

func _toast(text: String, success: bool = true) -> void:
	notice.text = text
	notice.add_theme_color_override("font_color",WHITE if success else AMBER)
	notice_time = 3.8
	notice.modulate.a = 1
	notice.show()
	if _notice_replaces_context and tools_open and (portrait_layout or layout_size.y < 700):
		tools_open = false
		_layout_ui()
	_update_context_visibility()

func _save() -> bool:
	if tutorial.active: return true
	if not has_active_run: return true
	if not cloud_profile_status.get("ok",false):
		save_failed = true
		_toast("Save profile unavailable. Open Saves & Steam for details.",false)
		return false
	var was_failed := save_failed
	save_failed = not run_save.write_run(run.save_data())
	_observe_achievements()
	if save_failed: _toast("PROGRESS NOT SAVED. Open Menu to retry saving.",false)
	elif was_failed: _toast("Progress saved. You can safely close the game.")
	_refresh()
	return not save_failed and not achievement_save_failed

func _new_achievement_run_id() -> String:
	# Independent of gameplay RNG so achievement tracking cannot alter a seed.
	return Crypto.new().generate_random_bytes(16).hex_encode()

func _configure_profiles(platform_status: Dictionary) -> void:
	cloud_profile_status = cloud_profile.configure(str(platform_status.get("account_id","")),_profile_base)
	if not _injected_run_path.is_empty() and not cloud_profile_status.get("scoped",false):
		cloud_profile_status["run_path"] = _injected_run_path
	# Conflict results retain their scoped paths so the player can recover them.
	if cloud_profile_status.has("run_path"):
		run_save.file_path = str(cloud_profile_status.run_path)
		var staging := str(cloud_profile_status.get("staging_root",""))
		run_save.staging_path = staging.path_join("run") if not staging.is_empty() else ""
		achievements.configure(str(cloud_profile_status.achievement_path),staging.path_join("achievements") if not staging.is_empty() else "",str(platform_status.get("account_id","")))
		achievement_save_failed = bool(achievements.get_status().get("save_failed",false))

func _observe_achievements() -> void:
	if tutorial.active or not has_active_run or not cloud_profile_status.get("ok",false): return
	var was_failed := achievement_save_failed
	achievements.observe_run(run)
	var status: Dictionary = achievements.get_status()
	achievement_save_failed = bool(status.get("save_failed",false))
	if achievement_save_failed and not was_failed:
		_toast("Achievement progress could not be saved. Open Achievements to retry.",false)
	achievements.synchronize(steam_platform)

func _can_replace_saved_run() -> bool:
	_observe_achievements()
	if has_active_run and achievement_save_failed:
		platform_ui.show_achievements()
		return false
	if not cloud_profile_status.get("ok",false):
		platform_ui.show_saves()
		return false
	# Do not adopt a changed disk snapshot until the player explicitly loads it.
	if not run_save.check_current():
		platform_ui.show_saves()
		return false
	return true

func _platform_back() -> void:
	if is_instance_valid(overlay) and overlay.get_meta("save_confirmation",false):
		platform_ui.show_saves()
	else:
		_show_menu(not has_active_run)

func _exit_tree() -> void:
	achievements.close()
	if is_instance_valid(steam_platform): steam_platform.shutdown()

func _clear_wrong_guess_feedback() -> void:
	wrong_guess_feedback.clear_feedback()
	penalty_notice_remaining = 0.0

func _load() -> bool:
	if not cloud_profile_status.get("ok",false): return false
	dock.cancel_controller_context(true)
	var saved: Dictionary = run_save.read_run()
	if saved.is_empty(): return false
	var loaded: bool = run.load_data(saved.data)
	if loaded:
		_clear_wrong_guess_feedback()
		run.enable_achievement_tracking(_new_achievement_run_id())
		has_active_run = true
		save_recovered = bool(saved.recovered)
		save_failed = false
	return loaded

func _show_unsaved_quit() -> void:
	var box := _modal(610,400)
	overlay.set_meta("unsaved_quit",true)
	box.add_child(label("Progress could not be saved",25,AMBER))
	var explanation := label("Some run or achievement progress could not be saved. Earlier saved files have been kept. Retry saving, keep playing, or close without the latest changes.",17,WHITE)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(explanation)
	var retry := button("Retry save and quit",func():
		if _save(): get_tree().quit()
	)
	box.add_child(retry)
	box.add_child(button("Keep playing",_close_overlay,true))
	box.add_child(button("Quit without saving",func(): get_tree().quit()))
	retry.grab_focus()

func _retry_save_from_menu() -> void:
	if tutorial.active: tutorial.restore()
	_save()
	_show_pause_menu()

func _start_run() -> void:
	if not _can_replace_saved_run(): return
	cleanup_fast = false
	if tutorial.active: tutorial.restore()
	_cancel_camera_controls()
	var input_seed: String = seed_input.text.strip_edges() if seed_input else ""
	var chosen_seed: int = input_seed.to_int() if input_seed.is_valid_int() else int(Time.get_unix_time_from_system())%2147483647
	has_active_run = true
	run.new_run(chosen_seed,{"mode":mode_choice,"puzzle_difficulty":puzzle_choice,"combat_difficulty":combat_choice,"achievement_run_id":_new_achievement_run_id()})
	_clear_wrong_guess_feedback()
	selected_cell = -1
	selected_number = 0
	armed_item = ""
	reserve_mode = false
	manual_pause = false
	dock.reset_for_run()
	world.setup(run)
	world.set_selected(-1,0)
	_close_overlay()
	last_phase = run.phase
	if _save(): _toast("Plant 6-8 correct answers, then prepare your defense.")

func _close_overlay() -> void:
	if controller != null and controller.settings_mode:
		_binding_target = ""
		controller.set_settings_mode(false)
	if is_instance_valid(overlay) and overlay.get_meta("feedback_panel",false):
		feedback_ui.back()
		return
	if is_instance_valid(overlay) and overlay.get_meta("platform_panel",false):
		_platform_back()
		return
	if not has_active_run:
		_show_menu(true)
		return
	if is_instance_valid(overlay): overlay.queue_free()
	overlay = null
	menu_open = false
	_seed_editing = false
	_release_ui_focus()
	if controller_used and dock.is_open(): dock._focus_current.call_deferred()
	_refresh()

func _modal(width: float = 650, height: float = 640) -> VBoxContainer:
	if controller != null and controller.settings_mode:
		_binding_target = ""
		controller.set_settings_mode(false)
	cleanup_fast = false
	if dock != null and dock.controller_workshop_cell >= 0: dock.cancel_controller_context(true)
	_close_controller_numbers()
	_cancel_camera_controls()
	if seed_pointer != null: seed_pointer.cancel()
	if board_input != null: board_input.cancel_pointer()
	if is_instance_valid(overlay): overlay.queue_free()
	menu_open = true
	overlay = Control.new()
	ui.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.008,0.018,0.027,.76)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var panel := PanelContainer.new()
	var surface := UISkin.panel(Color("0e2029"),Color("3b5e62"),12,12)
	surface.border_width_top = 2
	surface.shadow_size = 28
	surface.shadow_offset = Vector2(0,14)
	panel.add_theme_stylebox_override("panel",surface)
	overlay.add_child(panel)
	panel.set_meta("requested_size",Vector2(width,height))
	panel.position = Vector2((1280-width)/2,(800-height)/2)
	panel.size = Vector2(width,height)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",14)
	margin.add_theme_constant_override("margin_right",14)
	margin.add_theme_constant_override("margin_top",12)
	margin.add_theme_constant_override("margin_bottom",12)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	UISkin.scroll(scroll)
	margin.add_child(scroll)
	# Godot's visible scrollbar can overlay its content. Leave a gutter so
	# the right edge of choices and actions stays visible in scrolling dialogs.
	var content_margin := MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_right",12)
	scroll.add_child(content_margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_child(box)
	_layout_modal.call_deferred()
	return box

func _choice_row(box: VBoxContainer, title: String, values: Array, current: String, callback: Callable) -> void:
	box.add_child(label(title,11,MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	box.add_child(row)
	var choices: Array[Button] = []
	var descriptions := {"campaign":"50 rounds · choose", "freeplay":"One round", "locked":"50 rounds · fixed"}
	for value in values:
		var id: String = str(value[0])
		var b: Button = MenuChoice.new()
		b.configure(str(value[1]),str(descriptions.get(id,"")),id,current == id,not descriptions.has(id))
		if descriptions.has(id):
			b.tooltip_text = str({"campaign":"50 rounds. Choose Sudoku and siege difficulty before each round.", "freeplay":"One Sudoku board and one wave. Choose both difficulties at the start.", "locked":"50 rounds. Keep the same Sudoku and siege difficulties for the whole run."}[id])
		row.add_child(b)
		choices.append(b)
		b.pressed.connect(func():
			sound.click()
			callback.call(id)
			for c in choices: c.set_chosen(c == b)
		)

func _menu_art(parent: BoxContainer, caption: String = "FROM LOGIC TO FIREPOWER") -> void:
	var hero := VBoxContainer.new()
	hero.set_meta("menu_hero",true)
	hero.custom_minimum_size.x = 286
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.add_theme_constant_override("separation",12)
	parent.add_child(hero)
	var brand := label("Y A K   S T U D I O S",11,MINT)
	hero.add_child(brand)
	var art: Control = MenuArt.new()
	art.reduced_motion = reduced_motion
	art.custom_minimum_size = Vector2(280,232)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.add_child(art)
	hero.add_child(label(caption,12,AMBER))
	var lore := label("Solve the puzzle.
Build your towers.
Protect the core.",21,WHITE)
	hero.add_child(lore)
	var steps := label("01 SOLVE     02 PREPARE
03 DEFEND    04 LOOT",11,MUTED)
	hero.add_child(steps)

func _show_menu(initial: bool = false) -> void:
	_seed_editing = false
	_seed_return_initial = initial
	if not initial and has_active_run:
		_show_pause_menu()
		return
	var box := _modal(1000,674)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",28)
	box.add_child(columns)
	_menu_art(columns)
	var setup := VBoxContainer.new()
	setup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup.add_theme_constant_override("separation",10)
	columns.add_child(setup)
	setup.add_child(label("NEW RUN",11,MINT))
	setup.add_child(label("SUDOKU DEFENSE",34,WHITE))
	setup.add_child(label("Plant answers. Grow firepower.",17,AMBER))
	_choice_row(setup,"01  GAME MODE",[["campaign","Campaign / 50"],["freeplay","Free play / 1"],["locked","Locked in / 50"]],mode_choice,func(v): mode_choice=v)
	_choice_row(setup,"02  SUDOKU DIFFICULTY",[["easy","Easy"],["medium","Medium"],["hard","Hard"]],puzzle_choice,func(v): puzzle_choice=v)
	_choice_row(setup,"03  SIEGE DIFFICULTY",[["easy","Easy"],["medium","Medium"],["hard","Hard"]],combat_choice,func(v): combat_choice=v)
	setup.add_child(label("Harder puzzles have fewer clues and more room for towers.",12,MUTED))
	# A separate label and a bounded input row prevent the seed label from
	# wrapping letter-by-letter when a controller keypad is present.
	setup.add_child(label("RUN SEED  /  OPTIONAL",11,MUTED))
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation",8)
	setup.add_child(seed_row)
	seed_input = LineEdit.new()
	seed_input.placeholder_text = "Random seed"
	seed_input.expand_to_text_length = false
	seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_input.custom_minimum_size = Vector2(140,42)
	seed_input.add_theme_font_size_override("font_size",14)
	seed_input.add_theme_color_override("font_color",WHITE)
	seed_input.add_theme_color_override("font_placeholder_color",MUTED)
	seed_input.add_theme_stylebox_override("normal",UISkin.panel(Color("081820"),Color("304b53"),5,12,false))
	seed_input.add_theme_stylebox_override("focus",UISkin.panel(Color("102a31"),MINT,5,12,false))
	seed_input.text = _seed_text
	seed_input.text_changed.connect(func(value): _seed_text = value)
	seed_row.add_child(seed_input)
	var keypad := button("Keypad",_show_seed_pad)
	keypad.set_meta("menu_keypad",true)
	keypad.custom_minimum_size.x = 88
	seed_row.add_child(keypad)
	var start := button("Start run",_start_run,true)
	start.set_meta("menu_height",52)
	setup.add_child(start)
	var guide := button("Guided first round",func(): tutorial.start(self))
	guide.set_meta("focus_id","guide:start")
	setup.add_child(guide)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	setup.add_child(row)
	if has_active_run:
		var resume := button("Resume run",_close_overlay)
		resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(resume)
	elif run_save.has_save():
		var resume := button("Continue saved run",func():
			if _load():
				world.setup(run)
				_close_overlay()
				last_phase = run.phase
				_toast("Save recovered. Some recent actions may need replaying." if save_recovered else "Saved run loaded.")
			else: _toast("Could not read the saved run or its backup. The files have been kept.",false)
		)
		resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(resume)
	var how := button("How to play",_help)
	how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(how)
	var platform_row := HBoxContainer.new()
	platform_row.add_theme_constant_override("separation",8)
	setup.add_child(platform_row)
	for action in [["Achievements",platform_ui.show_achievements],["Saves & Steam",platform_ui.show_saves]]:
		var item := button(str(action[0]),action[1])
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		platform_row.add_child(item)
	setup.add_child(button("Controller mapping",_show_controller_settings))
	setup.add_child(button("Feedback / report a bug",feedback_ui.show_panel))
	if not OS.has_feature("web"): setup.add_child(button("Quit game",_request_quit))
	start.grab_focus()

func _show_pause_menu() -> void:
	var box := _modal(780,620)
	for panel in overlay.get_children():
		if panel is PanelContainer: panel.set_meta("portrait_height",620.0)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",28)
	box.add_child(columns)
	_menu_art(columns,"READY WHEN YOU ARE")
	var actions := VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation",12)
	columns.add_child(actions)
	actions.add_child(label("RUN PAUSED",11,MINT))
	actions.add_child(label("Paused",32,WHITE))
	actions.add_child(label("ROUND %02d / %02d  ·  %s" % [run.round_no,run.max_rounds,str({"solve":"Solve", "prep":"Prepare", "battle":"Defend", "loot":"Loot", "won":"Victory", "lost":"Defeat"}.get(run.phase,run.phase)).to_upper()],13,AMBER))
	actions.add_child(label("Latest progress is NOT saved." if save_failed or achievement_save_failed else "Your progress is saved on this device.",13,AMBER if save_failed or achievement_save_failed else MUTED))
	if save_failed or achievement_save_failed:
		actions.add_child(button("Return and retry saving" if tutorial.active else "Retry saving",_retry_save_from_menu,true))
	var resume := button("Resume run",_close_overlay,true)
	resume.set_meta("menu_height",54)
	actions.add_child(resume)
	if tutorial.active: actions.add_child(button("Skip guide / return",tutorial.finish))
	if run.phase in ["solve","prep"]:
		var intel := button("Wave intel",_show_wave_intel)
		intel.set_meta("focus_id","wave:intel")
		actions.add_child(intel)
	actions.add_child(button("Manage gear",func(): _open_management("bag")))
	actions.add_child(button("Chests / Open all",func(): _open_management("loot")))
	actions.add_child(button("Camp / Salvage slots",func(): _open_management("camp")))
	if run.phase == "battle":
		actions.add_child(button("Finish reserve planting" if reserve_mode else "Plant reserve seeds",func(): _close_overlay(); _toggle_reserve_mode()))
	actions.add_child(button("Settings / How to play",_help))
	actions.add_child(button("Audio settings",_show_audio_settings))
	actions.add_child(button("Controller mapping",_show_controller_settings))
	actions.add_child(button("Feedback / report a bug",feedback_ui.show_panel))
	actions.add_child(button("Achievements",platform_ui.show_achievements))
	actions.add_child(button("Saves & Steam",platform_ui.show_saves))
	actions.add_child(button("New run",func(): _show_menu(true)))
	if not OS.has_feature("web"): actions.add_child(button("Save and quit",_request_quit))
	resume.grab_focus()

func _show_wave_intel() -> void:
	if not has_active_run or run.phase not in ["solve","prep"]: return
	var forecast: Dictionary = run.wave_forecast()
	var box := _modal(620,660)
	overlay.set_meta("wave_intel",true)
	box.add_child(label("WAVE INTEL  /  ROUND %02d" % run.round_no,26,MINT))
	var summary := label("%d enemies incoming" % int(forecast.count),24,WHITE)
	summary.set_meta("forecast_total",int(forecast.count))
	box.add_child(summary)
	if bool(forecast.boss):
		var warning := label("BOSS IN THIS WAVE · arrives last",18,AMBER)
		warning.set_meta("forecast_boss",true)
		box.add_child(warning)
	box.add_child(label("Current corruption: %d  ·  Enemy health ×%.2f\nOne enemy arrives every %.2f seconds." % [int(run.corruption),float(forecast.corruption_multiplier),float(forecast.spawn_interval)],16,MUTED))
	var back := button("Back to preparation" if run.phase == "prep" else "Back to puzzle",_close_overlay,true)
	back.set_meta("focus_id","wave:close")
	back.tooltip_text = _controller_hint("Close wave intel · B / Escape")
	box.add_child(back)
	box.add_child(label(_controller_hint("D-pad / left stick: scroll · A / B: back"),14,MINT))
	var coverage := label(StrategyFeedback.defense_summary(run),17,MINT)
	coverage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coverage.set_meta("defense_coverage",true)
	box.add_child(coverage)
	var route_note := label("Only correct answers during Solve reshape the route. Battle placements keep it fixed. Route length gives enemies more travel time, but coverage determines when towers can fire.",15,MUTED)
	route_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(route_note)
	var names := {"grunt":"Grunts","runner":"Runners","swarm":"Swarm","tank":"Tanks","boss":"Boss"}
	var roles := {"grunt":"Steady pressure on your defenses.","runner":"Fast movers. Cover the route to the exit.","swarm":"Low health. Rapid fire clears them quickly.","tank":"High health. Strongest targeting concentrates fire.","boss":"Heavy health and core damage. Prepare concentrated fire."}
	for group: Dictionary in forecast.groups:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel",style(PANEL,AMBER if str(group.kind) == "boss" else Color("304955")))
		card.set_meta("forecast_kind",str(group.kind))
		card.set_meta("forecast_group",group.duplicate(true))
		box.add_child(card)
		var details := VBoxContainer.new()
		details.add_theme_constant_override("separation",5)
		card.add_child(details)
		details.add_child(label("%d × %s" % [int(group.count),str(names.get(str(group.kind),str(group.kind).capitalize()))],20,AMBER if str(group.kind) == "boss" else WHITE))
		details.add_child(label("%.1f HP  ·  %.2f speed  ·  %d core damage" % [float(group.health),float(group.speed),int(group.core_damage)],15,MINT))
		details.add_child(label(str(roles.get(str(group.kind),"")),15,MUTED))
	box.add_child(label(_controller_hint("Stats reflect current corruption. Planting a wrong number increases enemy health. Set each tower's target in its workshop.\n\nB / Escape closes this panel. Launch the wave from the board when ready."),15,MUTED))
	box.add_child(label(_controller_hint("D-pad / left stick: scroll · A / B: back"),14,MINT))
	var bottom_back := button(back.text,_close_overlay)
	bottom_back.set_meta("focus_id","wave:close_bottom")
	box.add_child(bottom_back)
	back.grab_focus()

func _help() -> void:
	if tutorial.active:
		tutorial.show_step()
		return
	var box := _modal(720,652)
	box.add_child(label("HOW TO PLAY",26,MINT))
	# Keep the initial safe action visible above the long instructions.
	var back := button("Got it",_close_overlay,true)
	box.add_child(back)
	box.add_child(button("Play guided first round",func(): tutorial.start(self),true))
	box.add_child(button("Audio settings",_show_audio_settings))
	box.add_child(button("Controller mapping",_show_controller_settings))
	box.add_child(button("Feedback / report a bug",feedback_ui.show_panel))
	for text in [
		"01  SOLVE  ·  Fill each row, column and 3x3 box with 1-9. Tap a square, then a number, or drag a number onto the board. Correct answers grow towers. Wrong answers cost 5 seconds. At zero, preparation begins. You may move on early.",
		"02  PREPARE  ·  Read Wave intel before launching. Select a tower, open Gear, select modules and Install selected. Each tower has five slots. Slow and Range filters help plan your build. Modules return to Gear on each new board; equip your new towers before launching. Menus pause the game.",
		"03  DEFEND  ·  Your recent answers shape the route before battle. During the wave, use reserve seeds to add towers. Wrong numbers are allowed, but add corruption: later enemies have more health, and those towers disappear after the wave.",
		"04  LOOT  ·  Open all affordable chests together, or enable automatic opening below. Both use the same fragment costs. Camp offers salvage slots and upgrades between rounds. Credits, gear and number upgrades carry over."
	]:
		var l := label(text,17,WHITE)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	box.add_child(label("CAMERA",12,MINT))
	var camera_help := label(_controller_hint("Right-drag the board or hold Q / E to rotate. Home resets the view.
Touch: tap Camera, drag left / right, then Done.
Controller: press L3, use the right stick, R3 to reset, B to finish."),15,MUTED)
	camera_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(camera_help)
	box.add_child(label("CONTROLLER",12,MINT))
	var input_label := label(ControllerBindings.help_text(controller.bindings),15,MUTED)
	box.add_child(input_label)
	box.add_child(label(_controller_hint("Tower modules: A on a tower focuses its first empty + socket. A opens available modules; A fits one and returns to this tower. B returns one step.\nD-pad / left stick: planted towers during setup and combat. LB / RB cycle towers; solving keeps number selection. Gear: A selects modules; Y installs the selection on this tower. Start opens Gear, Chests and Camp."),15,MUTED))
	var reduce := button("Reduced motion: " + ("ON" if reduced_motion else "OFF"),_toggle_reduced_motion)
	reduce.pressed.connect(func(): reduce.text = "Reduced motion: " + ("ON" if reduced_motion else "OFF"))
	box.add_child(reduce)
	var sound_toggle := button("Sound: " + ("OFF" if muted else "ON"),_toggle_sound)
	sound_toggle.pressed.connect(func(): sound_toggle.text = "Sound: " + ("OFF" if muted else "ON"))
	box.add_child(sound_toggle)
	var notes := button("Notes: " + ("ON" if board_notes else "OFF"),_toggle_notes)
	notes.pressed.connect(func(): notes.text = "Notes: " + ("ON" if board_notes else "OFF"))
	box.add_child(notes)
	var auto_open := button("Auto-open affordable chests: " + ("ON" if auto_open_chests else "OFF"),_toggle_auto_open_chests)
	auto_open.pressed.connect(func(): auto_open.text = "Auto-open affordable chests: " + ("ON" if auto_open_chests else "OFF"))
	box.add_child(auto_open)
	var auto_note := label("Uses fragments at the normal cost. Opens together after combat or when you finish your current menu action.",14,MUTED)
	auto_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(auto_note)
	var speed := button("Battle speed: %dx" % int(game_speed),_cycle_speed)
	speed.pressed.connect(func(): speed.text = "Battle speed: %dx" % int(game_speed))
	box.add_child(speed)
	box.add_child(label(_controller_hint("Long waves: after 45 battle seconds and the final spawn, Fast-forward 8x becomes available. Tap it or press Y / Enter. It speeds up enemies too. Press again or B to stop. Core hits, menus and tower inspection return to your normal speed; it never carries into the next wave."),15,MUTED))
	if has_active_run and selected_cell >= 0 and not run.givens[selected_cell] and not run.towers.has(selected_cell):
		box.add_child(button("Reveal selected square · 6 credits",func(): _action(run.hint(selected_cell)); _close_overlay()))
	box.add_child(label("Version " + str(ProjectSettings.get_setting("application/config/version")),11,MUTED))
	box.add_child(button("Got it",_close_overlay,true))
	back.grab_focus()

func _show_next_round() -> void:
	puzzle_choice = run.puzzle_difficulty
	combat_choice = run.combat_difficulty
	var box := _modal(610,450)
	box.add_child(label("NEXT ROUND",31,MINT))
	box.add_child(label("Next up: round %02d / %02d" % [run.round_no+1,run.max_rounds],22))
	if run.mode == "campaign":
		_choice_row(box,"SUDOKU DIFFICULTY",[["easy","Easy"],["medium","Medium"],["hard","Hard"]],run.puzzle_difficulty,func(v): puzzle_choice=v)
		_choice_row(box,"SIEGE DIFFICULTY",[["easy","Easy"],["medium","Medium"],["hard","Hard"]],run.combat_difficulty,func(v): combat_choice=v)
	else: box.add_child(label("Locked in keeps your starting difficulties for all 50 rounds.",17,MUTED))
	var note := label("Your credits, gear and number upgrades carry over. Towers reset; modules return to Gear. Fit modules to your new towers before launching.",16,MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var go := button("Start next round",func():
		var next_result: Dictionary = run.next_round({"puzzle_difficulty":puzzle_choice,"combat_difficulty":combat_choice})
		if not next_result.ok:
			_toast(next_result.message,false)
			return
		selected_cell = -1
		selected_number = 0
		reserve_mode = false
		armed_item = ""
		dock.set_selected(-1)
		_clear_wrong_guess_feedback()
		world.setup(run)
		_close_overlay()
		_save()
	,true)
	box.add_child(go)
	box.add_child(button("Back to loot",_close_overlay))
	go.grab_focus()

func _show_result() -> void:
	if tutorial.active:
		tutorial.show_step()
		return
	var box := _modal(640,660)
	box.add_child(label("VICTORY" if run.phase=="won" else "CORE DESTROYED",31,MINT if run.phase=="won" else AMBER))
	box.add_child(label("All rounds cleared." if run.phase=="won" else "Your run ends here.",23))
	box.add_child(label("ROUND %02d  /  SCORE %d  /  SEED %d" % [run.round_no,run.score,run.seed_value],17,MUTED))
	var go := button("Retry this seed",_retry_same_seed,true)
	go.set_meta("focus_id","result:retry")
	go.tooltip_text = "Start from round 1 with this seed, mode, and original difficulties. Campaign difficulty choices can differ again."
	box.add_child(go)
	box.add_child(button("New run setup",func(): _show_menu(true)))
	box.add_child(button("Inspect the board",_close_overlay))
	for text: String in StrategyFeedback.result_lines(run):
		var detail := label(text,17,WHITE)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(detail)
	box.add_child(label("D-pad / left stick: navigate and scroll",14,MINT))
	var return_to_retry := button("Back to retry",func(): go.grab_focus())
	return_to_retry.set_meta("focus_id","result:bottom")
	box.add_child(return_to_retry)
	go.grab_focus()

func _retry_same_seed() -> void:
	if run.phase not in ["won","lost"]: return
	if not _can_replace_saved_run(): return
	var retry_seed: int = run.seed_value
	var options: Dictionary = run.retry_options()
	options["achievement_run_id"] = _new_achievement_run_id()
	_cancel_camera_controls()
	_close_controller_numbers()
	run.new_run(retry_seed,options)
	_clear_wrong_guess_feedback()
	mode_choice = str(options.mode)
	puzzle_choice = str(options.puzzle_difficulty)
	combat_choice = str(options.combat_difficulty)
	has_active_run = true
	selected_cell = -1
	selected_number = 0
	armed_item = ""
	reserve_mode = false
	manual_pause = false
	dock.reset_for_run()
	world.setup(run)
	world.set_selected(-1,0)
	last_phase = run.phase
	_close_overlay()
	if _save(): _toast("Same seed, fresh run. Try a different route or loadout.")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode in [KEY_Q,KEY_E]:
		if not event.pressed:
			_camera_keys.erase(event.keycode)
		elif _camera_available():
			_camera_keys[event.keycode] = true
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_HOME and _camera_available():
			_reset_camera_view()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			return
		if event.keycode == KEY_ESCAPE:
			if camera_mode: _set_camera_mode(false)
			elif menu_open: _close_overlay()
			elif dock.is_open(): dock.close_panel()
			else: _show_menu(false)
			return
		if menu_open: return
		if event.keycode == KEY_I:
			_show_wave_intel()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_TAB: _toggle_dock("bag"); return
		if event.keycode == KEY_P: _toggle_pause(); return
		if event.keycode == KEY_M: _toggle_sound(); return
		if dock.is_open() or camera_mode: return
		controller_used = false
		if event.keycode >= KEY_1 and event.keycode <= KEY_9: _choose_number(event.keycode-KEY_0)
		elif event.keycode == KEY_ENTER: _advance()
		elif event.keycode == KEY_H: _action(run.hint(selected_cell))
		elif event.keycode == KEY_LEFT: _move_selection(Vector2i.LEFT)
		elif event.keycode == KEY_RIGHT: _move_selection(Vector2i.RIGHT)
		elif event.keycode == KEY_UP: _move_selection(Vector2i.UP)
		elif event.keycode == KEY_DOWN: _move_selection(Vector2i.DOWN)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.pressed: _camera_keys.erase(event.keycode)
	if controller_cursor != null and controller_cursor.owns_event(event): return
	if event is InputEventKey and event.pressed:
		_pointer_activity()
	elif event is InputEventMouseButton:
		if event.pressed: _pointer_activity(-1)
		elif _pointer_hint_owner == -1: _finish_pointer_activity.call_deferred()
	elif event is InputEventScreenTouch:
		if event.pressed: _pointer_activity(event.index)
		elif _pointer_hint_owner == event.index: _finish_pointer_activity.call_deferred()

func _camera_available() -> bool:
	return _camera_window_focused and not _steam_overlay_active and has_active_run and not menu_open and not manual_pause and not dock.is_open() and armed_item.is_empty() and run.phase in ["solve","prep","battle","loot"] and (seed_pointer == null or not seed_pointer.is_active()) and not get_viewport().gui_is_dragging()

func _toggle_camera_mode() -> void:
	if camera_mode: _set_camera_mode(false)
	elif _camera_available(): _set_camera_mode(true)

func _set_camera_mode(value: bool) -> void:
	if camera_mode == value: return
	_close_controller_numbers()
	camera_mode = value
	_camera_axis = Vector2.ZERO
	_camera_keys.clear()
	if board_input != null: board_input.cancel_pointer()
	if seed_pointer != null: seed_pointer.cancel()
	if controller_cursor != null: controller_cursor.deactivate()
	if controller != null: controller.reset_pointer()
	if value: tools_open = false
	_layout_ui()

func _cancel_camera_controls() -> void:
	_camera_axis = Vector2.ZERO
	_camera_keys.clear()
	if board_input != null: board_input.cancel_pointer()
	if camera_mode: _set_camera_mode(false)

func _reset_camera_view() -> void:
	if not _camera_available(): return
	world.reset_camera()

func _rotate_camera(radians: float) -> void:
	if _camera_available(): world.rotate_camera(radians)

func _tick_camera_controls(dt: float) -> void:
	if not _camera_available():
		if camera_mode or not _camera_keys.is_empty() or _camera_axis != Vector2.ZERO or (board_input != null and board_input.camera_pointer_active()):
			_cancel_camera_controls()
		return
	var strength: float = float(_camera_keys.has(KEY_E))-float(_camera_keys.has(KEY_Q))
	if camera_mode and absf(_camera_axis.x) > 0.20:
		strength += signf(_camera_axis.x)*pow((absf(_camera_axis.x)-0.20)/0.80,1.4)
	if not is_zero_approx(strength): world.rotate_camera(clampf(strength,-1.0,1.0)*CAMERA_SPEED*dt)

func _controller_pointer_axis(axis: Vector2) -> void:
	if camera_mode: _camera_axis = axis
	else: controller_cursor.set_axis(axis)

func _controller_pointer_button(source: String, pressed: bool) -> void:
	if camera_mode:
		if source == "stick" and pressed: _reset_camera_view()
		return
	controller_cursor.set_button(source,pressed)

func _controller_pointer_precision(pressed: bool) -> void:
	if not camera_mode: controller_cursor.set_precision(pressed)

func _controller_pointer_reset() -> void:
	_camera_axis = Vector2.ZERO
	if controller_cursor != null: controller_cursor.deactivate()

func _controller_pointer_active() -> bool:
	return controller_cursor != null and controller_cursor.is_active()

func _controller_pointer_activity() -> void:
	if dock.controller_workshop_cell >= 0: dock.cancel_controller_context(true)
	_close_controller_numbers()
	_pointer_hint_owner = -2
	if camera_mode:
		var changed_mode: bool = not controller_used
		controller_used = true
		if changed_mode: _refresh()
		return
	var changed_mode: bool = not controller_used or not _controller_pointer_active()
	if not _controller_pointer_active():
		if board_input != null: board_input.cancel_pointer()
		if seed_pointer != null: seed_pointer.cancel()
		controller_cursor.activate()
	controller_used = true
	if changed_mode: _refresh()

func _controller_activity() -> void:
	_camera_axis = Vector2.ZERO
	_cursor_gesture_canceled = controller_cursor.deactivate() if controller_cursor != null else false
	_pointer_hint_owner = -2
	if board_input != null: board_input.cancel_pointer()
	if seed_pointer != null and seed_pointer.is_active(): seed_pointer.cancel()
	if not controller_used:
		controller_used = true
		# Preserve the currently focused card through this input dispatch. The
		# dock can rebuild hints afterwards without losing the first A press.
		dock.set_controller_mode.call_deferred(true)
		_refresh()

func _release_ui_focus() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused): focused.release_focus()

func _controller_scope() -> Control:
	if menu_open and is_instance_valid(overlay): return overlay
	if dock.is_open(): return dock._shell
	return null

func _controller_buttons(scope: Control) -> Array[Control]:
	var buttons: Array[Control] = []
	for node in scope.find_children("*","BaseButton",true,false):
		if node.is_visible_in_tree() and not node.disabled and node.focus_mode != Control.FOCUS_NONE:
			buttons.append(node)
	return buttons

func _controller_navigate(direction: Vector2i) -> void:
	if camera_mode: return
	if _controller_number_cell >= 0:
		_cycle_controller_number(1 if direction.x > 0 or direction.y > 0 else -1)
		return
	if menu_open and is_instance_valid(overlay) and bool(overlay.get_meta("achievements_panel",false)) and direction.y != 0:
		platform_ui.navigate_achievements(direction.y)
		return
	if menu_open and is_instance_valid(overlay) and bool(overlay.get_meta("wave_intel",false)) and direction.y != 0:
		# Intel is an informational list. Let the stick / D-pad scroll its text,
		# without turning every enemy description into a nonfunctional button.
		var scroll: ScrollContainer = overlay.find_children("*","ScrollContainer",true,false)[0]
		var limit: int = maxi(0,int(scroll.get_v_scroll_bar().max_value-scroll.size.y))
		scroll.scroll_vertical = clampi(scroll.scroll_vertical+direction.y*maxi(80,int(scroll.size.y*0.3)),0,limit)
		if scroll.scroll_vertical == 0 or scroll.scroll_vertical >= limit:
			var id := "wave:close" if scroll.scroll_vertical == 0 else "wave:close_bottom"
			for control in _controller_buttons(overlay):
				if str(control.get_meta("focus_id","")) == id: control.grab_focus()
		return
	var scope: Control = _controller_scope()
	if scope == null:
		if has_active_run and not manual_pause: _move_selection(direction)
		return
	if dock.is_open() and not menu_open:
		dock.navigate_focus(direction)
		return
	var buttons: Array[Control] = _controller_buttons(scope)
	if buttons.is_empty(): return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if not buttons.has(focused):
		buttons[0].grab_focus()
		return
	var side: int = SIDE_LEFT if direction.x < 0 else (SIDE_RIGHT if direction.x > 0 else (SIDE_TOP if direction.y < 0 else SIDE_BOTTOM))
	# Audio has paired -/+ controls: vertical navigation must retain its column.
	var spatial_navigation: bool = direction.x != 0 or _seed_editing or bool(scope.get_meta("audio_settings",false))
	var neighbor: Control = focused.find_valid_focus_neighbor(side) if spatial_navigation else null
	if not buttons.has(neighbor) or neighbor == focused:
		var increment: int = 1 if direction.x > 0 or direction.y > 0 else -1
		neighbor = buttons[clampi(buttons.find(focused)+increment,0,buttons.size()-1)]
	neighbor.grab_focus()
	for scroll in scope.find_children("*","ScrollContainer",true,false):
		if scroll.is_ancestor_of(neighbor): scroll.ensure_control_visible.call_deferred(neighbor)

func _controller_confirm_ui() -> void:
	var scope: Control = _controller_scope()
	if scope == null: return
	var focused: Control = get_viewport().gui_get_focus_owner()
	var buttons: Array[Control] = _controller_buttons(scope)
	if not buttons.has(focused):
		if not buttons.is_empty(): buttons[0].grab_focus()
		return
	# This event is already consumed by ControllerInput, so GUI handling cannot
	# activate another control or fall through to the board on button release.
	if focused is BaseButton and not focused.disabled:
		focused.pressed.emit()

func _controller_action(action: String) -> void:
	if controller.settings_mode:
		if controller.capturing: return
		if action == "confirm": _controller_confirm_ui()
		elif action == "cancel": _close_overlay()
		return
	if dock.controller_workshop_cell >= 0 and not dock.validate_controller_context() and action in ["confirm","previous","next"]: return
	# Validate before dispatch too: a solve timeout must not leave a stale picker.
	if _controller_number_cell >= 0:
		_refresh()
		if _controller_number_cell < 0 and action == "confirm": return
		if _controller_number_cell >= 0:
			if action == "advance" and run.phase == "battle": return
			if action == "confirm":
				if _controller_number_choices().has(selected_number): _choose_number(selected_number)
				else: _cycle_controller_number(1)
				return
			if action in ["previous","next"]:
				_cycle_controller_number(-1 if action == "previous" else 1)
				return
			_close_controller_numbers()
			if action == "cancel":
				_refresh()
				return
	if action == "camera":
		_toggle_camera_mode()
		return
	if camera_mode and action == "cancel":
		_set_camera_mode(false)
		_cursor_gesture_canceled = false
		return
	if camera_mode and action in ["confirm","previous","next","advance"]: return
	var canceled_gesture: bool = _cursor_gesture_canceled
	_cursor_gesture_canceled = false
	if action == "cancel" and canceled_gesture:
		_refresh()
		return
	if action == "pause":
		controller.reset_navigation()
		if _seed_editing: _show_menu(_seed_return_initial)
		elif menu_open:
			if has_active_run: manual_pause = false; _close_overlay()
		else: _show_menu(false)
		return
	if action == "cancel":
		if _seed_editing: _show_menu(_seed_return_initial)
		elif menu_open: _close_overlay()
		elif dock.controller_back(): pass
		elif dock.is_open(): dock.close_panel()
		elif cleanup_fast: _toggle_cleanup()
		else:
			reserve_mode = false
			armed_item = ""
			dock.clear_armed()
			selected_number = 0
			world.set_selected(selected_cell,0)
			_refresh()
		return
	if action == "help":
		_help()
		return
	if menu_open:
		if action == "confirm": _controller_confirm_ui()
		return
	if action == "gear":
		_toggle_dock("bag")
		return
	if dock.is_open():
		if action == "confirm": _controller_confirm_ui()
		elif action == "advance" and dock.current_panel == "bag" and dock.has_selected_modules(): dock.install_selected_modules()
		elif action in ["previous","next"] and dock.controller_context_active(): _cycle_upgrade_tower(-1 if action == "previous" else 1)
		elif action in ["previous","next"] and dock.current_panel == "tower": _cycle_tower(-1 if action == "previous" else 1)
		elif action in ["previous","next"]: dock.cycle_panel(-1 if action == "previous" else 1)
		return
	if manual_pause: return
	match action:
		"previous", "next":
			if _tower_navigation_active():
				_cycle_tower(-1 if action == "previous" else 1)
				return
			if selected_number <= 0: selected_number = 9 if action == "previous" else 1
			else: selected_number = posmod(selected_number-1+(-1 if action == "previous" else 1),9)+1
			world.set_selected(selected_cell,selected_number)
			_refresh()
		"confirm":
			if _tower_navigation_active() and not run.towers.has(selected_cell): _move_tower_selection(Vector2i.RIGHT)
			elif selected_cell < 0: _select(40,false,false)
			elif run.board[selected_cell] == 0 and _number_placement_allowed(): _open_controller_numbers(selected_cell)
			elif run.towers.has(selected_cell) and armed_item.is_empty() and run._gear_phase():
				selected_number = int(run.towers[selected_cell].number)
				dock.open_controller_workshop(selected_cell)
				_refresh()
			else: _select(selected_cell,true)
		"advance": _advance()

func _controller_disconnected() -> void:
	_cancel_camera_controls()
	if controller_cursor != null: controller_cursor.deactivate()
	if has_active_run:
		if not menu_open: _show_menu(false)
		_toast("Controller disconnected. Game paused; reconnect or use touch / mouse.",false)

func _show_seed_pad() -> void:
	if is_instance_valid(seed_input): _seed_text = seed_input.text
	_seed_editing = true
	var box := _modal(490,570)
	box.add_child(label("CHOOSE A RUN SEED",25,MINT))
	box.add_child(label(_controller_hint("D-pad / stick move · A select · B back"),15,MUTED))
	var display := label(_seed_text if not _seed_text.is_empty() else "Random",30,WHITE)
	display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(display)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	box.add_child(grid)
	for digit in ["1","2","3","4","5","6","7","8","9","Clear","0","Delete"]:
		var value: String = digit
		var key := button(value,func():
			if value == "Clear": _seed_text = ""
			elif value == "Delete": _seed_text = _seed_text.left(maxi(0,_seed_text.length()-1))
			elif _seed_text.length() < 10:
				_seed_text += value
				_seed_text = str(mini(2147483647,_seed_text.to_int()))
			display.text = _seed_text if not _seed_text.is_empty() else "Random"
		)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.set_meta("seed_key",value)
		grid.add_child(key)
	box.add_child(button("Use seed",func(): _show_menu(_seed_return_initial),true))
	grid.get_child(0).grab_focus()
