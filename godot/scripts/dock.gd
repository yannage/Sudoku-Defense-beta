class_name DefenseDock
extends Control

signal changed(result: Dictionary)
signal closed()
signal cell_requested(cell: int)
signal item_armed(item_id: String)
signal family_preview_requested(number: int)

const Card = preload("res://scripts/item_card.gd")
const Icon = preload("res://scripts/voxel_icon.gd")
const Loot = preload("res://scripts/loot.gd")
const ChestStage = preload("res://scripts/chest_stage.gd")
const CanvasChestStage = preload("res://scripts/chest_canvas.gd")
const RenderProfile = preload("res://scripts/render_profile.gd")
const INK: Color = Color("081923")
const PANEL: Color = Color("0d202c")
const LINE: Color = Color("28434e")
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
	if _portrait:
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
	_shell.add_theme_stylebox_override("panel", _style(PANEL, LINE, 14, 1, 16))
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
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var top: HBoxContainer = HBoxContainer.new()
	_body.add_child(top)
	var names: Dictionary = {"tower":"TOWER WORKSHOP", "bag":"YOUR LOADOUT", "loot":"SEALED CACHES", "camp":"BETWEEN SIEGES"}
	var heading: Label = _label(str(names.get(current_panel, "LOADOUT")), 18, TEXT)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	var close_button: Button = _button("B" if controller_mode else "X", close_panel, false, false, 34, "close")
	close_button.custom_minimum_size = Vector2(34, 34)
	close_button.tooltip_text = "Close panel · B / Escape"
	top.add_child(close_button)
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	_body.add_child(tabs)
	for tab in ["tower", "bag", "loot", "camp"]:
		var tab_kind: String = str(tab)
		var text_value: String = str({"tower":"Tower", "bag":"Bag", "loot":"Loot", "camp":"Camp"}[tab_kind])
		var tab_button: Button = _button(text_value, func(): open_panel(tab_kind, selected_cell), tab_kind == current_panel, false, 32, "tab:" + tab_kind)
		tab_button.add_theme_font_size_override("font_size", 12)
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tab_button)
		if tab_kind == current_panel: _focus_target = tab_button
	var money: HBoxContainer = HBoxContainer.new()
	_body.add_child(money)
	var credits: Label = _label("%d CREDITS" % int(run.credits), 13, GOLD)
	credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money.add_child(credits)
	money.add_child(_label("%d FRAGMENTS" % int(run.fragments), 12, Color("b6a4ed")))
	if not _message.is_empty():
		var note: Label = _label(_message, 13, MINT)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(note)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	_scroll.add_child(content)
	match current_panel:
		"tower": _tower_panel(content)
		"bag": _bag_panel(content)
		"loot": _loot_panel(content)
		"camp": _camp_panel(content)
	if _portrait: _apply_touch_sizes(_body)
	_apply_layout()
	_scroll.set_deferred("scroll_vertical", old_scroll)
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
		if not candidate.disabled and candidate.focus_mode != Control.FOCUS_NONE:
			controls.append(candidate)
	return controls

func _apply_touch_sizes(node: Node) -> void:
	# A portrait canvas is 600 logical pixels wide; use larger type and touch
	# targets instead of scaling the desktop sidebar into a phone-sized strip.
	if node is Label or node is Button:
		var base_font: int = node.get_theme_font_size("font_size")
		node.add_theme_font_size_override("font_size", maxi(20, roundi(base_font * 1.5)))
	if node is TowerDropButton:
		node.custom_minimum_size = Vector2(54, 54)
	elif node is Button:
		node.custom_minimum_size.y = maxf(68, node.custom_minimum_size.y * 1.5)
		if str(node.get_meta("focus_id", "")) == "close": node.custom_minimum_size.x = 68
	for child in node.get_children():
		_apply_touch_sizes(child)

