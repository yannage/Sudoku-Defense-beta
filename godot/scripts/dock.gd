class_name DefenseDock
extends Control

signal changed(result: Dictionary)
signal closed()
signal cell_requested(cell: int)
signal item_armed(item_id: String)
signal family_preview_requested(number: int)

const LootTable = preload("res://scripts/loot_table.gd")
const Card = preload("res://scripts/item_card.gd")
const Icon = preload("res://scripts/voxel_icon.gd")
const QuickIcon = preload("res://scripts/quick_icon.gd")
const Loot = preload("res://scripts/loot.gd")
const ChestStage = preload("res://scripts/chest_stage.gd")
const CanvasChestStage = preload("res://scripts/chest_canvas.gd")
const RenderProfile = preload("res://scripts/render_profile.gd")
const INK: Color = Color("081923")
const PANEL: Color = Color("0b1923")
const LINE: Color = Color("2b424c")
const TEXT: Color = Color("e9f4ee")
const MUTED: Color = Color("91aab4")
const MINT: Color = Color("74e0c3")
const GOLD: Color = Color("ffc184")
const FAMILY_COLORS: Array[Color] = [Color("ffffff"), Color("6de8ff"), Color("a4c7ff"), Color("c6a0ff"), Color("ffae68"), Color("fb86c3"), Color("9be878"), Color("ffe188"), Color("bb9bff"), Color("dec3ed")]

class TowerDropButton extends Button:
	signal module_dropped(item_id: String)
	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return not disabled and data is Dictionary and str(data.get("type", "")) == "attachment"
	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		module_dropped.emit(str(data.get("item_id", "")))

var run
var current_panel: String = "bag"
var selected_cell: int = -1
var _opened: bool = false
var _armed_id: String = ""
var _message: String = ""
var _reward: Dictionary = {}
var _slot_result: Dictionary = {}
var _show_odds: bool = false
var _reveal_animated: bool = false
var _slot_animated: bool = false
var _shell: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _focus_target: Control
var _portrait: bool = false
var _layout_size: Vector2 = Vector2(1280, 800)
var _board_bottom: float = 760.0
var controller_mode: bool = false
var _hovered_family: int = 0
var _focused_family: int = 0
var _bag_filter: String = "all"
var _show_reserves: bool = false
var _recent_item_ids: Array[String] = []
var _loot_table: Control
var reduced_motion: bool = false

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if is_instance_valid(_loot_table): _loot_table.set_reduced_motion(value)

func _ensure_loot_table() -> void:
	if is_instance_valid(_loot_table): return
	_loot_table = LootTable.new()
	add_child(_loot_table)
	_loot_table.setup(run, reduced_motion)
	_loot_table.changed.connect(func(result):
		_reward = _loot_table.reward
		changed.emit(result)
	)
	_loot_table.gear_requested.connect(_show_new_gear)
	_loot_table.hide()

func _show_new_gear(items: Array) -> void:
	_armed_id = ""
	item_armed.emit("")
	_recent_item_ids.clear()
	# Present newly won attachments first, even when the bag already contains
	# rarer equipment. Consumables remain reachable without activating them.
	for kind in ["attachment", "consumable"]:
		for item: Dictionary in items:
			if str(item.get("type", "")) == kind:
				_recent_item_ids.append(str(item.get("id", "")))
	_bag_filter = "all" if items.any(func(item): return str(item.get("type", "")) == "attachment") else "items"
	open_panel("bag", selected_cell)
	if _recent_item_ids.is_empty(): return
	for button in _focusable_buttons():
		if str(button.get_meta("focus_id", "")) == "item:" + _recent_item_ids[0]:
			_focus_target = button
			_focus_current.call_deferred()
			break

func _preview_family(number: int, focused: bool, active: bool) -> void:
	if focused: _focused_family = number if active else 0
	else: _hovered_family = number if active else 0
	family_preview_requested.emit(_focused_family if _focused_family > 0 else _hovered_family)

func _clear_family_preview() -> void:
	_hovered_family = 0
	_focused_family = 0
	family_preview_requested.emit(0)

func _family_tower_count(number: int) -> int:
	var count: int = 0
	for tower in run.towers.values():
		if int(tower.number) == number: count += 1
	return count

func set_controller_mode(value: bool) -> void:
	if controller_mode == value: return
	controller_mode = value
	if _opened: refresh()

func cycle_panel(direction: int) -> void:
	var panels: Array[String] = ["tower", "bag", "loot", "camp"]
	var index: int = panels.find(current_panel)
	open_panel(panels[posmod(index + direction, panels.size())], selected_cell)

func set_layout(viewport_size: Vector2, portrait: bool, board_bottom: float) -> void:
	var mode_changed: bool = _portrait != portrait
	_portrait = portrait
	_layout_size = viewport_size
	_board_bottom = board_bottom
	_apply_layout()
	if mode_changed and _opened:
		refresh()

