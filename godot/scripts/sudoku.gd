class_name DefenseSudoku
extends RefCounted
## Seeded Sudoku generation. Difficulty is clue density, never non-unique guesses.

const CLUE_COUNTS: Dictionary = {"easy": 48, "medium": 36, "hard": 27}
const ALL_DIGITS: int = 1022

static func valid_board(board: Array, complete: bool = false) -> bool:
	if board.size() != 81: return false
	var rows: Array[int] = []
	var cols: Array[int] = []
	var boxes: Array[int] = []
	rows.resize(9); cols.resize(9); boxes.resize(9)
	for cell: int in range(81):
		var value = board[cell]
		# JSON may contain integral floats, but never silently round a corrupt
		# value, coerce a string, or treat true as the Sudoku digit 1.
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]: return false
		if not is_finite(float(value)) or float(value) != floor(float(value)): return false
		if value < (1 if complete else 0) or value > 9: return false
		var digit: int = int(value)
		if digit == 0: continue
		var row: int = cell / 9
		var col: int = cell % 9
		var box: int = (row / 3) * 3 + col / 3
		var bit: int = 1 << digit
		if ((rows[row] | cols[col] | boxes[box]) & bit) != 0: return false
		rows[row] |= bit; cols[col] |= bit; boxes[box] |= bit
	return true

static func valid_puzzle(puzzle: Dictionary) -> bool:
	for key in ["board", "solution", "givens"]:
		if not puzzle.has(key) or not puzzle[key] is Array or puzzle[key].size() != 81: return false
	if not valid_board(puzzle.board) or not valid_board(puzzle.solution, true): return false
	for cell: int in range(81):
		if typeof(puzzle.givens[cell]) != TYPE_BOOL: return false
		if puzzle.givens[cell] != (puzzle.board[cell] != 0): return false
		if puzzle.board[cell] != 0 and puzzle.board[cell] != puzzle.solution[cell]: return false
	return count_solutions(puzzle.board) == 1

static func legal(board: Array, cell: int, number: int) -> bool:
	if board.size() != 81 or cell < 0 or cell > 80 or number < 1 or number > 9:
		return false
	var row: int = cell / 9
	var col: int = cell % 9
	var box_row: int = (row / 3) * 3
	var box_col: int = (col / 3) * 3
	for i: int in range(9):
		var row_cell: int = row * 9 + i
		var col_cell: int = i * 9 + col
		if row_cell != cell and int(board[row_cell]) == number:
			return false
		if col_cell != cell and int(board[col_cell]) == number:
			return false
	for y: int in range(box_row, box_row + 3):
		for x: int in range(box_col, box_col + 3):
			var index: int = y * 9 + x
			if index != cell and int(board[index]) == number:
				return false
	return true

static func candidates(board: Array, cell: int) -> Array[int]:
	var result: Array[int] = []
	if board.size() != 81 or cell < 0 or cell > 80 or int(board[cell]) != 0:
		return result
	for digit: int in range(1, 10):
		if legal(board, cell, digit):
			result.append(digit)
	return result

static func count_solutions(input: Array, limit: int = 2) -> int:
	if limit < 1 or not valid_board(input):
		return 0
	var board: PackedInt32Array = PackedInt32Array(input)
	var rows: PackedInt32Array = PackedInt32Array()
	var cols: PackedInt32Array = PackedInt32Array()
	var boxes: PackedInt32Array = PackedInt32Array()
	rows.resize(9)
	cols.resize(9)
	boxes.resize(9)
	for cell: int in range(81):
		var digit: int = board[cell]
		if digit == 0:
			continue
		if digit < 1 or digit > 9:
			return 0
		var row: int = cell / 9
		var col: int = cell % 9
		var box: int = (row / 3) * 3 + (col / 3)
		var bit: int = 1 << digit
		if ((rows[row] | cols[col] | boxes[box]) & bit) != 0:
			return 0
		rows[row] |= bit
		cols[col] |= bit
		boxes[box] |= bit
	return _search(board, rows, cols, boxes, limit)

