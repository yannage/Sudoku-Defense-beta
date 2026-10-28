extends SceneTree
## An answer and numeral appear immediately; tower-foundation assembly is cosmetic.
## Runs headlessly for behavior and with GLES for framebuffer evidence.

const NativeBoard = preload("res://scripts/board.gd")
const CanvasBoard = preload("res://scripts/board_canvas.gd")
const RunScript = preload("res://scripts/run.gd")
const Planting = preload("res://scripts/seed_planting.gd")
var checks: int = 0
var failures: int = 0
var canvas: bool = false
var rendered: bool = false
var output_dir: String = "res://build/seed-checks"

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count: int = 2) -> void:
	for i in range(count): await process_frame
	if rendered: await RenderingServer.frame_post_draw

func events(model, board) -> void:
	for event: Dictionary in model.drain_events(): board.play_event(event)

func alpha(board, cell: int) -> float:
	if not canvas:
		return board._labels[cell].modulate.a if board._labels[cell].visible else 0.0
	if not board._seed_plantings.has(cell): return 1.0
	return Planting.number_alpha(float(board._seed_plantings[cell].age))

func blank(model, skip: Array[int] = []) -> int:
	# Prefer the middle of the board so the evidence is easy to inspect.
	for cell in [40, 41, 39, 31, 49, 30, 32, 48, 50] + range(81):
		if model.board[cell] == 0 and cell not in skip: return cell
	return -1

func capture(name: String) -> Image:
	if not rendered: return null
	var image: Image = root.get_texture().get_image()
	check(image != null and not image.is_empty(), "Framebuffer exists: " + name)
	if image != null and not image.is_empty():
		check(image.save_png(output_dir.path_join(("canvas-" if canvas else "native-") + name + ".png")) == OK, "Save seed evidence: " + name)
	return image

func changed_pixels(before: Image, after: Image, center: Vector2, radius: int = 25) -> int:
	var count: int = 0
	for x in range(maxi(0, int(center.x)-radius), mini(before.get_width(), int(center.x)+radius)):
		for y in range(maxi(0, int(center.y)-radius), mini(before.get_height(), int(center.y)+radius)):
			var a: Color = before.get_pixel(x,y)
			var b: Color = after.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) > 0.12: count += 1
	return count

func numeral_pixels(image: Image, center: Vector2) -> int:
	var count: int = 0
	for x in range(int(center.x)-16,int(center.x)+17):
		for y in range(int(center.y)-16,int(center.y)+17):
			var color: Color = image.get_pixel(x,y)
			if maxf(color.r,maxf(color.g,color.b)) < 0.70: count += 1
	return count

