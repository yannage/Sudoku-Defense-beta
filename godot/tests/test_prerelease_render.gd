extends SceneTree
## Actual GPU render capture without taking over the user's desktop.
## Launch from a QA copy with display/window/size/mode=1 and no_focus=true.
## The real game renders into an always-updating Deck-sized SubViewport.
var scene
var viewport: SubViewport
var checks := 0
var failures := 0
var variant := "native"
var output := "res://build/prerelease-render"

func _initialize() -> void:
	Engine.max_fps = 60
	root.mode = Window.MODE_MINIMIZED
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 8) -> void:
	for index in range(count):
		if is_instance_valid(scene): scene.world.tick(1.0/60.0)
		await process_frame
		RenderingServer.force_draw(false)

func button(scope: Node, id: String) -> Button:
	for control in scope.find_children("*","Button",true,false):
		if control.get_meta("focus_id","") == id: return control
	return null

func capture(name: String) -> void:
	# The simulation is paused for repeatable capture; reproduce the host's
	# ordinary HUD/layout refresh so snapshots do not retain a previous phase.
	scene._layout_ui()
	scene._refresh()
	scene.notice.hide()
	scene.notice_time = 0
	scene._update_context_visibility()
	await frames(12)
	var image: Image = viewport.get_texture().get_image()
	check(image != null and not image.is_empty(),name+": actual framebuffer pixels exist")
	if image == null or image.is_empty(): return
	check(image.get_size() == Vector2i(1280,800),name+": framebuffer is Deck resolution")
	var colors := {}
	var bright := 0
	for y in range(0,800,8):
		for x in range(0,1280,8):
			var color: Color = image.get_pixel(x,y)
			colors[color.to_rgba32()] = true
			if color.r+color.g+color.b > 1.2: bright += 1
	check(colors.size() > 100 and bright > 100,name+": GPU image has visible geometry/text, not a dummy black buffer")
	check(image.save_png(output.path_join(variant+"-"+name+".png")) == OK,name+": screenshot saved")
	print("CAPTURE %s %s colors=%d bright=%d" % [variant,name,colors.size(),bright])

func modal_bounds(name: String) -> void:
	for scroll in scene.overlay.find_children("*","ScrollContainer",true,false):
		var scrollbar: VScrollBar = scroll.get_v_scroll_bar()
		var content_right: float = scrollbar.get_global_rect().position.x if scrollbar.visible else scroll.get_global_rect().end.x
		for control in scroll.find_children("*","Control",true,false):
			if not control.is_visible_in_tree(): continue
			if control == scrollbar or control is MarginContainer: continue
			var bounds: Rect2 = control.get_global_rect()
			var area: Rect2 = scroll.get_global_rect()
			check(bounds.position.x >= area.position.x-2 and bounds.end.x <= content_right+1,name+": control clears the visible scrollbar: "+str(control.get_class())+" "+str(bounds))
	var focused: Control = viewport.gui_get_focus_owner()
	check(is_instance_valid(focused) and viewport.get_visible_rect().encloses(focused.get_global_rect()),name+": focused action is visible")