func _apply_layout() -> void:
	if not is_instance_valid(_shell): return
	_shell.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	if current_panel == "loot":
		_shell.position = Vector2(16, 16 if _layout_size.y < 700 else 22 if _portrait else 80)
		_shell.size = Vector2(_layout_size.x - 32, _layout_size.y - _shell.position.y - 16)
	elif _portrait:
		# The battlefield stays visible above this sheet, including while a module
		# is armed or dragged. Long equipment lists scroll inside the sheet.
		var top: float = clampf(_board_bottom + 8.0, 16.0, _layout_size.y - 300.0)
		_shell.position = Vector2(16, top)
		_shell.size = Vector2(_layout_size.x - 32, _layout_size.y - top - 16)
	else:
		_shell.position = Vector2(_layout_size.x - 340, 96)
		_shell.size = Vector2(320, maxf(300, _layout_size.y - 204))

func setup(game_run) -> void:
	run = game_run
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()
	visible = false

func _build_shell() -> void:
	if is_instance_valid(_shell):
		remove_child(_shell)
		_shell.queue_free()
	_shell = PanelContainer.new()
	_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	var frame := _style(PANEL, LINE, 10, 1, 16)
	frame.corner_detail = 1
	frame.border_width_top = 3
	frame.border_width_bottom = 4
	frame.shadow_color = Color(0,0,0,0.42)
	frame.shadow_size = 12
	frame.shadow_offset = Vector2(0,5)
	_shell.add_theme_stylebox_override("panel", frame)
	add_child(_shell)
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_shell.add_child(outer)
	_body = outer
	_apply_layout()

func open_panel(kind: String, cell: int = -1) -> void:
	current_panel = kind
	if is_instance_valid(_scroll): _scroll.scroll_vertical = 0
	if cell >= 0: selected_cell = cell
	_opened = true
	visible = true
	_message = ""
	refresh(false)
	_focus_current.call_deferred()
	_shell.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_shell, "modulate:a", 1.0, 0.16)

func _focus_current() -> void:
	if _opened and is_instance_valid(_focus_target) and _focus_target.is_inside_tree():
		_focus_target.grab_focus()
		if is_instance_valid(_scroll) and _scroll.is_ancestor_of(_focus_target):
			_scroll.ensure_control_visible.call_deferred(_focus_target)

func close_panel(preserve_armed: bool = false) -> void:
	_clear_family_preview()
	_opened = false
	visible = false
	if not preserve_armed: _armed_id = ""
	closed.emit()

func reset_for_run() -> void:
	_reward.clear()
	if is_instance_valid(_loot_table): _loot_table.reset_for_run()
	_bag_filter = "all"
	_show_reserves = false
	_recent_item_ids.clear()
	_slot_result.clear()
	_armed_id = ""
	_message = ""
	selected_cell = -1
	current_panel = "bag"
	close_panel()

func is_open() -> bool:
	return _opened

func set_selected(cell: int) -> void:
	selected_cell = cell
	if _opened: refresh()

func clear_armed() -> void:
	_armed_id = ""
	if _opened: refresh()

