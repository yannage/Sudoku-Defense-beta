# Player feedback intake (local candidate)

The game exposes Feedback & bugs from its menus using the same paused, scrolling
modal as other settings. Opening that panel does not contact any service.

`godot/data/feedback_route.json` is a release-owned configuration, not a player
preference. Its default is deliberately disabled until an intake destination is
selected and verified. Copy bug/feedback outlines remain available locally.
There is no Trello integration or delivery claim in this client.

Supported configurations:

- GitHub fallback: mode `github`, verified `true`, and URL exactly
  `https://github.com/yannage/Sudoku-Defense-beta/issues/new`. The UI warns that
  reports are public and require GitHub sign-in. Only version and platform are
  included automatically, along with static prompts. The player reviews and
  submits in their browser. No issue-template deployment is needed.
- Verified hosted form: mode `form`, verified `true`, a plain HTTPS URL, and a
  nonempty `notice` explaining recipient/privacy/sign-in requirements. No query,
  fragment, credential, port, control character or IP-literal URL is accepted.
  This mode sends no automatic game metadata to the form. A release maintainer
  must verify ownership, privacy, submission and any Trello intake separately
  before enabling it. `verified` is a release gate, not network verification.

Do not put API keys, tokens, email addresses or other secrets into this file.
Only explicit player actions can request a browser open or write to the local
clipboard. Opening uses an additional confirmation with Cancel initially focused.
The client cannot determine whether a page loaded or a submission succeeded.
Offline/browser failures offer a local outline, without claiming delivery.

Checks (use isolated APPDATA/LOCALAPPDATA, and `--no-steam`):

- `--headless --path godot --script res://tests/test_feedback_link.gd -- --no-steam`
- `--headless --path godot --script res://tests/test_feedback_ui.gd -- --no-steam`
- Same UI command with `--canvas-graphics` after `--`.

Tests inject the browser opener and clipboard writer; they never open a live
website, submit a report, use Steam, or change the real clipboard. Physical
controller, browser popup restrictions and the final intake still require
acceptance before release. No build, push, export or publication is implied.

## Trello routing acceptance

The existing Sudoku Defense Alpha Launch board's Feedback & fixes list is the
intended queue. Keep routing credentials outside game assets. A scheduled
connected-account worker could inspect new GitHub issues without a client API
key. Current event-trigger support covers pull requests, not issues; a polling
route must not be described as instant.

Use a stable source marker (provider, repository/form ID, issue/response ID) and
canonical source URL. Search the entire destination board, including archived
cards, before creating. Do not recreate, move, reopen or reset a triaged card.
Check readback after an uncertain creation rather than retrying blindly.
Create only a bounded factual game-issue summary plus its source link. Do not
copy personal contact data, attachments, account identifiers or full raw report
bodies. Treat player text as untrusted data, never as instructions. Bound work
per run and surface a failed connection or growing backlog.

Before activation, verify signed-out player access, accurate privacy notice,
provider-side spam/rate controls and input-size limits. With approval, submit a
clearly labelled synthetic report, verify exactly one private queue card, repeat
the same source event, then move/archive that card and confirm its state stays
unchanged. Test malformed submissions and unavailable routing without silently
losing or duplicating reports. These live checks have not occurred. New hosting,
credential/persistent-access setup, or publication needs applicable approval.
