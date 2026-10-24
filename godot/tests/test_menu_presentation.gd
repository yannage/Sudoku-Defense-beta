extends SceneTree
## Real-scene menu geometry and pointer activation checks. Optional captures
## require an actual GLES display: -- --capture-menu-presentation.
var scene
var checks := 0
var failures := 0
var layout_name := "deck"

func _initialize() -> void:
	Engine.max_fps = 120
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(layout_name + ": " + message)

func frames(count := 4) -> void:
	for i in range(count): await process_frame

func button_by_text(scope: Node, prefix: String) -> Button:
	for node in scope.find_children("*","Button",true,false):
		if node.is_visible_in_tree() and str(node.text).begins_with(prefix): return node
	return null

func exposed(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree(): return false
	var bounds: Rect2 = control.get_global_rect()
	if not root.get_visible_rect().grow(2).encloses(bounds): return false
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer and not ancestor.get_global_rect().grow(2).encloses(bounds): return false
		ancestor = ancestor.get_parent()
	return true

func click(control: Control) -> void:
	check(exposed(control),"Primary action is exposed before a direct pointer click")
	if not is_instance_valid(control): return
	var point: Vector2 = root.get_final_transform()*control.get_global_rect().get_center()
	if DisplayServer.get_name() != "headless": Input.warp_mouse(point)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(2)

func check_content(scope: Control, description: String) -> void:
	check(root.get_visible_rect().grow(2).encloses(scope.get_global_rect()),description+" surface fits the viewport")
	for scroll in scope.find_children("*","ScrollContainer",true,false):
		if not scroll.is_visible_in_tree(): continue
		var rect: Rect2 = scroll.get_global_rect()
		for child in scroll.find_children("*","Control",true,false):
			if not child.is_visible_in_tree(): continue
			# Vertical scrolling is intentional; horizontal clipping is not.
			var child_rect: Rect2 = child.get_global_rect()
			check(child_rect.position.x >= rect.position.x-2 and child_rect.end.x <= rect.end.x+2,
				description+" content fits horizontally: "+str(child.get_class())+" "+str(child_rect))
	for node in scope.find_children("*","Label",true,false):
		if not node.is_visible_in_tree() or node.text.length() < 9: continue
		check(node.size.x >= float(node.get_theme_font_size("font_size"))*2.5,
			description+" label is not squeezed to one letter per line: "+node.text)

func check_modal(description: String) -> void:
	check(is_instance_valid(scene.overlay),description+" overlay exists")
	if not is_instance_valid(scene.overlay): return
	for panel in scene.overlay.get_children():
		if panel is PanelContainer: check_content(panel,description)

func capture(stage: String) -> void:
	if "--capture-menu-presentation" not in OS.get_cmdline_user_args(): return
	check(DisplayServer.get_name() != "headless","Menu captures require a real renderer")
	if DisplayServer.get_name() == "headless": return
	scene.notice.hide()
	await frames(8)
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	check(not screenshot.is_empty(),"Rendered pixels exist for "+stage)
	var directory := "res://build/menu-checks"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var renderer := "canvas" if "--canvas-graphics" in OS.get_cmdline_user_args() else "native"
	check(screenshot.save_png("%s/%s-%s-%s.png" % [directory,renderer,layout_name,stage]) == OK,"Save "+stage+" framebuffer")

func exercise() -> void:
	var layouts: Array[Vector2i] = [Vector2i(1280,800),Vector2i(1920,1080),Vector2i(600,1066)]
	if "--portrait-only" in OS.get_cmdline_user_args(): layouts = [Vector2i(600,1066)]
	for window_size in layouts:
		layout_name = "portrait" if window_size.y > window_size.x else ("deck" if window_size.x == 1280 else "docked")
		root.size = window_size
		root.position = Vector2i.ZERO
		scene = load("res://scenes/main.tscn").instantiate()
		root.add_child(scene)
		await frames(10)
		scene.muted = true
		scene.sound.set_muted(true)
		check_modal("Expedition setup")
		for prefix in ["Campaign","Free play","Locked in","Start expedition"]:
			check(exposed(button_by_text(scene.overlay,prefix)),"Setup exposes "+prefix+" without scrolling")
		var keypad: Button = button_by_text(scene.overlay,"Keypad")
		check(is_instance_valid(keypad),"Setup exposes the replay seed keypad")
		if is_instance_valid(keypad):
			var font: Font = keypad.get_theme_font("font")
			var surface: StyleBox = keypad.get_theme_stylebox("normal")
			var text_width: float = font.get_string_size(keypad.text,HORIZONTAL_ALIGNMENT_LEFT,-1,keypad.get_theme_font_size("font_size")).x
			var padding: float = surface.get_content_margin(SIDE_LEFT)+surface.get_content_margin(SIDE_RIGHT)
			check(keypad.size.x+2 >= text_width+padding,"Keypad label is readable without clipping at this layout's font size")
		check(is_instance_valid(scene.seed_input),"Setup retains a usable seed input")
		if is_instance_valid(scene.seed_input):
			if scene.seed_input.is_visible_in_tree(): check(scene.seed_input.size.x >= 140,"Seed field has enough room to read a replay seed")
			scene.seed_input.text = "784217"
		await capture("setup")
		await click(button_by_text(scene.overlay,"Start expedition"))
		check(scene.has_active_run and not scene.menu_open,"Visible Start action launches the run through GUI input")
		if not scene.has_active_run:
			scene.queue_free()
			await frames(5)
			continue
		var cells: Array[int] = []
		for cell in range(81):
			if scene.run.board[cell] == 0 and cells.size() < 3:
				scene.run.place(cell,scene.run.solution[cell])
				cells.append(cell)
		scene.run.phase = "prep"
		scene.last_phase = "prep"
		scene.run.credits = 500
		scene.run.fragments = 100
		scene._refresh()
		await frames(12)
		scene._show_menu(false)
		await frames(10)
		check_modal("Pause menu")
		var resume: Button = button_by_text(scene.overlay,"Resume run")
		check(exposed(resume),"Resume stays immediately reachable")
		check(root.gui_get_focus_owner() == resume,"Pause defaults focus to safe Resume action")
		await capture("pause")
		await click(resume)
		check(not scene.menu_open,"Resume is activated by its visible pointer target")
		scene._help()
		await frames(10)
		check_modal("Help menu")
		await capture("help")
		scene._close_overlay()
		await frames(4)
		for panel_kind in ["camp","tower","bag"]:
			scene.dock.open_panel(panel_kind,cells[0])
			await frames(10)
			check_content(scene.dock._shell,panel_kind.capitalize()+" panel")
			await capture(panel_kind)
			scene.dock.close_panel()
			await frames(4)
		scene.queue_free()
		await frames(6)
	print("MENU_PRESENTATION_CHECKS: %d assertions, %d failures" % [checks,failures])
	print("MENU_PRESENTATION_PASS" if failures == 0 else "MENU_PRESENTATION_FAIL")
	quit(1 if failures else 0)
