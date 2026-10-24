class_name DefenseMenuDiorama
extends Control
## A small, live voxel garden for menus. Canvas drawing is identical on Web
## and native builds, and this decoration never owns pointer or focus input.

@export var reduced_motion := false:
	set(value):
		reduced_motion = value
		_sync_animation()
		queue_redraw()
@export var variant := "garden":
	set(value):
		variant = value
		queue_redraw()

const REFERENCE := Vector2(320, 240)
const ORIGIN := Vector2(160, 81)
const MINT := Color("83e7c1")
const COPPER := Color("e9aa75")
const IVORY := Color("e8f4dd")
var _time := 0.0
var _redraw_time := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2.ZERO

func _ready() -> void:
	visibility_changed.connect(_sync_animation)
	_sync_animation()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED: queue_redraw()

func _sync_animation() -> void:
	if is_inside_tree(): set_process(not reduced_motion and is_visible_in_tree())

func _process(delta: float) -> void:
	_time += minf(delta, 0.05)
	_redraw_time += delta
	if _redraw_time >= 1.0 / 30.0:
		_redraw_time = 0.0
		queue_redraw()

func _cell(x: float, y: float) -> Vector2:
	return ORIGIN + Vector2((x-y)*14, (x+y+1)*7)

func _draw() -> void:
	var unit: float = minf(size.x / REFERENCE.x, size.y / REFERENCE.y)
	if unit <= 0.0: return
	draw_set_transform((size-REFERENCE*unit)*0.5, 0.0, Vector2.ONE*unit)
	var pulse: float = 0.85 if reduced_motion else 0.85 + sin(_time*1.7)*0.15
	# Soft stepped shadows keep the floating island grounded without a panel.
	_poly([Vector2(24,159),Vector2(160,224),Vector2(298,159),Vector2(160,102)],Color(0,0,0,0.10))
	_poly([Vector2(35,158),Vector2(160,220),Vector2(285,158),Vector2(160,98)],Color(0,0,0,0.16))
	_block(Vector2(160,144),126,63,14,Color("24444c"))
	# Segmented copper and luminous contacts on the exposed island rim.
	for i in range(9):
		var p: Vector2 = _cell(float(i),8.5)
		_poly([p+Vector2(-10,2),p+Vector2(0,7),p+Vector2(0,11),p+Vector2(-10,6)],Color("39606a") if i%3 else COPPER.darkened(0.42))
		var q: Vector2 = _cell(8.5,float(i))
		_poly([q+Vector2(0,7),q+Vector2(10,2),q+Vector2(10,6),q+Vector2(0,11)],Color("29464f") if i%3 else MINT.darkened(0.42))
	for y in range(9):
		for x in range(9):
			var tint := Color("17333d") if (int(x/3)+int(y/3))%2 == 0 else Color("1c3d45")
			if (x+y)%4 == 0: tint = tint.lightened(0.035)
			_diamond(_cell(x,y),13.5,6.6,tint)
	for i in range(10):
		var edge := Color(MINT,0.35 if i%3 == 0 else 0.08)
		var line_width: float = 1.25 if i%3 == 0 else 0.6
		var a: Vector2 = ORIGIN + Vector2(i*14,i*7)
		var b: Vector2 = ORIGIN + Vector2(-i*14,i*7)
		draw_line(a,a+Vector2(-126,63),edge,line_width,true)
		draw_line(b,b+Vector2(126,63),edge,line_width,true)
	var route := PackedVector2Array()
	for grid in [Vector2(0,3),Vector2(1,3),Vector2(1,4),Vector2(3,4),Vector2(3,5),Vector2(5,5),Vector2(5,6),Vector2(8,6)]:
		route.append(_cell(grid.x,grid.y))
	draw_polyline(route,Color(COPPER,0.12),6.0,true)
	draw_polyline(route,Color(COPPER,0.75),1.6,true)
	# A few inlaid clue tiles echo Sudoku without adding text to the menu.
	for grid in [Vector2(0,0),Vector2(3,1),Vector2(7,1),Vector2(0,6),Vector2(4,7),Vector2(8,8)]:
		var p: Vector2 = _cell(grid.x,grid.y)
		_diamond(p,8.0,4.0,Color("2e545c"))
		draw_line(p+Vector2(-3,-1),p+Vector2(3,2),Color(IVORY,0.42),1.2,true)
	# Rear structures first, then front ones, so every stack reads in depth.
	_tower(_cell(1,1),"core",MINT,pulse)
	_tower(_cell(5,1),"rapid",COPPER,pulse)
	_tower(_cell(2,5),"electric",Color("b8a6e5"),pulse)
	if variant != "freeplay": _tower(_cell(7,3),"frost",Color("91cde0"),pulse)
	_chest(_cell(6,7))
	# One tiny enemy and an endpoint make the lit route feel inhabited.
	_block(_cell(3,4)+Vector2(0,-2),3.8,2.0,4.5,Color("b97963"))
	_block(_cell(8,6)+Vector2(0,-2),3.8,2.0,3.0,COPPER)
	for corner in [Vector2(0,0),Vector2(8,0),Vector2(0,8),Vector2(8,8)]:
		var p: Vector2 = _cell(corner.x,corner.y)
		_block(p+Vector2(0,-3),4.0,2.0,3.0,Color("648c8c"))
		_block(p+Vector2(0,-6),2.8,1.4,2.5,IVORY)
		draw_line(p+Vector2(-2,-5),p+Vector2(2,-5),Color(MINT,0.65*pulse),1.0,true)
	if variant == "locked":
		# A restrained perimeter rail gives the fixed-rules mode a distinct cue.
		draw_polyline(PackedVector2Array([Vector2(34,144),Vector2(160,207),Vector2(286,144)]),Color(COPPER,0.6),2.2,true)
	for i in range(6):
		var drift: float = 0.0 if reduced_motion else sin(_time*0.65+float(i))*3.0
		var p := Vector2(42+float(i)*46,53+float((i*29)%57)+drift)
		var tint: Color = COPPER if i%3 == 0 else MINT
		_diamond(p,1.4,0.9,Color(tint,0.25+float(i%2)*0.12))

