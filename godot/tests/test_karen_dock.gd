extends SceneTree
## Management navigation and fitting through the real dock controls.
const Run = preload("res://scripts/run.gd")
const Dock = preload("res://scripts/dock.gd")
const Loot = preload("res://scripts/loot.gd")
var checks := 0
var failures := 0
var run
var dock
var armed_count := 0

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 4) -> void:
	for i in range(count): await process_frame

func by_id(id: String) -> Button:
	for node in dock.find_children("*", "Button", true, false):
		if node.is_visible_in_tree() and str(node.get_meta("focus_id", "")) == id: return node
	return null

func press(id: String) -> void:
	var target := by_id(id)
	check(is_instance_valid(target) and not target.disabled, "Action available: " + id)
	if not is_instance_valid(target) or target.disabled: return
	target.grab_focus()
	target.pressed.emit()
	await frames()

func focused_id() -> String:
	var focused: Control = root.gui_get_focus_owner()
	return str(focused.get_meta("focus_id", "")) if is_instance_valid(focused) else ""

func capture(stage: String) -> void:
	if "--capture-karen" not in OS.get_cmdline_user_args(): return
	check(DisplayServer.get_name() != "headless", "Captures require a real framebuffer")
	if DisplayServer.get_name() == "headless": return
	await frames(4)
	await RenderingServer.frame_post_draw
	var directory := "res://build/karen-checks"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var layout := "portrait" if "--portrait" in OS.get_cmdline_user_args() else "deck"
	root.get_texture().get_image().save_png("%s/%s-%s.png" % [directory, layout, stage])

