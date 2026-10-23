extends SceneTree
## Exercises native joypad events through the real main scene. It does not map
## controller inputs to keyboard/mouse events or call gameplay action callbacks.
## Run both normally and with --canvas-graphics to cover the browser view too.

const DEVICE: int = 42
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

func send_button(index: int, pressed: bool, device: int = DEVICE) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)

func press(index: int, device: int = DEVICE) -> void:
	send_button(index, true, device)
	await frames(1)
	send_button(index, false, device)
	await frames()

func motion(axis: int, value: float, device: int = DEVICE) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	await frames()

func button_by_text(scope: Node, prefix: String) -> Button:
	for node in scope.find_children("*", "Button", true, false):
		if node.is_visible_in_tree() and str(node.text).begins_with(prefix): return node
	return null

func button_by_id(scope: Node, id: String) -> Button:
	for node in scope.find_children("*", "Button", true, false):
		if node.is_visible_in_tree() and str(node.get_meta("focus_id", "")) == id: return node
	return null

func activate_text(scope: Node, prefix: String) -> void:
	var target: Button = button_by_text(scope, prefix)
	check(is_instance_valid(target), "Controller can find action: " + prefix)
	if not is_instance_valid(target): return
	check(not target.disabled and target.focus_mode == Control.FOCUS_ALL, "Action accepts controller focus: " + prefix)
	target.grab_focus()
	await frames()
	await press(JOY_BUTTON_A)

func move_to(cell: int) -> void:
	if scene.selected_cell < 0: await press(JOY_BUTTON_DPAD_RIGHT)
	for i in range(18):
		if scene.selected_cell == cell: break
		if scene.selected_cell % 9 < cell % 9: await press(JOY_BUTTON_DPAD_RIGHT)
		elif scene.selected_cell % 9 > cell % 9: await press(JOY_BUTTON_DPAD_LEFT)
		elif scene.selected_cell / 9 < cell / 9: await press(JOY_BUTTON_DPAD_DOWN)
		else: await press(JOY_BUTTON_DPAD_UP)
	check(scene.selected_cell == cell, "D-pad reaches requested board square %d" % cell)

func choose_number(number: int) -> void:
	for i in range(9):
		if scene.selected_number == number: break
		await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(scene.selected_number == number, "Shoulders select number %d" % number)

func arm_first_module() -> String:
	await press(JOY_BUTTON_X)
	check(scene.dock.is_open() and scene.dock.current_panel == "bag", "X opens gear")
	var item_id: String = ""
	for item in scene.run.items:
		if str(item.type) == "attachment": item_id = str(item.id); break
	var card: Button = button_by_id(scene.dock, "item:" + item_id)
	check(not item_id.is_empty() and is_instance_valid(card), "Inventory module has a stable focus target")
	if is_instance_valid(card):
		for i in range(12):
			if root.gui_get_focus_owner() == card: break
			await press(JOY_BUTTON_DPAD_DOWN)
		check(root.gui_get_focus_owner() == card, "D-pad reaches the first module from the inventory tab")
		# Keep later checks useful if a navigation regression fails this assertion.
		if root.gui_get_focus_owner() != card: card.grab_focus()
		await frames()
		await press(JOY_BUTTON_A)
	check(scene.armed_item == item_id and not scene.dock.is_open(), "A selects module and returns to the board for targeting")
	var targeting_timer: float = scene.run.timer
	await create_timer(0.12).timeout
	check(scene.run.timer == targeting_timer, "Choosing a controller attachment target holds the solve clock")
	return item_id