func _tower_panel(content: VBoxContainer) -> void:
	if not run.towers.has(selected_cell):
		_note(content, "Choose one of your growing towers on the board or the mini grid.")
		_mini_grid(content)
		return
	var tower: Dictionary = run.towers[selected_cell]
	var number: int = int(tower.number)
	var stats: Dictionary = run.tower_stats(selected_cell)
	var title_row: HBoxContainer = HBoxContainer.new()
	content.add_child(title_row)
	var icon: Control = _icon("power", FAMILY_COLORS[number], Vector2(46, 52))
	title_row.add_child(icon)
	var title_box: VBoxContainer = VBoxContainer.new()
	title_row.add_child(title_box)
	title_box.add_child(_label("Seed %d  ·  Level %d" % [number, int(stats.get("level", 1))], 23, TEXT))
	title_box.add_child(_label("ROW %d / COLUMN %d" % [selected_cell / 9 + 1, selected_cell % 9 + 1], 11, MUTED))
	var stats_row: HBoxContainer = HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 6)
	content.add_child(stats_row)
	_stat(stats_row, "DAMAGE", "%.0f" % float(stats.get("damage", 0)))
	_stat(stats_row, "FIRE / SEC", "%.1f" % (1.0 / maxf(0.05, float(stats.get("interval", 1)))))
	_stat(stats_row, "RANGE", "%.1f" % float(stats.get("range", 0)))
	var cost: int = int(run.upgrade_cost(selected_cell))
	var cell: int = selected_cell
	content.add_child(_button("Upgrade this tower   ·   %d" % cost, func(): _act("upgrade_tower", [cell]), true, int(run.credits) < cost, 42, "upgrade:tower"))
	var family_cost: int = int(run.family_upgrade_cost(number))
	var family_count: int = _family_tower_count(number)
	_section(content, "SEED %d FAMILY" % number, "LEVEL %d → %d" % [int(run.family_levels[number]), int(run.family_levels[number]) + 1])
	var family_button: Button = _button("Upgrade all %ds · %d %s\n%d credits" % [number, family_count, "tower" if family_count == 1 else "towers", family_cost], func(): _act("upgrade_family", [number]), false, int(run.credits) < family_cost, 58, "upgrade:family")
	family_button.tooltip_text = "Improves all %d planted seed %d towers and every %d you plant later. Printed Sudoku clues are not towers." % [family_count, number, number]
	family_button.mouse_entered.connect(func(): _preview_family(number, false, true))
	family_button.mouse_exited.connect(func(): _preview_family(number, false, false))
	family_button.focus_entered.connect(func(): _preview_family(number, true, true))
	family_button.focus_exited.connect(func(): _preview_family(number, true, false))
	content.add_child(family_button)
	_note(content, "Highlighted: your %ds. Future %ds inherit this level." % [number, number], FAMILY_COLORS[number])
	_mini_grid(content)
	var attachments: Array = tower.get("attachments", [])
	_section(content, "ATTACHMENT STACK", "%d / 5 slots" % attachments.size())
	for i in range(5):
		var slot: int = i
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 7)
		content.add_child(row)
		var slot_label: Label = _label("%02d" % (i + 1), 13, MINT if i < attachments.size() else MUTED)
		slot_label.custom_minimum_size.x = 22
		row.add_child(slot_label)
		if i < attachments.size():
			var item: Dictionary = attachments[i]
			var item_text: VBoxContainer = VBoxContainer.new()
			item_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(item_text)
			item_text.add_child(_label(str(Loot.NAMES.get(str(item.get("kind", "")), "Attachment")), 14, Loot.rarity_color(str(item.get("rarity", "common")))))
			item_text.add_child(_label(Card._short_stat(item), 11, MUTED))
			var remove_button: Button = _button("-", func(): _act("unequip_item", [cell, slot]), false, false, 32, "slot:" + str(slot))
			remove_button.custom_minimum_size.x = 32
			remove_button.tooltip_text = "Return attachment to inventory"
			row.add_child(remove_button)
		else:
			var empty: Button = _button("Empty · add attachment", func(): open_panel("bag", cell), false, false, 32, "slot:" + str(slot))
			empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			empty.add_theme_font_size_override("font_size", 12)
			row.add_child(empty)
	content.add_child(_button("Open bag & attach", func(): open_panel("bag", cell), true))