func exercise() -> void:
	root.size = Vector2i(600, 1066) if "--portrait" in OS.get_cmdline_user_args() else Vector2i(1280, 800)
	root.content_scale_size = root.size
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	run = Run.new()
	run.new_run(324675, {"mode": "campaign", "puzzle_difficulty": "easy", "combat_difficulty": "easy"})
	var cell := -1
	for i in range(81):
		if not run.givens[i]:
			cell = i
			run.place(i, run.solution[i])
			break
	run.phase = "prep"
	run.items.clear()
	for index in range(16):
		var kind: String = ["frost", "range", "power", "rapid"][index % 4]
		run.items.append(Loot.make_item(run.rng, "common", 1, 5000 + index, kind, true))
	dock = Dock.new()
	root.add_child(dock)
	dock.setup(run)
	dock.set_layout(Vector2(root.size), "--portrait" in OS.get_cmdline_user_args(), 600.0)
	dock.set_controller_mode(true)
	dock.changed.connect(func(_result): dock.refresh())
	dock.item_armed.connect(func(id):
		if not str(id).is_empty(): armed_count += 1
	)
	dock.open_panel("tower", cell)
	await frames()
	check(focused_id() == "slot:0", "Workshop opens at first empty socket")
	await capture("tower")
	await press("slot:0")
	check(dock.current_panel == "bag" and dock.selected_cell == cell, "Empty socket opens Gear on same tower")
	await press("item:5000")
	check(dock.is_open() and dock.has_selected_modules() and armed_count == 0, "Selecting a module stays in Gear for batching")
	await press("filter:range")
	check(dock._selected_module_ids.size() == 1, "Changing effect filter retains selected modules")
	check(dock._visible_items().all(func(item): return str(item.kind) == "range"), "Range filter contains range modules")
	await press("item:5001")
	check(dock._selected_module_ids.size() == 2, "Modules from different filters can be selected together")
	check(root.get_visible_rect().grow(2).encloses(by_id("attach:selected").get_global_rect()), "Batch action remains visible while browsing inventory")
	check(not dock._scroll.is_ancestor_of(by_id("attach:selected")), "Batch count and action stay outside the scrolling list")
	var destination: Label = dock.find_child("BatchTarget", true, false)
	check(is_instance_valid(destination) and destination.text == "Tower %d · R%d C%d" % [int(run.towers[cell].number), cell / 9 + 1, cell % 9 + 1], "Fixed footer identifies the exact destination tower")
	check(root.get_visible_rect().grow(2).encloses(destination.get_global_rect()) and not dock._scroll.is_ancestor_of(destination), "Destination stays visible while browsing inventory")
	check(dock._scroll.size.x >= 270 and dock._scroll.size.y >= 174, "Gear retains enough scroll space for two full-width module tiles")
	await capture("gear-batch")
	dock._focus_id("filter:range")
	await frames()
	await capture("gear-filters")
	await press("attach:selected")
	check(run.towers[cell].attachments.size() == 2 and run.items.size() == 14, "Install selected moves both modules once")
	check(dock.selected_cell == cell and dock.current_panel == "bag" and dock.is_open(), "Batch install stays on same tower in Gear")
	check(dock._bag_filter == "range" and not dock.has_selected_modules(), "Install retains filter and clears completed selection")
	check(by_id("attach:selected").disabled, "Repeat activation cannot install the same batch again")
	await press("filter:slow")
	check(dock._visible_items().all(func(item): return str(item.kind) in ["frost", "gravity", "freeze"]), "Slow groups control effects")
	await press("filter:damage")
	check(dock._visible_items().all(func(item): return str(item.kind) == "power"), "Damage filters damage modules")
	await press("filter:speed")
	check(dock._visible_items().all(func(item): return str(item.kind) == "rapid"), "Speed filters fire-rate modules")
	await press("filter:all")
	for id in ["5002", "5003", "5004"]: await press("item:" + id)
	await press("item:5005")
	check(dock._selected_module_ids.size() == 3, "Selection cannot exceed remaining sockets")
	await press("item:5003")
	check(dock._selected_module_ids.size() == 2, "Selected module can be deselected")
	await press("gear:cancel")
	check(not dock.has_selected_modules(), "Clear selection retains owned gear")
	await press("item:5002")
	var seed_toggle := by_id("bag:reserves")
	seed_toggle.grab_focus()
	dock.navigate_focus(Vector2i.DOWN)
	await frames()
	check(focused_id() == "attach:selected", "D-pad reaches fixed install footer from the last content row")
	dock.navigate_focus(Vector2i.UP)
	await frames()
	check(focused_id() == "bag:reserves", "D-pad returns from footer to the last content row")
	# Long camp list must follow one row at a time, then reverse the same path.
	run.phase = "loot"
	run.credits = 1000
	dock._show_odds = true
	dock.open_panel("camp", cell)
	await frames(6)
	check(focused_id() == "slot:spin", "Camp opens on usable slots before upgrades")
	await capture("camp-slots")
	var path: Array[String] = [focused_id()]
	for i in range(4):
		dock.navigate_focus(Vector2i.DOWN)
		await frames()
		path.append(focused_id())
		var focused: Control = root.gui_get_focus_owner()
		check(dock._scroll.get_global_rect().grow(2).encloses(focused.get_global_rect()), "Navigating down scrolls focus into view")
	check(path == ["slot:spin", "slot:odds", "passive:power", "passive:salvage", "passive:vitality"], "Camp visits each row without jumping")
	for i in range(3, -1, -1):
		dock.navigate_focus(Vector2i.UP)
		await frames()
		check(focused_id() == path[i], "Reversing camp navigation returns to adjacent row")
	await press("slot:spin")
	check(not dock._slot_result.is_empty(), "Affordable salvage spin works through its button")
	run.phase = "prep"
	dock.refresh()
	await frames()
	check(by_id("slot:spin").disabled, "Slots remain closed before wave ends")
	run.phase = "loot"
	run.credits = 9
	dock.refresh()
	await frames()
	check(by_id("slot:spin").disabled, "Unaffordable slot action remains disabled")
	print("KAREN_DOCK_CHECKS=%d FAILURES=%d" % [checks, failures])
	dock.queue_free()
	await frames(2)
	quit(1 if failures else 0)
