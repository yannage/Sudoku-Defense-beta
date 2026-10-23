extends SceneTree
## Audit the generator using a separate set/peer based solver, rather than
## proving the generator with the same bitmask solver that removed its clues.
const Sudoku = preload("res://scripts/sudoku.gd")
var checks := 0
var failures := 0
var units: Array = []
var peers: Array = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("exercise")

func build_units() -> void:
	for row in range(9):
		var cells: Array[int] = []
		for col in range(9): cells.append(row * 9 + col)
		units.append(cells)
	for col in range(9):
		var cells: Array[int] = []
		for row in range(9): cells.append(row * 9 + col)
		units.append(cells)
	for first_row in [0, 3, 6]:
		for first_col in [0, 3, 6]:
			var cells: Array[int] = []
			for row in range(first_row, first_row + 3):
				for col in range(first_col, first_col + 3): cells.append(row * 9 + col)
			units.append(cells)
	for cell in range(81):
		var adjacent := {}
		for group in units:
			if cell in group:
				for other in group:
					if other != cell: adjacent[other] = true
		peers.append(adjacent.keys())

func valid_units(board: Array, complete: bool) -> bool:
	if board.size() != 81: return false
	for group in units:
		var seen := {}
		for cell in group:
			var digit: int = board[cell]
			if digit == 0 and not complete: continue
			if digit < 1 or digit > 9 or seen.has(digit): return false
			seen[digit] = true
	return true

func independent_count(board: Array, limit: int = 2) -> int:
	var selected := -1
	var options: Array = []
	for cell in range(81):
		if board[cell] != 0: continue
		var available := {1:true, 2:true, 3:true, 4:true, 5:true, 6:true, 7:true, 8:true, 9:true}
		for other in peers[cell]: available.erase(board[other])
		if available.is_empty(): return 0
		if selected == -1 or available.size() < options.size():
			selected = cell
			options = available.keys()
			if options.size() == 1: break
	if selected == -1: return 1
	var total := 0
	for digit in options:
		board[selected] = digit
		total += independent_count(board, limit - total)
		board[selected] = 0
		if total >= limit: break
	return total

func audit(puzzle: Dictionary, context: String) -> void:
	check(valid_units(puzzle.solution, true), context + ": completed solution contains 1–9 in every row, column and box")
	check(valid_units(puzzle.board, false), context + ": printed clues contain no row, column or box conflicts")
	var consistent := true
	for cell in range(81):
		if puzzle.givens[cell] != (puzzle.board[cell] != 0): consistent = false
		if puzzle.board[cell] != 0 and puzzle.board[cell] != puzzle.solution[cell]: consistent = false
	check(consistent, context + ": every printed clue agrees with the answer and mask")
	check(independent_count(puzzle.board.duplicate()) == 1, context + ": independent solver finds exactly one completion")
	check(Sudoku.valid_puzzle(puzzle), context + ": runtime acceptance agrees with independent audit")

