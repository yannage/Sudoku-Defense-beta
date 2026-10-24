class_name DefenseItemCard
extends Button

const Icon = preload("res://scripts/voxel_icon.gd")
const Loot = preload("res://scripts/loot.gd")
const DragIcon = preload("res://scripts/gear_drag_icon.gd")
var item: Dictionary = {}
var armed: bool = false

const EFFECT_NAMES: Dictionary = {"rapid":"Rapid fire", "electric":"Chain lightning", "frost":"Frost bolts", "blast":"Explosive bolts", "venom":"Poison bolts", "range":"Long range", "power":"Heavy bolts", "gravity":"Gravity pull", "nova":"Nova pulse", "overclock":"Fire-rate boost", "overcharge":"Damage boost", "freeze":"Slow field", "repair":"Core repair"}
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
	tooltip_text = str(item.get("name", "")) + "\n" + Loot.description(item)
	var rarity: String = str(item.get("rarity", "common"))
	var color: Color = Loot.rarity_color(rarity)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("203d47") if armed else Color("102431")
		if state == "hover": style.bg_color = Color("233e4b")
		if state == "pressed": style.bg_color = Color("0b1c27")
		if state == "focus": style.bg_color = Color.TRANSPARENT
		style.border_color = color if armed or state == "focus" else Color(color, 0.40)
		style.set_border_width_all(2 if armed or state == "focus" else 1)
		style.border_width_bottom = 2 if state == "pressed" else 4
		style.set_corner_radius_all(5)
		style.shadow_color = Color(0,0,0,0.30)
		style.shadow_size = 1 if state in ["pressed","focus"] else 4
		style.shadow_offset = Vector2(0,1 if state == "pressed" else 3)
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
	# Keep the cursor hotspot and destination tower uncovered. The root has no
	# panel or text; its small child token is offset from the actual drop point.
	var preview := Control.new()
	preview.name = "CompactGearDrag"
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.focus_mode = Control.FOCUS_NONE
	var icon: Control = DragIcon.new()
	icon.configure(item)
	var pointer: Vector2 = get_global_mouse_position()
	var bounds: Vector2 = get_viewport_rect().size
	icon.position = Vector2(-72 if pointer.x > bounds.x-76 else 16,14 if pointer.y < 68 else -62)
	preview.add_child(icon)
	set_drag_preview(preview)
	return {"type":"attachment", "item_id":str(item.get("id", "")), "kind":str(item.get("kind", "")), "color":str(item.get("color", "6ce3c5"))}

func _draw() -> void:
	if item.is_empty(): return
	var color: Color = Loot.rarity_color(str(item.get("rarity", "common")))
	# Small lit rails and recessed contacts give modules a physical silhouette
	# without moving their touch/drag hit areas during hover or selection.
	draw_line(Vector2(12,3),Vector2(minf(40,size.x-12),3),Color(color,0.85),2.0,true)
	draw_line(Vector2(44,3),Vector2(maxf(44,size.x-12),3),Color(color,0.15),1.0,true)
	if armed:
		var p := Vector2(size.x-12,12)
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-4),p+Vector2(4,0),p+Vector2(0,4),p+Vector2(-4,0)]),color)

static func _short_stat(data: Dictionary) -> String:
	var p: float = float(data.get("power", 1.0))
	match str(data.get("kind", "")):
		"rapid": return "+%d%% fire rate" % roundi(p * 20)
		"electric": return "Chain to %d more targets" % mini(7, 1 + floori(p))
		"frost": return "%d%% slow · 2 sec" % roundi(minf(70, p * 18))
		"blast": return "%d%% bolt damage as splash" % roundi(minf(300, p * 35))
		"venom": return "%d%% bolt damage / sec · 3 sec" % roundi(p * 30)
		"range": return "+%.2f cells of range" % (p * 0.28)
		"power": return "+%d%% bolt damage" % roundi(p * 25)
		"gravity": return "Pull back %.2f cells" % minf(0.8, p * 0.14)
		"nova": return "%d%% bolt damage as pulse" % roundi(minf(250, p * 20))
		"overclock": return "All towers: 2× fire rate · 20 sec"
		"overcharge": return "All towers: +60% damage · 20 sec"
		"freeze": return "All enemies: 60% slow · 12 sec"
		"repair": return "Restore up to 10 core health"
	return "Uses 1 module slot"
