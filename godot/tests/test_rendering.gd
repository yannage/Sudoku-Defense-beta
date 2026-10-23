extends SceneTree
## Real framebuffer regression. Run with GL/GLES + --safe-graphics, not --headless.
## Tests board pixels, numeral contrast, picking, framing, tower colors and chest.

const BoardScript = preload("res://scripts/board.gd")
const RunScript = preload("res://scripts/run.gd")
const ChestScript = preload("res://scripts/chest_stage.gd")
const VoxelMaterial = preload("res://scripts/voxel_material.gd")
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
		if board != null: board.tick(1.0 / 60.0)
		await process_frame
	await RenderingServer.frame_post_draw

func capture(name: String) -> Image:
	var image: Image = root.get_texture().get_image()
	check(image != null and not image.is_empty(), "Rendered framebuffer must contain pixels: " + name)
	if image != null and not image.is_empty():
		check(image.save_png(output_dir.path_join(name + ".png")) == OK, "Save renderer evidence: " + name)
	return image

func sample(image: Image, point: Vector2) -> Color:
	var scale: Vector2 = Vector2(image.get_size()) / root.get_visible_rect().size
	var p: Vector2i = Vector2i(point * scale)
	return image.get_pixel(clampi(p.x,0,image.get_width()-1), clampi(p.y,0,image.get_height()-1))

func brightness(color: Color) -> float:
	return (color.r + color.g + color.b) / 3.0

func check_board(board, model, image: Image, area: Rect2, solve: bool) -> void:
	for cell in range(81):
		var point: Vector2 = board.cell_screen_position(cell)
		check(area.has_point(point), "Cell %d is inside the usable board area" % cell)
		# Plane picking is deliberately checked on solve: battle chooses tall tops first.
		if solve: check(board.cell_at_screen(point) == cell, "Cell %d round-trip picking" % cell)
		var surface: Vector3 = Vector3(float(cell % 9)-3.72,0.02,float(cell / 9)-3.72)
		var pixel: Color = sample(image,board.camera.unproject_position(surface))
		check(brightness(pixel) > (0.48 if solve else 0.075), "Cell %d must render visible color, not black" % cell)
		if solve and model.board[cell] > 0:
			var darkest: float = 1.0
			for x in range(-8,9,2):
				for y in range(-8,9,2):
					darkest = minf(darkest, brightness(sample(image,point+Vector2(x,y))))
			check(darkest < brightness(pixel)-0.12, "Sudoku digit contrasts with cell %d" % cell)

func exercise() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Render regression requires a real GL/GLES display; dummy/headless cannot validate pixels.")
		quit(1)
		return
	check(VoxelMaterial.safe_profile(), "Run with --safe-graphics to exercise the exact web material profile")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280,800)
	var model = RunScript.new()
	model.new_run(784217,{"mode":"campaign","puzzle_difficulty":"easy","combat_difficulty":"easy"})
	var board = BoardScript.new()
	root.add_child(board)
	board.setup(model)
	var area := Rect2(246,118,838,562)
	board.set_board_rect(area)
	await frames(45,board)
	check(root.msaa_3d == Viewport.MSAA_DISABLED,"Web profile disables multisample 3D resolve")
	check(board._tile_mats[0] is ShaderMaterial,"Web profile uses the lightweight voxel shader")
	check_board(board,model,capture("board-solve-deck"),area,true)
	root.size = Vector2i(600,1066)
	area = Rect2(16,218,568,568)
	board.set_board_rect(area)
	await frames(10,board)
	check_board(board,model,capture("board-solve-phone"),area,true)
	var planted: Array[int] = []
	for cell in range(81):
		if model.board[cell] == 0 and planted.size() < 12:
			model.place(cell,model.solution[cell])
			planted.append(cell)
	for i in range(mini(model.items.size(),3)):
		model.equip_item(planted[0],str(model.items[0].id))
	model.advance_phase()
	# The fixture does not run the app loop; advance seed growth explicitly.
	for i in range(90): model.update(1.0 / 60.0)
	await frames(90,board)
	var battle_image: Image = capture("board-prep-phone")
	check_board(board,model,battle_image,area,false)
	var tower = board._tower_nodes[planted[0]]
	var top: Vector3 = tower.node.position + Vector3(0,tower.head.position.y+0.155,0)
	check(brightness(sample(battle_image,board.camera.unproject_position(top))) > 0.15,"Growing voxel tower retains a colored top")
	board.queue_free()
	await process_frame
	root.size = Vector2i(400,300)
	var chest = ChestScript.new()
	root.add_child(chest)
	chest.position = Vector2(20,20)
	chest.size = Vector2(360,250)
	chest.set_rarity("legendary")
	await frames(30)
	var chest_image: Image = capture("voxel-chest")
	var colored: int = 0
	for x in range(60,341,5):
		for y in range(50,241,5):
			var c: Color = chest_image.get_pixel(x,y)
			if brightness(c) > 0.20 and maxf(c.r,maxf(c.g,c.b))-minf(c.r,minf(c.g,c.b)) > 0.07: colored += 1
	check(colored > 100,"Voxel chest must contain visible colored faces and rarity trim")
	chest.queue_free()
	await process_frame
	# Capture the actual integrated HUD as review evidence at both target sizes.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size = Vector2i(1280,800)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await frames(6)
	# This is a renderer test with Dummy audio; do not leave asynchronous WAV
	# playback alive when the short-lived fixture tears its whole tree down.
	scene.muted = true
	scene.sound.set_muted(true)
	scene.seed_input.text = "784217"
	scene._start_run()
	await frames(20)
	check_board(scene.world,scene.run,capture("ui-solve-deck"),scene.board_rect,true)
	root.size = Vector2i(390,844)
	await frames(20)
	check_board(scene.world,scene.run,capture("ui-solve-phone"),scene.board_rect,true)
	for cell in range(81):
		if scene.run.board[cell] == 0 and scene.run.towers.size() < 12:
			scene._select(cell,false)
			scene._choose_number(scene.run.solution[cell])
	scene._advance()
	await frames(90)
	capture("ui-prep-phone")
	scene.queue_free()
	# Flush deferred Node/Signal cleanup before shutting the display server down.
	model = null
	tower.clear()
	await frames(3)
	print("RENDER_CHECKS: %d assertions, %d failures; safe profile = %s" % [checks,failures,VoxelMaterial.safe_profile()])
	if failures == 0: print("RENDER_PASS")
	quit(1 if failures else 0)
