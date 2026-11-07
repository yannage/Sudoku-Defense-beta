extends SceneTree
## Screenshot-only UI acceptance; no mouse warp, pointer dispatch, or drag.
var scene
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames() -> void:
	for i in 8: await process_frame

func capture(name: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://../qa/controller-mapping-captures")
	DirAccess.make_dir_recursive_absolute(output)
	check(image.save_png(output+"/"+name+".png") == OK,"Screenshot saved: "+name)
	var focused := root.gui_get_focus_owner()
	check(is_instance_valid(focused) and scene.overlay.is_ancestor_of(focused),"Focus stays in mapping panel")
	if is_instance_valid(focused):
		check(root.get_visible_rect().encloses(focused.get_global_rect()),"Focused control is within viewport")

func exercise() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	scene.preferences.file_path = "user://mapping-visual-settings.json"
	scene.run_save.file_path = "user://mapping-visual-run.json"
	root.add_child(scene)
	await frames()
	scene.sound.set_muted(true)
	scene.set_process(false)
	var renderer := "canvas" if "--canvas-graphics" in OS.get_cmdline_user_args() else "native"
	for size in [Vector2i(1280,800),Vector2i(390,844)]:
		root.size = size
		await frames()
		var prefix := renderer + ("-deck" if size.x == 1280 else "-portrait")
		scene._show_controller_settings()
		await capture(prefix+"-mapping")
		scene._capture_controller_binding("confirm")
		await capture(prefix+"-capture")
		scene.controller.cancel_capture()
		await frames()
		for item in scene.overlay.find_children("*","Button",true,false):
			if item.text.begins_with("Reset to defaults"):
				item.pressed.emit()
				break
		await capture(prefix+"-reset")
		scene._close_overlay()
		scene.feedback_ui.show_panel()
		await capture(prefix+"-feedback-disabled")
		scene.feedback_ui.service.route = {"mode":"github", "verified":true, "url":scene.feedback_ui.service.GITHUB_ISSUES}
		scene.feedback_ui._confirm("bug")
		await capture(prefix+"-feedback-confirmation")
		scene.feedback_ui.service.route = {}
		scene._close_overlay()
	scene.queue_free()
	await frames()
	print("CONTROLLER_MAPPING_VISUAL_PASS %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
