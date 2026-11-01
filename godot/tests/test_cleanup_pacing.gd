extends SceneTree
## Optional late-wave acceleration: production scene, native input, exact calls.
## Synthetic combat fixtures isolate boundaries; earned campaign balance is
## measured separately. --render-check rejects headless rendering.
const Run = preload("res://scripts/run.gd")
const Loot = preload("res://scripts/loot.gd")
const DEVICE := 43

class CountedRun extends "res://scripts/run.gd":
	var calls: Array[float] = []
	func update(dt: float) -> void:
		calls.append(dt)
		super.update(dt)

var scene
var original_run
var checks := 0
var failures := 0
var rendered := false
var variant := "native"
var output := "res://build/cleanup-pacing-checks"
var profile := "user://cleanup-pacing-%d" % Time.get_ticks_usec()

func _initialize() -> void:
	Engine.max_fps = 120
	rendered = "--render-check" in OS.get_cmdline_user_args()
	variant = "canvas" if "--canvas-graphics" in OS.get_cmdline_user_args() else "native"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	if rendered and DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_MINIMIZED
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 3) -> void:
	for index in range(count):
		if is_instance_valid(scene): scene.world.tick(1.0/60.0)
		await process_frame
		if rendered: RenderingServer.force_draw(false)

func press(index: int) -> void:
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device = DEVICE
		event.button_index = index
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(1 if down else 3)

func key(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event,true)
		await frames(1)

func click(point: Vector2) -> void:
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.position = point
		event.global_position = point
		event.pressed = down
		root.push_input(event,true)
		await frames(1)

func fixture(enemy_count := 2, hp := 5000.0) -> void:
	scene.run = original_run
	scene.tutorial.active = false
	scene.dock.reset_for_run()
	scene.manual_pause = false
	scene.armed_item = ""
	scene._close_controller_numbers()
	scene._cancel_camera_controls()
	scene.run.new_run(2046,{"mode":"freeplay","puzzle_difficulty":"medium","combat_difficulty":"easy"})
	var planted := 0
	for offset in range(81):
		var cell := (offset*37)%81
		if scene.run.board[cell] != 0: continue
		check(scene.run.place(cell,scene.run.solution[cell]).ok,"Fixture places a legal Sudoku answer")
		planted += 1
		if planted == 18: break
	check(scene.run.advance_phase().ok and scene.run.advance_phase().ok,"Fixture enters battle using ordinary actions")
	# Place a small deterministic tail on a legal route. This is a synthetic
	# boundary fixture, not evidence for human difficulty or a viable build.
	scene.run.spawned = scene.run.spawn_total-enemy_count
	scene.run.enemies.clear()
	for index in range(enemy_count):
		scene.run._spawn()
		var enemy: Dictionary = scene.run.enemies.back()
		enemy.hp = hp
		enemy.max_hp = hp
		enemy.progress = scene.run.route_length*0.45+index*0.3
		enemy.pos = scene.run.position_on_route(enemy.progress)
		enemy.speed = 0.15
	for tower in scene.run.towers.values(): tower.growth = 1.0
	scene.run.battle_time = 60.0
	scene.run.timer = 60.0
	scene.run.drain_events()
	scene.has_active_run = true
	scene.last_phase = "battle"
	scene.game_speed = 1.0
	scene.cleanup_fast = false
	scene.selected_cell = int(scene.run.towers.keys()[0])
	scene.selected_number = 0
	scene._close_overlay()
	scene.world.setup(scene.run)
	scene.world.set_selected(scene.selected_cell,0)
	scene._refresh()

func eligibility() -> void:
	fixture()
	check(scene._cleanup_available(),"All spawned, living enemies, and 60 seconds allow optional acceleration")
	scene.run.battle_time = 44.99
	check(not scene._cleanup_available(),"Acceleration is unavailable before 45 battle seconds")
	scene.run.battle_time = 45.0
	check(scene._cleanup_available(),"Acceleration becomes available at 45 battle seconds")
	scene.run.spawned -= 1
	check(not scene._cleanup_available(),"Unspawned enemies keep acceleration unavailable")
	scene.run.spawned += 1
	scene.run.spawn_total = 0
	check(not scene._cleanup_available(),"An uninitialized wave cannot accelerate")
	fixture(4)
	check(scene._cleanup_available(),"Availability does not claim a tail with four living enemies is safe")
	scene.run.enemies.clear()
	check(not scene._cleanup_available(),"Empty waves cannot enable acceleration")
	fixture()
	for phase in ["solve","prep","loot","won","lost"]:
		scene.run.phase = phase
		check(not scene._cleanup_available(),"Acceleration is exclusive to battle: "+phase)
	scene.run.phase = "battle"
	scene.tutorial.active = true
	check(not scene._cleanup_available(),"Guided practice keeps its existing battle pacing")
	scene.tutorial.active = false

