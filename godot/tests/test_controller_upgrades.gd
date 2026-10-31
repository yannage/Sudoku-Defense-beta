extends SceneTree
## Controller socket -> module -> next tower, using native joypad events.
## Fixtures seed models only; interactions never emit action callbacks.
## --render-check requires real GPU pixels; --capture-dir changes PNG output.
## Render on an isolated display, or a QA copy starting minimized/no_focus.
const Loot = preload("res://scripts/loot.gd")
const DEVICE := 42
var scene
var checks := 0
var failures := 0
var rendered := false
var variant := "native"
var output := "res://build/controller-upgrade-checks"
var group := ""
var profile := "user://controller-upgrades-%d" % Time.get_ticks_usec()

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
		push_error(group+": "+message)

func frames(count := 4) -> void:
	for index in range(count):
		if is_instance_valid(scene): scene.world.tick(1.0/60.0)
		await process_frame
		if rendered: RenderingServer.force_draw(false)

func press(index: int) -> void:
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device = DEVICE
		event.button_index = index
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(1 if down else 4)

func focused_id() -> String:
	var control: Control = root.gui_get_focus_owner()
	return str(control.get_meta("focus_id","")) if is_instance_valid(control) else ""

func by_id(id: String) -> Button:
	for control in scene.dock.find_children("*","Button",true,false):
		if control.is_visible_in_tree() and str(control.get_meta("focus_id","")) == id: return control
	return null

func focused_visible(description: String) -> void:
	var control: Control = root.gui_get_focus_owner()
	check(is_instance_valid(control),description+": focus exists")
	if not is_instance_valid(control): return
	check(control.is_visible_in_tree() and not control.disabled,description+": focused action is usable")
	var bounds := control.get_global_rect()
	check(root.get_visible_rect().grow(1).encloses(bounds),description+": focus fits Deck viewport")
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			check(ancestor.get_global_rect().grow(1).encloses(bounds),description+": scrolling exposes the whole focused action")
		ancestor = ancestor.get_parent()

func inventory_ids() -> Array[String]:
	var result: Array[String] = []
	for item in scene.run.items: result.append(str(item.id))
	result.sort()
	return result

func all_module_ids() -> Array[String]:
	var result: Array[String] = inventory_ids()
	for tower in scene.run.towers.values():
		for item in tower.attachments: result.append(str(item.id))
	result.sort()
	return result

func add_item(kind := "rapid") -> Dictionary:
	var item: Dictionary = Loot.make_item(scene.run.rng,"common",1,scene.run._id(),kind)
	scene.run.items.append(item)
	return item

func fill(cell: int, count: int) -> void:
	for index in range(count):
		var item: Dictionary = Loot.make_item(scene.run.rng,"common",1,scene.run._id(),"power")
		scene.run.towers[cell].attachments.append(item)

func fixture(cells: Array[int], items := 6) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await frames(3)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.preferences.file_path = profile+"-settings.json"
	scene.run_save.file_path = profile+"-run.json"
	root.add_child(scene)
	await frames(5)
	scene.sound.set_muted(true)
	scene.set_process(false)
	scene.run.new_run(784217)
	# Keep a uniquely solvable clue set so the normal save validator accepts
	# this deterministic geometry fixture; an empty clue board is not valid.
	scene.run.board.assign(scene.run.solution)
	scene.run.givens.fill(true)
	scene.run.towers.clear()
	for cell in cells:
		scene.run.board[cell] = 0
		scene.run.givens[cell] = false
	for cell in cells: check(scene.run.place(cell,scene.run.solution[cell]).ok,"Fixture plants square "+str(cell))
	scene.run.items.clear()
	for index in range(items): add_item("rapid" if index%2 == 0 else "range")
	scene.run.phase = "prep"
	scene.last_phase = "prep"
	scene.run.credits = 500
	scene.has_active_run = true
	scene._close_overlay()
	scene.dock.reset_for_run()
	scene.world.setup(scene.run)
	scene._select(cells[0],false,false)
	scene._refresh()
	await frames(8)

