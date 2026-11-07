extends SceneTree
const Link = preload("res://scripts/feedback_link.gd")
var failures := 0
var calls: Array[String] = []
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var link = Link.new()
	link.route = {} # Explicit disabled fixture, independent of the release route.
	link.opener = func(url: String) -> int: calls.append(url); return OK
	check(not link.configured(), "Explicit disabled route fails closed")
	check(link.open_report("bug", "0.3.25", "Windows") == ERR_UNCONFIGURED and calls.is_empty(), "No requests before configuration")
	link.route = {"mode":"github", "verified":true, "url":Link.GITHUB_ISSUES}
	check(link.configured(), "Fixed public GitHub fallback supported")
	var url: String = link.report_url("bug", "0.3.25", "Windows")
	check(url.begins_with(Link.GITHUB_ISSUES + "?title=%5BBug%5D%20&body="), "Title and body encoded")
	check(url.contains("Platform%3A%20Windows") and not url.contains("SteamID"), "Only version/platform metadata")
	check(link.report_url("other", "0.3.25", "Windows").is_empty(), "Kind bounded")
	check(link.report_url("bug", "x".repeat(33), "Windows").is_empty(), "Version bounded")
	check(link.report_url("bug", "hello\nInjected", "Windows").is_empty(), "Version controls rejected")
	check(link.report_url("bug", "0.3.25", "custom secret").is_empty(), "Platform allowlisted")
	check(calls.is_empty(), "Building preview does not open browser")
	check(link.open_report("feedback", "0.3.25", "Linux") == OK and calls.size() == 1, "Explicit open uses injected opener")
	link.opener = func(_url: String) -> int: return ERR_CANT_OPEN
	check(link.open_report("bug", "0.3.25", "Web") == ERR_CANT_OPEN, "Browser failure returned")
	link.route = {"mode":"form", "verified":true, "url":"https://example.com/feedback", "notice":"Example destination; reports handled privately."}
	check(link.configured() and link.report_url("bug", "0.3.25", "Windows") == "https://example.com/feedback", "Verified form receives no query data")
	check(link.report_url("feedback", "0.3.26-dev", "Web") == "https://example.com/feedback", "Both report types use the plain form URL")
	check(link.privacy_notice().contains("No game data is added"), "Form notice discloses no automatic metadata")
	for unsafe in ["http://example.com", "https://example.com@evil.test", "https://example.com/?token=secret", "https://127.0.0.1", "https://localhost", "https://example.com:123", "https://example.com/#x", "https://example.com/\n"]:
		link.route.url = unsafe
		check(not link.configured(), "Reject unsafe route " + unsafe)
	link.route.url = "https://example.com/form"
	link.route.verified = false
	check(not link.configured(), "Unverified destination rejected")
	print("FEEDBACK LINK TESTS: " + ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures else 0)
