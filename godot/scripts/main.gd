extends Node3D

const RunScript = preload("res://scripts/run.gd")
const BoardScript = preload("res://scripts/board.gd")
const CanvasBoardScript = preload("res://scripts/board_canvas.gd")
const RenderProfile = preload("res://scripts/render_profile.gd")
const DockScript = preload("res://scripts/dock.gd")
const SoundScript = preload("res://scripts/sound.gd")
const DropScript = preload("res://scripts/board_drop.gd")
const ControllerScript = preload("res://scripts/controller_input.gd")
const INK := Color("0a1722")
const PANEL := Color("112634")
const MINT := Color("83e7c1")
const AMBER := Color("ffb577")
const WHITE := Color("eef6ec")
const MUTED := Color("89a5ae")
const COLORS := [Color("6de8ff"), Color("a4c7ff"), Color("c6a0ff"), Color("ffae68"), Color("fb86c3"), Color("9be878"), Color("ffe188"), Color("bb9bff"), Color("ff7289")]

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
var reduced_motion := false
var board_notes := true
var game_speed := 1.0
var last_phase := ""
var ui_elapsed := 0.0
var controller_used := false
var controller
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

func _ready() -> void:
	get_tree().auto_accept_quit = false
	run.new_run(784217, {"mode":"campaign", "puzzle_difficulty":"easy", "combat_difficulty":"easy"})
	get_viewport().disable_3d = RenderProfile.uses_canvas()
	world = CanvasBoardScript.new() if RenderProfile.uses_canvas() else BoardScript.new()
	add_child(world)
	world.setup(run)
	sound = SoundScript.new()
	add_child(sound)
	_build_ui()
	controller = ControllerScript.new()
	controller.activity.connect(_controller_activity)
	controller.action_pressed.connect(_controller_action)
	controller.navigated.connect(_controller_navigate)
	controller.controller_lost.connect(_controller_disconnected)
	add_child(controller)
	controller_used = not Input.get_connected_joypads().is_empty()
	dock.set_controller_mode(controller_used)
	get_viewport().size_changed.connect(_queue_layout)
	_update_canvas_scale()
	_layout_ui()
	_show_menu(true)
	_refresh()
	if "--smoke-test" in OS.get_cmdline_user_args(): print("SUDOKU_DEFENSE_READY")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
		get_tree().quit()

