class_name DefenseItemCard
extends Button

const Icon = preload("res://scripts/voxel_icon.gd")
const Loot = preload("res://scripts/loot.gd")
var item: Dictionary = {}
var armed: bool = false

const EFFECT_NAMES: Dictionary = {"rapid":"Rapid fire", "electric":"Chain lightning", "frost":"Frost bolts", "blast":"Explosive bolts", "venom":"Poison bolts", "range":"Long range", "power":"Heavy bolts", "gravity":"Gravity pull", "nova":"Nova pulse", "overclock":"Fire-rate boost", "overcharge":"Damage boost", "freeze":"Freeze field", "repair":"Core repair"}
var tile_mode: bool = false

func configure(data: Dictionary, is_armed: bool = false, controller_mode: bool = false, as_tile: bool = false, is_new: bool = false) -> void:
	item = data
	armed = is_armed
	tile_mode = as_tile
	set_meta("focus_id", "item:" + str(data.get("id", "")))
	custom_minimum_size = Vector2(0, 174 if as_tile else 104)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = str(item.get("name", "")) + "\n" + str(item.get("description", ""))
	var rarity: String = str(item.get("rarity", "common"))
	var color: Color = Loot.rarity_color(rarity)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("203d47") if armed else Color("102431")
		if state == "hover": style.bg_color = Color("1c3543")
		style.border_color = color if armed or state == "focus" else Color(color, 0.40)
		style.set_border_width_all(2 if armed or state == "focus" else 1)
		style.border_width_bottom = 4
		style.set_corner_radius_all(9)
		style.shadow_color = Color(0,0,0,0.25)
		style.shadow_size = 3
		style.shadow_offset = Vector2(0,3)
		add_theme_stylebox_override(state, style)
	for child in get_children(): child.queue_free()
	var layout: BoxContainer = VBoxContainer.new() if as_tile else HBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 9
	layout.offset_right = -9
	layout.offset_top = 8
	layout.offset_bottom = -10
	layout.add_theme_constant_override("separation", 3 if as_tile else 9)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layout)
	var icon: Control = Icon.new()
	icon.kind = str(item.get("kind", "gear"))
	icon.tint = Color(str(Loot.KIND_COLORS.get(icon.kind, "6ce3c5")))
	icon.custom_minimum_size = Vector2(60, 62)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL if as_tile else Control.SIZE_SHRINK_CENTER
	layout.add_child(icon)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	layout.add_child(box)
	var title := _text(effect_name(item), 14 if as_tile else 17, Color("eef8f4"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var detail := _text(_short_stat(item), 11 if as_tile else 13, Color("a9c0c7"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(detail)
	var action_hint: String = "A USE" if controller_mode else "USE"
	if str(item.get("type", "")) != "consumable":
		action_hint = "SELECTED" if armed else ("A SELECT" if controller_mode else "DRAG / TAP")
	var tag := _text(("NEW · " if is_new else "") + rarity.to_upper() + ("  ·  " + action_hint if not as_tile else ""), 10, color)
	box.add_child(tag)
	if as_tile:
		var action := _text(action_hint, 9, Color("83e7c1") if armed else Color("6c8792"))
		box.add_child(action)

func _text(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

static func effect_name(data: Dictionary) -> String:
	return str(EFFECT_NAMES.get(str(data.get("kind", "")), "Module"))

func _get_drag_data(_at_position: Vector2) -> Variant:
	if str(item.get("type", "")) != "attachment": return null
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(160,166)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("163546ed")
	style.border_color = Loot.rarity_color(str(item.get("rarity", "common")))
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.shadow_color = Color(0,0,0,0.5)
	style.shadow_size = 8
	style.shadow_offset = Vector2(4,7)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	preview.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	preview.add_child(box)
	var icon: Control = Icon.new()
	icon.kind = str(item.get("kind", "gear"))
	icon.tint = Color(str(item.get("color", "6ce3c5")))
	icon.custom_minimum_size = Vector2(100,90)
	box.add_child(icon)
	var title := _text(effect_name(item),16,Color("eef8f4"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var hint := _text("SNAP INTO A TOWER",10,Color("83e7c1"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	set_drag_preview(preview)
	return {"type":"attachment", "item_id":str(item.get("id", "")), "kind":str(item.get("kind", "")), "color":str(item.get("color", "6ce3c5"))}

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
