class_name DefenseChestCanvas
extends Control
## Projected voxel reward chest. Uses only CanvasItem drawing, so the web reward
## reveal shares the same rendering path as the HUD instead of a 3D SubViewport.

const RARITY_COLORS: Dictionary = {
	"common": Color("bacbd0"), "uncommon": Color("91e8a6"),
	"rare": Color("77caff"), "epic": Color("c7a0ff"),
	"legendary": Color("ffca69")
}
const VIEW: Vector3 = Vector3(0.565685, 0.424264, 0.707107)
const RIGHT: Vector3 = Vector3(0.780869, 0.0, -0.624695)
const UP: Vector3 = Vector3(-0.265036, 0.905538, -0.331295)
const LIGHT: Vector3 = Vector3(-0.35, 0.85, 0.40)
const HINGE: Vector3 = Vector3(0.0, 1.03, -0.67)
const FACE_INDICES: Array = [[0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5], [4, 5, 6, 7], [0, 3, 2, 1]]
const FACE_NORMALS: Array[Vector3] = [Vector3.DOWN, Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.BACK, Vector3.FORWARD]

var rarity: String = "common"
var reduced_motion: bool = false
var _opened: bool = false
var _clock: float = 0.0
var _lid_angle: float = 0.0
var _shake: float = 0.0
var _glow: float = 0.0
var _particles: Array[Dictionary] = []
var _tween: Tween
var _origin: Vector2
var _scale: float = 1.0
var _root_basis: Basis = Basis.IDENTITY
var _bob: Vector3 = Vector3.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(220, 160)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func set_rarity(value: String) -> void:
	rarity = value if RARITY_COLORS.has(value) else "common"
	queue_redraw()

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	queue_redraw()

func open_chest() -> void:
	if _opened:
		return
	_opened = true
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween()
	if not reduced_motion:
		_tween.tween_property(self, "_shake", -0.055, 0.075)
		_tween.tween_property(self, "_shake", 0.055, 0.075)
		_tween.tween_property(self, "_shake", 0.0, 0.075)
	_tween.tween_property(self, "_lid_angle", -1.70, 0.12 if reduced_motion else 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "_glow", 1.0, 0.18)
	_tween.parallel().tween_callback(_burst).set_delay(0.06 if reduced_motion else 0.14)
	_tween.tween_property(self, "_glow", 0.28, 1.0)

func reset() -> void:
	if is_instance_valid(_tween):
		_tween.kill()
	_opened = false
	_lid_angle = 0.0
	_shake = 0.0
	_glow = 0.0
	_particles.clear()
	queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	for particle in _particles:
		particle.age = float(particle.age) + delta
	_particles = _particles.filter(func(p: Dictionary) -> bool: return float(p.age) < 1.2)
	if is_visible_in_tree():
		queue_redraw()

func _burst() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 7859
	for index in range(5 if reduced_motion else 22):
		_particles.append({
			"age": -random.randf_range(0.0, 0.12),
			"target": Vector3(random.randf_range(-1.6, 1.6), random.randf_range(1.65, 2.75), random.randf_range(-0.6, 0.8)),
			"size": random.randf_range(0.055, 0.12),
			"bright": index % 3 == 0,
		})

func _project(point: Vector3) -> Vector2:
	return _origin + Vector2(point.dot(RIGHT), -point.dot(UP)) * _scale

func _transform(point: Vector3, lid: bool) -> Vector3:
	if lid:
		point = HINGE + Basis(Vector3.RIGHT, _lid_angle) * point
	return _root_basis * point + _bob

