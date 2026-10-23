class_name DefenseQuickIcon
extends Control
## Tiny, resolution-independent voxel art for the three gameplay quick panels.
## Pure CanvasItem drawing keeps the same artwork on native and web renderers.

@export_enum("gear", "chest", "camp") var icon_kind: String = "gear":
	set(value):
		icon_kind = value
		queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(30, 30)

func _draw() -> void:
	var art_scale: float = minf(size.x, size.y) / 32.0
	if art_scale <= 0.0: return
	draw_set_transform((size - Vector2.ONE * 32.0 * art_scale) * 0.5, 0.0, Vector2.ONE * art_scale)
	_poly([Vector2(3, 26), Vector2(16, 21), Vector2(29, 26), Vector2(16, 31)], Color("071a24"))
	match icon_kind:
		"chest": _chest()
		"camp": _camp()
		_: _gear()

func _gear() -> void:
	# A socketed mint module, with a raised chip and exposed copper contacts.
	_voxel(Vector2(16, 23), 10.5, 5.0, 3.0, Color("406e72"))
	_voxel(Vector2(16, 12), 10.0, 5.0, 11.0, Color("58b6a3"))
	_voxel(Vector2(16, 9), 6.8, 3.4, 3.0, Color("91e9c4"))
	_voxel(Vector2(16, 7), 3.7, 1.85, 2.0, Color("ceffdf"))
	# Left-face inset and the small circuit that identifies it as equipment.
	_poly([Vector2(8, 16), Vector2(14, 19), Vector2(14, 25), Vector2(8, 22)], Color("1c5b5a"))
	draw_line(Vector2(10, 18.5), Vector2(10, 21), Color("9bf4d2"), 1.2)
	draw_line(Vector2(10, 21), Vector2(12.5, 22.2), Color("9bf4d2"), 1.2)
	for y: float in [18.0, 22.0]:
		_poly([Vector2(19, y), Vector2(24, y - 2.5), Vector2(24, y - 1.0), Vector2(19, y + 1.5)], Color("e2c68b"))

func _chest() -> void:
	# Squared lid, metal straps and a bright lock read at a glance at 30 pixels.
	_voxel(Vector2(16, 16), 11.0, 5.0, 9.0, Color("bd863f"))
	_voxel(Vector2(16, 10), 12.0, 5.5, 6.0, Color("e7b76a"))
	_voxel(Vector2(16, 7.8), 9.0, 4.0, 2.2, Color("f2cc87"))
	_poly([Vector2(8, 12), Vector2(10, 13), Vector2(10, 24.6), Vector2(8, 23.7)], Color("5b624f"))
	_poly([Vector2(22, 13), Vector2(24, 12), Vector2(24, 23.7), Vector2(22, 24.6)], Color("48544d"))
	draw_line(Vector2(5, 16.3), Vector2(16, 21.3), Color("73592f"), 1.0)
	draw_line(Vector2(16, 21.3), Vector2(27, 16.3), Color("73592f"), 1.0)
	draw_rect(Rect2(14.3, 19.2, 3.5, 6.1), Color("ffe3a4"))
	draw_rect(Rect2(15.4, 20.9, 1.3, 2.7), Color("4b513e"))

func _camp() -> void:
	# A tiny camp terminal: purple chassis, mint screen and a roof beacon.
	_voxel(Vector2(16, 25), 11.0, 4.3, 2.5, Color("5a6b85"))
	_voxel(Vector2(16, 9), 9.0, 4.0, 16.0, Color("a393cb"))
	_voxel(Vector2(16, 6), 9.8, 4.4, 3.0, Color("c1afe5"))
	_poly([Vector2(8.5, 12), Vector2(14.6, 14.7), Vector2(14.6, 22.1), Vector2(8.5, 19.4)], Color("173943"))
	draw_line(Vector2(10, 15), Vector2(12.8, 16.2), Color("a3f2ce"), 1.4)
	draw_line(Vector2(10, 18), Vector2(11.7, 18.7), Color("7adbbd"), 1.2)
	_poly([Vector2(19, 15), Vector2(23, 13.2), Vector2(23, 14.7), Vector2(19, 16.5)], Color("72658f"))
	_poly([Vector2(19, 19), Vector2(23, 17.2), Vector2(23, 18.7), Vector2(19, 20.5)], Color("72658f"))
	_voxel(Vector2(16, 3.8), 2.7, 1.25, 2.4, Color("eff1d0"))

func _voxel(center: Vector2, half_width: float, half_depth: float, height: float, tint: Color) -> void:
	var top: Vector2 = center + Vector2(0, -half_depth)
	var right: Vector2 = center + Vector2(half_width, 0)
	var front: Vector2 = center + Vector2(0, half_depth)
	var left: Vector2 = center + Vector2(-half_width, 0)
	var down: Vector2 = Vector2(0, height)
	_poly([left, front, front + down, left + down], tint.darkened(0.18))
	_poly([front, right, right + down, front + down], tint.darkened(0.36))
	_poly([top, right, front, left], tint.lightened(0.12))

func _poly(points: Array[Vector2], tint: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), tint)
