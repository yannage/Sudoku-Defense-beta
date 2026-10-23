extends SceneTree
## Pixel regression for the browser fallback. Requires a real GLES display.
## Passing with 3D disabled verifies that every gameplay voxel uses CanvasItem.
const BoardScript = preload("res://scripts/board_canvas.gd")
const RunScript = preload("res://scripts/run.gd")
const ChestScript = preload("res://scripts/chest_canvas.gd")
var failures: int = 0
var checks: int = 0
var output_dir: String = "res://build/render-checks"

func _initialize() -> void:
	call_deferred("exercise")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func frames(count: int, board = null) -> void:
	for i in range(count):
		if board != null: board.tick(1.0/60.0)
		await process_frame
	await RenderingServer.frame_post_draw

func capture(name: String) -> Image:
	var image: Image = root.get_texture().get_image()
	check(image != null and not image.is_empty(),"Framebuffer exists: "+name)
	if image != null and not image.is_empty():
		check(image.save_png(output_dir.path_join(name+".png")) == OK,"Save framebuffer: "+name)
	return image

func sample(image: Image, point: Vector2) -> Color:
	var scale: Vector2 = Vector2(image.get_size())/root.get_visible_rect().size
	var p: Vector2i = Vector2i(point*scale)
	return image.get_pixel(clampi(p.x,0,image.get_width()-1),clampi(p.y,0,image.get_height()-1))

func brightness(color: Color) -> float:
	return (color.r+color.g+color.b)/3.0

func check_board(board, model, image: Image, area: Rect2, solve: bool) -> void:
	for cell: int in range(81):
		var point: Vector2 = board.cell_screen_position(cell)
		check(area.has_point(point),"Cell %d fits board rectangle" % cell)
		if solve: check(board.cell_at_screen(point) == cell,"Cell %d round-trip picking" % cell)
		var surface: Vector3 = Vector3(float(cell%9)-3.68,0.0,float(cell/9)-3.73)
		var color: Color = sample(image,board.project_point(surface))
		check(brightness(color) > (0.47 if solve else 0.095),"Cell %d has visible tile color" % cell)
		if solve and int(model.board[cell]) > 0:
			var darkest: float = 1.0
			for x: int in range(-7,8,2):
				for y: int in range(-7,8,2):
					darkest = minf(darkest,brightness(sample(image,point+Vector2(x,y))))
			check(darkest < brightness(color)-0.15,"Cell %d digit has readable contrast" % cell)
	check(board.cell_at_screen(area.position-Vector2(10,10)) == -1,"HUD outside board is not a cell")

func assert_no_3d(node: Node) -> void:
	check(not node is Node3D and not node is SubViewport,"Canvas board has no 3D nodes or viewport texture dependency")
	for child: Node in node.get_children(): assert_no_3d(child)

