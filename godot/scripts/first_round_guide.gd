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
var previous_cell := -1
var previous_number := 0
var target_cell := -1
var reward_ready := false

func start(game) -> void:
	if active:
		show_step()
		return
	host = game
	previous_active = host.has_active_run
	previous = host.run.save_data().duplicate(true) if previous_active else {}
	previous_speed = host.game_speed
	previous_pause = host.manual_pause
	previous_cell = host.selected_cell
	previous_number = host.selected_number
	active = true
	step = -1
	reward_opened = false
	reward_ready = false
	host.run.new_run(784217,{"mode":"campaign","puzzle_difficulty":"easy","combat_difficulty":"easy"})
	host._clear_wrong_guess_feedback()
	host.has_active_run = true
	host.game_speed = 1.0
	host.manual_pause = false
	host.armed_item = ""
	host.selected_number = 0
	host.dock.reset_for_run()
	host.world.setup(host.run)
	host.last_phase = host.run.phase
	target_cell = next_blank()
	host._select(target_cell,false,false)
	host._close_overlay()
	observe()

func next_blank() -> int:
	for cell in range(81):
		if host.run.board[cell] == 0: return cell
	return -1

func observe() -> void:
	if not active: return
	var next := step
	match host.run.phase:
		"solve": next = 0 if host.run.towers.is_empty() else (1 if host.run.towers.size() < 6 else 2)
		"prep":
			next = 3
			for tower: Dictionary in host.run.towers.values():
				if not tower.attachments.is_empty(): next = 4
		"battle": next = 5
		"loot", "won":
			if not reward_ready:
				# A practice chest is guaranteed even if the player leaked enemies.
				# It is explicitly practice-only and cannot enter the saved campaign.
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
	if step == 1: target_cell = next_blank()
	# Let a chest reveal finish before the player opens the completion card.
	if step == 7:
		host._toast("Guide complete! Close Chests, then press Y / Next to finish.")
	else: show_step.call_deferred()

func event_seen(event: Dictionary) -> void:
	if active and host.run.phase in ["loot","won"] and str(event.get("type","")) == "chest_open": reward_opened = true

func can_advance() -> bool:
	if not active: return true
	observe()
	# Wrong guesses can exhaust practice Solve before any tower exists. Keep
	# the normal phase path available instead of requiring impossible equipment.
	if host.run.phase == "prep" and host.run.towers.is_empty(): return true
	if (host.run.phase == "solve" and host.run.towers.size() < 6) or (host.run.phase == "prep" and step < 4) or host.run.phase in ["loot","won","lost"]:
		show_step()
		return false
	return true

func apply_hud() -> void:
	if not active: return
	host.phase_label.text = "GUIDE %d / 7" % mini(step+1,7)
	host.hud_nodes.help.text = "?"
	host.hud_nodes.help.tooltip_text = "Current guide step / skip practice"
	if not host.portrait_layout:
		var hints := ["Plant the highlighted answer. Help reopens this step.","Plant six towers. Recent answers shape the route.","Ready: prepare now. The whole Sudoku is optional.","Open Gear. Select a module, then a planted tower.","Gear fitted! Read Wave intel, then launch.","Watch the route and towers. Gear panels pause battle.","Open Chests and claim a practice reward.","Reward collected! Press Next to finish.","Try another defense, or leave practice."]
		host.phase_detail.text = hints[clampi(step,0,8)]
		if step == 3 and host.run.towers.is_empty(): host.phase_detail.text = "No towers planted. Launch the wave or use Help to return."
	if step == 7: host.next_button.text = "Finish guide"