func enter_socket(slot: int) -> bool:
	await press(JOY_BUTTON_A)
	var open: bool = scene.dock.is_open() and scene.dock.controller_context_active()
	check(open,"A on a board tower opens its controller workshop")
	check(focused_id() == "slot:"+str(slot),"Workshop starts at the first empty socket")
	if open: focused_visible("socket")
	return open

func enter_picker() -> String:
	await press(JOY_BUTTON_A)
	check(scene.dock.controller_picker_slot >= 0,"A on + opens the contextual module chooser")
	check(bool(scene.dock._shell.get_meta("controller_module_picker",false)),"Chooser exposes its contextual state")
	focused_visible("chooser")
	var id := focused_id()
	check(id.begins_with("item:"),"Chooser focuses an available module, never a purchase")
	return id.trim_prefix("item:") if id.begins_with("item:") else ""

func capture(stage: String) -> void:
	if not rendered: return
	scene._layout_ui()
	scene._refresh()
	scene.notice.hide()
	scene.notice_time = 0
	scene._update_context_visibility()
	await frames(10)
	var image: Image = root.get_texture().get_image()
	check(image != null and not image.is_empty(),stage+": actual framebuffer exists")
	if image == null or image.is_empty(): return
	check(image.get_size() == Vector2i(1280,800),stage+": exact Deck resolution")
	var colors := {}
	var bright := 0
	for y in range(0,800,8):
		for x in range(0,1280,8):
			var color := image.get_pixel(x,y)
			colors[color.to_rgba32()] = true
			if color.r+color.g+color.b > 1.2: bright += 1
	check(colors.size() > 100 and bright > 100,stage+": real visible geometry and text")
	if scene.dock.is_open():
		focused_visible(stage)
		for scroll in scene.dock.find_children("*","ScrollContainer",true,false):
			var area: Rect2 = scroll.get_global_rect()
			var bar: VScrollBar = scroll.get_v_scroll_bar()
			var right: float = bar.get_global_rect().position.x if bar.visible else area.end.x
			for control in scroll.find_children("*","Control",true,false):
				if not control.is_visible_in_tree() or control == bar or control is MarginContainer: continue
				var bounds: Rect2 = control.get_global_rect()
				check(bounds.position.x >= area.position.x-1 and bounds.end.x <= right+1,stage+": content clears horizontal bounds and scrollbar")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	check(image.save_png(output.path_join(variant+"-"+stage+".png")) == OK,stage+": capture saved")

func repeated_equipping() -> void:
	group = "repeat and nearest"
	await fixture([40,31,39,41,49])
	fill(40,4)
	fill(31,5)
	fill(39,4)
	scene.run.towers[39].level = 12
	scene.world.setup(scene.run)
	var all_before := all_module_ids()
	var credits: int = scene.run.credits
	var board: Array = scene.run.board.duplicate()
	if not await enter_socket(4): return
	await capture("socket")
	var chosen := await enter_picker()
	await press(JOY_BUTTON_DPAD_RIGHT)
	check(focused_id().begins_with("item:") and focused_id() != "item:"+chosen,"D-pad selects another module in the chooser")
	chosen = focused_id().trim_prefix("item:")
	focused_visible("chooser navigation")
	await capture("chooser")
	await press(JOY_BUTTON_A)
	check(scene.run.towers[40].attachments.size() == 5,"Confirm adds exactly one module")
	check(str(scene.run.towers[40].attachments.back().id) == chosen,"Confirm installs the highlighted module")
	check(not inventory_ids().has(chosen),"Only the confirmed module leaves inventory")
	check(not scene.dock.is_open() and scene.selected_cell == 39,"Nearest squared-grid tie selects row-major39, skips full31 and ignores tower height")
	await capture("after-equip")
	if not await enter_socket(4): return
	chosen = await enter_picker()
	await press(JOY_BUTTON_A)
	check(scene.run.towers[39].attachments.size() == 5 and str(scene.run.towers[39].attachments.back().id) == chosen,"Repeated A flow equips the next tower once")
	check(scene.selected_cell == 49 and not scene.dock.is_open(),"Next selection uses squared grid distance;49 is nearer than41 from39")
	check(scene.run.credits == credits and scene.run.board == board,"Module loop never purchases or changes Sudoku numbers")
	check(all_module_ids() == all_before,"Repeated equipment conserves every module ID")
	check(not scene.save_failed,"Ordinary equipment actions save successfully to the isolated store")

