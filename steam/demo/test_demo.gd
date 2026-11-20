extends SceneTree

var scene
var failures := 0

func _initialize() -> void:
	exercise.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func find_button(caption: String) -> Button:
	for item in scene.overlay.find_children("*","Button",true,false):
		if item.text == caption: return item
	return null

func finish_wave() -> void:
	for i in range(10000):
		if scene.run.phase != "battle": break
		scene.run.update(0.05)

func plant_towers(count: int) -> void:
	for cell in range(81):
		if scene.run.towers.size() >= count: return
		if scene.run.board[cell] == 0:
			scene._action(scene.run.place(cell,scene.run.solution[cell]))

func exercise() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	check(OS.get_user_data_dir().get_file() == "Sudoku Defense Demo","Separate demo data directory")
	check(not Engine.has_singleton("Steam") and not scene.steam_platform.get_status().available,"Demo has no Steam SDK or authenticated account")
	check(find_button("Play the guided first wave") != null and find_button("Settings") != null,"Try the guide or open settings from launch")
	scene._start_demo_guide()
	await process_frame
	check(scene.tutorial.active and scene.run.max_rounds == 1,"Guided real wave is capped at round one")
	for i in range(2):
		var cell: int = scene.tutorial.target_cell
		scene._action(scene.run.place(cell,scene.run.solution[cell]))
		scene.tutorial.observe()
	scene._advance()
	check(scene.run.phase == "prep","Planting real answers unlocks preparation")
	scene._action(scene.run.equip_item(scene.run.towers.keys()[0],scene.run.items[0].id))
	scene.tutorial.observe()
	scene._advance()
	check(scene.run.phase == "battle","A fitted tower can launch")
	finish_wave()
	check(scene.run.phase == "won","Guided battle ends at wave one")
	scene.tutorial.observe()
	var cheapest: Dictionary = scene.run.chests[0]
	for chest: Dictionary in scene.run.chests:
		if int(chest.cost) < int(cheapest.cost): cheapest = chest
	check(scene.run.open_chest(cheapest.id).ok,"Reward opens after guided wave")
	for event in scene.run.drain_events(): scene.tutorial.event_seen(event)
	scene.tutorial.observe()
	check(scene.tutorial.step == 7,"Wave and reward completed")
	scene.tutorial.finish()
	check(find_button("Play a fresh board") != null,"Completion leads directly to replay")
	check(find_button("Buy or wishlist on Steam") != null,"Full game is available from result")
	scene._start_fresh_board()
	var first_seed: int = scene.run.seed_value
	check(not scene.tutorial.active and scene.run.mode == "freeplay" and scene.run.solve_pace == "untimed","Replay uses one-wave untimed free play")
	plant_towers(10)
	scene._advance()
	scene._advance()
	finish_wave()
	scene._show_result()
	check(scene.run.phase == "won" and find_button("Play a fresh board") != null,"Replay victory ends the demo")
	scene._start_fresh_board()
	check(scene.run.seed_value != first_seed,"Replaying produces a fresh puzzle")
	check(scene.run.achievement_stats.run_id.is_empty(),"Demo replay produces no eligible achievements")
	scene._show_demo_end(false,0)
	check(find_button("Buy or wishlist on Steam") != null,"A loss also offers replay and the full game")
	scene._save()
	check(not scene.run_save.has_save() and not FileAccess.file_exists("user://sudoku-defense-achievements.json"),"Demo writes no run or achievement files")
	scene.queue_free()
	await process_frame
	if failures == 0: print("DEMO_FLOW_PASS")
	quit(1 if failures else 0)
