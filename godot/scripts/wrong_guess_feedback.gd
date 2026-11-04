extends Control
## One readable map-space rejection cue, shared by native and Canvas boards.
const DURATION := 2.2
const RED := Color("ff7289")
const BACK := Color("251c2b")
var host
var _entries: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 18

func clear_feedback() -> void:
	_entries.clear()
	queue_redraw()

func play_event(event: Dictionary) -> void:
	if str(event.get("type", "")) == "plant":
		for i in range(_entries.size()-1, -1, -1):
			if int(_entries[i].cell) == int(event.get("cell",-1)): _entries.remove_at(i)
		queue_redraw()
		return
	if str(event.get("type", "")) != "invalid" or str(event.get("reason", "")) != "wrong_answer": return
	var cell := int(event.get("cell", -1))
	var lost := float(event.get("time_penalty", 0.0))
	if cell < 0 or cell >= 81 or lost <= 0.0: return
	var attempts := 1
	# Rapid retries remain one legible receipt. Its count makes the accumulated
	# loss explicit, rather than claiming one mistake had a larger penalty.
	for i in range(_entries.size()-1, -1, -1):
		if int(_entries[i].cell) != cell: continue
		lost += float(_entries[i].time_penalty)
		attempts += int(_entries[i].attempts)
		_entries.remove_at(i)
	_entries.append({"cell":cell, "time_penalty":lost, "attempts":attempts, "age":0.0})
	if _entries.size() > 6: _entries.pop_front()
	queue_redraw()

func _process(dt: float) -> void:
	if _entries.is_empty(): return
	for i in range(_entries.size()-1, -1, -1):
		_entries[i].age = float(_entries[i].age) + maxf(0.0,dt)
		if float(_entries[i].age) >= DURATION: _entries.remove_at(i)
	queue_redraw()

static func loss_text(seconds: float) -> String:
	if seconds > 0.0 and seconds < 0.01: return "−<0.01s"
	var value := "%.2f" % seconds
	while value.ends_with("0"): value = value.trim_suffix("0")
	value = value.trim_suffix(".")
	return "−%ss" % value

func _cell_shape(cell: int) -> PackedVector2Array:
	var center: Vector2 = host.world.cell_screen_position(cell)
	var step_x: int = 1 if cell % 9 < 8 else -1
	var step_y: int = 9 if cell / 9 < 8 else -9
	var x: Vector2 = (host.world.cell_screen_position(cell+step_x)-center) * (0.46 if step_x > 0 else -0.46)
	var y: Vector2 = (host.world.cell_screen_position(cell+step_y)-center) * (0.46 if step_y > 0 else -0.46)
	return PackedVector2Array([center-x-y,center+x-y,center+x+y,center-x+y])

func _receipt(entry: Dictionary) -> String:
	var loss := loss_text(float(entry.time_penalty))
	return "%s · %d wrong guesses" % [loss,int(entry.attempts)] if int(entry.attempts) > 1 else "%s solve time" % loss

func _popup_rect(entry: Dictionary) -> Rect2:
	var bounds: Rect2 = host.board_rect.grow(-8.0)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 23 if host.portrait_layout else 17
	var width := maxf(184.0,font.get_string_size(_receipt(entry),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+28.0)
	var dimensions := Vector2(minf(width,bounds.size.x),78.0 if host.portrait_layout else 60.0)
	var shape := _cell_shape(int(entry.cell))
	var center: Vector2 = host.world.cell_screen_position(int(entry.cell))
	var top := shape[0].y
	var bottom := shape[0].y
	for point in shape:
		top = minf(top,point.y)
		bottom = maxf(bottom,point.y)
	var point := Vector2(center.x-dimensions.x*0.5,top-dimensions.y-10.0)
	if point.y < bounds.position.y: point.y = bottom+10.0
	point.x = clampf(point.x,bounds.position.x,maxf(bounds.position.x,bounds.end.x-dimensions.x))
	point.y = clampf(point.y,bounds.position.y,maxf(bounds.position.y,bounds.end.y-dimensions.y))
	return Rect2(point,dimensions)

func _draw() -> void:
	if host == null or host.world == null or host.menu_open or _entries.is_empty(): return
	# No shake, flashing, drifting text, or scale animation. This remains equally
	# legible with reduced motion, and follows the board during phase transitions.
	for entry: Dictionary in _entries:
		var alpha := clampf((DURATION-float(entry.age))/0.35,0.0,1.0)
		var shape := _cell_shape(int(entry.cell))
		var center: Vector2 = host.world.cell_screen_position(int(entry.cell))
		var outline := shape.duplicate()
		outline.append(shape[0])
		draw_colored_polygon(shape,Color(RED,0.22*alpha))
		draw_polyline(outline,Color(RED,alpha),3.0,true)
		var radius: float = clampf(shape[0].distance_to(shape[2])*0.17,6.0,14.0)
		draw_line(center+Vector2(-radius,-radius),center+Vector2(radius,radius),Color("251c2b",alpha),7.0,true)
		draw_line(center+Vector2(-radius,radius),center+Vector2(radius,-radius),Color("251c2b",alpha),7.0,true)
		draw_line(center+Vector2(-radius,-radius),center+Vector2(radius,radius),Color(RED,alpha),3.5,true)
		draw_line(center+Vector2(-radius,radius),center+Vector2(radius,-radius),Color(RED,alpha),3.5,true)
	var entry: Dictionary = _entries.back()
	var alpha := clampf((DURATION-float(entry.age))/0.35,0.0,1.0)
	var rect := _popup_rect(entry)
	var center: Vector2 = host.world.cell_screen_position(int(entry.cell))
	var link := Vector2(clampf(center.x,rect.position.x+8,rect.end.x-8),rect.end.y if center.y >= rect.get_center().y else rect.position.y)
	draw_line(link,center,Color(RED,0.7*alpha),2.0,true)
	draw_rect(rect,Color(BACK,0.98*alpha))
	draw_rect(rect,Color(RED,alpha),false,2.0)
	var font: Font = ThemeDB.fallback_font
	var heading_size: int = 18 if host.portrait_layout else 13
	var body_size: int = 23 if host.portrait_layout else 17
	var heading_y: float = 27.0 if host.portrait_layout else 21.0
	var body_y: float = 59.0 if host.portrait_layout else 46.0
	draw_string(font,rect.position+Vector2(14,heading_y),"WRONG ANSWER",HORIZONTAL_ALIGNMENT_LEFT,-1,heading_size,Color(RED,alpha))
	draw_string(font,rect.position+Vector2(14,body_y),_receipt(entry),HORIZONTAL_ALIGNMENT_LEFT,-1,body_size,Color("fff1f0",alpha))
