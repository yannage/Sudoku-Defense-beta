extends SceneTree
## Test what players can see and select after orbiting, not only camera angles.
const NativeBoard = preload("res://scripts/board.gd")
const CanvasBoard = preload("res://scripts/board_canvas.gd")
const RunScript = preload("res://scripts/run.gd")
var checks := 0
var failures := 0
var canvas := false

func _initialize() -> void:
	call_deferred("exercise")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func points(board) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for cell: int in [0,8,40,72,80]: result.append(board.cell_screen_position(cell))
	return result

func distance(a: Array[Vector2], b: Array[Vector2]) -> float:
	var maximum := 0.0
	for i: int in range(a.size()): maximum = maxf(maximum,a[i].distance_to(b[i]))
	return maximum

func settle(board, fps: int = 60) -> void:
	for i: int in range(fps*2): board.tick(1.0/float(fps))

func check_board(board, area: Rect2, context: String) -> void:
	var framed := true
	var selected := true
	for cell: int in range(81):
		var point: Vector2 = board.cell_screen_position(cell)
		framed = framed and point.is_finite() and area.has_point(point)
		selected = selected and board.cell_at_screen(point) == cell
	check(framed,context+": all 81 cells stay framed")
	check(selected,context+": all 81 cell centers select the matching square")
	if not canvas:
		check(board.camera.basis.is_finite() and absf(board.camera.basis.determinant()-1.0)<0.001,context+": orbit basis stays orthonormal")

func check_reset_motion() -> void:
	var halfway_reference: Array[Vector2] = []
	for fps: int in [30,60,120]:
		var model = RunScript.new()
		model.new_run(784217,{})
		model.phase = "prep"
		var board = CanvasBoard.new() if canvas else NativeBoard.new()
		root.add_child(board)
		board.setup(model)
		board.set_board_rect(Rect2(246,118,838,562))
		settle(board)
		var default_pose: Array[Vector2] = points(board)
		board.rotate_camera(PI)
		settle(board)
		var previous: Array[Vector2] = points(board)
		var previous_yaw: float = board.get_camera_yaw()
		board.reset_camera()
		check(distance(previous,points(board))<0.001,"Reset begins at the displayed pose (%d FPS)" % fps)
		var first_speed := 0.0
		var maximum_speed := 0.0
		var last_step := 0.0
		for frame: int in range(fps*2):
			board.tick(1.0/float(fps))
			var current: Array[Vector2] = points(board)
			var step: float = distance(previous,current)
			var speed: float = rad_to_deg(absf(angle_difference(previous_yaw,board.get_camera_yaw())))*float(fps)
			if frame == 0: first_speed = speed
			maximum_speed = maxf(maximum_speed,speed)
			if step>0.0001: last_step = step
			if frame == roundi(fps*0.3)-1:
				if halfway_reference.is_empty(): halfway_reference = current.duplicate()
				else: check(distance(current,halfway_reference)<0.05,"Reset reaches the same 0.3-second pose at %d FPS" % fps)
			previous = current
			previous_yaw = board.get_camera_yaw()
		check(first_speed<25.0,"Half-turn reset eases out of rest, %.2f degrees/s at %d FPS" % [first_speed,fps])
		check(maximum_speed<750.0,"Half-turn reset never snaps, %.2f degrees/s at %d FPS" % [maximum_speed,fps])
		check(last_step<2.0*60.0/float(fps),"Half-turn reset eases into rest, %.3f px at %d FPS" % [last_step,fps])
		check(distance(default_pose,points(board))<0.05 and not board.camera_is_rotated(),"Half-turn reset restores the exact default view at %d FPS" % fps)
		# Grabbing the camera during reset hands control back at its visible angle.
		board.rotate_camera(PI)
		settle(board)
		board.reset_camera()
		board.tick(0.15)
		var interrupted_yaw: float = board.get_camera_yaw()
		var interrupted_pose: Array[Vector2] = points(board)
		board.rotate_camera(0.03)
		check(distance(interrupted_pose,points(board))<0.001,"Manual input during reset does not jump the current pose")
		board.tick(1.0/float(fps))
		check(absf(angle_difference(interrupted_yaw,board.get_camera_yaw()))<0.031,"Interrupted reset follows only the new manual movement")
		settle(board)
		check(absf(angle_difference(interrupted_yaw+0.03,board.get_camera_yaw()))<0.001,"Reset stays canceled after a manual drag takes control")
		board.queue_free()
		await process_frame