func show_step() -> void:
	if not active: return
	var box: VBoxContainer = host._modal(650,590)
	host.overlay.set_meta("first_round_guide",true)
	var titles := ["Plant your first tower","Shape the route","You can battle before finishing","Fit your first module","Launch your defense","Watch your defense work","Claim your reward","You know the loop","A defense to learn from"]
	var empty_defense: bool = host.run.towers.is_empty()
	if empty_defense:
		titles[3] = "Solve time ran out"
		titles[7] = "Practice round finished"
	box.add_child(host.label("GUIDED FIRST ROUND / PRACTICE",13,host.MINT))
	box.add_child(host.label(titles[clampi(step,0,8)],27,host.WHITE))
	var cell: int = target_cell if target_cell >= 0 else next_blank()
	var placement := ""
	if cell >= 0:
		placement = "Try row %d, column %d: its answer is %d. " % [cell/9+1,cell%9+1,host.run.solution[cell]]
	var descriptions := [
		placement+"Select the highlighted square, then its number below. On controller: A opens the number tray; choose the number and press A to plant and return. Each row, column and 3x3 box uses 1-9 once. The clock is paused while you learn; wrong answers still cost 5 seconds.",
		"That answer became a tower and earned credits. Plant five more answers. "+placement+"The last answers you place pull the enemy route toward them when you prepare. Spread towers around the route so enemies stay in range. Help reopens this guide at any time.",
		"Six towers are enough to try the first easy wave. You do NOT need to finish the Sudoku. Press Prepare defense (Y on controller). Watch the route change around your recent answers; numbers become firing towers.",
		"Open Gear (X), choose an Attack or Support module, then select a planted tower and confirm. Every tower has five sockets. Try Rapid, Lightning or Frost from your starting bag. Equipping changes that tower; number-family upgrades help all planted towers with that number.",
		"Your first module is fitted. Open Wave intel if you want to inspect health, speed and core damage. Launch the wave with the main button or Y. Towers fire automatically; enemies reaching the exit damage your core.",
		"Follow the enemies along the route. Watch where towers can reach them. Gear and menus pause the battle so you can inspect safely. During battle, reserve seeds add towers; wrong numbers increase corruption and enemy health. Close this card to let the wave run.",
		"You cleared the wave and earned credits, fragments and a chest. Open Chests, select a chest and confirm its displayed fragment cost. This practice guarantees enough fragments for one reward. In your own run, fragments come from defeated enemies.",
		"You placed answers, shaped a route, fitted gear, fought a wave and collected a reward. In a real campaign, credits, modules and number-family levels carry into the next board. You can replay this practice from How to play. Your previous run and its save are preserved.",
		"Enemies reached the exit before your towers stopped them. Try more coverage along the route and equip modules before launch. You can replay the practice or return to your own run."
	]
	for index in [0,2,3,4]: descriptions[index] = host._controller_hint(descriptions[index])
	if empty_defense:
		descriptions[3] = "Wrong answers used the remaining Solve time before you planted a tower. You can launch this practice wave and use reserve seeds during battle, or return to your own run. There is no tower to equip yet."
		descriptions[7] = "You finished this practice wave. Try another practice to plant answers and fit modules before launching. Your previous run and its save are preserved."
	box.add_child(host.label(descriptions[clampi(step,0,8)],19,host.WHITE))
	box.add_child(host.label("Practice progress stays separate from your saved run.",14,host.MUTED))
	var primary: Button
	if step in [7,8]:
		primary = host.button("Return to my run" if previous_active else "Choose my own run",finish,true)
	else:
		primary = host.button(("Launch wave" if empty_defense else "Open Gear") if step == 3 else ("Open Chests" if step == 6 else "Try it"),continue_step,true)
	primary.set_meta("focus_id","guide:continue")
	box.add_child(primary)
	var skip: Button = host.button("Skip guide / return",finish)
	skip.set_meta("focus_id","guide:skip")
	box.add_child(skip)
	primary.grab_focus()

func continue_step() -> void:
	if not active: return
	host._close_overlay()
	if step == 3:
		if host.run.towers.is_empty(): host._advance()
		else: host._toggle_dock("bag")
	elif step == 6: host._toggle_dock("loot")
	elif step in [4,5]: host.dock.close_panel()
	elif step in [0,1] and target_cell >= 0 and host.run.board[target_cell] == 0:
		host._select(target_cell,false,false)

func restore() -> void:
	if not active: return
	active = false
	host._clear_wrong_guess_feedback()
	host._close_controller_numbers()
	host.dock.reset_for_run()
	if previous_active: host.run.load_data(previous)
	else: host.run.new_run(784217,{"mode":"campaign","puzzle_difficulty":"easy","combat_difficulty":"easy"})
	host.has_active_run = previous_active
	host.game_speed = previous_speed
	host.manual_pause = previous_pause
	host.selected_cell = previous_cell
	host.selected_number = previous_number
	host.armed_item = ""
	host.world.setup(host.run)
	host.world.set_selected(previous_cell,previous_number)
	host.last_phase = host.run.phase
	host.save_elapsed = 0
	previous.clear()

func finish() -> void:
	if not active: return
	restore()
	if previous_active: host._close_overlay()
	else: host._show_menu(true)
	host._toast("Practice finished. Your own run is unchanged.")
