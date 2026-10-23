extends SceneTree
## Regression for the web chest: real CanvasItem pixels and reward/reset API.
## Run with a GL/GLES display; --headless also checks the animation lifecycle.

const Chest = preload("res://scripts/chest_canvas.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("exercise")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func image(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var result: Image = root.get_texture().get_image()
	var path: String = "res://build/render-checks"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	check(result != null and not result.is_empty(), "Canvas chest has a rendered framebuffer")
	if result != null and not result.is_empty():
		check(result.save_png(path.path_join(name + ".png")) == OK, "Save chest visual evidence")
	return result

func colored_count(result: Image) -> int:
	var count: int = 0
	for x in range(40, 360, 4):
		for y in range(35, 270, 4):
			var color: Color = result.get_pixel(x, y)
			if maxf(color.r, maxf(color.g, color.b)) > 0.30:
				count += 1
	return count

func exercise() -> void:
	root.size = Vector2i(400, 300)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.disable_3d = true
	var chest = Chest.new()
	root.add_child(chest)
	chest.position = Vector2(20, 20)
	chest.size = Vector2(360, 250)
	chest.set_reduced_motion(true)
	chest.set_rarity("legendary")
	await process_frame
	check(chest is Control and not chest is SubViewportContainer, "Reward renders directly through a Control")
	check(chest.get_child_count() == 0, "No embedded 3D viewport is needed for a chest")
	check(chest.rarity == "legendary", "Rarity can be configured before opening")
	var has_pixels: bool = DisplayServer.get_name() != "headless"
	var closed: Image
	if has_pixels:
		closed = await image("canvas-chest-closed")
		check(colored_count(closed) > 180, "Closed chest has visible colored voxel faces")
	chest.open_chest()
	await create_timer(0.40).timeout
	check(chest._opened and chest._lid_angle < -1.5, "Opening reveals a fully hinged lid")
	check(chest._particles.size() > 0, "Opening creates a reward burst even in reduced motion")
	if has_pixels:
		var opened: Image = await image("canvas-chest-open")
		check(colored_count(opened) > 180, "Open chest retains visible colored voxel faces")
		var changed: int = 0
		for x in range(40, 360, 4):
			for y in range(35, 270, 4):
				if closed.get_pixel(x, y).get_luminance() - opened.get_pixel(x, y).get_luminance() > 0.08:
					changed += 1
		check(changed > 30, "Hinged lid changes the visible geometry")
	chest.open_chest()
	check(chest._particles.size() <= 5, "Repeated open does not grant a duplicate reveal")
	chest.reset()
	check(not chest._opened and chest._lid_angle == 0.0 and chest._particles.is_empty(), "Reset clears reveal, lid rotation and particles")
	chest.set_rarity("unknown")
	check(chest.rarity == "common", "Unknown rarity safely falls back to common")
	chest.queue_free()
	await process_frame
	print("Canvas chest: %d checks, %d failures%s" % [checks, failures, " (headless API checks only)" if not has_pixels else " (real GLES pixels)"])
	quit(1 if failures else 0)