func refresh(preserve_focus: bool = true) -> void:
	if not _opened or run == null: return
	_clear_family_preview()
	var old_scroll: int = _scroll.scroll_vertical if is_instance_valid(_scroll) else 0
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	var restore_focus: bool = preserve_focus and is_instance_valid(focus_owner) and _shell.is_ancestor_of(focus_owner)
	var focus_id: String = str(focus_owner.get_meta("focus_id", "")) if restore_focus else ""
	var old_focus_index: int = _focusable_buttons().find(focus_owner) if restore_focus else -1
	if is_instance_valid(_loot_table):
		if _loot_table.get_parent() != self: _loot_table.reparent(self)
		_loot_table.hide()
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var top: HBoxContainer = HBoxContainer.new()
	_body.add_child(top)
	var names: Dictionary = {"tower":"TOWER WORKSHOP", "bag":"GEAR", "loot":"CHESTS", "camp":"BASE CAMP"}
	var captions: Dictionary = {"tower":"BUILD YOUR FIREPOWER", "bag":"FIND YOUR NEXT UPGRADE", "loot":"SALVAGE RECOVERED", "camp":"BETWEEN SIEGES"}
	var heading := HBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation",8)
	top.add_child(heading)
	heading.add_child(_navigation_icon(current_panel,Vector2(34,38)))
	var heading_text := VBoxContainer.new()
	heading_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_text.add_theme_constant_override("separation",3)
	heading.add_child(heading_text)
	heading_text.add_child(_label(str(captions.get(current_panel,"LOADOUT")),9,MINT))
	var title: Label = _label(str(names.get(current_panel, "LOADOUT")), 17, TEXT)
	title.clip_text = true
	heading_text.add_child(title)
	var close_button: Button = _button("B" if controller_mode else "X", close_panel, false, false, 34, "close")
	close_button.custom_minimum_size = Vector2(34, 34)
	close_button.tooltip_text = "Close panel · B / Escape"
	top.add_child(close_button)
	_focus_target = close_button
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	_body.add_child(tabs)
	tabs.visible = current_panel != "loot"
	for tab in ["tower", "bag", "loot", "camp"]:
		var tab_kind: String = str(tab)
		var text_value: String = str({"tower":"Tower", "bag":"Gear", "loot":"Chests", "camp":"Camp"}[tab_kind])
		var tab_button: Button = _button(text_value, func(): open_panel(tab_kind, selected_cell), tab_kind == current_panel, false, 32, "tab:" + tab_kind)
		tab_button.add_theme_font_size_override("font_size", 11)
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.custom_minimum_size.y = 38
		_selection_style(tab_button,tab_kind == current_panel,26)
		var tab_icon: Control = _navigation_icon(tab_kind,Vector2(20,20))
		tab_button.add_child(tab_icon)
		tab_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		tab_icon.position = Vector2(4,-10)
		tab_icon.size = Vector2(20,20)
		tabs.add_child(tab_button)
		if tab_kind == current_panel and current_panel != "loot": _focus_target = tab_button
	var money: HBoxContainer = HBoxContainer.new()
	_body.add_child(money)
	var credits: Label = _label("%d CREDITS" % int(run.credits), 13, GOLD)
	credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money.add_child(credits)
	money.add_child(_label("%d FRAGMENTS" % int(run.fragments), 12, Color("b6a4ed")))
	if _portrait and current_panel != "loot":
		# Keep a whole module tile reachable below the board. The top HUD already
		# shows resources; combine navigation and close into one touch-sized row.
		heading.hide()
		tabs.reparent(top)
		top.move_child(tabs, 0)
		tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		money.hide()
	if not _message.is_empty():
		var note: Label = _label(_message, 13, MINT)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(note)
	if current_panel == "loot":
		_ensure_loot_table()
		_loot_table.reparent(_body)
		_loot_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_loot_table.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_loot_table.controller_mode = controller_mode
		_loot_table.show()
		_loot_table.refresh()
		_scroll = null
		if _portrait:
			for child in _body.get_children():
				if child != _loot_table: _apply_touch_sizes(child)
		var preferred: Control = _loot_table.preferred_focus()
		if is_instance_valid(preferred): _focus_target = preferred
	else:
		_scroll = ScrollContainer.new()
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.follow_focus = true
		_style_scrollbar(_scroll.get_v_scroll_bar())
		_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_body.add_child(_scroll)
		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 12)
		_scroll.add_child(content)
		match current_panel:
			"tower": _tower_panel(content)
			"bag": _bag_panel(content)
			"camp": _camp_panel(content)
		if _portrait: _apply_touch_sizes(_body)
		_scroll.set_deferred("scroll_vertical", old_scroll)
	_apply_layout()
	# Containers recalculate their minimum after newly built content enters the
	# tree. Reapply the viewport bounds after that pass so a transient minimum
	# cannot leave the sheet stretched beyond the screen.
	_apply_layout.call_deferred()
	if restore_focus:
		var focus_found: bool = false
		if not focus_id.is_empty():
			for candidate in _focusable_buttons():
				if str(candidate.get_meta("focus_id", "")) == focus_id:
					_focus_target = candidate
					focus_found = true
					break
		if not focus_found and old_focus_index >= 0:
			var controls: Array[Control] = _focusable_buttons()
			if not controls.is_empty(): _focus_target = controls[mini(old_focus_index, controls.size() - 1)]
		_focus_current.call_deferred()

func _focusable_buttons() -> Array[Control]:
	var controls: Array[Control] = []
	if not is_instance_valid(_shell): return controls
	for candidate in _shell.find_children("*", "Button", true, false):
		if candidate.is_visible_in_tree() and not candidate.disabled and candidate.focus_mode != Control.FOCUS_NONE:
			controls.append(candidate)
	return controls

func _apply_touch_sizes(node: Node) -> void:
	# Increase small controls without multiplying already generous module tiles.
	# This leaves enough scrolling space to expose a whole tile for touch drag.
	if node is Label or node is Button:
		var base_font: int = node.get_theme_font_size("font_size")
		node.add_theme_font_size_override("font_size", maxi(16, base_font))
	if node is TowerDropButton:
		node.custom_minimum_size = Vector2(maxf(54, node.custom_minimum_size.x), maxf(54, node.custom_minimum_size.y))
	elif node is Button:
		node.custom_minimum_size.y = maxf(44, node.custom_minimum_size.y)
		if str(node.get_meta("focus_id", "")) == "close": node.custom_minimum_size.x = 44
	for child in node.get_children():
		_apply_touch_sizes(child)

