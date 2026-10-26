extends SceneTree
## Regress enemy health at every camera quadrant and when the creature turns.
## Runs headlessly for geometry; with GLES also checks actual fill pixels.

const NativeBoard = preload("res://scripts/board.gd")
const CanvasBoard = preload("res://scripts/board_canvas.gd")
const RunScript = preload("res://scripts/run.gd")
const Health = preload("res://scripts/enemy_health.gd")
var checks := 0
var failures := 0
var canvas := false

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func projected_rect(board, enemy: Dictionary) -> Rect2:
	if canvas:
		var center: Vector2 = board.project_point(Vector3(enemy.pos.x-4.0,Health.height_for(enemy.kind),enemy.pos.y-4.0))
		return Health.canvas_rects(center,board._scale,enemy.kind,Health.ratio(enemy)).track
	var bar: MeshInstance3D = board._enemy_nodes[enemy.id].bar
	var size: Vector2 = bar.mesh.size
	var top_left: Vector2 = board.camera.unproject_position(bar.to_global(Vector3(-size.x*0.5,size.y*0.5,0)))
	var bottom_right: Vector2 = board.camera.unproject_position(bar.to_global(Vector3(size.x*0.5,-size.y*0.5,0)))
	return Rect2(top_left,bottom_right-top_left)

func matches_color(actual: Color, expected: Color) -> bool:
	# Canvas rectangles are opaque and pixel-snapped. Allow only byte rounding,
	# not other warm scene art such as the route or the runner's orange shell.
	var tolerance := 1.5/255.0
	return absf(actual.r-expected.r)<=tolerance and absf(actual.g-expected.g)<=tolerance and absf(actual.b-expected.b)<=tolerance

func check_pixels(board, enemy: Dictionary, label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image != null and not image.is_empty(),label+": actual framebuffer exists")
	if image == null or image.is_empty(): return
	var rect := projected_rect(board,enemy)
	var ratio := Health.ratio(enemy)
	var y := floori(rect.get_center().y)
	var bright: Array[int] = []
	for x in range(floori(rect.position.x)-2,ceili(rect.end.x)+2):
		var pixel := image.get_pixel(clampi(x,0,image.get_width()-1),clampi(y,0,image.get_height()-1))
		var is_fill := matches_color(pixel,Health.color_for(ratio)) if canvas else pixel.r > 0.65 and pixel.r > pixel.b*1.15
		if is_fill:
			bright.append(x)
	if canvas:
		# Verify the whole actual bar, including every border pixel and the empty
		# portion. The old scan accepted any warm pixel, so route arrows just
		# outside a correct bar looked like overflowing or residual health.
		var parts := Health.canvas_rects(rect.get_center(),board._scale,enemy.kind,ratio)
		var mismatch := ""
		for row in range(int(rect.position.y),int(rect.end.y)):
			for column in range(int(rect.position.x),int(rect.end.x)):
				var expected: Color = Health.color_for(ratio) if (parts.fill as Rect2).has_point(Vector2(column+0.5,row+0.5)) else Health.TRACK
				var actual := image.get_pixel(column,row)
				if not matches_color(actual,expected) and mismatch.is_empty():
					mismatch = " at (%d,%d): %s instead of %s" % [column,row,actual.to_html(),expected.to_html()]
		check(mismatch.is_empty(),label+": every fill, empty-track, and border pixel matches"+mismatch)
	if ratio == 0.0:
		check(bright.is_empty(),label+": zero health has no residual foreground sliver")
	else:
		check(not bright.is_empty(),label+": foreground renders")
		if not bright.is_empty():
			check(float(bright[0]) >= rect.position.x-0.5 and float(bright[-1]) < rect.end.x,label+": foreground stays inside the track")
			check(absf(float(bright[0])-rect.position.x)<=2.5,label+": foreground remains anchored at the left inset")
			var border_px := maxf(1.0,Health.BORDER*rect.size.x/Health.size_for(enemy.kind).x)
			var expected_end := rect.position.x+border_px+(rect.size.x-2.0*border_px)*ratio
			check(absf(float(bright[-1])+1.0-expected_end)<=2.0,label+": visible fill matches the health fraction")
	if ratio == 0.5:
		var path := "res://build/health-checks/%s-%s.png" % ["canvas" if canvas else "native",label]
		check(image.save_png(path)==OK,label+": save visual evidence")

