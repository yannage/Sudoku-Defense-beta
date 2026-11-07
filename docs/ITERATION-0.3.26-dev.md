# 0.3.26-dev: controller mappings and feedback handoff

This is an isolated, local development candidate based on current 0.3.25
(`21d132aa7827767240a4160108b304bff71063c2`). It preserves the wrong-guess timer
penalty, run recovery, Steam account separation and achievement protections.
The frozen 0.3.25 source and prepared delivery artifacts remain unchanged.
No game export, Steam upload/activation, public push or merge occurs. The
separate no-account feedback form is live; this game candidate remains unreleased.

## Controller settings

Open Pause or How to play, then Controller mapping. Reassign twelve actions
across the standard face buttons, shoulders, View, Start, stick clicks and
triggers. Assigning an occupied input swaps the other action, keeping every
action reachable. Changes are staged until Save; Cancel discards them and
Reset prepares defaults without silently applying them. A failed save leaves
the last working mapping active. Invalid or duplicate saved bindings fall
back to the complete default map.

The mapping screen keeps A/confirm, B or Start/back, and D-pad/left-stick
navigation fixed so a mistaken gameplay map cannot trap the player. In capture,
D-pad Left or Escape cancels. D-pad/left-stick navigation and right-stick axes
remain fixed; this feature remaps buttons/triggers, not stick axes/deadzones.
Mappings are device-local settings, independent of run saves, and are shared
by controllers on that local profile. They are not per-controller profiles.

## Feedback handoff

Feedback & bugs is available in the menus. A player can copy a bug/suggestion
outline; configured online routes require deliberate confirmation before
requesting a browser open. The game never submits a report itself or attaches
logs, saves, Steam IDs or email. The checked-in route now opens the approved
no-account form at https://sudoku-defense-feedback.yakstudios.chatgpt.site.
Submitted reports remain private to YAKStudios and its Trello triage board.
Anonymous intake, privacy, duplicate/conflict handling and one synthetic
Trello delivery passed live checks. Hourly routing is enabled; its first
scheduled run completed with zero duplicates and zero backlog. See
FEEDBACK-INTAKE.md.

## Validation and remaining gates

The new model and UI suites are registered in the canonical build helper.
The initial candidate validation passed 111 permitted Godot suites: 78 headless
and 33 render, plus 16 Python packaging tests. The initial aggregate passed 109 suites; two new portrait
visual assertions compared logical and physical coordinates. After correcting
only that test assertion, both affected suites passed on rerun. Production
source hashes were unchanged between those runs. Whitespace lint then removed
extra EOF blank lines from three new feedback files; all seven feature suites
passed again against the final source. No production logic changed. There were
no known-environment error exceptions and no run observed changing source.

`qa/verification-summary.json` records this combined result and links the
unaltered initial aggregate and final visual rerun manifests, logs and exact
source hashes. Screenshots cover native/Canvas at 1280x800 and 390x844.
Representative screenshots were inspected for readable layouts and focus.

The enabled-form follow-up passed 21 focused suites against the final source:
19 headless plus two render suites. It covers feedback URL validation, actual
installed-route UI through an injected opener, explicit disabled/form fixtures,
controller mapping, edges, recovery, overlays, preferences, number picking,
upgrades and normal controller flow in native/Canvas modes. All processes used
isolated profiles and `--no-steam`; no browser was opened or report submitted.
No source changed during the run and there were no known-environment errors.
Installed-form screenshots at portrait and Deck sizes were reviewed for
readability, clipping and safe confirmation focus. Evidence is in
`qa/form-route-summary.json` and `qa/form-route-final/manifest.json`. The earlier
111-suite result is historical, not a full aggregate rerun for this follow-up.

Four previously restricted native cursor/drag suites stay excluded, and no
substitute route is used to bypass them. Physical Windows/Deck input, real
Steam/Cloud acceptance and actual exported browser popup behavior remain
unverified. Live intake and one synthetic Trello delivery are verified separately.
This is source-only local work, not a new release or a claim of full release readiness.