func input_flow() -> void:
	fixture()
	await frames()
	check(not scene.next_button.disabled and scene.next_button.text.contains("8x"),"Eligible board exposes a usable fast-forward action")
	var selected: int = scene.selected_cell
	await capture("available")
	await press(JOY_BUTTON_Y)
	check(scene.cleanup_fast and scene.hud_nodes.speed.text == "8x","Controller Y starts visible 8x acceleration")
	check(scene.selected_cell == selected,"Starting acceleration preserves the selected tower")
	await capture("active")
	await press(JOY_BUTTON_Y)
	check(not scene.cleanup_fast and scene.hud_nodes.speed.text == "1x","Second Y returns to ordinary selected speed")
	await capture("stopped")
	await press(JOY_BUTTON_Y)
	await press(JOY_BUTTON_B)
	check(not scene.cleanup_fast and scene.selected_cell == selected,"Free-board B stops acceleration and keeps useful board selection")
	await key(KEY_ENTER)
	check(scene.cleanup_fast,"Enter starts the same explicit acceleration action")
	await click(scene.next_button.get_global_rect().get_center())
	check(not scene.cleanup_fast,"Pointer can stop acceleration after keyboard/controller input")
	await click(scene.next_button.get_global_rect().get_center())
	check(scene.cleanup_fast,"Pointer can start acceleration once")
	await click(scene.hud_nodes.speed.get_global_rect().get_center())
	check(not scene.cleanup_fast and scene.game_speed == 2.0,"Ordinary speed button cancels acceleration and retains 1/2/4 cycle")
	scene.run.battle_time = 20.0
	scene._refresh()
	await press(JOY_BUTTON_Y)
	check(not scene.cleanup_fast and scene.next_button.disabled,"Early battle Y cannot silently accelerate or advance phase")
	fixture()
	scene.save_failed = true
	scene._toast("PROGRESS NOT SAVED. Open Menu to retry saving.",false)
	scene._toggle_cleanup()
	check(scene.notice.text.begins_with("PROGRESS NOT SAVED") and scene.hud_nodes.menu.text == "Save!","Fast-forward feedback preserves the existing save-failure warning")
	scene.save_failed = false

func context_gates() -> void:
	for context in ["menu","pause","dock","armed","camera","numbers"]:
		fixture()
		scene._toggle_cleanup()
		check(scene.cleanup_fast,"Fixture starts acceleration for context "+context)
		match context:
			"menu": scene._show_menu(false)
			"pause": scene.manual_pause = true
			"dock": scene.dock.open_panel("bag",scene.selected_cell)
			"armed": scene.armed_item = "synthetic-pending-module"
			"camera": scene._set_camera_mode(true)
			"numbers":
				for cell in range(81):
					if scene.run.board[cell] == 0:
						scene.run.inventory[int(scene.run.solution[cell])] = 2
						scene._select(cell,false,false)
						check(scene._open_controller_numbers(cell),"Battle reserve-number picker opens")
						break
		var before: float = scene.run.battle_time
		scene._process(0.02)
		check(not scene.cleanup_fast,"Entering "+context+" cancels temporary acceleration")
		if context in ["menu","pause","dock","armed"]:
			check(is_equal_approx(scene.run.battle_time,before),context+" blocks every combat update")
		else:
			check(scene.run.battle_time-before <= 0.020001,context+" uses at most ordinary speed")
		if context == "menu":
			await capture("paused")
			await press(JOY_BUTTON_Y)
			check(not scene.cleanup_fast and scene.menu_open,"Y cannot accelerate behind an overlay")
		elif context == "dock":
			await press(JOY_BUTTON_Y)
			check(not scene.cleanup_fast and scene.dock.is_open(),"Y cannot accelerate behind the workshop")
		elif context == "camera":
			await press(JOY_BUTTON_Y)
			check(not scene.cleanup_fast and scene.camera_mode,"Camera mode retains Y isolation")
		elif context == "numbers":
			await press(JOY_BUTTON_B)
			check(scene._controller_number_cell < 0 and not scene.cleanup_fast,"B exits number picker before any battle action")
	fixture()
	scene._toggle_cleanup()
	scene._controller_disconnected()
	scene._process(0.02)
	check(scene.menu_open and not scene.cleanup_fast,"Controller disconnect pauses and disarms acceleration")
	fixture()
	scene.run.phase = "prep"
	scene.last_phase = "prep"
	await press(JOY_BUTTON_Y)
	check(scene.run.phase == "battle" and not scene.cleanup_fast,"Y still launches a prepared wave at ordinary speed")
	fixture()
	scene.run.phase = "solve"
	scene.last_phase = "solve"
	scene.game_speed = 4.0
	scene.cleanup_fast = true
	var before: float = scene.run.timer
	scene._process(0.05)
	check(not scene.cleanup_fast and is_equal_approx(before-scene.run.timer,0.05),"Phase reset clears cleanup and solve countdown remains 1x")

