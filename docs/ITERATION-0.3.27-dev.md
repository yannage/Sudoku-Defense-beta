# Sudoku Defense 0.3.27-dev integration candidate

Karen's usability changes are integrated into the 0.3.26 development source on
`integration/karen-on-0.3.26`, starting at
`deac20b736975c2e52b13cf3eaf79fa7eb8ba188`. This candidate has not been uploaded or
activated on Steam. The original `sudoku-feedback-controls` checkout is retained.

## Provenance and scope

The user-downloaded `Sudoku-Defense-Karen-Usability.zip` is 38,064 bytes, SHA-256
`fce8df84e6cc3ce98f7b680a9b021846aebccf78efa4669dd1805e79fd13c277`.
Its three expected members are `Karen-Usability.patch`, `README.txt`, and
`Feedback-and-validation.md`. The patch identifies source commit
`be8d851f7b803c918a43463f486684f8a79cf9be` on older base
`36a84ac88533dead6ae9f85e468e657dc746901d` / 0.3.15. Conflicting hunks were merged
individually; older files did not replace 0.3.26 wholesale. The supplied historical
feedback record is retained in [KAREN-FEEDBACK-2026-11-07.md](KAREN-FEEDBACK-2026-11-07.md).

- Controller focus scrolls Camp and Gear in both directions. Start opens direct
  Gear, Chests and Camp actions. Setup/combat navigation visits planted towers;
  Solve retains cell and number navigation, and Reserve seeds explicitly opens
  combat planting.
- Gear supports manual selection of multiple owned modules for one tower, effect
  filters and atomic installation. Single-module installation stays on its tower
  with the next empty socket focused. Full sockets and inventory availability
  remain explicit; there is no automatic distribution among towers.
- Open All opens affordable chests in collected order at existing prices and
  reward odds. A persistent opt-in setting can open affordable chests at safe
  management moments, deferring combat, menus, tutorials and pointer gestures.
- Combat hides fixed clue digits/highlights and the ordinary number tray, while
  tower-family badges and the explicit reserve action remain. Help and next-round
  text explain module returns and new-board equipment resets.

Controller remapping, feedback routing, wrong-answer time penalties, guarded run
recovery, account-separated saves, audio settings and achievements remain from
0.3.26. Batch equipment updates achievement facts, and bulk chest opening reuses
the existing per-chest reward and achievement path. No shop/selling progression,
harder-mode expansion, pricing changes or new agreements were introduced.

## Verification and local delivery

`qa/run_local_checks.py` remains the canonical permitted aggregate adapter. The
candidate adds eight headless suite/renderer combinations, making 119 permitted
jobs. Each process uses an isolated profile and `--no-steam`. Four previously
restricted native cursor/drag render jobs remain excluded; aggregate status is
therefore deliberately `incomplete` even when all permitted jobs pass.

Final evidence is recorded in `qa/karen-final/manifest.json`; earlier diagnostic
passes remain separately named. `qa/render_karen.py` adds six sequential real
OpenGL screenshot checks for Deck/portrait management, module filters, rewards,
controller navigation and reserve layout. The settled 22-capture evidence is in
`qa/karen-visual-settled/manifest.json`. It does not use native cursor warps or
the restricted drag suites. Packaging contract tests are retained in
`qa/karen-packaging-tests.log`.

`qa/package_local_v27.py` and `qa/prepare_steam_delivery_v27.py` require the frozen
full source commit and completed matching aggregate, use canonical export/payload
helpers, and verify Windows exported startup headlessly and with rendering. They
produce Windows/Linux ZIPs and a complete 12-file shared-depot ZIP, preserving the
Linux launch path `sudoku-defense` and executable permissions. No Steam upload or
activation is performed. See the delivery preflight manifest for exact source,
hashes, logs and runtime qualifications.

Linux execution, physical Steam Deck controls/GPU, the four restricted native
pointer suites, and real Steam/Cloud/two-device behavior require separate
acceptance. A successful Windows cross-export is not a Linux runtime result.
The checked-in app VDF targets Linux-only content and must not be invoked
unchanged for the complete desktop candidate.
