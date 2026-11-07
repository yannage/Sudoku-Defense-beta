extends RefCounted
## Uses the shared modal so feedback pauses the run in either renderer.
const FeedbackLink = preload("res://scripts/feedback_link.gd")
var host
var service = FeedbackLink.new()
var status: Label
var pending_kind := "bug"
var copy_writer: Callable
var browser_requested := false
var open_button: Button

func _text(box: VBoxContainer, text: String, color: Color, size: int = 16) -> Label:
	var node: Label = host.label(text, size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(node)
	return node

func _action(box: VBoxContainer, text: String, callback: Callable, id: String) -> Button:
	var node: Button = host.button(text, callback, true)
	node.set_meta("focus_id", "feedback:" + id)
	box.add_child(node)
	return node

func _version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "unknown"))

func _platform() -> String:
	return "Web" if OS.has_feature("web") else OS.get_name()

func show_panel() -> void:
	var box: VBoxContainer = host._modal(720, 660)
	host.overlay.set_meta("feedback_panel", true)
	_text(box, "FEEDBACK & BUGS", host.MINT, 27)
	_text(box, service.privacy_notice(), host.AMBER)
	_text(box, "Do not include passwords or personal information. No logs, saves, Steam IDs or email addresses are collected by the game. Nothing is submitted automatically.", host.MUTED)
	_text(box, "Report details: Sudoku Defense %s / %s" % [_version(), _platform()], host.WHITE)
	var first := _action(box, "Report a bug", func(): _confirm("bug"), "bug")
	var feedback := _action(box, "Share feedback", func(): _confirm("feedback"), "idea")
	first.disabled = not service.configured()
	feedback.disabled = first.disabled
	_action(box, "Copy bug report outline", func(): _copy("bug"), "copy_bug")
	_action(box, "Copy feedback outline", func(): _copy("feedback"), "copy_feedback")
	status = _text(box, "Copy writes to your clipboard; the game does not send it. Your device clipboard settings may sync it. If offline, keep the outline for later.", host.MUTED, 14)
	var back_button := _action(box, "Back", back, "back")
	if first.disabled: back_button.grab_focus()
	else: first.grab_focus()

func _confirm(kind: String) -> void:
	pending_kind = kind
	browser_requested = false
	var box: VBoxContainer = host._modal(720, 560)
	host.overlay.set_meta("feedback_panel", true)
	host.overlay.set_meta("feedback_confirmation", true)
	_text(box, "OPEN REPORT IN BROWSER?", host.MINT, 25)
	_text(box, service.privacy_notice(), host.AMBER)
	_text(box, "Do not include passwords or personal information. No logs, saves, Steam IDs or email addresses are attached. The game stays paused.", host.MUTED)
	open_button = _action(box, "Open browser", _open, "open")
	status = _text(box, "You will review and submit the report yourself on the website.", host.MUTED)
	var cancel := _action(box, "Cancel", show_panel, "cancel")
	cancel.grab_focus() # A repeated confirm must not launch an external site.

func _open() -> void:
	if browser_requested: return
	var error: int = service.open_report(pending_kind, _version(), _platform())
	if error != OK:
		status.text = "Could not open the browser. Go back to copy an outline and try again when online. No report was sent."
	else:
		browser_requested = true
		open_button.disabled = true
		status.text = "Browser open requested. No report has been sent by the game. If the page does not load, go back to copy an outline and try later."

func _copy(kind: String) -> void:
	var text: String = service.report_body(kind, _version(), _platform())
	if copy_writer.is_valid(): copy_writer.call(text)
	elif DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD): DisplayServer.clipboard_set(text)
	else:
		status.text = "Clipboard is unavailable. Report details: Sudoku Defense %s / %s. Nothing was sent." % [_version(), _platform()]
		return
	status.text = "Report outline copied to clipboard. The game did not send it."

func back() -> void:
	if is_instance_valid(host.overlay) and host.overlay.get_meta("feedback_confirmation", false):
		show_panel()
	else:
		host._show_menu(not host.has_active_run)
