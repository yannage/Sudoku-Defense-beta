# 0.3.26-dev: controller mappings and feedback handoff

This is an isolated, local development candidate based on current 0.3.25
(`21d132aa7827767240a4160108b304bff71063c2`). It preserves the wrong-guess timer
penalty, run recovery, Steam account separation and achievement protections.
The frozen 0.3.25 source and prepared delivery artifacts remain unchanged.
No Steam upload/activation, public push, merge or website publication occurs.

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
logs, saves, Steam IDs or email. The checked-in route is deliberately disabled
until an approved intake and its Trello routing pass live acceptance. This is
not a completed live feedback-to-Trello service. See FEEDBACK-INTAKE.md.

## Validation and remaining gates

The new model and UI suites are registered in the canonical build helper.
111 permitted Godot suites passed: 78 headless and 33 render, plus 16 Python
packaging tests. The initial aggregate passed 109 suites; two new portrait
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

Four previously restricted native cursor/drag suites stay excluded, and no
substitute route is used to bypass them. Physical Windows/Deck input, real
Steam/Cloud acceptance and live feedback delivery remain unverified. This is
source-only local work, not a new release or a claim of full release readiness.
