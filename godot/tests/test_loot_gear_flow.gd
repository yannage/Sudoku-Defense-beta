extends SceneTree
## Real-scene loot/gear interaction and layout regression. Optional framebuffer
## captures use --capture-loot-gear; --portrait tests the phone layout.
const Loot = preload("res://scripts/loot.gd")
var scene
var checks := 0
var failures := 0
var tower_cells: Array[int] = []

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

func physical(point: Vector2) -> Vector2:
	return root.get_final_transform() * point

func synchronize_render_pointer(point: Vector2) -> void:
	# parse_input_event never moves the OS cursor. Native GUI drag hit testing
	# queries that cursor, so framebuffer fixtures synchronize it explicitly.
	# Headless regressions retain raw touch dispatch without any cursor warp;
	# rendered captures are not a substitute for physical Steam Deck testing.
	if DisplayServer.get_name() != "headless":
		Input.warp_mouse(physical(point))

func finger(point: Vector2, pressed: bool) -> void:
	synchronize_render_pointer(point)
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = physical(point)
	event.pressed = pressed
	dispatch(event)

func drag_finger(from: Vector2, to: Vector2) -> void:
	synchronize_render_pointer(to)
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = physical(to)
	event.relative = physical(to) - physical(from)
	dispatch(event)

func mouse_event(point: Vector2, pressed: bool) -> void:
	synchronize_render_pointer(point)
	var event := InputEventMouseButton.new()
	event.position = physical(point)
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	dispatch(event)

func mouse_drag(from: Vector2, to: Vector2) -> void:
	synchronize_render_pointer(to)
	var event := InputEventMouseMotion.new()
	event.position = physical(to)
	event.global_position = event.position
	event.relative = physical(to)-physical(from)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	dispatch(event)

func drag_module(item_id: String, destination: Vector2, use_mouse := false) -> void:
	var card := by_id("item:"+item_id)
	check(is_instance_valid(card),"Drag source exists in the filtered inventory")
	if not is_instance_valid(card): return
	await show(card)
	var start := center(card)
	var lift := start + Vector2(-18,-18)
	if use_mouse: mouse_event(start,true)
	else: finger(start,true)
	await frames(1)
	if use_mouse: mouse_drag(start,lift)
	else: drag_finger(start,lift)
	await frames(2)
	if use_mouse: mouse_drag(lift,destination)
	else: drag_finger(lift,destination)
	await frames(3)
	check(root.gui_is_dragging(),"Dragging a module starts Godot's actual GUI drag")
	if not use_mouse: await capture("module-drag")
	if use_mouse: mouse_event(destination,false)
	else: finger(destination,false)
	await frames(5)
	check(not root.gui_is_dragging(),"Releasing a module finishes GUI drag ownership")

func tap(point: Vector2) -> void:
	finger(point,true)
	await frames(1)
	finger(point,false)
	await frames()

func pad(button: int) -> void:
	for pressed in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device = 42
		event.button_index = button
		event.pressed = pressed
		dispatch(event)
		await frames(1)
	await frames()

func by_id(id: String) -> Button:
	for node in scene.dock.find_children("*","Button",true,false):
		if node.is_visible_in_tree() and str(node.get_meta("focus_id","")) == id: return node
	return null

func center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()

func show(control: Control) -> void:
	if not is_instance_valid(control): return
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await frames()

func tap_id(id: String) -> void:
	var button := by_id(id)
	check(is_instance_valid(button),"Visible action exists: " + id)
	if not is_instance_valid(button): return
	await show(button)
	await tap(center(button))

func choose_pad(id: String) -> void:
	var button := by_id(id)
	check(is_instance_valid(button) and not button.disabled,"Controller action is available: " + id)
	if not is_instance_valid(button): return
	button.grab_focus()
	await frames()
	await pad(JOY_BUTTON_A)

func viewport_contains(control: Control) -> bool:
	return root.get_visible_rect().grow(2).encloses(control.get_global_rect())