func cycle_and_cancel() -> void:
	group = "bumpers and back"
	await fixture([40,2,18,60,79])
	fill(18,5)
	var before := all_module_ids()
	for step in [[JOY_BUTTON_RIGHT_SHOULDER,60],[JOY_BUTTON_LEFT_SHOULDER,40],[JOY_BUTTON_LEFT_SHOULDER,2],[JOY_BUTTON_LEFT_SHOULDER,79],[JOY_BUTTON_RIGHT_SHOULDER,2]]:
		await press(step[0])
		check(scene.selected_cell == step[1] and not scene.dock.is_open(),"Board bumpers cycle eligible towers row-major with wrap, skipping full18")
	if not await enter_socket(0): return
	await enter_picker()
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(scene.selected_cell == 40 and scene.dock.controller_workshop_cell == 40 and scene.dock.controller_picker_slot == -1,"Chooser bumper changes tower and clears the old chooser")
	check(focused_id() == "slot:0","Bumper lands on destination first-empty socket")
	await enter_picker()
	await press(JOY_BUTTON_B)
	check(scene.dock.is_open() and scene.dock.controller_picker_slot == -1 and scene.selected_cell == 40 and focused_id() == "slot:0","B returns chooser to its origin socket")
	await press(JOY_BUTTON_B)
	check(not scene.dock.is_open() and scene.selected_cell == 40,"Second B returns workshop to the same board tower")
	check(all_module_ids() == before,"Browsing and cancellation never consume gear")
	await fixture([40],2)
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	await press(JOY_BUTTON_LEFT_SHOULDER)
	check(scene.selected_cell == 40,"One eligible tower wraps to itself")
	await enter_socket(0)
	await enter_picker()
	await press(JOY_BUTTON_A)
	check(scene.selected_cell == 40 and not scene.dock.is_open(),"No other eligible tower returns to the origin")

func sockets_and_removal() -> void:
	group = "socket selection and removal"
	await fixture([40],3)
	fill(40,2)
	var before := all_module_ids()
	if not await enter_socket(2): return
	for step in [[JOY_BUTTON_DPAD_RIGHT,"slot:3"],[JOY_BUTTON_DPAD_RIGHT,"slot:4"],[JOY_BUTTON_DPAD_LEFT,"slot:3"]]:
		await press(step[0])
		check(focused_id() == step[1],"D-pad reaches each distinct empty socket")
		focused_visible("socket navigation")
	await enter_picker()
	check(scene.dock.controller_picker_slot == 3,"Chooser remembers the selected empty socket")
	await press(JOY_BUTTON_B)
	check(focused_id() == "slot:3","B restores the exact selected empty socket")
	for index in range(3): await press(JOY_BUTTON_DPAD_LEFT)
	check(focused_id() == "slot:0","D-pad reaches an occupied socket")
	var old_id: String = str(scene.run.towers[40].attachments[0].id)
	var inventory_before: int = scene.run.items.size()
	await press(JOY_BUTTON_A)
	check(scene.run.towers[40].attachments.size() == 1 and scene.run.items.size() == inventory_before+1 and inventory_ids().has(old_id),"A on an occupied socket returns exactly that module")
	check(focused_id() == "slot:1","Removal focuses the new first empty socket after compaction")
	var chosen := await enter_picker()
	await press(JOY_BUTTON_A)
	check(scene.run.towers[40].attachments.size() == 2 and str(scene.run.towers[40].attachments.back().id) == chosen,"A on the emptied socket supports replacement without dragging")
	check(all_module_ids() == before,"Remove and replace preserve all module IDs")

