class_name DefenseCanvasBoard
extends Node2D
## Voxel battlefield projected on the CPU and painted by Godot's CanvasItem renderer.
## This deliberately has no MeshInstance3D, SubViewport texture or spatial shader.
## The exact same authoritative run model drives the native and canvas renderers.

const FAMILY_COLORS: Array[Color] = [Color("6de8ff"), Color("a4c7ff"), Color("c6a0ff"), Color("ffae68"), Color("fb86c3"), Color("9be878"), Color("ffe188"), Color("bb9bff"), Color("dec3ed")]
const MODULE_COLORS: Dictionary = {"rapid":Color("6de8ff"), "electric":Color("c6a0ff"), "frost":Color("a4c7ff"), "blast":Color("ffae68"), "venom":Color("9be878"), "range":Color("ffe188"), "power":Color("fb86c3"), "gravity":Color("bb9bff"), "nova":Color("ff7289")}
const SeedPlanting = preload("res://scripts/seed_planting.gd")
const BoardTransition = preload("res://scripts/board_transition.gd")
const CameraOrbit = preload("res://scripts/camera_orbit.gd")
const EnemyHealth = preload("res://scripts/enemy_health.gd")

var run: RefCounted
var selected_cell: int = -1
var selected_number: int = 0
var _family_focus: int = 0
var reduced_motion: bool = false
var _board_rect: Rect2 = Rect2()
var _clock: float = 0.0
var _morph: float = 0.0
var _blend: float = 0.0
var _scale: float = 40.0
var _origin: Vector2 = Vector2.ZERO
var _axis_x: Vector2 = Vector2.RIGHT
var _axis_z: Vector2 = Vector2.DOWN
var _axis_y: Vector2 = Vector2.ZERO
var _view: Vector3 = Vector3.UP
var _faces: Array[Dictionary] = []
var _effects: Array[Dictionary] = []
var _recoil: Dictionary = {}
var _enemy_positions: Dictionary = {}
var _enemy_angles: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _font: Font
var _drop_cell: int = -1
var _drop_number: int = 0
var _drop_allowed: bool = false
var _attachment_cell: int = -1
var _attachment_kind: String = ""
var _attachment_allowed: bool = false
var _attachment_targets: bool = false
var _equip_landings: Dictionary = {}
var _equip_slots: Dictionary = {}
var _seed_plantings: Dictionary = {}
var _camera_orbit = CameraOrbit.new()

func setup(model: RefCounted) -> void:
	run = model
	_camera_orbit.clear()
	_rng.seed = 44219
	_font = ThemeDB.fallback_font
	_effects.clear()
	_seed_plantings.clear()
	_equip_landings.clear()
	_equip_slots.clear()
	set_attachment_preview(-1,"",false)
	set_attachment_targets(false)
	_recoil.clear()
	_enemy_positions.clear()
	_enemy_angles.clear()
	_morph = 0.0 if str(run.phase) == "solve" else 1.0
	_update_projection()
	queue_redraw()

func tick(dt: float) -> void:
	if run == null: return
	_clock += dt
	_camera_orbit.advance(dt,reduced_motion)
	var target: float = 0.0 if str(run.phase) == "solve" else 1.0
	_morph = BoardTransition.advance(_morph, target, dt, reduced_motion)
	_update_projection()
	_tick_seed_plantings(dt)
	for cell: Variant in _equip_landings.keys():
		_equip_landings[cell] = float(_equip_landings[cell]) + dt
		if float(_equip_landings[cell]) >= 0.48:
			_equip_landings.erase(cell)
			_equip_slots.erase(cell)
	for key: Variant in _recoil.keys():
		_recoil[key] = maxf(0.0, float(_recoil[key]) - dt * 6.0)
		if float(_recoil[key]) <= 0.0: _recoil.erase(key)
	for i: int in range(_effects.size() - 1, -1, -1):
		_effects[i].age = float(_effects[i].age) + dt
		if float(_effects[i].age) >= float(_effects[i].life): _effects.remove_at(i)
	var alive: Dictionary = {}
	for enemy: Dictionary in run.enemies:
		var id: int = int(enemy.id)
		alive[id] = true
		var pos: Vector2 = enemy.pos
		var previous: Vector2 = _enemy_positions.get(id, pos)
		var movement: Vector2 = pos - previous
		if movement.length_squared() > 0.000001:
			_enemy_angles[id] = lerp_angle(float(_enemy_angles.get(id,0.0)), atan2(movement.x,movement.y), minf(1.0,dt*14.0))
		_enemy_positions[id] = pos
	for id: Variant in _enemy_positions.keys():
		if not alive.has(id):
			_enemy_positions.erase(id)
			_enemy_angles.erase(id)
	queue_redraw()

func set_selected(cell: int, number: int = 0) -> void:
	selected_cell = cell
	selected_number = clampi(number, 0, 9)
	queue_redraw()

func set_drop_preview(cell: int, number: int, allowed: bool) -> void:
	_drop_cell = cell if cell >= 0 and cell < 81 else -1
	_drop_number = clampi(number, 0, 9)
	_drop_allowed = allowed
	queue_redraw()

func set_attachment_preview(cell: int, kind: String, allowed: bool) -> void:
	_attachment_cell = cell if cell >= 0 and cell < 81 else -1
	_attachment_kind = kind
	_attachment_allowed = allowed
	queue_redraw()

func set_attachment_targets(active: bool) -> void:
	_attachment_targets = active
	queue_redraw()

func set_family_focus(number: int) -> void:
	var value: int = clampi(number,0,9)
	if _family_focus == value: return
	_family_focus = value
	queue_redraw()

func set_panel_open(_value: bool) -> void:
	# Main owns the HUD-free rectangle, including the expanded inventory dock.
	pass

