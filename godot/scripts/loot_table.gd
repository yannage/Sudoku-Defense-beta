class_name DefenseLootTable
extends Control
## The loot screen is a persistent scene, not a list rebuilt after every click.
## Economy commits once at the start; the opening/reveal is presentation only.
signal changed(result: Dictionary)
signal gear_requested(items: Array)

const ChestStage = preload("res://scripts/chest_stage.gd")
const CanvasChestStage = preload("res://scripts/chest_canvas.gd")
const RenderProfile = preload("res://scripts/render_profile.gd")
const Loot = preload("res://scripts/loot.gd")
const Icon = preload("res://scripts/voxel_icon.gd")
const ItemCard = preload("res://scripts/item_card.gd")
const PAGE_SIZE := 6
const TEXT := Color("edf7ef")
const MUTED := Color("9cb5bc")
const MINT := Color("83e7c1")

var run
var reduced_motion := false
var controller_mode := false
var reward: Dictionary = {}
var opening := false
var _page := 0
var _clock := 0.0
var _reveal_pop := 0.0
var _generation := 0
var _view: Control
var _title: Label
var _subtitle: Label
var _empty: Label
var _footer: Label
var _message := ""
var _cards: Array[Button] = []
var _stages: Array[Control] = []
var _reward_cards: Array[Control] = []
var _hero: Control
var _continue: Button
var _equip: Button
var _previous: Button
var _next: Button
var _buy: Button
var _page_label: Label
var _opening_stage: Control
var _opening_id := ""
var _sequence: Tween
var _focused_id := ""
var _shown_page_size := PAGE_SIZE
var _capacity_refresh_pending := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0,352)
	resized.connect(_layout)
	visibility_changed.connect(_visibility_changed)
	if run != null: refresh()

func setup(game_run, reduce_motion: bool = false) -> void:
	run = game_run
	reduced_motion = reduce_motion
	if is_inside_tree(): refresh()

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	for stage in _stages:
		if is_instance_valid(stage): stage.set_reduced_motion(value)
	if is_instance_valid(_hero): _hero.set_reduced_motion(value)
	queue_redraw()

func reset_for_run() -> void:
	_generation += 1
	if is_instance_valid(_sequence): _sequence.kill()
	opening = false
	reward.clear()
	_opening_id = ""
	_opening_stage = null
	_page = 0
	_message = ""
	refresh()

func _visibility_changed() -> void:
	# Native previews update only while this screen is visible.
	for stage in _stages:
		if is_instance_valid(stage) and stage.has_method("set_preview_active"):
			stage.set_preview_active(is_visible_in_tree())
	if is_instance_valid(_hero) and _hero.has_method("set_preview_active"):
		_hero.set_preview_active(is_visible_in_tree())

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_clock += delta
	queue_redraw()

