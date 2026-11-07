extends RefCounted
## Local-only report preparation. Never sends a report or contacts an endpoint.
const GITHUB_ISSUES := "https://github.com/yannage/Sudoku-Defense-beta/issues/new"
const CONFIG_PATH := "res://data/feedback_route.json"
const PLATFORMS := ["Windows", "Linux", "macOS", "Web", "Android", "iOS"]
var route: Dictionary = {}
var opener: Callable

func _init() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if parsed is Dictionary: route = parsed

func configured() -> bool:
	if route.get("verified", false) != true: return false
	if route.get("mode", "") == "github": return str(route.get("url", "")) == GITHUB_ISSUES
	if route.get("mode", "") != "form": return false
	var url := str(route.get("url", ""))
	# Release-owned, verified URLs only. No credentials, query data, ports,
	# fragments, IP literals, escapes or control characters in destinations.
	if not _safe_text(url, 512): return false
	var pattern := RegEx.new()
	pattern.compile("^https://[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*\\.[A-Za-z]{2,63}(?:/[A-Za-z0-9_./~-]*)?$")
	return pattern.search(url) != null and _safe_text(str(route.get("notice", "")), 400) and not str(route.get("notice", "")).is_empty()

func _safe_text(value: String, limit: int) -> bool:
	if value.length() > limit: return false
	for i in value.length():
		if value.unicode_at(i) < 32 or value.unicode_at(i) == 127: return false
	return true

func report_body(kind: String, version: String, platform: String) -> String:
	if kind not in ["bug", "feedback"] or not _safe_text(version, 32) or version.is_empty() or platform not in PLATFORMS: return ""
	var prompts := "What happened?\n\nSteps to reproduce:\n1. \n\nExpected result:\n\nActual result:\n" if kind == "bug" else "What would you like to share or improve?\n\nWhy would this help?\n"
	return "Sudoku Defense %s\nPlatform: %s\n\n%s\nDo not include passwords or personal information.\n" % [version, platform, prompts]

func report_url(kind: String, version: String, platform: String) -> String:
	var body := report_body(kind, version, platform)
	if not configured() or body.is_empty(): return ""
	if route.mode == "form": return str(route.url) # No game data transmitted to forms automatically.
	var title := "[Bug] " if kind == "bug" else "[Feedback] "
	return GITHUB_ISSUES + "?title=" + title.uri_encode() + "&body=" + body.uri_encode()

func open_report(kind: String, version: String, platform: String) -> int:
	var url := report_url(kind, version, platform)
	if url.is_empty(): return ERR_UNCONFIGURED
	if opener.is_valid(): return int(opener.call(url))
	return OS.shell_open(url)

func privacy_notice() -> String:
	if not configured(): return "Online feedback is not configured in this build. You can copy a report outline locally and keep it for later."
	if route.mode == "github": return "PUBLIC reports on GitHub. GitHub sign-in and an internet connection are needed. Opening a report includes only the game version and platform. Review it in your browser before submitting."
	return str(route.notice) + " An internet connection may be needed. No game data is added to the web form automatically. Review the form before submitting."
