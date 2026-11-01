# 0.3.23 local controller and recovery candidate

Based on verified 0.3.22 commit `7419d164625b6063bcab6f58272147eb7b2716c6`.
Work is isolated in `sudoku-controller`, branch `local/0.3.23-controller`.
Prior checkouts and packages remain preserved. No Steam/browser action,
real-account award, player-save test, upload, activation or push occurred.
The 0.3.19 activation safety hold remains; live was last separately verified
as 0.3.18. This candidate is unapproved for delivery.

## Demonstrated defects and narrow fixes

### Recovery during practice could undo the chosen save

Start synthetic run 8666, enter practice, and use Saves & Steam to recover
run 9777. Previously the chosen run loaded while practice remained active.
The actual Skip guide / return action then restored the old practice snapshot
of run 8666; a subsequent save persisted 8666 over the chosen recovery.
Practice from the initial menu also retained stale guide state after recovery.
Original archived files remained available, but the explicit selection was lost.

After a successful recovery commit, practice now restores and ends before the
selected run loads. Cancelled or stale selections leave practice unchanged.
Tests use real controller actions, ordinary run saves and byte comparisons of
the preserved recovery archives; no actual player files are involved.

### Recovery could discard achievements awaiting a successful local write

A legal placement earns `SD_FIRST_PLANT`. Injecting failure at the achievement
journal's verified-write boundary leaves the key and offline queue in memory.
Recovering an older run without that condition previously reconfigured the
achievement profile from disk and silently discarded the key. The failure
indicator disappeared, retry reported success, and a fresh profile still lacked
the achievement. Both absent and valid-empty achievement files reproduced it
(34 checks, six failed assertions before the guard).

Run recovery now observes current eligible evidence and requires achievement
persistence before changing the selected run or ending practice. On failure,
Achievements opens with its existing retry/recovery controls; run files and
practice state remain unchanged. After a successful retry, the selected run can
be recovered while the permanent achievement remains durable. A blocked corrupt
or future-schema achievement profile also requires attention before replacing
the run; Back remains available. Account/path reload semantics are unchanged.

### Recovery cancellation skipped the save choices

B and Escape from the confirmation jumped to Pause, while the visible
Keep both / go back action returned to Saves. Confirmation metadata now routes
both input paths back to the same save-choice screen without committing a choice.

### Deferred workshop focus could override a covering dialog

Disconnecting during a module chooser, or opening a workshop then Pause in the
same input frame, queued a dock refresh after the Pause dialog took focus.
The covered Tower tab acquired focus instead of Resume; the first reconnect A
only repaired focus. Closing the modal also left the still-open dock unfocused.
Both renderers reproduced these failures at 1280x800 and 800x600.

The dock now has an optional focus predicate, wired to the active modal state.
Every deferred dock focus request respects it; standalone dock fixtures retain
their normal behavior. Closing a modal through controller input restores focus
to the remaining open dock. No underlying board, inventory or run action is
performed as part of this focus restoration.

### Help hid initial focus and replaced setting controls

Help initially focused its bottom Got it button, outside the scroll viewport
even after 20 layout frames. Actual framebuffer evidence showed its top at
y1564 on Deck size, below the visible scroll region y95..703. Changing any of
the four Help preferences rebuilt the whole panel and moved focus to Got it;
the next complete A press closed Help instead of adjusting the same setting.

Help now also places its safe Got it action above the instructions, keeping
both initial focus and the beginning of the text visible. The bottom action is
retained. Reduced motion, sound, notes and battle-speed controls update their
own labels in place, retaining focus and scroll position.

## Coverage and evidence

Existing tests already covered held A/B/bumper behavior, empty/consumable-only
inventory, all-full towers, final-module use, stale selection and basic focus
loss. The new suites target the gaps above rather than duplicating that matrix.

