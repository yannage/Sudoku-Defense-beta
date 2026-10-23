class_name DefenseItemCard
extends Button

const Icon = preload("res://scripts/voxel_icon.gd")
const Loot = preload("res://scripts/loot.gd")
var item: Dictionary = {}
var armed: bool = false

func configure(data: Dictionary, is_armed: bool = false) -> void:
	item = data
	set_meta("focus_id", "item:" + str(data.get("id", "")))
	armed = is_armed
	custom_minimum_size = Vector2(0, 86)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = str(item.get("name", "")) + "\n" + str(item.get("description", ""))
	var rarity: String = str(item.get("rarity", "common"))
	var color: Color = Loot.rarity_color(rarity)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("18313b") if armed else Color("102431")
		if state == "hover": style.bg_color = Color("1c3543")
		style.border_color = color if armed or state == "focus" else Color(color, 0.35)
		style.set_border_width_all(2 if armed or state == "focus" else 1)
		style.set_corner_radius_all(9)
		style.content_margin_left = 10
		style.content_margin_right = 10
		add_theme_stylebox_override(state, style)
	var h: HBoxContainer = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 9
	h.offset_right = -9
	h.offset_top = 8
	h.offset_bottom = -8
	h.add_theme_constant_override("separation", 9)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(h)
	var icon: Control = Icon.new()
	icon.kind = str(item.get("kind", "gear"))
	icon.tint = Color(str(Loot.KIND_COLORS.get(icon.kind, "6ce3c5")))
	icon.custom_minimum_size = Vector2(42, 48)
	h.add_child(icon)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	h.add_child(box)
	var title: Label = Label.new()
	title.text = str(Loot.NAMES.get(str(item.get("kind", "")), "Module"))
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("eef8f4"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	var detail: Label = Label.new()
	detail.text = _short_stat(item)
	detail.add_theme_font_size_override("font_size", 13)
	detail.add_theme_color_override("font_color", Color("a9c0c7"))
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(detail)
	var tag: Label = Label.new()
	tag.text = rarity.to_upper() + ("  ·  USE" if str(item.get("type", "")) == "consumable" else ("  ·  SELECTED" if armed else "  ·  DRAG TO TOWER"))
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", color)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tag)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if str(item.get("type", "")) != "attachment": return null
	var preview: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("163546")
	style.border_color = Loot.rarity_color(str(item.get("rarity", "common")))
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	preview.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = str(Loot.NAMES.get(str(item.get("kind", "")), "Module")) + "\nDrop onto a tower"
	label.add_theme_font_size_override("font_size", 16)
	preview.add_child(label)
	set_drag_preview(preview)
	return {"type":"attachment", "item_id":str(item.get("id", ""))}

static func _short_stat(data: Dictionary) -> String:
	var p: float = float(data.get("power", 1.0))
	match str(data.get("kind", "")):
		"rapid": return "+%d%% fire rate" % roundi(p * 20)
		"electric": return "Chain to %d more targets" % mini(7, 1 + floori(p))
		"frost": return "%d%% slow · 2 sec" % roundi(minf(70, p * 18))
		"blast": return "+%d%% splash damage" % roundi(p * 35)
		"venom": return "+%d%% poison / sec" % roundi(p * 30)
		"range": return "+%.2f cells of range" % (p * 0.28)
		"power": return "+%d%% bolt damage" % roundi(p * 25)
		"gravity": return "Pull back %.2f cells" % minf(0.8, p * 0.14)
		"nova": return "+%d%% pulse damage" % roundi(p * 20)
		"overclock": return "All towers: 2× fire · 20 sec"
		"overcharge": return "All towers: +60% hit · 20 sec"
		"freeze": return "All enemies: 60% slow · 12 sec"
		"repair": return "Restore 10 core health"
	return "Stackable · 1 attachment slot"