func exercise() -> void:
	root.size = Vector2i(1280, 800)
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await frames(5)
	scene.muted = true
	scene.sound.set_muted(true)
	check(scene.menu_open and not scene.has_active_run, "Launch starts in the controller-accessible menu")
	if "--canvas-graphics" in OS.get_cmdline_user_args():
		check(root.disable_3d and scene.world is Node2D, "Controller test covers compatible browser board")
	# Navigate a real row with D-pad and activate the focused choice with A.
	var campaign: Button = button_by_text(scene.overlay, "Campaign")
	check(is_instance_valid(campaign), "Campaign choice exists")
	if is_instance_valid(campaign): campaign.grab_focus()
	await press(JOY_BUTTON_DPAD_RIGHT)
	var choice: Control = root.gui_get_focus_owner()
	check(choice is Button and str(choice.text).begins_with("Free play"), "D-pad moves menu focus to the next expedition")
	await press(JOY_BUTTON_A)
	check(scene.mode_choice == "freeplay", "A activates the focused mode choice")
	await press(JOY_BUTTON_DPAD_LEFT)
	await press(JOY_BUTTON_A)
	check(scene.mode_choice == "campaign", "Menu navigation returns to campaign")
	check(scene.selected_cell == -1, "Menu D-pad navigation never moves the background board")
	# Optional seeded runs also work without opening a physical keyboard.
	await activate_text(scene.overlay, "Keypad")
	check(scene._seed_editing, "Controller opens the seed keypad")
	await activate_text(scene.overlay, "Clear")
	await activate_text(scene.overlay, "1")
	await press(JOY_BUTTON_DPAD_RIGHT)
	await press(JOY_BUTTON_A)
	await press(JOY_BUTTON_DPAD_RIGHT)
	await press(JOY_BUTTON_A)
	await press(JOY_BUTTON_DPAD_DOWN)
	await press(JOY_BUTTON_DPAD_LEFT)
	await press(JOY_BUTTON_DPAD_LEFT)
	await press(JOY_BUTTON_A)
	await press(JOY_BUTTON_DPAD_RIGHT)
	await press(JOY_BUTTON_A)
	check(scene._seed_text == "12345", "D-pad and A enter digits on the three-column seed keypad")
	await activate_text(scene.overlay, "Delete")
	check(scene._seed_text == "1234", "Controller can delete the last seed digit")
	await activate_text(scene.overlay, "5")
	await press(JOY_BUTTON_B)
	check(scene.menu_open and not scene._seed_editing and scene.seed_input.text == "12345", "B returns from keypad to setup without starting a run")
	await activate_text(scene.overlay, "Keypad")
	await activate_text(scene.overlay, "Use seed")
	check(scene.seed_input.text == "12345", "A confirms the controller-entered run seed")
	await activate_text(scene.overlay, "Start expedition")
	check(not scene.menu_open and scene.has_active_run, "A launches a native controller run")
	check(scene.run.seed_value == 12345, "Menu seed is retained")
	check(scene.controller_used, "Native joypad events switch to controller prompts")
	# Stick drift is ignored; a deliberate direction moves immediately and repeats.
	await move_to(40)
	await motion(JOY_AXIS_LEFT_X, 0.18)
	await create_timer(0.25).timeout
	check(scene.selected_cell == 40, "Stick deadzone prevents accidental selection drift")
	await motion(JOY_AXIS_LEFT_X, 0.90)
	var first_stick_cell: int = scene.selected_cell
	check(first_stick_cell == 41, "Left stick makes one immediate directional step")
	await create_timer(0.58).timeout
	check(scene.selected_cell > first_stick_cell and scene.selected_cell <= 44, "Held stick repeats at a controlled pace")
	await motion(JOY_AXIS_LEFT_X, 0.0)
	var stopped_cell: int = scene.selected_cell
	await create_timer(0.30).timeout
	check(scene.selected_cell == stopped_cell, "Releasing the stick stops repeat movement")
	var cells: Array[int] = []
	for cell in range(81):
		if scene.run.board[cell] == 0 and cells.size() < 3: cells.append(cell)
	check(cells.size() == 3, "Fixture has unfilled Sudoku squares")
	for index in range(2):
		var cell: int = cells[index]
		await move_to(cell)
		await choose_number(int(scene.run.solution[cell]))
		check(scene.run.board[cell] == 0, "Cycling numbers does not plant before A")
		await press(JOY_BUTTON_A)
		check(scene.run.towers.has(cell), "A plants the chosen correct answer")
	# Inventory selection uses a confirmable board target, not a drag requirement.
	var item_count: int = scene.run.items.size()
	var first_item: String = await arm_first_module()
	await move_to(cells[0])
	check(scene.run.items.size() == item_count and scene.run.towers[cells[0]].attachments.is_empty(), "Moving the target never equips automatically")
	await press(JOY_BUTTON_A)
	check(scene.run.towers[cells[0]].attachments.size() == 1, "A confirms the target and equips exactly one module")
	check(str(scene.run.towers[cells[0]].attachments[0].id) == first_item, "Confirmed attachment is the selected inventory item")
	check(scene.run.items.size() == item_count - 1 and scene.armed_item.is_empty(), "Successful equip consumes one item and clears targeting")
	var canceled_item: String = await arm_first_module()
	var before_cancel: int = scene.run.items.size()
	await press(JOY_BUTTON_B)
	check(scene.armed_item.is_empty() and scene.run.items.size() == before_cancel, "B cancels targeting without consuming gear")
	check(scene.run.items.any(func(item): return str(item.id) == canceled_item), "Canceled module remains in inventory")
	# All workshop purchases are activated by native A, including refreshed focus.
	scene.run.credits = 1000
	await move_to(cells[0])
	await press(JOY_BUTTON_A)
	check(scene.dock.is_open() and scene.dock.current_panel == "tower", "A on a tower opens the workshop")
	var level_before: int = scene.run.towers[cells[0]].level
	await activate_text(scene.dock, "Upgrade this tower")
	check(scene.run.towers[cells[0]].level == level_before + 1, "Controller purchases one tower upgrade")
	var focused: Control = root.gui_get_focus_owner()
	check(focused is Button and str(focused.text).begins_with("Upgrade this tower"), "Upgrade focus survives its changing price label")
	await press(JOY_BUTTON_A)
	check(scene.run.towers[cells[0]].level == level_before + 2, "Repeated A upgrades exactly once after workshop refresh")
	var family: int = scene.run.towers[cells[0]].number
	var family_before: int = scene.run.family_levels[family]
	await activate_text(scene.dock, "Upgrade all")
	check(scene.run.family_levels[family] == family_before + 1, "Controller purchases the entire number-family upgrade")
	var mini_target: Button = button_by_id(scene.dock, "cell:" + str(cells[1]))
	check(is_instance_valid(mini_target), "Workshop mini-grid exposes planted towers to focus")
	if is_instance_valid(mini_target):
		mini_target.grab_focus()
		await frames(5)
		check(scene.dock._scroll.get_global_rect().grow(1.0).encloses(mini_target.get_global_rect()), "Workshop scroll follows controller focus to the mini-grid")
		await press(JOY_BUTTON_A)
		check(scene.selected_cell == cells[1], "A selects another tower through the workshop mini-grid")
	var selected_before: int = scene.selected_cell
	var number_before: int = scene.selected_number
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(scene.dock.current_panel == "bag", "RB cycles workshop to bag")
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(scene.dock.current_panel == "loot", "RB cycles bag to loot")
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(scene.dock.current_panel == "camp", "RB cycles loot to camp")
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(scene.dock.current_panel == "tower", "RB wraps back to workshop")
	await press(JOY_BUTTON_LEFT_SHOULDER)
	check(scene.dock.current_panel == "camp", "LB cycles management tabs backwards")
	check(scene.selected_cell == selected_before and scene.selected_number == number_before, "Management shoulder navigation never changes board selection")
	await press(JOY_BUTTON_B)
	check(not scene.dock.is_open(), "B closes the management panel")
	await press(JOY_BUTTON_START)
	check(scene.menu_open, "Start opens a pause menu")
	check(root.gui_get_focus_owner() is Button and root.gui_get_focus_owner().text == "Resume run", "Pause menu defaults to Resume, never a destructive new run")
	var timer_before: float = scene.run.timer
	await create_timer(0.12).timeout
	check(scene.run.timer == timer_before, "Pause menu holds the solve clock")
	await press(JOY_BUTTON_Y)
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(scene.run.phase == "solve" and scene.selected_number == number_before, "Menu blocks background phase and number shortcuts")
	await press(JOY_BUTTON_START)
	check(not scene.menu_open, "Start resumes the active run")
	await press(JOY_BUTTON_Y)
	check(scene.run.phase == "prep", "Y advances from solve into war preparation")
	await press(JOY_BUTTON_Y)
	check(scene.run.phase == "battle", "Y launches the defense wave")
	await press(JOY_BUTTON_X)
	check(scene.dock.is_open(), "Controller can inspect inventory during combat")
	var battle_before: float = scene.run.battle_time
	await create_timer(0.12).timeout
	check(scene.run.battle_time == battle_before, "Inventory pauses combat for controller management")
	var consumable: Dictionary = {}
	for item in scene.run.items:
		if str(item.type) == "consumable": consumable = item; break
	check(not consumable.is_empty(), "Run supplies a quick-use item for controller testing")
	if not consumable.is_empty():
		var consumable_card: Button = button_by_id(scene.dock, "item:" + str(consumable.id))
		check(is_instance_valid(consumable_card), "Consumable is a controller-focusable inventory action")
		if is_instance_valid(consumable_card):
			consumable_card.grab_focus()
			await frames()
			await press(JOY_BUTTON_A)
			check(not scene.run.items.any(func(item): return str(item.id) == str(consumable.id)), "A uses exactly the focused temporary item")
	await press(JOY_BUTTON_B)
	await create_timer(0.12).timeout
	check(scene.run.battle_time > battle_before, "Closing inventory resumes combat")
	# Hotplug signal fixture: device loss must not leave the timer running or
	# retained stick repeat active. The next pad's native events can resume play.
	var controller = scene.get("controller")
	check(is_instance_valid(controller), "Native controller router remains available after gameplay")
	if is_instance_valid(controller):
		controller._connection_changed(DEVICE, false)
		await frames()
		check(scene.menu_open, "Disconnecting the active controller pauses the run")
		controller._connection_changed(DEVICE + 1, true)
		await press(JOY_BUTTON_START, DEVICE + 1)
		check(not scene.menu_open, "A reconnected controller can resume the run")
		check(controller.active_device == DEVICE + 1, "Input ownership follows the reconnected controller")
	# Enter a completed-wave fixture; interact with loot and the next-round UI
	# exclusively through native joypad events rather than simulating 50 battles.
	scene.run.phase = "loot"
	scene.run.fragments = 100
	var chest: Dictionary = scene.run._add_chest("common")
	await frames(5)
	check(scene.dock.is_open() and scene.dock.current_panel == "loot", "Completed wave opens controller-accessible loot")
	var chests_before: int = scene.run.chests.size()
	var fragments_before: int = scene.run.fragments
	await activate_text(scene.dock, "Crack it open")
	check(scene.run.chests.size() == chests_before - 1 and scene.run.fragments == fragments_before - int(chest.cost), "A opens a chest and spends its fragment cost once")
	await press(JOY_BUTTON_B)
	await press(JOY_BUTTON_Y)
	check(scene.menu_open, "Y opens the next-round difficulty selection")
	await activate_text(scene.overlay, "Medium")
	check(scene.puzzle_choice == "medium", "A changes next-round Sudoku difficulty")
	await activate_text(scene.overlay, "Plant the next garden")
	check(scene.run.round_no == 2 and scene.run.phase == "solve" and not scene.menu_open, "Controller completes the loop into a new Sudoku round")
	check(scene.run.puzzle_difficulty == "medium", "Chosen next-round difficulty is applied")
	scene.queue_free()
	await frames()
	print("CONTROLLER_FLOW_CHECKS: %d assertions, %d failures" % [checks, failures])
	print("CONTROLLER_FLOW_PASS" if failures == 0 else "CONTROLLER_FLOW_FAIL")
	quit(1 if failures else 0)
