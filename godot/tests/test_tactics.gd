extends SceneTree

const Run = preload("res://scripts/run.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_test_forecasts()
	_test_core_damage()
	_test_priority_actions()
	_test_combat_targets()
	_test_priority_saves()
	if failures.is_empty():
		print("TACTICS_PASS: %d checks, 0 failures" % checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("TACTICS_FAIL: %d failures / %d checks" % [failures.size(),checks])
		quit(1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _equal(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in range(a.size()):
			if not _equal(a[index],b[index]): return false
		return true
	# JSON round trips can change the final decimal of floating point stats.
	if (a is float or a is int) and (b is float or b is int): return is_equal_approx(float(a),float(b))
	return a == b

func _game() -> RefCounted:
	var run = Run.new()
	run.new_run(314159)
	return run

func _plant(run: RefCounted, count: int) -> void:
	for cell in range(81):
		if count <= 0: break
		if run.board[cell] == 0:
			run.place(cell,run.solution[cell])
			count -= 1

func _test_forecasts() -> void:
	var run = _game()
	var kinds: Array[String] = ["grunt","runner","swarm","tank","boss"]
	# Independent snapshots of the pre-0.3.14 tuning catch shared-blueprint drift.
	var difficulty_factors: Dictionary = {
		"easy":[0.72,0.85,0.85], "medium":[1.0,1.0,1.0], "hard":[1.3,1.1,1.18]
	}
	var hp_factors: Dictionary = {"grunt":1.0,"runner":0.72,"swarm":0.58,"tank":2.3,"boss":5.0}
	var speed_factors: Dictionary = {"grunt":0.82,"runner":1.4,"swarm":0.95,"tank":0.57,"boss":0.47}
	for difficulty: String in difficulty_factors:
		run.combat_difficulty = difficulty
		var factors: Array = difficulty_factors[difficulty]
		for round_no in range(1,51):
			run.round_no = round_no
			for corruption in [0,1,7]:
				run.corruption = corruption
				run.enemies.clear()
				run.spawned = 0
				run.spawn_total = 0
				var label: String = "%s round %d corruption %d" % [difficulty,round_no,corruption]
				var before: Dictionary = run.save_data()
				var events_before: Array = run._events.duplicate(true)
				var forecast: Dictionary = run.wave_forecast()
				_check(run.save_data() == before and run._events == events_before,"Forecast leaves state, RNG, IDs, and events untouched: " + label)
				_check(forecast == run.wave_forecast(),"Repeated forecast is deterministic: " + label)
				var count: int = roundi((12.0+floorf(round_no*0.58))*float(factors[2]))
				var stage: int = round_no-1
				var multiplier: float = 1.0+corruption*0.075
				_check(forecast.count == count and forecast.boss == (round_no%5 == 0),"Legacy count and boss cadence: " + label)
				_check(is_equal_approx(forecast.spawn_interval,maxf(0.35,0.94-stage*0.0105)) and forecast.corruption_multiplier == multiplier,"Interval and corruption multiplier: " + label)
				var expected_counts: Dictionary = {}
				var group_by_kind: Dictionary = {}
				var last_kind: int = -1
				for group: Dictionary in forecast.groups:
					var kind_index: int = kinds.find(group.kind)
					_check(kind_index > last_kind and int(group.count)>0,"Unique nonempty forecast groups in canonical order: " + label)
					last_kind = kind_index
					group_by_kind[group.kind] = group
				run.spawn_total = count
				for index in range(count):
					var kind: String = "grunt"
					if round_no%5 == 0 and index == count-1: kind = "boss"
					elif index%7 == 5: kind = "tank"
					elif index%4 == 2: kind = "runner"
					elif index%5 == 3: kind = "swarm"
					expected_counts[kind] = int(expected_counts.get(kind,0))+1
					run._spawn()
					var enemy: Dictionary = run.enemies.back()
					var expected_hp: float = 28.0*(1.0+0.12*stage)*pow(1.025,stage)*float(factors[0])*float(hp_factors[kind])*multiplier
					var expected_speed: float = (1.0+minf(0.55,stage*0.011))*float(factors[1])*float(speed_factors[kind])
					_check(enemy.kind == kind and is_equal_approx(enemy.hp,expected_hp) and is_equal_approx(enemy.speed,expected_speed),"Legacy spawn precedence, health and speed: %s index %d" % [label,index])
					_check(group_by_kind.has(enemy.kind),"Every spawned enemy appears in forecast: " + label)
					if group_by_kind.has(enemy.kind):
						var group: Dictionary = group_by_kind[enemy.kind]
						_check(group.health == enemy.hp and group.health == enemy.max_hp and group.speed == enemy.speed,"Forecast matches actual spawned stats: " + label)
						_check(group.core_damage == (6 if kind == "boss" else (2 if kind == "tank" else 1)),"Forecast leak damage: " + label)
				_check(run.enemies.size() == forecast.count and expected_counts.size() == forecast.groups.size(),"Forecast total and enemy types exactly match spawning: " + label)
				for kind: String in expected_counts:
					_check(group_by_kind[kind].count == expected_counts[kind],"Forecast type count matches spawns: " + label)
				if forecast.boss:
					_check(run.enemies.back().kind == "boss" and expected_counts.boss == 1,"Single boss replaces final enemy: " + label)
	# A caller may alter its own preview without altering the model or next preview.
	var original: Dictionary = run.wave_forecast()
	var changed: Dictionary = run.wave_forecast()
	changed.groups[0].health = -1.0
	changed.groups.clear()
	_check(run.wave_forecast() == original,"Forecast returns independently owned data")

func _enemy(id: int, progress: float, hp: float, max_hp: float = 1000.0) -> Dictionary:
	return {"id":id,"pos":Vector2.ZERO,"hp":hp,"max_hp":max_hp,"progress":progress,"speed":0.0,"kind":"grunt","slow":1.0,"slow_time":0.0,"poison_time":0.0,"poison_dps":0.0}

func _combat() -> RefCounted:
	var run = _game()
	run.phase = "battle"
	run.spawned = 1
	run.spawn_total = 1
	run.route.assign([Vector2(-3,4),Vector2(12,4)])
	run._cache_route()
	run.towers[40] = {"id":50,"cell":40,"number":1,"illegal":false,"level":1,"attachments":[],"growth":1.0,"cooldown":0.0,"aim":Vector2.ZERO,"target_priority":"first"}
	run.drain_events()
	return run

func _shots(run: RefCounted) -> Array:
	return run.drain_events().filter(func(event: Dictionary) -> bool: return event.type == "shot")

func _test_core_damage() -> void:
	for kind in ["grunt","runner","swarm","tank","boss"]:
		var run = _combat()
		run.towers.clear()
		run.spawned = 0
		run._spawn_clock = 99.0
		var enemy: Dictionary = _enemy(100,run.route_length,100.0)
		enemy.kind = kind
		run.enemies.append(enemy)
		var health: float = run.health
		run.update(0.01)
		_check(run.health == health-(6 if kind == "boss" else (2 if kind == "tank" else 1)),"Actual core leak matches forecast damage: " + kind)

func _test_priority_actions() -> void:
	var run = _game()
	_plant(run,2)
	var cells: Array = run.towers.keys()
	var cell: int = cells[0]
	_check(run.towers[cell].target_priority == "first","New towers default to first")
	for phase in ["solve","prep","battle","loot"]:
		run.phase = phase
		for priority in ["strongest","nearest","first"]:
			var before: Dictionary = run.save_data()
			_check(run.set_target_priority(cell,priority).ok,"Priority allowed during " + phase)
			before.state.towers[0].target_priority = priority
			_check(run.save_data() == before,"Priority change is free and affects only selected tower")
	_check(run.towers[cells[1]].target_priority == "first","Targeting is per tower")
	_check(not run.set_target_priority(-1,"nearest").ok,"Missing tower rejected")
	_check(not run.set_target_priority(cell,"random").ok and run.towers[cell].target_priority == "first","Unknown priority rejected without mutation")
	for phase in ["won","lost"]:
		run.phase = phase
		_check(not run.set_target_priority(cell,"nearest").ok and run.towers[cell].target_priority == "first","Finished run cannot change targeting")

func _test_combat_targets() -> void:
	for priority in ["first","strongest","nearest"]:
		var run = _combat()
		var first: Dictionary = _enemy(101,8.8,70.0,70.0)
		var strongest: Dictionary = _enemy(102,5.4,140.0,500.0)
		var nearest: Dictionary = _enemy(103,7.2,55.0,1000.0)
		var dead: Dictionary = _enemy(104,7.0,0.0)
		var distant: Dictionary = _enemy(105,11.0,10000.0,10000.0)
		run.enemies.assign([nearest,distant,first,dead,strongest])
		run.set_target_priority(40,priority)
		var selected: Dictionary = {"first":first,"strongest":strongest,"nearest":nearest}[priority]
		var previous_hp: float = selected.hp
		run.update(0.01)
		var shots: Array = _shots(run)
		_check(shots.size() == 1 and shots[0].target == selected.pos,"Combat shot selects " + priority)
		_check(selected.hp == previous_hp-9.0 and distant.hp == 10000.0 and dead.hp == 0.0,"Shot damages correct living in-range target: " + priority)
		for enemy in [first,strongest,nearest]:
			if enemy.id != selected.id:
				_check(enemy.hp == {101:70.0,102:140.0,103:55.0}[enemy.id],"Unselected enemy unchanged: " + priority)
		# Selection must be evaluated again on the next shot after a live switch.
		var next_priority: String = "strongest" if priority != "strongest" else "nearest"
		run.set_target_priority(40,next_priority)
		run.towers[40].cooldown = 0.0
		run.update(0.01)
		shots = _shots(run)
		var next: Dictionary = strongest if next_priority == "strongest" else nearest
		_check(shots.size() == 1 and shots[0].target == next.pos,"Mid-battle priority applies to next shot")
	for priority in ["strongest","nearest"]:
		var run = _combat()
		var earlier: Dictionary = _enemy(102,6.0,100.0)
		var later: Dictionary = _enemy(103,8.0,100.0)
		run.enemies.assign([earlier,later])
		run.set_target_priority(40,priority)
		run.update(0.01)
		_check(later.hp == 91.0 and earlier.hp == 100.0,"Equal " + priority + " breaks tie by route progress")
		run = _combat()
		var higher_id: Dictionary = _enemy(109,7.0,100.0)
		var lower_id: Dictionary = _enemy(105,7.0,100.0)
		run.enemies.assign([higher_id,lower_id])
		run.set_target_priority(40,priority)
		run.update(0.01)
		_check(lower_id.hp == 91.0 and higher_id.hp == 100.0,"Equal " + priority + " and progress breaks tie by ID")
	var run = _combat()
	var first_in_array: Dictionary = _enemy(109,7.0,100.0)
	var second_in_array: Dictionary = _enemy(105,7.0,100.0)
	run.enemies.assign([first_in_array,second_in_array])
	run.update(0.01)
	_check(first_in_array.hp == 91.0 and second_in_array.hp == 100.0,"Default First preserves existing equal-progress order")
	for priority in ["first","strongest","nearest"]:
		run = _combat()
		run.towers[40].attachments.append({"kind":"range","power":9.0})
		run.set_target_priority(40,priority)
		var boundary: Dictionary = _enemy(110,11.75,100.0)
		var outside: Dictionary = _enemy(111,11.751,1000.0)
		run.enemies.assign([outside,boundary])
		run.update(0.01)
		_check(boundary.hp == 91.0 and outside.hp == 1000.0,"Exact range boundary is eligible: " + priority)
		run = _combat()
		run.set_target_priority(40,priority)
		run.enemies.assign([_enemy(112,7.0,0.0),_enemy(113,12.0,100.0)])
		run.update(0.01)
		_check(_shots(run).is_empty() and run.towers[40].cooldown == 0.0,"No eligible target does not consume a shot: " + priority)

func _test_priority_saves() -> void:
	var run = _game()
	_plant(run,9)
	var cells: Array = run.towers.keys()
	var priorities: Array[String] = ["first","strongest","nearest"]
	for index in range(cells.size()): run.set_target_priority(cells[index],priorities[index%3])
	run.advance_phase()
	run.advance_phase()
	run.update(6.0)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(run.save_data()))
	var restored = Run.new()
	_check(restored.load_data(saved),"Mixed-priority mid-battle save loads")
	for index in range(cells.size()):
		_check(restored.towers[cells[index]].target_priority == priorities[index%3],"JSON save preserves per-tower targeting")
	run.drain_events()
	for step in range(60):
		run.update(0.05)
		restored.update(0.05)
	_check(_equal(run.save_data(),restored.save_data()),"Mixed-priority combat resumes deterministically")
	var events: Array = run.drain_events()
	_check(events == restored.drain_events(),"Mixed-priority resumed combat produces identical shots/events")
	_check(events.any(func(event: Dictionary) -> bool: return event.type == "shot"),"Replay comparison includes actual tower shots")
	for replacement in [null,"obsolete",73,{},"nearest"]:
		var migrated: Dictionary = saved.duplicate(true)
		if replacement == null: migrated.state.towers[0].erase("target_priority")
		else: migrated.state.towers[0].target_priority = replacement
		var legacy = Run.new()
		_check(legacy.load_data(migrated),"Legacy/unknown targeting never invalidates a valid save")
		_check(legacy.towers[cells[0]].target_priority == ("nearest" if replacement is String and replacement == "nearest" else "first"),"Missing/unknown saved targeting defaults safely to first")
