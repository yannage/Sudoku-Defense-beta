class_name DefenseChestStage
extends SubViewportContainer
## Drop this Control into any loot panel for a lit, animated native voxel chest.
## set_rarity("rare") colors the rails. open_chest() reveals the reward.

const RARITY_COLORS: Dictionary = {"common":Color("bacbd0"),"uncommon":Color("91e8a6"),"rare":Color("77caff"),"epic":Color("c7a0ff"),"legendary":Color("ffca69")}
const VoxelMaterial = preload("res://scripts/voxel_material.gd")
var rarity: String = "common"
var reduced_motion: bool = false
var _viewport: SubViewport
var _world: Node3D
var _chest: Node3D
var _lid: Node3D
var _glow: Node3D
var _trim: Material
var _cube: BoxMesh = BoxMesh.new()
var _materials: Dictionary = {}
var _tween: Tween
var _particles: Array[Node3D] = []
var _clock: float = 0.0
var _opened: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(220, 160)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(360, 250)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.gui_disable_input = true
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c9e3e2")
	environment.ambient_light_energy = 0.75
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.8
	light.light_color = Color("fff0d6")
	_world.add_child(light)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 120, 0)
	fill.light_energy = 0.55
	fill.light_color = Color("a1d9e9")
	_world.add_child(fill)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.65
	camera.position = Vector3(3.6, 3.0, 4.5)
	_world.add_child(camera)
	camera.look_at(Vector3(0, 0.85, 0))
	camera.current = true
	_chest = Node3D.new()
	_world.add_child(_chest)
	_trim = VoxelMaterial.create(RARITY_COLORS.get(rarity, Color("bacbd0")))
	# Stepped feet and steel chassis.
	for x: float in [-0.83, 0.83]:
		for z: float in [-0.47, 0.47]:
			_box(_chest, Vector3(x, 0.1, z), Vector3(0.30, 0.22, 0.30), Color("546d74"))
	_box(_chest, Vector3(0, 0.25, 0), Vector3(2.08, 0.15, 1.35), Color("7c9999"))
	_box(_chest, Vector3(0, 0.61, 0), Vector3(1.96, 0.66, 1.24), Color("36535f"))
	_box(_chest, Vector3(0, 0.98, 0), Vector3(1.75, 0.08, 1.06), Color("102631"))
	# Front recessed panels; illuminated lock gives the reveal a strong focal point.
	for x: float in [-0.52, 0.52]:
		_box(_chest, Vector3(x, 0.61, 0.645), Vector3(0.68, 0.36, 0.055), Color("668487"))
	for x: float in [-0.88, 0.88]:
		_box(_chest, Vector3(x, 0.65, 0.67), Vector3(0.15, 0.74, 0.10), Color.WHITE, true)
		_box(_chest, Vector3(x, 0.65, -0.66), Vector3(0.15, 0.74, 0.10), Color.WHITE, true)
	_box(_chest, Vector3(0, 0.86, 0.73), Vector3(0.36, 0.42, 0.18), Color("233e4b"))
	_box(_chest, Vector3(0, 0.87, 0.835), Vector3(0.15, 0.17, 0.045), Color.WHITE, true)
	_box(_chest, Vector3(1.02, 0.61, 0), Vector3(0.075, 0.25, 0.46), Color("203d48"))
	_box(_chest, Vector3(1.065, 0.61, 0), Vector3(0.03, 0.075, 0.29), Color.WHITE, true)
	# Lid pivots on the actual rear hinge, not the chest center.
	_lid = Node3D.new()
	_chest.add_child(_lid)
	_lid.position = Vector3(0, 1.03, -0.67)
	_box(_lid, Vector3(0, 0.14, 0.67), Vector3(2.12, 0.28, 1.40), Color("658588"))
	_box(_lid, Vector3(0, 0.31, 0.67), Vector3(1.82, 0.08, 1.13), Color("a2bdb3"))
	for x: float in [-0.82, 0.82]:
		_box(_lid, Vector3(x, 0.16, 0.67), Vector3(0.22, 0.34, 1.43), Color.WHITE, true)
	_box(_lid, Vector3(0, 0.38, 0.67), Vector3(0.49, 0.10, 0.43), Color("345763"))
	_box(_lid, Vector3(0, 0.46, 0.67), Vector3(0.24, 0.08, 0.22), Color.WHITE, true)
	_glow = Node3D.new()
	_chest.add_child(_glow)
	_glow.position = Vector3(0, 1.0, 0)
	_glow.visible = false
	for x: float in [-0.62, -0.22, 0.22, 0.62]:
		var beam: MeshInstance3D = _box(_glow, Vector3(x, 0.62, 0), Vector3(0.07, 1.25, 0.07), Color.WHITE, true)
		beam.rotation.z = x * 0.13
	set_rarity(rarity)