func refresh() -> void:
	if run == null or not is_inside_tree(): return
	# A parent HUD refresh after spending fragments must not replace the chest
	# being opened or clear its rewards. Resize is handled without rebuilding.
	if opening or not reward.is_empty():
		_layout()
		return
	var owner: Control = get_viewport().gui_get_focus_owner()
	_focused_id = str(owner.get_meta("focus_id", "")) if is_instance_valid(owner) and is_ancestor_of(owner) else ""
	_clear_view()
	_title = _label("YOUR CHESTS",24,TEXT)
	_subtitle = _label("Select a chest to open it with fragments.",14,MUTED)
	_footer = _label("FRAGMENTS COME FROM DEFEATED ENEMIES",11,Color("7f9aa5"))
	_view.add_child(_title)
	_view.add_child(_subtitle)
	_view.add_child(_footer)
	var count: int = run.chests.size()
	_shown_page_size = _page_capacity()
	var pages: int = maxi(1,ceili(float(count)/_shown_page_size))
	_page = clampi(_page,0,pages-1)
	for index in range(_page*_shown_page_size,mini(count,(_page+1)*_shown_page_size)):
		_add_chest(run.chests[index])
	if count == 0:
		var stage: Control = _make_stage("common")
		stage.modulate = Color(0.70,0.80,0.85,0.72)
		_view.add_child(stage)
		stage.custom_minimum_size = Vector2.ZERO
		_hero = stage
		_empty = _label("No chests yet.\nDefeat enemies and clear waves to collect them.",18,MUTED)
		_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_view.add_child(_empty)
	if pages > 1:
		_previous = _button("‹ Previous",func(): _page -= 1; refresh(); _focus_after_page(),"loot:previous")
		_previous.disabled = _page == 0
		_next = _button("Next ›",func(): _page += 1; refresh(); _focus_after_page(),"loot:next")
		_next.disabled = _page >= pages-1
		_page_label = _label("%d / %d  ·  %d CHESTS" % [_page+1,pages,count],12,MUTED)
		_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_view.add_child(_previous)
		_view.add_child(_next)
		_view.add_child(_page_label)
	if str(run.phase) == "loot":
		var price: int = run.chest_price("common")
		_buy = _button("Buy a chest · %d credits" % price,_buy_chest,"buy:chest")
		_buy.disabled = int(run.credits) < price
		_buy.tooltip_text = "Buy a common chest. Opening it costs another 5 fragments."
		_view.add_child(_buy)
	if not _message.is_empty(): _subtitle.text = _message
	elif not str(run.phase) in ["solve","prep","loot","won"]:
		_subtitle.text = "Open your chests before or after battle."
	_layout()
	if not reduced_motion:
		for i in range(_cards.size()):
			var card: Control = _cards[i]
			card.pivot_offset = card.size*0.5
			card.scale = Vector2.ONE*0.92
			card.modulate.a = 0.0
			var arrival := card.create_tween().set_parallel(true)
			arrival.tween_property(card,"scale",Vector2.ONE,0.30).set_delay(i*0.035).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			arrival.tween_property(card,"modulate:a",1.0,0.18).set_delay(i*0.035)
	_restore_focus.call_deferred()

func _clear_view() -> void:
	if is_instance_valid(_view):
		remove_child(_view)
		_view.queue_free()
	_view = Control.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_view)
	_cards.clear()
	_stages.clear()
	_reward_cards.clear()
	_hero = null
	_empty = null
	_continue = null
	_equip = null
	_previous = null
	_next = null
	_buy = null
	_page_label = null
	_footer = null

func _make_stage(rarity: String) -> Control:
	var stage: Control = CanvasChestStage.new() if RenderProfile.uses_canvas() else ChestStage.new()
	stage.set_rarity(rarity)
	stage.set_reduced_motion(reduced_motion)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return stage

func _add_chest(data: Dictionary) -> void:
	var rarity: String = str(data.get("rarity","common"))
	var tint: Color = Loot.rarity_color(rarity)
	var id: String = str(data.id)
	var cost: int = int(data.get("cost",5))
	var unlocked: bool = int(run.fragments) >= cost
	var allowed: bool = str(run.phase) in ["solve","prep","loot","won"]
	var button: Button = _button("",func(): open_chest(id),"chest:"+id,tint)
	button.tooltip_text = "%s chest · %d fragments · %d item%s" % [rarity.capitalize(),cost,_reward_count(rarity),"s" if _reward_count(rarity)>1 else ""]
	button.set_meta("chest_id",id)
	button.disabled = not unlocked or not allowed
	_view.add_child(button)
	_cards.append(button)
	var stage: Control = _make_stage(rarity)
	button.add_child(stage)
	stage.custom_minimum_size = Vector2.ZERO
	stage.set_meta("chest_stage",true)
	stage.modulate.a = 1.0 if unlocked else 0.55
	_stages.append(stage)
	var rarity_label: Label = _label(rarity.to_upper(),13,tint)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.set_meta("part","rarity")
	button.add_child(rarity_label)
	var action: Label = _label("%d fragments · Open" % cost if unlocked else "%d / %d fragments" % [int(run.fragments),cost],16,TEXT if unlocked else MUTED)
	if not allowed: action.text = "Open after the wave"
	action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action.set_meta("part","action")
	button.add_child(action)
	var count: Label = _label("%d ITEM%s INSIDE" % [_reward_count(rarity),"S" if _reward_count(rarity)>1 else ""],10,Color(tint,0.7))
	count.set_meta("part","count")
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_child(count)
	button.mouse_entered.connect(func(): _chest_hover(button,true))
	button.mouse_exited.connect(func(): _chest_hover(button,false))
	button.focus_entered.connect(func(): _chest_hover(button,true))
	button.focus_exited.connect(func(): _chest_hover(button,false))