func _tower_panel(content: VBoxContainer) -> void:
	if not run.towers.has(selected_cell):
		_note(content, "Select a tower on the board or the mini grid to inspect it.")
		_mini_grid(content)
		return
	var tower: Dictionary = run.towers[selected_cell]
	var number: int = int(tower.number)
	var stats: Dictionary = run.tower_stats(selected_cell)
	var hero := _panel(FAMILY_COLORS[number].darkened(0.6))
	content.add_child(hero)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation",10)
	hero.add_child(title_row)
	var icon: Control = _icon("power", FAMILY_COLORS[number], Vector2(48,56))
	title_row.add_child(icon)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation",4)
	title_row.add_child(title_box)
	title_box.add_child(_label("TOWER %d" % number,22,TEXT))
	title_box.add_child(_label("LEVEL %d  /  R%d · C%d" % [int(stats.get("level",1)),selected_cell/9+1,selected_cell%9+1],11,FAMILY_COLORS[number]))
	var stats_row: HBoxContainer = HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 6)
	content.add_child(stats_row)
	_stat(stats_row, "DAMAGE", "%.0f" % float(stats.get("damage", 0)))
	_stat(stats_row, "FIRE / SEC", "%.1f" % (1.0 / maxf(0.05, float(stats.get("interval", 1)))))
	_stat(stats_row, "RANGE", "%.1f" % float(stats.get("range", 0)))
	_section(content, "TARGET PRIORITY", "IN RANGE")
	var priority: String = str(tower.get("target_priority","first"))
	var target_row := HBoxContainer.new()
	target_row.add_theme_constant_override("separation",4)
	content.add_child(target_row)
	var descriptions := {"first":"First: nearest the exit.","strongest":"Strongest: highest current health.","nearest":"Nearest: closest to this tower."}
	for mode: String in ["first","strongest","nearest"]:
		var target_mode: String = mode
		var target_cell: int = selected_cell
		var choice := _button(mode.capitalize(),func(): _act("set_target_priority",[target_cell,target_mode]),false,false,44,"target:"+mode)
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.tooltip_text = str(descriptions[mode])
		choice.set_meta("selected_priority",priority == mode)
		_selection_style(choice,priority == mode,6)
		target_row.add_child(choice)
	_note(content,"First = nearest exit\nStrongest = highest current HP\nNearest = closest to this tower")
	var attachments: Array = tower.get("attachments", [])
	_section(content, "MODULE SOCKETS", "%d / 5 used" % attachments.size())
	_socket_strip(content, selected_cell)
	_note(content, "Select a module to remove it. Drag another onto a filled slot to swap.")
	content.add_child(_button("Fit a module", func(): open_panel("bag", selected_cell), false, false, 38, "gear:open"))
	var cost: int = int(run.upgrade_cost(selected_cell))
	var cell: int = selected_cell
	content.add_child(_button("Upgrade this tower   ·   %d" % cost, func(): _act("upgrade_tower", [cell]), true, int(run.credits) < cost, 42, "upgrade:tower"))
	var family_cost: int = int(run.family_upgrade_cost(number))
	var family_count: int = _family_tower_count(number)
	_section(content, "NUMBER %d UPGRADE" % number, "LEVEL %d → %d" % [int(run.family_levels[number]), int(run.family_levels[number]) + 1])
	var family_button: Button = _button("Upgrade all %ds · %d %s\n%d credits" % [number, family_count, "tower" if family_count == 1 else "towers", family_cost], func(): _act("upgrade_family", [number]), false, int(run.credits) < family_cost, 58, "upgrade:family")
	family_button.tooltip_text = "Upgrades your %d towers numbered %d and every %d tower you plant later in this run. Fixed clues are not towers." % [family_count, number, number]
	family_button.mouse_entered.connect(func(): _preview_family(number, false, true))
	family_button.mouse_exited.connect(func(): _preview_family(number, false, false))
	family_button.focus_entered.connect(func(): _preview_family(number, true, true))
	family_button.focus_exited.connect(func(): _preview_family(number, true, false))
	content.add_child(family_button)
	_note(content, "Highlighted: your %d towers. Future %ds get this upgrade too." % [number, number], FAMILY_COLORS[number])
	_mini_grid(content)