func _bag_panel(content: VBoxContainer) -> void:
	_note(content, "A selects a module. Choose its tower, then A to attach. LB / RB changes tabs." if controller_mode else "Drag a module onto a tower. Or select a module, then select its tower.")
	if run.towers.has(selected_cell):
		var tower: Dictionary = run.towers[selected_cell]
		var count: int = tower.get("attachments", []).size()
		_section(content, "SELECTED: SEED %d" % int(tower.number), "%d / 5 slots" % count)
		if not _armed_id.is_empty():
			var cell: int = selected_cell
			var id: String = _armed_id
			content.add_child(_button("Attach selected module", func(): _act("equip_item", [cell, id]); _armed_id = "", true, count >= 5))
	else:
		_note(content, "Plant a correct answer to grow your first tower.", GOLD)
	var attachments: Array = []
	var consumables: Array = []
	for item in run.items:
		if str(item.get("type", "")) == "consumable": consumables.append(item)
		else: attachments.append(item)
	_section(content, "MODULES", str(attachments.size()))
	if attachments.is_empty(): _note(content, "No loose modules. Open caches or visit camp to collect more.")
	for item in attachments:
		var data: Dictionary = item
		var card: Button = Card.new()
		card.configure(data, str(data.id) == _armed_id, controller_mode)
		card.pressed.connect(func():
			_armed_id = str(data.id)
			_message = "Choose a tower, then A to attach." if controller_mode else "Select a tower on the board to attach."
			item_armed.emit(_armed_id)
			refresh()
		)
		content.add_child(card)
	if not consumables.is_empty():
		_section(content, "QUICK USE", "One charge each")
		for item in consumables:
			var data: Dictionary = item
			var card: Button = Card.new()
			card.configure(data, false, controller_mode)
			card.pressed.connect(func(): _act("use_item", [data.id]))
			content.add_child(card)
	_section(content, "EMERGENCY SEEDS", "6 credits each")
	var seed_grid: GridContainer = GridContainer.new()
	seed_grid.columns = 3
	seed_grid.add_theme_constant_override("h_separation", 5)
	seed_grid.add_theme_constant_override("v_separation", 5)
	content.add_child(seed_grid)
	for seed_number in range(1,10):
		var number: int = seed_number
		var buy: Button = _button("%d  ·  ×%d" % [number,int(run.inventory[number])], func(): _act("buy_seed", [number]), false, int(run.credits)<6, 36, "seed:" + str(number))
		buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buy.tooltip_text = "Buy one reserve seed %d for 6 credits" % number
		seed_grid.add_child(buy)
	_section(content, "TOWER SELECTOR", "A chooses a tower" if controller_mode else "Tap a planted square")
	_mini_grid(content, false)

func _loot_panel(content: VBoxContainer) -> void:
	if not _reward.is_empty():
		_reward_view(content)
		return
	_note(content, "Enemies drop energy fragments. Spend them to unlock the gear inside each cache.")
	if run.chests.is_empty():
		var empty_icon: Control = _icon("chest", Color("7897a7"), Vector2(0, 105))
		content.add_child(empty_icon)
		_note(content, "No sealed caches yet. Win a siege to earn your next drop.")
	for chest in run.chests:
		var data: Dictionary = chest
		var rarity: String = str(data.get("rarity", "common"))
		var color: Color = Loot.rarity_color(rarity)
		var panel: PanelContainer = _panel(color.darkened(0.75))
		content.add_child(panel)
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 7)
		panel.add_child(box)
		var row: HBoxContainer = HBoxContainer.new()
		box.add_child(row)
		row.add_child(_icon("chest", color, Vector2(58, 58)))
		var text_box: VBoxContainer = VBoxContainer.new()
		row.add_child(text_box)
		text_box.add_child(_label(rarity.capitalize() + " cache", 18, color))
		text_box.add_child(_label("%d fragments to unlock" % int(data.get("cost", 5)), 12, MUTED))
		var can_open: bool = str(run.phase) in ["solve", "prep", "loot", "won"]
		box.add_child(_button("Crack it open   ·   %d" % int(data.get("cost", 5)), func(): _open_chest(data.id), true, int(run.fragments) < int(data.get("cost", 5)) or not can_open, 42, "chest:" + str(data.id)))
	if not str(run.phase) in ["solve", "prep", "loot", "won"]:
		_note(content, "Open caches before or after a siege.", GOLD)
	if str(run.phase) == "loot":
		_section(content, "SUPPLY CACHE", "Optional purchase")
		var price: int = int(run.chest_price("common"))
		content.add_child(_button("Buy common cache   ·   %d" % price, func(): _act("buy_chest", ["common"]), false, int(run.credits) < price, 42, "buy:chest"))