func exercise() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This suite requires an actual graphics renderer, not headless/dummy.")
		quit(1)
		return
	variant = "canvas" if "--canvas-graphics" in OS.get_cmdline_user_args() else "native"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	print("RENDER_DEVICE display=%s adapter=%s api=%s version=%s" % [DisplayServer.get_name(),RenderingServer.get_video_adapter_name(),RenderingServer.get_video_adapter_api_version(),ProjectSettings.get_setting("application/config/version")])
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	scene = load("res://scenes/main.tscn").instantiate()
	var instance_id := str(Time.get_ticks_usec())
	scene.preferences.file_path = "user://prerelease-render-settings-"+instance_id+".json"
	scene.run_save.file_path = "user://prerelease-render-run-"+instance_id+".json"
	viewport.add_child(scene)
	await frames(15)
	scene.sound.set_muted(true)
	scene.set_process(false)
	scene._layout_ui()
	await capture("menu")
	modal_bounds("menu")
	scene.tutorial.start(scene)
	await capture("guide-first-answer")
	modal_bounds("guide")
	button(scene.overlay,"guide:continue").pressed.emit()
	await frames()
	check(not scene.menu_open,"Guide action exposes the actual board")
	scene.selected_number = scene.run.solution[scene.selected_cell]
	scene._refresh()
	await capture("placement-strategy")
	var first: int = scene.selected_cell
	scene.number_buttons[scene.selected_number-1].pressed.emit()
	check(scene.run.towers.has(first),"Number button plants the guided square")
	scene.tutorial.observe()
	await capture("guide-route")
	scene.tutorial.continue_step()
	for cell in range(81):
		if scene.run.towers.size() >= 6: break
		if scene.run.board[cell] == 0: scene._action(scene.run.place(cell,scene.run.solution[cell]))
	scene.tutorial.observe()
	await capture("guide-unfinished-puzzle")
	scene.tutorial.continue_step()
	scene._advance()
	scene.tutorial.observe()
	await capture("guide-gear")
	scene.tutorial.continue_step()
	scene.dock._act("equip_item",[first,scene.run.items[0].id])
	scene.tutorial.observe()
	await capture("guide-launch")
	scene.tutorial.continue_step()
	scene._select(first)
	await frames(75)
	check(scene.dock.is_open() and scene.dock.current_panel == "tower","Selecting a planted tower opens the family upgrade panel")
	await capture("tower-targeting")
	var family_upgrade: Button = button(scene.dock,"upgrade:family")
	check(is_instance_valid(family_upgrade),"Family upgrade action exists")
	family_upgrade.grab_focus()
	scene.dock._scroll.ensure_control_visible(family_upgrade)
	await frames()
	await capture("family-upgrade")
	scene.dock.close_panel()
	scene._show_wave_intel()
	await capture("wave-intel")
	modal_bounds("wave-intel")
	button(scene.overlay,"wave:close_bottom").grab_focus()
	await capture("wave-intel-scrolled")
	scene._close_overlay()
	scene._advance()
	scene.tutorial.observe()
	await capture("guide-battle")
	scene.tutorial.continue_step()
	var steps := 0
	while scene.run.phase == "battle" and steps < 10000:
		scene.run.update(0.05)
		steps += 1
	check(scene.run.phase == "loot","Rendered guide fixture clears real wave")
	scene.tutorial.observe()
	await capture("guide-reward")
	scene.tutorial.continue_step()
	var cheapest: Dictionary = scene.run.chests[0]
	for chest: Dictionary in scene.run.chests:
		if int(chest.cost) < int(cheapest.cost): cheapest = chest
	scene._action(scene.run.open_chest(cheapest.id))
	for event: Dictionary in scene.run.drain_events(): scene.tutorial.event_seen(event)
	scene.tutorial.observe()
	scene.dock.close_panel()
	scene.tutorial.show_step()
	await capture("guide-complete")
	scene.tutorial.finish()
	scene.run.new_run(9147,{"mode":"campaign","puzzle_difficulty":"medium","combat_difficulty":"hard"})
	scene.has_active_run = true
	var expected_board: Array = scene.run.board.duplicate()
	for phase in ["lost","won"]:
		scene.run.phase = phase
		scene.run.round_no = 12 if phase == "lost" else 50
		scene.run.combat_report.damage = 12345.0
		scene.run.combat_report.leaks = {"runner":3,"tank":2}
		scene.run.combat_report.towers = {"1:0":{"round":1,"cell":0,"number":7,"damage":100.0,"kills":9}}
		scene._show_result()
		await capture("results-"+phase)
		modal_bounds("results")
		button(scene.overlay,"result:bottom").grab_focus()
		await capture("results-"+phase+"-scrolled")
		button(scene.overlay,"result:retry").pressed.emit()
		check(scene.run.phase == "solve" and scene.run.board == expected_board,"Rendered retry restarts identical seed and settings")
		scene.world.setup(scene.run)
	await capture("retry-board")
	scene._show_audio_settings()
	await capture("audio")
	modal_bounds("audio")
	button(scene.overlay,"audio:music:lower").pressed.emit()
	button(scene.overlay,"audio:effects:lower").pressed.emit()
	check(is_equal_approx(scene.music_volume,0.95) and is_equal_approx(scene.effects_volume,0.95),"Rendered audio buttons apply channel levels")
	await capture("audio-adjusted")
	print("PRERELEASE_RENDER_%s: %d checks / %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	scene.queue_free()
	await frames(3)
	quit(0 if failures == 0 else 1)