func _socket_strip(content: VBoxContainer, cell: int) -> void:
	var tower: Dictionary = run.towers[cell]
	var attachments: Array = tower.get("attachments", [])
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation",5)
	content.add_child(strip)
	for i in range(5):
		var slot: int = i
		var filled: bool = slot < attachments.size()
		var socket := TowerDropButton.new()
		socket.custom_minimum_size = Vector2(45,64)
		socket.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		socket.set_meta("focus_id","slot:" + str(slot))
		socket.focus_mode = Control.FOCUS_ALL
		socket.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var tint: Color = Loot.rarity_color(str(attachments[slot].get("rarity","common"))) if filled else MINT if not _armed_id.is_empty() else LINE
		for state in ["normal","hover","pressed","focus"]:
			socket.add_theme_stylebox_override(state,_style(Color("122b35") if filled else Color("081923"),TEXT if state == "focus" else tint,6,2 if state == "focus" else 1,0))
		if filled:
			var module: Dictionary = attachments[slot]
			var visual: Control = _icon(str(module.kind),Color(str(module.color)),Vector2.ZERO)
			visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			socket.add_child(visual)
			socket.tooltip_text = Card.effect_name(module) + "\n" + Card._short_stat(module) + "\nSelect to remove · drag another module here to swap"
			socket.pressed.connect(func(): _act("unequip_item",[cell,slot]))
		else:
			socket.text = "+"
			socket.add_theme_font_size_override("font_size",22)
			socket.add_theme_color_override("font_color",MINT if not _armed_id.is_empty() else MUTED)
			socket.tooltip_text = "Empty slot %d / 5" % (slot+1)
			socket.pressed.connect(func():
				if not _armed_id.is_empty(): _act("equip_item",[cell,_armed_id])
				else: open_panel("bag",cell)
			)
		socket.module_dropped.connect(func(id):
			if filled: _act("swap_attachment",[cell,slot,id])
			else: _act("equip_item",[cell,id])
		)
		strip.add_child(socket)

func _visible_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in run.items:
		var consumable: bool = str(item.get("type","")) == "consumable"
		var support: bool = str(item.get("kind","")) in ["frost","range","gravity"]
		if _bag_filter == "items" and not consumable: continue
		if _bag_filter == "attack" and (consumable or support): continue
		if _bag_filter == "support" and (consumable or not support): continue
		result.append(item)
	result.sort_custom(func(a,b):
		var an: int = _recent_item_ids.find(str(a.get("id", "")))
		var bn: int = _recent_item_ids.find(str(b.get("id", "")))
		if an >= 0 or bn >= 0:
			if an < 0: return false
			if bn < 0: return true
			return an < bn
		var ar: int = Loot.rarity_index(str(a.get("rarity","common")))
		var br: int = Loot.rarity_index(str(b.get("rarity","common")))
		if ar != br: return ar > br
		if str(a.kind) != str(b.kind): return str(a.kind) < str(b.kind)
		return float(a.get("power",1)) > float(b.get("power",1))
	)
	return result

func _set_bag_filter(value: String) -> void:
	_bag_filter = value
	if is_instance_valid(_scroll): _scroll.scroll_vertical = 0
	refresh()

func _selected_module() -> Dictionary:
	for item: Dictionary in run.items:
		if str(item.id) == _armed_id: return item
	return {}