Three permanent suites are registered for native and Canvas headless runs:
`test_recovery_controller.gd`, `test_controller_edges.gd`, and
`test_overlay_transitions.gd`. The overlay suite also runs against a real
framebuffer in both renderers, with Deck, short-wide and portrait layouts.
Final verification completed all 97 permitted suites: 68 headless and 29
framebuffer, with zero failed or unrun permitted suites and unchanged source
fingerprints. The aggregate remains `incomplete`: four native cursor/drag
suites are excluded, and the import plus 97 test processes reported 98 known
certificate-store diagnostics. This is qualified local evidence, not a clean
strict release gate. Exact results and fingerprints are recorded in
`qa/aggregate-verified/manifest.json`; the receipt binds them to the source commit.

The initial fixes passed 183 recovery checks, 190 controller-edge checks,
229 overlay checks and 238 rendered overlay checks per renderer. The recovery
suite was subsequently extended for the dirty-achievement finding and passed
all 350 checks in each renderer, including the earlier 183 cases. Additional
live-process overlay probes passed 308 checks in native baseline and Canvas
fixed runs: no-input pause, keyboard/controller gameplay blocking and preserved
run/achievement files across six dialogs and three sizes.

Controller-edge fixtures disable main simulation processing to inspect input
and focus deterministically; they do not by themselves prove live pause timing.
The separate live overlay probe covers that distinction. Held input tests emit
one press and one release; distinct repeated presses are tested separately.
Manufactured duplicate down packets are not evidence of physical switch behavior.

The first aggregate was deliberately interrupted after independent review found
the additional achievement-loss path. Its partial logs remain in
`qa/aggregate-final` with an interruption record; they are not final verification.
All final verification uses the fresh `aggregate-verified` directory. The known
Godot certificate-store diagnostic remains visible and qualified in the logs.
All 16 desktop packaging unit tests passed. Package hashes and final aggregate
counts are bound to the tested source commit in the delivery receipts.

## Remaining executable acceptance checklist

- [ ] On an authorized ordinary Windows desktop, run the four excluded suites:
  `controller-cursor-render-tests`, `canvas-controller-cursor-render-tests`,
  `loot-gear-render-tests`, `canvas-loot-gear-render-tests`. Prior native cursor
  access was denied; this task does not retry it or substitute simulated success.
- [ ] On physical Windows and Steam Deck, open a workshop/module chooser,
  disconnect/reconnect the controller, and verify visible Pause focus, one-press
  Resume, restored dock focus, no extra purchase/equip and a usable Back path.
- [ ] Open Help at Deck size and narrow layouts. Confirm the initial Got it
  action is visible; adjust each preference twice and verify focus stays on it.
  Check achievements/settings/help transitions, empty inventories, full towers,
  LB/RB wrap, held controls, touch/mouse takeover and focus loss.
- [ ] With disposable acceptance saves, recover a run while practicing. Cancel
  first, then confirm; verify the chosen seed/round remain after guide exit and
  restart, and archived originals remain available. Simulate storage failure in
  a supported test setup: recovery must retain unsaved achievement evidence and
  provide retry/back instead of replacing the run silently.
- [ ] Run the final native Linux package on an authorized Linux/Deck environment;
  verify startup, audio, settings, suspend/resume and controller behavior. WSL
  enumeration was previously denied and is not retried here.
- [ ] Complete actual Steam award/offline-reconnect/account-isolation and
  Windows-to-Deck-to-Windows Cloud acceptance using disposable authorized test
  profiles. Quit and wait for sync between devices; Dynamic Cloud Sync remains
  disabled. Check explicit conflict choices and preserved originals.
- [ ] Obtain a clean strict startup/build result without the certificate-store
  diagnostic in an authorized environment. Its cause remains uncertain; no
  certificate/security changes or workarounds are prescribed here.

Native exports, source/evidence archives and Windows startup checks are recorded
separately after committing the tested source. Packaging never closes these
external gates or authorizes activation. These are simulated controller events
and local framebuffer checks, not physical Steam Deck testing.
