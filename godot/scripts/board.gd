class_name DefenseBoard
extends Node3D
## Native voxel battlefield. The run model is authoritative; this node only renders it.

const FAMILY_COLORS: Array[Color] = [Color("6de8ff"), Color("a4c7ff"), Color("c6a0ff"), Color("ffae68"), Color("fb86c3"), Color("9be878"), Color("ffe188"), Color("bb9bff"), Color("dec3ed")]
const MODULE_COLORS: Dictionary = {"rapid":Color("6de8ff"), "electric":Color("c6a0ff"), "frost":Color("a4c7ff"), "blast":Color("ffae68"), "venom":Color("9be878"), "range":Color("ffe188"), "power":Color("fb86c3"), "gravity":Color("bb9bff"), "nova":Color("ff7289")}
const VoxelMaterial = preload("res://scripts/voxel_material.gd")
const SeedPlanting = preload("res://scripts/seed_planting.gd")

var run: RefCounted
var selected_cell: int = -1
var selected_number: int = 0
var _family_focus: int = 0
var reduced_motion: bool = false
var camera: Camera3D
var _clock: float = 0.0
var _morph: float = 0.0
var _panel_open: bool = false
var _panel_blend: float = 0.0
var _last_board: String = ""
var _route_signature: String = ""
var _world: Node3D
var _tiles: Array[MeshInstance3D] = []
var _labels: Array[Label3D] = []
var _tower_nodes: Dictionary = {}
var _enemy_nodes: Dictionary = {}
var _route_root: Node3D
var _route_markers: Array[MeshInstance3D] = []
var _fx_root: Node3D
var _selection: Node3D
var _range_root: Node3D
var _decor: Array[Node3D] = []
var _particles: Array[Dictionary] = []
var _beams: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _materials: Dictionary = {}
var _box_mesh: BoxMesh
var _last_palette_morph: float = -1.0
var _shake: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _tile_mats: Array[Material] = []
var _grid_mats: Array[Material] = []
var _fine_grid_mats: Array[Material] = []
var _match_frames: Array[Node3D] = []
var _match_accent: Material
var _selection_accent: Material
var _drop_preview: Node3D
var _drop_label: Label3D
var _drop_accent: Material
var _drop_cell: int = -1
var _drop_number: int = 0
var _drop_allowed: bool = false
var _attachment_cell: int = -1
var _attachment_kind: String = ""
var _attachment_allowed: bool = false
var _attachment_preview: Node3D
var _attachment_hover: Node3D
var _attachment_signature: String = ""
var _attachment_targets: bool = false
var _target_frames: Dictionary = {}
var _equip_landings: Dictionary = {}
var _equip_slots: Dictionary = {}
var _seed_plantings: Dictionary = {}
var _environment: Environment
var _board_rect: Rect2 = Rect2()

func setup(model: RefCounted) -> void:
	run = model
	_rng.seed = 44219
	if camera == null:
		_build_world()
	_clear_seed_plantings()
	_last_board = ""
	_route_signature = ""
	_equip_landings.clear()
	_equip_slots.clear()
	set_attachment_preview(-1,"",false)
	set_attachment_targets(false)
	_sync_board(true)

