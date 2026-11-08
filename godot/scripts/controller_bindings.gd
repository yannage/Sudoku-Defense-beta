extends RefCounted
## A complete, unique action map. Reserved D-pad/stick axes guarantee recovery.
const DEFAULTS := {
	"confirm":"b0", "cancel":"b1", "gear":"b2", "advance":"b3",
	"previous":"b9", "next":"b10", "pause":"b6", "help":"b4",
	"camera":"b7", "click":"b8", "drag":"t5", "precision":"t4",
}
const TITLES := {"confirm":"Confirm / plant", "cancel":"Back / cancel", "gear":"Gear", "advance":"Advance / speed", "previous":"Previous number / tower / tab", "next":"Next number / tower / tab", "pause":"Pause menu", "help":"Help", "camera":"Camera mode", "click":"Cursor click / camera reset", "drag":"Cursor drag", "precision":"Precision cursor"}
const INPUTS := ["b0","b1","b2","b3","b4","b6","b7","b8","b9","b10","t4","t5"]
const NAMES := {"b0":"A", "b1":"B", "b2":"X", "b3":"Y", "b4":"View", "b6":"Start", "b7":"L3", "b8":"R3", "b9":"LB", "b10":"RB", "t4":"LT", "t5":"RT"}

static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != DEFAULTS.size(): return DEFAULTS.duplicate()
	var result := {}
	var used := []
	for action: String in DEFAULTS:
		var token: Variant = value.get(action)
		if not token is String or not INPUTS.has(token) or used.has(token): return DEFAULTS.duplicate()
		result[action] = token
		used.append(token)
	return result

static func swap_binding(value: Dictionary, action: String, token: String) -> Dictionary:
	var result := validate(value)
	if not DEFAULTS.has(action) or not INPUTS.has(token): return result
	var old: String = result[action]
	for other: String in result:
		if result[other] == token: result[other] = old; break
	result[action] = token
	return result

static func display(value: Dictionary, action: String) -> String:
	return str(NAMES.get(value.get(action), "?"))

static func help_text(value: Dictionary) -> String:
	var lines := PackedStringArray(["D-pad / left stick: grid, towers and menus (fixed)", "Right stick: cursor / camera (fixed)"])
	for action: String in DEFAULTS:
		lines.append(display(value, action) + ": " + TITLES[action])
	return "\n".join(lines)
