extends Control
## Light, non-interactive screen effects. The board owns the actual module art.
const QuickIcon = preload("res://scripts/quick_icon.gd")
var host
var target_cell := -1
var target_point := Vector2.ZERO
var pointer_point := Vector2.ZERO
var target_color := Color("83e7c1")
var slots_used := 0
var allowed := false
var dragging := false
var _pickups: Array[Control] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 18

func set_target(cell: int, point: Vector2, pointer: Vector2, color: Color, slots: int, valid: bool, is_dragging: bool) -> void:
	target_cell = cell
	target_point = point
	pointer_point = pointer
	target_color = color
	slots_used = slots
	allowed = valid
	dragging = is_dragging
	queue_redraw()

func _draw() -> void:
	if target_cell < 0: return
	var tint: Color = target_color if allowed else Color("d5ad91")
	if dragging and pointer_point.distance_to(target_point) > 20:
		var points := PackedVector2Array()
		var bend: Vector2 = (pointer_point + target_point) * 0.5 + Vector2(0,-38)
		for i in range(17):
			var t: float = float(i) / 16.0
			points.append(pointer_point.lerp(bend,t).lerp(bend.lerp(target_point,t),t))
		draw_polyline(points,Color(tint,0.58),2.0,true)
	var text_value := "STACK FULL  ·  5 / 5"
	if allowed:
		var action_hint := "RELEASE TO ATTACH" if dragging else "A TO ATTACH" if host.controller_used else "TAP TO ATTACH"
		text_value = "SLOT %d / 5  ·  %s" % [slots_used+1,action_hint]
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 17 if host.portrait_layout else 13
	var width: float = font.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x + 24
	var location: Vector2 = target_point + Vector2(-width*0.5,34)
	location.x = clampf(location.x,8,maxf(8,size.x-width-8))
	location.y = clampf(location.y,8,maxf(8,size.y-36))
	var box := Rect2(location,Vector2(width,30))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102632f2")
	style.border_color = Color(tint,0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	draw_style_box(style,box)
	draw_string(font,location+Vector2(12,21),text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)

func chest_recovered(event: Dictionary) -> void:
	if host == null or host.menu_open or _pickups.size() >= 4: return
	var icon: Control = QuickIcon.new()
	icon.icon_kind = "chest"
	icon.size = Vector2(52,52)
	icon.pivot_offset = icon.size * 0.5
	icon.modulate = Color(event.get("color",Color.WHITE)).lightened(0.25)
	add_child(icon)
	_pickups.append(icon)
	var destination: Vector2 = host.loot_button.get_global_rect().get_center()-icon.size*0.5
	var drop: Vector2 = event.get("pos",Vector2(-99,-99))
	var origin: Vector2 = host.board_rect.get_center()
	if drop.x >= 0 and drop.y >= 0 and drop.x <= 8 and drop.y <= 8:
		origin = host.world.cell_screen_position(clampi(roundi(drop.y),0,8)*9+clampi(roundi(drop.x),0,8))
	icon.position = destination if host.reduced_motion else origin-icon.size*0.5
	var tween := create_tween()
	if not host.reduced_motion:
		icon.scale = Vector2(0.2,0.2)
		tween.tween_property(icon,"scale",Vector2(1.18,1.18),0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(icon,"position:y",icon.position.y-32,0.22)
		tween.tween_interval(0.18)
		tween.tween_property(icon,"position",destination,0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(icon,"scale",Vector2(0.7,0.7),0.6)
	else:
		tween.tween_interval(0.35)
	tween.tween_property(icon,"modulate:a",0.0,0.2)
	tween.tween_callback(func(): _pickups.erase(icon); icon.queue_free())