func exercise() -> void:
	canvas = "--canvas-graphics" in OS.get_cmdline_user_args()
	root.disable_3d = canvas
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280,800)
	var render := DisplayServer.get_name() != "headless"
	if render: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/health-checks"))
	var model = RunScript.new()
	model.new_run(784217,{})
	model.phase = "battle"
	model.enemies.clear()
	model.drain_events()
	var board = CanvasBoard.new() if canvas else NativeBoard.new()
	root.add_child(board)
	board.setup(model)
	board.set_reduced_motion(true)
	board.set_board_rect(Rect2(246,118,838,562))
	for kind: String in ["runner","boss"]:
		var enemy := {"id":1 if kind == "runner" else 2,"kind":kind,"pos":Vector2(4,4),"hp":100.0,"max_hp":100.0}
		model.enemies.assign([enemy])
		for turn in range(8):
			board.rotate_camera(PI*0.25)
			for frame in range(20): board.tick(1.0/60.0)
			var fixed_size := Vector2.ZERO
			for amount: float in [1.0,0.5,0.0]:
				enemy.hp = amount*100.0
				# Force a different movement heading to detect inherited bar rotation.
				enemy.pos += Vector2(0.01 if turn%2==0 else 0.0,0.0 if turn%2==0 else 0.01)
				board.tick(1.0/60.0)
				var label := "%s-yaw%d-hp%d" % [kind,turn*45,roundi(amount*100)]
				var track := projected_rect(board,enemy)
				check(track.size.x>8.0 and track.size.y>1.0,label+": track remains readable, horizontal, and front-facing")
				if fixed_size == Vector2.ZERO: fixed_size = track.size
				else: check(track.size.distance_to(fixed_size)<0.01,label+": damage never scales or shifts the track")
				if canvas:
					var parts := Health.canvas_rects(track.get_center(),board._scale,kind,amount)
					var fill: Rect2 = parts.fill
					var inner: Rect2 = parts.inner
					check(fill.position == inner.position and fill.end.x<=inner.end.x,label+": foreground shares the inset track origin")
					check(fill.position.y>track.position.y and fill.end.y<track.end.y,label+": matching top and bottom inset")
					if amount == 0.0: check(fill.size.x == 0.0,label+": empty means no fill")
				else:
					var bar: MeshInstance3D = board._enemy_nodes[enemy.id].bar
					check(bar.mesh is QuadMesh and bar.get_child_count()==0,label+": foreground and track share one surface")
					check(bar.global_basis.x.dot(board.camera.global_basis.x)>0.99999 and bar.global_basis.y.dot(board.camera.global_basis.y)>0.99999,label+": bar follows camera axes, never enemy heading")
					check(is_equal_approx(float(bar.material_override.get_shader_parameter("fill_ratio")),amount),label+": actual material receives exact health")
				if render: await check_pixels(board,enemy,label)
	# Defensive bounds matter during hit/death updates and over-healing.
	check(Health.ratio({"hp":-20,"max_hp":100})==0.0,"Negative damage remainder clamps to empty")
	check(Health.ratio({"hp":200,"max_hp":100})==1.0,"Over-healing cannot spill past the track")
	board.queue_free()
	await process_frame
	print("ENEMY_HEALTH_%s: %d checks, %d failures; canvas=%s; pixels=%s" % ["PASS" if failures==0 else "FAIL",checks,failures,canvas,render])
	quit(1 if failures else 0)
