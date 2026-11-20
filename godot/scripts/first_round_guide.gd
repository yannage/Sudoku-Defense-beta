extends RefCounted
## A guided practice round uses the real simulation and input paths. Its state
## never replaces a player's run file, and leaving restores the in-memory run.
var host
var active := false
var step := -1
var reward_opened := false
var previous: Dictionary = {}
var previous_active := false
var previous_speed := 1.0
var previous_pause := false
var previous_reserve_mode := false
var previous_cell := -1
var previous_number := 0
var target_cell := -1
var reward_ready := false
var played_this_session := false
var marker: Control

# One stationary outline follows the actual projected square and HUD control.
# It ignores input so mouse, touch and controller all use the normal game.
class GuideMarker extends Control:
	var guide

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		z_index = 11

	func _draw() -> void:
		var game = guide.host
		if game.menu_open or game.camera_mode: return
		if game.dock.is_open():
			# The workshop already identifies the first free socket and the
			# first fitting module. Outline it only while inside the scroll view.
			var target: Control = game.dock._focus_target
			if guide.step == 3 and is_instance_valid(target) and target.is_visible_in_tree():
				var id := str(target.get_meta("focus_id",""))
				var scroll: ScrollContainer = game.dock._scroll
				if (id.begins_with("slot:") or id.begins_with("item:")) and is_instance_valid(scroll):
					var bounds := target.get_global_rect()
					if scroll.get_global_rect().encloses(bounds):
						draw_rect(bounds.grow(-2.0),game.AMBER,false,3.0)
			return
		var cell: int = guide.target_cell
		if cell >= 0 and guide.step in [0, 1, 3]:
			var shape: PackedVector2Array = game.wrong_guess_feedback._cell_shape(cell)
			shape.append(shape[0])
			draw_polyline(shape, Color("102328"), 6.0, true)
			draw_polyline(shape, game.AMBER, 3.0, true)
		var button: Button = null
		if guide.step in [0, 1] and cell >= 0 and game.selected_cell == cell:
			button = game.number_buttons[int(game.run.solution[cell]) - 1]
		elif guide.step in [2, 4, 7] or (guide.step == 3 and cell < 0):
			button = game.next_button
		elif guide.step == 6:
			button = game.loot_button
		if button != null and button.is_visible_in_tree():
			draw_rect(button.get_global_rect().grow(2.0), game.AMBER, false, 3.0)

func start(game) -> void:
	if active:
		show_step()
		return
	host = game
	previous_active = host.has_active_run
	previous = host.run.save_data().duplicate(true) if previous_active else {}
	previous_speed = host.game_speed
	previous_pause = host.manual_pause
	previous_reserve_mode = host.reserve_mode
	previous_cell = host.selected_cell
	previous_number = host.selected_number
	active = true
	played_this_session = true
	step = -1
	reward_opened = false
	reward_ready = false
	host.run.new_run(784217,{"mode":"campaign","puzzle_difficulty":"easy","combat_difficulty":"easy","solve_pace":"untimed"})
	host._clear_wrong_guess_feedback()
	host.has_active_run = true
	host.game_speed = 1.0
	host.manual_pause = false
	host.reserve_mode = false
	host.armed_item = ""
	host.selected_number = 0
	host.dock.reset_for_run()
	host.world.setup(host.run)
	host.last_phase = host.run.phase
	if not is_instance_valid(marker):
		marker = GuideMarker.new()
		marker.guide = self
		host.ui.add_child(marker)
		marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marker.show()
	target_cell = next_blank()
	host._select(target_cell,false,false)
	host._close_overlay()
	observe()

func next_blank() -> int:
	# A single candidate can be deduced immediately. For the route lesson,
	# favor another three-row band so the second placement shows a new bend.
	var first: int = -1 if host.run.recent_moves.is_empty() else int(host.run.recent_moves[0])
	var best := -1
	var best_score := -1
	for cell in range(81):
		if host.run.board[cell] != 0: continue
		var score: int = 100 if host.run.candidates(cell).size() == 1 else 0
		if first >= 0:
			if cell / 27 != first / 27: score += 30
			score -= absi(cell % 9 - first % 9) + absi(cell / 9 - first / 9)
		else:
			score -= absi(cell % 9 - 4) + absi(cell / 9 - 4)
		if score > best_score or best < 0:
			best = cell
			best_score = score
	return best

