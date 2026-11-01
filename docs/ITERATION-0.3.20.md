# 0.3.20 local polish candidate

Based exactly on 0.3.19 source `0b2e7278fe9b0985c0149247c323e7d8095bb386`.
This candidate lives in the isolated `sudoku-local-polish` clone on
`local/0.3.20-polish`. No push, upload, Steam activation, store change, or
account-achievement operation is part of this iteration. The separately
uploaded 0.3.19 build 26355721 and original checkout were left untouched.

## Confirmed fixes

- Achievement Back buttons draw their complete focus ring inside their bounds,
  including the clipped edges at the top and bottom of the scrolling list.
  Middle/end scrolling and A/B return behavior remain covered.
- Narrow landscape HUD buttons now have space for their actual font/padding
  minimum height. At 844 x 390 the previous nine number buttons overlapped
  footer hints by 10 logical pixels. The footer and board clearance now reserve
  the additional space. Six window shapes are checked in both renderers.
- Singular count copy now reads `1 unlock`, `1 tower grown/active`, and
  `1 enemy left/on route`. Plural cases remain checked.
- First-time Steam migration records the owning account before copying legacy
  progress. Previously, if account A's copy committed but the completion claim
  failed, account B launching next could copy the same run and achievements.
  Synthetic regressions reproduce both cases and check retry by A, preservation
  of the originals, failed reservation, and failed copy.

No additional offline queue or journal backup defect was demonstrated. Existing
durable queue, backup, future-schema, external-change, and explicit-conflict
tests remain part of the regression pass. No production controller routing was
changed; new held A/B/LB/RB checks cover rebuilt menus and chooser wrap.

## Local verification

All engine runs use `--no-steam` and isolated APPDATA/LOCALAPPDATA profiles.
Steam behavior is mocked; test profiles never award to a real account.

The untouched strict build runner was attempted. Its simulation assertions
passed 1,338 checks, but it stopped on the sandbox engine error
`ERROR: Failed to read the root certificate store.` This is not a clean
production aggregate pass.

The accompanying `qa/run_local_checks.py` adapter collects the same canonical
test list from `build_exports.py`, executes every suite, and preserves raw logs
and process exit codes. It records that exact environment error separately;
all other engine errors, nonzero exits, missing completion markers, timeouts,
and source changes fail the run. Windows framebuffer checks use the installed
NVIDIA OpenGL driver (`opengl3`) instead of the Linux CI GLES driver.

The final aggregate ran all 90 suites: all 59 headless suites and 27 of 31
framebuffer suites passed their assertions with the certificate-store
qualification. Four framebuffer suites failed: controller cursor and loot/gear
dragging, each in native and Canvas modes. Their native OS pointer coordinates
were invalid. All four failures reproduce with exactly the same assertion-error
lists and identical test scripts in a separate untouched 0.3.19 baseline. This
establishes that they predate this candidate under the same hidden Windows
setup; it does not establish normal-window or physical controller behavior.
The full aggregate therefore remains **failed**, and native packaging is held.
The delivery evidence contains the baseline comparison,
raw logs, exact commands, unchanged-source hashes and source artifact hashes.
The 16 Python desktop packaging unit tests pass. A separate read-only code
review found no actionable issue.

Reproduction evidence includes four failing platform UI assertions (focus
outline at three boundaries and singular unlock text), fourteen HUD assertions
(nine overlaps and five singular counts), and two interrupted migration
account-boundary assertions. The fixed rendered platform suite passes 189
checks; each rendered HUD suite passes 483 checks. Held controller upgrade
coverage passes 521 checks per renderer.

## Compatibility limits

The migration fix prevents new interrupted copies from losing account ownership.
It does not scan other account folders to reconstruct an old 0.3.19 orphan copy
that already has no device claim. If 0.3.20 stops after reserving ownership but
before any copy finishes, 0.3.19 blocks safely on the empty-source reservation;
finish migration in 0.3.20 before rollback. Ordinary completed claims remain
compatible. See [Cloud paths and recovery](STEAM-CLOUD.md).

## Executable device acceptance

Use a backed-up, disposable acceptance profile. Record OS, device, candidate
version, launch method, account, and pass/fail for each step. Never reset or
fabricate real account achievements to test the API.

1. **Windows local startup and input:** first rerun the four failing rendered
   pointer/drag suites on a working native display and complete the strict
   aggregate. After packaging, launch the candidate from an isolated
   profile. Start/resume a run, place a number, inspect a tower, select an empty
   socket, choose a module, and confirm once. Hold A across each transition;
   confirm it never advances twice. Verify all menus can be exited with B.
2. **Physical Steam Deck:** when delivery is separately authorized, launch the
   tested build from the Steam library. Check D-pad/stick movement, number tray,
   both LB/RB wrap directions, full/empty inventories, repeated confirm/cancel,
   achievement list middle/end, focus outlines, touchscreen handoff, and 8x
   controls. Disconnect/reconnect the controller and suspend/resume the Deck.
   Confirm graphics, performance, audio, and continued save state on hardware.
3. **Natural Steam unlock:** play normally and earn an ordinary achievement.
   Confirm the overlay/account award and local queue acknowledgement. Earn
   another naturally offline, restart offline, then reconnect; confirm one
   eventual award without replay. Repeat account switching with separate
   backed-up acceptance progress.
4. **Windows to Deck Cloud:** record seed, round, phase, health, inventory, gear,
   and achievement progress. Quit normally, wait for Steam's Up to date status,
   launch the same account on the second device, and compare every value.
   Make progress there and repeat in the reverse direction. Test Cloud disabled.
5. **Conflict recovery:** only with disposable acceptance saves, create divergent
   progress and verify explicit recovery keeps both originals archived and
   preserves the chosen run. Do not replace a real player's save with a fixture.
   Dynamic suspend/resume Cloud syncing remains disabled; quit before switching
   devices. Forced Proton needs a separate Windows-path acceptance pass.

Browser gameplay, authenticated Steam launch/unlocks, two-device synchronization,
Linux executable startup, and physical Windows/Deck input are not established
by the local synthetic or framebuffer checks. The paused Steam delivery and
browser approval remain with their original task; this iteration does not
retry or bypass them.
