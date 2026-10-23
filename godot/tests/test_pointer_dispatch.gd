extends SceneTree
## Exercise Input's actual touch-to-mouse conversion, not just Viewport.push_input.
## A Deck screen can deliver mouse-only input; other screens send raw touches.
var scene
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 3) -> void:
	for i in range(count): await process_frame

func dispatch(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func screen_event(point: Vector2, pressed: bool, index := 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	event.index = index
	dispatch(event)

func screen_drag(from: Vector2, to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.position = to
	event.relative = to-from
	event.index = 0
	dispatch(event)

func mouse_event(point: Vector2, pressed: bool, device := 0) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.device = device
	event.pressed = pressed
	dispatch(event)

func tap(point: Vector2) -> void:
	screen_event(point,true)
	await frames(1)
	screen_event(point,false)
	await frames()

func click(point: Vector2, device := 0) -> void:
	mouse_event(point,true,device)
	await frames(1)
	mouse_event(point,false,device)
	await frames()

func controller(button := JOY_BUTTON_RIGHT_SHOULDER) -> void:
	for pressed in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device = 42
		event.button_index = button
		event.pressed = pressed
		dispatch(event)
		await frames()


func paired_tap(at: Vector2, mouse_first: bool) -> void:
	# Bypass Input conversion for this explicit stream so we can exercise both
	# platform orderings without adding a second synthetic mouse pair.
	for pressed in [true,false]:
		var finger := InputEventScreenTouch.new()
		finger.position = at
		finger.index = 0
		finger.pressed = pressed
		var pointer := InputEventMouseButton.new()
		pointer.position = at
		pointer.global_position = at
		pointer.button_index = MOUSE_BUTTON_LEFT
		pointer.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		pointer.pressed = pressed
		pointer.device = InputEvent.DEVICE_ID_EMULATION
		for event in ([pointer,finger] if mouse_first else [finger,pointer]):
			root.push_input(event,true)
		await frames(1)
	await frames()

func show_control(control: Control) -> void:
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await frames()

func dock_button(id: String) -> Button:
	for control in scene.dock._shell.find_children("*","Button",true,false):
		if control.get_meta("focus_id","") == id: return control
	return null

func point(control: Control) -> Vector2:
	return control.get_global_rect().get_center()

func blank() -> int:
	for cell in range(81):
		if scene.run.board[cell] == 0: return cell
	return -1

func button_text(prefix: String) -> Button:
	for control in scene.overlay.find_children("*","Button",true,false):
		if control.text.begins_with(prefix): return control
	return null

func exercise() -> void:
	root.size = Vector2i(1280,800)
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await frames(6)
	scene.muted = true
	scene.sound.set_muted(true)
	scene.seed_input.text = "12345"
	check(Input.is_emulating_mouse_from_touch(),"Native touch must generate mouse input for ordinary GUI controls")
	var start: Button = button_text("Start expedition")
	check(start != null,"Start button is discoverable in the actual menu")
	await show_control(start)
	await tap(point(start))
	check(scene.has_active_run and not scene.menu_open,"Raw Input touch can activate Start expedition through real mouse emulation")
	if scene.menu_open: scene._start_run()
	await frames()
	scene.set_process(false)
	var cell := blank()
	var answer: int = scene.run.solution[cell]
	var before: int = scene.run.towers.size()
	await controller()
	await tap(scene.world.cell_screen_position(cell))
	check(scene.selected_cell == cell and scene.run.board[cell] == 0,"Parsed native touch selects the intended square after controller input")
	check(not scene.controller_used,"Parsed native touch switches to pointer hints")
	await tap(point(scene.number_buttons[answer-1]))
	check(scene.run.board[cell] == answer and scene.run.towers.size() == before+1,"Real touch plus its generated mouse clicks plant exactly once")
	check(not scene.dock.is_open(),"Generated mouse cannot open the freshly planted tower")
	await tap(scene.world.cell_screen_position(cell))
	check(scene.dock.is_open() and scene.dock.current_panel == "tower","A subsequent real touch opens the planted tower")
	scene.dock.close_panel()
	await frames()
	for entry in [[scene.bag_button,"bag"],[scene.loot_button,"loot"],[scene.hud_nodes.camp,"camp"]]:
		await controller()
		await tap(point(entry[0]))
		check(scene.dock.is_open() and scene.dock.current_panel == entry[1],"Parsed native touch opens %s after controller input" % entry[1])
		scene.dock.close_panel()
		await frames()

	# Finger movement follows the same real event conversion as a physical screen.
	cell = blank()
	answer = scene.run.solution[cell]
	before = scene.run.towers.size()
	var from: Vector2 = point(scene.number_buttons[answer-1])
	var target: Vector2 = scene.world.cell_screen_position(cell)
	screen_event(from,true)
	await frames(1)
	screen_drag(from,target)
	await frames(1)
	screen_event(target,false)
	await frames()
	check(scene.run.board[cell] == answer and scene.run.towers.size() == before+1,"Parsed native seed drag commits exactly once")
	check(not scene.seed_pointer.is_active(),"Parsed native drag releases pointer ownership")

	# Mouse-only emulation must work even without a ScreenTouch paired with it.
	# This intentionally has no mouse-motion event before either click.
	cell = blank()
	answer = scene.run.solution[cell]
	before = scene.run.towers.size()
	await controller()
	await click(scene.world.cell_screen_position(cell),InputEvent.DEVICE_ID_EMULATION)
	check(scene.selected_cell == cell and scene.run.board[cell] == 0,"Standalone emulated mouse selects square at the click position")
	await click(point(scene.number_buttons[answer-1]),InputEvent.DEVICE_ID_EMULATION)
	check(scene.run.board[cell] == answer and scene.run.towers.size() == before+1,"Standalone emulated mouse number click plants exactly once")
	check(not scene.controller_used,"Standalone emulated mouse switches from controller hints")
	await click(point(scene.bag_button),InputEvent.DEVICE_ID_EMULATION)
	check(scene.dock.is_open() and scene.dock.current_panel == "bag","Standalone emulated mouse opens Gear")
	scene.dock.close_panel()
	await frames()

	for mouse_first in [true,false]:
		cell = blank()
		answer = scene.run.solution[cell]
		before = scene.run.towers.size()
		await paired_tap(scene.world.cell_screen_position(cell),mouse_first)
		check(scene.selected_cell == cell and scene.run.board[cell] == 0,"Paired events select without planting (mouse first: %s)" % mouse_first)
		await paired_tap(point(scene.number_buttons[answer-1]),mouse_first)
		check(scene.run.board[cell] == answer and scene.run.towers.size() == before+1,"Paired events plant exactly once (mouse first: %s)" % mouse_first)
		check(not scene.seed_pointer.is_active() and not scene.dock.is_open(),"Paired release clears ownership without inspecting tower (mouse first: %s)" % mouse_first)

	# Test a money-spending GUI button on the very first pointer gesture after
	# using the controller. Dock hint rebuilds must not destroy a pressed button.
	scene.run.credits = 1000
	scene._refresh()
	for native_touch in [true,false]:
		await click(scene.world.cell_screen_position(cell))
		await controller(JOY_BUTTON_DPAD_UP)
		check(scene.dock.current_panel == "tower" and scene.dock.is_open(),"Upgrade fixture keeps its tower workshop open")
		var upgrade: Button = dock_button("upgrade:tower")
		await show_control(upgrade)
		var level: int = scene.run.towers[cell].level
		var credits: int = scene.run.credits
		var cost: int = scene.run.upgrade_cost(cell)
		if native_touch: await tap(point(upgrade))
		else: await click(point(upgrade),InputEvent.DEVICE_ID_EMULATION)
		check(scene.run.towers[cell].level == level+1,"First pointer click upgrades exactly one level (native touch: %s)" % native_touch)
		check(scene.run.credits == credits-cost,"First pointer click charges exactly once (native touch: %s)" % native_touch)
		scene.dock.close_panel()
		await frames()

	# Ordinary mouse-only Deck emulation still works after raw touch use.
	cell = blank()
	answer = scene.run.solution[cell]
	await click(scene.world.cell_screen_position(cell))
	await click(point(scene.number_buttons[answer-1]))
	check(scene.run.board[cell] == answer,"Ordinary mouse click without prior motion works after touch and emulated mouse")
	scene.queue_free()
	await frames()
	print("POINTER_DISPATCH_CHECKS: %d assertions, %d failures" % [checks,failures])
	print("POINTER_DISPATCH_PASS" if failures == 0 else "POINTER_DISPATCH_FAIL")
	quit(1 if failures else 0)