static func _search(board: PackedInt32Array, rows: PackedInt32Array, cols: PackedInt32Array, boxes: PackedInt32Array, limit: int) -> int:
	var selected: int = -1
	var selected_mask: int = 0
	var best: int = 10
	for cell: int in range(81):
		if board[cell] != 0:
			continue
		var row: int = cell / 9
		var col: int = cell % 9
		var box: int = (row / 3) * 3 + (col / 3)
		var mask: int = ALL_DIGITS & ~(rows[row] | cols[col] | boxes[box])
		if mask == 0:
			return 0
		var count: int = 0
		var bits: int = mask
		while bits != 0:
			bits &= bits - 1
			count += 1
		if count < best:
			best = count
			selected = cell
			selected_mask = mask
			if count == 1:
				break
	if selected == -1:
		return 1
	var selected_row: int = selected / 9
	var selected_col: int = selected % 9
	var selected_box: int = (selected_row / 3) * 3 + (selected_col / 3)
	var total: int = 0
	for digit: int in range(1, 10):
		var bit: int = 1 << digit
		if (selected_mask & bit) == 0:
			continue
		board[selected] = digit
		rows[selected_row] |= bit
		cols[selected_col] |= bit
		boxes[selected_box] |= bit
		total += _search(board, rows, cols, boxes, limit - total)
		rows[selected_row] ^= bit
		cols[selected_col] ^= bit
		boxes[selected_box] ^= bit
		board[selected] = 0
		if total >= limit:
			return total
	return total

static func _shuffled(values: Array[int], rng: RandomNumberGenerator) -> Array[int]:
	var result: Array[int] = values.duplicate()
	for i: int in range(result.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temporary: int = result[i]
		result[i] = result[j]
		result[j] = temporary
	return result

static func make_puzzle(seed_value: int, difficulty: String = "medium") -> Dictionary:
	var target: int = int(CLUE_COUNTS.get(difficulty, 36))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var best: Dictionary = {}
	var best_clues: int = 82
	for _attempt: int in range(12):
		var rows: Array[int] = []
		var cols: Array[int] = []
		var triplet: Array[int] = [0, 1, 2]
		for band: int in _shuffled(triplet, rng):
			for offset: int in _shuffled(triplet, rng):
				rows.append(band * 3 + offset)
		for stack: int in _shuffled(triplet, rng):
			for offset: int in _shuffled(triplet, rng):
				cols.append(stack * 3 + offset)
		var source_digits: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
		var digits: Array[int] = _shuffled(source_digits, rng)
		var solution: Array[int] = []
		for row: int in rows:
			for col: int in cols:
				var pattern: int = (row * 3 + row / 3 + col) % 9
				solution.append(digits[pattern])
		if not valid_board(solution, true): continue
		var board: Array[int] = solution.duplicate()
		var positions: Array[int] = []
		for cell: int in range(81):
			positions.append(cell)
		var clues: int = 81
		for cell: int in _shuffled(positions, rng):
			var old_digit: int = board[cell]
			board[cell] = 0
			if count_solutions(board) == 1:
				clues -= 1
			else:
				board[cell] = old_digit
			if clues == target:
				break
		if clues < best_clues:
			var givens: Array[bool] = []
			for digit: int in board:
				givens.append(digit != 0)
			var candidate := {"board": board, "solution": solution, "givens": givens}
			if not valid_puzzle(candidate): continue
			best = candidate
			best_clues = clues
		if clues == target:
			break
	if not best.is_empty(): return best
	# A bounded generation failure must not hand an invalid board to a run.
	# This independently checked classic puzzle stays unique as clues are added.
	push_warning("Seeded Sudoku generation exhausted its safety retries; using a verified fallback puzzle.")
	var fallback: Dictionary = _fallback_puzzle(target)
	if valid_puzzle(fallback): return fallback
	push_error("Sudoku fallback failed validation; refusing to return an invalid puzzle.")
	return {}

static func _fallback_puzzle(target: int) -> Dictionary:
	const PRINTED := "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
	const ANSWERS := "534678912672195348198342567859761423426853791713924856961537284287419635345286179"
	var board: Array[int] = []
	var solution: Array[int] = []
	var givens: Array[bool] = []
	for cell: int in range(81):
		board.append(int(PRINTED[cell]))
		solution.append(int(ANSWERS[cell]))
	var clues: int = 81 - board.count(0)
	for cell: int in range(81):
		if clues >= target: break
		if board[cell] == 0:
			board[cell] = solution[cell]
			clues += 1
	for digit: int in board: givens.append(digit != 0)
	return {"board":board, "solution":solution, "givens":givens}