func observe() -> void:
	if not active: return
	marker.queue_redraw()
	var next := step
	match host.run.phase:
		"solve": next = mini(host.run.towers.size(), 2)
		"prep":
			next = 3
			for tower: Dictionary in host.run.towers.values():
				if not tower.attachments.is_empty(): next = 4
		"battle": next = 5
		"loot", "won":
			if not reward_ready:
				var cheapest := 9999
				for chest: Dictionary in host.run.chests: cheapest = mini(cheapest,int(chest.cost))
				if cheapest == 9999:
					var chest: Dictionary = host.run._add_chest("common")
					cheapest = int(chest.cost)
				host.run.fragments = maxi(host.run.fragments,cheapest)
				reward_ready = true
			next = 7 if reward_opened else 6
		"lost": next = 8
	if next == step: return
	step = next
	match step:
		1:
			target_cell = next_blank()
			# Leave the player's focus on the newly grown tower. Clear the seed
			# brush so clicking the next highlighted square safely selects it.
			host.selected_number = 0
			host.world.set_selected(host.selected_cell,0)
		3:
			target_cell = int(host.run.recent_moves.back()) if not host.run.recent_moves.is_empty() else -1
			if target_cell >= 0: host._select(target_cell,false,false)
		2, 4, 5, 6, 7, 8: target_cell = -1
	host._refresh()

func event_seen(event: Dictionary) -> void:
	if active and host.run.phase in ["loot","won"] and str(event.get("type","")) == "chest_open": reward_opened = true

func needs_module() -> bool:
	return not host.run.towers.is_empty() and host.run.items.any(func(item): return str(item.get("type","")) == "attachment")

func can_advance() -> bool:
	if not active: return true
	observe()
	if step in [7,8]:
		finish()
		return false
	if step in [0,1,6] or (step == 3 and needs_module()):
		host._toast(instruction(),false)
		return false
	return true

func instruction() -> String:
	match step:
		0, 1:
			if target_cell < 0: return "Plant an answer in an empty square."
			var spot := "R%d C%d" % [target_cell / 9 + 1, target_cell % 9 + 1]
			var digit: int = host.run.solution[target_cell]
			if host.selected_cell != target_cell:
				return ("Your first answer grew a tower! " if step == 1 else "") + "Select the gold square at %s." % spot
			var clue := "Try %d in %s." % [digit,spot]
			if host.run.candidates(target_cell).size() == 1:
				clue = "This row, column and box leave only %d." % digit
			if host.controller_used and not host._controller_pointer_active():
				return clue + host._controller_hint(" Press A to open numbers." if host._controller_number_cell < 0 else " Choose %d, then press A." % digit)
			return clue + " Pick %d below to grow a tower." % digit
		2: return "Your latest answer bent the gold route. Plant more, or choose Prepare defense to lock it."
		3:
			if not needs_module(): return "No spare modules to fit. Launch the wave."
			if host.dock.is_open():
				if host.dock.current_panel == "tower": return "Pick an empty + socket on this tower."
				if host.dock.current_panel == "bag":
					if host.dock.controller_picker_slot >= 0: return "Choose a module to fit in the socket."
					return "Choose a module and use Install selected, or open a tower's + socket."
				return "Close the panel and select a planted tower."
			return host._controller_hint("Select the marked tower. Press A to open its sockets.") if host.controller_used else "Select the marked tower to open its five sockets."
		4:
			if host.dock.is_open(): return host._controller_hint("Module fitted. Press B to close the workshop.") if host.controller_used else "Module fitted. Close the workshop to see the route."
			return "Follow the gold line from entry to exit. Launch the wave when ready."
		5: return "Towers fire at enemies in range. Any that reach the exit damage your core."
		6: return "Wave cleared! Open Chests and spend fragments on a reward."
		7: return "Reward collected. Close Chests and choose Finish guide."
		8: return "Your core fell. Choose Finish guide to leave practice."
	return ""

func optional_tools() -> Array:
	return [host.hud_nodes.camp, host.hud_nodes.tools, host.hud_nodes.camera, host.hud_nodes.camera_reset,
		host.hud_nodes.notes, host.hud_nodes.hint, host.reserve_button]