func _bag_panel(content: VBoxContainer) -> void:
	var chosen: Dictionary = _selected_module()
	if not chosen.is_empty():
		var info := _panel(Loot.rarity_color(str(chosen.rarity)))
		content.add_child(info)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation",6)
		info.add_child(box)
		var name := _label(Card.effect_name(chosen),19,TEXT)
		box.add_child(name)
		_note(box,Card._short_stat(chosen),MINT)
		_note(box,str(chosen.get("name","")),Loot.rarity_color(str(chosen.rarity)))
		if run.towers.has(selected_cell):
			var tower: Dictionary = run.towers[selected_cell]
			var used: int = tower.attachments.size()
			_note(box,"Tower %d · %d empty slots" % [int(tower.number),5-used],GOLD)
			_socket_strip(box,selected_cell)
			var id: String = _armed_id
			var cell: int = selected_cell
			box.add_child(_button("Fit to tower %d" % int(tower.number),func(): _act("equip_item",[cell,id]),true,used >= 5,42,"attach:selected"))
			if used >= 5: _note(box,"All five slots are full. Remove a module or choose another tower.",GOLD)
			else: _note(box,_effect_preview(chosen,selected_cell),MINT)
		else:
			_note(box,"Select a tower to equip this module. Each tower has five slots.")
		box.add_child(_button("Cancel selection",func(): _armed_id = ""; item_armed.emit(""); refresh(),false,false,32,"gear:cancel"))
	else:
		_note(content,"Select a module, then a tower. You can also drag modules onto towers.")
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation",3)
	content.add_child(filters)
	for entry in [["all","All"],["attack","Attack"],["support","Support"],["items","Boosts"]]:
		var key: String = entry[0]
		var filter := _button(entry[1],func(): _set_bag_filter(key),_bag_filter == key,false,32,"filter:"+key)
		filter.add_theme_font_size_override("font_size",11)
		_selection_style(filter,_bag_filter == key)
		filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		filters.add_child(filter)
	var visible_items: Array[Dictionary] = _visible_items()
	_section(content,"YOUR GEAR" if _bag_filter != "items" else "SINGLE-USE BOOSTS", "%d items" % visible_items.size())
	if visible_items.is_empty(): _note(content,"No gear in this category. Try another filter or open a chest.")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",7)
	grid.add_theme_constant_override("v_separation",9)
	content.add_child(grid)
	for item: Dictionary in visible_items:
		var data: Dictionary = item
		var card: Button = Card.new()
		card.configure(data,str(data.id) == _armed_id,controller_mode,true,_recent_item_ids.has(str(data.id)))
		card.pressed.connect(func():
			if str(data.get("type","")) == "consumable":
				_act("use_item",[data.id])
				return
			_armed_id = str(data.id)
			_message = ""
			item_armed.emit(_armed_id)
			if is_instance_valid(_scroll): _scroll.scroll_vertical = 0
			refresh(false)
		)
		grid.add_child(card)
	content.add_child(_button(("Hide" if _show_reserves else "Show") + " emergency seeds",func(): _show_reserves = not _show_reserves; refresh(),false,false,34,"bag:reserves"))
	if _show_reserves:
		_note(content,"Reserve seeds cost 6 credits each. Use them to add towers during battle. Wrong numbers add corruption.")
		var seed_grid := GridContainer.new()
		seed_grid.columns = 3
		seed_grid.add_theme_constant_override("h_separation",5)
		seed_grid.add_theme_constant_override("v_separation",5)
		content.add_child(seed_grid)
		for seed_number in range(1,10):
			var number: int = seed_number
			var buy := _button("%d · ×%d" % [number,int(run.inventory[number])],func(): _act("buy_seed",[number]),false,int(run.credits)<6,36,"seed:"+str(number))
			buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			seed_grid.add_child(buy)

func _effect_preview(item: Dictionary, cell: int) -> String:
	var stats: Dictionary = run.tower_stats(cell)
	var power: float = float(item.get("power",1))
	var effects: Dictionary = stats.effects
	match str(item.kind):
		"power":
			var before: float = float(stats.damage)
			var after: float = before * (1.0 + .25 * (float(effects.get("power",0))+power)) / (1.0 + .25 * float(effects.get("power",0)))
			return "Bolt damage: %.1f → %.1f" % [before,after]
		"rapid":
			var before: float = float(stats.attack_speed)
			var after: float = before * (1.0 + .20 * (float(effects.get("rapid",0))+power)) / (1.0 + .20 * float(effects.get("rapid",0)))
			return "Shots / sec: %.1f → %.1f" % [before,after]
		"range": return "Range: %.2f → %.2f cells" % [float(stats.range),minf(4.75,float(stats.range)+.28*power)]
	return "Uses one slot. Matching module effects add together."


