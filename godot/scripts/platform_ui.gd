extends RefCounted
## Device-local presentation; no Steam calls or save selection occurs on open.
var host

func _text(box: VBoxContainer, value: String, color: Color, size: int = 17) -> Label:
	var node: Label = host.label(value,size,color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(node)
	return node

func _back(box: VBoxContainer, id: String = "platform:back") -> Button:
	var button: Button = host.button("Back",host._platform_back,true)
	# ScrollContainer clips at its boundary; keep the whole focus ring inside
	# the Back control even when it is the first or last visible list action.
	var focus: StyleBoxFlat = button.get_theme_stylebox("focus").duplicate()
	focus.set_expand_margin_all(0)
	button.add_theme_stylebox_override("focus",focus)
	button.set_meta("focus_id",id)
	box.add_child(button)
	return button

func show_achievements() -> void:
	var box: VBoxContainer = host._modal(760,690)
	host.overlay.set_meta("platform_panel",true)
	host.overlay.set_meta("achievements_panel",true)
	var state: Dictionary = host.achievements.get_status()
	_text(box,"ACHIEVEMENTS",host.MINT,27)
	_text(box,"%d / 26 unlocked" % int(state.get("unlocked_count",0)),host.WHITE,21)
	var pending: int = int(state.get("pending_count",0))
	var platform: Dictionary = host.steam_platform.get_status()
	var status := "Progress is saved locally. Steam unlocks sync when Steam is available."
	if not host.cloud_profile_status.get("scoped",false):
		status = "Local achievements. Launch from Steam to use your Steam account."
	elif pending > 0:
		status = "%d %s waiting for Steam confirmation. You can keep playing offline." % [pending,"unlock" if pending == 1 else "unlocks"]
	elif platform.get("ready",false):
		status = "Saved unlocks are confirmed by Steam."
	_text(box,status,host.MUTED,16)
	if state.get("save_failed",false):
		_text(box,str(state.get("message","Achievement progress could not be saved.")),host.AMBER)
		if state.get("recoverable",false):
			_text(box,"Recovery combines the saved unlocks for this account and archives every original file on this device.",host.MUTED,15)
			box.add_child(host.button("Recover saved unlocks",func():
				if host.achievements.recover_conflict():
					host._configure_profiles(host.steam_platform.get_status())
					host.achievement_save_failed = bool(host.achievements.get_status().get("save_failed",false))
				show_achievements()
			))
		else:
			box.add_child(host.button("Retry saving achievements",func():
				host.achievements.retry_save()
				host.achievement_save_failed = bool(host.achievements.get_status().get("save_failed",false))
				show_achievements()
			))
	_text(box,"Practice does not unlock achievements. Notes, accessibility settings and battle speed are always allowed.",host.MUTED,15)
	_text(box,"D-pad / left stick: scroll | Up at the top: save action | A: select | B: back" if state.get("save_failed",false) else "D-pad / left stick: scroll | A / B: back",host.MINT,14)
	var back := _back(box)
	for item: Dictionary in host.achievements.entries():
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel",host.style(host.PANEL,Color("36515c")))
		box.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",14)
		card.add_child(row)
		var icon := TextureRect.new()
		var unlocked: bool = bool(item.get("unlocked",false))
		var path := "res://assets/achievements/%s%s.svg" % [str(item.get("icon","")),"" if unlocked else "_locked"]
		if ResourceLoader.exists(path): icon.texture = load(path)
		icon.custom_minimum_size = Vector2(64,64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var detail := VBoxContainer.new()
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(detail)
		_text(detail,str(item.name),host.MINT if unlocked else host.WHITE,19)
		_text(detail,str(item.description),host.MUTED,16)
		_text(detail,"Unlocked · awaiting Steam" if unlocked and item.get("pending",false) else ("Unlocked" if unlocked else "Locked"),host.AMBER if unlocked else host.MUTED,13)
		card.set_meta("achievement_id",str(item.id))
	_back(box,"platform:back_bottom")
	back.grab_focus()

func navigate_achievements(direction: int) -> void:
	# Cards are informational. Scroll through them without skipping straight
	# between the Back buttons, while leaving save recovery above the list usable.
	var scroll: ScrollContainer = host.overlay.find_children("*","ScrollContainer",true,false)[0]
	var buttons: Array[Control] = host._controller_buttons(host.overlay)
	var top: Control
	var bottom: Control
	for control in buttons:
		match str(control.get_meta("focus_id","")):
			"platform:back": top = control
			"platform:back_bottom": bottom = control
	var focused: Control = host.get_viewport().gui_get_focus_owner()
	var index := buttons.find(focused)
	var top_index := buttons.find(top)
	if scroll.scroll_vertical == 0 and index >= 0 and index <= top_index:
		if direction < 0:
			buttons[maxi(0,index-1)].grab_focus()
			return
		if direction > 0 and index < top_index:
			buttons[index+1].grab_focus()
			return
	if focused != top and focused != bottom:
		# Pointer scrolling can leave a save action focused above the viewport.
		# Once the controller browses the cards, A must safely lead back.
		scroll.follow_focus = false
		top.grab_focus()
		scroll.follow_focus = true
	var limit: int = maxi(0,int(scroll.get_v_scroll_bar().max_value-scroll.size.y))
	scroll.scroll_vertical = clampi(scroll.scroll_vertical+direction*maxi(80,int(scroll.size.y*0.3)),0,limit)
	if scroll.scroll_vertical == 0:
		top.grab_focus()
	elif scroll.scroll_vertical >= limit:
		bottom.grab_focus()

func show_saves() -> void:
	var box: VBoxContainer = host._modal(720,660)
	host.overlay.set_meta("platform_panel",true)
	host.overlay.set_meta("saves_panel",true)
	_text(box,"SAVES & STEAM",host.MINT,27)
	var profile: Dictionary = host.cloud_profile_status
	var steam: Dictionary = host.steam_platform.get_status()
	if not profile.get("ok",false):
		var error: Variant = profile.get("error",{})
		_text(box,str(error.get("message","The save profile could not be opened.")) if error is Dictionary else str(error),host.AMBER)
	elif profile.get("scoped",false):
		_text(box,"Your run and achievements belong to the current Steam account.",host.WHITE)
		if steam.get("cloud_enabled",false):
			_text(box,"Steam Cloud is enabled. Quit normally and wait for Steam to report Up to date before playing on another device.",host.MINT)
		else:
			_text(box,"Cloud is unavailable or disabled. Progress is still saved on this device. Check the game's Steam Cloud setting when connected.",host.AMBER)
		_text(box,"Cloud sync happens before launch and after exit. Suspend does not promise an immediate sync. If Steam reports a conflict, compare the saves before choosing.",host.MUTED,16)
	else:
		_text(box,"Local saves on this device. Launch the game from Steam to use account-specific Cloud saves and Steam achievements.",host.WHITE)
	_text(box,"Audio, display preferences, practice, temporary files and recovery archives stay on this device. Your previous local save is preserved when first moving to a Steam profile.",host.MUTED,16)
	if profile.has("run_path"):
		host.run_save.check_current()
		if not host.run_save.last_error.is_empty():
			_text(box,str(host.run_save.last_error.get("message","The save needs attention.")),host.AMBER)
			_text(box,"The files have been kept. No saved run will be replaced until this is resolved.",host.MUTED,16)
			_show_conflict_choices(box)
		elif host.save_failed:
			box.add_child(host.button("Retry saving run",func(): host._save(); show_saves()))
	var back := _back(box)
	back.grab_focus()

func _show_conflict_choices(box: VBoxContainer) -> void:
	# Filled from validated journal candidates only; future-schema saves stay
	# protected. Opening this panel never resolves or overwrites a conflict.
	if not host.run_save.has_method("conflict_candidates"): return
	for candidate: Dictionary in host.run_save.conflict_candidates():
		var state: Dictionary = candidate.get("data",{}).get("state",{})
		var name := "%s · round %d · %s · seed %s" % [str(candidate.get("label","Saved run")),int(state.get("round_no",0)),str(state.get("phase","")),str(state.get("seed_value",""))]
		box.add_child(host.button(name,func(): _confirm_save(candidate)))

func _confirm_save(candidate: Dictionary) -> void:
	var box: VBoxContainer = host._modal(700,460)
	host.overlay.set_meta("platform_panel",true)
	host.overlay.set_meta("save_confirmation",true)
	_text(box,"USE THIS SAVED RUN?",host.AMBER,25)
	var state: Dictionary = candidate.get("data",{}).get("state",{})
	_text(box,"Round %d · %s\nSeed %s" % [int(state.get("round_no",0)),str(state.get("phase","")),str(state.get("seed_value",""))],host.WHITE,21)
	_text(box,"Both versions will first be archived on this device. This choice becomes the active save for the next Steam sync.",host.MUTED)
	var cancel: Button = host.button("Keep both / go back",show_saves,true)
	box.add_child(cancel)
	box.add_child(host.button("Use this run",func():
		# Reconfiguring after recovery reloads achievement evidence from disk.
		# Never discard an earned unlock that still exists only in memory.
		host._observe_achievements()
		var achievements_saved: bool = host.achievements.retry_save()
		host.achievement_save_failed = bool(host.achievements.get_status().get("save_failed",false))
		if not achievements_saved:
			show_achievements()
			return
		if host.run_save.resolve_candidate(str(candidate.get("hash",""))):
			# End practice before loading the chosen run, so its old snapshot
			# cannot later replace this explicit recovery when the guide exits.
			if host.tutorial.active: host.tutorial.restore()
			host._configure_profiles(host.steam_platform.get_status())
			if host._load():
				host.world.setup(host.run)
				host.last_phase = host.run.phase
				host.save_failed = false
		show_saves()
	))
	cancel.grab_focus()