func _box(faces: Array[Dictionary], center: Vector3, dimensions: Vector3, color: Color, lid: bool = false) -> void:
	var half: Vector3 = dimensions * 0.5
	var vertices: Array[Vector3] = [
		center + Vector3(-half.x, -half.y, -half.z), center + Vector3(half.x, -half.y, -half.z),
		center + Vector3(half.x, half.y, -half.z), center + Vector3(-half.x, half.y, -half.z),
		center + Vector3(-half.x, -half.y, half.z), center + Vector3(half.x, -half.y, half.z),
		center + Vector3(half.x, half.y, half.z), center + Vector3(-half.x, half.y, half.z)
	]
	for index in range(vertices.size()):
		vertices[index] = _transform(vertices[index], lid)
	var normal_basis: Basis = _root_basis * (Basis(Vector3.RIGHT, _lid_angle) if lid else Basis.IDENTITY)
	for index in range(6):
		var normal: Vector3 = normal_basis * FACE_NORMALS[index]
		if normal.dot(VIEW) < 0.001:
			continue
		var polygon := PackedVector2Array()
		var depth: float = 0.0
		for corner in FACE_INDICES[index]:
			var vertex: Vector3 = vertices[int(corner)]
			polygon.append(_project(vertex))
			depth += vertex.dot(VIEW)
		var shade: float = clampf(0.68 + 0.34 * normal.dot(LIGHT), 0.43, 1.0)
		faces.append({"points": polygon, "depth": depth * 0.25, "color": Color(color.r * shade, color.g * shade, color.b * shade, color.a)})

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_scale = minf(size.x / 4.25, size.y / 3.35)
	_origin = Vector2(size.x * 0.5, size.y * 0.79)
	_root_basis = Basis(Vector3.UP, 0.0 if reduced_motion else sin(_clock * 0.58) * 0.10) * Basis(Vector3.FORWARD, _shake)
	_bob = Vector3(0.0, 0.0 if reduced_motion else sin(_clock * 1.4) * 0.025, 0.0)
	var color: Color = RARITY_COLORS[rarity]
	_draw_shadow(color)
	if _glow > 0.0:
		_draw_light(color)
	var faces: Array[Dictionary] = []
	for x in [-0.83, 0.83]:
		for z in [-0.47, 0.47]:
			_box(faces, Vector3(x, 0.10, z), Vector3(0.30, 0.22, 0.30), Color("546d74"))
	_box(faces, Vector3(0, 0.25, 0), Vector3(2.08, 0.15, 1.35), Color("7c9999"))
	_box(faces, Vector3(0, 0.61, 0), Vector3(1.96, 0.66, 1.24), Color("36535f"))
	_box(faces, Vector3(0, 0.96, 0), Vector3(1.75, 0.08, 1.06), Color("102631"))
	# Recessed cavity, bordered by a raised rim visible as the lid swings away.
	_box(faces, Vector3(0, 1.01, 0.60), Vector3(1.98, 0.12, 0.12), Color("8ba59e"))
	_box(faces, Vector3(0, 1.01, -0.60), Vector3(1.98, 0.12, 0.12), Color("8ba59e"))
	for x in [-0.93, 0.93]:
		_box(faces, Vector3(x, 1.01, 0), Vector3(0.12, 0.12, 1.14), Color("8ba59e"))
	for x in [-0.52, 0.52]:
		_box(faces, Vector3(x, 0.61, 0.645), Vector3(0.68, 0.36, 0.055), Color("668487"))
	for x in [-0.88, 0.88]:
		for z in [-0.66, 0.67]:
			_box(faces, Vector3(x, 0.65, z), Vector3(0.15, 0.74, 0.10), color)
	_box(faces, Vector3(0, 0.84, 0.73), Vector3(0.36, 0.42, 0.18), Color("233e4b"))
	_box(faces, Vector3(0, 0.85, 0.835), Vector3(0.15, 0.17, 0.045), color.lightened(0.15))
	_box(faces, Vector3(1.02, 0.61, 0), Vector3(0.075, 0.25, 0.46), Color("203d48"))
	_box(faces, Vector3(1.065, 0.61, 0), Vector3(0.03, 0.075, 0.29), color)
	_box(faces, Vector3(0, 0.14, 0.67), Vector3(2.12, 0.28, 1.40), Color("658588"), true)
	_box(faces, Vector3(0, 0.31, 0.67), Vector3(1.82, 0.08, 1.13), Color("a2bdb3"), true)
	# Luminous inset on the underside makes the open pose read clearly.
	_box(faces, Vector3(0, -0.015, 0.67), Vector3(1.62, 0.025, 1.02), Color("294653"), true)
	_box(faces, Vector3(0, -0.032, 0.67), Vector3(0.34, 0.026, 0.32), color, true)
	for x in [-0.82, 0.82]:
		_box(faces, Vector3(x, 0.16, 0.67), Vector3(0.22, 0.34, 1.43), color, true)
	_box(faces, Vector3(0, 0.38, 0.67), Vector3(0.49, 0.10, 0.43), Color("345763"), true)
	_box(faces, Vector3(0, 0.46, 0.67), Vector3(0.24, 0.08, 0.22), color.lightened(0.20), true)
	for particle in _particles:
		var age: float = maxf(float(particle.age), 0.0)
		var travel: float = 1.0 - pow(1.0 - clampf(age / 0.72, 0.0, 1.0), 3.0)
		var point: Vector3 = Vector3(0, 1.03, 0).lerp(particle.target, travel)
		point.y -= maxf(age - 0.55, 0.0) * 0.45
		var extent: float = float(particle.size) * (1.0 - clampf((age - 0.72) / 0.48, 0.0, 1.0))
		var particle_color: Color = color.lightened(0.45) if particle.bright else color
		if extent > 0.001:
			_box(faces, point, Vector3.ONE * extent, particle_color)
	faces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.depth) < float(b.depth))
	for face in faces:
		draw_colored_polygon(face.points, face.color)
	_draw_motes(color)

