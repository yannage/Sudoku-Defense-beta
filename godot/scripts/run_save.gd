extends "res://scripts/journal_store.gd"
## Run-specific schema validation over the shared recoverable journal.

const Run = preload("res://scripts/run.gd")
var _resolution_signature := ""

func _init() -> void:
	file_path = "user://sudoku-defense-run.json"

func read_run() -> Dictionary:
	return read_data()

func write_run(data: Dictionary) -> bool:
	return write_data(data)

func conflict_candidates() -> Array[Dictionary]:
	var snapshot := recovery_snapshot()
	_resolution_signature = str(snapshot.token)
	var candidates: Array[Dictionary] = []
	var labels := {"": "Saved run", ".pending": "Interrupted save", ".bak": "Last-good backup"}
	for candidate: Dictionary in snapshot.candidates:
		candidate["label"] = labels[str(candidate.suffix)]
		candidates.append(candidate)
	return candidates

func resolve_candidate(candidate_hash: String) -> bool:
	last_error = {}
	if _resolution_signature.is_empty() or _signature() != _resolution_signature:
		return _fail("external_change", "Saved files changed while choosing. Reopen the save choices before continuing; all versions have been kept.")
	if not _check_committed() and str(last_error.get("code", "")) != "sync_conflict": return false
	var chosen: Dictionary = {}
	for suffix: String in ["", ".pending", ".bak"]:
		var candidate := _read_valid(file_path + suffix)
		if not candidate.is_empty() and str(candidate.text).sha256_text() == candidate_hash: chosen = candidate
	if chosen.is_empty(): return _fail("invalid_choice", "That saved run is no longer available. Reopen the save choices; all versions have been kept.")
	var result := resolve_merged(chosen.data, _resolution_signature)
	if result: _resolution_signature = ""
	return result
func _valid_data(data: Variant) -> bool:
	# Reject malformed complete JSON before the model's semantic validation.
	# Keep version-1 files and optional future/additive fields compatible.
	if not data is Dictionary or not data.get("state") is Dictionary: return false
	if not _number(data.get("version")) or float(data.version) != 1: return false
	if not str(data.get("rng_state", "")).is_valid_int(): return false
	var state: Dictionary = data.state
	for key in ["round_no", "max_rounds", "credits", "fragments", "health", "max_health", "score", "timer", "kills", "spawned", "spawn_total", "corruption", "combo", "round_solved", "solve_duration", "last_wave_bonus", "battle_time", "next_id", "spawn_clock"]:
		if not _number(state.get(key)): return false
	for key in ["phase", "mode", "puzzle_difficulty", "combat_difficulty", "locked_puzzle", "locked_combat"]:
		if not state.get(key) is String: return false
	if not str(state.get("seed_value", "")).is_valid_int() or not state.get("settled") is bool: return false
	for key in ["board", "solution", "family_levels", "inventory", "recent_moves"]:
		if not state.get(key) is Array: return false
		for value in state[key]:
			if not _number(value): return false
	for key in ["items", "chests", "active_effects", "towers", "enemies"]:
		if not state.get(key) is Array: return false
		for value in state[key]:
			if not value is Dictionary: return false
	if not state.get("passives") is Dictionary: return false
	for key in ["power", "salvage", "vitality"]:
		if not _number(state.passives.get(key)): return false
	for item in state.items:
		if not _item(item): return false
	for chest in state.chests:
		if not _number(chest.get("id")) or not _number(chest.get("cost")): return false
		if not chest.get("rarity") is String or not Run.Loot.RARITIES.has(chest.rarity): return false
	for effect in state.active_effects:
		for key in ["id", "remaining", "duration"]:
			if not _number(effect.get(key)): return false
		for key in ["kind", "name"]:
			if not effect.get(key) is String: return false
	if not state.get("route") is Array: return false
	for point in state.route:
		if not _point(point): return false
	for tower in state.towers:
		if not _point(tower.get("aim")) or not tower.get("attachments") is Array: return false
		for key in ["id", "cell", "number", "level", "growth", "cooldown"]:
			if not _number(tower.get(key)): return false
		if not tower.get("illegal") is bool: return false
		for item in tower.attachments:
			if not _item(item) or item.type != "attachment": return false
	for enemy in state.enemies:
		if not _point(enemy.get("pos")): return false
		for key in ["id", "hp", "max_hp", "progress", "speed", "slow", "slow_time", "poison_time", "poison_dps"]:
			if not _number(enemy.get(key)): return false
		if not enemy.get("kind") is String or not Run.ENEMY_KINDS.has(enemy.kind): return false
	var probe = Run.new()
	return probe.load_data(data)

func _point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0]) and _number(value[1])

func _item(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key in ["id", "power"]:
		if not _number(value.get(key)): return false
	for key in ["type", "kind", "name", "rarity", "color", "description"]:
		if not value.get(key) is String: return false
	return value.type in ["attachment", "consumable"] and Run.Loot.RARITIES.has(value.rarity) and Run.Loot.NAMES.has(value.kind) and Color.html_is_valid(value.color)