func _chest_hover(button: Button, active: bool) -> void:
	if opening or button.disabled: return
	var stage: Control = button.get_child(0)
	if not reduced_motion:
		stage.pivot_offset = stage.size*0.5
		stage.create_tween().tween_property(stage,"scale",Vector2.ONE*(1.06 if active else 1.0),0.14)

func open_chest(id: Variant) -> void:
	if run == null or opening or not reward.is_empty(): return
	var stage: Control
	var rarity := "common"
	for data in run.chests:
		if str(data.id) == str(id): rarity = str(data.rarity)
	for i in range(_cards.size()):
		if str(_cards[i].get_meta("chest_id","")) == str(id): stage = _stages[i]
	# Assign presentation state before emitting changed: the host synchronously
	# saves/refreshes on this signal. A second press cannot spend or grant twice.
	opening = true
	var result: Dictionary = run.open_chest(id)
	if not bool(result.get("ok",false)):
		opening = false
		_message = str(result.get("message",""))
		refresh()
		changed.emit(result)
		return
	reward = result.duplicate(true)
	_opening_id = str(id)
	_opening_stage = stage
	for card in _cards: card.disabled = true
	if is_instance_valid(_buy): _buy.disabled = true
	if is_instance_valid(_previous): _previous.disabled = true
	if is_instance_valid(_next): _next.disabled = true
	if is_instance_valid(_subtitle): _subtitle.text = "UNLOCKING " + rarity.to_upper() + " CHEST…"
	if is_instance_valid(stage): stage.open_chest()
	_generation += 1
	var generation: int = _generation
	_sequence = create_tween()
	_sequence.tween_interval(0.14 if reduced_motion else 0.76)
	_sequence.tween_callback(func():
		if generation != _generation: return
		opening = false
		_build_reveal()
	)
	changed.emit(result)