func rotate_camera(radians: float) -> void:
	_camera_orbit.rotate(radians)

func reset_camera() -> void:
	_camera_orbit.reset()

func camera_is_rotated() -> bool:
	return _camera_orbit.is_rotated()

func get_camera_yaw() -> float:
	return _camera_orbit.yaw

func set_board_rect(value: Rect2) -> void:
	_board_rect = value
	_update_projection()
	queue_redraw()

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if value: _seed_plantings.clear()
	queue_redraw()

func _tick_seed_plantings(dt: float) -> void:
	# Presentation never delays the answer or blocks the next placement.
	if reduced_motion or str(run.phase) != "solve":
		_seed_plantings.clear()
		return
	for key: Variant in _seed_plantings.keys():
		var cell: int = int(key)
		var planting: Dictionary = _seed_plantings[key]
		planting.age = float(planting.age) + maxf(0.0,dt)
		if float(planting.age) >= SeedPlanting.DURATION or not run.towers.has(cell) or int(run.board[cell]) != int(planting.number):
			_seed_plantings.erase(key)

func _update_projection() -> void:
	_blend = BoardTransition.eased(_morph)
	var rect: Rect2 = _board_rect
	if not rect.has_area():
		var size: Vector2 = get_viewport_rect().size
		rect = Rect2(Vector2(16,16),size-Vector2(32,32))
	var portrait: bool = get_viewport_rect().size.y > get_viewport_rect().size.x
	var yaw: float = (0.12 if portrait else 0.32) * _blend + _camera_orbit.yaw
	# Ease the pitch itself: deriving height from a flattened blend introduces
	# a square-root slope at the overhead endpoint and starts the tilt abruptly.
	var pitch: float = acos(0.76 if portrait else 0.70) * _blend
	var flatten: float = cos(pitch)
	var height: float = sin(pitch)
	_axis_x = Vector2(cos(yaw),sin(yaw)*flatten)
	_axis_z = Vector2(-sin(yaw),cos(yaw)*flatten)
	_axis_y = Vector2(0,-height)
	_view = Vector3(sin(yaw)*height,flatten,cos(yaw)*height)
	var low: Vector2 = Vector2(INF,INF)
	var high: Vector2 = Vector2(-INF,-INF)
	for x: float in [-4.98,4.98]:
		for z: float in [-4.98,4.98]:
			for y: float in [-0.78,1.7*_blend]:
				var point: Vector2 = _axis_x*x + _axis_z*z + _axis_y*y
				low = low.min(point)
				high = high.max(point)
	var span: Vector2 = high-low
	var inset: Rect2 = rect.grow(-5.0)
	_scale = maxf(1.0,minf(inset.size.x/span.x,inset.size.y/span.y))
	_origin = rect.get_center() - (low+high)*0.5*_scale

func project_point(point: Vector3) -> Vector2:
	return _origin + (_axis_x*point.x + _axis_y*point.y + _axis_z*point.z)*_scale

func _cell_pos(cell: int) -> Vector3:
	return Vector3(float(cell%9)-4.0,0.0,float(cell/9)-4.0)

