class_name DefenseVoxelIcon
extends Control

var kind: String = "gear"
var tint: Color = Color("6ce3c5")
var opened: bool = false
var sparkle: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO: custom_minimum_size = Vector2(44, 44)

func _cube(center: Vector2, half_width: float, height: float, color: Color) -> void:
	var depth: float = half_width * 0.48
	var top: Vector2 = center + Vector2(0, -height)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-half_width, 0), top + Vector2(0, depth), center + Vector2(0, depth), center + Vector2(-half_width, 0)]), color.darkened(0.30))
	draw_colored_polygon(PackedVector2Array([top + Vector2(0, depth), top + Vector2(half_width, 0), center + Vector2(half_width, 0), center + Vector2(0, depth)]), color.darkened(0.12))
	draw_colored_polygon(PackedVector2Array([top + Vector2(-half_width, 0), top + Vector2(0, -depth), top + Vector2(half_width, 0), top + Vector2(0, depth)]), color.lightened(0.24))

func _draw() -> void:
	var c: Vector2 = size * Vector2(0.5, 0.60)
	var u: float = minf(size.x, size.y) / 44.0
	if kind.begins_with("chest"):
		draw_circle(c + Vector2(0, 6) * u, 16 * u, Color(tint, 0.10))
		_cube(c, 15 * u, 12 * u, Color("234659"))
		_cube(c + Vector2(0, -12 - (8 if opened else 0)) * u, 15 * u, 5 * u, tint)
		draw_rect(Rect2(c + Vector2(-2, -9) * u, Vector2(4, 7) * u), Color("ffe3a1"))
		if opened:
			for i in range(5):
				var a: float = float(i) / 5.0 * TAU - 1.2
				var p: Vector2 = c + Vector2(cos(a) * 15, sin(a) * 12 - 20) * u
				_cube(p, 2 * u, 3 * u, tint.lightened(0.3))
	elif kind == "credit":
		for i in range(3):
			_cube(c + Vector2(0, -i * 5) * u, 11 * u, 4 * u, Color("ffc780"))
	else:
		_cube(c + Vector2(0, 6) * u, 13 * u, 5 * u, Color("2b4053"))
		match kind:
			"electric":
				for i in range(3):
					_cube(c + Vector2((1 if i == 1 else -1) * 3, -i * 7) * u, 5 * u, 6 * u, tint)
			"frost", "freeze":
				_cube(c + Vector2(0, -5) * u, 8 * u, 15 * u, tint)
				_cube(c + Vector2(-8, 1) * u, 4 * u, 8 * u, tint.lightened(0.20))
			"rapid", "overclock":
				for i in range(3):
					_cube(c + Vector2((i - 1) * 8, -3) * u, 3 * u, (8 + i * 3) * u, tint)
			"repair", "venom":
				_cube(c + Vector2(0, -3) * u, 7 * u, 11 * u, tint)
				_cube(c + Vector2(0, -14) * u, 4 * u, 4 * u, Color("e9f1df"))
			_:
				_cube(c + Vector2(0, -1) * u, 9 * u, 11 * u, tint)
				_cube(c + Vector2(0, -12) * u, 4 * u, 6 * u, tint.lightened(0.22))
