extends SceneTree
## Render the shipping menu's voxel artwork for the store branding system.
## Run with --path godot and a real GLES display; output is intentionally ignored.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("The capsule capture requires an actual renderer.")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(3200, 2400)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var art = load("res://scripts/menu_diorama.gd").new()
	art.size = Vector2(3200,2400)
	art.reduced_motion = true
	viewport.add_child(art)
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var file := ProjectSettings.globalize_path("res://../release/marketing/capsules/diorama-source.png")
	DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	var result := viewport.get_texture().get_image().save_png(file)
	if result != OK:
		push_error("Could not save capsule diorama")
		quit(1)
		return
	print("CAPSULE_DIARAMA_READY ",file)
	quit(0)
