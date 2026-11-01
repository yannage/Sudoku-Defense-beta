# 0.3.21 local reliability candidate

Based on fixed local 0.3.20 source `dbcca63085fe0b6c3cdfa1e37bd04ce284a1e630`.
The isolated clone is `sudoku-reliability`, branch `local/0.3.21-reliability`.
This candidate is unapproved for delivery. The original 0.3.19 checkout and
uploaded candidate remain untouched and on safety hold. The last separately
verified live version remains 0.3.18. No push, upload, Steam setting change,
activation, real account achievement, or player-save test was performed.

## Demonstrated defects

### Achievement read crossed an account boundary

The adapter validated the Steam identity before `getAchievement`, then accepted
the returned value without checking identity again. A mocked account/app switch
inside that native call reproduced six failing regression assertions. The real
profile layer could persist the returned unlock under the previous account before
the next query detected the switch. This does not depend on Cloud being enabled.

The adapter now validates identity immediately after the call and discards the
response if it changed. The session becomes unavailable, and foreign evidence
never reaches the profile or disk. No production profile or achievement-rule
change was necessary; the 26 achievement names, requirements and mapping remain
unchanged.

### External progress could be overwritten during a journal operation

Preflight checks only protected changes already present before a save started.
A synthetic external writer replacing primary, pending or backup data during
snapshot/backup staging could have that data overwritten. When an I/O operation
failed, observing the new disk state also allowed an ordinary retry to overwrite
it. Promotion and recovery-choice enumeration exposed related stale-state gaps.

The journal now carries the expected committed-file state through reads,
staging and promotions, rejects detected changes, and keeps a failed external
change from becoming the retry baseline. Recovery candidates must come from a
stable snapshot. Explicit recovery still archives the originals and requires a
current choice. Run data, achievement profiles and migration claims share these
guards; no save schema or Cloud path changed.

These checks detect changes at the tested file-operation boundaries. They do not
provide an operating-system lock or atomic compare-and-rename against arbitrary
concurrent writers. Steam Auto-Cloud remains a between-session workflow; dynamic
in-game/suspend synchronization is not being enabled.

## Added regression coverage

- Journal interruptions at actual verified-write and rename boundaries, both
  legacy and account-scoped staging; recovery, corrupt/future schemas, changed
  files during operations and fresh-instance retry behavior.
- 72 migration cases: 18 reservation/copy/completion boundaries, two data types,
  and both A-first/B-first restart orders. Before a reservation commits there is
  no A copy; afterward B cannot acquire A's evidence. Counters, RNG and originals
  remain intact. Corrupt/future claims and reservation backup recovery are covered.
- Five acknowledgement-write failure stages, offline restart persistence,
  account/adapter replacement, detached callbacks, in-flight conflicts, and
  timeout/restart reconciliation through the real adapter/profile boundary with
  a mocked Steam gateway.
- A complete guided practice round exercises placement, module, wave and chest
  counters while leaving the original achievement journal byte-identical. Reload
  retains only the real run's queued unlock; replay and menu practice are checked.

The migration and journal suites are registered in the canonical build helper.
All engine tests use synthetic profiles, redirected APPDATA/LOCALAPPDATA and
`--no-steam`. No tests award or reset an actual Steam achievement.

## Focused verification

| Suite | Assertions passed |
| --- | ---: |
| Journal failure/recovery matrix | 1,300 |
| Migration matrix | 1,190 |
| Achievement profile | 411 |
| Steam adapter/profile integration | 112 |
| Existing run-save suite | 119 |
| Existing Cloud profile suite | 132 |
| Complete guided practice | 67 per renderer |

The 16 desktop-packaging Python unit tests pass. Engine results retain the known
`ERROR: Failed to read the root certificate store.` startup diagnostic; these
are qualified assertion passes, not a clean production aggregate. The initial
unchanged 0.3.20 baseline passed all 59 headless suites under that qualification.
Final aggregate counts, unchanged-source fingerprints and independent review
are included in the delivery receipt and evidence archive.

The first integrated aggregate caught a test-harness signature mismatch: the
new migration fault injector had not forwarded the journal's expected-state
argument. The hook was corrected, and all 1,190 integrated migration checks
passed. That failed aggregate remains in `qa/aggregate-final`; the fresh final
pass is `qa/aggregate-verified`. No production change was made for this harness
correction. Earlier draft test failures remain in the evidence with their causes.

## Release acceptance still required

1. On an ordinary supported Windows test desktop, run the four native cursor and
   loot/gear drag framebuffer suites in both renderers, then the complete strict
   aggregate. This task does not retry the denied native cursor path. Exercise
   physical controller navigation, empty sockets, LB/RB wrap, held/repeated A/B,
   focus at achievement-list top/middle/end, touch/mouse handoff and narrow layouts.
2. Resolve the engine certificate-store diagnostic in an authorized environment
   and obtain a clean strict build/startup result. No certificate or security
   settings were changed here; successful assertions do not waive this gate.
3. Validate the final source in Windows and Linux/Steam Deck exports and on actual
   hardware, including startup, audio, performance, suspend/resume and reconnect.
   Earlier 0.3.20 packages do not contain the fixes in this iteration.
4. When separately authorized, earn achievements naturally with an acceptance
   account, including offline earning/restart/reconnect. Verify acknowledgement,
   account switching and session restart after timeout. Mock callback coverage
   does not establish arbitrary callback duplication during a later active batch;
   the native StoreStats callback has no request identifier.
5. With backed-up disposable saves, quit and wait for Steam sync, compare the run
   and achievements on Windows and Deck in both directions, test Cloud disabled,
   and resolve a deliberate divergence while retaining archived originals. Forced
   Proton needs its own Windows-path acceptance. Never use real player saves as
   fault-injection fixtures.

Browser gameplay approval, Steam delivery/activation, native cursor access and
WSL/Linux execution restrictions remain with their original tasks. None was
retried or bypassed. The final source commit, full test counts, raw logs and
artifact hashes are recorded in the accompanying local delivery receipt.
