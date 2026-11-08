extends SceneTree
## Clues disappear on a stationary Prep -> Battle transition in both renderers.
const RunScript = preload("res://scripts/run.gd")
const NativeBoard = preload("res://scripts/board.gd")

class RecordingCanvas extends "res://scripts/board_canvas.gd":
	var digit_draws: Array[String] = []

	func _text_center(value: String, _center: Vector2, _size: int, _color: Color) -> void:
		digit_draws.append(value)

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("exercise")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func exercise() -> void:
	root.size = Vector2i(1280, 800)
	var model = RunScript.new()
	model.new_run(784217, {"mode":"campaign", "puzzle_difficulty":"easy", "combat_difficulty":"easy"})
	var tower_cell := -1
	var blank_cell := -1
	var clue_count := 0
	for cell in range(81):
		if model.givens[cell]:
			clue_count += 1
		elif tower_cell < 0:
			tower_cell = cell
		elif blank_cell < 0:
			blank_cell = cell
	check(bool(model.place(tower_cell, model.solution[tower_cell]).ok), "Fixture plants a tower")
	var numbers: Array = model.board.duplicate()
	var givens: Array = model.givens.duplicate()
	var native = NativeBoard.new()
	root.add_child(native)
	native.setup(model)
	var canvas = RecordingCanvas.new()
	root.add_child(canvas)
	canvas.hide()
	canvas.setup(model)
	model.advance_phase()
	for i in range(30):
		native.tick(0.05)
		canvas.tick(0.05)
	canvas.digit_draws.clear()
	canvas._draw_digits()
	check(canvas.digit_draws.size() == clue_count, "Prepare retains clues while tower numbers use separate badges")
	var matching_clue := -1
	for cell in range(81):
		if model.givens[cell] and model.board[cell] == model.board[tower_cell]:
			matching_clue = cell
			break
	check(matching_clue >= 0, "Fixture includes a printed clue matching the tower family")
	native.set_selected(tower_cell, model.board[tower_cell])
	check(native._labels[matching_clue].visible and native._match_frames[matching_clue].visible, "Prepare shows matching clues")
	var settled_morph: float = native._morph
	model.advance_phase()
	native.tick(0.0)
	canvas.tick(0.0)
	check(native._morph == settled_morph, "Wave launch does not depend on further camera movement")
	check(not native._labels[matching_clue].visible and not native._match_frames[matching_clue].visible, "Native battle immediately hides printed clues and their matching highlights")
	check(native._labels[tower_cell].visible and native._labels[tower_cell].billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Native battle retains the compact tower-family badge")
	canvas.digit_draws.clear()
	canvas._draw_digits()
	check(canvas.digit_draws.is_empty(), "Canvas battle draws no puzzle clues beneath the towers")
	native.set_drop_preview(blank_cell, 2, true)
	canvas.set_drop_preview(blank_cell, 2, true)
	check(native._drop_label.text == "2" and canvas._drop_number == 2, "Emergency reserve previews still identify the number being planted")
	check(model.board == numbers and model.givens == givens and model.towers.has(tower_cell), "Presentation changes leave puzzle values and tower ownership untouched")
	model.phase = "loot"
	native.tick(0.0)
	canvas.tick(0.0)
	canvas.digit_draws.clear()
	canvas._draw_digits()
	check(native._labels[matching_clue].visible and canvas.digit_draws.size() == clue_count, "Leaving combat restores clues without moving the camera")
	model.new_run(784218, {"mode":"campaign", "puzzle_difficulty":"easy", "combat_difficulty":"easy"})
	native.setup(model)
	canvas.setup(model)
	native.tick(0.0)
	canvas.tick(0.0)
	var new_clues := 0
	var shown_clues := 0
	for cell in range(81):
		if model.givens[cell]:
			new_clues += 1
			if native._labels[cell].visible and native._labels[cell].text == str(model.board[cell]): shown_clues += 1
	canvas.digit_draws.clear()
	canvas._draw_digits()
	check(shown_clues == new_clues and canvas.digit_draws.size() == new_clues, "A new Solve board restores every clue in both renderers")
	native.queue_free()
	canvas.queue_free()
	await process_frame
	print("COMBAT_CLUTTER: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
