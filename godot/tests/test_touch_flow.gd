extends SceneTree
## Real pointer events through the game's input and GUI dispatch, in logical
## viewport coordinates. Run with both native 3D and --canvas-graphics.

var checks: int = 0
var failures: int = 0
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

func touch(point: Vector2, pressed: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)

func touch_motion(from: Vector2, to: Vector2, index: int = 0) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = to
	event.relative = to - from
	root.push_input(event, true)

func mouse(point: Vector2, pressed: bool, device: int = 0) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = point
	event.global_position = point
	event.pressed = pressed
	event.device = device
	root.push_input(event, true)

func mouse_motion(from: Vector2, to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	event.relative = to - from
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)

func tap(point: Vector2) -> void:
	touch(point, true)
	await frames(1)
	touch(point, false)
	await frames()

func click(point: Vector2) -> void:
	mouse(point, true)
	await frames(1)
	mouse(point, false)
	await frames()

func press_pad(button: int) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 42
		event.button_index = button
		event.pressed = down
		Input.parse_input_event(event)
		await frames(1)
	await frames()

func point_for_number(number: int) -> Vector2:
	return scene.number_buttons[number - 1].get_global_rect().get_center()

func blank_cell(except: Array[int] = []) -> int:
	for cell in range(81):
		if scene.run.board[cell] == 0 and cell not in except: return cell
	return -1

func given_cell() -> int:
	for cell in range(81):
		if scene.run.givens[cell]: return cell
	return -1

func drag_number(number: int, destination: Vector2, use_mouse: bool = false) -> void:
	var start: Vector2 = point_for_number(number)
	if use_mouse: mouse(start, true)
	else: touch(start, true)
	await frames(1)
	var middle: Vector2 = start.lerp(destination, 0.5)
	if use_mouse: mouse_motion(start, middle)
	else: touch_motion(start, middle)
	await frames(1)
	if use_mouse: mouse_motion(middle, destination)
	else: touch_motion(middle, destination)
	await frames(1)
	if use_mouse: mouse(destination, false)
	else: touch(destination, false)
	await frames()

