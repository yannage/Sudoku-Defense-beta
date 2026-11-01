# 0.3.22 local progression candidate

Based on verified 0.3.21 commit `223ed8019a82bdcff4d7f1ca37a0ec93119f1a6c`,
in isolated clone `sudoku-progression`, branch `local/0.3.22-progression`.
Original checkouts and packages are preserved. This is an unapproved local
candidate: no push, upload, Steam changes, activation, real achievement awards,
or player-save tests. The uploaded 0.3.19 activation safety hold remains;
last separately verified live version is 0.3.18.

## Demonstrated save/resume defect

An uninterrupted and journal-restarted Locked In run (seed 9137, hard Sudoku,
hard combat) first diverged during round 49. Default JSON serialization rounded
an enemy poison timer from `1.6500000000000032` to `1.65`. The simulation checks
for a positive timer before applying a 0.05-second tick. Rounding removed one
tick: 38.73096 poison DPS multiplied by 0.05 seconds = **1.936548 damage**.
Both enemy HP and the tower's damage report differed. Tower 49:16 reported
6874.88346661865 damage uninterrupted and 6872.94691861865 after restart.

A three-way probe used the same naturally reached checkpoint: direct in-memory
load, default JSON, and full-precision JSON. Only default JSON produced this
combat divergence. The reproduced run still had the same victory, kills,
currency, RNG and awards; there is no evidence here of a different win/loss or
achievement outcome. A damage-report-only explanation would be inaccurate.

Normal journal writes and explicit recovery now request full-precision JSON.
These are the only two production behavior changes. Save schema, paths, timer
rules, difficulty, economy and achievement conditions are unchanged. Original
backup/archive bytes and parent hashes remain based on original file contents.
The change prevents the demonstrated rounding loss; it does not retroactively
recover precision discarded by an older save or promise universally bit-exact
floating-point parsing. The precision probe still measured smaller numeric
round-trip differences that did not affect this tested combat result.

## Regression and progression evidence

The canonical build now includes `test_progression_resume.gd`, with a public-action
perfect-information player. It plays full Campaign 4093 medium/medium and Locked
In 9137 hard/hard runs, plus Free Play, comparing actual journal restarts at solve,
launch, mid-wave, settled and opened-chest checkpoints. A partial solve/prep/gear
restart and untracked-to-normal achievement isolation scenario are included.
Integer values, RNG and earned keys compare exactly; float state compares with
a relative tolerance of 1e-7. A failed first-difference check is not evidence
that other fields match. The original run failed 13 assertions, retained in QA.

The journal fault suite also tests the exact reduced timer boundary in both
ordinary and account-staged writes and recovery, including byte-identical
archival of older JSON and correct parent hashes. This is a serialization probe;
the full-run suite supplies the actual gameplay reproduction.

The independent pre-fix progression matrix passed 56,858 checks across 153
cleared waves: three 50-round runs and three single-round Free Plays. The
settlement/economy matrix passed 4,406 checks, including real round-5 boss kill
and boss leak branches, repeated settlement rejection, upgrades, gear ownership,
chests and slot ledgers. Targeted achievement play passed 691 checks and, together
with full-run evidence, witnessed all 26 conditions without setting award flags.
These runs exercise unchanged gameplay code; the final resume suite validates
the new persistence behavior. See the companion acceptance document for the
complete mapping, seeds, action evidence and remaining gates.

The final permitted aggregate passed all **89 suites: 62 headless and 27
renderer checks**, with zero failed or unrun permitted jobs and unchanged source
fingerprints. It remains **incomplete**, because four denied pointer/drag suites
were excluded; 90 known certificate diagnostics (import plus engine suites) are
retained. The journal suite passed 1,318 checks and the full resume suite passed
23,146 checks across 68 actual restarts. All 16 desktop packaging unit tests pass.
Exact commit, package results and hashes are recorded in the delivery receipts.
Engine runs use disposable synthetic profiles, redirected APPDATA/LOCALAPPDATA
and `--no-steam`. The known certificate-store diagnostic is retained. Four
previously denied native pointer/drag tests are excluded, never silently passed.

## Limits and remaining acceptance

These are finite-seed correctness simulations using the known Sudoku solution,
not evidence of human solve difficulty, fun, balance, input feel or performance.
Free Play intentionally has one wave. No economy or difficulty tuning was made.

Required external acceptance remains ordinary Windows and physical Steam Deck
input/rendering, the four native pointer/drag suites, Linux executable startup,
real Steam achievement/offline lifecycle, and two-device Cloud recovery/sync.
The root-certificate-store diagnostic remains unresolved; no certificate or
security settings were changed. Browser and Steam delivery permissions remain
outside this local pass, and denied cursor/WSL operations were not retried.