func _build_world() -> void:
	if VoxelMaterial.safe_profile():
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	_box_mesh = BoxMesh.new()
	_box_mesh.size = Vector3.ONE
	_world = Node3D.new()
	add_child(_world)
	_fx_root = Node3D.new()
	add_child(_fx_root)
	_route_root = Node3D.new()
	_world.add_child(_route_root)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("09151d")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("91b7c1")
	_environment.ambient_light_energy = 0.75
	_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR if VoxelMaterial.safe_profile() else Environment.TONE_MAPPER_FILMIC
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	environment_node.environment = _environment
	add_child(environment_node)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("fff0d6")
	sun.light_energy = 1.7
	sun.shadow_enabled = not VoxelMaterial.safe_profile()
	sun.directional_shadow_max_distance = 28.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-30, 135, 0)
	rim.light_color = Color("70c9d0")
	rim.light_energy = 0.55
	add_child(rim)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 11.65
	camera.near = 0.1
	camera.far = 100.0
	camera.current = true
	add_child(camera)
	camera.position = Vector3(0, 16, 0.02)
	camera.look_at(Vector3.ZERO, Vector3(0, 0, -1))
	# A layered, floating circuit garden. Every piece is a real shaded mesh.
	_box(_world, Vector3(0, -0.42, 0), Vector3(9.65, 0.60, 9.65), Color("172e38"))
	_box(_world, Vector3(0, -0.77, 0), Vector3(8.95, 0.16, 8.95), Color("0b202a"))
	_box(_world, Vector3(0, -0.91, 0), Vector3(7.35, 0.13, 7.35), Color("132c37"))
	for side: int in [-1, 1]:
		_box(_world, Vector3(side * 4.76, -0.07, 0), Vector3(0.12, 0.13, 9.57), Color("608b86"))
		_box(_world, Vector3(0, -0.07, side * 4.76), Vector3(9.57, 0.13, 0.12), Color("608b86"))
		for q: int in range(-4, 5):
			_box(_world, Vector3(side * 4.84, -0.43, q), Vector3(0.045, 0.09, 0.42), Color("52c9ba"), true)
			_box(_world, Vector3(q, -0.43, side * 4.84), Vector3(0.42, 0.09, 0.045), Color("52c9ba"), true)
	_match_accent = VoxelMaterial.create(Color("357991"), true)
	for i: int in range(81):
		var pos: Vector3 = _cell_pos(i)
		var material: Material = VoxelMaterial.create(Color("f4f3e9"), true)
		_tile_mats.append(material)
		var tile: MeshInstance3D = _box(_world, pos + Vector3(0, -0.075, 0), Vector3(0.97, 0.12, 0.97), Color.WHITE)
		tile.material_override = material
		_tiles.append(tile)
		var label: Label3D = Label3D.new()
		label.font_size = 72
		label.pixel_size = 0.0095
		label.outline_size = 0
		label.modulate = Color("294450")
		label.no_depth_test = false
		label.shaded = false
		label.rotation_degrees.x = -90.0
		label.position = pos + Vector3(0, 0.008, 0.035)
		_world.add_child(label)
		_labels.append(label)
		var match_frame: Node3D = Node3D.new()
		_world.add_child(match_frame)
		match_frame.position = pos
		_square_frame(match_frame, 0.89, 0.032, Color.WHITE, 0.035)
		for edge: MeshInstance3D in match_frame.get_children(): edge.material_override = _match_accent
		match_frame.visible = false
		_match_frames.append(match_frame)
	# Give every square an explicit ink line. Tile gaps alone disappear under
	# desktop lighting/MSAA; thicker 3x3 dividers keep Sudoku groups unmistakable.
	for line: int in range(10):
		var boundary: float = float(line) - 4.5
		var major: bool = line % 3 == 0
		var thickness: float = 0.075 if major else 0.026
		var mat: Material = VoxelMaterial.create(Color("193b46") if major else Color("83989a"), true)
		if major: _grid_mats.append(mat)
		else: _fine_grid_mats.append(mat)
		var a: MeshInstance3D = _box(_world, Vector3(boundary, 0.006, 0), Vector3(thickness, 0.018, 9.075), Color.WHITE)
		a.material_override = mat
		var b: MeshInstance3D = _box(_world, Vector3(0, 0.006, boundary), Vector3(9.075, 0.018, thickness), Color.WHITE)
		b.material_override = mat
	_selection = Node3D.new()
	_world.add_child(_selection)
	_square_frame(_selection, 0.91, 0.10, Color("13333d"), 0.065)
	var selection_trim: Node3D = Node3D.new()
	_selection.add_child(selection_trim)
	_square_frame(selection_trim, 0.91, 0.043, Color.WHITE, 0.125)
	_selection_accent = VoxelMaterial.create(Color("187568"), true)
	for edge: MeshInstance3D in selection_trim.get_children(): edge.material_override = _selection_accent
	for x: float in [-0.415, 0.415]:
		for z: float in [-0.415, 0.415]:
			_box(_selection, Vector3(x, 0.14, z), Vector3(0.095, 0.08, 0.095), Color("ffe6a6"), true)
	_selection.visible = false
	_drop_preview = Node3D.new()
	_world.add_child(_drop_preview)
	_square_frame(_drop_preview, 0.91, 0.12, Color("13333d"), 0.16)
	var drop_trim: Node3D = Node3D.new()
	_drop_preview.add_child(drop_trim)
	_square_frame(drop_trim, 0.91, 0.06, Color.WHITE, 0.235)
	_drop_accent = VoxelMaterial.create(Color("81efc0"), true)
	for edge: MeshInstance3D in drop_trim.get_children(): edge.material_override = _drop_accent
	_drop_label = Label3D.new()
	_drop_label.font_size = 72
	_drop_label.pixel_size = 0.0106
	_drop_label.outline_size = 0
	_drop_label.shaded = false
	_drop_label.rotation_degrees.x = -90.0
	_drop_label.position = Vector3(0, 0.10, 0.035)
	_drop_preview.add_child(_drop_label)
	_drop_preview.visible = false
	_range_root = Node3D.new()
	_world.add_child(_range_root)
	# Sparse voxel plants and edge terminals leave every playable cell readable.
	for i: int in range(16):
		var corner: int = i % 4
		var u: float = -3.7 + float(i / 4) * 2.35
		var pos: Vector3 = Vector3(5.1 if corner == 0 else -5.1 if corner == 1 else u, -0.10, u if corner < 2 else 5.1 if corner == 2 else -5.1)
		var plant: Node3D = _plant(pos, i)
		_decor.append(plant)
	for x: float in [-4.65, 4.65]:
		for z: float in [-4.65, 4.65]:
			_box(_world, Vector3(x, -0.03, z), Vector3(0.38, 0.26, 0.38), Color("203c44"))
			_box(_world, Vector3(x, 0.12, z), Vector3(0.2, 0.05, 0.2), Color("ffbf78"), true)
	# Small star-like cubes suggest a suspended island, without a noisy texture.
	for i: int in range(36):
		var p: Vector3 = Vector3(_rng.randf_range(-15, 15), _rng.randf_range(-3.5, -1.4), _rng.randf_range(-13, 13))
		if absf(p.x) < 5.7 and absf(p.z) < 5.7:
			continue
		var dust: MeshInstance3D = _box(_world, p, Vector3.ONE * _rng.randf_range(0.025, 0.07), Color("335d65"), true)
		dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func tick(dt: float) -> void:
	if run == null or camera == null:
		return
	_clock += dt
	var phase: String = str(run.get("phase"))
	var target: float = 0.0 if phase == "solve" else 1.0
	_morph = move_toward(_morph, target, dt * (4.0 if reduced_motion else 1.35))
	_panel_blend = move_toward(_panel_blend, 1.0 if _panel_open else 0.0, dt * 4.0)
	var eased: float = smoothstep(0.0, 1.0, _morph)
	# A gentler portrait yaw makes the grid larger and keeps rows easy to read
	# on phones, while the Deck keeps the wider tactical diorama perspective.
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var battle_pose: Vector3 = Vector3(2.4, 15.5, 10.4) if viewport_size.y > viewport_size.x else Vector3(10.5, 13.4, 13.2)
	var target_position: Vector3 = Vector3(0, 16, 0.02).lerp(battle_pose, eased)
	var focus: Vector3 = Vector3(0, -0.12 - eased * 0.25, 0)
	_shake = maxf(0, _shake - dt * 2.4)
	if _shake > 0.001 and not reduced_motion:
		focus += Vector3(sin(_clock * 74.0), cos(_clock * 91.0), 0) * _shake * 0.06
	camera.position = target_position
	camera.look_at(focus, Vector3(0, 0, -1) if eased < 0.001 else Vector3.UP)
	camera.size = lerpf(11.65, 13.25, eased) + lerpf(0.30, 1.45, eased) * _panel_blend
	camera.h_offset = lerpf(0.90, 1.05, eased) * _panel_blend
	camera.v_offset = 0.0
	if _board_rect.has_area():
		_fit_board_rect(eased)
	_sync_board(false)
	_sync_towers(dt)
	_sync_attachment_targets()
	if is_instance_valid(_attachment_hover):
		_attachment_hover.position.y = 0.06 if reduced_motion else 0.06 + sin(_clock * 3.0) * 0.035
	_sync_enemies(dt)
	_update_fx(dt)
	_animate_route()
	_selection.visible = selected_cell >= 0 and selected_cell < 81
	if _selection.visible:
		_selection.position = _cell_pos(selected_cell)
		_selection.scale.y = 1.0 + (0.0 if reduced_motion else sin(_clock * 3.4) * 0.14)
	if absf(_last_palette_morph - eased) > 0.02:
		_last_palette_morph = eased
		_update_palette(eased)
	for i: int in range(_decor.size()):
		var d: Node3D = _decor[i]
		d.rotation.z = 0.0 if reduced_motion else sin(_clock * 0.8 + float(i)) * 0.025
	_range_root.visible = _morph > 0.65 and selected_cell >= 0 and phase != "solve"
	_update_seed_plantings(dt)

func set_selected(cell: int, number: int = 0) -> void:
	selected_cell = cell
	selected_number = clampi(number, 0, 9)
	if camera == null:
		return
	_update_palette(smoothstep(0.0, 1.0, _morph))
	_refresh_range()