func _process(dt: float) -> void:
	_clock += dt
	if _chest == null:
		return
	_chest.rotation.y = 0.0 if reduced_motion else sin(_clock * 0.58) * 0.13
	_chest.position.y = 0.0 if reduced_motion else sin(_clock * 1.4) * 0.025
	if _glow != null and _opened:
		_glow.scale.x = 1.0 + sin(_clock * 3.0) * 0.08

func set_rarity(value: String) -> void:
	rarity = value
	if _trim != null:
		var color: Color = RARITY_COLORS.get(value, Color("bacbd0"))
		VoxelMaterial.set_color(_trim, color)
		if _trim is StandardMaterial3D:
			(_trim as StandardMaterial3D).emission_enabled = true
			(_trim as StandardMaterial3D).emission = color
			(_trim as StandardMaterial3D).emission_energy_multiplier = 0.20

func open_chest() -> void:
	if _lid == null or _opened:
		return
	_opened = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	if not reduced_motion:
		_tween.tween_property(_chest, "rotation:z", -0.055, 0.08)
		_tween.tween_property(_chest, "rotation:z", 0.055, 0.08)
		_tween.tween_property(_chest, "rotation:z", 0.0, 0.08)
	_tween.tween_property(_lid, "rotation:x", -1.70, 0.5 if not reduced_motion else 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_callback(_sparkles).set_delay(0.14)
	_tween.tween_property(_glow, "scale:y", 0.2, 1.2).set_ease(Tween.EASE_OUT)

func show_opened() -> void:
	# Completed-reveal pose for a persistent loot table.
	if _tween != null: _tween.kill()
	_opened = true
	if _lid != null: _lid.rotation.x = -1.70
	if _glow != null:
		_glow.visible = true
		_glow.scale.y = 0.22

func set_preview_active(value: bool) -> void:
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if value else SubViewport.UPDATE_DISABLED
	set_process(value)

func reset() -> void:
	_opened = false
	if _tween != null:
		_tween.kill()
	if _lid != null:
		_lid.rotation = Vector3.ZERO
	if _glow != null:
		_glow.visible = false
		_glow.scale = Vector3.ONE
	for particle: Node3D in _particles:
		if is_instance_valid(particle):
			particle.queue_free()
	_particles.clear()

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value

func _sparkles() -> void:
	_glow.visible = true
	_glow.scale.y = 0.6
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7859
	for i: int in range(5 if reduced_motion else 18):
		var color: Color = RARITY_COLORS.get(rarity, Color("bacbd0"))
		var particle: MeshInstance3D = _box(_world, Vector3(0, 1.03, 0), Vector3.ONE * rng.randf_range(0.055, 0.11), color.lightened(0.20 if i % 2 == 0 else 0.0))
		_particles.append(particle)
		var target: Vector3 = Vector3(rng.randf_range(-1.7, 1.7), rng.randf_range(1.3, 2.6), rng.randf_range(-0.8, 0.9))
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(particle, "position", target, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "rotation", Vector3(rng.randf() * 4, rng.randf() * 4, rng.randf() * 4), 0.8)
		tween.tween_property(particle, "scale", Vector3.ZERO, 0.35).set_delay(0.65)
		tween.chain().tween_callback(particle.queue_free)

func _box(parent: Node3D, pos: Vector3, dimensions: Vector3, color: Color, trim: bool = false) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = _cube
	mesh.position = pos
	mesh.scale = dimensions
	if trim:
		mesh.material_override = _trim
	else:
		var key: String = color.to_html()
		if not _materials.has(key):
			_materials[key] = VoxelMaterial.create(color)
		mesh.material_override = _materials[key]
	parent.add_child(mesh)
	return mesh