func exercise() -> void:
	root.size = Vector2i(1280, 800)
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await frames(5)
	scene.muted = true
	scene.sound.set_muted(true)
	scene.seed_input.text = "12345"
	scene._start_run()
	await frames(5)
	check(scene.selected_number == 0 and scene.world.selected_number == 0, "A new run starts without an unexplained digit highlight")
	if "--canvas-graphics" in OS.get_cmdline_user_args():
		check(root.disable_3d and scene.world is Node2D, "Touch suite exercises the browser's Canvas board")

	# A remembered number must never cause a new board tap to submit an answer.
	var cell: int = blank_cell()
	var answer: int = scene.run.solution[cell]
	scene.selected_number = answer
	var before: int = scene.run.towers.size()
	await tap(scene.world.cell_screen_position(cell))
	check(scene.selected_cell == cell, "Touch selects the square under the finger")
	check(scene.run.board[cell] == 0 and scene.run.towers.size() == before, "Touching an empty square only selects, even with a remembered number")
	# Exercise a raw finger and its synthetic mouse copy as one gesture.
	# A later standalone emulated mouse click is valid input, not a duplicate.
	var solved_before: int = scene.run.round_solved
	var number_point: Vector2 = point_for_number(answer)
	touch(number_point, true)
	mouse(number_point, true, InputEvent.DEVICE_ID_EMULATION)
	await frames(1)
	mouse(number_point, false, InputEvent.DEVICE_ID_EMULATION)
	touch(number_point, false)
	await frames()
	check(scene.run.board[cell] == answer and scene.run.towers.size() == before + 1, "Tapping a number commits exactly one tower to the selected square")
	check(not scene.dock.is_open(), "One placement does not also open the tower inspector")
	check(scene.run.round_solved == solved_before + 1, "Paired touch/mouse placement awards one answer")
	check(not scene.dock.is_open(), "Paired mouse input cannot open the newly planted tower")
	await tap(scene.world.cell_screen_position(cell))
	check(scene.dock.is_open() and scene.dock.current_panel == "tower", "A separate tap on an existing tower opens its workshop")
	scene.dock.close_panel()
	await frames()

	# The Deck's configured touchscreen mouse emulation gets the same flow.
	cell = blank_cell()
	answer = scene.run.solution[cell]
	scene.selected_number = answer
	await click(scene.world.cell_screen_position(cell))
	check(scene.selected_cell == cell and scene.run.board[cell] == 0, "Mouse-emulated Deck tap selects without auto-planting")
	await click(point_for_number(answer))
	check(scene.run.board[cell] == answer, "Mouse-emulated Deck number tap plants the selected square")

	# A drag belongs to its destination, not to the previously selected square.
	var selected_before_drag: int = blank_cell()
	cell = blank_cell([selected_before_drag])
	await tap(scene.world.cell_screen_position(selected_before_drag))
	answer = scene.run.solution[cell]
	before = scene.run.towers.size()
	var start: Vector2 = point_for_number(answer)
	var destination: Vector2 = scene.world.cell_screen_position(cell)
	touch(start, true)
	await frames()
	check(scene.run.towers.size() == before, "Touch-down on a number does not prematurely submit to the selected square")
	touch_motion(start, destination)
	await frames()
	check(scene.seed_pointer.is_active() and scene.seed_pointer.dragging, "Dragging a number keeps an active seed preview")
	check(scene.seed_pointer.hover_cell == cell, "Seed drag identifies the visible destination square")
	check(scene.run.board[cell] == 0, "Hovering a number over the grid waits for release")
	touch(destination, false)
	await frames()
	check(scene.run.towers.size() == before + 1 and scene.run.board[cell] == answer, "Touch release plants one number at the drop destination")
	check(scene.run.board[selected_before_drag] == 0, "Dragging never plants into the previously selected square")
	check(not scene.seed_pointer.is_active() and not scene.dock.is_open(), "Successful drop clears the drag and keeps the board playable")
	cell = blank_cell()
	answer = scene.run.solution[cell]
	before = scene.run.towers.size()
	await drag_number(answer, scene.world.cell_screen_position(cell), true)
	check(scene.run.board[cell] == answer and scene.run.towers.size() == before + 1, "Held mouse drag plants one tower through the same interaction")

	# Invalid drops preserve inventory, clue values, and all already built towers.
	cell = blank_cell()
	answer = scene.run.solution[cell]
	var wrong: int = answer % 9 + 1
	before = scene.run.towers.size()
	var credits: int = scene.run.credits
	await drag_number(wrong, scene.world.cell_screen_position(cell))
	check(scene.run.board[cell] == 0 and scene.run.towers.size() == before, "Wrong Sudoku number is rejected on drop")
	check(scene.run.credits == credits and not scene.seed_pointer.is_active(), "Rejected Sudoku drop spends no credits and clears its gesture")
	var fixed: int = given_cell()
	var clue: int = scene.run.board[fixed]
	await drag_number(wrong, scene.world.cell_screen_position(fixed))
	check(scene.run.board[fixed] == clue and scene.run.towers.size() == before, "A drop cannot overwrite a fixed clue")
	var existing: int = int(scene.run.towers.keys()[0])
	var existing_number: int = scene.run.board[existing]
	await drag_number(wrong, scene.world.cell_screen_position(existing))
	check(scene.run.board[existing] == existing_number and scene.run.towers.size() == before, "A seed drop cannot overwrite an existing tower")
	check(not scene.dock.is_open(), "Dropping on an occupied tower does not unexpectedly open a panel")
	await tap(scene.world.cell_screen_position(cell))
	await drag_number(answer, Vector2(8, 8))
	check(scene.run.board[cell] == 0 and scene.run.towers.size() == before, "Dropping outside the board cancels instead of using the previous selection")
	check(not scene.seed_pointer.is_active(), "Outside release does not leave a stuck drag")

	# One finger owns a gesture. A second finger cannot choose, move, or release it.
	start = point_for_number(answer)
	destination = scene.world.cell_screen_position(cell)
	touch(start, true, 0)
	touch_motion(start, destination, 0)
	await frames()
	touch(point_for_number(wrong), true, 1)
	touch_motion(point_for_number(wrong), destination, 1)
	touch(destination, false, 1)
	await frames()
	check(scene.run.board[cell] == 0 and scene.seed_pointer.is_active(), "Second finger cannot finish the first finger's drag")
	touch(destination, false, 0)
	await frames()
	check(scene.run.board[cell] == answer and scene.run.towers.size() == before + 1, "Original finger releases its original number exactly once")

	# Menu opening cancels an in-progress drag. Its release cannot reach the board.
	cell = blank_cell()
	answer = scene.run.solution[cell]
	before = scene.run.towers.size()
	start = point_for_number(answer)
	destination = scene.world.cell_screen_position(cell)
	touch(start, true)
	touch_motion(start, destination)
	await frames()
	scene._show_menu(false)
	await frames()
	touch(destination, false)
	await frames()
	check(scene.menu_open and scene.run.towers.size() == before, "Opening a menu cancels a drag before it can plant")
	check(not scene.seed_pointer.is_active(), "Menu cancellation removes the drag preview")
	await tap(destination)
	check(scene.run.towers.size() == before, "Modal touch never plants behind the overlay")
	scene._close_overlay()
	await frames()

	# Touch and controller can alternate during a run without sharing gestures.
	await tap(scene.world.cell_screen_position(cell))
	start = point_for_number(answer)
	touch(start, true)
	touch_motion(start, destination)
	await frames()
	await press_pad(JOY_BUTTON_RIGHT_SHOULDER)
	check(not scene.seed_pointer.is_active() and scene.run.board[cell] == 0, "Controller input cancels an unfinished touch drag")
	touch(destination, false)
	await frames()
	check(scene.run.board[cell] == 0, "Canceled touch release cannot submit after controller takeover")
	for i in range(9):
		if scene.selected_number == answer: break
		await press_pad(JOY_BUTTON_RIGHT_SHOULDER)
	await press_pad(JOY_BUTTON_A)
	check(scene.run.board[cell] == answer, "Controller A still plants after touch use")

	# Pick locations after each real viewport resize; exercise both tap and drag.
	for window_size in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 800)]:
		root.size = window_size
		await frames(7)
		scene._layout_ui()
		for i in range(30): scene.world.tick(0.05)
		await frames()
		cell = blank_cell()
		answer = scene.run.solution[cell]
		destination = scene.world.cell_screen_position(cell)
		check(scene.board_rect.has_point(destination), "Touchable square stays inside board at %s" % window_size)
		await tap(destination)
		check(scene.selected_cell == cell and scene.run.board[cell] == 0, "Touch selects the rendered cell at %s" % window_size)
		await tap(point_for_number(answer))
		check(scene.run.board[cell] == answer, "Number tap plants after resizing to %s" % window_size)
		cell = blank_cell()
		answer = scene.run.solution[cell]
		await drag_number(answer, scene.world.cell_screen_position(cell))
		check(scene.run.board[cell] == answer, "Seed drag targets the rendered grid at %s" % window_size)
		for entry in [[scene.bag_button,"bag"],[scene.loot_button,"loot"],[scene.hud_nodes.camp,"camp"]]:
			var quick: Button = entry[0]
			var glyph: Control = quick.get_meta("quick_icon")
			await tap(glyph.get_global_rect().get_center())
			check(scene.dock.is_open() and scene.dock.current_panel == entry[1],"Tapping the %s voxel icon opens its panel at %s" % [entry[1],window_size])
			scene.dock.close_panel()
			await frames()

	# Selecting a toolbar number highlights its entire family, even when the
	# selected square is a printed clue and therefore cannot be planted into.
	await tap(scene.world.cell_screen_position(fixed))
	before = scene.run.towers.size()
	await tap(point_for_number(7))
	check(scene.selected_number == 7 and scene.world.selected_number == 7, "Toolbar tap propagates digit 7 to the rendered board's matching highlights")
	await tap(point_for_number(3))
	check(scene.selected_number == 3 and scene.world.selected_number == 3, "Choosing another toolbar digit replaces the matching-number highlight")
	check(scene.run.towers.size() == before and scene.run.board[fixed] == clue, "Changing highlight family never overwrites a printed clue")
	await press_pad(JOY_BUTTON_B)
	check(scene.selected_number == 0 and scene.world.selected_number == 0, "Controller cancel clears the selected-digit highlight after touch use")

	# Activate the visible speed control, then measure actual model clocks with
	# scene processing held so wall-clock frame timing cannot affect the result.
	scene.set_process(false)
	for multiplier in [2.0, 4.0, 1.0, 2.0, 4.0]:
		await click(scene.hud_nodes.speed.get_global_rect().get_center())
		check(scene.game_speed == multiplier and scene.hud_nodes.speed.text == "%dx" % int(multiplier), "Speed button cycles to %dx with an accurate label" % int(multiplier))
	var solve_before: float = scene.run.timer
	scene._process(0.05)
	check(is_equal_approx(solve_before - scene.run.timer, 0.05), "4x battle speed leaves the Sudoku countdown at normal speed")

	# Battle preserves deliberate illegal emergency seeds and charges once.
	scene.run.advance_phase()
	scene.run.advance_phase()
	scene.last_phase = "battle"
	var battle_before: float = scene.run.battle_time
	scene.run.active_effects.append({"id":"speed-test", "kind":"haste", "name":"Test haste", "remaining":2.0, "duration":2.0})
	scene._process(0.05)
	check(is_equal_approx(scene.run.battle_time - battle_before, 0.2), "4x speed advances combat by four times the elapsed time")
	check(is_equal_approx(float(scene.run.active_effects[0].remaining), 1.8), "Temporary combat effects use the same accelerated battle clock")
	scene.game_speed = 1.0
	scene.set_process(true)
	for i in range(40): scene.world.tick(0.05)
	cell = blank_cell()
	wrong = int(scene.run.solution[cell]) % 9 + 1
	scene.run.inventory[wrong] = 2
	var reserves: int = scene.run.inventory[wrong]
	var corruption: int = scene.run.corruption
	await drag_number(wrong, scene.world.cell_screen_position(cell))
	check(scene.run.towers.has(cell) and scene.run.board[cell] == wrong, "Touch drag accepts an illegal emergency seed during defense")
	check(scene.run.inventory[wrong] == reserves - 1 and scene.run.corruption == corruption + 1, "Emergency drag consumes one reserve and adds corruption once")

	# Complete-family buttons are a per-board progress cue, not disabled input.
	# Start a fresh puzzle so this fixture counts both printed clues and answers.
	scene.set_process(false)
	scene.run.new_run(54321,{"mode":"campaign","puzzle_difficulty":"medium","combat_difficulty":"easy"})
	scene.dock.close_panel()
	scene.manual_pause = false
	scene.selected_cell = -1
	scene.selected_number = 0
	scene.world.setup(scene.run)
	scene.world.set_selected(-1,0)
	var planted_nine: int = -1
	var clue_nines: int = 0
	for index in range(81):
		if scene.run.solution[index] != 9: continue
		if scene.run.givens[index]: clue_nines += 1
		else:
			planted_nine = index
			check(scene.run.place(index,9).ok,"Completion fixture plants a correct 9")
	for i in range(40): scene.world.tick(0.05)
	scene._refresh()
	await frames()
	var nine: Button = scene.number_buttons[8]
	check(clue_nines > 0 and planted_nine >= 0,"Completion counts include a mixture of printed clues and planted towers")
	check(scene._number_complete(9) and nine.get_theme_color("font_color") == Color("82939a"),"All nine correct copies gray the corresponding toolbar digit")
	check(not nine.disabled and nine.tooltip_text.begins_with("9 / 9 complete"),"Completed digit stays selectable and explains its completed status")
	cell = blank_cell()
	await tap(scene.world.cell_screen_position(cell))
	scene.run.drain_events()
	var combo_before: int = scene.run.combo
	before = scene.run.towers.size()
	await tap(point_for_number(9))
	check(scene.selected_number == 9 and scene.world.selected_number == 9,"Tapping a completed digit still highlights matching numbers")
	check(scene.run.board[cell] == 0 and scene.run.combo == combo_before and scene.run.drain_events().is_empty(),"Selecting a completed digit over an empty solve square does not attempt an invalid answer")
	start = point_for_number(9)
	destination = scene.world.cell_screen_position(cell)
	touch(start,true)
	touch_motion(start,destination)
	await frames()
	check(scene.seed_pointer._hint.text == "ALL 9 COMPLETE" and scene.seed_pointer.hover_cell == -1,"Dragging a completed solve digit explains completion without offering a false drop target")
	touch(destination,false)
	await frames()
	check(scene.run.towers.size() == before and scene.run.board[cell] == 0,"Completed solve digit cannot be planted through drag")

	# Nine visible 9s are insufficient if one is an illegal emergency duplicate.
	scene.run.board[planted_nine] = 0
	scene.run.towers.erase(planted_nine)
	scene.run.phase = "battle"
	scene.run.inventory[9] = 3
	check(scene.run.place(cell,9).ok,"Completion fixture can place an illegal emergency 9")
	scene._refresh()
	check(not scene._number_complete(9) and nine.get_theme_color("font_color") == scene.COLORS[8],"An illegal duplicate does not count toward completion or gray the digit")
	check(scene.run.place(planted_nine,9).ok,"Restoring the missing correct 9 completes its family again")
	scene._refresh()
	cell = blank_cell()
	reserves = scene.run.inventory[9]
	for i in range(40): scene.world.tick(0.05)
	await drag_number(9,scene.world.cell_screen_position(cell))
	check(scene._number_complete(9) and scene.run.board[cell] == 9 and scene.run.inventory[9] == reserves-1,"Completed families can still spend a reserve on an emergency battle tower")

	# Going to the next campaign puzzle recalculates counts rather than keeping
	# a cached completed-family flag from the previous grid.
	scene.run.phase = "loot"
	check(scene.run.next_round().ok,"Completion fixture advances to another campaign puzzle")
	scene.selected_cell = -1
	scene.world.setup(scene.run)
	scene._refresh()
	check(not scene._number_complete(9) and nine.get_theme_color("font_color") == scene.COLORS[8],"Next puzzle restores a completed digit's normal color")
	check(not nine.tooltip_text.begins_with("9 / 9 complete"),"Next puzzle clears the previous completion tooltip")

	scene.queue_free()
	await frames()
	print("TOUCH_FLOW_CHECKS: %d assertions, %d failures" % [checks, failures])
	print("TOUCH_FLOW_PASS" if failures == 0 else "TOUCH_FLOW_FAIL")
	quit(1 if failures else 0)