func set_drop_preview(cell: int, number: int, allowed: bool) -> void:
	_drop_cell = cell if cell >= 0 and cell < 81 else -1
	_drop_number = clampi(number, 0, 9)
	_drop_allowed = allowed
	if _drop_preview == null: return
	_drop_preview.visible = _drop_cell >= 0
	if not _drop_preview.visible: return
	_drop_preview.position = _cell_pos(_drop_cell)
	VoxelMaterial.set_color(_drop_accent, Color("81efc0") if allowed else Color("ff788b"))
	_drop_label.text = str(_drop_number) if _drop_number > 0 and run != null and int(run.board[_drop_cell]) == 0 else ""
	_drop_label.modulate = Color("176a54") if allowed else Color("9c2440")
	if _morph > 0.5: _drop_label.modulate = Color("c2ffe3") if allowed else Color("ffacb9")

func set_attachment_targets(active: bool) -> void:
	_attachment_targets = active
	if _world != null: _sync_attachment_targets()

func _sync_attachment_targets() -> void:
	for key: Variant in _target_frames.keys():
		if run == null or not run.towers.has(key):
			(_target_frames[key] as Node3D).queue_free()
			_target_frames.erase(key)
	if run == null: return
	for key: Variant in run.towers:
		if not _attachment_targets and not _target_frames.has(key): continue
		var full: bool = run.towers[key].attachments.size() >= 5
		var frame: Node3D = _target_frames.get(key)
		if frame == null or bool(frame.get_meta("full",false)) != full:
			if frame != null: frame.queue_free()
			frame = Node3D.new()
			_world.add_child(frame)
			frame.position = _cell_pos(int(key))
			frame.set_meta("full",full)
			_square_frame(frame,0.77,0.018,Color("44615f") if full else Color("5b9d88"),0.045)
			_target_frames[key] = frame
		frame.visible = _attachment_targets

func set_attachment_preview(cell: int, kind: String, allowed: bool) -> void:
	_attachment_cell = cell if cell >= 0 and cell < 81 else -1
	_attachment_kind = kind
	_attachment_allowed = allowed
	if _world == null: return
	var used: int = run.towers[cell].attachments.size() if run != null and run.towers.has(cell) else 0
	var signature := "%d/%s/%s/%d" % [_attachment_cell,kind,allowed,used]
	if signature == _attachment_signature: return
	_attachment_signature = signature
	if is_instance_valid(_attachment_preview):
		_attachment_preview.queue_free()
		_attachment_preview = null
		_attachment_hover = null
	if _attachment_cell < 0: return
	_attachment_preview = Node3D.new()
	_world.add_child(_attachment_preview)
	_attachment_preview.position = _cell_pos(cell)
	var tint: Color = MODULE_COLORS.get(kind,Color("83e7c1")) if allowed else Color("c08b83")
	_square_frame(_attachment_preview,0.85,0.042,tint,0.07)
	for slot: int in range(5):
		var pip_color: Color = Color("526a6c") if slot >= used else Color("accac1")
		if slot == used and allowed: pip_color = tint.lightened(0.2)
		_box(_attachment_preview,Vector3((slot-2)*0.13,0.09,0.39),Vector3(0.09,0.055,0.06),pip_color,true)
	if allowed and used < 5:
		_attachment_hover = Node3D.new()
		_attachment_preview.add_child(_attachment_hover)
		_module(_attachment_hover,kind,0.85+float(used)*0.16)

func set_family_focus(number: int) -> void:
	var value: int = clampi(number,0,9)
	if _family_focus == value: return
	_family_focus = value
	if camera != null: _update_palette(smoothstep(0.0,1.0,_morph))

func set_panel_open(value: bool) -> void:
	_panel_open = value

func set_board_rect(value: Rect2) -> void:
	# HUD layout supplies the usable area in root-viewport coordinates. Fitting
	# the actual camera-space bounds keeps every tile reachable after rotation.
	_board_rect = value
	if camera != null and value.has_area():
		_fit_board_rect(smoothstep(0.0, 1.0, _morph))

func _fit_board_rect(blend: float) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var area: Rect2 = _board_rect.grow(-8.0)
	if not area.has_area():
		return
	var low: Vector2 = Vector2(INF, INF)
	var high: Vector2 = Vector2(-INF, -INF)
	# Include the island edge, garden decorations, and maximum tower stack.
	for x: float in [-5.35, 5.35]:
		for z: float in [-5.35, 5.35]:
			for y: float in [-0.95, lerpf(0.40, 1.90, blend)]:
				var local: Vector3 = camera.to_local(Vector3(x, y, z))
				low = low.min(Vector2(local.x, local.y))
				high = high.max(Vector2(local.x, local.y))
	var span: Vector2 = high - low
	var units_per_pixel: float = maxf(span.x / area.size.x, span.y / area.size.y)
	var center: Vector2 = (low + high) * 0.5
	var target_offset: Vector2 = area.get_center() - viewport_size * 0.5
	camera.size = maxf(1.0, units_per_pixel * viewport_size.y)
	camera.h_offset = center.x - target_offset.x * units_per_pixel
	camera.v_offset = center.y + target_offset.y * units_per_pixel

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if value:
		_shake = 0.0
		_clear_seed_plantings()

func cell_at_screen(screen_pos: Vector2) -> int:
	if camera == null:
		return -1
	if _board_rect.has_area() and not _board_rect.has_point(screen_pos):
		return -1
	# Pick visible tower tops before the plane, so selecting a tall tower feels direct.
	if _morph > 0.65:
		var best: int = -1
		var best_distance: float = 26.0
		for key: Variant in _tower_nodes:
			var entry: Dictionary = _tower_nodes[key]
			var tower: Node3D = entry["node"]
			var head: Node3D = entry["head"]
			var spot: Vector2 = camera.unproject_position(tower.position + Vector3(0, head.position.y, 0))
			var distance: float = spot.distance_to(screen_pos)
			if distance < best_distance:
				best_distance = distance
				best = int(key)
		if best >= 0:
			return best
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if hit == null:
		return -1
	var p: Vector3 = hit
	if p.x < -4.5 or p.x >= 4.5 or p.z < -4.5 or p.z >= 4.5:
		return -1
	return int(floor(p.z + 4.5)) * 9 + int(floor(p.x + 4.5))

func cell_screen_position(cell: int) -> Vector2:
	return camera.unproject_position(_cell_pos(cell) + Vector3(0, 0.05, 0)) if camera != null else Vector2.ZERO

func _sync_board(force: bool) -> void:
	if run == null:
		return
	var values: Array = run.get("board")
	if values.size() < 81:
		return
	var signature: String = str(values) + str(run.get("round_no"))
	if force or signature != _last_board:
		_last_board = signature
		for i: int in range(81):
			_labels[i].text = str(values[i]) if int(values[i]) > 0 else ""
		_update_palette(smoothstep(0.0, 1.0, _morph))
	var route: Array = run.get("route")
	var route_signature: String = str(route)
	if force or route_signature != _route_signature:
		_route_signature = route_signature
		_build_route(route)
	_route_root.visible = _morph > 0.3