func apply_hud() -> void:
	if not active or step < 0: return
	host.hud_nodes.help.tooltip_text = "Current guide step / skip practice"
	host.phase_label.text = ["FIRST SEED","SECOND SEED","PLAN THE ROUTE","FIT A MODULE","LAUNCH WAVE","DEFEND","OPEN A CHEST","ROUND CLEAR","CORE LOST"][step]
	# Introduce the controls used in this lesson as their actions become
	# available. Help, pause, and the run menu stay within reach throughout.
	for tool: Control in optional_tools(): tool.hide()
	host.bag_button.visible = step in [3,4,5]
	host.loot_button.visible = step in [6,7]
	host.hud_nodes.speed.visible = step == 5
	host.next_button.visible = step in [2,4,7,8] or (step == 3 and not needs_module())
	if step in [0,1] and host.selected_cell >= 0 and host.run.board[host.selected_cell] == 0:
		var options: Array = host.run.candidates(host.selected_cell)
		host.candidate_label.text = "Possible numbers   " + "  ".join(options.map(func(n): return str(n)))
	host.phase_detail.text = instruction()
	host.phase_detail.show()
	host.phase_label.visible = not host.portrait_layout
	# In portrait the two ordinary phase labels share a narrow row. Give its
	# whole width to the instruction, keeping the board and touch tray clear.
	if host.portrait_layout:
		host.hud_nodes.intel.hide()
		host._font(host.phase_detail,20)
		host._place(host.phase_detail,Rect2(20,147,host.layout_size.x-40,57))
	elif step in [3,4]:
		host.phase_detail.size.y = 77
	if step in [7,8]: host.next_button.text = "Finish guide"

# Help is available on demand. Advancing the lesson never opens an overlay.
func show_step() -> void:
	if not active: return
	var box: VBoxContainer = host._modal(565,360)
	host.overlay.set_meta("first_round_guide",true)
	box.add_child(host.label("GUIDED FIRST ROUND",14,host.MINT))
	box.add_child(host.label(instruction(),23,host.WHITE))
	if step in [0,1]:
		box.add_child(host.label("Each row, column and 3×3 box uses the numbers 1–9 once. Every correct answer grows a tower.",16,host.MUTED))
	box.add_child(host.label("Practice has no solve timer. You can leave at any time.",16,host.MUTED))
	var primary: Button = host.button("Finish guide" if step in [7,8] else "Back to board",finish if step in [7,8] else continue_step,true)
	primary.set_meta("focus_id","guide:continue")
	box.add_child(primary)
	if step not in [7,8]:
		var skip: Button = host.button("Skip guide / return",finish)
		skip.set_meta("focus_id","guide:skip")
		box.add_child(skip)
	primary.grab_focus()

func continue_step() -> void:
	if active and host.menu_open: host._close_overlay()

func restore() -> void:
	if not active: return
	active = false
	if is_instance_valid(marker): marker.hide()
	for tool: Control in optional_tools() + [host.bag_button, host.loot_button, host.next_button, host.hud_nodes.speed]: tool.show()
	host.phase_label.show()
	host.hud_nodes.help.tooltip_text = "How to play / controller controls"
	host._clear_wrong_guess_feedback()
	host._close_controller_numbers()
	host.dock.reset_for_run()
	if previous_active: host.run.load_data(previous)
	else: host.run.new_run(784217,{"mode":"campaign","puzzle_difficulty":"easy","combat_difficulty":"easy"})
	host.has_active_run = previous_active
	host.game_speed = previous_speed
	host.manual_pause = previous_pause
	host.reserve_mode = previous_reserve_mode
	host.selected_cell = previous_cell
	host.selected_number = previous_number
	host.armed_item = ""
	host.world.setup(host.run)
	host.world.set_selected(previous_cell,previous_number)
	host.last_phase = host.run.phase
	host.save_elapsed = 0
	previous.clear()
	host._layout_ui()

func finish() -> void:
	if not active: return
	restore()
	if previous_active: host._close_overlay()
	else: host._show_menu(true)
	host._toast("Practice finished. Welcome back." if previous_active else "Practice finished. Choose your own run.")