func empty_and_full() -> void:
	group = "empty inventory and full capacity"
	for consumable_only in [false,true]:
		await fixture([40,41],0)
		if consumable_only: add_item("repair")
		var before := all_module_ids()
		var credits: int = scene.run.credits
		await enter_socket(0)
		await press(JOY_BUTTON_A)
		check(scene.dock.controller_picker_slot == 0 and focused_id() == "upgrade:back","No compatible inventory opens explanatory chooser with safe Back focus")
		for control in scene.dock.find_children("*","Button",true,false):
			check(not str(control.get_meta("focus_id","")).begins_with("item:"),"Chooser excludes consumables and unavailable modules")
		focused_visible("empty chooser")
		await press(JOY_BUTTON_A)
		check(scene.run.credits == credits and all_module_ids() == before and scene.run.towers[40].attachments.is_empty(),"A with no compatible gear never buys, consumes boosts or equips")
		await press(JOY_BUTTON_B)
		await press(JOY_BUTTON_RIGHT_SHOULDER)
		check(scene.selected_cell == 40,"No eligible upgrade targets leaves board selection stable")
	await fixture([40,41],1)
	await enter_socket(0)
	await enter_picker()
	await press(JOY_BUTTON_A)
	check(scene.run.items.is_empty() and scene.selected_cell == 40 and not scene.dock.is_open(),"Using final module returns to origin with no automatic next action")
	await fixture([40,41],2)
	fill(40,5)
	fill(41,5)
	var before := all_module_ids()
	var credits: int = scene.run.credits
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	await press(JOY_BUTTON_LEFT_SHOULDER)
	check(scene.selected_cell == 40,"All-full board has no eligible bumper destination")
	await press(JOY_BUTTON_A)
	check(scene.dock.is_open() and focused_id() == "close","Full tower starts on safe Close instead of an occupied socket or purchase")
	await capture("full-tower")
	for index in range(3): await press(JOY_BUTTON_A)
	check(all_module_ids() == before and scene.run.towers[40].attachments.size() == 5 and scene.run.credits == credits,"Repeated A on a full tower never removes, equips or purchases")
	await press(JOY_BUTTON_A)
	for index in range(12):
		if focused_id().begins_with("slot:"): break
		await press(JOY_BUTTON_DPAD_DOWN)
	check(focused_id().begins_with("slot:"),"Full tower occupied sockets remain reachable from safe initial focus")
	if focused_id().begins_with("slot:"):
		for index in range(4):
			if focused_id() == "slot:0": break
			await press(JOY_BUTTON_DPAD_LEFT)
		check(focused_id() == "slot:0","D-pad can select the first occupied full-tower socket")
		await press(JOY_BUTTON_A)
		check(scene.run.towers[40].attachments.size() == 4 and focused_id() == "slot:4","Explicit occupied-socket removal remains available on a full tower")

func stale_selections() -> void:
	group = "stale chooser"
	for stale in ["item","target","replacement","slots","phase"]:
		await fixture([40,41],2)
		await enter_socket(0)
		var chosen := await enter_picker()
		if stale == "item":
			for index in range(scene.run.items.size()-1,-1,-1):
				if str(scene.run.items[index].id) == chosen: scene.run.items.remove_at(index)
		elif stale == "target": scene.run.towers.erase(40)
		elif stale == "replacement": scene.run.towers[40] = scene.run.towers[40].duplicate(true)
		elif stale == "slots": fill(40,1)
		else: scene.run.phase = "battle"
		var before := inventory_ids()
		var attached: int = scene.run.towers[40].attachments.size() if scene.run.towers.has(40) else 0
		var credits: int = scene.run.credits
		await press(JOY_BUTTON_A)
		check(inventory_ids() == before and scene.run.credits == credits,"Stale "+stale+" cannot consume a different module or purchase")
		check(scene.run.towers[41].attachments.is_empty(),"Stale "+stale+" never equips another tower")
		if scene.run.towers.has(40): check(scene.run.towers[40].attachments.size() == attached,"Stale "+stale+" cannot equip the old target")
		if stale in ["target","replacement","phase"]: check(not scene.dock.controller_context_active(),"Stale "+stale+" clears controller upgrade context")
		if scene.dock.is_open(): focused_visible("stale recovery")

