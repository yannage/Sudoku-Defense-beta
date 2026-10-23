class_name DefenseRun
extends RefCounted

const Sudoku = preload("res://scripts/sudoku.gd")
const Loot = preload("res://scripts/loot.gd")
const COLORS: Array[String] = ["6de8ff", "a4c7ff", "c6a0ff", "ffae68", "fb86c3", "9be878", "ffe188", "bb9bff", "dec3ed"]
const DIFFICULTIES: Dictionary = {
	"easy":{"clues":48, "duration":150.0, "hp":0.72, "speed":0.85, "count":0.85, "reward":0.9},
	"medium":{"clues":36, "duration":120.0, "hp":1.0, "speed":1.0, "count":1.0, "reward":1.0},
	"hard":{"clues":27, "duration":100.0, "hp":1.3, "speed":1.1, "count":1.18, "reward":1.25}
}
const CHEST_PRICES: Dictionary = {"common":30,"uncommon":50,"rare":90,"epic":160,"legendary":280}

var phase: String = "solve"
var round_no: int = 1
var max_rounds: int = 50
var mode: String = "campaign"
var puzzle_difficulty: String = "easy"
var combat_difficulty: String = "easy"
var seed_value: int = 1
var board: Array[int] = []
var solution: Array[int] = []
var givens: Array[bool] = []
var towers: Dictionary = {}
var enemies: Array[Dictionary] = []
var route: Array[Vector2] = []
var recent_moves: Array[int] = []
var credits: int = 40
var fragments: int = 0
var health: float = 30.0
var max_health: float = 30.0
var score: int = 0
var timer: float = 150.0
var kills: int = 0
var spawned: int = 0
var spawn_total: int = 0
var items: Array[Dictionary] = []
var chests: Array[Dictionary] = []
var family_levels: Array[int] = []
var inventory: Array[int] = []
var passives: Dictionary = {"power":0, "salvage":0, "vitality":0}
var active_effects: Array[Dictionary] = []
var corruption: int = 0
var combo: int = 0
var round_solved: int = 0
var route_length: float = 1.0
var solve_duration: float = 150.0
var last_wave_bonus: int = 0
var battle_time: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_id: int = 1
var _events: Array[Dictionary] = []
var _route_distances: Array[float] = []
var _spawn_clock: float = 0.0
var _settled: bool = false
var _rewarded_units: Array[String] = []
var _locked_puzzle: String = "easy"
var _locked_combat: String = "easy"
var _hinting: bool = false

func new_run(run_seed: int, options: Dictionary = {}) -> void:
	seed_value = run_seed
	rng.seed = run_seed
	mode = str(options.get("mode", "campaign"))
	if not ["campaign","freeplay","locked"].has(mode): mode = "campaign"
	puzzle_difficulty = _difficulty(str(options.get("puzzle_difficulty", options.get("sudokuDifficulty", "easy"))))
	combat_difficulty = _difficulty(str(options.get("combat_difficulty", options.get("combatDifficulty", "easy"))))
	_locked_puzzle = puzzle_difficulty
	_locked_combat = combat_difficulty
	max_rounds = 1 if mode == "freeplay" else 50
	round_no = 1
	credits = 40
	fragments = 0
	health = 30.0
	max_health = 30.0
	score = 0
	kills = 0
	_next_id = 1
	family_levels.clear()
	inventory.clear()
	for i in range(10):
		family_levels.append(1)
		inventory.append(1)
	passives = {"power":0, "salvage":0, "vitality":0}
	items.clear()
	chests.clear()
	active_effects.clear()
	_events.clear()
	for kind in ["rapid", "electric", "frost", "overclock"]:
		items.append(Loot.make_item(rng, "common", 1, _id(), kind))
	_new_board()

func _difficulty(value: String) -> String:
	return value if DIFFICULTIES.has(value) else "easy"

func _id() -> int:
	var result: int = _next_id
	_next_id += 1
	return result

func _new_board() -> void:
	var puzzle: Dictionary = Sudoku.make_puzzle(seed_value + round_no * 7919, puzzle_difficulty)
	board.assign(puzzle.board)
	solution.assign(puzzle.solution)
	givens.assign(puzzle.givens)
	phase = "solve"
	solve_duration = float(DIFFICULTIES[puzzle_difficulty].duration)
	timer = solve_duration
	towers.clear()
	enemies.clear()
	recent_moves.clear()
	_rewarded_units.clear()
	corruption = 0
	combo = 0
	round_solved = 0
	spawned = 0
	spawn_total = 0
	battle_time = 0.0
	_settled = false
	_build_route()
	_emit("phase", {"phase":phase,"text":"Round %d · plant your defense" % round_no})

func _emit(type: String, data: Dictionary = {}) -> void:
	var event: Dictionary = data.duplicate()
	event.type = type
	_events.append(event)
	if _events.size() > 600:
		_events.pop_front()

func drain_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = _events
	_events = []
	return result