func exercise() -> void:
	build_units()
	var seeds: Array[int] = []
	for value in range(32): seeds.append(value)
	seeds.append_array([-1, -9223372036854775807, 9223372036854775807, 12345, 912, 171024])
	# Exercise the same per-round seed transformation used by a full campaign.
	for round_number in range(1, 51): seeds.append(12345 + round_number * 7919)
	var generated := 0
	for difficulty in ["easy", "medium", "hard"]:
		for seed_value in seeds:
			var puzzle: Dictionary = Sudoku.make_puzzle(seed_value, difficulty)
			audit(puzzle, "%s seed %d" % [difficulty, seed_value])
			check(81 - puzzle.board.count(0) == Sudoku.CLUE_COUNTS[difficulty], "Requested clue density is preserved")
			if generated % 20 == 0:
				check(puzzle == Sudoku.make_puzzle(seed_value, difficulty), "Repeated seed and difficulty reproduce the whole puzzle")
			generated += 1
		print("SUDOKU_AUDIT: %s validated; %d generated puzzles" % [difficulty, generated])

	for target in [48, 36, 27]:
		var fallback: Dictionary = Sudoku._fallback_puzzle(target)
		audit(fallback, "Emergency fallback target %d" % target)
		check(81 - fallback.board.count(0) >= target, "Fallback favors extra clues over a non-unique puzzle")

	var puzzle: Dictionary = Sudoku.make_puzzle(12345, "medium")
	var original: Array = puzzle.board.duplicate()
	check(Sudoku.count_solutions(puzzle.board) == 1 and puzzle.board == original, "Counting solutions never mutates the puzzle shown to the player")
	check(Sudoku.count_solutions(puzzle.solution) == 1, "A complete valid grid has one solution")
	var empty: Array = []
	empty.resize(81); empty.fill(0)
	check(Sudoku.valid_board(empty) and not Sudoku.valid_board(empty, true), "An empty partial grid is valid but is not a complete solution")
	check(Sudoku.count_solutions(empty) == 2 and independent_count(empty.duplicate()) == 2, "Both independent counters stop at two for a non-unique grid")
	check(Sudoku.count_solutions(empty, 0) == 0, "A zero search limit is rejected")
	for bad in ["2", true, null, 2.5, NAN, INF, -1, 10]:
		var malformed: Array = empty.duplicate()
		malformed[0] = bad
		check(not Sudoku.valid_board(malformed) and Sudoku.count_solutions(malformed) == 0, "Malformed digit cannot be rounded or coerced into a Sudoku answer: %s" % str(bad))
	var integral: Array = empty.duplicate()
	integral[0] = 2.0
	check(Sudoku.valid_board(integral), "Integral JSON numbers remain supported")
	for other in [1, 9, 10]:
		var duplicate: Array = empty.duplicate()
		duplicate[0] = 2; duplicate[other] = 2
		check(not Sudoku.valid_board(duplicate) and Sudoku.count_solutions(duplicate) == 0, "Adjacent row, column or box duplicate 2s are rejected")
	var impossible: Array = empty.duplicate()
	for cell in range(8): impossible[cell] = cell + 1
	impossible[17] = 9
	check(Sudoku.valid_board(impossible) and Sudoku.count_solutions(impossible) == 0 and independent_count(impossible.duplicate()) == 0, "Locally legal but impossible clues are rejected by both solvers")
	var too_short: Array = empty.slice(0, 80)
	check(not Sudoku.valid_board(too_short) and Sudoku.count_solutions(too_short) == 0, "Malformed board length is rejected")
	check(not Sudoku.valid_puzzle({}), "Missing puzzle fields are rejected")
	var corrupted: Dictionary = puzzle.duplicate(true)
	corrupted.solution[0] = corrupted.solution[1]
	check(not Sudoku.valid_puzzle(corrupted), "A duplicate in the hidden answer prevents puzzle acceptance")
	corrupted = puzzle.duplicate(true)
	corrupted.givens[0] = not corrupted.givens[0]
	check(not Sudoku.valid_puzzle(corrupted), "A clue mask that disagrees with the grid is rejected")
	corrupted = puzzle.duplicate(true)
	for cell in range(81):
		if corrupted.board[cell] != 0:
			corrupted.board[cell] = int(corrupted.board[cell]) % 9 + 1
			break
	check(not Sudoku.valid_puzzle(corrupted), "Printed clues must agree with the hidden answer")
	corrupted = puzzle.duplicate(true)
	corrupted.board = empty.duplicate()
	corrupted.givens.fill(false)
	check(not Sudoku.valid_puzzle(corrupted), "Consistent but non-unique clues cannot pass puzzle acceptance")
	print("SUDOKU_CHECKS: %d assertions, %d failures, %d generated puzzles" % [checks, failures, generated])
	print("SUDOKU_PASS" if failures == 0 else "SUDOKU_FAIL")
	quit(1 if failures else 0)