func capture(stage: String) -> void:
	if "--capture-loot-gear" not in OS.get_cmdline_user_args(): return
	check(DisplayServer.get_name() != "headless","Framebuffer captures require a real graphics display")
	if DisplayServer.get_name() == "headless": return
	scene.notice.hide()
	await frames(4)
	await RenderingServer.frame_post_draw
	var directory := "res://build/loot-gear-checks"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var variant := "canvas" if "--canvas-graphics" in OS.get_cmdline_user_args() else "native"
	var layout := "portrait" if "--portrait" in OS.get_cmdline_user_args() else "deck"
	var screenshot: Image = root.get_texture().get_image()
	check(not screenshot.is_empty(),"Real framebuffer exists for " + stage)
	screenshot.save_png("%s/%s-%s-%s.png" % [directory,variant,layout,stage])

func reward_cards() -> Array[Control]:
	var cards: Array[Control] = []
	for node in scene.dock._loot_table.find_children("*","Control",true,false):
		if node.is_visible_in_tree() and node.has_meta("reward_item_id"): cards.append(node)
	return cards

func open_loot() -> void:
	if scene.dock.is_open(): scene.dock.close_panel()
	await frames()
	await tap(center(scene.loot_button))
	check(scene.dock.is_open() and scene.dock.current_panel == "loot","Chest quick button opens the loot table")
	check(is_instance_valid(scene.dock._loot_table) and scene.dock._loot_table.is_visible_in_tree(),"Loot table is a visible persistent control")
	check(viewport_contains(scene.dock._shell),"Full loot surface stays within the screen")
	check(scene.dock._shell.size.x > scene.layout_size.x * 0.7,"Loot gets a full-width presentation rather than the narrow inventory panel")

