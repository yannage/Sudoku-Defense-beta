extends SceneTree
## HUD bounds/copy against actual responsive layout, with disposable profiles.
var scene
var checks := 0
var failures := 0
var rendered := false
var output := "res://build/hud-polish-checks"
var variant := "native"

func _initialize() -> void:
	Engine.max_fps = 120
	rendered = "--render-check" in OS.get_cmdline_user_args()
	variant = "canvas" if "--canvas-graphics" in OS.get_cmdline_user_args() else "native"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	if rendered and DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_MINIMIZED
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 6) -> void:
	for index in range(count):
		await process_frame
		if rendered: RenderingServer.force_draw(false)

func capture(stage: String) -> void:
	if not rendered: return
	await frames()
	var image := root.get_texture().get_image()
	check(image != null and not image.is_empty(),stage+": real framebuffer")
	if image == null or image.is_empty(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	check(image.save_png(output.path_join(variant+"-"+stage+".png")) == OK,stage+": capture saved")

func layout(window_size: Vector2i) -> void:
	root.size = window_size
	await frames(10)
	scene._layout_ui()
	scene.notice.hide()
	scene.notice_time = 0
	scene._update_context_visibility()
	await frames()
	var viewport: Rect2 = root.get_visible_rect()
	check(scene.board_rect.end.y <= scene.hud_nodes.bottom.get_global_rect().position.y,"%s: board stays above footer" % window_size)
	var footer: Array[Control] = []
	for button in scene.number_buttons: footer.append(button)
	footer.append(scene.hud_nodes.speed)
	footer.append(scene.next_button)
	for i in range(footer.size()):
		check(viewport.encloses(footer[i].get_global_rect()),"%s: footer action %s stays on screen" % [window_size,footer[i].text])
		for j in range(i+1,footer.size()):
			check(not footer[i].get_global_rect().intersects(footer[j].get_global_rect()),"%s: footer actions %s and %s do not overlap" % [window_size,footer[i].text,footer[j].text])
	if scene.controls_label.visible:
		check(viewport.encloses(scene.controls_label.get_global_rect()),"%s: footer hints stay on screen" % window_size)
		for button in footer:
			check(not scene.controls_label.get_global_rect().intersects(button.get_global_rect()),"%s: footer hints do not overlap %s" % [window_size,button.text])
	print("HUD_LAYOUT %s logical=%s speed=%s last_number=%s hints=%s" % [window_size,viewport.size,scene.hud_nodes.speed.get_global_rect(),scene.number_buttons[8].get_global_rect(),scene.controls_label.get_global_rect()])
	await capture("layout-%dx%d" % [window_size.x,window_size.y])

func count_copy() -> void:
	root.size = Vector2i(1280,800)
	await frames()
	for cell in range(81):
		if scene.run.board[cell] == 0:
			check(scene.run.place(cell,scene.run.solution[cell]).ok,"Place one legitimate tower for HUD count")
			break
	scene._refresh()
	check(scene.phase_detail.text.contains("1 tower grown"),"Solve HUD uses singular tower")
	check(scene.run.advance_phase().ok and scene.run.advance_phase().ok,"Enter battle for live count display")
	scene.last_phase = "battle"
	scene.run.enemies.clear()
	scene.run.spawned = scene.run.spawn_total-1
	scene.run._spawn()
	scene._refresh()
	check(scene.phase_detail.text.contains("1 tower active"),"Battle HUD uses singular active tower")
	check(scene.phase_detail.text.contains("enemy left"),"Battle HUD uses singular remaining enemy")
	scene.run.battle_time = 60.0
	scene._refresh()
	check(scene.phase_detail.text.contains("1 enemy on route"),"Cleanup HUD uses singular enemy")
	root.size = Vector2i(720,1280)
	await frames()
	scene._refresh()
	check(scene.phase_detail.text.contains("1 enemy left"),"Portrait HUD uses singular enemy")
	scene.run.spawned -= 1
	scene.run._spawn()
	scene._refresh()
	check(scene.phase_detail.text.contains("2 enemies left"),"Portrait HUD retains plural enemies")
	root.size = Vector2i(1280,800)
	await frames()
	scene._refresh()
	check(scene.phase_detail.text.contains("2 enemies on route"),"Cleanup HUD retains plural enemies")

func exercise() -> void:
	if not "--no-steam" in OS.get_cmdline_user_args() or (rendered and DisplayServer.get_name() == "headless"):
		push_error("HUD polish suite requires --no-steam, and real rendering for --render-check")
		quit(1)
		return
	root.size = Vector2i(1280,800)
	scene = load("res://scenes/main.tscn").instantiate()
	var profile := "user://hud-polish-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(profile)
	scene.preferences.file_path = profile.path_join("settings.json")
	scene.run_save.file_path = profile.path_join("run.json")
	root.add_child(scene)
	await frames()
	scene.sound.set_muted(true)
	scene.set_process(false)
	scene.seed_input.text = "784217"
	scene._start_run()
	await frames()
	for window_size in [Vector2i(1280,800),Vector2i(720,1280),Vector2i(844,390),Vector2i(960,540),Vector2i(1024,768),Vector2i(800,600)]:
		await layout(window_size)
	await count_copy()
	print("HUD_POLISH_%s %d checks / %d failures (%s%s)" % ["PASS" if failures == 0 else "FAIL",checks,failures,variant,", rendered" if rendered else ", headless"])
	scene.queue_free()
	await frames(2)
	quit(1 if failures else 0)