func _update_palette(blend: float) -> void:
	if run == null:
		return
	var givens: Array = run.get("givens")
	var values: Array = run.get("board")
	var towers: Dictionary = run.get("towers")
	for i: int in range(_tiles.size()):
		var row: int = i / 9
		var col: int = i % 9
		var block_even: bool = (row / 3 + col / 3) % 2 == 0
		var flat: Color = Color("f4f3e9") if block_even else Color("e4eee8")
		var dark: Color = Color("153940") if block_even else Color("1b4449")
		if i < givens.size() and bool(givens[i]):
			dark = dark.lightened(0.025)
		if selected_cell >= 0 and (row == selected_cell / 9 or col == selected_cell % 9):
			flat = flat.lerp(Color("97cebc"), 0.32)
			dark = dark.lightened(0.045)
		# Matching digits share a blue fill and border, including clues and towers.
		# The active square remains gold so scanning does not hide the cursor.
		var matching: bool = selected_number > 0 and i < values.size() and int(values[i]) == selected_number
		if _family_focus > 0: matching = towers.has(i) and int(towers[i].number) == _family_focus
		_match_frames[i].visible = matching
		if matching:
			flat = Color("c3e3ed")
			dark = Color("285b6e")
		if i == selected_cell:
			flat = Color("ffe6a6")
			dark = Color("326b65")
		VoxelMaterial.set_color(_tile_mats[i], flat.lerp(dark, blend))
		var number_color: Color = Color("17343f").lerp(Color("c2d8d1"), blend)
		if towers.has(i):
			var tower: Dictionary = towers[i]
			number_color = _family(int(tower.get("number", 1))).darkened(0.55).lerp(_family(int(tower.get("number", 1))).lightened(0.15), blend)
			if bool(tower.get("illegal", false)):
				number_color = Color("9d2440").lerp(Color("ff9c9c"), blend)
		_labels[i].modulate = number_color
		_labels[i].pixel_size = lerpf(0.0106, 0.0067 if towers.has(i) else 0.0081, blend)
		_labels[i].position = _cell_pos(i) + Vector3(0, 0.014, lerpf(0.035, 0.35 if towers.has(i) else 0.02, blend))
		# Battle tower numbers face the player and render above the voxel stack.
		# Reuse the paper labels so these never add another interactive UI layer.
		var badge: bool = towers.has(i) and blend > 0.60
		_labels[i].billboard = BaseMaterial3D.BILLBOARD_ENABLED if badge else BaseMaterial3D.BILLBOARD_DISABLED
		_labels[i].no_depth_test = badge
		_labels[i].rotation_degrees.x = 0.0 if badge else -90.0
		_labels[i].outline_size = 8 if badge else 0
		_labels[i].outline_modulate = Color("0a202a")
		if badge:
			# Tower IDs are quiet annotations, not another row of bright Sudoku digits.
			var emphasized: bool = matching or i == selected_cell
			_labels[i].pixel_size = 0.0068 if emphasized else 0.0058
			_labels[i].position = _cell_pos(i) + Vector3(0.22,0.13,0.28)
			var badge_color: Color = Color("f6e7c8") if i == selected_cell else _family(int(towers[i].number)).lerp(Color("b4c9c5"),0.36)
			if bool(towers[i].illegal): badge_color = Color("e6aaa6")
			_labels[i].modulate = Color(badge_color,0.88 if emphasized else 0.58)
			_labels[i].outline_modulate = Color(Color("0a202a"),0.78 if emphasized else 0.48)
		_apply_seed_number(i)
	var match_color: Color = _family(_family_focus).lightened(0.18) if _family_focus > 0 else Color("77d8ee")
	VoxelMaterial.set_color(_match_accent, Color("357991").lerp(match_color, blend))
	for material: Material in _grid_mats:
		VoxelMaterial.set_color(material, Color("193b46").lerp(Color("6ca69c"), blend))
	for material: Material in _fine_grid_mats:
		VoxelMaterial.set_color(material, Color("83989a").lerp(Color("355b61"), blend))
	if _selection_accent != null:
		VoxelMaterial.set_color(_selection_accent, Color("187568").lerp(Color("8dffce"), blend))

func _sync_towers(dt: float) -> void:
	for cell: Variant in _equip_landings.keys():
		_equip_landings[cell] = float(_equip_landings[cell]) + dt
		if float(_equip_landings[cell]) >= 0.48:
			_equip_landings.erase(cell)
			_equip_slots.erase(cell)
	var towers: Dictionary = run.get("towers")
	for key: Variant in _tower_nodes.keys():
		if not towers.has(key):
			var removed: Dictionary = _tower_nodes[key]
			(removed["node"] as Node3D).queue_free()
			_tower_nodes.erase(key)
	for key: Variant in towers:
		var tower: Dictionary = towers[key]
		var attachments: Array = tower.get("attachments", [])
		var signature: String = str(tower.get("number", 1)) + "/" + str(attachments) + "/" + str(tower.get("level", 1))
		if not _tower_nodes.has(key) or str(_tower_nodes[key].get("signature", "")) != signature:
			if _tower_nodes.has(key):
				(_tower_nodes[key]["node"] as Node3D).queue_free()
			_tower_nodes[key] = _build_tower(int(key), tower, signature)
		var entry: Dictionary = _tower_nodes[key]
		var node: Node3D = entry["node"]
		var seed_node: Node3D = entry["seed"]
		var body: Node3D = entry["body"]
		var head: Node3D = entry["head"]
		var landing: float = clampf(float(_equip_landings.get(key,0.48))/0.48,0.0,1.0)
		var lift: float = 0.0 if reduced_motion else pow(1.0-landing,3.0)*0.82
		var layers: Array = entry.get("layers",[])
		var landing_slot: int = int(_equip_slots.get(key,layers.size()-1))
		for index: int in range(layers.size()):
			var layer: Node3D = layers[index]
			layer.position.y = lift if index == landing_slot else 0.0
			layer.rotation.y = lift*0.45 if index == landing_slot else 0.0
		head.position.y = float(entry["head_y"])+lift*0.20
		var growth: float = clampf(float(tower.get("growth", 1.0)), 0.0, 1.0)
		var show_amount: float = smoothstep(0.12, 0.8, _morph) * maxf(0.1, growth)
		body.scale = Vector3(lerpf(0.45, 1.0, show_amount), maxf(0.015, show_amount), lerpf(0.45, 1.0, show_amount))
		seed_node.visible = _morph < 0.7 and not _seed_plantings.has(key)
		seed_node.scale = Vector3.ONE * lerpf(1.0, 0.2, smoothstep(0.2, 0.72, _morph))
		body.visible = show_amount > 0.01
		node.position = _cell_pos(int(key))
		var origin2: Vector2 = Vector2(float(int(key) % 9), float(int(key) / 9))
		var aim: Vector2 = (tower.get("aim", origin2 + Vector2(0, -1)) as Vector2) - origin2
		if aim.length_squared() > 0.001:
			var angle: float = atan2(aim.x, aim.y)
			head.rotation.y = lerp_angle(head.rotation.y, angle, 1.0 if reduced_motion else minf(1.0, dt * 18.0))
		var recoil: float = maxf(0.0, float(entry.get("recoil", 0.0)) - dt * 3.7)
		entry["recoil"] = recoil
		(entry["barrel"] as Node3D).position.z = 0.25 - recoil * 0.16

