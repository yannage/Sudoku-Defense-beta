extends SceneTree
var failures: int = 0
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("exercise")
func exercise() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for i in range(3): await process_frame
	check(scene.menu_open,"Menu should open at launch")
	scene._close_overlay()
	check(scene.menu_open and not scene.has_active_run,"Closing initial menu must not silently start placeholder run")
	var panels: Array = []
	for node in scene.overlay.get_children():
		if node is PanelContainer:
			check(node.get_rect().end.y <= 800,"Launch menu must fit 800px height: %s" % node.get_rect())
			check(node.get_rect().end.x <= 1280,"Launch menu must fit viewport")
	scene.seed_input.text = "12345"
	scene._start_run()
	check(not scene.menu_open,"Starting game closes menu")
	check(scene.run.seed_value==12345,"Typed seed is applied")
	var cells: Array[int] = []
	for cell in range(81):
		if scene.run.board[cell]==0 and cells.size()<8: cells.append(cell)
	for cell in cells:
		scene._select(cell,false)
		scene._choose_number(scene.run.solution[cell])
	check(scene.run.towers.size()==8,"Number bar flow plants 8 towers")
	scene._select(cells[0],true)
	check(scene.dock.is_open(),"Click tower opens workshop")
	check(scene.dock.current_panel=="tower","Selected tower panel")
	scene.dock.close_panel()
	scene._advance()
	check(scene.run.phase=="prep","Prepare advances phase")
	var first_item = scene.run.items[0]
	scene.armed_item = str(first_item.id)
	scene._select(cells[0],false)
	check(scene.run.towers[cells[0]].attachments.size()==1,"Arm then select equips")
	var second_item: Dictionary = scene.run.items[0]
	var third_item: Dictionary = scene.run.items[1]
	scene.armed_item = str(second_item.id)
	var drop = scene.ui.get_child(0)
	drop._drop_data(scene.world.cell_screen_position(cells[0]),{"type":"attachment","item_id":str(third_item.id)})
	check(scene.run.towers[cells[0]].attachments.size()==2,"A drag equips only its payload even with another armed item")
	for kind in ["bag","tower","loot","camp"]:
		scene.dock.open_panel(kind,cells[0])
		await process_frame
		check(scene.dock._shell.get_global_rect().end.y <= 800,"Dock fits screen")
	scene.dock.close_panel()
	scene._advance()
	check(scene.run.phase=="battle","Launch wave advances phase")
	scene._toggle_dock("bag")
	var previous: float = scene.run.battle_time
	scene._process(.1)
	check(scene.run.battle_time==previous,"Inventory tactical pause holds battle")
	scene.dock.close_panel()
	scene._process(.05)
	check(scene.run.battle_time>previous,"Close inventory resumes battle")
	scene._save()
	check(scene._load(),"UI can save and resume model")
	scene._help()
	for i in range(2): await process_frame
	for node in scene.overlay.get_children():
		if node is PanelContainer: check(node.get_rect().end.y <= 800,"Help fits 800px height: %s"%node.get_rect())
	scene._close_overlay()
	scene.queue_free()
	await process_frame
	print("UI_FLOW_PASS" if failures==0 else "UI_FLOW_FAILURES: %d" % failures)
	quit(1 if failures>0 else 0)
