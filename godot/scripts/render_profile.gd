class_name DefenseRenderProfile
extends RefCounted

# The affected mobile browsers render CanvasItems correctly but black out the
# entire spatial scene, including unshaded meshes. Project voxels with ordinary
# CanvasItem polygons on the web; never allocate a hidden 3D viewport there.
# Desktop keeps its native spatial scene. The flag exercises the exact web path
# in the desktop pixel and input regression suites.
static func uses_canvas() -> bool:
	return OS.has_feature("web") or "--canvas-graphics" in OS.get_cmdline_user_args()