func _build_tower(cell: int, tower: Dictionary, signature: String) -> Dictionary:
	var color: Color = _family(int(tower.get("number", 1)))
	var node: Node3D = Node3D.new()
	_world.add_child(node)
	node.position = _cell_pos(cell)
	var seed_node: Node3D = Node3D.new()
	node.add_child(seed_node)
	seed_node.position = Vector3(0.29, 0.05, -0.30)
	_box(seed_node, Vector3.ZERO, Vector3(0.14, 0.08, 0.14), Color("997f53"))
	_box(seed_node, Vector3(0, 0.07, 0), Vector3(0.035, 0.12, 0.035), Color("4c8d65"))
	_box(seed_node, Vector3(-0.05, 0.12, 0), Vector3(0.12, 0.04, 0.06), color)
	_box(seed_node, Vector3(0.05, 0.15, 0), Vector3(0.10, 0.04, 0.06), color.lightened(0.2))
	var body: Node3D = Node3D.new()
	node.add_child(body)
	_box(body, Vector3(0, 0.07, 0), Vector3(0.64, 0.12, 0.64), Color("3b6264"))
	_box(body, Vector3(0, 0.15, 0), Vector3(0.49, 0.08, 0.49), Color("718e86"))
	for x: float in [-0.22, 0.22]:
		for z: float in [-0.22, 0.22]:
			_box(body, Vector3(x, 0.12, z), Vector3(0.095, 0.18, 0.095), Color("36545b"))
	_box(body, Vector3(0, 0.28, 0), Vector3(0.35, 0.19, 0.35), color.darkened(0.35))
	_box(body, Vector3(0, 0.28, 0.185), Vector3(0.15, 0.07, 0.02), color, true)
	var attachments: Array = tower.get("attachments", [])
	var layers: Array[Node3D] = []
	for i: int in range(mini(5, attachments.size())):
		var item: Dictionary = attachments[i]
		var layer := Node3D.new()
		body.add_child(layer)
		layers.append(layer)
		_module(layer, str(item.get("kind", "power")), 0.43 + float(i) * 0.16)
	var head_y: float = 0.47 + float(mini(5, attachments.size())) * 0.16
	var head: Node3D = Node3D.new()
	body.add_child(head)
	head.position.y = head_y
	_box(head, Vector3.ZERO, Vector3(0.38, 0.2, 0.31), Color("759795"))
	_box(head, Vector3(0, 0.125, 0), Vector3(0.25, 0.06, 0.23), color)
	var barrel: Node3D = Node3D.new()
	head.add_child(barrel)
	barrel.position.z = 0.25
	_box(barrel, Vector3.ZERO, Vector3(0.12, 0.12, 0.39), Color("304d5c"))
	_box(barrel, Vector3(0, 0, 0.22), Vector3(0.16, 0.15, 0.055), color, true)
	var level: int = int(tower.get("level", 1))
	for j: int in range(mini(level - 1, 4)):
		_box(body, Vector3(-0.25 + float(j) * 0.15, 0.20, 0.29), Vector3(0.065, 0.045, 0.04), Color("ffe6a3"), true)
	return {"node":node, "body":body, "seed":seed_node, "head":head, "barrel":barrel, "signature":signature, "recoil":0.0, "layers":layers, "head_y":head_y}

func _module(parent: Node3D, kind: String, y: float) -> void:
	var color: Color = MODULE_COLORS.get(kind, Color("ffb5d5"))
	_box(parent, Vector3(0, y, 0), Vector3(0.43, 0.11, 0.43), Color("2c4854"))
	_box(parent, Vector3(0, y + 0.06, 0), Vector3(0.45, 0.035, 0.45), color)
	match kind:
		"electric":
			for x: float in [-0.26, 0.26]:
				_box(parent, Vector3(x, y + 0.07, 0), Vector3(0.08, 0.19, 0.12), color)
				_box(parent, Vector3(x, y + 0.16, 0), Vector3(0.15, 0.045, 0.17), color.lightened(0.3), true)
		"rapid":
			for x: float in [-0.12, 0.12]:
				_box(parent, Vector3(x, y, 0.27), Vector3(0.06, 0.06, 0.19), color, true)
		"frost":
			for z: float in [-0.25, 0.25]:
				var crystal: MeshInstance3D = _box(parent, Vector3(0, y + 0.06, z), Vector3(0.10, 0.18, 0.10), color, true)
				crystal.rotation.z = 0.45
		"blast", "nova":
			for x: float in [-0.25, 0.25]:
				_box(parent, Vector3(x, y, 0), Vector3(0.12, 0.14, 0.25), color.darkened(0.1))
				_box(parent, Vector3(x, y + 0.08, 0), Vector3(0.09, 0.04, 0.09), Color("ffe2a5"), true)
		"range":
			_box(parent, Vector3(0, y, -0.30), Vector3(0.35, 0.07, 0.08), color)
		"gravity":
			for x: float in [-0.28, 0.28]:
				_box(parent, Vector3(x, y + 0.05, 0), Vector3(0.045, 0.12, 0.38), color)
		"venom":
			for x: float in [-0.23, 0.23]:
				_box(parent, Vector3(x, y + 0.02, 0.17), Vector3(0.11, 0.16, 0.11), color, true)
		_:
			_box(parent, Vector3(0, y, 0.25), Vector3(0.19, 0.10, 0.055), color, true)