func style(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

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
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", INK if accent else WHITE)
	b.add_theme_color_override("font_hover_color", INK if accent else WHITE)
	b.add_theme_color_override("font_pressed_color", INK if accent else WHITE)
	b.add_theme_stylebox_override("normal", style(AMBER if accent else PANEL, Color("35505a")))
	b.add_theme_stylebox_override("hover", style(Color("ffc891") if accent else Color("214252"), MINT))
	b.add_theme_stylebox_override("pressed", style(MINT if accent else Color("305564"), MINT))
	b.add_theme_stylebox_override("focus", style(Color(0,0,0,0), MINT))
	b.add_theme_stylebox_override("disabled", style(Color("172631"), Color("253c48")))
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
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background",style(Color("1a333f"),Color.TRANSPARENT,3))
	progress.add_theme_stylebox_override("fill",style(MINT,Color.TRANSPARENT,3))
	positioned(progress,Rect2(30,313,174,5))
	selected_label = label("SELECT A SQUARE",13,MINT)
	positioned(selected_label,Rect2(30,352,200,24))
	candidate_label = label("",17)
	candidate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	positioned(candidate_label,Rect2(30,383,193,100))
	var notes_btn: Button = hud("notes", button("Notes ON",func(): board_notes = not board_notes; _refresh()))
	positioned(notes_btn,Rect2(30,509,174,44))
	notes_btn.pressed.connect(func(): notes_btn.text = "Notes  ON" if board_notes else "Notes  OFF")
	var hint_btn: Button = hud("hint", button("Reveal / 6",func(): _action(run.hint(selected_cell))))
	hint_btn.tooltip_text = "Reveal selected square, costs credits (H)"
	positioned(hint_btn,Rect2(30,563,174,44))
	reserve_button = button("Buy reserve  ·  6",func(): _action(run.buy_seed(selected_number if selected_number>0 else 1)))
	reserve_button.tooltip_text = "Buy one emergency seed of the selected number"
	positioned(reserve_button,Rect2(30,617,174,44))
	bag_button = button("Gear",func(): _toggle_dock("bag"))
	positioned(bag_button,Rect2(1092,94,164,46))
	loot_button = button("Chests",func(): _toggle_dock("loot"))
	positioned(loot_button,Rect2(1092,149,164,46))
	var camp: Button = hud("camp", button("Camp",func(): _toggle_dock("camp")))
	camp.tooltip_text = "Passives and salvage slots, available between battles"
	positioned(camp,Rect2(1092,204,164,46))
	pause_label = label("TACTICAL PAUSE",14,AMBER)
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	positioned(pause_label,Rect2(430,85,420,32))
	var bottom: Panel = hud("bottom", Panel.new())
	bottom.add_theme_stylebox_override("panel",style(Color("0a1722f5"),Color("28414c"),0))
	positioned(bottom,Rect2(0,696,1280,104))
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.move_child(bottom,1) # Background must stay behind the quick tabs moved here on phones.
	positioned(hud("plant_caption",label("PLANT A NUMBER",11,MUTED)),Rect2(26,710,170,22))
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
	var speed: Button = hud("speed", button("1x",func(): game_speed = 2.0 if game_speed == 1.0 else 1.0; _refresh()))
	speed.tooltip_text = "Battle speed"
	positioned(speed,Rect2(848,715,74,56))
	speed.pressed.connect(func(): speed.text = "2x" if game_speed == 2.0 else "1x")
	notice = label("",18,WHITE)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_stylebox_override("normal",style(Color("173c42ed"),MINT))
	positioned(notice,Rect2(300,640,680,44))
	notice.hide()
	dock = DockScript.new()
	ui.add_child(dock)
	dock.setup(run)
	dock.changed.connect(_action)
	dock.closed.connect(func(): armed_item = ""; _release_ui_focus(); _refresh())
	dock.cell_requested.connect(func(cell): _select(cell,false))
	dock.item_armed.connect(func(item_id):
		if controller_used:
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
	hud_nodes.tools.visible = portrait_layout
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
		# Four quick tabs expose one management surface at a time.
		var quick_w := (w-64)/4.0
		var quick_buttons: Array = [bag_button,loot_button,hud_nodes.camp,hud_nodes.tools]
		for i in range(quick_buttons.size()):
			var quick: Button = quick_buttons[i]
			_place(quick,Rect2(20+i*(quick_w+8),h-276,quick_w,72)); _font(quick,24)
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
		_place(progress,Rect2(30,313,174,5))
		_place(selected_label,Rect2(30,352,200,24)); _font(selected_label,13)
		_place(candidate_label,Rect2(30,383,193,100)); _font(candidate_label,17)
		_place(hud_nodes.notes,Rect2(30,509,174,46)); _font(hud_nodes.notes,17)
		_place(hud_nodes.hint,Rect2(30,563,174,46)); _font(hud_nodes.hint,17)
		_place(reserve_button,Rect2(30,617,174,46)); _font(reserve_button,17)
		_place(bag_button,Rect2(w-188,94,164,46)); _font(bag_button,17)
		_place(loot_button,Rect2(w-188,149,164,46)); _font(loot_button,17)
		_place(hud_nodes.camp,Rect2(w-188,204,164,46)); _font(hud_nodes.camp,17)
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
			_place(hud_nodes.bottom,Rect2(0,h-80,w,80))
			for i in range(9):
				_place(number_buttons[i],Rect2(20+i*61,h-70,54,50)); _font(number_buttons[i],29)
			_place(hud_nodes.speed,Rect2(w-418,h-70,74,50)); _font(hud_nodes.speed,22)
			_place(next_button,Rect2(w-326,h-70,304,50)); _font(next_button,21)
			_place(controls_label,Rect2(20,h-19,680,17))
			_place(pause_label,Rect2(260,68,w-480,28)); _font(pause_label,16)
			_place(notice,Rect2(18,270,188,158)); _font(notice,18)
			board_rect = Rect2(218,80,w-(578 if open else 406),h-170)
	if world.has_method("set_board_rect"): world.set_board_rect(board_rect)
	if dock != null and dock.has_method("set_layout"):
		dock.set_layout(layout_size,portrait_layout,board_rect.end.y)
		dock.z_index = 10
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
		"prep": phase_detail.text = "PREPARE  /  %d towers" % run.towers.size()
		"battle": phase_detail.text = "DEFEND  %d / %d" % [run.kills,run.spawn_total]
		"loot": phase_detail.text = "LOOT & GROW"
		_: phase_detail.text = "RUN COMPLETE"
	if selected_cell >= 0:
		selected_label.text = "ROW %d / COL %d" % [selected_cell/9+1,selected_cell%9+1]
		if run.towers.has(selected_cell):
			var t: Dictionary = run.towers[selected_cell]
			candidate_label.text = "Tower %d  /  Lv %d  /  %d of 5 modules" % [t.number,run.tower_stats(selected_cell).level,t.attachments.size()]
		elif run.givens[selected_cell]: candidate_label.text = "Fixed clue. Choose an empty square."
		elif board_notes: candidate_label.text = "Try  " + "  ".join(run.candidates(selected_cell).map(func(v): return str(v)))
		else: candidate_label.text = "Tap a number to plant here."
	else:
		selected_label.text = "YOUR ANSWERS GROW TOWERS"
		candidate_label.text = "Tap an empty square, then a number."
	reserve_button.text = "Seed %d / 6" % (selected_number if selected_number>0 else 1)
	pause_label.text = "TACTICAL PAUSE" if dock.is_open() else "PAUSED"

func _layout_modal() -> void:
	if not is_instance_valid(overlay): return
	overlay.z_index = 20
	for panel in overlay.get_children():
		if not panel is PanelContainer: continue
		var requested: Vector2 = panel.get_meta("requested_size",Vector2(650,640))
		var wanted := Vector2(minf(requested.x,layout_size.x-32),minf(requested.y,layout_size.y-32))
		if portrait_layout: wanted = Vector2(layout_size.x-32,minf(requested.y*1.7,layout_size.y-48))
		_place(panel,Rect2((layout_size-wanted)/2,wanted))
		_style_modal_tree(panel)

func _style_modal_tree(node: Node) -> void:
	if node is Label or node is Button or node is LineEdit:
		if not node.has_meta("base_font"): node.set_meta("base_font",node.get_theme_font_size("font_size"))
		var base: int = node.get_meta("base_font")
		_font(node,maxi(21,int(base*1.35)) if portrait_layout else base)
		if node is Label: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if node is Button:
			node.custom_minimum_size.y = 72 if portrait_layout else 46
			node.clip_text = true
		if node is LineEdit: node.custom_minimum_size.y = 60 if portrait_layout else 36
	for child in node.get_children(): _style_modal_tree(child)

func _process(dt: float) -> void:
	if dock.is_open() != _dock_was_open:
		_dock_was_open = dock.is_open()
		_layout_ui()
	var blocked: bool = menu_open or manual_pause or dock.is_open() or not armed_item.is_empty()
	if not blocked:
		run.update(minf(dt,0.05)*game_speed if run.phase == "battle" else minf(dt,0.05))
	if world.has_method("set_panel_open"): world.set_panel_open(dock.is_open())
	world.tick(minf(dt,0.05))
	for event in run.drain_events():
		world.play_event(event)
		sound.play_event(event)
	if notice_time > 0:
		notice_time -= dt
		notice.modulate.a = minf(1,notice_time*2)
		if notice_time <= 0:
			notice.hide()
			_update_context_visibility()
	ui_elapsed += dt
	if ui_elapsed > .15:
		ui_elapsed = 0
		_refresh()
	if run.phase != last_phase:
		last_phase = run.phase
		_save()
		if run.phase == "loot" and not menu_open:
			_toast("WAVE CLEAR  ·  Your garden held. Collect your rewards.")
			dock.open_panel("loot",selected_cell)
		elif run.phase in ["won","lost"] and not menu_open:
			_show_result()
	save_elapsed += dt
	if save_elapsed > 15 and not menu_open:
		save_elapsed = 0
		_save()

func _refresh() -> void:
	resources.text = "CORE %d/%d   CREDITS %d   FRAGMENTS %d" % [int(run.health),int(run.max_health),run.credits,run.fragments]
	var phases := ["solve","prep","battle","loot"]
	for i in range(4): phase_badges[i].modulate = MINT if run.phase == phases[i] else Color("647d85")
	phase_label.text = "ROUND %02d / %02d" % [run.round_no,run.max_rounds]
	var count: int = run.towers.size()
	match run.phase:
		"solve":
			phase_detail.text = "PLANT YOUR DEFENSE\n\n%d towers grown\n%02d:%02d remaining" % [count,int(run.timer)/60,int(run.timer)%60]
			progress.value = 100.0*run.timer/maxf(1,run.solve_duration)
			next_button.text = "Prepare defense"
		"prep":
			phase_detail.text = "MAKE IT YOURS\n\nAttach modules.\nUpgrade your favorites.\nThen hold the line."
			progress.value = 100
			next_button.text = "Launch wave"
		"battle":
			phase_detail.text = "HOLD THE LINE\n\n%d / %d defeated\n%d towers active\n%d corruption" % [run.kills,run.spawn_total,count,run.corruption]
			progress.value = 100.0*run.kills/maxi(1,run.spawn_total)
			next_button.text = "Wave in progress"
		"loot":
			phase_detail.text = "A LITTLE STRONGER\n\nCollect your loot.\nRefine your loadout.\nChoose the next grid."
			progress.value = 100
			next_button.text = "Next garden"
		_:
			phase_detail.text = "RUN COMPLETE"
			next_button.text = "New expedition"
	next_button.disabled = run.phase == "battle"
	reserve_button.text = "Seed %d  +1  ·  6" % selected_number if selected_number>0 else "Buy seed 1  ·  6"
	reserve_button.disabled = run.credits<6
	bag_button.text = "Gear %d" % run.items.size()
	loot_button.text = "Chests %d" % run.chests.size()
	pause_label.visible = (manual_pause or dock.is_open() or not armed_item.is_empty()) and not menu_open
	pause_label.text = "TACTICAL PAUSE  ·  Choose a tower · A attach · B cancel" if not armed_item.is_empty() else ("TACTICAL PAUSE  ·  Manage your loadout" if dock.is_open() else "PAUSED  ·  P / Start to resume")
	if selected_cell >= 0:
		selected_label.text = "ROW %d  /  COLUMN %d" % [selected_cell/9+1,selected_cell%9+1]
		if run.towers.has(selected_cell):
			var t: Dictionary = run.towers[selected_cell]
			candidate_label.text = "Seed %d · Lv %d\n%d / 5 modules\n%s" % [t.number,run.tower_stats(selected_cell).level,t.attachments.size(),"A customize" if controller_used else "Click to customize"]
		elif run.givens[selected_cell]:
			candidate_label.text = "A fixed clue.\nGrow towers in\nthe empty squares."
		elif board_notes:
			var options: Array = run.candidates(selected_cell)
			candidate_label.text = "Possible numbers\n" + "  ".join(options.map(func(v): return str(v)))
		else: candidate_label.text = "Choose a number\nto plant here."
	else:
		selected_label.text = "GROW YOUR ADVANTAGE"
		candidate_label.text = "Select a square.\nPlant a number.\nBuild your own weapon."
	for i in range(9):
		var b: Button = number_buttons[i]
		b.tooltip_text = "Seed %d · %d reserves for emergency battle planting" % [i+1,run.inventory[i+1]]
		b.add_theme_stylebox_override("normal",style(Color("315950") if selected_number==i+1 else PANEL, COLORS[i] if selected_number==i+1 else Color("35505a")))
	if portrait_layout: _refresh_portrait_text()
	controls_label.text = "D-PAD move   LB/RB number   A plant   X gear   Y advance   B back" if controller_used else "CLICK select   1-9 plant   ENTER advance   TAB gear   ESC menu"
	if controller_used and not armed_item.is_empty(): controls_label.text = "D-PAD / STICK choose tower     A attach module     B cancel"

func _choose_number(number: int) -> void:
	selected_number = number
	world.set_selected(selected_cell,selected_number)
	if selected_cell >= 0 and not run.givens[selected_cell] and not run.towers.has(selected_cell):
		_action(run.place(selected_cell,number))
	_refresh()

func _select(cell: int, place_now: bool = true, equip_armed: bool = true) -> void:
	if cell < 0 or cell >= 81: return
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
		else: _toast("Choose a planted tower for this module.",false)
	elif place_now and run.towers.has(cell):
		dock.open_panel("tower",cell)
	elif place_now and selected_number > 0 and not run.givens[cell]:
		_action(run.place(cell,selected_number))
	_refresh()

func _move_selection(direction: Vector2i) -> void:
	if selected_cell < 0: selected_cell = 40
	else:
		var x: int = clampi(selected_cell%9+direction.x,0,8)
		var y: int = clampi(selected_cell/9+direction.y,0,8)
		selected_cell = y*9+x
	_select(selected_cell,false,false)

func _action(result: Dictionary) -> void:
	if result.has("message"): _toast(str(result.message),bool(result.get("ok",false)))
	if result.get("ok",false):
		_save()
		if not armed_item.is_empty() and not run.items.any(func(item): return str(item.id)==armed_item):
			armed_item = ""
			dock.clear_armed()
	dock.refresh()
	_refresh()

func _advance() -> void:
	if run.phase == "loot":
		dock.close_panel()
		_show_next_round()
	elif run.phase in ["won","lost"]: _show_menu(true)
	elif run.phase != "battle":
		dock.close_panel()
		_action(run.advance_phase())

func _toggle_dock(kind: String) -> void:
	if menu_open: return
	if dock.is_open() and dock.current_panel == kind: dock.close_panel()
	else: dock.open_panel(kind,selected_cell)
	_refresh()

func _toggle_sound() -> void:
	muted = not muted
	sound.set_muted(muted)
	_toast("Sound off" if muted else "Sound on")

func _toggle_pause() -> void:
	if menu_open: return
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

func _save() -> void:
	if not has_active_run: return
	var file := FileAccess.open("user://sudoku-defense-run.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(run.save_data()))

func _load() -> bool:
	if not FileAccess.file_exists("user://sudoku-defense-run.json"): return false
	var file := FileAccess.open("user://sudoku-defense-run.json",FileAccess.READ)
	if not file: return false
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary: return false
	var loaded: bool = run.load_data(data)
	if loaded: has_active_run = true
	return loaded

func _start_run() -> void:
	var input_seed: String = seed_input.text.strip_edges() if seed_input else ""
	var chosen_seed: int = input_seed.to_int() if input_seed.is_valid_int() else int(Time.get_unix_time_from_system())%2147483647
	has_active_run = true
	run.new_run(chosen_seed,{"mode":mode_choice,"puzzle_difficulty":puzzle_choice,"combat_difficulty":combat_choice})
	selected_cell = -1
	selected_number = 0
	armed_item = ""
	manual_pause = false
	dock.reset_for_run()
	world.setup(run)
	world.set_selected(-1,0)
	_close_overlay()
	last_phase = run.phase
	_save()
	_toast("Plant 6–8 correct answers, then prepare your defense.")

func _close_overlay() -> void:
	if not has_active_run:
		_show_menu(true)
		return
	if is_instance_valid(overlay): overlay.queue_free()
	overlay = null
	menu_open = false
	_seed_editing = false
	_release_ui_focus()
	_refresh()

func _modal(width: float = 650, height: float = 640) -> VBoxContainer:
	if is_instance_valid(overlay): overlay.queue_free()
	menu_open = true
	overlay = Control.new()
	ui.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.015,0.035,0.055,.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",style(Color("102330"),Color("40636b"),22))
	overlay.add_child(panel)
	panel.set_meta("requested_size",Vector2(width,height))
	panel.position = Vector2((1280-width)/2,(800-height)/2)
	panel.size = Vector2(width,height)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",22)
	margin.add_theme_constant_override("margin_right",22)
	margin.add_theme_constant_override("margin_top",16)
	margin.add_theme_constant_override("margin_bottom",16)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",13)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_layout_modal.call_deferred()
	return box

func _choice_row(box: VBoxContainer, title: String, values: Array, current: String, callback: Callable) -> void:
	box.add_child(label(title,12,MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	box.add_child(row)
	var choices: Array[Button] = []
	for value in values:
		var id: String = str(value[0])
		var b := button(str(value[1]),func(): callback.call(id))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size",15)
		b.add_theme_stylebox_override("normal",style(Color("315950") if current==id else PANEL,MINT if current==id else Color("35505a")))
		row.add_child(b)
		choices.append(b)
		b.pressed.connect(func():
			for c in choices: c.add_theme_stylebox_override("normal",style(Color("315950") if c==b else PANEL,MINT if c==b else Color("35505a")))
		)

func _show_menu(initial: bool = false) -> void:
	_seed_editing = false
	_seed_return_initial = initial
	var box := _modal(674,690)
	box.add_child(label("Y A K   S T U D I O S     /     G O D O T   E D I T I O N",11,MINT))
	box.add_child(label("SUDOKU DEFENSE",38,WHITE))
	var subtitle := label("Plant answers. Grow firepower.",21,AMBER)
	box.add_child(subtitle)
	var desc := label("A quiet grid becomes a living battlefield. Solve, stack your towers with loot, and keep your core alive.",16,MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)
	_choice_row(box,"EXPEDITION",[["campaign","Campaign / 50"],["freeplay","Free play / 1"],["locked","Locked in / 50"]],mode_choice,func(v): mode_choice=v)
	_choice_row(box,"SUDOKU  ·  HARDER GRIDS LEAVE MORE ROOM TO GROW",[["easy","Easy"],["medium","Medium"],["hard","Hard"]],puzzle_choice,func(v): puzzle_choice=v)
	_choice_row(box,"SIEGE DIFFICULTY",[["easy","Easy"],["medium","Medium"],["hard","Hard"]],combat_choice,func(v): combat_choice=v)
	var seed_row := HBoxContainer.new()
	box.add_child(seed_row)
	seed_row.add_child(label("RUN SEED  ",12,MUTED))
	seed_input = LineEdit.new()
	seed_input.placeholder_text = "Random — or enter a seed to replay"
	seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_input.custom_minimum_size.y = 36
	seed_input.add_theme_font_size_override("font_size",14)
	seed_input.text = _seed_text
	seed_input.text_changed.connect(func(value): _seed_text = value)
	seed_row.add_child(seed_input)
	seed_row.add_child(button("Keypad",_show_seed_pad))
	var start := button("Start expedition ",_start_run,true)
	box.add_child(start)
	var initial_focus: Button = start
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	box.add_child(row)
	if not initial:
		var resume := button("Resume run",_close_overlay)
		initial_focus = resume
		resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(resume)
	elif FileAccess.file_exists("user://sudoku-defense-run.json"):
		var resume := button("Continue saved run",func():
			if _load():
				world.setup(run)
				_close_overlay()
				last_phase = run.phase
				_toast("Welcome back. Your garden is waiting.")
			else: _toast("Save could not be loaded. Start a new expedition.",false)
		)
		resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(resume)
	var how := button("How to play",_help)
	how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(how)
	box.add_child(label("CONTROLLER • MOUSE • TOUCH     /     Saves automatically on this device",11,MUTED))
	initial_focus.grab_focus()

func _help() -> void:
	var box := _modal(720,652)
	box.add_child(label("A LITTLE LOGIC. A LOT OF FIREPOWER.",26,MINT))
	for text in [
		"01  SOLVE  ·  Select an empty square and plant a correct number. Every answer grows a tower and earns credits. Aim for 6–8 towers before your first wave.",
		"02  PREPARE  ·  Click a tower to upgrade it. Open Gear to drag a module onto a tower, or select an item and then its target. Each tower holds five modules. Repeats stack.",
		"03  DEFEND  ·  Your latest moves bend the enemy route. Need emergency firepower? Plant a number during battle—even an illegal one—at a credit and corruption cost.",
		"04  LOOT  ·  Enemies drop energy fragments. Spend them to unlock chests. Gear and family upgrades follow you to the next garden. Visit Camp between waves."
	]:
		var l := label(text,17,WHITE)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	box.add_child(label("CONTROLLER",12,MINT))
	var input_label := label("D-pad / left stick: move  ·  LB / RB: number / inventory tab\nA: confirm / plant / attach  ·  X: gear  ·  Y: next phase  ·  B: back\nStart: pause / resume  ·  View: help / options",15,MUTED)
	box.add_child(input_label)
	var reduce := button("Reduced motion: " + ("ON" if reduced_motion else "OFF"),func(): reduced_motion=not reduced_motion; world.set_reduced_motion(reduced_motion); _help())
	box.add_child(reduce)
	box.add_child(button("Sound: " + ("OFF" if muted else "ON"),func(): _toggle_sound(); _help()))
	box.add_child(button("Notes: " + ("ON" if board_notes else "OFF"),func(): board_notes=not board_notes; _help()))
	box.add_child(button("Battle speed: " + ("2x" if game_speed>1.0 else "1x"),func(): game_speed=1.0 if game_speed>1.0 else 2.0; _help()))
	if has_active_run and selected_cell >= 0 and not run.givens[selected_cell] and not run.towers.has(selected_cell):
		box.add_child(button("Reveal selected square · 6 credits",func(): _action(run.hint(selected_cell)); _close_overlay()))
	box.add_child(label("Godot edition " + str(ProjectSettings.get_setting("application/config/version")) + "  /  " + ("Compatible voxels" if RenderProfile.uses_canvas() else "3D voxels"),11,MUTED))
	var back := button("Got it",_close_overlay,true)
	box.add_child(back)
	back.grab_focus()

func _show_next_round() -> void:
	puzzle_choice = run.puzzle_difficulty
	combat_choice = run.combat_difficulty
	var box := _modal(610,450)
	box.add_child(label("THE GARDEN GROWS",31,MINT))
	box.add_child(label("Next up: round %02d / %02d" % [run.round_no+1,run.max_rounds],22))
	if run.mode == "campaign":
		_choice_row(box,"NEXT SUDOKU GRID",[["easy","Easy"],["medium","Medium"],["hard","Hard"]],run.puzzle_difficulty,func(v): puzzle_choice=v)
		_choice_row(box,"NEXT ENEMY SIEGE",[["easy","Easy"],["medium","Medium"],["hard","Hard"]],run.combat_difficulty,func(v): combat_choice=v)
	else: box.add_child(label("Locked in: your chosen difficulties carry forward.",17,MUTED))
	var note := label("Your gear, credits, and family levels carry over. Equipped modules return safely to your bag.",16,MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var go := button("Plant the next garden",func():
		var next_result: Dictionary = run.next_round({"puzzle_difficulty":puzzle_choice,"combat_difficulty":combat_choice})
		if not next_result.ok:
			_toast(next_result.message,false)
			return
		selected_cell = -1
		selected_number = 0
		world.setup(run)
		_close_overlay()
		_save()
	,true)
	box.add_child(go)
	box.add_child(button("Back to loot",_close_overlay))
	go.grab_focus()

func _show_result() -> void:
	var box := _modal(600,440)
	box.add_child(label("THE GARDEN ENDURES" if run.phase=="won" else "ROOTS REMAIN",31,MINT if run.phase=="won" else AMBER))
	box.add_child(label("Victory." if run.phase=="won" else "A new garden awaits.",23))
	box.add_child(label("ROUND %02d     /     SCORE %d\n\n%d towers grown  ·  %d credits collected\nSeed %d" % [run.round_no,run.score,run.towers.size(),run.credits,run.seed_value],18,MUTED))
	var go := button("Another expedition",func(): _show_menu(true),true)
	box.add_child(go)
	box.add_child(button("Inspect the board",_close_overlay))
	go.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			return
		if event.keycode == KEY_ESCAPE:
			if menu_open: _close_overlay()
			elif dock.is_open(): dock.close_panel()
			else: _show_menu(false)
			return
		if menu_open: return
		if event.keycode == KEY_TAB: _toggle_dock("bag"); return
		if event.keycode == KEY_P: _toggle_pause(); return
		if event.keycode == KEY_M: muted=not muted; sound.set_muted(muted); return
		if dock.is_open(): return
		controller_used = false
		if event.keycode >= KEY_1 and event.keycode <= KEY_9: _choose_number(event.keycode-KEY_0)
		elif event.keycode == KEY_ENTER: _advance()
		elif event.keycode == KEY_H: _action(run.hint(selected_cell))
		elif event.keycode == KEY_LEFT: _move_selection(Vector2i.LEFT)
		elif event.keycode == KEY_RIGHT: _move_selection(Vector2i.RIGHT)
		elif event.keycode == KEY_UP: _move_selection(Vector2i.UP)
		elif event.keycode == KEY_DOWN: _move_selection(Vector2i.DOWN)

func _input(event: InputEvent) -> void:
	if controller_used and ((event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION) or event is InputEventScreenTouch):
		controller_used = false
		if controller != null: controller.reset_navigation()
		dock.set_controller_mode.call_deferred(false)
		_refresh()

func _controller_activity() -> void:
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
	var scope: Control = _controller_scope()
	if scope == null:
		if has_active_run and not manual_pause: _move_selection(direction)
		return
	var buttons: Array[Control] = _controller_buttons(scope)
	if buttons.is_empty(): return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if not buttons.has(focused):
		buttons[0].grab_focus()
		return
	var side: int = SIDE_LEFT if direction.x < 0 else (SIDE_RIGHT if direction.x > 0 else (SIDE_TOP if direction.y < 0 else SIDE_BOTTOM))
	var neighbor: Control = focused.find_valid_focus_neighbor(side)
	if not buttons.has(neighbor) or neighbor == focused:
		var increment: int = 1 if direction.x > 0 or direction.y > 0 else -1
		neighbor = buttons[posmod(buttons.find(focused)+increment,buttons.size())]
	neighbor.grab_focus()

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
		elif dock.is_open(): dock.close_panel()
		else:
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
		elif action in ["previous","next"]: dock.cycle_panel(-1 if action == "previous" else 1)
		return
	if manual_pause: return
	match action:
		"previous", "next":
			if selected_number <= 0: selected_number = 9 if action == "previous" else 1
			else: selected_number = posmod(selected_number-1+(-1 if action == "previous" else 1),9)+1
			world.set_selected(selected_cell,selected_number)
			_refresh()
		"confirm":
			if selected_cell < 0: _select(40,false,false)
			else: _select(selected_cell,true)
		"advance": _advance()

func _controller_disconnected() -> void:
	if has_active_run:
		if not menu_open: _show_menu(false)
		_toast("Controller disconnected. Game paused; reconnect or use touch / mouse.",false)

func _show_seed_pad() -> void:
	if is_instance_valid(seed_input): _seed_text = seed_input.text
	_seed_editing = true
	var box := _modal(490,570)
	box.add_child(label("CHOOSE A RUN SEED",25,MINT))
	box.add_child(label("D-pad / stick move · A select · B back",15,MUTED))
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