func _camp_panel(content: VBoxContainer) -> void:
	_note(content, "These upgrades last for the rest of this run.")
	_section(content, "RUN UPGRADES", "Lasts for this run")
	var definitions: Array[Dictionary] = [
		{"id":"power", "name":"Root reactor", "detail":"+9% base bolt damage per level, for every tower", "icon":"power"},
		{"id":"salvage", "name":"Salvage drone", "detail":"Better chest rarity and a chance for extra fragments", "icon":"rapid"},
		{"id":"vitality", "name":"Living core", "detail":"+4 maximum core health; repairs 4 health now", "icon":"repair"}
	]
	for entry in definitions:
		var kind: String = str(entry.id)
		var cost: int = int(run.passive_cost(kind))
		var level: int = int(run.passives.get(kind, 0))
		var row: PanelContainer = _panel(LINE)
		content.add_child(row)
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		row.add_child(box)
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation",8)
		box.add_child(title_row)
		title_row.add_child(_icon(str(entry.icon),MINT if kind != "vitality" else GOLD,Vector2(38,42)))
		var titles := VBoxContainer.new()
		titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(titles)
		titles.add_child(_label("LEVEL %02d" % level,10,MINT))
		var title := _label(str(entry.name),16,TEXT)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		titles.add_child(title)
		_note(box, str(entry.detail))
		box.add_child(_button("Improve   ·   %d" % cost, func(): _act("buy_passive", [kind]), false, int(run.credits) < cost or str(run.phase) != "loot", 34, "passive:" + kind))
	_section(content, "THE SALVAGE REELS", "10 credits / spin")
	var slot_box: PanelContainer = _panel(Color("574835"))
	content.add_child(slot_box)
	var slot_content: VBoxContainer = VBoxContainer.new()
	slot_content.add_theme_constant_override("separation", 9)
	slot_box.add_child(slot_content)
	var reels: HBoxContainer = HBoxContainer.new()
	reels.add_theme_constant_override("separation", 6)
	slot_content.add_child(reels)
	var symbols: Array = _slot_result.get("reels", ["gear", "credit", "chest-common"])
	for i in range(3):
		var reel: PanelContainer = _panel(Color("3a474b"))
		reel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reels.add_child(reel)
		var symbol: String = str(symbols[i]) if i < symbols.size() else "gear"
		var rarity: String = symbol.trim_prefix("chest-") if symbol.begins_with("chest-") else "common"
		var color: Color = Loot.rarity_color(rarity) if symbol.begins_with("chest") else GOLD
		var icon: Control = _icon(symbol, color, Vector2(40, 58))
		reel.add_child(icon)
		if not _slot_result.is_empty() and not _slot_animated:
			icon.modulate.a = 0.15
			var tween: Tween = create_tween()
			tween.tween_interval(0.18 + float(i) * 0.15)
			tween.tween_property(icon, "modulate:a", 1.0, 0.28)
	if not _slot_result.is_empty():
		_slot_animated = true
		_note(slot_content, str(_slot_result.get("message", _slot_result.get("label", "Reward added to Gear."))), MINT)
	slot_content.add_child(_button("Spin for salvage   ·   10", _spin, true, int(run.credits) < 10 or str(run.phase) != "loot"))
	_note(content, "Every spin gives a reward. If you get fewer than 10 credits back, you also get a common module.", GOLD)
	content.add_child(_button("Hide odds" if _show_odds else "View odds", func(): _show_odds = not _show_odds; refresh(), false, false, 32, "slot:odds"))
	if _show_odds:
		_note(content, "25%: common module\n20%: 5 credits + common module\n25%: 10 credits\n20%: 20 credits\n5%: 30 credits\n5%: sealed chest + 10 credits\n\nAverage return: 9.5 credits per 10-credit spin, plus gear or chests. Chest rewards still need fragments to open.")
	if str(run.phase) != "loot": _note(content, "Camp purchases and slots open after each wave.", GOLD)

func _mini_grid(content: VBoxContainer, heading: bool = true) -> void:
	var selected_family: int = int(run.towers[selected_cell].number) if run.towers.has(selected_cell) else 0
	if heading: _section(content, "MATCHING TOWERS" if selected_family > 0 else "YOUR TOWERS", "Gold: selected" if selected_family > 0 else "A inspects" if controller_mode else "Tap to inspect")
	var center: CenterContainer = CenterContainer.new()
	content.add_child(center)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	center.add_child(grid)
	for i in range(81):
		var cell: int = i
		var occupied: bool = run.towers.has(cell)
		var number: int = int(run.board[cell]) if run.board.size() > cell else 0
		var button: Button = TowerDropButton.new()
		button.module_dropped.connect(func(item_id): _act("equip_item", [cell, item_id]))
		button.text = str(number) if number > 0 else "·"
		button.set_meta("focus_id", "cell:" + str(cell))
		button.custom_minimum_size = Vector2(27, 27)
		button.add_theme_font_size_override("font_size", 13)
		button.focus_mode = Control.FOCUS_ALL if occupied else Control.FOCUS_NONE
		button.disabled = not occupied
		button.tooltip_text = "Row %d, column %d%s" % [cell / 9 + 1, cell % 9 + 1, " · select tower" if occupied else ""]
		var color: Color = FAMILY_COLORS[number] if occupied else MUTED.darkened(0.3)
		var affected: bool = occupied and number == selected_family
		var selected: bool = occupied and cell == selected_cell
		var bg: Color = color.darkened(0.53 if affected else 0.83) if occupied else Color("0b1a24")
		var border: Color = GOLD if selected else color if affected else LINE
		if occupied:
			button.tooltip_text += " · Tower %d%s" % [number, " · included in this upgrade" if affected else ""]
		elif number > 0:
			button.tooltip_text += " · printed clue, not a tower"
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, _style(bg.lightened(0.08) if state == "hover" else bg, TEXT if state == "focus" else border, 3, 3 if selected else 2 if affected else 1, 0))
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_disabled_color", Color("4d6670"))
		button.pressed.connect(func():
			selected_cell = cell
			cell_requested.emit(cell)
			if current_panel != "bag": current_panel = "tower"
			refresh()
		)
		grid.add_child(button)

func _open_chest(id) -> void:
	_ensure_loot_table()
	_loot_table.open_chest(id)

func _spin() -> void:
	var result: Dictionary = run.spin_slots()
	_message = ""
	if bool(result.get("ok", false)):
		_slot_result = result.duplicate(true)
		_slot_animated = false
	else: _message = str(result.get("message", ""))
	changed.emit(result)