func exercise() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Canvas render regression needs a real GL/GLES display; dummy cannot validate pixels.")
		quit(1)
		return
	root.disable_3d = true
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	root.size = Vector2i(1280,800)
	var model = RunScript.new()
	model.new_run(784217,{"mode":"campaign","puzzle_difficulty":"easy","combat_difficulty":"easy"})
	var board = BoardScript.new()
	root.add_child(board)
	board.setup(model)
	var area: Rect2 = Rect2(246,118,838,562)
	board.set_board_rect(area)
	board.set_selected(40,4)
	await frames(3,board)
	assert_no_3d(board)
	check(root.disable_3d,"All render checks run with viewport 3D disabled")
	check_board(board,model,capture("canvas-board-solve-deck"),area,true)
	root.size = Vector2i(600,1066)
	area = Rect2(16,218,568,568)
	board.set_board_rect(area)
	await frames(3,board)
	check_board(board,model,capture("canvas-board-solve-phone"),area,true)
	var planted: Array[int] = []
	for cell: int in range(81):
		if model.board[cell] == 0 and planted.size() < 14:
			model.place(cell,model.solution[cell])
			planted.append(cell)
	for i: int in range(3): model.equip_item(planted[0],str(model.items[0].id))
	model.advance_phase()
	for i: int in range(90): model.update(1.0/60.0)
	board.set_selected(planted[0],model.board[planted[0]])
	await frames(65,board)
	var image: Image = capture("canvas-board-prep-phone")
	check_board(board,model,image,area,false)
	for cell: int in planted:
		check(board.cell_at_screen(board.tower_screen_position(cell)) == cell,"Visible tower head %d is directly selectable" % cell)
		check(brightness(sample(image,board.tower_screen_position(cell))) > 0.18,"Tower %d has visible colored faces" % cell)
	var angle_before: Vector2 = board._axis_x
	root.size = Vector2i(1280,800)
	area = Rect2(246,118,838,562)
	board.set_board_rect(area)
	await frames(3,board)
	check(board._axis_x != angle_before,"Deck uses the wider tactical viewing angle")
	check_board(board,model,capture("canvas-board-prep-deck"),area,false)
	model.advance_phase()
	for i: int in range(180):
		model.update(1.0/60.0)
		for event: Dictionary in model.drain_events(): board.play_event(event)
		board.tick(1.0/60.0)
		if i%15 == 0: await process_frame
	check(not model.enemies.is_empty(),"Combat fixture spawns real moving enemies")
	board.play_event({"type":"shot","pos":Vector2(1,1),"target":Vector2(3,3),"color":Color("c6a0ff"),"kind":"electric","cell":planted[0]})
	board.play_event({"type":"explosion","pos":Vector2(4,5),"radius":1.2,"color":Color("ffb578")})
	board.play_event({"type":"fragment","pos":Vector2(5,4),"text":"+2 energy","color":Color("90f2c8")})
	await frames(2,board)
	capture("canvas-board-combat-deck")
	check(not board._effects.is_empty(),"Shots, impact cubes and reward effects are active")
	board.set_reduced_motion(true)
	check(board.reduced_motion,"Reduced-motion setting is accepted")
	await frames(70,board)
	check(board._effects.is_empty(),"Temporary effects expire and release their draw work")
	board.queue_free()
	await process_frame
	root.size = Vector2i(400,300)
	var chest = ChestScript.new()
	root.add_child(chest)
	chest.position = Vector2(20,20)
	chest.size = Vector2(360,250)
	chest.set_rarity("legendary")
	await frames(3)
	var chest_image: Image = capture("canvas-loot-chest")
	var colored: int = 0
	for x: int in range(60,341,5):
		for y: int in range(50,241,5):
			var c: Color = chest_image.get_pixel(x,y)
			if brightness(c) > 0.20 and maxf(c.r,maxf(c.g,c.b))-minf(c.r,minf(c.g,c.b)) > 0.07: colored += 1
	check(colored > 100,"Canvas chest has colored voxel faces and rarity trim")
	chest.queue_free()
	await process_frame
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size = Vector2i(1280,800)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await frames(6)
	scene.muted = true
	scene.sound.set_muted(true)
	scene.seed_input.text = "784217"
	scene._start_run()
	await frames(12)
	check(scene.world is DefenseCanvasBoard,"Integrated main chooses Canvas renderer with --canvas-graphics")
	if scene.world is DefenseCanvasBoard:
		check_board(scene.world,scene.run,capture("canvas-ui-solve-deck"),scene.board_rect,true)
		root.size = Vector2i(390,844)
		await frames(12)
		check_board(scene.world,scene.run,capture("canvas-ui-solve-phone"),scene.board_rect,true)
		for cell: int in range(81):
			if scene.run.board[cell] == 0 and scene.run.towers.size() < 12:
				scene._select(cell,false)
				scene._choose_number(scene.run.solution[cell])
		scene._advance()
		await frames(90)
		capture("canvas-ui-prep-phone")
	scene.queue_free()
	model = null
	await frames(3)
	print("CANVAS_RENDER_CHECKS: %d assertions, %d failures; 3D disabled = %s" % [checks,failures,root.disable_3d])
	if failures == 0: print("CANVAS_RENDER_PASS")
	quit(1 if failures else 0)