func exercise() -> void:
	canvas = "--canvas-graphics" in OS.get_cmdline_user_args()
	root.disable_3d = canvas
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var cases := [
		{"size":Vector2i(1280,800),"area":Rect2(246,118,838,562),"name":"Deck"},
		{"size":Vector2i(600,1066),"area":Rect2(16,228,568,466),"name":"portrait"},
		{"size":Vector2i(1280,800),"area":Rect2(246,118,674,562),"name":"open gear dock"},
	]
	for layout: Dictionary in cases:
		root.size = layout.size
		await process_frame
		var model = RunScript.new()
		model.new_run(784217,{"mode":"campaign","puzzle_difficulty":"easy","combat_difficulty":"easy"})
		model.drain_events()
		var board = CanvasBoard.new() if canvas else NativeBoard.new()
		root.add_child(board)
		board.setup(model)
		board.set_board_rect(layout.area)
		board.tick(0.0)
		for phase: String in ["solve","prep"]:
			model.phase = phase
			board.reset_camera()
			settle(board)
			var rest: Array[Vector2] = points(board)
			var context: String = str(layout.name)+" "+phase
			check(not board.camera_is_rotated(),context+": default view reports centered")
			for step: int in range(8):
				board.rotate_camera(PI/4.0)
				var framed := true
				var selected := true
				for frame: int in range(120):
					board.tick(1.0/60.0)
					for cell: int in range(81):
						var p: Vector2 = board.cell_screen_position(cell)
						framed = framed and p.is_finite() and layout.area.has_point(p)
						selected = selected and board.cell_at_screen(p) == cell
				check(framed and selected,context+": cells remain framed and selectable throughout orbit step %d" % step)
				check_board(board,layout.area,context+" yaw %d" % ((step+1)*45))
				if step == 1: check(distance(rest,points(board))>40,context+": quarter turn visibly moves the board")
			check(distance(rest,points(board))<0.1,context+": a full revolution returns to the same view")
			board.rotate_camera(deg_to_rad(355.0))
			settle(board)
			var before: Array[Vector2] = points(board)
			board.reset_camera()
			var excursion := 0.0
			for frame: int in range(120):
				board.tick(1.0/60.0)
				excursion = maxf(excursion,distance(before,points(board)))
			check(excursion<50,context+": reset near the wrap seam takes the short path")
			check(distance(rest,points(board))<0.1 and not board.camera_is_rotated(),context+": reset restores default framing")
		# An already rotated board still eases out of rest when the phase changes.
		model.phase = "solve"
		board.rotate_camera(-PI*0.65)
		settle(board)
		var before_transition: Array[Vector2] = points(board)
		var yaw: float = board.get_camera_yaw()
		model.phase = "prep"
		board.tick(1.0/60.0)
		check(distance(before_transition,points(board))<2.0,str(layout.name)+": manual yaw preserves gentle phase-transition start")
		settle(board)
		check(absf(angle_difference(yaw,board.get_camera_yaw()))<0.001,str(layout.name)+": phase changes preserve the requested manual angle")
		check_board(board,layout.area,str(layout.name)+" rotated defense")
		board.set_reduced_motion(true)
		board.reset_camera()
		board.rotate_camera(PI/2.0)
		board.tick(1.0/60.0)
		check_board(board,layout.area,str(layout.name)+" reduced motion")
		board.setup(model)
		board.tick(0.0)
		check(not board.camera_is_rotated(),str(layout.name)+": starting a new run clears manual rotation")
		board.queue_free()
		await process_frame
	# Equal elapsed time must yield the same orbit at different frame rates.
	root.size = Vector2i(1280,800)
	await process_frame
	var reference: Array[Vector2] = []
	for fps: int in [30,60,120]:
		var model = RunScript.new()
		model.new_run(784217,{})
		var board = CanvasBoard.new() if canvas else NativeBoard.new()
		root.add_child(board)
		board.setup(model)
		board.set_board_rect(Rect2(246,118,838,562))
		board.rotate_camera(PI/2.0)
		for frame: int in range(fps/2): board.tick(1.0/float(fps))
		if reference.is_empty(): reference = points(board)
		else: check(distance(reference,points(board))<0.05,"Orbit motion has the same half-second pose at %d FPS" % fps)
		board.queue_free()
		await process_frame
	await check_reset_motion()
	print("CAMERA_ORBIT_%s: %d checks, %d failures" % ["PASS" if failures==0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
