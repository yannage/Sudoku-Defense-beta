extends SceneTree

const Run = preload("res://scripts/run.gd")
const Feedback = preload("res://scripts/strategy_feedback.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_test_routes()
	_test_upgrades()
	_test_report()
	_test_poison()
	_test_retry()
	for failure in failures: push_error(failure)
	print("%s: %d checks / %d failures" % ["STRATEGY_FEEDBACK_PASS" if failures.is_empty() else "STRATEGY_FEEDBACK_FAIL",checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not equal(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not equal(a[i],b[i]): return false
		return true
	if (a is int or a is float) and (b is int or b is float): return is_equal_approx(float(a),float(b))
	return a == b

func game():
	var run = Run.new()
	run.new_run(784217)
	return run

func empty_cells(run: RefCounted) -> Array[int]:
	var cells: Array[int] = []
	for cell in range(81):
		if int(run.board[cell]) == 0: cells.append(cell)
	return cells

func _test_routes() -> void:
	var run = game()
	var default_route: Array[Vector2] = [Vector2(.5,-.5),Vector2(.5,1.5),Vector2(7.5,1.5),Vector2(7.5,4.5),Vector2(1.5,4.5),Vector2(1.5,7.5),Vector2(7.5,7.5),Vector2(7.5,8.5),Vector2(8.5,8.5)]
	check(run.route == default_route,"Unplanted route retains 0.3.15 geometry")
	var moves: Array[int] = [26,27,53,54]
	var boundary_route: Array[Vector2] = [Vector2(.5,-.5),Vector2(.5,2.5),Vector2(8.5,2.5),Vector2(8.5,5.5),Vector2(.5,5.5),Vector2(.5,6.5),Vector2(7.5,6.5),Vector2(7.5,8.5),Vector2(8.5,8.5)]
	check(run.route_for_moves(moves) == boundary_route,"Band boundaries retain known route geometry")
	check(is_equal_approx(Feedback.route_length(boundary_route),33.0),"Known route length is measured in tiles")
	var straight: Array[Vector2] = [Vector2(-3,0),Vector2(3,0)]
	check(is_equal_approx(Feedback.route_in_range(straight,Vector2.ZERO,2),4.0),"Range clips both ends of a segment")
	check(Feedback.route_in_range(straight,Vector2(0,2),2) == 0,"Tangent contact gives no firing distance")
	for cell: int in empty_cells(run).slice(0,16):
		var before: Dictionary = run.save_data()
		var events: Array = run._events.duplicate(true)
		var preview: Dictionary = Feedback.placement(run,cell,run.solution[cell])
		var wrong: Dictionary = Feedback.placement(run,cell,1+int(run.solution[cell])%9)
		check(preview.route == wrong.route and preview.coverage == wrong.coverage,"Wrong candidate does not reveal hidden answer")
		check(before == run.save_data() and events == run._events,"Preview changes no state, events, IDs or RNG")
		run.place(cell,run.solution[cell])
		check(preview.route == run.route and is_equal_approx(preview.length,run.route_length),"Preview matches committed route through 12-move history limit")
	run.advance_phase()
	check(Feedback.placement(run,empty_cells(run)[0],1).is_empty(),"Preparation does not advertise placement")
	run.advance_phase()
	check(Feedback.placement(run,empty_cells(run)[0],1).is_empty(),"Battle does not advertise route changes")
	check(Feedback.defense_summary(run).contains("active towers"),"Forecast summarizes actual defense")

func _test_upgrades() -> void:
	var run = game()
	for cell: int in empty_cells(run): run.place(cell,run.solution[cell])
	run.credits = 10000
	run.passives.power = 3
	run.active_effects.append({"kind":"overcharge","remaining":9.0})
	var cell: int = run.towers.keys()[0]
	run.towers[cell].attachments.append({"kind":"power","power":1.7})
	run.towers[cell].illegal = true
	var before: Dictionary = run.save_data()
	var preview: Dictionary = Feedback.upgrade(run,cell)
	check(before == run.save_data(),"Upgrade preview is pure with gear and effects")
	var number: int = run.towers[cell].number
	var current_damage := 0.0
	for key: int in run.towers:
		if int(run.towers[key].number) == number: current_damage += float(run.tower_stats(key).damage)
	run.upgrade_family(number)
	check(is_equal_approx(run.tower_stats(cell).damage,preview.after),"Family preview includes gear, passive, effect, and illegal penalties")
	var upgraded_damage := 0.0
	for key: int in run.towers:
		if int(run.towers[key].number) == number: upgraded_damage += float(run.tower_stats(key).damage)
	check(is_equal_approx(upgraded_damage-current_damage,preview.total_gain),"Family total includes exactly matching current towers")
	preview = Feedback.upgrade(run,cell)
	run.upgrade_tower(cell)
	check(is_equal_approx(run.tower_stats(cell).damage,preview.after),"Tower preview matches one actual level")

func enemy(id: int, hp: float = 20.0) -> Dictionary:
	return {"id":id,"pos":Vector2.ZERO,"hp":hp,"max_hp":hp,"progress":0.0,"speed":0.0,"kind":"grunt","slow":1.0,"slow_time":0.0,"poison_time":0.0,"poison_dps":0.0}

func _test_report() -> void:
	var run = game()
	var cell: int = empty_cells(run)[0]
	run.place(cell,run.solution[cell])
	var target: Dictionary = enemy(900,7)
	run._damage(target,100.0,Color.WHITE,false,cell)
	run._damage(target,100.0,Color.WHITE,false,cell)
	check(run.combat_report.damage == 7.0 and run.kills == 1,"Overkill and repeated dead hits are not double counted")
	check(run.combat_report.towers["1:%d" % cell].kills == 1,"Killing blow belongs to attacking tower")
	for kind: String in ["runner","tank","boss"]:
		var leaked: Dictionary = enemy(901)
		leaked.kind = kind
		leaked.progress = run.route_length
		run.enemies.assign([leaked])
		run.phase = "battle"
		run._spawn_clock = 99.0
		run.spawned = 0
		run.spawn_total = 5
		run._step(0.01)
	check(run.combat_report.core_damage == 9 and run.combat_report.leaks == {"runner":1,"tank":1,"boss":1},"Core report records enemy types and nominal hit damage before healing")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(run.save_data()))
	var restored = Run.new()
	check(restored.load_data(saved),"Telemetry save restores through JSON")
	check(equal(restored.combat_report,run.combat_report),"Report survives save/resume")
	for i in range(20):
		run.update(0.05)
		restored.update(0.05)
	check(equal(restored.save_data(),run.save_data()),"Report does not change deterministic resumed combat")
	saved.state.erase("combat_report")
	check(restored.load_data(saved) and not restored.combat_report.complete,"Legacy save gets explicitly partial report")
	check(Feedback.result_lines(restored)[0].begins_with("Partial report"),"Legacy history is not presented as measured zero")
	saved.state.combat_report = {"complete":true,"damage":"corrupt","core_damage":0,"leaks":{},"towers":{}}
	check(restored.load_data(saved) and not restored.combat_report.complete,"Malformed optional history does not block legitimate run")

func _test_poison() -> void:
	var run = game()
	var cells: Array[int] = empty_cells(run).slice(0,2)
	for cell: int in cells: run.place(cell,run.solution[cell])
	var strong: Dictionary = run.towers[cells[0]]
	var weak: Dictionary = run.towers[cells[1]]
	strong.attachments.append({"kind":"venom","power":5.0})
	weak.attachments.append({"kind":"venom","power":1.0})
	var target: Dictionary = enemy(910,500)
	run._fire(strong,target,run.tower_stats(cells[0]))
	run._fire(weak,target,run.tower_stats(cells[1]))
	check(int(target.poison_source) == cells[0],"Weaker poison refresh cannot steal stronger damage credit")
	run.phase = "battle"
	run.spawn_total = 1
	run.spawned = 1
	run.enemies.assign([target])
	for tower: Dictionary in run.towers.values(): tower.cooldown = 99.0
	var damage_before: float = run.combat_report.towers["1:%d" % cells[0]].damage
	run._step(0.05)
	check(float(run.combat_report.towers["1:%d" % cells[0]].damage) > damage_before,"Poison tick credits originating tower")
	var restored = Run.new()
	check(restored.load_data(JSON.parse_string(JSON.stringify(run.save_data()))),"Mid-poison run restores")
	check(restored.enemies[0].poison_source == cells[0],"Poison ownership survives save/resume")
	for i in range(10):
		run.update(0.05)
		restored.update(0.05)
	check(equal(restored.save_data(),run.save_data()),"Mid-poison report stays deterministic after resume")

func _test_retry() -> void:
	var run = Run.new()
	var options := {"mode":"campaign","puzzle_difficulty":"medium","combat_difficulty":"hard"}
	run.new_run(9147,options)
	var board: Array = run.board.duplicate()
	var items: Array = run.items.duplicate(true)
	run.puzzle_difficulty = "easy"
	run.combat_difficulty = "easy"
	check(run.retry_options() == options,"Retry uses original campaign difficulties, not current round")
	var restored = Run.new()
	check(restored.load_data(JSON.parse_string(JSON.stringify(run.save_data()))),"Changed campaign difficulties restore")
	restored.new_run(restored.seed_value,restored.retry_options())
	check(restored.board == board and restored.items == items,"Same-seed restart recreates puzzle and starting gear")
	check(restored.round_no == 1 and restored.combat_report.damage == 0.0 and restored.combat_report.complete,"Retry starts clean progression and accounting")