func exact_calls() -> void:
	# The production helper is observed at each supported base rate and frame
	# cadence. A separate model replays every measured call, preserving the
	# original <=.05 simulation substeps, target order, loot RNG and rewards.
	for fps in [30,60,120]:
		for speed in [1.0,2.0,4.0]:
			fixture(2,200.0)
			var snapshot: Dictionary = scene.run.save_data()
			var observed := CountedRun.new()
			var reference := Run.new()
			check(observed.load_data(snapshot) and reference.load_data(snapshot),"Paired models restore identical snapshot")
			scene.run = observed
			scene.game_speed = speed
			scene.cleanup_fast = true
			var batches := 0
			var plain_calls := 0
			for frame in range(20000):
				if observed.phase != "battle": break
				observed.calls.clear()
				var was_fast: bool = scene.cleanup_fast
				var health_before: float = observed.health
				scene._advance_gameplay(1.0/float(fps))
				var expected_max: int = 8/int(speed) if was_fast else 1
				check(observed.calls.size() >= 1 and observed.calls.size() <= expected_max,"Bounded repeated calls at %d FPS, %.0fx" % [fps,speed])
				if observed.phase == "battle" and observed.health >= health_before:
					check(observed.calls.size() == expected_max,"Uninterrupted acceleration executes the complete 8x batch")
				for dt in observed.calls:
					check(is_equal_approx(dt,speed/float(fps)),"Every accelerated call retains the normal selected-speed timestep")
					check(reference.phase == "battle","No extra update is issued after battle settlement")
					reference.update(dt)
					plain_calls += 1
				if observed.health < health_before:
					check(not scene.cleanup_fast,"Any core damage disarms acceleration within its batch")
				observed.drain_events()
				reference.drain_events()
				batches += 1
			check(observed.phase != "battle","Paired tail settles without a timeout")
			check(observed.save_data() == reference.save_data(),"Identical complete state, RNG, damage and rewards at %d FPS, %.0fx" % [fps,speed])
			check(not scene.cleanup_fast,"Completion clears temporary acceleration")
			check(batches < plain_calls,"Optional fast-forward uses fewer displayed frames than identical normal updates")
			print("CLEANUP_PARITY fps=%d base=%.0f frames=%d calls=%d phase=%s core=%.1f credits=%d" % [fps,speed,batches,plain_calls,observed.phase,observed.health,observed.credits])
	fixture(2,1000.0)
	var leaking := CountedRun.new()
	check(leaking.load_data(scene.run.save_data()),"Core-hit boundary fixture restores")
	leaking.towers.clear()
	leaking.enemies[0].progress = leaking.route_length-0.00001
	leaking.enemies[0].pos = leaking.position_on_route(leaking.enemies[0].progress)
	leaking.enemies[1].progress = 0.0
	leaking.enemies[1].pos = leaking.position_on_route(0.0)
	scene.run = leaking
	scene.cleanup_fast = true
	scene.game_speed = 1.0
	scene._advance_gameplay(1.0/60.0)
	check(leaking.calls.size() == 1 and not scene.cleanup_fast,"First leaking update stops the batch immediately")
	check(int(leaking.combat_report.core_damage)>0,"Leak cancellation is caused by actual core damage")
	fixture()

func capture(stage: String) -> void:
	if not rendered: return
	scene._layout_ui()
	scene._refresh()
	scene.notice.hide()
	scene.notice_time = 0
	scene._update_context_visibility()
	await frames(8)
	var image: Image = root.get_texture().get_image()
	check(image != null and not image.is_empty(),stage+": real framebuffer exists")
	if image == null or image.is_empty(): return
	check(image.get_size() == Vector2i(1280,800),stage+": Deck resolution")
	var colors := {}
	var bright := 0
	for y in range(0,800,8):
		for x in range(0,1280,8):
			var color := image.get_pixel(x,y)
			colors[color.to_rgba32()] = true
			if color.r+color.g+color.b > 1.2: bright += 1
	check(colors.size()>100 and bright>100,stage+": visible geometry and text")
	for control in [scene.next_button,scene.hud_nodes.speed,scene.phase_detail,scene.controls_label]:
		check(root.get_visible_rect().grow(1).encloses(control.get_global_rect()),stage+": action and status fit viewport")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	check(image.save_png(output.path_join(variant+"-"+stage+".png")) == OK,stage+": capture saved")

func exercise() -> void:
	if rendered and DisplayServer.get_name() == "headless":
		push_error("Cleanup render checks require a real graphics renderer")
		quit(1)
		return
	root.size = Vector2i(1280,800)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.preferences.file_path = profile+"-settings.json"
	scene.run_save.file_path = profile+"-run.json"
	root.add_child(scene)
	await frames(6)
	scene.set_process(false)
	scene.sound.set_muted(true)
	original_run = scene.run
	eligibility()
	await input_flow()
	await context_gates()
	exact_calls()
	print("CLEANUP_PACING_%s: %d checks, %d failures (%s%s)" % ["PASS" if failures == 0 else "FAIL",checks,failures,variant,", rendered" if rendered else ", headless"])
	scene.queue_free()
	await frames(2)
	quit(0 if failures == 0 else 1)