func _build_reveal() -> void:
	if reward.is_empty(): return
	_clear_view()
	var rarity: String = str(reward.get("rarity","common"))
	var tint: Color = Loot.rarity_color(rarity)
	var rewards: Array = reward.get("rewards",[])
	_title = _label("CHEST OPENED",26,TEXT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle = _label("%s CHEST  ·  %d ITEM%s RECOVERED" % [rarity.to_upper(),rewards.size(),"S" if rewards.size()!=1 else ""],12,tint)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_view.add_child(_title)
	_view.add_child(_subtitle)
	_hero = _make_stage(rarity)
	_view.add_child(_hero)
	_hero.custom_minimum_size = Vector2.ZERO
	_hero.show_opened()
	for item in rewards:
		if item is Dictionary: _add_reward_card(item)
	_footer = _label("Added to Gear. Equip modules or use boosts.",13,MUTED)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_view.add_child(_footer)
	_continue = _button("Back to the table",dismiss_reward,"loot:continue")
	_equip = _button("Equip new gear  →",_request_new_gear,"loot:equip",MINT)
	_view.add_child(_continue)
	_view.add_child(_equip)
	_equip.add_theme_stylebox_override("normal",_style(Color("83e7c1"),Color("a1ffdc"),1))
	_equip.add_theme_color_override("font_color",Color("102c29"))
	_reveal_pop = 1.0 if reduced_motion else 0.0
	_layout()
	if not reduced_motion:
		create_tween().tween_property(self,"_reveal_pop",1.0,0.44).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		for card in _reward_cards:
			card.pivot_offset = card.size*0.5
			card.scale = Vector2.ONE*0.84
			card.modulate.a = 0.0
			var tween := card.create_tween().set_parallel(true)
			tween.tween_property(card,"scale",Vector2.ONE,0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(card,"modulate:a",1.0,0.18)
	if is_visible_in_tree(): _apply_preferred_focus.call_deferred()

func _add_reward_card(item: Dictionary) -> void:
	var color: Color = Loot.rarity_color(str(item.get("rarity","common")))
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_meta("reward_item_id",str(item.get("id","")))
	card.add_theme_stylebox_override("panel",_style(Color("142b36"),Color(color,0.75),2))
	_view.add_child(card)
	_reward_cards.append(card)
	var body := Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(body)
	var icon: Control = Icon.new()
	icon.kind = str(item.get("kind","power"))
	icon.tint = Color(str(item.get("color","83e7c1")))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(icon)
	var name_label: Label = _label(ItemCard.effect_name(item),17,TEXT)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(name_label)
	var stat: Label = _label(ItemCard._short_stat(item),14,MINT)
	stat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(stat)
	var tag: Label = _label(str(item.get("rarity","common")).to_upper()+"  ·  "+("ONE USE" if str(item.get("type","")) == "consumable" else "TOWER MODULE"),10,color)
	body.add_child(tag)
	card.tooltip_text = str(item.get("name",""))+"\n"+Loot.description(item)

func dismiss_reward() -> void:
	if opening: return
	reward.clear()
	_opening_id = ""
	_message = ""
	refresh()
	_focus_after_page()

func _request_new_gear() -> void:
	if opening or reward.is_empty(): return
	# Rewards are already owned. Hand their identity to the bag so the player
	# sees this discovery, without equipping or using anything automatically.
	var earned: Array = reward.get("rewards",[]).duplicate(true)
	dismiss_reward()
	gear_requested.emit(earned)

func _buy_chest() -> void:
	if run == null or opening or not reward.is_empty(): return
	var result: Dictionary = run.buy_chest("common")
	_message = str(result.get("message",""))
	if bool(result.get("ok",false)): _page = maxi(0,ceili(float(run.chests.size())/_page_capacity())-1)
	refresh()
	changed.emit(result)

func _focus_after_page() -> void:
	_apply_preferred_focus.call_deferred()

func _apply_preferred_focus() -> void:
	if not is_inside_tree() or not is_visible_in_tree(): return
	var focus: Control = preferred_focus()
	if is_instance_valid(focus) and focus.is_inside_tree(): focus.grab_focus()

func preferred_focus() -> Control:
	if is_instance_valid(_equip): return _equip
	for card in _cards:
		if not card.disabled: return card
	if is_instance_valid(_buy) and not _buy.disabled: return _buy
	if is_instance_valid(_next) and not _next.disabled: return _next
	return null

func _restore_focus() -> void:
	if not is_visible_in_tree() or _focused_id.is_empty(): return
	for button in find_children("*","Button",true,false):
		if str(button.get_meta("focus_id","")) == _focused_id and not button.disabled:
			button.grab_focus()
			return

func _layout() -> void:
	if not is_instance_valid(_view): return
	var w: float = size.x
	var h: float = size.y
	var portrait: bool = w < 680
	var compact: bool = h < 440 and not portrait
	if not reward.is_empty() and not opening:
		_place(_title,Rect2(8,8,w-16,36))
		_place(_subtitle,Rect2(8,47,w-16,24))
		var hero_h: float = 72.0 if compact else clampf(h*0.25,100,168)
		_place(_hero,Rect2((w-240)*0.5,64,240,hero_h))
		var card_top: float = 66+hero_h
		var foot_h: float = 102 if portrait else 84
		var available: float = maxf(130,h-card_top-foot_h)
		var count: int = _reward_cards.size()
		for i in range(count):
			var card: Control = _reward_cards[i]
			if portrait:
				var card_h: float = minf(142,(available-10*(count-1))/maxi(1,count))
				_place(card,Rect2(12,card_top+i*(card_h+10),w-24,card_h))
			else:
				var card_w: float = minf(278,(w-32-14*(count-1))/maxi(1,count))
				var total: float = card_w*count+14*(count-1)
				_place(card,Rect2((w-total)*0.5+i*(card_w+14),card_top,card_w,minf(232,available)))
			_layout_reward(card,portrait or compact)
		_place(_footer,Rect2(12,h-foot_h+4,w-24,25))
		var button_y: float = h-50
		if portrait:
			_place(_continue,Rect2(12,button_y,w*0.44-18,44))
			_place(_equip,Rect2(w*0.44,button_y,w*0.56-12,44))
		else:
			_place(_continue,Rect2(w*0.5-240,button_y,214,44))
			_place(_equip,Rect2(w*0.5-14,button_y,254,44))
		return
	if _shown_page_size != _page_capacity() and not opening and not _capacity_refresh_pending:
		_capacity_refresh_pending = true
		_refresh_capacity.call_deferred()
	_place(_title,Rect2(16,6,w-32,34))
	_place(_subtitle,Rect2(16,43,w-32,40))
	var footer_space: float = 76 if is_instance_valid(_buy) else 34
	var pager_space: float = 46 if is_instance_valid(_previous) else 0
	var table_top: float = 90
	var table_h: float = maxf(130 if compact else 220,h-table_top-footer_space-pager_space)
	var columns: int = 2 if portrait else 3
	if _cards.size() <= 3 and not portrait: columns = maxi(1,_cards.size())
	var rows: int = maxi(1,ceili(float(_cards.size())/columns))
	var card_w: float = minf(290,(w-32-14*(columns-1))/columns)
	var card_h: float = minf(258,(table_h-12*(rows-1))/rows)
	var total: float = card_w*columns+14*(columns-1)
	for i in range(_cards.size()):
		var card: Button = _cards[i]
		_place(card,Rect2((w-total)*0.5+(i%columns)*(card_w+14),table_top+floori(float(i)/columns)*(card_h+12),card_w,card_h))
		_place(_stages[i],Rect2(8,3,card_w-16,maxf(54,card_h-70)))
		for child in card.get_children():
			if child is Label:
				var part: String = str(child.get_meta("part",""))
				var y: float = card_h-66 if part == "rarity" else card_h-43 if part == "action" else card_h-20
				_place(child,Rect2(4,y,card_w-8,22 if part != "count" else 18))
	if is_instance_valid(_empty):
		_place(_hero,Rect2(w*0.5-180,table_top+12,360,maxf(140,table_h*0.62)))
		_place(_empty,Rect2(20,table_top+table_h*0.68,w-40,72))
	if is_instance_valid(_previous):
		var y: float = h-footer_space-44
		_place(_previous,Rect2(16,y,125,38))
		_place(_next,Rect2(w-141,y,125,38))
		_place(_page_label,Rect2(145,y,w-290,38))
	_place(_footer,Rect2(16,h-28,w-32,24))
	if is_instance_valid(_buy): _place(_buy,Rect2(w*0.5-150,h-73,300,38))

func _page_capacity() -> int:
	return 3 if size.x >= 680 and size.y < 440 else PAGE_SIZE

func _refresh_capacity() -> void:
	_capacity_refresh_pending = false
	if opening or not reward.is_empty(): return
	refresh()

func _layout_reward(card: Control, portrait: bool) -> void:
	var body: Control = card.get_child(0)
	var w: float = card.size.x
	var h: float = card.size.y
	if portrait:
		var art: float = minf(70 if w < 350 else 100,h-8)
		_place(body.get_child(0),Rect2(5,4,art,art))
		_place(body.get_child(1),Rect2(art+12,10,w-art-28,38))
		_place(body.get_child(2),Rect2(art+12,48,w-art-28,38))
		_place(body.get_child(3),Rect2(art+12,h-23,w-art-28,20))
	else:
		var art_h: float = maxf(70,h-100)
		_place(body.get_child(0),Rect2(w*0.5-60,2,120,art_h))
		_place(body.get_child(1),Rect2(14,art_h+4,w-28,42))
		_place(body.get_child(2),Rect2(14,art_h+46,w-28,36))
		_place(body.get_child(3),Rect2(14,h-23,w-28,20))

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO,size)
	draw_style_box(_style(Color("091c26"),Color("294653"),1),rect)
	# A recessed, beveled salvage worktop: quiet texture leaves chest silhouettes clear.
	var top: float = 86.0
	var bottom: float = size.y-80.0
	draw_rect(Rect2(8,top,size.x-16,maxf(1,bottom-top)),Color("102936"))
	for line in range(12):
		var y: float = top+float(line)*42.0
		if y > bottom: break
		draw_line(Vector2(10,y),Vector2(size.x-10,y),Color("1a3540"),1)
	for side in [12.0,size.x-12.0]:
		draw_line(Vector2(side,top),Vector2(side,bottom),Color("3b5359"),2)
	for x in [19.0,size.x-19.0]:
		for y in [top+10,bottom-10]: draw_rect(Rect2(x-2,y-2,4,4),Color("67857e"))
	if not reward.is_empty():
		var tint: Color = Loot.rarity_color(str(reward.get("rarity","common")))
		var center := Vector2(size.x*0.5,164)
		var strength: float = 0.14 if reduced_motion else 0.12+sin(_clock*1.3)*0.025
		for ray in range(10):
			var angle: float = -PI+float(ray)*PI/9.0
			var length: float = 140.0+float(ray%3)*25.0
			var points := PackedVector2Array([center,center+Vector2(cos(angle-0.035),sin(angle-0.035))*length,center+Vector2(cos(angle+0.035),sin(angle+0.035))*length])
			draw_colored_polygon(points,Color(tint,strength))
		if not reduced_motion and not opening:
			for i in range(20):
				var t: float = fposmod(_clock*0.16+float(i)*0.061,1.0)
				var p := Vector2(24+fposmod(float(i)*73.0,maxf(1,size.x-48)),size.y*(1.0-t))
				draw_rect(Rect2(p,Vector2(3,3)),Color(tint,sin(t*PI)*0.24*_reveal_pop))

static func _reward_count(rarity: String) -> int:
	return 3 if rarity == "legendary" else 2 if rarity in ["rare","epic"] else 1

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(value: String, callback: Callable, focus_id: String, color: Color = Color("7697a3")) -> Button:
	var button := Button.new()
	button.text = value
	button.set_meta("focus_id",focus_id)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size",15)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var tint: Color = color if state in ["hover","pressed","focus"] else Color(color,0.32)
		var fill: Color = Color("173442") if state in ["hover","focus"] else Color("0d222e")
		if state == "disabled": fill = Color("0c202a")
		button.add_theme_stylebox_override(state,_style(fill,tint,2 if state == "focus" else 1))
	button.add_theme_color_override("font_color",TEXT)
	button.pressed.connect(callback)
	return button

func _style(fill: Color, outline: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(width)
	style.set_corner_radius_all(9)
	style.shadow_color = Color(0,0,0,0.28)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0,4)
	return style

func _place(control: Control, rect: Rect2) -> void:
	if not is_instance_valid(control): return
	control.position = rect.position
	control.size = rect.size
