extends SceneTree
## Marketing-only capture of the shipping scene and simulation. Every tower,
## item, upgrade and chest is earned through public DefenseRun actions. The
## seeded solver is an automated player, not modified combat or reward rules.
## Run with --fixed-fps 30 --write-movie capture.avi; --stills-only is a proof.
const Run = preload("res://scripts/run.gd")
var scene
var output := "res://../release/marketing"
var footage_frame := 0
var steps: Array[Dictionary] = []
var cells: Array[int] = []
var stills_only := false

func _initialize() -> void:
	call_deferred("capture_run")

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		footage_frame += 1

func mark(name: String) -> void:
	var rendered_frame := Engine.get_frames_drawn()
	steps.append({"name":name,"frame":rendered_frame,"seconds":float(rendered_frame)/30.0})
	print("CAPTURE_MARK ", name," ",rendered_frame)

func still(name: String) -> void:
	await RenderingServer.frame_post_draw
	var shot: Image = root.get_texture().get_image()
	shot.save_png(output+"/"+name+".png")

func earn_run() -> RefCounted:
	var run = Run.new()
	run.new_run(784217,{"mode":"campaign","puzzle_difficulty":"medium","combat_difficulty":"easy"})
	for round_index in range(9):
		for cell in range(81):
			if run.board[cell] == 0: assert(run.place(cell,run.solution[cell]).ok)
		var tower_keys: Array = run.towers.keys()
		var equip_index := 0
		for item in run.items.duplicate():
			if item.type == "attachment":
				var target: int = int(tower_keys[equip_index % tower_keys.size()])
				if run.towers[target].attachments.size() < 5:
					assert(run.equip_item(target,item.id).ok)
					equip_index += 1
		assert(run.advance_phase().ok)
		assert(run.advance_phase().ok)
		var ticks := 0
		while run.phase == "battle" and ticks < 12000:
			run.update(0.05)
			run.drain_events()
			ticks += 1
		assert(run.phase == "loot", "Seeded player must legitimately clear each warmup round")
		for chest in run.chests.duplicate():
			if run.fragments >= int(chest.cost): run.open_chest(chest.id)
		if round_index == 8:
			assert(run.buy_chest("legendary").ok)
			assert(run.buy_chest("rare").ok)
		assert(run.next_round({"puzzle_difficulty":"medium","combat_difficulty":"medium" if round_index == 8 else "easy"}).ok)
	run.drain_events()
	return run

func by_id(id: String) -> Button:
	for node in scene.dock.find_children("*","Button",true,false):
		if node.is_visible_in_tree() and str(node.get_meta("focus_id","")) == id: return node
	return null

func mouse(point: Vector2, down: bool) -> void:
	var physical: Vector2 = root.get_final_transform()*point
	Input.warp_mouse(physical)
	var event := InputEventMouseButton.new()
	event.position = physical
	event.global_position = physical
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func motion(point: Vector2, relative: Vector2, held := false) -> void:
	var physical: Vector2 = root.get_final_transform()*point
	Input.warp_mouse(physical)
	var event := InputEventMouseMotion.new()
	event.position = physical
	event.global_position = physical
	event.relative = root.get_final_transform().basis_xform(relative)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func drag(item_id: String, cell: int) -> void:
	var card: Button = by_id("item:"+item_id)
	assert(is_instance_valid(card), "Visible module card required")
	var ancestor: Node = card.get_parent()
	while ancestor:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(card)
		ancestor = ancestor.get_parent()
	await frames(3)
	var start: Vector2 = card.get_global_rect().get_center()
	var end: Vector2 = scene.world.cell_screen_position(cell)
	mouse(start,true)
	await frames(2)
	var previous := start
	for i in range(32):
		var t := float(i+1)/32.0
		var point := start.lerp(end,smoothstep(0.0,1.0,t)) + Vector2(0,-sin(t*PI)*40.0)
		motion(point,point-previous,true)
		previous = point
		await frames(1)
	assert(root.gui_is_dragging(), "Capture real Godot icon drag")
	await still("03-equip-modules")
	await frames(10)
	mouse(end,false)
	await frames(24)