func _sync_enemies(dt: float) -> void:
	var enemies: Array = run.get("enemies")
	var alive: Dictionary = {}
	for raw: Variant in enemies:
		var enemy: Dictionary = raw
		var id: int = int(enemy.get("id", 0))
		alive[id] = true
		if not _enemy_nodes.has(id):
			_enemy_nodes[id] = _build_enemy(enemy)
		var entry: Dictionary = _enemy_nodes[id]
		var node: Node3D = entry["node"]
		var pos: Vector2 = enemy.get("pos", Vector2.ZERO)
		var target: Vector3 = Vector3(pos.x - 4.0, 0.0, pos.y - 4.0)
		var previous: Vector3 = node.position
		node.position = target
		node.position.y = 0.11 + (0.0 if reduced_motion else sin(_clock * 9.0 + float(id)) * 0.035)
		var movement: Vector3 = target - previous
		if movement.length_squared() > 0.000001:
			node.rotation.y = lerp_angle(node.rotation.y, atan2(movement.x, movement.z), minf(1.0, dt * 12.0))
		var ratio: float = clampf(float(enemy.get("hp", 1.0)) / maxf(1.0, float(enemy.get("max_hp", 1.0))), 0.0, 1.0)
		var bar: Node3D = entry["bar"]
		bar.scale.x = maxf(0.001, ratio)
		bar.position.x = -(1.0 - ratio) * 0.19
		var body: Node3D = entry["body"]
		body.rotation.z = 0.0 if reduced_motion else sin(_clock * 11.0 + float(id)) * 0.035
	for key: Variant in _enemy_nodes.keys():
		if not alive.has(key):
			(_enemy_nodes[key]["node"] as Node3D).queue_free()
			_enemy_nodes.erase(key)

func _build_enemy(enemy: Dictionary) -> Dictionary:
	var node: Node3D = Node3D.new()
	_world.add_child(node)
	var kind: String = str(enemy.get("kind", "runner"))
	var color: Color = Color("e97983")
	if kind == "armored" or kind == "tank":
		color = Color("d396bc")
	elif kind == "swift" or kind == "runner":
		color = Color("f6a56c")
	elif kind == "boss":
		color = Color("d06cdd")
	var body: Node3D = Node3D.new()
	node.add_child(body)
	_box(body, Vector3(0, 0.16, 0), Vector3(0.34, 0.26, 0.38), color.darkened(0.35))
	_box(body, Vector3(0, 0.33, 0), Vector3(0.28, 0.12, 0.27), color)
	_box(body, Vector3(0, 0.21, 0.21), Vector3(0.22, 0.075, 0.035), Color("ffdaa6"), true)
	for x: float in [-0.22, 0.22]:
		_box(body, Vector3(x, 0.08, 0.10), Vector3(0.10, 0.12, 0.13), Color("513c4b"))
		_box(body, Vector3(x, 0.08, -0.12), Vector3(0.10, 0.12, 0.13), Color("513c4b"))
	if kind == "tank" or kind == "armored" or kind == "boss":
		for x: float in [-0.23, 0.23]:
			_box(body, Vector3(x, 0.26, 0), Vector3(0.12, 0.25, 0.43), color)
	if kind == "boss":
		body.scale = Vector3.ONE * 1.45
		for x: float in [-0.16, 0.16]:
			_box(body, Vector3(x, 0.5, 0), Vector3(0.09, 0.25, 0.09), Color("f6d5ff"), true)
	var health: Node3D = Node3D.new()
	node.add_child(health)
	health.position.y = 0.68 if kind == "boss" else 0.53
	_box(health, Vector3.ZERO, Vector3(0.43, 0.035, 0.075), Color("13252e"), true)
	var bar: MeshInstance3D = _box(health, Vector3.ZERO, Vector3(0.38, 0.045, 0.055), color.lightened(0.25), true)
	return {"node":node, "body":body, "bar":bar}

func _build_route(route: Array) -> void:
	_route_markers.clear()
	for child: Node in _route_root.get_children():
		child.queue_free()
	if route.size() < 2:
		return
	for i: int in range(route.size() - 1):
		var a2: Vector2 = route[i]
		var b2: Vector2 = route[i + 1]
		var a: Vector3 = Vector3(a2.x - 4.0, 0.035, a2.y - 4.0)
		var b: Vector3 = Vector3(b2.x - 4.0, 0.035, b2.y - 4.0)
		var line: MeshInstance3D = _line_box(_route_root, a, b, 0.055, Color("e3aa67"))
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if i % 2 == 0:
			var direction: Vector3 = (b - a).normalized()
			var left: Vector3 = Vector3(direction.z, 0, -direction.x)
			var center: Vector3 = a.lerp(b, 0.5)
			_line_box(_route_root, center - direction * 0.10 + left * 0.09, center + direction * 0.04, 0.032, Color("ffdb9a"))
			_line_box(_route_root, center - direction * 0.10 - left * 0.09, center + direction * 0.04, 0.032, Color("ffdb9a"))
	var start: Vector2 = route[0]
	var end: Vector2 = route[route.size() - 1]
	_gate(Vector3(start.x - 4, 0, start.y - 4), Color("f18d85"), false)
	_gate(Vector3(end.x - 4, 0, end.y - 4), Color("8ce0bb"), true)
	for i: int in range(3):
		var marker: MeshInstance3D = _box(_route_root, Vector3.ZERO, Vector3(0.11, 0.045, 0.11), Color("ffe3a6"), true)
		_route_markers.append(marker)

func _animate_route() -> void:
	if run == null or _route_markers.is_empty():
		return
	var route: Array = run.get("route")
	if route.size() < 2:
		return
	for i: int in range(_route_markers.size()):
		var marker: MeshInstance3D = _route_markers[i]
		marker.visible = not reduced_motion
		var progress_value: float = fmod(_clock * 1.55 + float(i) * float(route.size() - 1) / 3.0, float(route.size() - 1))
		var idx: int = int(progress_value)
		var a: Vector2 = route[idx]
		var b: Vector2 = route[mini(idx + 1, route.size() - 1)]
		var pos: Vector2 = a.lerp(b, progress_value - float(idx))
		marker.position = Vector3(pos.x - 4.0, 0.071, pos.y - 4.0)

func _gate(pos: Vector3, color: Color, core: bool) -> void:
	var gate: Node3D = Node3D.new()
	_route_root.add_child(gate)
	gate.position = pos
	_box(gate, Vector3(0, 0.03, 0), Vector3(0.62, 0.10, 0.62), Color("203a45"))
	if core:
		_box(gate, Vector3(0, 0.25, 0), Vector3(0.37, 0.36, 0.37), color.darkened(0.25))
		_box(gate, Vector3(0, 0.48, 0), Vector3(0.23, 0.16, 0.23), color, true)
		_box(gate, Vector3(0, 0.60, 0), Vector3(0.10, 0.08, 0.10), Color("d9ffe0"), true)
	else:
		for x: float in [-0.25, 0.25]:
			_box(gate, Vector3(x, 0.29, 0), Vector3(0.09, 0.50, 0.13), color)
		_box(gate, Vector3(0, 0.54, 0), Vector3(0.59, 0.08, 0.13), color, true)