func _act(method: String, args: Array = []) -> void:
	var result: Dictionary = run.callv(method, args)
	_message = str(result.get("message", ""))
	if method in ["equip_item", "swap_attachment"] and bool(result.get("ok", false)): _armed_id = ""
	changed.emit(result)

func _section(parent: VBoxContainer, title: String, detail: String = "") -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation",7)
	parent.add_child(row)
	var mark := ColorRect.new()
	mark.color = MINT.darkened(0.28)
	mark.custom_minimum_size = Vector2(3,11)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mark)
	var name_label: Label = _label(title, 11, MINT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(_label(detail, 11, MUTED))

func _note(parent: VBoxContainer, text_value: String, color: Color = MUTED) -> void:
	var label: Label = _label(text_value, 13, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text_value: String, action: Callable, primary: bool = false, disabled_value: bool = false, height: int = 42, focus_id: String = "") -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.set_meta("focus_id", focus_id if not focus_id.is_empty() else "button:" + text_value)
	button.custom_minimum_size.y = height
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.disabled = disabled_value
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", INK if primary else TEXT)
	button.add_theme_color_override("font_hover_color", INK if primary else TEXT)
	button.add_theme_color_override("font_pressed_color", INK if primary else TEXT)
	button.add_theme_color_override("font_focus_color", INK if primary else TEXT)
	button.add_theme_color_override("font_disabled_color", Color("667b84"))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var bg: Color = GOLD if primary else Color("152b36")
		var border: Color = Color("9c724b") if primary else Color("304955")
		if state == "hover":
			bg = bg.lightened(0.08)
			border = GOLD if primary else MINT.darkened(0.28)
		if state == "pressed": bg = bg.darkened(0.12)
		if state == "disabled":
			bg = Color("101e27")
			border = Color("21343e")
		var skin := _style(bg,border,6,1,6)
		skin.corner_detail = 1
		skin.border_width_bottom = 1 if state == "pressed" else 3
		button.add_theme_stylebox_override(state,skin)
	var focus := _style(Color.TRANSPARENT,MINT,6,2,6)
	focus.corner_detail = 1
	button.add_theme_stylebox_override("focus",focus)
	button.pressed.connect(action)
	return button

func _style(bg: Color, border: Color, radius: int, width: int, margin: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_corner_radius_all(radius)
	style.set_border_width_all(width)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

func _panel(border: Color) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var skin := _style(Color("101f29"),border,7,1,10)
	skin.corner_detail = 1
	skin.border_width_bottom = 3
	panel.add_theme_stylebox_override("panel",skin)
	return panel

func _icon(kind: String, color: Color, minimum: Vector2) -> Control:
	var icon: Control = Icon.new()
	icon.kind = kind
	icon.tint = color
	icon.custom_minimum_size = minimum
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL if minimum.x == 0 else Control.SIZE_SHRINK_CENTER
	return icon

func _stat(parent: HBoxContainer, title: String, value: String) -> void:
	var panel: PanelContainer = _panel(LINE)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_label(title, 9, MUTED))
	box.add_child(_label(value, 19, TEXT))

func _navigation_icon(kind: String, minimum: Vector2) -> Control:
	if kind == "tower": return _icon("power",GOLD,minimum)
	var icon := QuickIcon.new()
	icon.icon_kind = {"bag":"gear","loot":"chest","camp":"camp"}.get(kind,"gear")
	icon.custom_minimum_size = minimum
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _selection_style(control: Button, selected: bool, left_margin: int = 6) -> void:
	for state in ["normal","hover","pressed"]:
		var bg := Color("173a39") if selected else Color("101f2a")
		if state == "hover": bg = bg.lightened(0.06)
		if state == "pressed": bg = bg.darkened(0.08)
		var skin := _style(bg,MINT.darkened(0.22) if selected else LINE,4,1,5)
		skin.corner_detail = 1
		skin.border_width_bottom = 3 if selected else 1
		skin.content_margin_left = left_margin
		skin.content_margin_right = 4
		control.add_theme_stylebox_override(state,skin)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		control.add_theme_color_override(state,MINT if selected else MUTED)

func _style_scrollbar(bar: VScrollBar) -> void:
	var track := _style(Color("0a151e"),Color.TRANSPARENT,2,0,0)
	track.content_margin_left = 4
	track.content_margin_right = 4
	bar.add_theme_stylebox_override("scroll",track)
	for state in ["grabber","grabber_highlight","grabber_pressed"]:
		var handle := _style(Color("476569") if state == "grabber" else MINT.darkened(0.18),Color.TRANSPARENT,2,0,0)
		handle.content_margin_left = 4
		handle.content_margin_right = 4
		bar.add_theme_stylebox_override(state,handle)