func save_failure_feedback() -> void:
	group = "save failure feedback"
	await fixture([40,41],2)
	scene.run_save.file_path = profile+"/missing/run.json"
	await enter_socket(0)
	var chosen := await enter_picker()
	await press(JOY_BUTTON_A)
	check(scene.run.towers[40].attachments.size() == 1 and str(scene.run.towers[40].attachments[0].id) == chosen,"Failed save still equips the confirmed module exactly once in memory")
	check(scene.selected_cell == 41 and not scene.dock.is_open(),"Failed save leaves a valid next tower selection")
	check(scene.save_failed and scene.notice.visible and scene.notice.text.begins_with("PROGRESS NOT SAVED"),"Contextual success feedback cannot overwrite the immediate save failure notice")
	check(scene.hud_nodes.menu.text == "Save!","Failed equipment save retains its persistent retry indicator")

func pointer_at(point: Vector2, touch := false) -> void:
	for down in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = point
			event.pressed = down
			root.push_input(event,true)
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
			event.position = point
			event.global_position = point
			event.pressed = down
			root.push_input(event,true)
		await frames(1 if down else 5)

func pointer_click(control: Control) -> void:
	await pointer_at(control.get_global_rect().get_center())

func controller_pointer_takeover() -> void:
	group = "controller pointer takeover"
	for trigger in [false,true]:
		for lower_card in [false,true]:
			await fixture([40,41],4)
			fill(40,2)
			await enter_socket(2)
			await enter_picker()
			var cards: Array[Button] = []
			for control in scene.dock.find_children("*","Button",true,false):
				if str(control.get_meta("focus_id","")).begins_with("item:"): cards.append(control)
			check(cards.size() >= 3,"Pointer takeover fixture has two rows of module cards")
			if cards.size() < 3: continue
			var bounds := cards[2 if lower_card else 0].get_global_rect()
			var point := bounds.position+Vector2(24,46) if lower_card else bounds.get_center()
			# Model a retained cursor over the old card. The actual takeover and
			# click still originate solely as native R3/right-trigger events.
			scene.controller_cursor.cursor_position = point
			scene.controller_cursor._initialized = true
			var before := all_module_ids()
			var inventory_before := inventory_ids()
			var credits: int = scene.run.credits
			var level: int = scene.run.towers[40].level
			var priority: String = scene.run.towers[40].target_priority
			if trigger:
				for down in [true,false]:
					var event := InputEventJoypadMotion.new()
					event.device = DEVICE
					event.axis = JOY_AXIS_TRIGGER_RIGHT
					event.axis_value = 1.0 if down else 0.0
					Input.parse_input_event(event)
					Input.flush_buffered_events()
					await frames(1 if down else 4)
			else: await press(JOY_BUTTON_RIGHT_STICK)
			check(not scene.dock.controller_context_active(),"R3/trigger takeover clears the chooser context")
			check(all_module_ids() == before and inventory_ids() == inventory_before and scene.run.towers[40].attachments.size() == 2,"First pointer-button takeover cannot equip or remove through replacement UI")
			check(scene.run.credits == credits and scene.run.towers[40].level == level and scene.run.towers[40].target_priority == priority,"First pointer-button takeover cannot purchase or change targeting")
			check(scene.selected_cell == 40 and scene.run.towers[41].attachments.is_empty(),"First pointer-button takeover cannot advance or equip another tower")
			scene.controller_cursor.deactivate()

