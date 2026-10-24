extends SceneTree
## Real Deck-sized framebuffer checks for default native lighting and canvas.
## Optional: --fixed-fps 60 --write-movie /path/to/readability.avi
## Does not accept dummy/headless rendering as evidence of visual quality.

const NativeBoard = preload("res://scripts/board.gd")
const CanvasBoard = preload("res://scripts/board_canvas.gd")
const RunScript = preload("res://scripts/run.gd")
var checks := 0
var failures := 0
var canvas := false
var output_dir := "res://build/readability-checks"
var metrics: Dictionary = {}

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count: int, board = null, model = null) -> void:
	for index in range(count):
		if model != null:
			model.update(1.0/60.0)
			for event: Dictionary in model.drain_events(): board.play_event(event)
		if board != null: board.tick(1.0/60.0)
		await process_frame
	await RenderingServer.frame_post_draw

func capture(name: String) -> Image:
	var result: Image = root.get_texture().get_image()
	check(result != null and not result.is_empty(), "Real framebuffer: " + name)
	if result != null and not result.is_empty():
		check(result.save_png(output_dir.path_join(("canvas-" if canvas else "native-")+name+".png")) == OK, "Save evidence: " + name)
	return result

func project(board, point: Vector3) -> Vector2:
	return board.project_point(point) if canvas else board.camera.unproject_position(point)

func sample(image: Image, point: Vector2) -> Color:
	return image.get_pixel(clampi(roundi(point.x),0,image.get_width()-1),clampi(roundi(point.y),0,image.get_height()-1))

func luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return linear.r*0.2126 + linear.g*0.7152 + linear.b*0.0722

func contrast(a: Color, b: Color) -> float:
	var low := minf(luminance(a),luminance(b))
	var high := maxf(luminance(a),luminance(b))
	return (high+0.05)/(low+0.05)

func cell_origin(cell: int) -> Vector3:
	return Vector3(float(cell%9)-4.0,0,float(cell/9)-4.0)

func blank(model, skip: Array[int] = []) -> int:
	for cell in [40,10,16,64,70,22,58]+range(81):
		if model.board[cell] == 0 and cell not in skip: return cell
	return -1

func events(model, board) -> void:
	for event: Dictionary in model.drain_events(): board.play_event(event)

func check_solve(board, model, image: Image) -> void:
	var tile_values: Array[float] = []
	var lowest_ratio := INF
	for cell in range(81):
		var floor_color := sample(image,project(board,cell_origin(cell)+Vector3(0.28,0.02,0.28)))
		tile_values.append((floor_color.r+floor_color.g+floor_color.b)/3.0)
		if model.board[cell] <= 0: continue
		var center: Vector2 = board.cell_screen_position(cell)
		var ink := floor_color
		# Read the core of a digit, excluding the tile borders and antialias fringe.
		for x in range(-9,10):
			for y in range(-12,13):
				var pixel := sample(image,center+Vector2(x,y))
				if luminance(pixel) < luminance(ink): ink = pixel
		var ratio := contrast(floor_color,ink)
		lowest_ratio = minf(lowest_ratio,ratio)
		check(ratio >= 4.5,"Solve digit %d has at least 4.5:1 contrast (%.2f)" % [cell,ratio])
	tile_values.sort()
	var median := tile_values[tile_values.size()/2]
	metrics.solve_tile_median = median
	metrics.solve_min_digit_contrast = lowest_ratio
	# Protect against both the original nearly-white board and an unreadable dark one.
	check(median >= 0.40 and median <= 0.86,"Solve tiles keep a middle value instead of near-white glare (%.3f)" % median)
	check(tile_values[-1] < 0.94,"No plain solve tile clips toward white (%.3f)" % tile_values[-1])

func check_towers(board, model, image: Image, planted: Array[int]) -> void:
	var smallest_contrast := INF
	var largest_roof_brightness := 0.0
	var smallest_chroma := INF
	for cell in planted:
		var head_height := 0.625
		if not canvas: head_height = float(board._tower_nodes[cell].head.position.y)+0.155
		# Sample the colored top at its center, with no badge or muzzle flash over it.
		var roof := sample(image,project(board,cell_origin(cell)+Vector3(0,head_height,0)))
		var floor_color := sample(image,project(board,cell_origin(cell)+Vector3(-0.38,0.02,0.36)))
		var ratio := contrast(roof,floor_color)
		var brightness := (roof.r+roof.g+roof.b)/3.0
		var chroma := maxf(roof.r,maxf(roof.g,roof.b))-minf(roof.r,minf(roof.g,roof.b))
		smallest_contrast = minf(smallest_contrast,ratio)
		largest_roof_brightness = maxf(largest_roof_brightness,brightness)
		smallest_chroma = minf(smallest_chroma,chroma)
		check(ratio >= 2.0,"Tower %d separates from its floor (%.2f:1)" % [cell,ratio])
		check(brightness < 0.94,"Tower %d roof retains highlight headroom (%.3f)" % [cell,brightness])
		check(chroma > 0.045,"Tower %d keeps its family color instead of washing white (%.3f)" % [cell,chroma])
	metrics.tower_min_floor_contrast = smallest_contrast
	metrics.tower_max_roof_brightness = largest_roof_brightness
	metrics.tower_min_roof_chroma = smallest_chroma

func exercise() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Readability requires an actual GLES framebuffer, not --headless.")
		quit(1)
		return
	canvas = "--canvas-graphics" in OS.get_cmdline_user_args()
	check("--safe-graphics" not in OS.get_cmdline_user_args(),"Native test must exercise shipping lighting, not safe materials")
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
	await frames(8,board)
	var baseline := capture("01-solve-deck")
	check_solve(board,model,baseline)
	var planted: Array[int] = []
	for index in range(4):
		var cell := blank(model,planted)
		planted.append(cell)
		check(model.place(cell,model.solution[cell]).ok,"Place seed for visible capture")
		events(model,board)
		await frames(7,board)
		if index == 0: capture("02-seed-approach")
		await frames(10,board)
		if index == 0: capture("03-seed-impact")
		await frames(8,board)
		if index == 0: capture("04-seed-reveal")
		await frames(24,board)
	check_solve(board,model,capture("05-solved-seeds"))
	check(board._seed_plantings.is_empty(),"All seed presentations clean up before the phase change")
	# Sparse, separated towers keep samples clear of occlusion by neighbors.
	check(model.advance_phase().ok,"Prepare the defense")
	events(model,board)
	await frames(90,board,model)
	var prep := capture("06-prepare-deck")
	check_towers(board,model,prep,planted)
	check(model.advance_phase().ok,"Start a real wave for visual evidence")
	events(model,board)
	await frames(90,board,model)
	capture("07-battle-deck")
	var file := FileAccess.open(output_dir.path_join(("canvas" if canvas else "native")+"-metrics.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
	board.queue_free()
	await process_frame
	print("READABILITY_METRICS ",JSON.stringify(metrics))
	print("READABILITY_CHECKS: %d assertions, %d failures; canvas=%s" % [checks,failures,canvas])
	if failures == 0: print("READABILITY_PASS")
	quit(1 if failures else 0)