func _tower(base: Vector2, kind: String, tint: Color, pulse: float) -> void:
	_diamond(base+Vector2(0,4),14,7,Color(0,0,0,0.25))
	_block(base+Vector2(0,-3),10.5,5.2,3.0,Color("375a62"))
	_block(base+Vector2(0,-8),8.5,4.2,5.0,IVORY.darkened(0.13))
	_block(base+Vector2(0,-13),6.8,3.4,5.0,Color("36545f"))
	_block(base+Vector2(0,-16),7.4,3.7,3.0,tint)
	match kind:
		"rapid":
			for x in [-1,0,1]:
				_block(base+Vector2(float(x)*5,-31-float(abs(x))*-3),2.4,1.2,15-float(abs(x))*3,Color("9fb5b5"))
				_block(base+Vector2(float(x)*5,-34-float(abs(x))*-3),2.5,1.3,3.0,tint)
		"electric":
			for i in range(3):
				_block(base+Vector2(-2 if i%2 == 0 else 2,-23-i*7),5.2,2.6,6.0,tint.lightened(float(i)*0.05))
			_block(base+Vector2(0,-45),2.6,1.3,3.0,IVORY)
		"frost":
			_block(base+Vector2(0,-37),5.8,3.0,21.0,tint)
			_block(base+Vector2(-7,-28),3.2,1.6,12.0,tint.lightened(0.18))
			_block(base+Vector2(7,-25),2.8,1.4,9.0,tint.darkened(0.08))
		_:
			_block(base+Vector2(0,-33),6.0,3.0,17.0,IVORY)
			_block(base+Vector2(0,-38),8.0,4.0,5.0,tint)
			_block(base+Vector2(0,-44),3.8,1.9,6.0,IVORY)
			_diamond(base+Vector2(0,-45),2.7,1.35,Color(tint,0.75+0.2*pulse))
	# Exposed copper contacts and a luminous front-facing status slit.
	for x in [-1,0,1]: _block(base+Vector2(float(x)*3,-3),0.8,0.4,2.5,COPPER)
	draw_line(base+Vector2(-5,-9),base+Vector2(-1,-7),Color(tint,0.6+0.2*pulse),1.3,true)

func _chest(base: Vector2) -> void:
	_diamond(base+Vector2(0,4),13,6.5,Color(0,0,0,0.22))
	_block(base+Vector2(0,-8),10,5,8,Color("956c42"))
	_block(base+Vector2(0,-12),11,5.5,4,COPPER)
	_block(base+Vector2(0,-14),8,4,2,Color("f2cf92"))
	_poly([base+Vector2(-7,-9),base+Vector2(-5,-8),base+Vector2(-5,2),base+Vector2(-7,1)],Color("66756a"))
	_poly([base+Vector2(5,-8),base+Vector2(7,-9),base+Vector2(7,1),base+Vector2(5,2)],Color("485e58"))
	draw_rect(Rect2(base+Vector2(-1.4,-5),Vector2(2.8,5)),Color("ffe4ac"))

func _block(center: Vector2, half_width: float, half_depth: float, height: float, tint: Color) -> void:
	var top: Vector2 = center+Vector2(0,-half_depth)
	var right: Vector2 = center+Vector2(half_width,0)
	var front: Vector2 = center+Vector2(0,half_depth)
	var left: Vector2 = center+Vector2(-half_width,0)
	var down := Vector2(0,height)
	_poly([left,front,front+down,left+down],tint.darkened(0.20))
	_poly([front,right,right+down,front+down],tint.darkened(0.40))
	_poly([top,right,front,left],tint.lightened(0.13))

func _diamond(center: Vector2, half_width: float, half_depth: float, tint: Color) -> void:
	_poly([center+Vector2(0,-half_depth),center+Vector2(half_width,0),center+Vector2(0,half_depth),center+Vector2(-half_width,0)],tint)

func _poly(points: Array[Vector2], tint: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points),tint)