func exercise() -> void:
	root.size = Vector2i(600,1066) if "--portrait" in OS.get_cmdline_user_args() else Vector2i(1280,800)
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await frames(6)
	scene.muted = true
	scene.sound.set_muted(true)
	scene.seed_input.text = "784217"
	scene._start_run()
	for cell in range(81):
		if scene.run.board[cell] == 0 and tower_cells.size() < 3:
			scene.run.place(cell,scene.run.solution[cell])
			tower_cells.append(cell)
	scene.run.phase = "prep"
	scene.last_phase = "prep"
	scene.run.fragments = 100
	scene.run.credits = 500
	scene.run.chests.clear()
	var common: Dictionary = scene.run._add_chest("common")
	var rare: Dictionary = scene.run._add_chest("rare")
	var legendary: Dictionary = scene.run._add_chest("legendary")
	scene._refresh()
	await frames(8)
	await open_loot()
	await capture("table")
	var table = scene.dock._loot_table
	var fragments: int = scene.run.fragments
	var items: int = scene.run.items.size()
	var sealed: int = scene.run.chests.size()
	var legendary_button := by_id("chest:" + str(legendary.id))
	check(is_instance_valid(legendary_button) and not legendary_button.disabled,"Earned legendary chest itself is tappable")
	if is_instance_valid(legendary_button):
		var spot := center(legendary_button)
		await tap(spot)
		await tap(spot)
	check(scene.run.fragments == fragments-int(legendary.cost),"Repeated chest taps charge fragments exactly once")
	check(scene.run.items.size() == items+3 and scene.run.chests.size() == sealed-1,"Legendary opening grants all three items exactly once")
	await pad(JOY_BUTTON_B)
	check(not scene.dock.is_open(),"Controller B can leave during the opening animation")
	await create_timer(0.85).timeout
	await open_loot()
	check(scene.dock._loot_table == table,"Closing and reopening preserves the same loot presentation")
	check(scene.run.items.size() == items+3 and scene.run.fragments == fragments-int(legendary.cost),"Reopening the presentation never grants or charges again")
	var cards := reward_cards()
	check(cards.size() == 3,"All three legendary rewards appear together")
	for card in cards: check(viewport_contains(card),"Every reward fits onscreen without scrolling")
	check(is_instance_valid(by_id("loot:continue")) and viewport_contains(by_id("loot:continue")),"Reveal has an onscreen continue action")
	await capture("reveal")
	await choose_pad("loot:continue")
	check(table.reward.is_empty(),"Continuing returns to the table without unresolved reward state")
	# One- and two-item chests use the same direct presentation and safe economy.
	for chest in [common,rare]:
		items = scene.run.items.size()
		fragments = scene.run.fragments
		var count := 1 if str(chest.rarity) == "common" else 2
		await choose_pad("chest:" + str(chest.id))
		await create_timer(0.85).timeout
		check(scene.run.items.size() == items+count and scene.run.fragments == fragments-int(chest.cost),"Controller opening grants and charges the quoted chest once")
		check(reward_cards().size() == count,"Every reward is shown for a %s chest" % chest.rarity)
		if str(chest.rarity) == "rare":
			var earned_ids: Array[String] = []
			for earned in table.reward.get("rewards",[]): earned_ids.append(str(earned.id))
			var secured_count: int = scene.run.items.size()
			await choose_pad("loot:equip")
			check(scene.dock.is_open() and scene.dock.current_panel == "bag","Equip new gear leads directly to the module bench")
			check(scene.armed_item.is_empty() and scene.run.items.size() == secured_count,"Reward handoff neither auto-equips nor consumes gear")
			var focus: Control = root.gui_get_focus_owner()
			check(is_instance_valid(focus) and str(focus.get_meta("focus_id","")).trim_prefix("item:") in earned_ids,"Reward handoff focuses one of the newly earned items")
			await open_loot()
		else: await tap_id("loot:continue")
	# Insufficient fragments and combat phase cannot bypass the unlock cost.
	var locked: Dictionary = scene.run._add_chest("epic")
	scene.run.fragments = 0
	table.refresh()
	await frames()
	var locked_button := by_id("chest:" + str(locked.id))
	check(is_instance_valid(locked_button) and locked_button.disabled,"Unaffordable chest remains visible and locked")
	items = scene.run.items.size()
	await tap(center(locked_button))
	check(scene.run.items.size() == items and scene.run.chests.size() == 1,"Touching a locked chest cannot grant gear")
	scene.run.fragments = 100
	scene.run.phase = "battle"
	scene.last_phase = "battle"
	table.refresh()
	await frames()
	check(by_id("chest:" + str(locked.id)).disabled,"Combat prevents chest opening while preserving the table")
	scene.run.phase = "prep"
	scene.last_phase = "prep"
	scene.dock.close_panel()
	await frames()
	await gear_checks()
	scene.queue_free()
	await frames()
	print("LOOT_GEAR_FLOW_CHECKS: %d assertions, %d failures" % [checks,failures])
	print("LOOT_GEAR_FLOW_PASS" if failures == 0 else "LOOT_GEAR_FLOW_FAIL")
	quit(1 if failures else 0)