func _refresh_range() -> void:
	for child: Node in _range_root.get_children():
		child.queue_free()
	if run == null or selected_cell < 0:
		return
	var towers: Dictionary = run.get("towers")
	if not towers.has(selected_cell):
		return
	var stats: Dictionary = run.call("tower_stats", selected_cell)
	var radius: float = float(stats.get("range", 2.4))
	var center: Vector3 = _cell_pos(selected_cell) + Vector3(0, 0.028, 0)
	for i: int in range(48):
		if i % 2 == 1:
			continue
		var a: float = float(i) * TAU / 48.0
		var b: float = float(i + 1) * TAU / 48.0
		_line_box(_range_root, center + Vector3(cos(a), 0, sin(a)) * radius, center + Vector3(cos(b), 0, sin(b)) * radius, 0.023, Color("6db49e"))

func play_event(event: Dictionary) -> void:
	if _fx_root == null:
		return
	var kind: String = str(event.get("type", ""))
	var cell: int = int(event.get("cell", -1))
	var pos: Vector3 = _cell_pos(cell) if cell >= 0 else Vector3.ZERO
	if event.get("pos") is Vector2:
		var p: Vector2 = event["pos"]
		pos = Vector3(p.x - 4.0, 0.14, p.y - 4.0)
	var color: Color = event.get("color", Color("8ee7ca")) if event.get("color") is Color else Color("8ee7ca")
	match kind:
		"plant":
			if run != null and str(run.get("phase")) == "solve" and not bool(event.get("illegal",false)):
				_start_seed_planting(cell, int(event.get("number",0)))
			else:
				_burst(pos + Vector3(0, 0.18, 0), color, 10, 0.7)
				_ring(pos, color, 0.9, 0.45)
		"equip":
			if cell >= 0 and not str(event.get("kind","")).is_empty():
				_equip_landings[cell] = 0.0
				if event.has("slot"): _equip_slots[cell] = int(event.slot)
				else: _equip_slots.erase(cell)
			_burst(pos + Vector3(0,0.48,0),color,7,0.55)
			_ring(pos,color,0.7,0.45)
			_refresh_range()
		"upgrade":
			_burst(pos + Vector3(0, 0.55, 0), Color("ffd694"), 15, 1.1)
			_ring(pos, Color("ffd694"), 1.1, 0.65)
			_refresh_range()
		"shot":
			var target: Vector2 = event.get("target", Vector2(4, 4))
			var source: Vector3 = pos + Vector3(0, 0.5, 0)
			if _tower_nodes.has(cell):
				var entry: Dictionary = _tower_nodes[cell]
				var head: Node3D = entry["head"]
				source.y = head.position.y
				entry["recoil"] = 1.0
				color = _family(int((run.get("towers") as Dictionary)[cell].get("number", 1)))
			var target3: Vector3 = Vector3(target.x - 4, 0.30, target.y - 4)
			var beam: MeshInstance3D = _line_box(_fx_root, source, target3, 0.035, color.lightened(0.20))
			_beams.append({"node":beam,"life":0.11,"max_life":0.11})
			_burst(target3, color, 3, 0.30)
		"hit":
			_burst(pos + Vector3(0, 0.23, 0), color, 3, 0.3)
		"kill":
			_burst(pos + Vector3(0, 0.2, 0), Color("f3b883"), 8, 0.85)
			_burst(pos + Vector3(0, 0.3, 0), Color("b89be8"), 3, 1.2)
		"leak":
			_shake = 0.45
			_ring(pos, Color("ff7d7d"), 1.4, 0.4)
		"loot", "chest_open":
			_burst(pos + Vector3(0, 0.6, 0), Color("ffd48b"), 24, 2.0)
			_ring(pos, Color("ffd48b"), 2.5, 0.8)
		"phase":
			_last_board = ""
			if str(run.get("phase")) != "solve": _clear_seed_plantings()
			if str(run.get("phase")) == "battle":
				_ring(Vector3.ZERO, Color("78dcc3"), 6.0, 0.8)

func _start_seed_planting(cell: int, number: int) -> void:
	if reduced_motion or cell < 0 or cell >= 81 or number < 1 or number > 9: return
	if bool(run.givens[cell]) or int(run.board[cell]) != number or not run.towers.has(cell): return
	if _seed_plantings.has(cell): return
	var node := Node3D.new()
	_fx_root.add_child(node)
	node.position = _cell_pos(cell)
	var seed := Node3D.new()
	node.add_child(seed)
	_box(seed, Vector3.ZERO, Vector3(0.24,0.20,0.29), Color("8c633d"))
	_box(seed, Vector3(0.0,0.108,0.0), Vector3(0.09,0.028,0.26), Color("edc581"))
	_box(seed, Vector3(0.035,0.14,-0.07), Vector3(0.10,0.07,0.11), _family(number).darkened(0.10), true)
	var soil := Node3D.new()
	node.add_child(soil)
	for offset: Vector3 in [Vector3(-0.095,0.025,-0.05),Vector3(0.09,0.023,0.035),Vector3(-0.015,0.024,0.10),Vector3(0.025,0.026,-0.105)]:
		_box(soil,offset,Vector3(0.105,0.04,0.09),Color("827257"))
	var pulse := Node3D.new()
	node.add_child(pulse)
	_square_frame(pulse,1.0,0.022,_family(number).darkened(0.25),0.026)
	_seed_plantings[cell] = {"age":0.0,"number":number,"node":node,"seed":seed,"soil":soil,"pulse":pulse}
	_animate_seed_planting(cell)
	if _tower_nodes.has(cell): (_tower_nodes[cell].seed as Node3D).visible = false

func _animate_seed_planting(cell: int) -> void:
	var entry: Dictionary = _seed_plantings[cell]
	var age: float = float(entry.age)
	var seed: Node3D = entry.seed
	seed.position = SeedPlanting.seed_offset(age)
	seed.scale = Vector3.ONE * maxf(0.001,SeedPlanting.seed_scale(age))
	seed.visible = age < SeedPlanting.REVEAL_AT
	seed.rotation = Vector3(0.0,lerpf(-0.75,0.2,clampf(age/SeedPlanting.LAND_AT,0.0,1.0)),0.0)
	var soil: Node3D = entry.soil
	soil.visible = age >= SeedPlanting.LAND_AT and age < SeedPlanting.REVEAL_END
	soil.scale = Vector3.ONE * maxf(0.001,SeedPlanting.soil_scale(age))
	var pulse: Node3D = entry.pulse
	var width: float = SeedPlanting.impact_scale(age)
	var weight: float = maxf(0.001,SeedPlanting.impact_alpha(age))
	pulse.visible = age >= SeedPlanting.LAND_AT
	pulse.scale = Vector3(width,1.0,width)
	for index: int in range(pulse.get_child_count()):
		var edge: Node3D = pulse.get_child(index)
		edge.scale = Vector3(0.022*weight,0.022,1.0) if index%2 == 0 else Vector3(1.0,0.022,0.022*weight)
	_apply_seed_number(cell)

