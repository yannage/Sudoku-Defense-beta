class_name DefenseVoxelMaterial
extends RefCounted
## Web uses a small prelit shader: readable colored faces without relying on
## mobile WebGL drivers' full StandardMaterial3D light/shadow shader variants.

const PRELIT = preload("res://assets/voxel_prelit.gdshader")

static func safe_profile() -> bool:
	return OS.has_feature("web") or "--safe-graphics" in OS.get_cmdline_user_args()

static func create(color: Color, unshaded: bool = false) -> Material:
	if safe_profile():
		var material := ShaderMaterial.new()
		material.shader = PRELIT
		material.set_shader_parameter("tint", color)
		material.set_shader_parameter("face_shading", not unshaded)
		return material
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.80
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

static func set_color(material: Material, color: Color) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("tint", color)
	elif material is StandardMaterial3D:
		(material as StandardMaterial3D).albedo_color = color