func _world_pos(point: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(point.x-4.0,height,point.y-4.0)

func cell_screen_position(cell: int) -> Vector2:
	if cell < 0 or cell >= 81: return Vector2(-1000,-1000)
	return project_point(_cell_pos(cell))

func tower_screen_position(cell: int) -> Vector2:
	if run == null or not run.towers.has(cell): return cell_screen_position(cell)
	var tower: Dictionary = run.towers[cell]
	return project_point(_cell_pos(cell)+Vector3(0,_tower_height(tower),0))

func cell_at_screen(screen_pos: Vector2) -> int:
	if run == null or (_board_rect.has_area() and not _board_rect.has_point(screen_pos)): return -1
	# The visible turret is a target, not just the square hidden underneath it.
	if _blend > 0.65:
		var best: int = -1
		var distance: float = maxf(12.0,_scale*0.34)
		for key: Variant in run.towers:
			var candidate: float = screen_pos.distance_to(tower_screen_position(int(key)))
			if candidate < distance:
				distance = candidate
				best = int(key)
		if best >= 0: return best
	var point: Vector2 = (screen_pos-_origin)/_scale
	var determinant: float = _axis_x.cross(_axis_z)
	if absf(determinant) < 0.00001: return -1
	var x: float = point.cross(_axis_z)/determinant
	var z: float = _axis_x.cross(point)/determinant
	if x < -4.5 or x >= 4.5 or z < -4.5 or z >= 4.5: return -1
	return int(floor(z+4.5))*9 + int(floor(x+4.5))

func _draw() -> void:
	if run == null or run.board.size() != 81: return
	if _font == null: _font = ThemeDB.fallback_font
	_faces.clear()
	_draw_island()
	_flush_faces()
	_draw_tiles()
	if _blend > 0.08: _draw_route()
	_draw_selection()
	_draw_seed_ground()
	_draw_digits()
	_draw_drop_preview()
	_faces.clear()
	if _blend > 0.05: _draw_gates()
	for key: Variant in run.towers:
		_draw_tower(int(key),run.towers[key])
	for enemy: Dictionary in run.enemies: _draw_enemy(enemy)
	_draw_attachment_preview()
	_flush_faces()
	_draw_entity_labels()
	_draw_effects()
	_draw_tower_badges()

func _draw_island() -> void:
	# Layered floating chassis. All faces are normal 2D polygons, including trim.
	_cube(Vector3(0,-0.30,0),Vector3(9.55,0.52,9.55),Color("203e46"))
	_cube(Vector3(0,-0.63,0),Vector3(9.16,0.16,9.16),Color("102b37"))
	_cube(Vector3(0,-0.75,0),Vector3(8.1,0.10,8.1),Color("153a43"))
	var trim: Color = Color("7ca19a").lerp(Color("3c7c78"),_blend)
	for side: float in [-1.0,1.0]:
		_cube(Vector3(side*4.64,-0.005,0),Vector3(0.18,0.12,9.46),trim)
		_cube(Vector3(0,-0.005,side*4.64),Vector3(9.46,0.12,0.18),trim)
		if _blend > 0.1:
			for q: int in range(-4,5):
				_cube(Vector3(float(q),-0.31,side*4.784),Vector3(0.36,0.065,0.025),Color("59dbbe"))
				_cube(Vector3(side*4.784,-0.31,float(q)),Vector3(0.025,0.065,0.36),Color("59dbbe"))
	for x: float in [-4.65,4.65]:
		for z: float in [-4.65,4.65]:
			_cube(Vector3(x,0.06,z),Vector3(0.26,0.13,0.26),Color("25464d"))
			_cube(Vector3(x,0.14,z),Vector3(0.12,0.035,0.12),Color("ffca8b"))

func _draw_tiles() -> void:
	for cell: int in range(81):
		var alternate: bool = ((cell%9)/3 + (cell/9)/3)%2 == 0
		var paper: Color = Color("a8b8a6") if alternate else Color("99aca0")
		var tactical: Color = Color("142b30") if alternate else Color("193439")
		if run.givens[cell]: tactical = tactical.lightened(0.025)
		if selected_cell >= 0 and (cell%9 == selected_cell%9 or cell/9 == selected_cell/9):
			paper = paper.lerp(Color("729e8c"),0.25)
			tactical = tactical.lightened(0.025)
		var matching: bool = selected_number > 0 and int(run.board[cell]) == selected_number
		if _family_focus > 0: matching = run.towers.has(cell) and int(run.towers[cell].number) == _family_focus
		if matching:
			paper = Color("8fb6bf")
			tactical = Color("244451")
		if cell == selected_cell:
			paper = Color("c7b27c")
			tactical = Color("28534e")
		var pos: Vector3 = _cell_pos(cell)
		var color: Color = paper.lerp(tactical,_blend)
		draw_colored_polygon(_quad(pos,0.492,0.0),color)
		# A restrained bevel anchors each tile; avoid a white luminous tabletop.
		var bevel: PackedVector2Array = _quad(pos,0.465,0.008)
		var edge_width: float = maxf(1.0,_scale*0.018)
		draw_line(bevel[0],bevel[1],color.lightened(0.055),edge_width)
		draw_line(bevel[0],bevel[3],color.lightened(0.035),edge_width)
		draw_line(bevel[1],bevel[2],color.darkened(0.12),edge_width)
		draw_line(bevel[2],bevel[3],color.darkened(0.16),edge_width)
		if _attachment_targets and run.towers.has(cell):
			var full: bool = run.towers[cell].attachments.size() >= 5
			_polyline_closed(_quad(pos,0.385,0.045),Color("44615f") if full else Color("5b9d88"),maxf(1.0,_scale*0.02))
		if matching:
			var match_color: Color = FAMILY_COLORS[_family_focus-1].lightened(0.18) if _family_focus > 0 else Color("77d8ee")
			_polyline_closed(_quad(pos,0.445,0.025),Color("357991").lerp(match_color,_blend),maxf(1.35,_scale*0.032))
	# Draw each shared edge once, with a minimum pixel weight on small screens.
	# The 3x3 separators are intentionally much stronger than cell boundaries.
	for line: int in range(10):
		var boundary: float = float(line)-4.5
		var major: bool = line%3 == 0
		var grid: Color = Color("29453f").lerp(Color("426b66"),_blend) if major else Color("6a8078").lerp(Color("29474c"),_blend)
		var width: float = maxf(2.6,_scale*0.075) if major else maxf(1.0,_scale*0.026)
		draw_line(project_point(Vector3(boundary,0.01,-4.5)),project_point(Vector3(boundary,0.01,4.5)),grid,width,true)
		draw_line(project_point(Vector3(-4.5,0.01,boundary)),project_point(Vector3(4.5,0.01,boundary)),grid,width,true)

func _draw_digits() -> void:
	for cell: int in range(81):
		var number: int = int(run.board[cell])
		if number <= 0: continue
		var planted: bool = run.towers.has(cell)
		if planted and _blend > 0.60: continue
		var color: Color = Color("17343f").lerp(Color("c2d8d1"),_blend)
		if planted:
			color = FAMILY_COLORS[number-1].darkened(0.72).lerp(FAMILY_COLORS[number-1],_blend)
			if bool(run.towers[cell].illegal): color = Color("9d2440").lerp(Color("ff9c9c"),_blend)
		var reveal_scale: float = 1.0
		if _seed_plantings.has(cell):
			var age: float = float(_seed_plantings[cell].age)
			color.a *= SeedPlanting.number_alpha(age)
			if color.a <= 0.001: continue
			reveal_scale = SeedPlanting.number_scale(age)
		var pos: Vector3 = _cell_pos(cell)
		if planted: pos.z += _blend*0.32
		var font_size: int = maxi(10,roundi(_scale*lerpf(0.58,0.34 if planted else 0.40,_blend)*reveal_scale))
		_text_center(str(number),project_point(pos),font_size,color)

func _draw_seed_ground() -> void:
	for key: Variant in _seed_plantings:
		var planting: Dictionary = _seed_plantings[key]
		var age: float = float(planting.age)
		var alpha: float = SeedPlanting.impact_alpha(age)
		var family: Color = FAMILY_COLORS[clampi(int(planting.number)-1,0,8)]
		if alpha > 0.001:
			var radius: float = SeedPlanting.impact_scale(age) * 0.5
			_polyline_closed(_quad(_cell_pos(int(key)),radius,0.026),Color(family.darkened(0.30),alpha),maxf(1.0,_scale*0.020))

func _draw_foundation(origin: Vector3, family: Color, age: float, size: float) -> void:
	for index: int in range(4):
		var corner: Vector3 = SeedPlanting.corner_offset(age,index) * size
		var scale3: float = SeedPlanting.corner_scale(age,index) * size
		for part: Dictionary in SeedPlanting.corner_blocks(index,family):
			_cube(origin+corner+Vector3(part.offset)*scale3,Vector3(part.size)*scale3,Color(part.color))

func _draw_tower_badges() -> void:
	if _blend <= 0.60: return
	for key: Variant in run.towers:
		var cell: int = int(key)
		var number: int = int(run.towers[cell].number)
		var focused: bool = number == (_family_focus if _family_focus > 0 else selected_number)
		# Keep the compact ID beside the body so it cannot cover the next row's
		# colored turret roof in the flatter portrait camera.
		var center: Vector2 = project_point(_cell_pos(cell)+Vector3(0.22,0.13,0.28))
		var emphasized: bool = focused or cell == selected_cell
		var size: int = maxi(13 if emphasized else 11,roundi(_scale*(0.36 if emphasized else 0.30)))
		var color: Color = Color("f6e7c8") if cell == selected_cell else FAMILY_COLORS[number-1].lerp(Color("b4c9c5"),0.36)
		if bool(run.towers[cell].illegal): color = Color("e6aaa6")
		color.a = 0.88 if emphasized else 0.58
		var text: String = str(number)
		var width: float = _font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		var badge_size: Vector2 = Vector2(width+6.0,float(size)+2.0)
		var badge: Rect2 = Rect2(center-badge_size*0.5,badge_size)
		draw_rect(badge,Color(Color("102a35"),0.58 if emphasized else 0.32))
		if emphasized: draw_rect(badge,Color(color,0.38),false,1.0)
		var baseline: Vector2 = center+Vector2(-width*0.5,(_font.get_ascent(size)-_font.get_descent(size))*0.5)
		draw_string_outline(_font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,maxi(1,roundi(_scale*0.035)),Color(Color("0a202a"),0.78 if emphasized else 0.48))
		draw_string(_font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw_selection() -> void:
	if selected_cell < 0 or selected_cell >= 81: return
	var pos: Vector3 = _cell_pos(selected_cell)
	var tint: Color = Color("187568").lerp(Color("8dffce"),_blend)
	if run.towers.has(selected_cell) and _blend > 0.7:
		var radius: float = float(run.tower_stats(selected_cell).get("range",2.4))
		for i: int in range(48):
			if i%2 == 1: continue
			var a: float = float(i)/48.0*TAU
			var b: float = float(i+1)/48.0*TAU
			var start: Vector3 = pos+Vector3(cos(a)*radius,0.025,sin(a)*radius)
			var finish: Vector3 = pos+Vector3(cos(b)*radius,0.025,sin(b)*radius)
			# Range hints are clipped to the battlefield to protect the compact HUD.
			if absf(start.x) <= 4.5 and absf(start.z) <= 4.5 and absf(finish.x) <= 4.5 and absf(finish.z) <= 4.5:
				draw_line(project_point(start),project_point(finish),Color(tint,0.48),maxf(1.0,_scale*0.024),true)
	_polyline_closed(_quad(pos,0.455,0.02),Color("13333d"),maxf(3.6,_scale*0.10))
	_polyline_closed(_quad(pos,0.455,0.03),tint,maxf(1.8,_scale*0.043))
	for x: float in [-0.415,0.415]:
		for z: float in [-0.415,0.415]:
			var point: Vector2 = project_point(pos+Vector3(x,0.04,z))
			var side: float = maxf(3.0,_scale*0.095)
			draw_rect(Rect2(point-Vector2.ONE*side*0.5,Vector2.ONE*side),Color("ffe6a6"))

func _draw_drop_preview() -> void:
	if _drop_cell < 0 or _drop_cell >= 81: return
	var pos: Vector3 = _cell_pos(_drop_cell)
	var tint: Color = Color("81efc0") if _drop_allowed else Color("ff788b")
	_polyline_closed(_quad(pos,0.455,0.035),Color("13333d"),maxf(4.0,_scale*0.12))
	_polyline_closed(_quad(pos,0.455,0.04),tint,maxf(2.0,_scale*0.06))
	if int(run.board[_drop_cell]) == 0 and _drop_number > 0:
		var ink: Color = Color("176a54").lerp(Color("c2ffe3"),_blend) if _drop_allowed else Color("9c2440").lerp(Color("ffacb9"),_blend)
		_text_center(str(_drop_number),project_point(pos),maxi(10,roundi(_scale*0.58)),ink)

func _draw_attachment_preview() -> void:
	if _attachment_cell < 0 or _attachment_cell >= 81: return
	var pos: Vector3 = _cell_pos(_attachment_cell)
	var tint: Color = MODULE_COLORS.get(_attachment_kind,Color("83e7c1")) if _attachment_allowed else Color("c08b83")
	_polyline_closed(_quad(pos,0.425,0.07),tint,maxf(1.8,_scale*0.042))
	var used: int = run.towers[_attachment_cell].attachments.size() if run.towers.has(_attachment_cell) else 0
	for slot: int in range(5):
		var color: Color = Color("526a6c") if slot >= used else Color("accac1")
		if slot == used and _attachment_allowed: color = tint.lightened(0.2)
		_cube(pos+Vector3((slot-2)*0.13,0.09,0.39),Vector3(0.09,0.055,0.06),color)
	if _attachment_allowed and used < 5:
		var hover: float = 0.0 if reduced_motion else sin(_clock*3.0)*0.035
		var y: float = (0.91+float(used)*0.16+hover)*maxf(0.25,_blend)
		_cube(pos+Vector3(0,y,0),Vector3(0.43,0.11,0.43),Color("2d4956"))
		_cube(pos+Vector3(0,y+0.065,0),Vector3(0.45,0.035,0.45),tint)
		for side: float in [-1.0,1.0]:
			_cube(pos+Vector3(side*0.22,y+0.06,0),Vector3(0.07,0.16,0.10),tint.lightened(0.20))

func _draw_route() -> void:
	if run.route.size() < 2: return
	var points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in run.route: points.append(project_point(_world_pos(point,0.018)))
	draw_polyline(points,Color(0.02,0.07,0.09,0.45*_blend),maxf(3.0,_scale*0.19),true)
	draw_polyline(points,Color(Color("e5b271"),0.88*_blend),maxf(1.4,_scale*0.055),true)
	for i: int in range(1,run.route.size()):
		var a: Vector2 = run.route[i-1]
		var b: Vector2 = run.route[i]
		var delta: Vector2 = b-a
		var steps: int = maxi(1,int(delta.length()/1.4))
		for n: int in range(steps):
			var p: Vector2 = a.lerp(b,(float(n)+0.5)/float(steps))
			var forward: Vector2 = delta.normalized()*0.12
			var side: Vector2 = Vector2(-forward.y,forward.x)*0.65
			var arrow: PackedVector2Array = PackedVector2Array([project_point(_world_pos(p-forward+side,0.025)),project_point(_world_pos(p+forward,0.025)),project_point(_world_pos(p-forward-side,0.025))])
			draw_polyline(arrow,Color(Color("ffe0a2"),0.80*_blend),maxf(1.0,_scale*0.025),true)
	if not reduced_motion:
		for i: int in range(3):
			var point: Vector2 = run.position_on_route(fmod(_clock*1.55+float(i)*float(run.route_length)/3.0,float(run.route_length)))
			var pixel: Vector2 = project_point(_world_pos(point,0.035))
			draw_rect(Rect2(pixel-Vector2.ONE*1.4,Vector2.ONE*2.8),Color("ffedbd"))

func _draw_gates() -> void:
	if run.route.size() < 2: return
	var entry: Vector3 = _world_pos(run.route[0])
	var core: Vector3 = _world_pos(run.route.back())
	for side: float in [-1.0,1.0]:
		_cube(entry+Vector3(side*0.25,0.20*_blend,0),Vector3(0.10,0.4*_blend,0.13),Color("c56c73"))
	_cube(entry+Vector3(0,0.41*_blend,0),Vector3(0.60,0.09*_blend,0.16),Color("f4aa90"))
	_cube(core+Vector3(0,0.08,0),Vector3(0.42,0.16,0.42),Color("2c6b68"))
	_cube(core+Vector3(0,0.26*_blend,0),Vector3(0.28,0.27*_blend,0.28),Color("8be9b9"))
	_cube(core+Vector3(0,0.44*_blend,0),Vector3(0.16,0.10*_blend,0.16),Color("d1ffe2"))

func _tower_height(tower: Dictionary) -> float:
	var growth: float = smoothstep(0.12,0.85,_morph)*maxf(0.10,float(tower.get("growth",1.0)))
	return (0.52+minf(5.0,float(tower.attachments.size()))*0.16)*growth

func _draw_tower(cell: int, tower: Dictionary) -> void:
	var pos: Vector3 = _cell_pos(cell)
	var family: Color = FAMILY_COLORS[clampi(int(tower.number)-1,0,8)]
	var growth: float = smoothstep(0.12,0.85,_morph)*maxf(0.10,float(tower.get("growth",1.0)))
	if bool(tower.illegal): family = family.lerp(Color("ff747e"),0.45)
	if growth < 0.75:
		var age: float = float(_seed_plantings[cell].age) if _seed_plantings.has(cell) else SeedPlanting.DURATION
		_draw_foundation(pos,family,age,1.0-growth)
	if growth < 0.015: return
	var width: float = lerpf(0.45,1.0,growth)
	var scale3: Vector3 = Vector3(width,growth,width)
	var shade: PackedVector2Array = _quad(pos+Vector3(0.05,0,0.07),0.35*width,0.022)
	draw_colored_polygon(shade,Color(0.01,0.025,0.03,0.48*_blend))
	_tower_box(pos,Vector3(0,0.07,0),Vector3(0.64,0.12,0.64),Color("3b6566"),scale3)
	_tower_box(pos,Vector3(0,0.15,0),Vector3(0.49,0.08,0.49),Color("718e86"),scale3)
	for x: float in [-0.22,0.22]:
		for z: float in [-0.22,0.22]:
			_tower_box(pos,Vector3(x,0.10,z),Vector3(0.12,0.18,0.12),Color("315056"),scale3)
	_tower_box(pos,Vector3(0,0.28,0),Vector3(0.35,0.19,0.35),family.darkened(0.32),scale3)
	_tower_box(pos,Vector3(0,0.28,0.185),Vector3(0.15,0.075,0.035),family.lightened(0.25),scale3)
	for i: int in range(mini(5,tower.attachments.size())):
		var kind: String = str(tower.attachments[i].kind)
		var color: Color = MODULE_COLORS.get(kind,family)
		var landing: float = clampf(float(_equip_landings.get(cell,0.48))/0.48,0.0,1.0)
		var landing_slot: int = int(_equip_slots.get(cell,tower.attachments.size()-1))
		var lift: float = 0.0 if reduced_motion or i != landing_slot else pow(1.0-landing,3.0)*0.82
		var y: float = 0.43+float(i)*0.16+lift
		_tower_box(pos,Vector3(0,y,0),Vector3(0.43,0.11,0.43),Color("2d4956"),scale3)
		_tower_box(pos,Vector3(0,y+0.065,0),Vector3(0.45,0.035,0.45),color,scale3)
		if kind == "electric" or kind == "frost":
			for side: float in [-1.0,1.0]:
				_tower_box(pos,Vector3(side*0.24,y+0.06,0),Vector3(0.07,0.22,0.11),color.lightened(0.2),scale3)
		elif kind == "blast" or kind == "nova" or kind == "venom":
			for side: float in [-1.0,1.0]:
				_tower_box(pos,Vector3(side*0.25,y,0.04),Vector3(0.12,0.11,0.20),color.darkened(0.12),scale3)
		elif kind == "range":
			_tower_box(pos,Vector3(0.25,y+0.13,-0.1),Vector3(0.035,0.28,0.035),Color("a8b7a3"),scale3)
			_tower_box(pos,Vector3(0.25,y+0.27,-0.1),Vector3(0.10,0.07,0.10),color,scale3)
		elif kind == "rapid":
			_tower_box(pos,Vector3(0,y,0.26),Vector3(0.28,0.055,0.12),color,scale3)
	var height: float = 0.48+float(mini(5,tower.attachments.size()))*0.16
	var aim: Vector2 = Vector2(tower.get("aim",Vector2(cell%9,cell/9))) - Vector2(cell%9,cell/9)
	var angle: float = atan2(aim.x,aim.y) if aim.length_squared() > 0.00001 else 0.0
	var head: Vector3 = pos+Vector3(0,height*growth,0)
	var kick: float = float(_recoil.get(cell,0.0))*0.14
	_cube(head,Vector3(0.38,0.20,0.31)*scale3,Color("759795"),angle)
	_cube(head+Vector3(0,0.12*growth,0),Vector3(0.25,0.06,0.23)*scale3,family,angle)
	var barrel: Vector3 = _rotate(Vector3(0,0.015,(0.25-kick)*width),angle)
	_cube(head+barrel,Vector3(0.12,0.12,0.39)*scale3,Color("334f5c"),angle)
	var muzzle: Vector3 = _rotate(Vector3(0,0.015,(0.46-kick)*width),angle)
	_cube(head+muzzle,Vector3(0.145,0.14,0.055)*scale3,family.lightened(0.15),angle)
	if _recoil.has(cell):
		_cube(head+_rotate(Vector3(0,0.015,(0.51-kick)*width),angle),Vector3.ONE*0.13*float(_recoil[cell]),Color("fff2ba"),angle)

func _tower_box(origin: Vector3, local: Vector3, size: Vector3, color: Color, scale3: Vector3) -> void:
	_cube(origin+local*scale3,size*scale3,color)

func _draw_enemy(enemy: Dictionary) -> void:
	var kind: String = str(enemy.get("kind","grunt"))
	var color: Color = Color("ec818c")
	if kind == "tank" or kind == "armored": color = Color("d99ac6")
	elif kind == "runner" or kind == "swift": color = Color("ffb66c")
	elif kind == "boss": color = Color("d879ee")
	elif kind == "swarm": color = Color("f4a688")
	var size: float = 1.45 if kind == "boss" else (0.78 if kind == "swarm" else 1.0)
	var pos: Vector3 = _world_pos(enemy.pos,0.025)
	var angle: float = float(_enemy_angles.get(int(enemy.id),0.0))
	var bob: float = 0.0 if reduced_motion else sin(_clock*10.0+float(enemy.id))*0.023
	var ground: PackedVector2Array = _quad(pos,0.28*size,0.022)
	draw_colored_polygon(ground,Color(0.02,0.035,0.05,0.40))
	pos.y += bob+0.03
	_enemy_box(pos,Vector3(0,0.17,0),Vector3(0.34,0.26,0.38),color.darkened(0.28),size,angle)
	_enemy_box(pos,Vector3(0,0.34,0),Vector3(0.28,0.12,0.27),color,size,angle)
	_enemy_box(pos,Vector3(0,0.22,0.21),Vector3(0.22,0.075,0.035),Color("ffedc2"),size,angle)
	for x: float in [-0.22,0.22]:
		for z: float in [-0.12,0.12]:
			var step: float = 0.0 if reduced_motion else sin(_clock*12.0+float(enemy.id)+x*8.0+z*15.0)*0.035
			_enemy_box(pos,Vector3(x,0.08+step,z),Vector3(0.10,0.12,0.13),Color("68465b"),size,angle)
	if kind == "tank" or kind == "armored" or kind == "boss":
		for x: float in [-0.23,0.23]:
			_enemy_box(pos,Vector3(x,0.26,0),Vector3(0.12,0.25,0.43),color,size,angle)
	if kind == "boss":
		for x: float in [-0.16,0.16]:
			_enemy_box(pos,Vector3(x,0.52,0),Vector3(0.09,0.25,0.09),Color("f6d5ff"),size,angle)
	if float(enemy.get("slow_time",0.0)) > 0:
		_enemy_box(pos,Vector3(0,0.42,0),Vector3(0.13,0.10,0.13),Color("a9e7ff"),size,angle)
	if float(enemy.get("poison_time",0.0)) > 0:
		_enemy_box(pos,Vector3(0.17,0.41,0),Vector3(0.08,0.10,0.08),Color("bdff7e"),size,angle)

func _enemy_box(pos: Vector3, local: Vector3, size3: Vector3, color: Color, size: float, angle: float) -> void:
	_cube(pos+_rotate(local*size,angle),size3*size,color,angle)

func _draw_entity_labels() -> void:
	if _blend < 0.60: return
	for key: Variant in run.towers:
		var tower: Dictionary = run.towers[key]
		var level: int = int(tower.level)+int(run.family_levels[int(tower.number)])-1
		if level <= 1: continue
		var p: Vector2 = project_point(_cell_pos(int(key))+Vector3(0,0.02,0.43))
		for i: int in range(mini(4,level-1)):
			var dot: Vector2 = p+Vector2((float(i)-float(mini(4,level-1)-1)*0.5)*_scale*0.085,0)
			draw_rect(Rect2(dot-Vector2.ONE*1.3,Vector2.ONE*2.6),Color("ffdf93"))
	for enemy: Dictionary in run.enemies:
		var ratio: float = EnemyHealth.ratio(enemy)
		var height: float = EnemyHealth.height_for(str(enemy.kind))
		var pos: Vector2 = project_point(_world_pos(enemy.pos,height))
		var rects: Dictionary = EnemyHealth.canvas_rects(pos,_scale,str(enemy.kind),ratio)
		draw_rect(rects.track,EnemyHealth.TRACK)
		if (rects.fill as Rect2).size.x > 0.0:
			draw_rect(rects.fill,EnemyHealth.color_for(ratio))

func play_event(event: Dictionary) -> void:
	var type: String = str(event.get("type",""))
	var pos: Vector2 = event.get("pos",Vector2(-99,-99))
	var color: Color = event.get("color",Color("90f2c8"))
	if type == "shot":
		if event.has("cell"): _recoil[int(event.cell)] = 1.0
		_add_effect({"kind":"beam","pos":pos,"target":event.get("target",pos),"height":float(event.get("height",0.5)),"color":color,"style":str(event.get("kind","bolt")),"life":0.16})
		_burst(event.get("target",pos),color,3,0.3)
	elif type == "equip":
		var cell: int = int(event.get("cell",-1))
		if cell >= 0:
			if not str(event.get("kind","")).is_empty():
				_equip_landings[cell] = 0.0
				if event.has("slot"): _equip_slots[cell] = int(event.slot)
				else: _equip_slots.erase(cell)
			if pos.x < -90: pos = Vector2(cell%9,cell/9)
		if pos.x > -90:
			_burst(pos,color,6,0.45)
			_add_effect({"kind":"ring","pos":pos,"color":color,"radius":0.65,"life":0.45})
	elif type == "plant" and _begin_seed_planting(event):
		pass # The shared foundation assembly provides the placement feedback.
	elif type == "plant" or type == "upgrade":
		if pos.x > -90:
			_burst(pos,color,9,0.7)
			_add_effect({"kind":"ring","pos":pos,"color":color,"radius":0.65,"life":0.65})
		elif type == "upgrade" and event.has("number") and run != null:
			for key: Variant in run.towers:
				if int(run.towers[key].number) == int(event.number):
					_add_effect({"kind":"ring","pos":Vector2(int(key)%9,int(key)/9),"color":color,"radius":0.62,"life":0.7})
	elif type == "hit":
		_burst(pos,color,2,0.28)
	elif type == "kill":
		_burst(pos,color,10 if str(event.get("kind","")) == "boss" else 6,0.68)
	elif type == "explosion":
		_burst(pos,color,14,0.8)
		_add_effect({"kind":"ring","pos":pos,"color":color,"radius":float(event.get("radius",1.0)),"life":0.55})
	elif type == "leak" or type == "invalid":
		if pos.x < -90 and event.has("cell"): pos = Vector2(int(event.cell)%9,int(event.cell)/9)
		if pos.x > -90: _add_effect({"kind":"ring","pos":pos,"color":Color("ff7888"),"radius":0.65,"life":0.6})
	elif type == "fragment" or type == "reward" or type == "loot":
		if pos.x > -90:
			_add_effect({"kind":"text","pos":pos,"color":color,"text":str(event.get("text","+")),"life":1.05})
			if type == "loot": _burst(pos,color,12,0.85)
	queue_redraw()

func _begin_seed_planting(event: Dictionary) -> bool:
	var cell: int = int(event.get("cell",-1))
	if reduced_motion or run == null or str(run.phase) != "solve" or cell < 0 or cell >= 81: return false
	if bool(event.get("illegal",false)) or run.givens[cell] or not run.towers.has(cell): return false
	var number: int = int(event.get("number",run.board[cell]))
	if number <= 0 or int(run.board[cell]) != number: return false
	_seed_plantings[cell] = {"age":0.0,"number":number}
	return true

func _add_effect(data: Dictionary) -> void:
	data.age = 0.0
	_effects.append(data)
	# Bounded effects prevent late-campaign waves from ballooning draw work.
	if _effects.size() > 220: _effects.pop_front()

func _burst(pos: Vector2, color: Color, count: int, life: float) -> void:
	if reduced_motion: count = mini(count,2)
	for i: int in range(count):
		var angle: float = _rng.randf()*TAU
		var speed: float = _rng.randf_range(0.5,1.6)
		_add_effect({"kind":"particle","pos":pos,"color":color,"velocity":Vector3(cos(angle)*speed,_rng.randf_range(1.2,2.7),sin(angle)*speed),"size":_rng.randf_range(0.035,0.075),"life":life})

func _draw_effects() -> void:
	for effect: Dictionary in _effects:
		var age: float = float(effect.age)
		var t: float = age/float(effect.life)
		var color: Color = Color(effect.color,1.0-t)
		var pos: Vector2 = effect.pos
		match str(effect.kind):
			"beam":
				var from: Vector2 = project_point(_world_pos(pos,float(effect.height)*_blend))
				var to: Vector2 = project_point(_world_pos(effect.target,0.28*_blend))
				var points: PackedVector2Array = PackedVector2Array([from,to])
				if str(effect.style) == "electric":
					var delta: Vector2 = to-from
					var side: Vector2 = delta.orthogonal().normalized()*_scale*0.065
					points = PackedVector2Array([from,from.lerp(to,0.33)+side,from.lerp(to,0.62)-side,to])
				draw_polyline(points,Color(color,0.20*(1.0-t)),maxf(4.0,_scale*0.14),true)
				draw_polyline(points,color,maxf(1.2,_scale*0.043),true)
				draw_circle(to,maxf(1.5,_scale*0.06)*(1.0-t),Color("fff2c7"))
			"particle":
				var position: Vector3 = _world_pos(pos,0.08)+Vector3(effect.velocity)*age
				position.y -= age*age*2.2
				var pixel: Vector2 = project_point(position)
				var size: float = maxf(1.0,float(effect.size)*_scale*(1.0-t*0.7))
				if _inside_art(pixel): draw_rect(Rect2(pixel-Vector2.ONE*size*0.5,Vector2.ONE*size),color)
			"ring":
				var radius: float = float(effect.radius)*(0.25+t*0.75)
				var points: PackedVector2Array = PackedVector2Array()
				for i: int in range(33):
					var angle: float = float(i)/32.0*TAU
					points.append(project_point(_world_pos(pos,0.04)+Vector3(cos(angle)*radius,0,sin(angle)*radius)))
				draw_polyline(points,Color(color,0.7*(1.0-t)),maxf(1.0,_scale*0.045*(1.0-t)),true)
			"text":
				var pixel: Vector2 = project_point(_world_pos(pos,0.45+age*0.65))
				# A top-down camera collapses height: keep solve rewards off the seed
				# and answer instead of covering the square's center for a second.
				if str(run.phase) == "solve": pixel.y -= _scale*(0.36 + (0.0 if reduced_motion else age*0.12))
				if _inside_art(pixel):
					var size: int = clampi(roundi(_scale*0.24),10,17)
					_text_center(str(effect.text),pixel+Vector2(1,1),size,Color(0.025,0.06,0.08,1.0-t))
					_text_center(str(effect.text),pixel,size,color)

func _inside_art(point: Vector2) -> bool:
	return not _board_rect.has_area() or _board_rect.grow(-2).has_point(point)

func _rotate(point: Vector3, yaw: float) -> Vector3:
	return Vector3(point.x*cos(yaw)+point.z*sin(yaw),point.y,-point.x*sin(yaw)+point.z*cos(yaw))

func _cube(center: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	if size.x <= 0.0001 or size.y <= 0.0001 or size.z <= 0.0001: return
	var half: Vector3 = size*0.5
	# Top plus camera-facing sides. Fixed face lighting preserves the voxel look
	# without asking a mobile browser to compile or execute spatial materials.
	_face(center,[Vector3(-half.x,half.y,-half.z),Vector3(half.x,half.y,-half.z),Vector3(half.x,half.y,half.z),Vector3(-half.x,half.y,half.z)],Vector3.UP,color.lightened(0.045),yaw)
	_face(center,[Vector3(-half.x,-half.y,half.z),Vector3(-half.x,half.y,half.z),Vector3(half.x,half.y,half.z),Vector3(half.x,-half.y,half.z)],Vector3(0,0,1),color.darkened(0.20),yaw)
	_face(center,[Vector3(half.x,-half.y,-half.z),Vector3(half.x,half.y,-half.z),Vector3(-half.x,half.y,-half.z),Vector3(-half.x,-half.y,-half.z)],Vector3(0,0,-1),color.darkened(0.30),yaw)
	_face(center,[Vector3(half.x,-half.y,half.z),Vector3(half.x,half.y,half.z),Vector3(half.x,half.y,-half.z),Vector3(half.x,-half.y,-half.z)],Vector3(1,0,0),color.darkened(0.34),yaw)
	_face(center,[Vector3(-half.x,-half.y,-half.z),Vector3(-half.x,half.y,-half.z),Vector3(-half.x,half.y,half.z),Vector3(-half.x,-half.y,half.z)],Vector3(-1,0,0),color.darkened(0.25),yaw)

func _face(center: Vector3, corners: Array, normal: Vector3, color: Color, yaw: float) -> void:
	var facing: Vector3 = _rotate(normal,yaw)
	if facing.dot(_view) <= 0.0001: return
	var points: PackedVector2Array = PackedVector2Array()
	var middle: Vector3 = Vector3.ZERO
	for corner: Vector3 in corners:
		var position: Vector3 = center+_rotate(corner,yaw)
		middle += position*0.25
		points.append(project_point(position))
	# Morphing seeds and edge-on sides can collapse to subpixel slivers.
	# The Canvas triangulator correctly rejects those; skip them before submission.
	var twice_area: float = 0.0
	for i: int in range(points.size()):
		twice_area += points[i].cross(points[(i+1)%points.size()])
	if absf(twice_area) < 0.5: return
	_faces.append({"points":points,"color":color,"depth":middle.dot(_view)})

func _flush_faces() -> void:
	_faces.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.depth)<float(b.depth))
	for face: Dictionary in _faces:
		draw_colored_polygon(face.points,face.color)
	_faces.clear()

func _quad(center: Vector3, half: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([project_point(center+Vector3(-half,height,-half)),project_point(center+Vector3(half,height,-half)),project_point(center+Vector3(half,height,half)),project_point(center+Vector3(-half,height,half))])

func _polyline_closed(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	draw_polyline(closed,color,width,true)

func _text_center(value: String, center: Vector2, size: int, color: Color) -> void:
	var extent: Vector2 = _font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size)
	var baseline: float = (_font.get_ascent(size)-_font.get_descent(size))*0.5
	draw_string(_font,center+Vector2(-extent.x*0.5,baseline),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
