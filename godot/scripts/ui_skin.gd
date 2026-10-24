class_name DefenseUISkin
extends RefCounted
## Shared tactile surfaces. No shaders, raster dependencies or input overlays.
const INK := Color("08141c")
const PANEL := Color("142a34")
const MINT := Color("8ce8c8")
const GOLD := Color("f7b77e")
const TEXT := Color("eef5ee")

static func panel(bg: Color, border: Color, radius: int = 8, margin: int = 12, raised: bool = true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0 else 0)
	s.border_width_bottom = 3 if raised and border.a > 0 else s.border_width_bottom
	s.set_corner_radius_all(radius)
	s.corner_detail = 2
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = 9
	s.content_margin_bottom = 11
	if raised:
		s.shadow_color = Color(0.015,0.035,0.045,0.45)
		s.shadow_size = 7
		s.shadow_offset = Vector2(0,4)
	return s

static func button(control: Button, accent: bool = false) -> void:
	control.add_theme_color_override("font_color", INK if accent else TEXT)
	control.add_theme_color_override("font_hover_color", INK if accent else Color("ffffff"))
	control.add_theme_color_override("font_pressed_color", INK if accent else MINT)
	control.add_theme_color_override("font_focus_color", INK if accent else TEXT)
	control.add_theme_color_override("font_disabled_color", Color("657f86"))
	control.add_theme_stylebox_override("normal", panel(GOLD if accent else PANEL, Color("b1764d") if accent else Color("36505b"),6))
	control.add_theme_stylebox_override("hover", panel(Color("ffd1a2") if accent else Color("203e46"), Color("e1a169") if accent else Color("6fa995"),6))
	control.add_theme_stylebox_override("pressed", panel(Color("d99865") if accent else Color("0b222b"),Color("8d6848") if accent else MINT,6,12,false))
	control.add_theme_stylebox_override("disabled", panel(Color("0d1d27"),Color("203741"),6,12,false))
	var focus := panel(Color.TRANSPARENT,MINT,6,12,false)
	focus.set_border_width_all(2)
	focus.expand_margin_left = 2
	focus.expand_margin_right = 2
	focus.expand_margin_top = 2
	focus.expand_margin_bottom = 2
	control.add_theme_stylebox_override("focus",focus)

static func scroll(control: ScrollContainer) -> void:
	var bar: VScrollBar = control.get_v_scroll_bar()
	bar.custom_minimum_size.x = 8
	var track := panel(Color("091820"),Color.TRANSPARENT,3,0,false)
	track.content_margin_top = 0
	track.content_margin_bottom = 0
	bar.add_theme_stylebox_override("scroll",track)
	for state in ["grabber","grabber_highlight","grabber_pressed"]:
		var grip := panel(Color("3d6b68") if state == "grabber" else MINT,Color.TRANSPARENT,3,0,false)
		grip.content_margin_left = 3
		grip.content_margin_right = 3
		bar.add_theme_stylebox_override(state,grip)