func click(point: Vector2, touch: bool = false) -> void:
	for pressed in [true, false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = point
			event.pressed = pressed
			root.push_input(event,true)
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
			event.position = point
			event.global_position = point
			event.pressed = pressed
			root.push_input(event,true)
		await frames(1)

func integrated_inputs() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await frames(5)
	scene.muted = true
	scene.sound.set_muted(true)
	scene.seed_input.text = "784217"
	scene._start_run()
	await frames(4)
	# Freeze time, not input: the fixture explicitly drains the normal game loop
	# after each input so every animation remains observable at its first frame.
	scene.set_process(false)
	for kind in ["mouse", "touch", "keyboard", "controller"]:
		var cell: int = blank(scene.run)
		var number: int = int(scene.run.solution[cell])
		if kind in ["mouse", "touch"]:
			await click(scene.world.cell_screen_position(cell),kind == "touch")
			await click(scene.number_buttons[number-1].get_global_rect().get_center(),kind == "touch")
		else:
			scene._select(cell,false)
			if kind == "keyboard":
				var event := InputEventKey.new()
				event.keycode = KEY_0 + number
				event.pressed = true
				root.push_input(event,true)
				event.pressed = false
				root.push_input(event,true)
			else:
				scene.selected_number = number
				scene._release_ui_focus()
				for stage in range(2):
					for pressed in [true,false]:
						var event := InputEventJoypadButton.new()
						event.device = 42
						event.button_index = JOY_BUTTON_A
						event.pressed = pressed
						Input.parse_input_event(event)
						await frames(1)
					if stage == 0:
						check(scene.run.board[cell] == 0 and scene._controller_number_cell == cell, "Controller first A focuses the number tray before foundation assembly")
			scene._process(0.0)
		# Mouse and touch also reach the same normal event-drain path.
		scene._process(0.0)
		check(scene.run.board[cell] == number, "%s immediately commits the correct answer" % kind)
		check(scene.world._seed_plantings.has(cell), "%s uses the foundation assembly presentation" % kind)
	check(scene.world._seed_plantings.size() == 4, "Four input methods can plant while prior foundations are still assembling")
	scene.world.tick(0.80)
	check(scene.world._seed_plantings.is_empty(), "Integrated foundation presentations finish without further player input")
	scene.queue_free()
	await frames(3)

func exercise() -> void:
	canvas = "--canvas-graphics" in OS.get_cmdline_user_args()
	rendered = DisplayServer.get_name() != "headless"
	root.disable_3d = canvas
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280,800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var model = RunScript.new()
	model.new_run(784217,{"mode":"campaign","puzzle_difficulty":"easy","combat_difficulty":"easy"})
	model.drain_events()
	var board = CanvasBoard.new() if canvas else NativeBoard.new()
	root.add_child(board)
	board.setup(model)
	board.set_board_rect(Rect2(246,118,838,562))
	board.tick(0.0)
	await frames(4)
	check(board._seed_plantings.is_empty(), "New puzzle and fixed clues do not replay planting animations")
	check(Planting.DURATION <= 0.60,"Placement feedback completes quickly")
	for step: int in range(51):
		var age: float = float(step)*0.01
		check(Planting.number_alpha(age) == 1.0,"Answer remains opaque at %.2f seconds" % age)
		for index: int in range(4):
			var corner: Vector3 = Planting.corner_offset(age,index)
			var scale3: float = Planting.corner_scale(age,index)
			for part: Dictionary in Planting.corner_blocks(index,Color.CYAN):
				var center: Vector3 = corner+Vector3(part.offset)*scale3
				var half: Vector3 = Vector3(part.size)*scale3*0.5
				check(absf(center.x)-half.x > 0.15 or absf(center.z)-half.z > 0.15,"Foundation never covers the central numeral")
	for index: int in range(4):
		check(Planting.corner_offset(Planting.SETTLE_AT,index).is_equal_approx(Planting.corner_offset(Planting.DURATION,index)),"Assembled corners match their permanent foundation position")

	var first: int = blank(model)
	var second: int = blank(model,[first])
	var third: int = blank(model,[first,second])
	var fixed: int = -1
	for cell in range(81):
		if model.givens[cell]:
			fixed = cell
			check(alpha(board,cell) >= 0.99,"Fixed clue %d stays readable" % cell)
	var baseline: Image = capture("00-blank")
	var position: Vector2 = board.cell_screen_position(first)
	var credit_before: int = model.credits
	check(model.place(first,model.solution[first]).ok,"Correct answer is accepted")
	events(model,board)
	board.tick(0.0)
	check(model.board[first] == model.solution[first] and model.towers.has(first),"The board and tower commit before the foundation assembly finishes")
	check(model.credits > credit_before,"Solve reward is immediate, not animation-dependent")
	check(board._seed_plantings.has(first),"Successful placement begins a per-cell foundation assembly")
	var native_seed_nodes: Array[Node] = []
	if not canvas: native_seed_nodes.append(board._seed_plantings[first].node)
	check(alpha(board,first) >= 0.99,"Numeral is fully readable on the first placement frame")
	if not canvas:
		check(board._seed_plantings[first].corners.get_child_count() == 4,"Four mechanical corners assemble around the answer")
		check(not board._seed_plantings[first].has("soil") and not board._seed_plantings[first].has("seed"),"No soil or free-floating seed model remains")
	board.tick(0.10)
	await frames()
	var approach: Image = capture("01-foundation-assembly")
	if rendered: check(changed_pixels(baseline,approach,position) > 8,"Number and assembling foundation visibly respond on the target square")
	check(model.place(second,model.solution[second]).ok,"A second answer is accepted during the first animation")
	events(model,board)
	board.tick(0.0)
	check(board._seed_plantings.has(first) and board._seed_plantings.has(second),"Rapid placements animate independently")
	if not canvas: native_seed_nodes.append(board._seed_plantings[second].node)
	check(float(board._seed_plantings[first].age) > float(board._seed_plantings[second].age),"A new foundation does not restart the previous assembly")
	var invalid_number: int = 1 + int(model.solution[third]) % 9
	check(not model.place(third,invalid_number).ok,"Incorrect solve placement is rejected")
	events(model,board)
	check(not board._seed_plantings.has(third) and model.board[third] == 0,"Rejected move does not assemble a foundation or change the square")
	check(not model.place(fixed,model.solution[fixed]).ok,"Fixed clue cannot be replanted")
	events(model,board)
	check(not board._seed_plantings.has(fixed),"Fixed clue never gains planting animation state")
	board.tick(0.17)
	await frames()
	capture("02-foundation-locking")
	check(alpha(board,first) >= 0.99,"Numeral stays readable throughout foundation assembly")
	board.tick(0.25)
	await frames()
	capture("03-foundation-complete")
	check(alpha(board,first) >= 0.99,"Numeral is fully readable after the foundation locks")
	if not canvas:
		var foundation: Node3D = board._tower_nodes[first].seed
		check(foundation.visible,"Permanent foundation is visible on the assembly cleanup frame")
		check(foundation.name == "TowerFoundation" and foundation.get_child_count() == 4,"Completed answer retains its four tower foundation corners")
		for index: int in range(4):
			check(foundation.get_child(index).position.is_equal_approx(Planting.corner_offset(Planting.DURATION,index)),"Completed corner stays at its assembly endpoint")

	board.tick(0.30)
	await frames()
	var settled: Image = capture("04-settled")
	check(board._seed_plantings.is_empty(),"Finished animations remove per-cell state")
	check(alpha(board,first) >= 0.99 and alpha(board,second) >= 0.99,"Both solved digits remain visible after animation cleanup")
	if rendered:
		check(changed_pixels(baseline,settled,position) > 12,"Settled answer changes real numeral pixels from the blank tile")
		check(numeral_pixels(settled,position) > 100,"Settled answer has a full readable numeral, not only impact particles")
	# Toggling accessibility or advancing phase mid-animation must reveal digits.
	model.place(third,model.solution[third]); events(model,board)
	if not canvas: native_seed_nodes.append(board._seed_plantings[third].node)
	board.set_reduced_motion(true)
	board.tick(0.0)
	check(board._seed_plantings.is_empty() and alpha(board,third) >= 0.99,"Reduced motion restores a digit when enabled during its foundation assembly")
	var fourth: int = blank(model)
	model.place(fourth,model.solution[fourth]); events(model,board); board.tick(0.0)
	check(board._seed_plantings.is_empty() and alpha(board,fourth) >= 0.99,"Reduced motion plants answers immediately without hiding numerals")
	board.set_reduced_motion(false)
	var fifth: int = blank(model)
	model.place(fifth,model.solution[fifth]); events(model,board)
	check(board._seed_plantings.has(fifth),"Animation can be enabled again")
	if not canvas: native_seed_nodes.append(board._seed_plantings[fifth].node)
	model.advance_phase(); events(model,board); board.tick(0.01)
	check(board._seed_plantings.is_empty() and alpha(board,fifth) > 0.5,"Immediate Prepare transition cannot leave a digit hidden")
	await frames(2)
	for node in native_seed_nodes:
		check(not is_instance_valid(node),"Completed, accessibility-canceled, and phase-canceled native assemblies free their temporary nodes")
	board.setup(model); board.tick(0.0)
	check(board._seed_plantings.is_empty(),"Setup of an existing board does not replay assemblies")
	model.new_run(7319,{"puzzle_difficulty":"easy"}); model.drain_events(); board.setup(model); board.tick(0.0)
	var reset_cell: int = blank(model)
	model.place(reset_cell,model.solution[reset_cell]); events(model,board)
	check(board._seed_plantings.has(reset_cell),"Fresh run can assemble a foundation")
	model.new_run(7320,{"puzzle_difficulty":"easy"}); model.drain_events(); board.setup(model); board.tick(0.0)
	check(board._seed_plantings.is_empty(),"Starting a new board clears active foundation assemblies")
	board.queue_free()
	await frames(3)
	await integrated_inputs()
	print("SEED_PLANTING_CHECKS: %d assertions, %d failures; renderer=%s; real pixels=%s" % [checks,failures,"canvas" if canvas else "native",rendered])
	if failures == 0: print("SEED_PLANTING_PASS")
	quit(1 if failures else 0)
