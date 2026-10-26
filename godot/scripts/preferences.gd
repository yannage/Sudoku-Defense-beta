extends RefCounted
## Device-local accessibility and presentation choices, independent of run saves.

const DEFAULTS := {"muted": false, "reduced_motion": false, "board_notes": true}
var file_path := "user://sudoku-defense-settings.json"

func read_settings() -> Dictionary:
	var settings := DEFAULTS.duplicate()
	if not FileAccess.file_exists(file_path): return settings
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null: return settings
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return settings
	for key: String in DEFAULTS:
		# Strings such as "false" must never silently become true.
		if typeof(parser.data.get(key)) == TYPE_BOOL:
			settings[key] = parser.data[key]
	return settings

func write_settings(settings: Dictionary) -> bool:
	var validated := DEFAULTS.duplicate()
	for key: String in DEFAULTS:
		if typeof(settings.get(key)) == TYPE_BOOL:
			validated[key] = settings[key]
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