func _reward_view(content: VBoxContainer) -> void:
	var rarity: String = str(_reward.get("rarity", "common"))
	var color: Color = Loot.rarity_color(rarity)
	var hero: PanelContainer = _panel(color.darkened(0.76))
	content.add_child(hero)
	var box: VBoxContainer = VBoxContainer.new()
	hero.add_child(box)
	var label: Label = _label(rarity.to_upper() + " CACHE OPENED", 17, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var icon: Control = CanvasChestStage.new() if RenderProfile.uses_canvas() else ChestStage.new()
	icon.custom_minimum_size = Vector2(0, 180)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(icon)
	icon.custom_minimum_size = Vector2(220, 180)
	icon.set_rarity(rarity)
	icon.open_chest.call_deferred()
	var rewards: Array = _reward.get("rewards", _reward.get("items", []))
	for item in rewards:
		if item is Dictionary:
			var card: Button = Card.new()
			card.configure(item, false, controller_mode)
			card.pressed.connect(func(): open_panel("bag", selected_cell))
			content.add_child(card)
	_note(content, "Your new gear is already in the bag. Equip it to shape your next defense.", MINT)
	content.add_child(_button("Equip your new gear", func(): _reward.clear(); open_panel("bag", selected_cell), true))
	content.add_child(_button("Back to caches", func(): _reward.clear(); refresh()))
	if not _reveal_animated:
		_reveal_animated = true
		icon.pivot_offset = Vector2(130, 90)
		icon.scale = Vector2(0.35, 0.35)
		icon.modulate.a = 0.0
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(icon, "scale", Vector2.ONE, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(icon, "modulate:a", 1.0, 0.3)

func _camp_panel(content: VBoxContainer) -> void:
	_note(content, "Permanent improvements last for this run. Equipment returns to your bag between maps.")
	_section(content, "RUN UPGRADES", "Build your advantage")
	var definitions: Array[Dictionary] = [
		{"id":"power", "name":"Root reactor", "detail":"Stronger bolts across every tower", "icon":"power"},
		{"id":"salvage", "name":"Salvage drone", "detail":"Improve rewards from defeated enemies", "icon":"rapid"},
		{"id":"vitality", "name":"Living core", "detail":"More core health for future sieges", "icon":"repair"}
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
		box.add_child(_label(str(entry.name) + "  ·  Lv %d" % level, 16, TEXT))
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
		_note(slot_content, str(_slot_result.get("message", _slot_result.get("label", "Reward added to your bag."))), MINT)
	slot_content.add_child(_button("Spin for salvage   ·   10", _spin, true, int(run.credits) < 10 or str(run.phase) != "loot"))
	_note(content, "Below-stake results always include a usable module. No empty spins.", GOLD)
	content.add_child(_button("Hide odds" if _show_odds else "View the fixed odds", func(): _show_odds = not _show_odds; refresh(), false, false, 32, "slot:odds"))
	if _show_odds:
		_note(content, "25% module · 20% 5 credits + module\n25% stake back · 20% double · 5% triple\n5% cache + stake back\n\nAverage credit return: 95%. Gear and caches are extra. Credits stay inside this game.")
	if str(run.phase) != "loot": _note(content, "The camp opens after you survive a siege.", GOLD)

func _mini_grid(content: VBoxContainer, heading: bool = true) -> void:
	var selected_family: int = int(run.towers[selected_cell].number) if run.towers.has(selected_cell) else 0
	if heading: _section(content, "FAMILY TARGETS" if selected_family > 0 else "YOUR TOWERS", "Gold: selected" if selected_family > 0 else "A inspects" if controller_mode else "Tap to inspect")
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
			button.tooltip_text += " · Seed %d%s" % [number, " · included in family upgrade" if affected else ""]
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
	var result: Dictionary = run.open_chest(id)
	_message = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		_reward = result.duplicate(true)
		_reveal_animated = false
	changed.emit(result)

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
	if method == "equip_item" and bool(result.get("ok", false)): _armed_id = ""
	changed.emit(result)

func _section(parent: VBoxContainer, title: String, detail: String = "") -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
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
	button.add_theme_color_override("font_disabled_color", Color("607985"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var bg: Color = MINT if primary else Color("18303c")
		if state == "hover": bg = bg.lightened(0.10)
		if state == "pressed": bg = bg.darkened(0.12)
		if state == "disabled": bg = Color("12232c")
		button.add_theme_stylebox_override(state, _style(bg, TEXT if state == "focus" else LINE, 8, 2 if state == "focus" else 1, 6))
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
	panel.add_theme_stylebox_override("panel", _style(Color("102530"), border, 9, 1, 10))
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