func gear_checks() -> void:
	# Fill a representative inventory with every module category and consumables.
	scene.run.items.clear()
	for kind in Loot.ATTACHMENTS + ["repair","overclock"]:
		scene.run.items.append(Loot.make_item(scene.run.rng,"rare",3,scene.run._id(),kind))
	scene._select(tower_cells[0],false,false)
	await tap(center(scene.bag_button))
	check(scene.dock.current_panel == "bag" and scene.dock.is_open(),"Gear quick button opens the module inventory")
	check(viewport_contains(scene.dock._shell),"Gear inventory stays within the screen")
	var reachable: Dictionary = {}
	for category in ["attack","support","items"]:
		await tap_id("filter:" + category)
		check(scene.dock._bag_filter == category,"Touch activates the %s inventory filter" % category)
		for card in scene.dock._shell.find_children("*","Button",true,false):
			if str(card.get_meta("focus_id","")).begins_with("item:"):
				reachable[str(card.item.id)] = true
	check(reachable.size() == scene.run.items.size(),"Category filters collectively expose every inventory item")
	await tap_id("filter:all")
	await capture("gear")
	var item: Dictionary = scene.run.items[0]
	await tap_id("item:" + str(item.id))
	check(scene.armed_item == str(item.id),"Tapping a module arms that exact item")
	await capture("gear-armed")
	var inventory_before: int = scene.run.items.size()
	await tap(scene.world.cell_screen_position(tower_cells[0]))
	check(scene.run.towers[tower_cells[0]].attachments.size() == 1,"Touching the tower snaps one selected module into its stack")
	check(scene.run.items.size() == inventory_before-1 and scene.armed_item.is_empty(),"Successful attachment removes only the selected module and clears targeting")
	# Drag through real pointer dispatch; no force_drag or direct _drop_data calls.
	for use_mouse in [false,true]:
		scene.dock.open_panel("bag",tower_cells[0])
		await frames()
		item = scene.run.items[0]
		inventory_before = scene.run.items.size()
		var target_cell: int = tower_cells[2] if use_mouse else tower_cells[1]
		await drag_module(str(item.id),scene.world.cell_screen_position(target_cell),use_mouse)
		check(scene.run.towers[target_cell].attachments.size() == 1,"Actual %s drag attaches one module to the destination tower" % ("mouse" if use_mouse else "touch"))
		check(scene.run.items.size() == inventory_before-1,"Actual drag consumes exactly one inventory item")
	# Full towers reject an attempted sixth module without consuming inventory.
	for i in range(4):
		var extra: Dictionary = Loot.make_item(scene.run.rng,"common",1,scene.run._id(),"rapid")
		scene.run.items.append(extra)
		scene.run.equip_item(tower_cells[0],str(extra.id))
	check(scene.run.towers[tower_cells[0]].attachments.size() == 5,"Capacity fixture has exactly five equipped modules")
	scene.dock.open_panel("bag",tower_cells[0])
	await frames()
	item = scene.run.items[0]
	await tap_id("item:" + str(item.id))
	inventory_before = scene.run.items.size()
	await tap(scene.world.cell_screen_position(tower_cells[0]))
	check(scene.run.towers[tower_cells[0]].attachments.size() == 5 and scene.run.items.size() == inventory_before,"A full target never consumes a sixth module")
	await pad(JOY_BUTTON_B)
	await pad(JOY_BUTTON_B)
	check(scene.armed_item.is_empty(),"Cancel leaves the rejected item in inventory and releases targeting")
	# Swapping uses a real drag into an occupied socket, preserving the old item.
	scene.dock.open_panel("bag",tower_cells[0])
	await frames()
	item = scene.run.items[0]
	var item_id: String = str(item.id)
	await tap_id("item:" + item_id)
	var previous_id: String = str(scene.run.towers[tower_cells[0]].attachments[0].id)
	inventory_before = scene.run.items.size()
	var source := by_id("item:" + item_id)
	await show(source)
	var start := center(source)
	var lift := start + Vector2(-18,-18)
	mouse_event(start,true)
	await frames(1)
	mouse_drag(start,lift)
	await frames(2)
	check(root.gui_is_dragging(),"Socket swap begins with a real module drag")
	var socket := by_id("slot:0")
	check(is_instance_valid(socket),"Selected tower exposes its occupied module sockets")
	if is_instance_valid(socket):
		await show(socket)
		var destination := center(socket)
		mouse_drag(lift,destination)
		await frames(2)
		mouse_event(destination,false)
		await frames(4)
	check(str(scene.run.towers[tower_cells[0]].attachments[0].id) == item_id,"Dropping onto an occupied socket installs the selected module")
	check(scene.run.towers[tower_cells[0]].attachments.size() == 5 and scene.run.items.size() == inventory_before,"Socket swap preserves both inventory and tower capacity")
	check(scene.run.items.any(func(module): return str(module.id) == previous_id),"Socket swap returns the previous module to inventory without loss")
	scene.dock.open_panel("tower",tower_cells[0])
	await frames()
	await capture("workshop")
