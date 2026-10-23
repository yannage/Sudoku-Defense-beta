extends SceneTree
## A family upgrade must show exactly which planted towers receive it.
var checks := 0
var failures := 0
var scene

func _initialize() -> void:
	call_deferred("exercise")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func button_by_id(id: String) -> Button:
	for button in scene.dock._shell.find_children("*", "Button", true, false):
		if str(button.get_meta("focus_id", "")) == id: return button
	return null

func move_mouse(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	await frames()

func click(point: Vector2) -> void:
	await move_mouse(point)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		root.push_input(event, true)
		await frames(1)
	await frames()

func press_a() -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 42
		event.button_index = JOY_BUTTON_A
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)
	await frames()

func exercise() -> void:
	root.size = Vector2i(1280, 800)
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await frames(5)
	scene.muted = true
	scene.sound.set_muted(true)
	scene.seed_input.text = "784217"
	scene._start_run()
	var family := 0
	var targets: Array[int] = []
	for number in [4]:
		var eligible: Array[int] = []
		for cell in range(81):
			if scene.run.board[cell] == 0 and scene.run.solution[cell] == number: eligible.append(cell)
		if eligible.size() >= 3:
			family = number
			targets.assign(eligible.slice(0, 3))
			break
	check(family > 0, "Fixture includes three plantable towers of one number")
	for cell in targets: scene.run.place(cell, family)
	var other_cell := -1
	for cell in range(81):
		if scene.run.board[cell] == 0 and scene.run.solution[cell] == 8:
			other_cell = cell
			scene.run.place(cell, scene.run.solution[cell])
			break
	var other_number: int = scene.run.board[other_cell]
	scene.run.credits = 500
	scene.run.update(1.0)
	scene.run.drain_events()
	scene.run.advance_phase()
	scene.last_phase = "prep"
	for i in range(40): scene.world.tick(0.05)
	scene._refresh()
	await frames()
	await click(scene.world.cell_screen_position(targets[0]))
	check(scene.dock.is_open() and scene.dock.current_panel == "tower", "Clicking a planted tower opens the family workshop")
	check(scene.selected_number == family and scene.world.selected_number == family, "Inspecting a tower chooses its number family on the main board")
	check(scene.world._family_focus == family, "Open workshop highlights the selected planted family")
	var upgrade: Button = button_by_id("upgrade:family")
	check(is_instance_valid(upgrade), "Family upgrade action exists")
	check(upgrade.text.contains("Upgrade all %ds · 3 towers" % family), "Family action names the number and exact affected tower count")
	check(upgrade.text.contains("%d credits" % scene.run.family_upgrade_cost(family)), "Family upgrade displays a separate, explicit credit price")
	var matching_givens := 0
	for cell in range(81):
		var button: Button = button_by_id("cell:" + str(cell))
		check(is_instance_valid(button), "Mini-grid contains square %d" % cell)
		var style: StyleBoxFlat = button.get_theme_stylebox("normal")
		if cell in targets:
			check(button.text == str(family) and not button.disabled, "Affected mini-grid towers have their number and remain selectable")
			check(style.border_width_left == (3 if cell == targets[0] else 2), "Selected tower is distinct from the other highlighted family targets")
			check(style.border_color == (scene.dock.GOLD if cell == targets[0] else scene.dock.FAMILY_COLORS[family]), "Selected tower has a gold border and its family has number-colored borders")
		elif scene.run.givens[cell] and scene.run.board[cell] == family:
			matching_givens += 1
			check(button.disabled and style.border_width_left == 1 and style.border_color == scene.dock.LINE, "Printed matching clues are excluded from family upgrade targets")
		elif cell == other_cell:
			check(style.border_width_left == 1 and style.border_color == scene.dock.LINE, "A different planted number is excluded from the family outline")
	check(matching_givens > 0, "Fixture checks matching fixed clues as well as matching towers")
	var previews: Array[int] = []
	scene.dock.family_preview_requested.connect(func(number: int): previews.append(number))
	await move_mouse(upgrade.get_global_rect().get_center())
	check(family in previews and scene.world._family_focus == family, "Mouse hover on the actual family action previews its affected towers")
	await move_mouse(Vector2(30, 90))
	check(scene.world._family_focus == family, "Leaving the action preserves the open workshop's selected family")
	scene.controller_used = true
	scene.dock.set_controller_mode(true)
	await frames()
	upgrade = button_by_id("upgrade:family")
	upgrade.grab_focus()
	await frames()
	check(scene.world._family_focus == family, "Controller focus also previews the family")
	if "--capture-workshop" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		scene.notice_time = 0
		scene.notice.hide()
		scene._update_context_visibility()
		var last_square: Button = button_by_id("cell:80")
		var below: float = last_square.get_global_rect().end.y - scene.dock._scroll.get_global_rect().end.y + 4
		scene.dock._scroll.scroll_vertical += int(maxf(0.0, below))
		await frames()
		await RenderingServer.frame_post_draw
		var variant := "canvas" if "--canvas-graphics" in OS.get_cmdline_user_args() else "native"
		root.get_texture().get_image().save_png("res://build/family-workshop-%s.png" % variant)
	var old_damage: Dictionary = {}
	for cell in targets: old_damage[cell] = scene.run.tower_stats(cell).damage
	var other_damage: float = scene.run.tower_stats(other_cell).damage
	var board_before: Array = scene.run.board.duplicate()
	var credits_before: int = scene.run.credits
	var cost: int = scene.run.family_upgrade_cost(family)
	await press_a()
	check(scene.run.family_levels[family] == 2 and scene.run.credits == credits_before - cost, "Controller activation buys the shown family level exactly once for its quoted price")
	for cell in targets:
		check(scene.run.tower_stats(cell).damage > old_damage[cell], "Every highlighted family tower receives the purchased improvement")
	check(scene.run.tower_stats(other_cell).damage == other_damage, "Other number families receive no unintended upgrade")
	check(scene.run.board == board_before, "Family upgrades never alter Sudoku numbers or printed clues")
	# The first mouse click after controller use must survive the hint refresh,
	# including when its target is a scrolled mini-grid button.
	await move_mouse(Vector2(30, 90))
	var mini_other: Button = button_by_id("cell:" + str(other_cell))
	scene.dock._scroll.ensure_control_visible(mini_other)
	await frames()
	await click(mini_other.get_global_rect().get_center())
	check(scene.selected_cell == other_cell and scene.selected_number == other_number, "Mini-grid selection changes the inspected tower and chosen family together")
	check(scene.world._family_focus == other_number, "Main board follows a mini-grid family change")
	upgrade = button_by_id("upgrade:family")
	check(upgrade.text.contains("Upgrade all %ds · 1 tower" % other_number), "Family summary updates to the newly selected number and count")
	scene.controller_used = true
	scene.dock.set_controller_mode(true)
	await frames()
	var mini_touch: Button = button_by_id("cell:" + str(targets[1]))
	scene.dock._scroll.ensure_control_visible(mini_touch)
	await frames()
	var touch_point: Vector2 = mini_touch.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = touch_point
		event.pressed = pressed
		root.push_input(event, true)
		await frames(1)
	await frames()
	check(scene.selected_cell == targets[1] and scene.selected_number == family, "First touch after controller use selects its mini-grid tower without losing the press")
	check(scene.world._family_focus == family, "Touch mini-grid selection restores the chosen family's board highlight")
	scene.dock.close_panel()
	await frames()
	check(scene.world._family_focus == 0, "Closing the workshop clears its family focus")
	scene.queue_free()
	await frames()
	print("FAMILY_WORKSHOP_CHECKS: %d assertions, %d failures" % [checks, failures])
	print("FAMILY_WORKSHOP_PASS" if failures == 0 else "FAMILY_WORKSHOP_FAIL")
	quit(1 if failures else 0)
