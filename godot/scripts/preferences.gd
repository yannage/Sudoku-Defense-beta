extends RefCounted
## Device-local accessibility and presentation choices, independent of run saves.

const DEFAULTS := {"muted": false, "reduced_motion": false, "board_notes": true,
	"master_volume": 0.85, "music_volume": 1.0, "effects_volume": 1.0}
var file_path := "user://sudoku-defense-settings.json"

func read_settings() -> Dictionary:
	var settings := DEFAULTS.duplicate()
	if not FileAccess.file_exists(file_path): return settings
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null: return settings
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return settings
	return validate(parser.data)

func validate(settings: Dictionary) -> Dictionary:
	var validated := DEFAULTS.duplicate()
	for key: String in DEFAULTS:
		var value: Variant = settings.get(key)
		# Legacy boolean settings keep their meaning; strings never become true.
		if typeof(DEFAULTS[key]) == TYPE_BOOL:
			if typeof(value) == TYPE_BOOL: validated[key] = value
		elif typeof(value) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(value)):
			validated[key] = clampf(float(value), 0.0, 1.0)
	return validated

func write_settings(settings: Dictionary) -> bool:
	var validated := validate(settings)
	var temporary := file_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(validated))
	file.flush()
	var status := file.get_error()
	file.close()
	if status != OK:
		DirAccess.remove_absolute(temporary)
		return false
	# Replace only after a complete write; never truncate the prior settings.
	var renamed := DirAccess.rename_absolute(temporary, file_path)
	if renamed != OK: DirAccess.remove_absolute(temporary)
	return renamed == OK
