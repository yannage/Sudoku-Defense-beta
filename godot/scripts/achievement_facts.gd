extends RefCounted

# Facts are part of the run save, not the bounded/drained presentation queue.
# This script never talks to Steam. An empty run ID explicitly disables delivery.
const IDS: Array[String] = [
	"SD_FIRST_PLANT", "SD_FIRST_UNIT", "SD_FIRST_UPGRADE", "SD_FIRST_MODULE",
	"SD_FIRST_CHEST", "SD_FIRST_BOOST", "SD_FIRST_CLEAR", "SD_FIRST_BOSS",
	"SD_ROUND_10", "SD_ROUND_25", "SD_CAMPAIGN_CLEAR", "SD_LOCKED_CLEAR",
	"SD_FIRST_FAMILY", "SD_FAMILY_FIVE", "SD_TOWER_FIVE", "SD_FIVE_SOCKETS",
	"SD_STACK_MODULES", "SD_THREE_EFFECTS", "SD_TARGET_LINEUP", "SD_NINE_FAMILIES",
	"SD_HARD_GRID", "SD_NO_HINT_GRID", "SD_BOSS_WAVE_CLEAN", "SD_CORRUPT_CLEAR",
	"SD_UNFINISHED_CLEAR", "SD_CLEAN_CAMPAIGN"
]
const COUNTERS: Array[String] = [
	"manual_placements", "hinted_placements", "hints", "wrong_answers", "illegal_placements",
	"battle_placements", "completed_rows", "completed_columns", "completed_boxes", "completed_boards",
	"kills", "boss_kills", "leaks", "boss_leaks", "core_damage", "tower_upgrades", "family_upgrades",
	"module_equips", "module_moves", "module_swaps", "consumables_used", "chests_opened",
	"passives_bought", "waves_cleared"
]
const MAXIMA: Array[String] = ["combo", "tower_level", "family_level", "modules_on_tower", "distinct_module_kinds", "same_module_kind", "passives_total"]
const SEEN: Dictionary = {
	"module_kinds":["rapid", "electric", "frost", "blast", "venom", "range", "power", "gravity", "nova"],
	"consumable_kinds":["overclock", "overcharge", "freeze", "repair"],
	"chest_rarities":["common", "uncommon", "rare", "epic", "legendary"]
}

static func valid_id(value: Variant) -> bool:
	if not value is String or value.length() > 128: return false
	for character in value:
		if not (character >= "a" and character <= "z") and not (character >= "A" and character <= "Z") and not (character >= "0" and character <= "9") and not character in ["-", "_"]: return false
	return true

static func zeros(keys: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for key in keys: result[key] = 0
	return result

static func new_round(number: int, complete: bool = true) -> Dictionary:
	return {"round":number, "complete_history":complete, "counters":zeros(COUNTERS), "maxima":zeros(MAXIMA), "board_complete":false, "board_complete_no_hints":false, "board_complete_in_solve":false}

static func create(run_id: String = "", complete: bool = true, number: int = 1) -> Dictionary:
	var seen: Dictionary = {}
	for key: String in SEEN: seen[key] = []
	return {"version":1, "run_id":run_id if valid_id(run_id) else "", "complete_history":complete, "counters":zeros(COUNTERS), "maxima":zeros(MAXIMA), "seen":seen, "earned":{}, "current_round":new_round(number,complete), "waves":[]}

static func count(stats: Dictionary, key: String, amount: int = 1) -> void:
	if not COUNTERS.has(key) or amount <= 0: return
	stats.counters[key] += amount
	stats.current_round.counters[key] += amount

static func maximum(stats: Dictionary, key: String, value: int) -> void:
	if not MAXIMA.has(key): return
	stats.maxima[key] = maxi(int(stats.maxima[key]),value)
	stats.current_round.maxima[key] = maxi(int(stats.current_round.maxima[key]),value)

static func see(stats: Dictionary, key: String, value: String) -> void:
	if SEEN.has(key) and SEEN[key].has(value) and not stats.seen[key].has(value): stats.seen[key].append(value)

static func earn(stats: Dictionary, key: String) -> void:
	if IDS.has(key): stats.earned[key] = true

static func _natural(value: Variant, limit: int = 1000000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= 0.0 and float(value) <= limit

static func _counts(value: Variant, keys: Array[String]) -> bool:
	if not value is Dictionary or value.size() != keys.size(): return false
	for key in keys:
		if not _natural(value.get(key)): return false
	return true

static func _round(value: Variant) -> bool:
	if not value is Dictionary or not _natural(value.get("round"),50) or int(value.round) < 1: return false
	for key in ["complete_history", "board_complete", "board_complete_no_hints", "board_complete_in_solve"]:
		if not value.get(key) is bool: return false
	return _counts(value.get("counters"),COUNTERS) and _counts(value.get("maxima"),MAXIMA)

static func read(value: Variant, number: int) -> Dictionary:
	# Optional malformed/missing metadata never breaks an otherwise valid old save.
	# It loses its ID and all untrustworthy evidence, including perfect-run claims.
	var fallback: Dictionary = create("",false,number)
	if not value is Dictionary: return fallback
	if not _natural(value.get("version"),1) or int(value.version) != 1 or not valid_id(value.get("run_id")): return fallback
	if not value.get("complete_history") is bool or not _counts(value.get("counters"),COUNTERS) or not _counts(value.get("maxima"),MAXIMA): return fallback
	if not value.get("earned") is Dictionary or value.earned.size() > IDS.size(): return fallback
	for key: Variant in value.earned:
		if not IDS.has(str(key)) or not value.earned[key] is bool or not value.earned[key]: return fallback
	if not value.get("seen") is Dictionary or value.seen.size() != SEEN.size(): return fallback
	for key: String in SEEN:
		if not value.seen.get(key) is Array or value.seen[key].size() > SEEN[key].size(): return fallback
		var found: Array = []
		for entry: Variant in value.seen[key]:
			if not SEEN[key].has(entry) or found.has(entry): return fallback
			found.append(entry)
	if not _round(value.get("current_round")) or int(value.current_round.round) != number: return fallback
	if not value.get("waves") is Array or value.waves.size() > 50: return fallback
	var previous_round: int = 0
	for wave: Variant in value.waves:
		if not _round(wave) or int(wave.round) <= previous_round or int(wave.round) > number: return fallback
		if not ["campaign", "locked", "freeplay"].has(wave.get("mode")): return fallback
		for key in ["puzzle_difficulty", "combat_difficulty"]:
			if not ["easy", "medium", "hard"].has(wave.get(key)): return fallback
		if not _natural(wave.get("legal_families"),9) or not _natural(wave.get("target_priorities"),3) or not wave.get("grid_incomplete") is bool: return fallback
		previous_round = int(wave.round)
	return value.duplicate(true)
