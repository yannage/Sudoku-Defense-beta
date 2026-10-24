extends Button
## A compact game-mode tile; Button semantics remain available to gamepads.
const Palette = preload("res://scripts/ui_skin.gd")
var chosen := false
var detail := ""
var symbol := ""
var compact := false

func configure(title: String, subtitle: String, glyph: String, selected: bool, small: bool = false) -> void:
	text = title
	detail = subtitle
	symbol = glyph
	compact = small
	custom_minimum_size = Vector2(0,52 if compact else 82)
	set_meta("menu_height",custom_minimum_size.y)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_text = true
	tooltip_text = subtitle
	Palette.button(self)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		add_theme_color_override(state,Color.TRANSPARENT)
	set_chosen(selected)
	for event in [mouse_entered,mouse_exited,focus_entered,focus_exited]: event.connect(queue_redraw)

func set_chosen(value: bool) -> void:
	chosen = value
	add_theme_stylebox_override("normal",Palette.panel(Color("1a3c3b") if chosen else Color("10232d"),Color("6eaf98") if chosen else Color("304751"),6,8))
	queue_redraw()

func _draw() -> void:
	var accent := Palette.MINT if chosen else Color("90aeb6")
	var font: Font = ThemeDB.fallback_font
	var title: String = text.split(" / ")[0]
	var font_size: int = clampi(get_theme_font_size("font_size"),14,22)
	if compact:
		draw_string(font,Vector2(12,size.y*0.5+5),title,HORIZONTAL_ALIGNMENT_LEFT,maxf(20,size.x-44),font_size,Palette.TEXT)
		var bars: int = {"easy":1,"medium":2,"hard":3}.get(symbol,1)
		for i in range(3):
			draw_rect(Rect2(size.x-30+i*6, size.y*0.5+7-(i+1)*5,4,(i+1)*5),accent if i<bars else Color("27434b"))
	else:
		_glyph(Vector2(17,20),accent)
		draw_string(font,Vector2(12,47),title,HORIZONTAL_ALIGNMENT_LEFT,size.x-22,font_size,Palette.TEXT)
		draw_string(font,Vector2(12,66),detail,HORIZONTAL_ALIGNMENT_LEFT,size.x-22,13 if font_size>18 else 11,accent)
	if chosen:
		draw_line(Vector2(10,size.y-5),Vector2(size.x-10,size.y-5),Palette.MINT,2)
		draw_circle(Vector2(size.x-12,12),3,Palette.MINT)

func _glyph(p: Vector2, color: Color) -> void:
	if symbol == "locked":
		draw_arc(p+Vector2(3,-3),5,PI,TAU,10,color,2,true)
		draw_rect(Rect2(p+Vector2(-4,-3),Vector2(14,11)),color)
		draw_line(p+Vector2(3,0),p+Vector2(3,5),Palette.INK,2)
	elif symbol == "freeplay":
		draw_colored_polygon(PackedVector2Array([p+Vector2(2,-10),p+Vector2(-5,2),p+Vector2(1,2),p+Vector2(-1,11),p+Vector2(9,-2),p+Vector2(3,-2)]),color)
	else:
		for y in range(3):
			for x in range(3): draw_rect(Rect2(p+Vector2(x*6-5,y*6-8),Vector2(4,4)),color if x==y or x==1 else Color(color,0.4))