func _apply_seed_number(cell: int) -> void:
	if not _seed_plantings.has(cell) or run == null or str(run.phase) != "solve": return
	var age: float = float(_seed_plantings[cell].age)
	_labels[cell].modulate.a = SeedPlanting.number_alpha(age)
	_labels[cell].scale = Vector3.ONE * SeedPlanting.number_scale(age)

func _update_seed_plantings(dt: float) -> void:
	if _seed_plantings.is_empty(): return
	if reduced_motion or str(run.phase) != "solve":
		_clear_seed_plantings()
		return
	var completed: bool = false
	for cell: Variant in _seed_plantings.keys():
		var entry: Dictionary = _seed_plantings[cell]
		entry.age = float(entry.age) + maxf(0.0,dt)
		if float(entry.age) >= SeedPlanting.DURATION or int(run.board[cell]) != int(entry.number) or bool(run.givens[cell]):
			(entry.node as Node3D).visible = false
			(entry.node as Node3D).queue_free()
			_labels[cell].scale = Vector3.ONE
			_seed_plantings.erase(cell)
			completed = true
		else:
			_animate_seed_planting(int(cell))
	if completed: _update_palette(smoothstep(0.0,1.0,_morph))

func _clear_seed_plantings() -> void:
	for cell: Variant in _seed_plantings:
		var entry: Dictionary = _seed_plantings[cell]
		(entry.node as Node3D).visible = false
		(entry.node as Node3D).queue_free()
		_labels[cell].scale = Vector3.ONE
	_seed_plantings.clear()
	if not _labels.is_empty(): _update_palette(smoothstep(0.0,1.0,_morph))

func _burst(pos: Vector3, color: Color, count: int, strength: float) -> void:
	if reduced_motion:
		count = mini(count, 3)
	for i: int in range(count):
		if _particles.size() >= 220:
			return
		var size: float = _rng.randf_range(0.035, 0.085)
		var cube: MeshInstance3D = _box(_fx_root, pos, Vector3.ONE * size, color.lightened(float(_rng.randi_range(0, 3)) * 0.1 - 0.1), true)
		cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var velocity: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.6, 2.1), _rng.randf_range(-1, 1)) * strength
		_particles.append({"node":cube, "velocity":velocity, "life":_rng.randf_range(0.35, 0.65), "size":size})

func _ring(pos: Vector3, color: Color, radius: float, duration: float) -> void:
	var node: Node3D = Node3D.new()
	_fx_root.add_child(node)
	node.position = pos + Vector3(0, 0.04, 0)
	for i: int in range(24):
		var a: float = float(i) * TAU / 24.0
		var b: float = float(i + 1) * TAU / 24.0
		_line_box(node, Vector3(cos(a), 0, sin(a)), Vector3(cos(b), 0, sin(b)), 0.026, color)
	node.scale = Vector3.ONE * 0.15
	_rings.append({"node":node, "life":duration,"duration":duration,"radius":radius})

func _update_fx(dt: float) -> void:
	for i: int in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p["life"] = float(p["life"]) - dt
		var node: Node3D = p["node"]
		if float(p["life"]) <= 0.0:
			node.queue_free()
			_particles.remove_at(i)
			continue
		var velocity: Vector3 = p["velocity"]
		velocity.y -= dt * 3.6
		p["velocity"] = velocity
		node.position += velocity * dt
		node.rotation += Vector3(2.3, 3.7, 1.7) * dt
		node.scale = Vector3.ONE * float(p["size"]) * minf(1.0, float(p["life"]) * 5.0)
	for i: int in range(_beams.size() - 1, -1, -1):
		var beam: Dictionary = _beams[i]
		beam["life"] = float(beam["life"]) - dt
		var node: Node3D = beam["node"]
		if float(beam["life"]) <= 0.0:
			node.queue_free()
			_beams.remove_at(i)
	for i: int in range(_rings.size() - 1, -1, -1):
		var ring: Dictionary = _rings[i]
		ring["life"] = float(ring["life"]) - dt
		var node: Node3D = ring["node"]
		if float(ring["life"]) <= 0.0:
			node.queue_free()
			_rings.remove_at(i)
			continue
		var t: float = 1.0 - float(ring["life"]) / float(ring["duration"])
		node.scale = Vector3(float(ring["radius"]) * t, maxf(0.1, 1.0 - t), float(ring["radius"]) * t)

func _plant(pos: Vector3, index: int) -> Node3D:
	var plant: Node3D = Node3D.new()
	_world.add_child(plant)
	plant.position = pos
	_box(plant, Vector3(0, -0.1, 0), Vector3(0.34, 0.18, 0.34), Color("273d42"))
	_box(plant, Vector3(0, 0.09, 0), Vector3(0.06, 0.24, 0.06), Color("4c7561"))
	var color: Color = Color("5c9f87") if index % 3 != 0 else Color("a1b97d")
	_box(plant, Vector3(-0.09, 0.13, 0), Vector3(0.21, 0.075, 0.12), color)
	_box(plant, Vector3(0.07, 0.23, 0.015), Vector3(0.19, 0.075, 0.13), color.lightened(0.13))
	if index % 4 == 0:
		_box(plant, Vector3(0.015, 0.33, 0), Vector3(0.10, 0.10, 0.10), Color("f4c086"))
	return plant

func _square_frame(parent: Node3D, width: float, thickness: float, color: Color, y: float) -> void:
	for sign_value: int in [-1, 1]:
		_box(parent, Vector3(sign_value * width / 2, y, 0), Vector3(thickness, thickness, width), color, true)
		_box(parent, Vector3(0, y, sign_value * width / 2), Vector3(width, thickness, thickness), color, true)

func _box(parent: Node3D, pos: Vector3, dimensions: Vector3, color: Color, unshaded: bool = false) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = _box_mesh
	instance.material_override = _material(color, unshaded)
	instance.position = pos
	instance.scale = dimensions
	parent.add_child(instance)
	return instance

func _line_box(parent: Node3D, a: Vector3, b: Vector3, width: float, color: Color) -> MeshInstance3D:
	var distance: float = a.distance_to(b)
	var mesh: MeshInstance3D = _box(parent, a.lerp(b, 0.5), Vector3(width, width, maxf(distance, 0.001)), color, true)
	if distance > 0.001:
		mesh.rotation = Basis.looking_at((b - a).normalized(), Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT).get_euler()
	return mesh

func _material(color: Color, unshaded: bool = false) -> Material:
	var key: String = color.to_html() + ("u" if unshaded else "s")
	if not _materials.has(key):
		_materials[key] = VoxelMaterial.create(color, unshaded)
	return _materials[key]

func _cell_pos(cell: int) -> Vector3:
	return Vector3(float(cell % 9) - 4.0, 0.0, float(cell / 9) - 4.0)

func _family(number: int) -> Color:
	return FAMILY_COLORS[clampi(number - 1, 0, 8)]