func _ok(message: String, extras: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok":true,"message":message}
	result.merge(extras, true)
	return result

func _fail(message: String, cell: int = -1) -> Dictionary:
	_emit("invalid", {"text":message,"cell":cell,"color":Color("ff7289")})
	return {"ok":false,"message":message}

func cell_position(cell: int) -> Vector2:
	return Vector2(cell % 9, cell / 9)

func color_for(number: int) -> Color:
	return Color(COLORS[clampi(number - 1, 0, 8)])

func candidates(cell: int) -> Array[int]:
	return Sudoku.candidates(board, cell)

func place(cell: int, number: int) -> Dictionary:
	if cell < 0 or cell >= 81 or number < 1 or number > 9:
		return _fail("Choose a square and a number.")
	if phase != "solve" and phase != "battle":
		return _fail("Plant during solve or battle.", cell)
	if board[cell] != 0:
		return _fail("Printed clues stay fixed." if givens[cell] else "Select this tower to upgrade it.", cell)
	var correct: bool = solution[cell] == number
	var illegal: bool = not correct or not Sudoku.legal(board, cell, number)
	if phase == "solve" and illegal:
		combo = 0
		return _fail("That number does not solve this square. Try the candidate notes.", cell)
	if phase == "battle":
		if inventory[number] <= 0: return _fail("Buy a reserve seed for 6 credits first.", cell)
		inventory[number] -= 1
	board[cell] = number
	towers[cell] = {"id":_id(),"cell":cell,"number":number,"illegal":illegal,"level":1,"attachments":[],"growth":0.0,"cooldown":rng.randf_range(0.0,0.20),"aim":cell_position(cell) + Vector2(0,-1)}
	_emit("plant", {"cell":cell,"pos":cell_position(cell),"number":number,"illegal":illegal,"color":color_for(number),"text":"Emergency seed" if illegal else "Seed planted"})
	if illegal:
		corruption += 1
	else:
		round_solved += 1
		recent_moves.append(cell)
		if recent_moves.size() > 12: recent_moves.pop_front()
		if not _hinting:
			combo += 1
			var earned: int = 3 + mini(3, (combo - 1) / 3) + (1 if puzzle_difficulty == "hard" else 0)
			credits += earned
			score += 100 + mini(300, (combo - 1) * 25)
			_emit("reward", {"cell":cell,"pos":cell_position(cell),"text":"+%d credits" % earned,"color":Color("ffe188")})
		else:
			combo = 0
		_check_units(cell, not _hinting)
		if phase == "solve": _build_route()
	return _ok("Emergency tower planted. Corruption strengthens the remaining enemies." if illegal else "Seed planted. Select it to add modules or upgrade.", {"cell":cell,"illegal":illegal})

func _check_units(cell: int, award: bool) -> void:
	var row: int = cell / 9
	var col: int = cell % 9
	var box: int = (row / 3) * 3 + col / 3
	var units: Dictionary = {"r%d" % row:[], "c%d" % col:[], "b%d" % box:[]}
	for i in range(9):
		units["r%d" % row].append(row * 9 + i)
		units["c%d" % col].append(i * 9 + col)
		units["b%d" % box].append(((box / 3) * 3 + i / 3) * 9 + (box % 3) * 3 + i % 3)
	for key: String in units:
		if _rewarded_units.has(key): continue
		var complete: bool = true
		for index: int in units[key]:
			if board[index] != solution[index]: complete = false
		if complete:
			_rewarded_units.append(key)
			if award:
				credits += 8
				score += 300
				_emit("reward", {"cell":cell,"pos":cell_position(cell),"text":"Unit complete · +8","color":Color("ffe188")})

func hint(cell: int = -1) -> Dictionary:
	if phase != "solve": return _fail("Hints are available during solve.")
	if credits < 6: return _fail("A hint costs 6 credits.")
	if cell < 0 or cell >= 81 or board[cell] != 0:
		cell = -1
		var fewest: int = 10
		for i in range(81):
			if board[i] == 0:
				var count: int = candidates(i).size()
				if count < fewest:
					cell = i
					fewest = count
	if cell < 0: return _fail("The grid is complete.")
	credits -= 6
	_hinting = true
	var result: Dictionary = place(cell, solution[cell])
	_hinting = false
	result.message = "Hint planted for 6 credits. No solve reward."
	result.number = solution[cell]
	return result

func advance_phase() -> Dictionary:
	if phase == "solve":
		phase = "prep"
		timer = 0.0
		_build_route()
		_emit("phase", {"phase":phase,"text":"War prep · stack your modules"})
		return _ok("Equip modules and upgrade towers, then launch the wave.")
	if phase == "prep":
		phase = "battle"
		timer = 0.0
		spawned = 0
		spawn_total = int(wave_stats().count)
		_spawn_clock = 0.6
		battle_time = 0.0
		enemies.clear()
		_emit("phase", {"phase":phase,"text":"DEFEND THE GRID","color":Color("ffae68")})
		return _ok("Wave launched. Emergency seeds can bend Sudoku rules.")
	if phase == "loot": return next_round()
	return _fail("Finish the current wave first.")

func next_round(options: Dictionary = {}) -> Dictionary:
	if phase != "loot": return _fail("Clear the wave before starting another map.")
	if round_no >= max_rounds: return _fail("This run is complete.")
	var next_puzzle: String = _difficulty(str(options.get("puzzle_difficulty", options.get("sudokuDifficulty", puzzle_difficulty))))
	var next_combat: String = _difficulty(str(options.get("combat_difficulty", options.get("combatDifficulty", combat_difficulty))))
	if mode == "locked" and (next_puzzle != _locked_puzzle or next_combat != _locked_combat):
		return _fail("Locked In keeps your starting difficulties for all 50 rounds.")
	for tower: Dictionary in towers.values():
		for item: Dictionary in tower.attachments: items.append(item)
	puzzle_difficulty = next_puzzle
	combat_difficulty = next_combat
	round_no += 1
	_new_board()
	return _ok("Round %d. All equipped modules returned to your bag." % round_no)

func buy_seed(number: int) -> Dictionary:
	if not ["solve","prep","battle","loot"].has(phase): return _fail("Start a new run to buy seeds.")
	if number < 1 or number > 9: return _fail("Choose a seed from 1 to 9.")
	if credits < 6: return _fail("A reserve seed costs 6 credits.")
	credits -= 6
	inventory[number] += 1
	return _ok("Seed %d reserve added. Plant it during battle." % number)

func tower_stats(cell: int) -> Dictionary:
	if not towers.has(cell): return {}
	var tower: Dictionary = towers[cell]
	var effects: Dictionary = {}
	for item: Dictionary in tower.attachments:
		var kind: String = str(item.kind)
		effects[kind] = float(effects.get(kind, 0.0)) + float(item.power)
	var level: int = int(tower.level) + family_levels[int(tower.number)] - 1
	var damage: float = 9.0 * (1.0 + 0.32 * (level - 1)) * (1.0 + 0.25 * float(effects.get("power",0.0))) * (1.0 + 0.09 * int(passives.power))
	if bool(tower.illegal): damage *= 0.84
	if _has_effect("overcharge"): damage *= 1.6
	var interval: float = 0.72 / (1.0 + 0.20 * float(effects.get("rapid",0.0)))
	if _has_effect("overclock"): interval *= 0.5
	return {"level":level,"damage":damage,"interval":interval,"cooldown":interval,"range":minf(4.75,2.4 + 0.28 * float(effects.get("range",0.0))),"effects":effects,"slots_used":tower.attachments.size(),"attack_speed":1.0 / interval}

func upgrade_cost(cell: int) -> int:
	if not towers.has(cell): return 0
	return roundi(12.0 + 10.0 * pow(float(towers[cell].level), 1.25))

func family_upgrade_cost(number: int) -> int:
	if number < 1 or number > 9: return 0
	return roundi(24.0 + 20.0 * pow(float(family_levels[number]), 1.3))

func upgrade_tower(cell: int) -> Dictionary:
	if not towers.has(cell): return _fail("Select a planted tower.",cell)
	if not ["solve","prep","battle","loot"].has(phase): return _fail("Upgrade during an active run.")
	var cost: int = upgrade_cost(cell)
	if credits < cost: return _fail("Need %d credits to upgrade this tower." % cost,cell)
	credits -= cost
	towers[cell].level += 1
	_emit("upgrade", {"cell":cell,"pos":cell_position(cell),"color":color_for(towers[cell].number),"text":"LEVEL %d" % int(tower_stats(cell).level)})
	return _ok("Tower upgraded. Damage increased by one level.",{"cost":cost})

func upgrade_family(number: int) -> Dictionary:
	if number < 1 or number > 9: return _fail("Choose a number family.")
	if not ["solve","prep","battle","loot"].has(phase): return _fail("Upgrade during an active run.")
	var cost: int = family_upgrade_cost(number)
	if credits < cost: return _fail("Need %d credits to upgrade every %d." % [cost,number])
	credits -= cost
	family_levels[number] += 1
	_emit("upgrade", {"number":number,"color":color_for(number),"text":"ALL %ds · LEVEL %d" % [number,family_levels[number]]})
	return _ok("Every current and future %d gains a level for this run." % number,{"cost":cost})

func _gear_phase() -> bool:
	return ["solve","prep","battle","loot","won"].has(phase)

func equip_item(cell: int, item_id: Variant) -> Dictionary:
	if not _gear_phase(): return _fail("Equip modules during an active run.")
	if not towers.has(cell): return _fail("Choose a planted tower.",cell)
	var index: int = _item_index(item_id)
	if index < 0 or str(items[index].type) != "attachment": return _fail("Choose an attachment from your bag.")
	if towers[cell].attachments.size() >= 5: return _fail("All five slots are full. Remove a module first.",cell)
	var item: Dictionary = items[index]
	items.remove_at(index)
	towers[cell].attachments.append(item)
	_emit("equip", {"cell":cell,"pos":cell_position(cell),"kind":item.kind,"color":Color(str(item.color)),"text":item.name})
	return _ok("%s equipped." % item.name,{"item":item})

func unequip_item(cell: int, slot: int) -> Dictionary:
	if not _gear_phase(): return _fail("Move equipment during an active run.")
	if not towers.has(cell) or slot < 0 or slot >= towers[cell].attachments.size(): return _fail("Choose an occupied module slot.")
	var item: Dictionary = towers[cell].attachments[slot]
	towers[cell].attachments.remove_at(slot)
	items.append(item)
	_emit("equip", {"cell":cell,"pos":cell_position(cell),"text":"Module returned","color":Color(str(item.color))})
	return _ok("Module returned to your bag.",{"item":item})

func move_attachment(source: int, slot: int, target: int) -> Dictionary:
	if not _gear_phase(): return _fail("Move equipment during an active run.")
	if source == target or not towers.has(source) or not towers.has(target): return _fail("Choose a different planted tower.")
	if slot < 0 or slot >= towers[source].attachments.size(): return _fail("That module is no longer in its slot.")
	if towers[target].attachments.size() >= 5: return _fail("The destination tower has five modules already.")
	var item: Dictionary = towers[source].attachments[slot]
	towers[source].attachments.remove_at(slot)
	towers[target].attachments.append(item)
	_emit("equip", {"cell":target,"pos":cell_position(target),"kind":item.kind,"color":Color(str(item.color)),"text":"Module transferred"})
	return _ok("Module transferred.")

func swap_attachment(cell: int, slot: int, item_id: Variant) -> Dictionary:
	if not _gear_phase(): return _fail("Swap equipment during an active run.")
	if not towers.has(cell) or slot < 0 or slot >= towers[cell].attachments.size(): return _fail("Choose an occupied module slot.")
	var index: int = _item_index(item_id)
	if index < 0 or str(items[index].type) != "attachment": return _fail("Choose a bag attachment.")
	var old: Dictionary = towers[cell].attachments[slot]
	var item: Dictionary = items[index]
	towers[cell].attachments[slot] = item
	items[index] = old
	_emit("equip", {"cell":cell,"pos":cell_position(cell),"kind":item.kind,"color":Color(str(item.color)),"text":"Module swapped"})
	return _ok("Module swapped. Previous equipment returned to your bag.")

func _item_index(item_id: Variant) -> int:
	for i in range(items.size()):
		if int(items[i].id) == int(item_id): return i
	return -1

func _has_effect(kind: String) -> bool:
	for effect in active_effects:
		if str(effect.kind) == kind and float(effect.remaining) > 0.0: return true
	return false

func use_item(item_id: Variant) -> Dictionary:
	var index: int = _item_index(item_id)
	if index < 0 or str(items[index].type) != "consumable": return _fail("Choose a consumable from your bag.")
	var item: Dictionary = items[index]
	var kind: String = str(item.kind)
	if kind == "repair":
		if not ["solve","prep","battle","loot"].has(phase): return _fail("Repair during an active run.")
		if health >= max_health: return _fail("The core is already at full health.")
		health = minf(max_health,health + 10.0)
	else:
		if phase != "battle": return _fail("Use this boost during a battle.")
		if not ["overclock","overcharge","freeze"].has(kind): return _fail("Unknown combat boost.")
		var duration: float = 12.0 if kind == "freeze" else 20.0
		var refreshed: bool = false
		for effect in active_effects:
			if str(effect.kind) == kind:
				effect.remaining = duration
				effect.duration = duration
				refreshed = true
		if not refreshed: active_effects.append({"id":_id(),"kind":kind,"name":item.name,"remaining":duration,"duration":duration})
	items.remove_at(index)
	_emit("item_used", {"kind":kind,"text":item.name,"color":Color(str(item.color))})
	return _ok("Core repaired." if kind == "repair" else "%s active." % item.name,{"item":item})

func chest_price(rarity: String = "common") -> int:
	return int(CHEST_PRICES.get(rarity,0))

func _luck() -> float:
	return minf(0.65, 0.01 * int(passives.salvage) + (0.10 if puzzle_difficulty == "hard" else (0.03 if puzzle_difficulty == "medium" else 0.0)) + 0.003 * (round_no - 1))

func _add_chest(rarity: String, pos: Vector2 = Vector2(-99,-99)) -> Dictionary:
	var tier: int = Loot.rarity_index(rarity)
	var chest: Dictionary = {"id":_id(),"rarity":Loot.RARITIES[tier],"cost":Loot.FRAGMENT_COSTS[tier]}
	chests.append(chest)
	_emit("loot", {"pos":pos,"chest_id":chest.id,"rarity":chest.rarity,"color":Loot.rarity_color(rarity),"text":"%s cache recovered" % str(chest.rarity).capitalize()})
	return chest

func open_chest(chest_id: Variant) -> Dictionary:
	if not ["solve","prep","loot","won"].has(phase): return _fail("Open caches during solve, preparation, or loot camp.")
	var index: int = -1
	for i in range(chests.size()):
		if int(chests[i].id) == int(chest_id): index = i
	if index < 0: return _fail("That cache has already been opened.")
	var chest: Dictionary = chests[index]
	if fragments < int(chest.cost): return _fail("Need %d fragments. Defeat enemies to earn energy." % int(chest.cost))
	fragments -= int(chest.cost)
	chests.remove_at(index)
	var count: int = 3 if str(chest.rarity) == "legendary" else (2 if ["rare","epic"].has(str(chest.rarity)) else 1)
	var rewards: Array[Dictionary] = []
	for i in range(count):
		var item: Dictionary = Loot.make_item(rng,str(chest.rarity),round_no,_id())
		items.append(item)
		rewards.append(item)
	_emit("chest_open", {"rarity":chest.rarity,"color":Loot.rarity_color(chest.rarity),"text":rewards[0].name})
	return _ok("%d item%s recovered." % [count,"s" if count > 1 else ""],{"rewards":rewards,"rarity":chest.rarity})

func buy_chest(rarity: String = "common") -> Dictionary:
	if phase != "loot": return _fail("Buy caches between rounds.")
	var cost: int = chest_price(rarity)
	if cost <= 0: return _fail("Choose a known cache rarity.")
	if credits < cost: return _fail("Need %d credits for this cache." % cost)
	credits -= cost
	var chest: Dictionary = _add_chest(rarity)
	return _ok("Sealed cache purchased. Fragments unlock the contents.",{"chest":chest})

func passive_cost(kind: String) -> int:
	var prices: Dictionary = {"power":60,"salvage":50,"vitality":55}
	if not prices.has(kind): return 0
	return roundi(float(prices[kind]) * pow(1.55,float(passives[kind])))

func buy_passive(kind: String) -> Dictionary:
	if phase != "loot": return _fail("Buy run upgrades between rounds.")
	var cost: int = passive_cost(kind)
	if cost <= 0: return _fail("Choose power, salvage, or vitality.")
	if credits < cost: return _fail("Need %d credits for this run upgrade." % cost)
	credits -= cost
	passives[kind] += 1
	if kind == "vitality":
		max_health += 4.0
		health = minf(max_health,health + 4.0)
	_emit("upgrade", {"text":"%s %d" % [kind.to_upper(),int(passives[kind])],"color":Color("ffe188")})
	return _ok("%s upgraded for this run." % kind.capitalize(),{"cost":cost})

func spin_slots() -> Dictionary:
	if phase != "loot": return _fail("The slot machine opens between rounds.")
	if credits < Loot.SLOT_COST: return _fail("A spin costs 10 credits.")
	var result: Dictionary = Loot.roll_slots(rng)
	credits -= Loot.SLOT_COST
	credits += int(result.credits)
	var item: Variant = null
	var chest: Variant = null
	if bool(result.gear):
		item = Loot.make_item(rng,"common",round_no,_id(),"",true)
		items.append(item)
	if not str(result.chest).is_empty(): chest = _add_chest(str(result.chest))
	var reward: Dictionary = {"credits":result.credits,"item":item,"chest":chest,"chest_rarity":result.chest}
	_emit("slots", {"reels":result.reels,"reward":reward,"text":result.label,"color":Color("ffe188")})
	return _ok(str(result.label),{"outcome_id":result.id,"reels":result.reels,"credits":result.credits,"cost":10,"net_credits":int(result.credits)-10,"reward":reward})

func _build_route() -> void:
	route.clear()
	var entry: float = 0.5
	if not recent_moves.is_empty(): entry = clampf(float(recent_moves.back() % 9) - 0.5,0.5,7.5)
	route.append(Vector2(entry,-0.5))
	var x: float = entry
	for band in range(3):
		var move: int = -1
		for i in range(recent_moves.size()-1,-1,-1):
			if recent_moves[i] / 27 == band:
				move = recent_moves[i]
				break
		var y: float = float(band * 3) + 1.5 if move < 0 else float(move / 9) + 0.5
		var base: int = (7 if band % 2 == 0 else 1) if move < 0 else move % 9
		var next_x: float = float(base) + 0.5
		if absf(next_x-x) < 2.0: next_x = 7.5 if x < 4.0 else 0.5
		_add_route_point(Vector2(x,y))
		_add_route_point(Vector2(next_x,y))
		x = next_x
	_add_route_point(Vector2(x,8.5))
	_add_route_point(Vector2(8.5,8.5))
	_cache_route()

func _add_route_point(point: Vector2) -> void:
	if route.is_empty() or route.back() != point: route.append(point)

func _cache_route() -> void:
	_route_distances = [0.0]
	for i in range(1,route.size()): _route_distances.append(_route_distances.back() + route[i-1].distance_to(route[i]))
	route_length = maxf(1.0,_route_distances.back())

func position_on_route(progress: float) -> Vector2:
	var distance: float = clampf(progress,0.0,route_length)
	var index: int = 1
	while index < _route_distances.size()-1 and _route_distances[index] < distance: index += 1
	var span: float = _route_distances[index] - _route_distances[index-1]
	return route[index-1].lerp(route[index],(distance-_route_distances[index-1]) / span if span > 0.0 else 0.0)

func wave_stats() -> Dictionary:
	var stage: int = round_no - 1
	var difficulty: Dictionary = DIFFICULTIES[combat_difficulty]
	return {"health":28.0 * (1.0 + 0.12 * stage) * pow(1.025,stage) * float(difficulty.hp),"speed":(1.0 + minf(0.55,stage*0.011)) * float(difficulty.speed),"count":roundi((12.0 + floorf(round_no * 0.58)) * float(difficulty.count)),"spawn_interval":maxf(0.35,0.94 - stage*0.0105),"boss":round_no%5 == 0}

func _spawn() -> void:
	var stats: Dictionary = wave_stats()
	var index: int = spawned
	spawned += 1
	var kind: String = "grunt"
	if bool(stats.boss) and index == spawn_total-1: kind = "boss"
	elif index%7 == 5: kind = "tank"
	elif index%4 == 2: kind = "runner"
	elif index%5 == 3: kind = "swarm"
	var hp_factors: Dictionary = {"boss":5.0,"tank":2.3,"runner":0.72,"swarm":0.58,"grunt":1.0}
	var speed_factors: Dictionary = {"boss":0.47,"tank":0.57,"runner":1.4,"swarm":0.95,"grunt":0.82}
	var hp: float = float(stats.health) * float(hp_factors[kind]) * (1.0 + corruption*0.075)
	var enemy: Dictionary = {"id":_id(),"pos":route[0],"hp":hp,"max_hp":hp,"progress":0.0,"speed":float(stats.speed)*float(speed_factors[kind]),"kind":kind,"slow":1.0,"slow_time":0.0,"poison_time":0.0,"poison_dps":0.0}
	enemies.append(enemy)
	_emit("spawn", {"pos":enemy.pos,"kind":kind,"color":Color("ff547d") if kind == "boss" else Color("f2a273")})

func _damage(enemy: Dictionary, amount: float, color: Color, quiet: bool = false) -> void:
	if float(enemy.hp) <= 0.0 or amount <= 0.0 or not is_finite(amount): return
	enemy.hp = float(enemy.hp) - amount
	if not quiet: _emit("hit", {"pos":enemy.pos,"color":color,"amount":amount})
	if float(enemy.hp) > 0.0: return
	kills += 1
	score += roundi(float(enemy.max_hp)*2.0)
	var earned: int = 12 if str(enemy.kind) == "boss" else (2 if str(enemy.kind) == "tank" else 1)
	credits += earned
	var energy: int = 8 if str(enemy.kind) == "boss" else (2 if str(enemy.kind) == "tank" else 1)
	if rng.randf() < minf(0.75,0.05*int(passives.salvage)): energy += 1
	fragments += energy
	_emit("kill", {"pos":enemy.pos,"kind":enemy.kind,"text":"+%d" % earned,"color":color})
	_emit("fragment", {"pos":enemy.pos,"amount":energy,"text":"+%d energy" % energy,"color":Color("75eab8")})
	var chance: float = 0.09 + (0.045 if puzzle_difficulty == "hard" else (0.015 if puzzle_difficulty == "medium" else 0.0))
	if str(enemy.kind) == "boss" or rng.randf() < chance:
		_add_chest(Loot.roll_rarity(rng,_luck()),enemy.pos)

func _fire(tower: Dictionary, target: Dictionary, stats: Dictionary) -> void:
	var cell: int = int(tower.cell)
	var origin: Vector2 = cell_position(cell)
	var effects: Dictionary = stats.effects
	var color: Color = color_for(int(tower.number))
	var kind: String = "basic"
	for candidate in ["nova","gravity","electric","blast","venom","frost","rapid","power","range"]:
		if float(effects.get(candidate,0.0)) > 0.0:
			kind = candidate
			break
	tower.aim = target.pos
	var impact: Vector2 = target.pos
	_emit("shot", {"cell":cell,"pos":origin,"target":impact,"number":tower.number,"kind":kind,"color":color,"height":0.5+tower.attachments.size()*0.18})
	_damage(target,float(stats.damage),color)
	var frost: float = float(effects.get("frost",0.0))
	if frost > 0.0 and float(target.hp)>0.0:
		target.slow_time = 2.0
		target.slow = minf(float(target.slow),1.0-minf(0.70,0.18*frost))
	var venom: float = float(effects.get("venom",0.0))
	if venom > 0.0 and float(target.hp)>0.0:
		target.poison_time = 3.0
		target.poison_dps = maxf(float(target.poison_dps),0.30*venom*float(stats.damage))
	var electric: float = float(effects.get("electric",0.0))
	if electric > 0.0:
		var last: Dictionary = target
		var used: Array[int] = [int(target.id)]
		for jump in range(mini(7,1+floori(electric))):
			var next: Dictionary = {}
			var nearest: float = 1.5+0.06*electric
			for enemy in enemies:
				if float(enemy.hp)<=0.0 or used.has(int(enemy.id)): continue
				var distance: float = (enemy.pos as Vector2).distance_to(last.pos)
				if distance < nearest:
					nearest = distance
					next = enemy
			if next.is_empty(): break
			_emit("shot", {"pos":last.pos,"target":next.pos,"color":Color("c6a0ff"),"kind":"electric","height":0.25})
			_damage(next,float(stats.damage)*minf(1.0,0.30+0.12*electric)*pow(0.75,jump),Color("c6a0ff"))
			used.append(int(next.id))
			last = next
	var blast: float = float(effects.get("blast",0.0))
	if blast > 0.0:
		var radius: float = minf(2.3,0.65+0.12*blast)
		for enemy in enemies:
			if int(enemy.id) != int(target.id) and float(enemy.hp)>0.0 and (enemy.pos as Vector2).distance_to(impact)<radius:
				_damage(enemy,float(stats.damage)*minf(3.0,0.35*blast),Color("ffae68"))
		_emit("explosion", {"pos":impact,"radius":radius,"color":Color("ffae68"),"kind":"blast"})
	var gravity: float = float(effects.get("gravity",0.0))
	if gravity > 0.0:
		for enemy in enemies:
			if float(enemy.hp)>0.0 and (enemy.pos as Vector2).distance_to(impact)<1.25:
				enemy.progress = maxf(0.0,float(enemy.progress)-minf(0.8,0.14*gravity)*(0.3 if str(enemy.kind)=="boss" else 1.0))
				enemy.pos = position_on_route(float(enemy.progress))
		_emit("explosion", {"pos":impact,"radius":1.25,"color":Color("bb9bff"),"kind":"gravity"})
	var nova: float = float(effects.get("nova",0.0))
	if nova > 0.0:
		for enemy in enemies:
			if float(enemy.hp)>0.0 and (enemy.pos as Vector2).distance_to(origin)<=1.4:
				_damage(enemy,float(stats.damage)*minf(2.5,0.20*nova),Color("ff7289"))
		_emit("explosion", {"pos":origin,"radius":1.4,"color":Color("ff7289"),"kind":"nova"})

func update(dt: float) -> void:
	if not is_finite(dt) or dt <= 0.0: return
	var remaining: float = minf(dt,10.0)
	while remaining > 0.000001:
		var step: float = minf(remaining,0.05)
		_step(step)
		remaining -= step

func _step(dt: float) -> void:
	for tower: Dictionary in towers.values(): tower.growth = minf(1.0,float(tower.growth)+dt/0.8)
	if phase == "solve":
		timer = maxf(0.0,timer-dt)
		if timer <= 0.000001: advance_phase()
		return
	if phase != "battle": return
	battle_time += dt
	timer = battle_time
	for effect in active_effects: effect.remaining = maxf(0.0,float(effect.remaining)-dt)
	active_effects = active_effects.filter(func(effect: Dictionary) -> bool: return float(effect.remaining)>0.0)
	_spawn_clock -= dt
	if spawned < spawn_total and _spawn_clock <= 0.0:
		_spawn()
		_spawn_clock = float(wave_stats().spawn_interval)
	var global_slow: float = 0.4 if _has_effect("freeze") else 1.0
	for enemy in enemies:
		if float(enemy.hp) <= 0.0: continue
		if float(enemy.poison_time)>0.0:
			enemy.poison_time = maxf(0.0,float(enemy.poison_time)-dt)
			_damage(enemy,float(enemy.poison_dps)*dt,Color("9be878"),true)
		if float(enemy.hp)<=0.0: continue
		var slow: float = minf(global_slow,float(enemy.slow) if float(enemy.slow_time)>0.0 else 1.0)
		enemy.slow_time = maxf(0.0,float(enemy.slow_time)-dt)
		if float(enemy.slow_time)<=0.0: enemy.slow = 1.0
		enemy.progress = float(enemy.progress) + float(enemy.speed)*slow*dt
		enemy.pos = position_on_route(float(enemy.progress))
		if float(enemy.progress) >= route_length:
			enemy.hp = 0.0
			health -= 6.0 if str(enemy.kind)=="boss" else (2.0 if str(enemy.kind)=="tank" else 1.0)
			_emit("leak", {"pos":enemy.pos,"text":"CORE HIT","color":Color("ff7289")})
	if health <= 0.0:
		health = 0.0
		phase = "lost"
		_emit("phase", {"phase":phase,"text":"THE CORE FELL","color":Color("ff7289")})
		return
	for tower: Dictionary in towers.values():
		if float(tower.growth)<1.0: continue
		tower.cooldown = float(tower.cooldown)-dt
		if float(tower.cooldown)>0.0: continue
		var origin: Vector2 = cell_position(int(tower.cell))
		var stats: Dictionary = tower_stats(int(tower.cell))
		var target: Dictionary = {}
		var progress: float = -1.0
		for enemy in enemies:
			if float(enemy.hp)>0.0 and (enemy.pos as Vector2).distance_to(origin)<=float(stats.range) and float(enemy.progress)>progress:
				target = enemy
				progress = float(enemy.progress)
		if not target.is_empty():
			_fire(tower,target,stats)
			# Carry elapsed time past the shot boundary into the next interval,
			# so larger steps at 2x/4x do not reduce the tower's fire rate.
			tower.cooldown = float(tower.cooldown) + float(stats.interval)
		else: tower.cooldown = 0.0
	enemies = enemies.filter(func(enemy: Dictionary) -> bool: return float(enemy.hp)>0.0)
	if spawned >= spawn_total and enemies.is_empty(): _finish_wave()

func _finish_wave() -> void:
	if phase != "battle" or _settled or spawned < spawn_total or not enemies.is_empty(): return
	_settled = true
	var removed: Array[int] = []
	for cell: int in towers:
		var tower: Dictionary = towers[cell]
		if bool(tower.illegal):
			board[cell] = 0
			for item: Dictionary in tower.attachments: items.append(item)
			removed.append(cell)
	for cell in removed: towers.erase(cell)
	last_wave_bonus = roundi((22.0 + round_no*2.0)*float(DIFFICULTIES[combat_difficulty].reward))
	credits += last_wave_bonus
	score += roundi(500.0+health*10.0)
	health = minf(max_health,health+3.0)
	_add_chest(Loot.roll_rarity(rng,_luck()))
	phase = "won" if round_no >= max_rounds else "loot"
	_emit("phase", {"phase":phase,"text":"GRID SECURED" if phase=="won" else "Round clear · +%d credits" % last_wave_bonus,"color":Color("ffe188")})

# JSON-safe saves keep the 64-bit RNG state as text, avoiding JSON precision loss.
func save_data() -> Dictionary:
	var state: Dictionary = {
		"phase":phase,"round_no":round_no,"max_rounds":max_rounds,"mode":mode,
		"puzzle_difficulty":puzzle_difficulty,"combat_difficulty":combat_difficulty,"seed_value":str(seed_value),
		"board":board.duplicate(),"solution":solution.duplicate(),"givens":givens.duplicate(),
		"recent_moves":recent_moves.duplicate(),"credits":credits,"fragments":fragments,"health":health,
		"max_health":max_health,"score":score,"timer":timer,"kills":kills,"spawned":spawned,"spawn_total":spawn_total,
		"items":items.duplicate(true),"chests":chests.duplicate(true),"family_levels":family_levels.duplicate(),
		"inventory":inventory.duplicate(),"passives":passives.duplicate(),"active_effects":active_effects.duplicate(true),
		"corruption":corruption,"combo":combo,"round_solved":round_solved,"solve_duration":solve_duration,
		"last_wave_bonus":last_wave_bonus,"battle_time":battle_time,"next_id":_next_id,"spawn_clock":_spawn_clock,
		"settled":_settled,"rewarded_units":_rewarded_units.duplicate(),"locked_puzzle":_locked_puzzle,"locked_combat":_locked_combat,
		"towers":[],"enemies":[],"route":[]
	}
	for tower: Dictionary in towers.values():
		var saved: Dictionary = tower.duplicate(true)
		var aim: Vector2 = tower.aim
		saved.aim = [aim.x,aim.y]
		state.towers.append(saved)
	for enemy in enemies:
		var saved: Dictionary = enemy.duplicate(true)
		var pos: Vector2 = enemy.pos
		saved.pos = [pos.x,pos.y]
		state.enemies.append(saved)
	for point in route: state.route.append([point.x,point.y])
	return {"version":1,"rng_state":str(rng.state),"state":state}

func load_data(data: Dictionary) -> bool:
	if int(data.get("version",0)) != 1 or not data.get("state") is Dictionary: return false
	var state: Dictionary = data.state
	for key in ["board","solution","givens"]:
		if not state.get(key) is Array or state[key].size() != 81: return false
	for key in ["family_levels","inventory"]:
		if not state.get(key) is Array or state[key].size() != 10: return false
	for key in ["items","chests","active_effects","towers","enemies","route","recent_moves","rewarded_units"]:
		if not state.get(key) is Array: return false
	for key in ["credits","fragments","health","max_health","timer","kills","spawned","spawn_total","next_id","battle_time","solve_duration"]:
		if not state.has(key) or float(state[key]) < 0.0 or not is_finite(float(state[key])): return false
	if not ["solve","prep","battle","loot","won","lost"].has(str(state.get("phase",""))): return false
	if not ["campaign","freeplay","locked"].has(str(state.get("mode",""))): return false
	if not DIFFICULTIES.has(str(state.get("puzzle_difficulty",""))) or not DIFFICULTIES.has(str(state.get("combat_difficulty",""))): return false
	if int(state.get("round_no",0)) < 1 or int(state.round_no) > 50: return false
	if not state.get("passives") is Dictionary or state.route.size()<2: return false
	# Validate the original puzzle separately from player moves: emergency
	# towers can deliberately violate Sudoku during battle and after a loss.
	var clue_board: Array[int] = []
	for i in range(81):
		var digit: Variant = state.board[i]
		if not (digit is int or digit is float) or not state.givens[i] is bool: return false
		var value: float = float(digit)
		if not is_finite(value) or value != floorf(value) or value < 0.0 or value > 9.0: return false
		clue_board.append(int(digit) if state.givens[i] else 0)
	if not Sudoku.valid_puzzle({"board":clue_board,"solution":state.solution,"givens":state.givens}): return false
	if not str(state.phase) in ["battle","lost"]:
		for i in range(81):
			if int(state.board[i]) != 0 and int(state.board[i]) != int(state.solution[i]): return false
	for point in state.route:
		if not point is Array or point.size()!=2: return false
	for tower in state.towers:
		if not tower is Dictionary or not tower.get("aim") is Array or tower.aim.size()!=2: return false
		if not tower.get("attachments") is Array or tower.attachments.size()>5: return false
		if int(tower.get("cell",-1))<0 or int(tower.cell)>=81 or int(tower.get("number",0))<1 or int(tower.number)>9: return false
	for enemy in state.enemies:
		if not enemy is Dictionary or not enemy.get("pos") is Array or enemy.pos.size()!=2: return false
	# Everything below is assignment from a validated own-format save.
	phase = str(state.phase)
	round_no = int(state.round_no)
	max_rounds = int(state.max_rounds)
	mode = str(state.mode)
	puzzle_difficulty = str(state.puzzle_difficulty)
	combat_difficulty = str(state.combat_difficulty)
	seed_value = int(state.seed_value)
	board.clear()
	solution.clear()
	givens.clear()
	for i in range(81):
		board.append(int(state.board[i]))
		solution.append(int(state.solution[i]))
		givens.append(bool(state.givens[i]))
	recent_moves.clear()
	for cell in state.recent_moves: recent_moves.append(int(cell))
	credits = int(state.credits)
	fragments = int(state.fragments)
	health = float(state.health)
	max_health = float(state.max_health)
	score = int(state.score)
	timer = float(state.timer)
	kills = int(state.kills)
	spawned = int(state.spawned)
	spawn_total = int(state.spawn_total)
	items.assign(state.items.duplicate(true))
	chests.assign(state.chests.duplicate(true))
	active_effects.assign(state.active_effects.duplicate(true))
	family_levels.clear()
	inventory.clear()
	for i in range(10):
		family_levels.append(int(state.family_levels[i]))
		inventory.append(int(state.inventory[i]))
	passives = state.passives.duplicate()
	corruption = int(state.corruption)
	combo = int(state.combo)
	round_solved = int(state.round_solved)
	solve_duration = float(state.solve_duration)
	last_wave_bonus = int(state.last_wave_bonus)
	battle_time = float(state.battle_time)
	_next_id = int(state.next_id)
	_spawn_clock = float(state.spawn_clock)
	_settled = bool(state.settled)
	_rewarded_units.assign(state.rewarded_units)
	_locked_puzzle = str(state.locked_puzzle)
	_locked_combat = str(state.locked_combat)
	towers.clear()
	for value in state.towers:
		var tower: Dictionary = value.duplicate(true)
		tower.cell = int(tower.cell)
		tower.number = int(tower.number)
		tower.level = int(tower.level)
		tower.aim = Vector2(float(tower.aim[0]),float(tower.aim[1]))
		towers[int(tower.cell)] = tower
	enemies.clear()
	for value in state.enemies:
		var enemy: Dictionary = value.duplicate(true)
		enemy.pos = Vector2(float(enemy.pos[0]),float(enemy.pos[1]))
		enemies.append(enemy)
	route.clear()
	for value in state.route: route.append(Vector2(float(value[0]),float(value[1])))
	_cache_route()
	rng.seed = seed_value
	rng.state = int(data.get("rng_state","0"))
	_events.clear()
	_hinting = false
	return true