func ordinary_flows() -> void:
	group = "pointer takeover and ordinary controls"
	for native_touch in [false,true]:
		await fixture([40,41],3)
		await enter_socket(0)
		var chosen := await enter_picker()
		var choice := by_id("item:"+chosen)
		check(is_instance_valid(choice),"Contextual takeover target exists")
		var before := inventory_ids()
		if is_instance_valid(choice): await pointer_at(choice.get_global_rect().get_center(),native_touch)
		await frames(6)
		check(not scene.dock.controller_context_active(),"Pointer/touch takeover clears controller-only context: "+str(native_touch))
		check(inventory_ids() == before and scene.run.towers[40].attachments.is_empty() and scene.selected_cell == 40,"Takeover tap on contextual card cannot equip or advance the board: "+str(native_touch))
		check(scene.dock.is_open() and scene.dock.current_panel == "tower","Takeover returns to ordinary tower UI before another pointer action")
	scene.dock.open_panel("bag",40)
	await frames(6)
	var id: String = str(scene.run.items[0].id)
	var card := by_id("item:"+id)
	check(is_instance_valid(card),"Ordinary gear retains selected module")
	if is_instance_valid(card):
		scene.dock._scroll.ensure_control_visible(card)
		await frames()
		await pointer_click(card)
		var attach := by_id("attach:selected")
		check(is_instance_valid(attach),"Pointer selection retains its explicit fit action")
		if is_instance_valid(attach):
			scene.dock._scroll.ensure_control_visible(attach)
			await frames()
			await pointer_click(attach)
			check(scene.run.towers[40].attachments.size() == 1 and scene.selected_cell == 40,"Pointer equip fits once without controller automatic tower advance")
	scene.dock.close_panel()
	await press(JOY_BUTTON_X)
	check(scene.dock.current_panel == "bag" and not scene.dock.controller_context_active(),"Ordinary X gear opens outside the upgrade context")
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(scene.dock.current_panel == "loot","Ordinary gear RB still selects the next management tab")
	await press(JOY_BUTTON_LEFT_SHOULDER)
	check(scene.dock.current_panel == "bag","Ordinary gear LB still selects the previous management tab")
	await press(JOY_BUTTON_B)
	scene.run.phase = "solve"
	scene.last_phase = "solve"
	for number in range(1,10):
		for cell in range(81):
			if scene.run.givens[cell] and scene.run.solution[cell] == number:
				scene.run.board[cell] = 0
				scene.run.givens[cell] = false
				break
	scene._select(0,false,false)
	scene.selected_number = 1
	scene._refresh()
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(scene.selected_number == 2 and scene.selected_cell == 0,"Solve-mode ordinary shoulders still cycle Sudoku numbers")
	await press(JOY_BUTTON_LEFT_SHOULDER)
	check(scene.selected_number == 1 and scene.selected_cell == 0,"Ordinary number cycle works in both directions")

func exercise() -> void:
	if rendered and DisplayServer.get_name() == "headless":
		push_error("--render-check needs a real graphics display; dummy headless pixels are not accepted")
		quit(1)
		return
	root.size = Vector2i(1280,800)
	await repeated_equipping()
	await cycle_and_cancel()
	await sockets_and_removal()
	await empty_and_full()
	await stale_selections()
	await save_failure_feedback()
	await controller_pointer_takeover()
	await ordinary_flows()
	if is_instance_valid(scene):
		scene.queue_free()
		await frames(3)
	print("CONTROLLER_UPGRADES_%s: %d checks / %d failures; renderer=%s; real_pixels=%s" % ["PASS" if failures == 0 else "FAIL",checks,failures,variant,rendered])
	quit(0 if failures == 0 else 1)
