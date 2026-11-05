extends SceneTree
## Wrong guesses spend Solve time through the authoritative model, regardless
## of the input device or renderer. Presentation/input coverage lives separately.
const Run = preload("res://scripts/run.gd")
const Sudoku = preload("res://scripts/sudoku.gd")
const Save = preload("res://scripts/run_save.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_test_wrong_guesses()
	_test_candidate_is_not_answer()
	_test_rapid_guesses()
	_test_timeout()
	_test_uncharged_actions()
	_test_save_reload()
	_test_journal_restart()
	_test_modes_and_legacy_history()
	_test_battle()
	if failures.is_empty():
		print("WRONG_GUESS_PENALTY_PASS %d checks" % checks)
		quit(0)
	else:
		for message: String in failures: push_error(message)
		print("WRONG_GUESS_PENALTY_FAIL %d / %d checks" % [failures.size(),checks])
		quit(1)

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func game(difficulty: String = "easy") -> RefCounted:
	var run = Run.new()
	run.new_run(784217,{"puzzle_difficulty":difficulty})
	run.drain_events()
	return run

func blank(run: RefCounted) -> int:
	for cell in range(81):
		if run.board[cell] == 0: return cell
	return -1

func wrong(run: RefCounted, cell: int) -> int:
	return int(run.solution[cell]) % 9 + 1

func without_wrong_count(run: RefCounted) -> Dictionary:
	var state: Dictionary = run.save_data()
	state.state.achievement_stats.counters.erase("wrong_answers")
	state.state.achievement_stats.current_round.counters.erase("wrong_answers")
	return state

func without_clock_and_combo(run: RefCounted) -> Dictionary:
	var state: Dictionary = without_wrong_count(run)
	state.state.erase("timer")
	state.state.erase("combo")
	return state

func _test_wrong_guesses() -> void:
	for difficulty: String in ["easy","medium","hard"]:
		var run = game(difficulty)
		var cell: int = blank(run)
		var number: int = wrong(run,cell)
		run.combo = 8
		var starting: float = run.timer
		var unchanged: Dictionary = without_clock_and_combo(run)
		var result: Dictionary = run.place(cell,number)
		check(not result.ok and result.get("reason") == "wrong_answer",difficulty+": wrong guess is rejected with an explicit reason")
		check(is_equal_approx(run.timer,starting-5.0),difficulty+": wrong guess costs five seconds")
		check(run.combo == 0 and run.phase == "solve",difficulty+": wrong guess resets combo and retains Solve while time remains")
		check(run.achievement_stats.counters.wrong_answers == 1 and run.achievement_stats.current_round.counters.wrong_answers == 1,difficulty+": rejection preserves durable lifetime and round wrong-answer evidence")
		check(without_clock_and_combo(run) == unchanged,difficulty+": rejection cannot plant, reward, consume reserves, alter route, or change RNG")
		check(is_equal_approx(float(result.time_penalty),5.0) and is_equal_approx(float(result.remaining_time),run.timer),difficulty+": result reports the actual deduction and remaining time")
		var events: Array = run.drain_events()
		check(events.size() == 1,difficulty+": one guess creates one rejection event")
		if events.size() != 1: continue
		var event: Dictionary = events[0]
		check(event.type == "invalid" and event.reason == "wrong_answer",difficulty+": rejection preserves the error sound event and identifies a wrong answer")
		check(event.cell == cell and event.number == number and event.pos == run.cell_position(cell),difficulty+": feedback points to the rejected square and number")
		check(is_equal_approx(float(event.time_penalty),5.0) and is_equal_approx(float(event.remaining_time),run.timer),difficulty+": feedback reports the same exact loss as the model")
		check(str(event.text).contains("Wrong answer") and str(event.text).contains("5s"),difficulty+": readable feedback explains both the error and time cost")

func _test_candidate_is_not_answer() -> void:
	var run = game("hard")
	var cell: int = -1
	var number: int = -1
	for index in range(81):
		if run.board[index] != 0: continue
		for candidate: int in run.candidates(index):
			if candidate != run.solution[index]:
				cell = index
				number = candidate
				break
		if cell >= 0: break
	check(cell >= 0,"Fixture contains a locally legal candidate that is not the answer")
	if cell < 0: return
	check(Sudoku.legal(run.board,cell,number),"Candidate obeys visible row, column, and box restrictions")
	var before: float = run.timer
	check(not run.place(cell,number).ok,"Locally legal wrong candidate is rejected")
	check(is_equal_approx(run.timer,before-5.0) and run.board[cell] == 0,"Notes do not exempt a wrong guess from the time penalty")

func _test_rapid_guesses() -> void:
	var run = game()
	var cell: int = blank(run)
	run.timer = 39.0
	var total_loss: float = 0.0
	for attempt in range(8):
		var result: Dictionary = run.place(cell,wrong(run,cell))
		total_loss += float(result.get("time_penalty",0.0))
		check(not result.ok and run.board[cell] == 0,"Rapid guess %d never places a tower" % attempt)
		check(is_equal_approx(run.timer,maxf(0.0,39.0-(attempt+1)*5.0)),"Rapid guess %d deducts immediately without a visual cooldown" % attempt)
	check(is_equal_approx(total_loss,39.0) and run.phase == "prep","Rapid guesses spend only the remaining time and enter Prep")
	var events: Array = run.drain_events()
	check(events.filter(func(event: Dictionary) -> bool: return event.type == "invalid").size() == 8,"Every accepted guess attempt emits its own rejection feedback")
	check(events.filter(func(event: Dictionary) -> bool: return event.type == "phase").size() == 1,"Rapid guesses cause exactly one phase transition")
	for attempt in range(12):
		var result: Dictionary = run.place(cell,wrong(run,cell))
		check(not result.ok and not result.has("time_penalty") and run.timer == 0.0 and run.phase == "prep","Further spam after timeout neither deducts time nor advances Prep")
	check(run.towers.is_empty() and run.board[cell] == 0,"Spam cannot plant an emergency tower by crossing the phase boundary")
	check(run.achievement_stats.counters.wrong_answers == 8 and run.achievement_stats.current_round.counters.wrong_answers == 8,"Only the eight Solve guesses record wrong-answer evidence; post-expiry spam does not")
	check(run.drain_events().all(func(event: Dictionary) -> bool: return event.type != "phase"),"Post-timeout attempts produce no extra phase event")

func _test_timeout() -> void:
	for remaining: float in [5.0,2.25,0.005,0.0]:
		var run = game()
		var cell: int = blank(run)
		run.timer = remaining
		var result: Dictionary = run.place(cell,wrong(run,cell))
		check(not result.ok and run.timer == 0.0 and run.phase == "prep","%.3fs: penalty immediately ends Solve at exactly zero" % remaining)
		check(is_equal_approx(float(result.time_penalty),remaining) and float(result.remaining_time) == 0.0,"%.3fs: result reports only the time actually lost" % remaining)
		var events: Array = run.drain_events()
		check(events.size() == 2,"%.3fs: timeout produces rejection and phase events only" % remaining)
		if events.size() == 2:
			check(events[0].type == "invalid" and events[1].type == "phase" and events[1].phase == "prep","%.3fs: map feedback precedes the normal Prep phase event" % remaining)
			check(is_equal_approx(float(events[0].time_penalty),remaining),"%.3fs: visual loss cannot claim the full five seconds" % remaining)
		check(str(result.message).contains("Prepare your defense"),"%.3fs: rejection explains the timeout transition" % remaining)
		run.update(1.0)
		check(run.timer == 0.0 and run.phase == "prep" and run.drain_events().is_empty(),"%.3fs: subsequent updates keep Prep stable" % remaining)
	var penalized = game()
	var natural = game()
	penalized.timer = 2.25
	natural.timer = 2.25
	penalized.place(blank(penalized),wrong(penalized,blank(penalized)))
	natural.update(2.25)
	check(without_wrong_count(penalized) == without_wrong_count(natural),"Penalty timeout preserves natural timer-expiration state apart from the existing wrong-answer evidence")
	check(penalized.achievement_stats.counters.wrong_answers == 1 and natural.achievement_stats.counters.wrong_answers == 0,"Only a wrong guess records wrong-answer evidence; natural expiry does not")

func _test_uncharged_actions() -> void:
	var run = game()
	var cell: int = blank(run)
	var before: float = run.timer
	check(run.place(cell,run.solution[cell]).ok and run.timer == before,"Correct answer costs no Solve time")
	check(not run.place(cell,wrong(run,cell)).ok and run.timer == before,"Clicking an occupied tower costs no Solve time")
	var fixed: int = -1
	for index in range(81):
		if run.givens[index]: fixed = index; break
	check(not run.place(fixed,wrong(run,fixed)).ok and run.timer == before,"Fixed clues do not charge a penalty")
	for arguments: Array in [[-1,1],[81,1],[blank(run),0],[blank(run),10]]:
		var result: Dictionary = run.place(arguments[0],arguments[1])
		check(not result.ok and not result.has("time_penalty") and run.timer == before,"Invalid cell/number arguments do not charge a penalty")
	check(run.hint(blank(run)).ok and run.timer == before,"A purchased correct hint costs credits without deducting time")
	check(run.drain_events().all(func(event: Dictionary) -> bool: return not event.has("time_penalty")),"Other errors and successful actions do not masquerade as wrong-answer penalties")
	for phase: String in ["prep","loot","won","lost"]:
		run.phase = phase
		var result: Dictionary = run.place(blank(run),wrong(run,blank(run)))
		check(not result.ok and not result.has("time_penalty") and run.timer == before and run.phase == phase,phase+": placement guard does not charge time or advance phases")

func _test_save_reload() -> void:
	var run = game()
	var cell: int = blank(run)
	run.timer = 12.25
	run.place(cell,wrong(run,cell))
	var restored = Run.new()
	check(restored.load_data(JSON.parse_string(JSON.stringify(run.save_data()))),"Penalty state round-trips through the existing save format")
	check(is_equal_approx(restored.timer,7.25) and restored.phase == "solve" and restored.board[cell] == 0,"Reload retains deducted time and the empty square")
	check(restored.drain_events().is_empty(),"Reload does not replay an old penalty event")
	# JSON parses integer counters as floats. Compare the full expected facts in
	# that same serialized representation, without dropping identity or history.
	check(restored.achievement_stats == JSON.parse_string(JSON.stringify(run.achievement_stats)),"Reload retains existing achievement facts including the wrong-answer count")
	restored.place(cell,wrong(restored,cell))
	check(is_equal_approx(restored.timer,2.25),"The next wrong guess after reload pays another penalty")
	restored.place(cell,wrong(restored,cell))
	var timed_out = Run.new()
	check(timed_out.load_data(JSON.parse_string(JSON.stringify(restored.save_data()))),"Timeout state can be saved and restored")
	check(timed_out.timer == 0.0 and timed_out.phase == "prep","Reload cannot resurrect Solve time after penalty timeout")
	check(not timed_out.place(cell,timed_out.solution[cell]).ok and timed_out.board[cell] == 0,"Reloaded Prep rejects placement until the player launches the wave")

func _test_battle() -> void:
	var run = game()
	run.advance_phase()
	run.advance_phase()
	run.update(0.5)
	run.drain_events()
	var cell: int = blank(run)
	var number: int = wrong(run,cell)
	var before: float = run.timer
	var reserve: int = run.inventory[number]
	var result: Dictionary = run.place(cell,number)
	check(result.ok and result.illegal and not result.has("time_penalty"),"Battle still accepts an intentionally wrong emergency number")
	check(run.timer == before and run.phase == "battle","Emergency placement leaves the Battle clock unchanged")
	check(run.board[cell] == number and run.towers.has(cell) and run.corruption == 1,"Battle keeps the emergency tower and corruption tradeoff")
	check(run.inventory[number] == reserve-1,"Battle still consumes exactly one reserve")
	check(run.drain_events().all(func(event: Dictionary) -> bool: return not event.has("time_penalty")),"Battle feedback never claims a Solve time penalty")
	result = run.place(blank(run),number)
	check(not result.ok and not result.has("time_penalty") and run.timer == before,"A missing Battle reserve does not deduct time")

func _test_journal_restart() -> void:
	var run = game()
	check(run.enable_achievement_tracking("isolated-penalty-journal"),"Synthetic run identity can be attached without Steam")
	var cell: int = blank(run)
	run.timer = 12.2578125
	var store = Save.new()
	store.file_path = "user://wrong-guess-penalty-journal.json"
	check(store.write_run(run.save_data()),"Initial synthetic run writes through the current journal")
	run.place(cell,wrong(run,cell))
	check(store.write_run(run.save_data()),"Rejected guess persists the changed timer through the current journal")
	var fresh_store = Save.new()
	fresh_store.file_path = store.file_path
	var saved: Dictionary = fresh_store.read_run()
	check(not saved.is_empty(),"Fresh store reads the committed penalty state")
	if saved.is_empty(): return
	var restored = Run.new()
	check(restored.load_data(saved.data),"Journal penalty state loads into a fresh model")
	check(restored.timer == 7.2578125 and restored.phase == "solve","Journal restart preserves fractional penalty time exactly")
	check(restored.achievement_stats == JSON.parse_string(JSON.stringify(run.achievement_stats)) and restored.achievement_stats.run_id == "isolated-penalty-journal","Journal restart retains only this synthetic run's identity and evidence")
	check(restored.achievement_stats.earned.is_empty(),"Wrong guesses do not award an achievement")
	check(restored.drain_events().is_empty(),"Journal restart does not replay feedback")
	restored.place(cell,wrong(restored,cell))
	check(restored.timer == 2.2578125 and fresh_store.write_run(restored.save_data()),"Repeated wrong guess after restart persists another five-second deduction")
	restored.place(cell,wrong(restored,cell))
	check(restored.timer == 0.0 and restored.phase == "prep" and fresh_store.write_run(restored.save_data()),"Penalty expiry is committed as Prepare at zero")
	var final_store = Save.new()
	final_store.file_path = store.file_path
	var final_saved: Dictionary = final_store.read_run()
	check(not final_saved.is_empty(),"Restart reads committed Prepare state")
	if final_saved.is_empty(): return
	var final_run = Run.new()
	check(final_run.load_data(final_saved.data),"Fresh model restores Prepare through the journal")
	check(final_run.timer == 0.0 and final_run.phase == "prep" and final_run.board[cell] == 0,"Restart does not restore Solve time or plant a rejected number")
	check(final_run.achievement_stats.counters.wrong_answers == 3 and final_run.achievement_stats.current_round.counters.wrong_answers == 3,"All three actual guesses remain recorded exactly once")
	check(final_run.achievement_stats.earned.is_empty() and final_run.achievement_stats.run_id == "isolated-penalty-journal","Timeout preserves identity without fabricating awards")

func _test_modes_and_legacy_history() -> void:
	for mode: String in ["campaign","locked","freeplay"]:
		var run = Run.new()
		run.new_run(784217,{"mode":mode})
		var cell: int = blank(run)
		run.timer = 3.125
		var result: Dictionary = run.place(cell,wrong(run,cell))
		check(not result.ok and result.time_penalty == 3.125 and run.timer == 0.0 and run.phase == "prep",mode+": the same penalty rule reaches Prepare without negative time")
		check(run.mode == mode and run.round_no == 1 and run.max_rounds == (1 if mode == "freeplay" else 50),mode+": penalty does not alter run progression settings")
	var original = game()
	var old_data: Dictionary = original.save_data()
	old_data.state.erase("achievement_stats")
	var legacy = Run.new()
	check(legacy.load_data(JSON.parse_string(JSON.stringify(old_data))),"Existing version-one saves without achievement history still load")
	var cell: int = blank(legacy)
	var before: float = legacy.timer
	legacy.place(cell,wrong(legacy,cell))
	check(legacy.timer == before-5.0 and legacy.achievement_stats.counters.wrong_answers == 1,"Only the new wrong guess is recorded after a legacy resume")
	check(not legacy.achievement_stats.complete_history and not legacy.achievement_stats.current_round.complete_history,"Penalty does not fabricate complete legacy achievement history")
	check(legacy.achievement_stats.run_id.is_empty() and legacy.achievement_stats.earned.is_empty(),"Legacy penalty does not bind an account/run identity or award progress")

