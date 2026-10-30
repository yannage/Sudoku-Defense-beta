extends RefCounted
## A verified write-ahead journal makes replacement recoverable on every target.
## Publishing .pending is the commit point. On Windows Godot's rename removes
## an existing destination first, so loading must check the journal before the
## primary. At no point is the only committed snapshot opened for writing.

const Run = preload("res://scripts/run.gd")
const MAX_BYTES := 8 * 1024 * 1024
var file_path := "user://sudoku-defense-run.json"

func has_save() -> bool:
	for suffix in ["", ".pending", ".bak"]:
		if FileAccess.file_exists(file_path + suffix): return true
	return false

func read_run() -> Dictionary:
	for suffix in [".pending", "", ".bak"]:
		var candidate := _read_valid(file_path + suffix)
		if not candidate.is_empty():
			candidate["recovered"] = suffix != ""
			candidate["source"] = file_path + suffix
			return candidate
	return {}

func write_run(data: Dictionary) -> bool:
	var text := JSON.stringify(data)
	if not _valid_data(JSON.parse_string(text)): return false
	# Finish a previously committed transaction before reusing its journal name.
	# A failed promotion keeps that journal intact and refuses a newer write.
	var pending := _read_valid(file_path + ".pending")
	if not pending.is_empty():
		if not _replace(file_path + ".pending", file_path): return false
	elif FileAccess.file_exists(file_path + ".pending"):
		if DirAccess.remove_absolute(file_path + ".pending") != OK: return false
	var previous := read_run()
	if not _write_verified(file_path + ".tmp", text): return false
	# Stage the backup without touching the current primary. A crash during
	# backup replacement still leaves the primary; after commit, either .pending
	# or the new primary survives, with the previous known-good data in .bak.
	if not previous.is_empty() and str(previous.source) != file_path + ".bak":
		if not _write_verified(file_path + ".bak.tmp", str(previous.text)): return false
		if not _replace(file_path + ".bak.tmp", file_path + ".bak"): return false
	if not _replace(file_path + ".tmp", file_path + ".pending"): return false
	if not _replace(file_path + ".pending", file_path): return false
	return true

func _replace(source: String, destination: String) -> bool:
	return DirAccess.rename_absolute(source, destination) == OK

func _write_verified(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(text)
	file.flush()
	var status := file.get_error()
	file.close()
	if status != OK: return false
	var verified := _read_valid(path)
	return not verified.is_empty() and str(verified.text) == text

func _read_valid(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	if file.get_length() <= 0 or file.get_length() > MAX_BYTES:
		file.close()
		return {}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK or not _valid_data(parser.data): return {}
	return {"data": parser.data, "text": text}

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _valid_data(data: Variant) -> bool:
	# Reject malformed complete JSON before the model's semantic validation.
	# Keep version-1 files and optional future/additive fields compatible.
	if not data is Dictionary or not data.get("state") is Dictionary: return false
	if not _number(data.get("version")) or int(data.version) != 1: return false
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