func _draw_shadow(color: Color) -> void:
	for ring in range(3):
		var points := PackedVector2Array()
		for index in range(32):
			var angle: float = TAU * float(index) / 32.0
			points.append(_origin + Vector2(cos(angle) * (1.42 + ring * 0.10), sin(angle) * (0.44 + ring * 0.035)) * _scale)
		draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.12 - ring * 0.025))
	if _opened:
		var from: Vector2 = _origin + Vector2(-0.85, 0.12) * _scale
		var to: Vector2 = _origin + Vector2(0.85, 0.12) * _scale
		draw_line(from, to, Color(color, 0.25 * _glow), 2.0, true)

func _draw_light(color: Color) -> void:
	var pulse: float = 1.0 if reduced_motion else 0.90 + sin(_clock * 3.5) * 0.10
	for index in range(5):
		var x: float = (float(index) - 2.0) * 0.29
		var height: float = 2.0 + (0.65 if index % 2 == 0 else 0.35)
		var bottom: Vector2 = _project(_transform(Vector3(x, 0.98, 0.0), false))
		var top: Vector2 = _project(_transform(Vector3(x * 1.4, height, 0.0), false))
		var width: float = _scale * (0.055 if index % 2 == 0 else 0.025)
		draw_polygon(PackedVector2Array([bottom - Vector2(width, 0), bottom + Vector2(width, 0), top + Vector2(width * 2, 0), top - Vector2(width * 2, 0)]), PackedColorArray([Color(color, 0.38 * _glow * pulse), Color(color, 0.38 * _glow * pulse), Color(color, 0.0), Color(color, 0.0)]))

func _draw_motes(color: Color) -> void:
	if reduced_motion:
		return
	for index in range(6):
		var t: float = fposmod(_clock * 0.23 + float(index) * 0.167, 1.0)
		var x: float = sin(float(index) * 2.4) * 1.60
		var point: Vector2 = _project(Vector3(x, 0.45 + t * 1.8, 0.0))
		var alpha: float = sin(t * PI) * (0.45 if _opened else 0.23)
		var extent: float = maxf(1.0, _scale * 0.025)
		draw_rect(Rect2(point - Vector2.ONE * extent * 0.5, Vector2.ONE * extent), Color(color, alpha))
