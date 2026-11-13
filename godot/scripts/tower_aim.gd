extends Control
## Screen-space target preview. A stick gesture commits once, on release.
const PRESS_ZONE := 0.55
const RELEASE_ZONE := 0.30
const AIM_CONE := 0.5 # At most 60 degrees away from the intended direction.
var host
var target := -1
var origin_cell := -1
var _axis := Vector2.ZERO
var _stick_active := false
var _pointer_active := false
var _pointer := Vector2.ZERO
var _needs_neutral := false
var _peak_strength := 0.0
var _releasing := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 40
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func setup(game_host) -> void:
	host = game_host

func cancel() -> void:
	_needs_neutral = _needs_neutral or _stick_active or _axis.length() > RELEASE_ZONE
	_axis = Vector2.ZERO
	_stick_active = false
	_pointer_active = false
	target = -1
	origin_cell = -1
	queue_redraw()

func set_stick(axis: Vector2) -> void:
	if _needs_neutral:
		if axis.length() <= RELEASE_ZONE: _needs_neutral = false
		return
	_axis = axis
	_pointer_active = false

func point_at(point: Vector2) -> void:
	if _stick_active: cancel()
	if not host._tower_aim_available():
		cancel()
		return
	_axis = Vector2.ZERO
	_stick_active = false
	_pointer_active = true
	_pointer = point
	origin_cell = host.selected_cell
	_update_pointer_target()
	queue_redraw()

static func pick_target(origin: Vector2, direction: Vector2, positions: Dictionary, current: int) -> int:
	if direction.length_squared() < 0.0001: return current
	var aim := direction.normalized()
	var best := INF
	var result := current
	var cells := positions.keys()
	cells.sort()
	for cell: int in cells:
		if cell == current: continue
		var offset: Vector2 = positions[cell] - origin
		var distance := offset.length()
		if distance < 1.0 or offset.normalized().dot(aim) < AIM_CONE: continue
		var lateral := absf(offset.cross(aim))
		var score := distance + lateral * 2.0
		if score < best:
			best = score
			result = cell
	return result

func target_in_direction(direction: Vector2) -> int:
	var cells: Array[int] = host._tower_cells()
	if cells.is_empty(): return -1
	if not cells.has(host.selected_cell): return cells[0]
	var positions := {}
	for cell in cells: positions[cell] = host.world.cell_screen_position(cell)
	return pick_target(positions[host.selected_cell],direction,positions,host.selected_cell)

func target_at(point: Vector2) -> int:
	if not host._tower_aim_available() or not host.board_rect.has_point(point): return -1
	var direct: int = host.world.cell_at_screen(point)
	if host.run.towers.has(direct): return direct
	if not host.run.towers.has(host.selected_cell): return -1
	var origin: Vector2 = host.world.cell_screen_position(host.selected_cell)
	if origin.distance_to(point) < 20.0: return host.selected_cell
	return target_in_direction(point-origin)

func _update_pointer_target() -> void:
	target = target_at(_pointer)

func commit() -> bool:
	if not _stick_active: return false
	var chosen := target
	var valid: bool = host._tower_aim_available() and origin_cell == host.selected_cell and host.run.towers.has(chosen)
	var released := _axis.length() <= RELEASE_ZONE
	cancel()
	if released: _needs_neutral = false
	if valid and chosen != host.selected_cell: host._select(chosen,false,false)
	return true

func _process(_delta: float) -> void:
	if host == null: return
	if not host._tower_aim_available():
		cancel()
		return
	# Coalesce X/Y axis events before aiming or releasing a diagonal gesture.
	if _axis.length() >= PRESS_ZONE:
		if not _stick_active:
			_stick_active = true
			origin_cell = host.selected_cell
			_peak_strength = _axis.length()
			_releasing = false
		if host.selected_cell != origin_cell:
			cancel()
			return
		_peak_strength = maxf(_peak_strength,_axis.length())
		if _axis.length() < _peak_strength-0.15: _releasing = true
		elif _axis.length() >= _peak_strength-0.08: _releasing = false
		# Preserve the last deliberate direction as X/Y return at different rates.
		if not _releasing: target = target_in_direction(_axis)
	elif _stick_active and _axis.length() <= RELEASE_ZONE:
		commit()
	elif _pointer_active:
		# A pointer is never allowed to chain selection while it is stationary.
		if origin_cell != host.selected_cell:
			cancel()
			return
		_update_pointer_target()
	queue_redraw()

func _draw() -> void:
	if host == null or not host._tower_aim_available(): return
	if target < 0 or target == host.selected_cell or not host.run.towers.has(target): return
	var destination: Vector2 = host.world.cell_screen_position(target)
	var tint := Color("83e7c1")
	draw_arc(destination,19.0,0.0,TAU,40,Color("07141dcc"),7.0,true)
	draw_arc(destination,19.0,0.0,TAU,40,tint,3.0,true)
	if host.run.towers.has(host.selected_cell):
		var origin: Vector2 = host.world.cell_screen_position(host.selected_cell)
		var direction := (destination-origin).normalized()
		var start := origin+direction*22.0
		var end := destination-direction*23.0
		if origin.distance_to(destination) > 48.0:
			draw_line(start,end,Color("07141dcc"),7.0,true)
			draw_line(start,end,tint,3.0,true)
			var side := direction.orthogonal()*6.0
			draw_colored_polygon(PackedVector2Array([end,end-direction*11.0+side,end-direction*11.0-side]),tint)
