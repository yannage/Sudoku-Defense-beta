class_name DefenseLoot
extends RefCounted

const RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]
const RARITY_COLORS: Array[String] = ["b7c7d9", "91e8a6", "77caff", "c7a0ff", "ffca69"]
const MULTIPLIERS: Array[float] = [1.0, 1.35, 1.8, 2.4, 3.2]
const FRAGMENT_COSTS: Array[int] = [5, 7, 10, 14, 20]
const ATTACHMENTS: Array[String] = ["rapid", "electric", "frost", "blast", "venom", "range", "power", "gravity", "nova"]
const NAMES: Dictionary = {"rapid":"Tempo Petal", "electric":"Livewire Crown", "frost":"Rime Bud", "blast":"Cinder Pod", "venom":"Spore Injector", "range":"Horizon Tendril", "power":"Heartwood Reactor", "gravity":"Anchor Root", "nova":"Sunburst Corolla", "overclock":"Rushbloom Capsule", "overcharge":"Solar Sap Ampoule", "freeze":"Winterwake Flask", "repair":"Coremend Nectar"}
const KIND_COLORS: Dictionary = {"rapid":"6de8ff", "electric":"c6a0ff", "frost":"a4c7ff", "blast":"ffae68", "venom":"9be878", "range":"ffe188", "power":"fb86c3", "gravity":"bb9bff", "nova":"ff7289", "overclock":"6de8ff", "overcharge":"ffe188", "freeze":"a4c7ff", "repair":"91e8a6"}
const SLOT_COST: int = 10
# Fixed odds. Returns below the stake always include useful permanent equipment.
const SLOT_TABLE: Array[Dictionary] = [
	{"id":"salvage", "units":250, "credits":0, "gear":true, "chest":"", "label":"Common module"},
	{"id":"recovery", "units":200, "credits":5, "gear":true, "chest":"", "label":"5 credits + common module"},
	{"id":"refund", "units":250, "credits":10, "gear":false, "chest":"", "label":"Stake recovered"},
	{"id":"double", "units":200, "credits":20, "gear":false, "chest":"", "label":"Double credits"},
	{"id":"triple", "units":50, "credits":30, "gear":false, "chest":"", "label":"Triple credits"},
	{"id":"chest-common", "units":20, "credits":10, "gear":false, "chest":"common", "label":"Common cache + stake back"},
	{"id":"chest-uncommon", "units":15, "credits":10, "gear":false, "chest":"uncommon", "label":"Uncommon cache + stake back"},
	{"id":"chest-rare", "units":10, "credits":10, "gear":false, "chest":"rare", "label":"Rare cache + stake back"},
	{"id":"chest-epic", "units":4, "credits":10, "gear":false, "chest":"epic", "label":"Epic cache + stake back"},
	{"id":"chest-legendary", "units":1, "credits":10, "gear":false, "chest":"legendary", "label":"Legendary cache + stake back"},
]

static func rarity_index(rarity: String) -> int:
	return maxi(0, RARITIES.find(rarity))

static func rarity_color(rarity: String) -> Color:
	return Color(RARITY_COLORS[rarity_index(rarity)])

static func roll_rarity(rng: RandomNumberGenerator, luck: float = 0.0) -> String:
	var base: Array[float] = [0.58, 0.27, 0.10, 0.04, 0.01]
	var boosted: Array[float] = [0.30, 0.32, 0.22, 0.12, 0.04]
	var draw: float = rng.randf()
	var threshold: float = 0.0
	for i in range(5):
		threshold += lerpf(base[i], boosted[i], clampf(luck, 0.0, 1.0))
		if draw < threshold:
			return RARITIES[i]
	return "legendary"

static func make_item(rng: RandomNumberGenerator, rarity: String, round_no: int, item_id: int, force_kind: String = "", attachment_only: bool = false) -> Dictionary:
	var tier: int = rarity_index(rarity)
	var kind: String = force_kind
	if kind.is_empty():
		var chance: float = 0.20 if tier == 0 else (0.15 if tier == 1 else 0.0)
		if not attachment_only and rng.randf() < chance:
			var consumables: Array[String] = ["overclock", "overcharge", "freeze", "repair"]
			kind = consumables[rng.randi_range(0, 3)]
		else:
			kind = ATTACHMENTS[rng.randi_range(0, ATTACHMENTS.size() - 1)]
	var is_attachment: bool = ATTACHMENTS.has(kind)
	var power: float = snappedf(MULTIPLIERS[tier] * rng.randf_range(0.90, 1.10) * (1.0 + 0.006 * (clampi(round_no, 1, 50) - 1)), 0.01) if is_attachment else 1.0
	var prefixes: Array[String] = ["Workshop", "Verdant", "Moonforged", "Astral", "Last Sunrise"]
	var name_text: String = str(NAMES.get(kind, kind))
	if is_attachment:
		name_text = prefixes[tier] + " " + name_text
	var result: Dictionary = {"id":item_id, "type":"attachment" if is_attachment else "consumable", "kind":kind, "name":name_text, "rarity":RARITIES[tier], "color":KIND_COLORS.get(kind, "b7c7d9"), "power":power}
	result.description = description(result)
	return result

static func description(item: Dictionary) -> String:
	var power: float = float(item.get("power", 1.0))
	match str(item.get("kind", "")):
		"rapid": return "+%d%% fire rate. Stack for faster bolts." % roundi(20.0 * power)
		"electric": return "Lightning jumps to %d extra enemies." % mini(7, 1 + floori(power))
		"frost": return "Slows targets %d%% for 2 seconds." % roundi(minf(70.0, 18.0 * power))
		"blast": return "Explosive bolts deal %d%% splash damage." % roundi(minf(300.0, 35.0 * power))
		"venom": return "Poison adds %d%% damage each second for 3 seconds." % roundi(30.0 * power)
		"range": return "+%.2f cells of targeting range." % (0.28 * power)
		"power": return "+%d%% bolt damage." % roundi(25.0 * power)
		"gravity": return "Pulls targets back %.2f cells per shot." % minf(0.8, 0.14 * power)
		"nova": return "Adds a %d%% damage pulse around the tower." % roundi(minf(250.0, 20.0 * power))
		"overclock": return "Every tower fires 2× as fast for 20 seconds. Battle only."
		"overcharge": return "Every tower deals 60% more damage for 20 seconds. Battle only."
		"freeze": return "All enemies move 60% slower for 12 seconds. Battle only."
		"repair": return "Restore 10 core health. Use during any active phase."
	return "Unknown equipment."

static func roll_slots(rng: RandomNumberGenerator) -> Dictionary:
	var draw: int = rng.randi_range(0, 999)
	var total: int = 0
	for row in SLOT_TABLE:
		total += int(row.units)
		if draw < total:
			var result: Dictionary = row.duplicate(true)
			var symbol: String = "gear" if bool(row.gear) else ("chest-" + str(row.chest) if not str(row.chest).is_empty() else "credit")
			result.reels = [symbol, symbol, symbol]
			return result
	return SLOT_TABLE[0].duplicate(true)
