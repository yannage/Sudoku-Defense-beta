extends SceneTree
## Measure the board the player sees, including automatic camera framing.
## The first/last projected steps catch orientation snaps despite eased position.
const NativeBoard = preload("res://scripts/board.gd")
const CanvasBoard = preload("res://scripts/board_canvas.gd")
const RunScript = preload("res://scripts/run.gd")
var checks: int = 0
var failures: int = 0
var canvas: bool = false
var metrics: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func project(board, point: Vector3) -> Vector2:
	return board.project_point(point) if canvas else board.camera.unproject_position(point)

func positions(board) -> Array[Vector2]:
	var result: Array[Vector2] = []
	# Ground corners expose roll/zoom jumps; raised points expose abrupt tilt.
	for x: float in [-4.0, 0.0, 4.0]:
		for z: float in [-4.0, 0.0, 4.0]:
			for y: float in [0.0, 1.5]: result.append(project(board,Vector3(x,y,z)))
	return result

func distance(a: Array[Vector2], b: Array[Vector2]) -> float:
	var maximum := 0.0
	for i in range(a.size()): maximum = maxf(maximum,a[i].distance_to(b[i]))
	return maximum

func check_endpoint(board, area: Rect2, label: String) -> void:
	var framed := true
	var picked := true
	for cell in range(81):
		var point: Vector2 = board.cell_screen_position(cell)
		framed = framed and point.is_finite() and area.has_point(point)
		picked = picked and board.cell_at_screen(point) == cell
	check(framed,label+": every cell stays in the usable board area")
	check(picked,label+": every projected cell picks the same square")
	if not canvas:
		check(board.camera.basis.is_finite() and absf(board.camera.basis.determinant()-1.0)<0.001,label+": camera basis is finite and orthonormal")

func transition(board, model, phase: String, fps: int, label: String) -> Array[Vector2]:
	model.phase = phase
	var previous: Array[Vector2] = positions(board)
	var start: Array[Vector2] = previous.duplicate()
	var midpoint: Array[Vector2] = []
	var first_steps := 0.0
	var last_step := 0.0
	var max_speed := 0.0
	var max_angular_speed := 0.0
	var finite := true
	var framed := true
	var picked := true
	var previous_rotation: Quaternion = Quaternion.IDENTITY if canvas else board.camera.basis.get_rotation_quaternion()
	for index in range(fps*2):
		board.tick(1.0/float(fps))
		var current: Array[Vector2] = positions(board)
		var step := distance(previous,current)
		for point: Vector2 in current: finite = finite and point.is_finite()
		for cell in range(81):
			var point: Vector2 = board.cell_screen_position(cell)
			framed = framed and board._board_rect.has_point(point)
			picked = picked and board.cell_at_screen(point) == cell
		if index < maxi(1,fps/30): first_steps = maxf(first_steps,step)
		if step > 0.0001: last_step = step
		max_speed = maxf(max_speed,step*float(fps))
		if not canvas:
			var rotation: Quaternion = board.camera.basis.get_rotation_quaternion()
			max_angular_speed = maxf(max_angular_speed,rad_to_deg(previous_rotation.angle_to(rotation))*float(fps))
			previous_rotation = rotation
		if index == fps/2-1: midpoint = current.duplicate()
		previous = current
	check(finite,label+": all projected points remain finite")
	check(framed,label+": every cell remains framed throughout the movement")
	check(picked,label+": cell picking follows the whole animated view")
	check(first_steps <= 1.0*60.0/float(fps),label+": eases out of rest (first steps %.3f px)" % first_steps)
	check(last_step <= 1.0*60.0/float(fps),label+": eases into rest (last step %.3f px)" % last_step)
	check(max_speed < 900.0,label+": no sudden projected jump (%.1f px/s)" % max_speed)
	if not canvas: check(max_angular_speed < 200.0,label+": no orientation snap (%.1f degrees/s)" % max_angular_speed)
	check(distance(start,previous)>30.0,label+": camera actually reaches a different view")
	var before_idle: Array[Vector2] = positions(board)
	board.tick(0.25)
	check(distance(before_idle,positions(board))<0.01,label+": view settles completely")
	metrics.append({"case":label,"first_px":first_steps,"last_px":last_step,"max_px_per_second":max_speed,"max_degrees_per_second":max_angular_speed})
	return midpoint

func check_combat_shake(board, fps: int, label: String) -> void:
	var resting: Array[Vector2] = positions(board)
	board.play_event({"type":"leak","pos":Vector2(4,4)})
	board.tick(1.0/float(fps))
	var displacement := distance(resting,positions(board))
	check(displacement>0.05 and displacement<3.0,label+": a core hit produces a small visible shake after board fitting (%.3f px)" % displacement)
	board.tick(0.3)
	check(distance(resting,positions(board))<0.01,label+": shake decays back to exactly the settled camera")
	board.set_reduced_motion(true)
	board.play_event({"type":"leak","pos":Vector2(4,4)})
	board.tick(1.0/float(fps))
	check(distance(resting,positions(board))<0.01,label+": reduced motion suppresses core-hit camera shake")
	board.tick(0.3)
	board.set_reduced_motion(false)

func exercise() -> void:
	canvas = "--canvas-graphics" in OS.get_cmdline_user_args()
	root.disable_3d = canvas
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for viewport: Vector2i in [Vector2i(1280,800),Vector2i(720,1280)]:
		root.size = viewport
		await process_frame
		var area := Rect2(246,118,838,562) if viewport.x>viewport.y else Rect2(16,260,688,760)
		var midpoint_reference: Array[Vector2] = []
		for fps: int in [30,60,120]:
			var model = RunScript.new()
			model.new_run(784217,{"mode":"campaign","puzzle_difficulty":"easy","combat_difficulty":"easy"})
			model.drain_events()
			var board = CanvasBoard.new() if canvas else NativeBoard.new()
			root.add_child(board)
			board.setup(model)
			board.set_board_rect(area)
			board.tick(0.0)
			var label := "%s %s %dfps" % ["canvas" if canvas else "native",str(viewport),fps]
			var solve: Array[Vector2] = positions(board)
			check_endpoint(board,area,label+" solve")
			var midpoint: Array[Vector2] = transition(board,model,"prep",fps,label+" forward")
			check_endpoint(board,area,label+" defense")
			if not midpoint_reference.is_empty(): check(distance(midpoint,midpoint_reference)<0.05,label+": frame rate does not change the halfway pose")
			else: midpoint_reference = midpoint
			var defense: Array[Vector2] = positions(board)
			# Entering combat must not restart the already-finished prepare movement.
			model.phase = "battle"
			board.tick(1.0/float(fps))
			check(distance(defense,positions(board))<0.01,label+": launching combat preserves the defense pose")
			if not canvas: check_combat_shake(board,fps,label)
			transition(board,model,"solve",fps,label+" return")
			check(distance(solve,positions(board))<0.05,label+": returning to solve restores the original framing")
			check_endpoint(board,area,label+" returned solve")
			board.set_reduced_motion(true)
			model.phase = "prep"
			for index in range(fps): board.tick(1.0/float(fps))
			check(distance(defense,positions(board))<0.05,label+": reduced motion reaches the same defense pose")
			check_endpoint(board,area,label+" reduced motion")
			board.queue_free()
			await process_frame
	print("TRANSITION_METRICS "+JSON.stringify(metrics))
	print("BOARD_TRANSITION_%s: %d checks, %d failures" % ["PASS" if failures==0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