func capture_run() -> void:
	stills_only = "--stills-only" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1920,1080)
	root.position = Vector2i.ZERO
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await frames(10)
	scene.has_active_run = true
	scene._close_overlay()
	scene.run = earn_run()
	scene.world.setup(scene.run)
	scene.dock.run = scene.run
	scene.last_phase = scene.run.phase
	scene.muted = false
	scene.sound.set_muted(false)
	scene.sound.set_music_enabled(false)
	# Capture commands use an isolated XDG_DATA_HOME profile.
	scene.save_elapsed = -100000.0
	var blanks: Array[int] = []
	for cell in range(81):
		if scene.run.board[cell] == 0: blanks.append(cell)
	# Spread choices across the board instead of scanning only its first row.
	blanks.sort_custom(func(a: int,b: int): return ((a*37)%83)<((b*37)%83))
	for index in range(6):
		var cell: int = blanks[index]
		assert(scene.run.place(cell,scene.run.solution[cell]).ok)
		cells.append(cell)
	scene._refresh()
	await frames(30)
	mark("solve")
	for index in range(6,14):
		var cell: int = blanks[index]
		scene.selected_number = scene.run.solution[cell]
		scene._select(cell,false,false)
		await frames(7 if not stills_only else 1)
		scene._action(scene.run.place(cell,scene.run.solution[cell]))
		cells.append(cell)
		await frames(18 if not stills_only else 2)
		if index == 9: await still("01-solve-the-grid")
	await frames(20)
	mark("transform")
	scene._advance()
	await frames(65 if not stills_only else 30)
	await still("02-build-your-defense")
	# Put legitimately earned varied modules onto a compact set of towers.
	var selected_items: Array[Dictionary] = []
	for kind in ["blast","frost","electric","rapid","venom","power","gravity","nova"]:
		for item in scene.run.items:
			if item.kind == kind:
				selected_items.append(item)
				break
	for index in range(maxi(0,selected_items.size()-2)):
		assert(scene.run.equip_item(cells[(index*3)%cells.size()],selected_items[index].id).ok)
	for cell in cells.slice(0,4): scene.run.upgrade_tower(cell)
	scene._refresh()
	mark("gear")
	scene.dock.open_panel("bag",cells[4])
	await frames(20)
	for index in range(maxi(0,selected_items.size()-2),selected_items.size()):
		await drag(str(selected_items[index].id),cells[4])
	await frames(20)
	scene.dock.close_panel()
	await frames(12)
	mark("battle")
	scene._advance()
	# Native 1x simulation for real projectiles, aiming and drops.
	for i in range(18*30 if not stills_only else 6*30):
		await frames(1)
		if i == 90: await still("04-defend-the-route")
		if i == 180: await still("05-defend-your-towers")
		if i == 270: await still("08-combat-effects")
	mark("battle_end")
	# Finish the earned wave off camera. No altered health, damage or loot.
	if scene.dock.is_open(): scene.dock.close_panel()
	while scene.run.phase == "battle":
		scene.run.update(0.1)
		scene.run.drain_events()
	assert(scene.run.phase == "loot", "Feature round must be won")
	scene.last_phase = "loot"
	scene._refresh()
	mark("loot")
	scene.dock.open_panel("loot",cells[4])
	await frames(40)
	await still("06-open-earned-chests")
	var chosen: Dictionary = {}
	for chest in scene.run.chests:
		if chest.rarity == "legendary": chosen = chest
	assert(not chosen.is_empty(), "Use the legendary chest purchased with earned credits")
	scene.dock._loot_table.open_chest(chosen.id)
	await frames(38)
	await still("07-loot-reveal")
	await frames(100 if not stills_only else 5)
	mark("end")
	var manifest := {"engine":Engine.get_version_info().string,"version":ProjectSettings.get_setting("application/config/version"),"seed":784217,"round":scene.run.round_no,"resolution":[1920,1080],"fps":30,"timeline":steps,"provenance":"Real shipping native Godot scene. Seeded automated solves; first nine rounds simulated through public gameplay actions. No altered damage, enemy stats, rewards, inventory or visual renderer. Legendary chest purchased with earned credits."}
	var file := FileAccess.open(output+"/capture-manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"  "))
	print("MARKETING_CAPTURE_PASS")
	quit()
