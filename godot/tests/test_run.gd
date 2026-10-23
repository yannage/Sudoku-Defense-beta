extends SceneTree

const Run = preload("res://scripts/run.gd")
const Sudoku = preload("res://scripts/sudoku.gd")
const Loot = preload("res://scripts/loot.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_test_puzzle()
	_test_actions()
	_test_equipment()
	_test_save()
	_test_slots()
	_test_combat()
	_test_progression()
	_test_campaign()
	if failures.is_empty():
		print("PASS: %d checks · Sudoku, economy, gear, saves, combat and 50-round progression" % checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("FAIL: %d / %d checks" % [failures.size(),checks])
		quit(1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _game(seed_value: int = 123, options: Dictionary = {}) -> RefCounted:
	var run = Run.new()
	run.new_run(seed_value,options)
	return run

func _blank(run: RefCounted, start: int = 0) -> int:
	for i in range(start,81):
		if run.board[i] == 0: return i
	return -1

func _plant(run: RefCounted, count: int) -> void:
	for i in range(81):
		if count <= 0: break
		if run.board[i] == 0:
			run.place(i,run.solution[i])
			count -= 1

func _test_puzzle() -> void:
	for difficulty in ["easy","medium","hard"]:
		for seed_value in [1,99,12345]:
			var puzzle: Dictionary = Sudoku.make_puzzle(seed_value,difficulty)
			_check(Sudoku.count_solutions(puzzle.board) == 1,"Puzzle must have one solution")
			var expected: int = 48 if difficulty=="easy" else (36 if difficulty=="medium" else 27)
			_check(puzzle.board.filter(func(n: int) -> bool: return n>0).size()==expected,"Clue density")
			_check(Sudoku.count_solutions(puzzle.solution)==1,"Completed board is valid")
	var puzzle: Dictionary = Sudoku.make_puzzle(912,"hard")
	_check(puzzle==Sudoku.make_puzzle(912,"hard"),"Puzzle deterministic seed")

func _test_actions() -> void:
	var run = _game()
	_check(run.items.size()==4,"Starter kit contains 3 modules and boost")
	var cell: int = _blank(run)
	var number: int = run.solution[cell]
	var starting: int = run.credits
	_check(not run.place(cell,number%9+1).ok,"Reject wrong solve placement")
	_check(run.credits==starting and run.board[cell]==0,"Wrong move has no cost or overwrite")
	var route_before: Array = run.route.duplicate()
	_check(run.place(cell,number).ok,"Correct placement accepted")
	_check(run.credits>starting and run.towers.has(cell),"Correct solve earns tower and currency")
	_check(run.route != route_before,"Recent move changes route")
	_check(not run.place(cell,number).ok,"Occupied square cannot duplicate rewards")
	var hinted: int = _blank(run)
	starting = run.credits
	_check(run.hint(hinted).ok and run.credits==starting-6,"Hint costs six without reward")
	run.advance_phase()
	_check(run.phase=="prep","Solve advances to preparation")
	var clock: float = run.timer
	run.update(10.0)
	_check(run.phase=="prep" and run.timer==clock,"War prep has no timer")
	run.advance_phase()
	var locked_route: Array = run.route.duplicate()
	cell = _blank(run)
	number = run.solution[cell]%9+1
	_check(run.place(cell,number).ok and run.corruption==1,"Emergency illegal tower allowed")
	_check(run.route==locked_route,"Battle routing remains fixed to prevent teleporting enemies")
	_check(run.inventory[number]==0,"Emergency placement consumes reserve")
	_check(not run.place(_blank(run),number).ok,"No unlimited reserve seeds")
	_check(run.buy_seed(number).ok and run.inventory[number]==1,"Buy reserve uses credits")

func _test_equipment() -> void:
	var run = _game()
	_plant(run,2)
	var cell: int = int(run.towers.keys()[0])
	var target: int = int(run.towers.keys()[1])
	var item_id: int = int(run.items[0].id)
	_check(run.equip_item(cell,str(item_id)).ok,"String ID equip supported")
	_check(run.items.size()==3 and run.towers[cell].attachments.size()==1,"Equip transfers ownership")
	_check(not run.equip_item(cell,item_id).ok,"Cannot duplicate equipped gear")
	_check(run.move_attachment(cell,0,target).ok,"Move attachment between towers")
	_check(run.towers[cell].attachments.is_empty() and run.towers[target].attachments.size()==1,"Move is atomic")
	_check(run.swap_attachment(target,0,run.items[0].id).ok,"Swap bag and equipped gear")
	_check(run.unequip_item(target,0).ok and run.items.size()==4,"Unequip returns gear")
	for i in range(6): run.items.append(Loot.make_item(run.rng,"rare",1,900+i,"power"))
	for i in range(5): _check(run.equip_item(cell,900+i).ok,"Module slot accepts attachment")
	_check(not run.equip_item(cell,905).ok,"Maximum five slots")
	var before: float = run.tower_stats(cell).damage
	run.credits = 1000
	_check(run.upgrade_tower(cell).ok and run.tower_stats(cell).damage>before,"Single tower upgrade increases damage")
	var family: int = run.towers[cell].number
	before = run.tower_stats(cell).damage
	_check(run.upgrade_family(family).ok and run.tower_stats(cell).damage>before,"Family upgrade stacks")
	var consumable: Dictionary = {}
	for item in run.items:
		if item.kind=="overclock": consumable=item
	_check(not run.use_item(consumable.id).ok,"Combat boost cannot be wasted during prep")
	run.advance_phase()
	run.advance_phase()
	var interval: float = run.tower_stats(cell).interval
	_check(run.use_item(str(consumable.id)).ok,"Consumable activates during battle")
	_check(is_equal_approx(run.tower_stats(cell).interval,interval*0.5),"Overclock doubles fire rate")
	_check(not run.use_item(consumable.id).ok,"Consumable used once")

func _test_save() -> void:
	var run = _game(875)
	_plant(run,8)
	run.equip_item(int(run.towers.keys()[2]),run.items[1].id)
	run.advance_phase()
	run.advance_phase()
	run.update(2.5)
	var data: Dictionary = JSON.parse_string(JSON.stringify(run.save_data()))
	var loaded = Run.new()
	_check(loaded.load_data(data),"JSON save restores mid battle")
	_check(run.board==loaded.board and run.route==loaded.route,"Board and route restored")
	_check(run.rng.state==loaded.rng.state,"64-bit RNG state retains full precision")
	for i in range(60):
		run.update(0.1)
		loaded.update(0.1)
	_check(run.kills==loaded.kills and run.credits==loaded.credits,"Save replay preserves deterministic combat")
	_check(_equal(run.save_data(),loaded.save_data()),"Save replay preserves entire state")
	_check(not loaded.load_data({"version":1,"state":{}}),"Reject incomplete save")

func _test_slots() -> void:
	var total_units: int = 0
	var weighted: int = 0
	for row in Loot.SLOT_TABLE:
		total_units += row.units
		weighted += row.units*row.credits
		_check(row.credits>=10 or row.gear,"All losing outcomes include gear")
	_check(total_units==1000 and weighted==9500,"Slots advertise exact 95% credits return")
	var run = _game(43)
	run.phase = "loot"
	run.credits = 10000
	var gear_count: int = 0
	var cash_count: int = 0
	for i in range(1000):
		var before: int = run.credits
		var result: Dictionary = run.spin_slots()
		_check(result.ok and run.credits==before-10+result.credits,"Slot settles stake and payout once")
		if result.reward.item != null: gear_count += 1
		if result.credits>=10: cash_count += 1
	_check(gear_count>350 and gear_count<550,"Seeded sample delivers expected gear frequency")
	_check(cash_count>450 and cash_count<650,"Seeded sample frequent stake recovery")
	var chest: Dictionary = run._add_chest("rare")
	var count: int = run.items.size()
	_check(not run.open_chest(chest.id).ok,"Fragments required to open cache")
	run.fragments = 10
	_check(run.open_chest(str(chest.id)).ok and run.items.size()==count+2 and run.fragments==0,"Rare cache gives two items and exact cost")
	_check(not run.open_chest(chest.id).ok,"Cache cannot be opened twice")

func _test_combat() -> void:
	for seed_value in [3,51,123]:
		var run = _game(seed_value,{"mode":"freeplay"})
		_plant(run,8)
		run.advance_phase()
		run.advance_phase()
		for i in range(900):
			if run.phase != "battle": break
			run.update(0.1)
		_check(run.phase=="won","Eight simple towers should survive first easy wave")
		_check(run.kills>=5 and run.fragments>=5,"First wave awards enough energy for chest")
		_check(not run.chests.is_empty(),"Every clear grants a cache")
		var credits_after: int = run.credits
		run.update(5.0)
		_check(run.credits==credits_after,"Wave reward settles only once")
	var run = _game(2)
	var prior_hp: float = 0.0
	for stage in range(1,51):
		run.round_no=stage
		var stats: Dictionary = run.wave_stats()
		_check(float(stats.health)>prior_hp,"Enemy strength scales through 50 rounds")
		_check(bool(stats.boss)==(stage%5==0),"Boss every five rounds")
		prior_hp=stats.health

func _test_progression() -> void:
	var run = _game(88)
	_plant(run,1)
	var cell: int = int(run.towers.keys()[0])
	run.equip_item(cell,run.items[0].id)
	run.phase = "loot"
	var bag_before: int = run.items.size()
	_check(run.next_round({"puzzle_difficulty":"hard","combat_difficulty":"medium"}).ok,"Campaign chooses next map difficulty")
	_check(run.round_no==2 and run.puzzle_difficulty=="hard" and run.combat_difficulty=="medium","Next map settings applied")
	_check(run.items.size()==bag_before+1,"Equipment returned between maps")
	var locked = _game(88,{"mode":"locked","puzzle_difficulty":"medium","combat_difficulty":"hard"})
	locked.phase="loot"
	_check(not locked.next_round({"puzzle_difficulty":"easy"}).ok,"Locked mode preserves original difficulty")
	for stage in range(2,51):
		locked.phase="loot"
		_check(locked.next_round().ok,"Locked campaign can generate every map")
	_check(locked.round_no==50 and locked.max_rounds==50,"Campaign has fifty levels")

func _equal(a: Variant,b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not _equal(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in range(a.size()):
			if not _equal(a[i],b[i]): return false
		return true
	if (a is float or a is int) and (b is float or b is int): return is_equal_approx(float(a),float(b))
	return a==b

func _test_campaign() -> void:
	var run = _game(1023,{"puzzle_difficulty":"medium","combat_difficulty":"medium"})
	var cleared: int = 0
	for stage in range(1,51):
		_plant(run,81)
		# Spend permanent progression evenly; equip earned modules near the path.
		for purchase in range(100):
			var cheapest: int = 1
			for family in range(2,10):
				if run.family_upgrade_cost(family)<run.family_upgrade_cost(cheapest): cheapest=family
			if run.credits<run.family_upgrade_cost(cheapest): break
			run.upgrade_family(cheapest)
		var cells: Array = run.towers.keys()
		var equipped: bool = true
		while equipped:
			equipped=false
			for cell: int in cells:
				if run.towers[cell].attachments.size()>=5: continue
				for item in run.items:
					if item.type=="attachment":
						run.equip_item(cell,item.id)
						equipped=true
						break
		run.advance_phase()
		run.advance_phase()
		for tick in range(1800):
			if run.phase!="battle": break
			run.update(0.1)
		if run.phase=="lost": break
		_check(run.phase=="loot" or run.phase=="won","Campaign battle settles")
		cleared+=1
		for chest in run.chests.duplicate():
			if run.fragments>=int(chest.cost): run.open_chest(chest.id)
		if stage<50: run.next_round()
	print("Balance: solved-grid medium campaign cleared ",cleared,"/50; core ",run.health,"; family levels ",run.family_levels.slice(1))
	_check(cleared==50 and run.phase=="won","Full campaign viable with earned upgrades and loot")
