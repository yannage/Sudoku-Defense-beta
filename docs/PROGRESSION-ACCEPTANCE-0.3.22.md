# 0.3.22 progression and achievement acceptance

**Status: unapproved local 0.3.22 candidate; external release acceptance remains open.**
The full-run, targeted-achievement and settlement matrices below were collected
on 0.3.21 source `223ed8019a82bdcff4d7f1ca37a0ec93119f1a6c`; those gameplay
systems are unchanged. The final verification record distinguishes the new
persistence regressions and aggregate on 0.3.22. No push, upload, activation, Steam setting change,
real achievement award, or real player-save test is authorized by this document.
The original 0.3.19 candidate remains on hold. The last separately verified live
version remains 0.3.18.

## Final verification record

| Required record | Current status |
| --- | --- |
| Final 0.3.22 source commit and patch | Exact commit in accompanying `RECEIPT.json`; `0.3.21-to-0.3.22.patch` and incremental Git bundle |
| Narrow save-precision regression, including journal recovery writes | 1,318 journal checks passed; `qa/journal-precision-fixed/manifest.json` |
| Interrupted/resumed full-run comparison after fix | 23,146 checks passed across 68 real journal restarts; `qa/resume-fixed/manifest.json` |
| Affected suites and permitted aggregate after final edits | 89 suites passed (62 headless, 27 renderer), zero failed/unrun, unchanged source; aggregate remains incomplete for four exclusions and qualified by the certificate diagnostic. `qa/aggregate-final/manifest.json` |
| Independent final diff/evidence review | Narrow fix, original reproduction, post-fix comparison and all 26 witnesses reviewed; `qa/evidence-review.md` |
| Final native package hashes and packaged startup | Post-commit export/validation is recorded separately in the accompanying native `RECEIPT.json`; prior packages do not contain this fix |
| Four native cursor/drag renderer checks | Unverified: prior native cursor access was denied; not retried here |
| Clean strict startup/build without certificate diagnostic | Unverified in this environment |
| Physical Windows/Deck input, real Steam awards, two-device synchronization | Unverified; requires separate acceptance |

## Demonstrated save/resume defect

An actual Locked In run, seed 9137 with Hard puzzle and Hard combat, reached
round 49 using legal actions and earned resources. Saving mid-wave with the
default journal JSON serializer changed an enemy's poison duration from
`1.6500000000000032` to `1.65`. Combat updates use steps of at most 0.05 seconds.
The uninterrupted duration retained a tiny positive remainder after 33 steps,
so it received one more poison tick; the resumed duration reached zero sooner.

This produced **1.936548 less poison damage** after resume: 38.73096 damage per
second multiplied by 0.05 seconds. At the first divergence, enemy 4652 had
211.17478351246913 HP uninterrupted and 213.11133151246958 HP after default JSON
restoration. Its poison source stayed tower 16. Tower 49:16's final recorded
damage was 6874.88346661865 versus 6872.94691861865. This is a real combat-state
difference, not just a different printed decimal or attribution to another tower.

In this reproduction, terminal outcome, kills, credits, core health, RNG state
and earned achievement keys stayed the same. No changed achievement or lost run
has been demonstrated. Damage contributes to the player's result summary.
Direct dictionary restoration and the probe's full-precision JSON restoration
matched the uninterrupted damage result. The 0.3.22 correction targets journal
serialization precision. Both ordinary writes and recovery writes passed their
new regression. It does not imply universally bit-exact JSON round trips:
the full-precision probe still observed small numeric differences elsewhere.

The original resume matrix recorded **23,146 checks, 13 failed comparisons,
68 restart checkpoints**. The repeated failures retained this round-49 damage
difference into later comparisons. That failed evidence remains available. The
fresh post-fix run passed all 23,146 comparisons/checks and 68 restarts; recorded
terminal resources, RNG, outcomes and earned keys also match the original run.

Evidence: `qa/resume-initial/manifest.json`, `qa/resume-initial/engine.log`,
`qa/resume_precision_probe.gd`, `qa/precision-probe/`, and
`qa/resume-diagnosis-readonly.md`.

## All 26 achievement conditions and real witnesses

The canonical catalog is `godot/data/achievements.json`. These witnesses show
that the game logic reaches each condition. They are **not real Steam unlocks**.
The scripts place answers through public actions, purchase using earned money,
equip owned modules, and run normal combat updates. They never inject earned
flags, achievement counters, rounds, health, currency, enemies, or rewards.

Witness shorthand:

- **H1:** Campaign seed 875, Hard puzzle / Easy combat, round 1, targeted
  `hard-investments` scenario. It solves the grid, pays for upgrades, equips real
  modules, uses the starter boost, and kills ten enemies with zero leaks.
- **C:** Campaign seed 875, Medium / Medium, actual 50-round full run.
- **L:** Locked In seed 2046, Medium / Medium, actual 50-round full run.
- **E1:** Campaign seed 875, Easy / Easy, round 1; three ordinary illegal
  emergency placements followed by real combat. Seeds 1023 and 2046 also pass.

| API ID / achievement | Exact successful condition | Observed witness |
| --- | --- | --- |
| `SD_FIRST_PLANT` — A Number Takes Root | Make a legal placement without a hint. | H1: first successful `place`. |
| `SD_FIRST_UNIT` — Nine in Line | A non-hint placement completes a row, column, or box; starting clues and hint completions do not count. | H1: a player placement completes a unit. |
| `SD_FIRST_UPGRADE` — Growing Stronger | Purchase an individual tower upgrade. | H1: successful tower upgrade. |
| `SD_FIRST_MODULE` — Added Potential | Equip, transfer, or swap a module onto a tower. | H1: equip a starter module. |
| `SD_FIRST_CHEST` — Recovered Supplies | Pay fragments and successfully open a chest. | H1: open an earned chest after combat. |
| `SD_FIRST_BOOST` — Timely Intervention | Consume Overclock, Overcharge, or Freeze during battle; Repair is excluded. | H1: consume the real starter Overclock during combat. |
| `SD_FIRST_CLEAR` — Holding the Line | Clear a wave, including a Free Play wave. | H1: ordinary combat updates settle round 1. |
| `SD_FIRST_BOSS` — Giant Answer | Deal the killing damage to a boss before it reaches the core. | C: actual round-5 boss kill. |
| `SD_ROUND_10` — Double Digits | Clear round 10 in Campaign or Locked In. | C: round 10 settles after combat. |
| `SD_ROUND_25` — Halfway Home | Clear round 25 in Campaign or Locked In. | C: round 25 settles after combat. |
| `SD_CAMPAIGN_CLEAR` — Fifty and Standing | Clear round 50 of a 50-round Campaign or Locked In run; Free Play victory is excluded. | C: round 50 clears. |
| `SD_LOCKED_CLEAR` — A Promise Kept | Clear round 50 of a 50-round Locked In run. | L: round 50 clears. |
| `SD_FIRST_FAMILY` — Family Investment | Purchase a number-family upgrade. | H1: successful family upgrade. |
| `SD_FAMILY_FIVE` — Strength in Numbers | Purchase the family upgrade that raises it to level 5 or above. | H1: four paid family upgrades, costing 369 credits in total, reach level 5. |
| `SD_TOWER_FIVE` — A Tower of Your Own | Purchase upgrades bringing one tower's own level to at least 5; family bonuses do not count. | H1: four paid individual upgrades, costing 178 credits in total, reach level 5. |
| `SD_FIVE_SOCKETS` — Fully Fitted | An equip, transfer, or swap leaves all five sockets on one tower occupied. | H1: three starter modules plus two from a naturally dropped rare chest fill five sockets. |
| `SD_STACK_MODULES` — Double Down | An equip, transfer, or swap leaves at least two modules of the same kind on one tower. | H1: the owned modules include a matching pair, equipped on one tower. |
| `SD_THREE_EFFECTS` — Combined Arms | An equip, transfer, or swap leaves at least three different module kinds on one tower. | H1: equip the three different starter module kinds. |
| `SD_TARGET_LINEUP` — Different Priorities | Clear a wave with legal towers collectively using First, Strongest, and Nearest targeting. | H1: set all three priorities on legal towers, then clear through ordinary combat. |
| `SD_NINE_FAMILIES` — Every Number Counts | Clear a wave with legal towers collectively covering numbers 1 through 9. | H1: the solved grid supplies all nine number families during the clear. |
| `SD_HARD_GRID` — Hard Answers | Make the placement completing a Hard Sudoku grid; hints are permitted. | H1: final correct placement completes the Hard grid. |
| `SD_NO_HINT_GRID` — Your Own Reasoning | Complete a grid with fully observed round history and zero successful hints. | H1: finish the grid without a hint. |
| `SD_BOSS_WAVE_CLEAN` — Nothing Gets Through | Clear a boss wave with a recorded boss kill and zero leaks across its fully observed round history. | C: round 5 kills the boss and all other enemies without leaks. |
| `SD_CORRUPT_CLEAR` — Controlled Chaos | Clear a wave after at least three successful illegal emergency placements in that round. | E1: plant three illegal reserve towers and clear with ten kills, zero leaks. |
| `SD_UNFINISHED_CLEAR` — Enough to Defend | Clear a wave while the grid remains incomplete after illegal emergency towers are removed. | E1: cleanup removes those three towers and leaves the grid incomplete. |
| `SD_CLEAN_CAMPAIGN` — By the Rules | Clear all 50 recorded Campaign or Locked In rounds with complete history and zero illegal emergency placements; rejected wrong answers do not count as placements. | C: all 50 rounds clear with no illegal placements. |

Exact action and round indices are in
`qa/reachability/26-achievement-matrix.json`. The targeted witness run passed
**691 checks**; its evidence is `qa/reachability/final-targeted/results.json`.
The remaining milestone witnesses are in
`qa/full-runs/initial/full-run-results.json`. Independent evidence review resolved
all 26 distinct catalog IDs to actual newly earned entries. No paid slot spins
were needed for the H1 witnesses.

Practice/test runs with an empty achievement identity remain excluded. Older
saves with incomplete history cannot retroactively prove no-hint, clean boss,
or clean Campaign history. See [the full rule and persistence design](ACHIEVEMENTS-0.3.19.md).

## Full-run progression evidence

The baseline matrix passed **56,858 checks across six scenarios and 153 cleared
waves**, with 4,215 actual kills, 30 actual boss kills, and zero leaks.

| Mode | Seed | Puzzle / combat | Cleared waves | Kills | Boss kills | Final core |
| --- | ---: | --- | ---: | ---: | ---: | ---: |
| Campaign | 875 | Medium / Medium | 50 | 1,314 | 10 | 30 / 30 |
| Locked In | 2046 | Medium / Medium | 50 | 1,314 | 10 | 30 / 30 |
| Locked In | 875 | Hard / Hard | 50 | 1,551 | 10 | 30 / 30 |
| Free Play | 875 | Easy / Easy | 1 | 10 | 0 | 30 / 30 |
| Free Play | 1023 | Medium / Medium | 1 | 12 | 0 | 30 / 30 |
| Free Play | 2046 | Hard / Hard | 1 | 14 | 0 | 30 / 30 |

Every generated puzzle has valid givens, one solution, the expected clue density,
and deterministic seed/round generation. Each enemy is accounted for once as a
kill or leak. Waves settle once; repeated terminal updates do not grant rewards
again. Purchases charge the displayed cost once, resources stay nonnegative,
module IDs have one owner, socket limits hold, and gear returns once between
boards. Locked In rejects changed difficulty. Free Play intentionally ends after
one round and cannot grant either Campaign completion condition.

The bot reads the solution and spends no simulated time deciding answers. These
are legal-action reachability and simulation checks for the stated seeds, not
proof of human balance, fun, solve speed, performance, or physical input quality.
No economy or difficulty change is justified solely by these perfect-answer wins.

See `qa/full-runs/REPORT.md`, the manifest, raw log, per-wave ledgers, and six
synthetic final snapshots in `qa/full-runs/initial/`.

## Settlement and economy evidence

The separate focused baseline harness passed **4,406 assertions** across nine
real wave clears and a natural boss-leak branch, using Easy/Easy seeds 875, 1023
and 2046. Its verified source fingerprints are in
`qa/settlement/verified/manifest.json`.

- After four real clears, solving round 5 kills all twelve enemies including
  the boss, with no leaks. Rewards are 53 credits (24 kill credits plus a
  29-credit clear bonus) and 20 fragments; both boss achievements are earned.
- From the same genuinely reached round-5 starting state, leaving the board
  unplanted leaks all twelve enemies, including the boss. The core loses 18
  health and heals to 15. It awards neither boss achievement, no kill credits
  or fragments, and only the normal 29-credit clear bonus and one clear chest.
- Kill/leak events, counters, reward inventories, and core damage/healing agree.
  Repeated post-terminal updates and explicitly adversarial internal settlement
  calls after real combat cannot award again. Internal calls are not achievement
  witnesses and are not used to bypass combat.
- Equip, transfer, swap, unequip, illegal-tower removal, and next-board cleanup
  preserve unique ownership. Individual levels reset on the next board; paid
  family levels persist. Invalid repeated actions leave state unchanged.
- Upgrade/chest/vitality costs match quoted prices. Reopening a chest fails
  without mutation. Fifty paid slot spins close the currency/item ledger
  (384 credits before, 374 after). One seeded sequence does not establish the
  slot's expected return or game balance. No item sale/scrap API is claimed.

See `qa/settlement/REPORT.md` and `qa/settlement/verified/`.

## Executable acceptance checklist

### Permitted local verification after final edits

Run from the isolated checkout, using fresh output names. These runners provide
disposable synthetic profiles and `--no-steam`; never substitute a player save.
The following reproduce the final persistence/aggregate checks using the QA
runners from the evidence archive. Their results are recorded above. Use this
task's bundled runtime paths or validated equivalents on the acceptance machine.
The other gameplay matrices are retained baseline evidence; their scripts are
also in the archive and need repeating only after a relevant gameplay change.

```powershell
$qaPython = 'C:/Users/Yanni/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$qaGodot = 'C:/Users/Yanni/Documents/Codex/2026-10-25/computer-plugin-computer-use-openai-bundled-4/work/godot/Godot_v4.7.2-stable_win64_console.exe'
& $qaPython qa/run_scenario.py resume-0322-final godot/tests/test_progression_resume.gd PROGRESSION_RESUME_PASS
& $qaPython qa/run_local_checks.py --godot $qaGodot --mode all --output qa/aggregate-0322-final
```

- [x] Freeze the final source before running checks. Record its exact commit,
  runtime version, hashes, commands, raw logs, and before/after source hashes.
- [x] Run the narrow precision regression through normal journal writing and
  recovery publication. Require the formerly failing snapshot to continue with
  matching gameplay, enemy HP, damage report, RNG, resources and earned keys.
- [x] Re-run interrupted/resumed progression through solve, launch, mid-wave,
  settlement and loot at early, boss, round-25, round-49 and round-50 checkpoints.
  Require zero failed comparisons and retain the original failure evidence.
- [x] Re-run affected save/journal/achievement suites and the permitted aggregate.
  Every process must exit successfully, expected markers must appear, no unknown
  errors may occur, and tested source must stay unchanged. Record any harness
  correction separately from a product fix.
- [x] Check practice exclusion with a disposable profile: complete practice,
  restart, then begin a normal run. Practice must leave persistent awards and
  the prior profile unchanged; the fresh normal run must track its own actions.
- [ ] Preserve old packages and saves. Build a distinctly named local native
  candidate only through the approved export workflow, then record package
  hashes and inspect version/contents. Packaging does not close device or Steam
  acceptance and does not authorize upload.

The aggregate runner intentionally omits the four denied native cursor suites
and reports the aggregate as incomplete. It retains the known Godot
`Failed to read the root certificate store` diagnostic as a qualification.
Do not remove exclusions, suppress errors, modify certificate stores/security,
or retry the denied path to make this checklist green.

### Ordinary Windows and physical Steam Deck acceptance

These are manual acceptance steps for a separately permitted test environment.
They are not instructions to retry denied operations in this task.

- [ ] On an ordinary supported Windows desktop with a disposable profile, run
  `controller-cursor-render-tests`, `canvas-controller-cursor-render-tests`,
  `loot-gear-render-tests`, and `canvas-loot-gear-render-tests` from the canonical
  build list. Require their expected markers and successful real-pointer/drag
  behavior in both renderers; headless pointer-dispatch tests do not substitute.
- [ ] Obtain a clean strict startup/build result in an authorized environment
  without the certificate-store error. Record the exact failing action if it
  remains; no certificate/security workaround is specified by this document.
- [ ] Start the final Windows and native Linux/Deck packages from a fresh test
  profile. Confirm displayed version, audio, rendering, settings persistence,
  readable UI, frame pacing, suspend/resume, controller disconnect/reconnect,
  and normal quit/restart. Record hardware, renderer, package hash and result.
- [ ] With the physical controller, traverse every menu; select an empty upgrade
  socket; wrap both directions with LB/RB; press Back/Cancel repeatedly and hold
  confirm/cancel. Expect one intended action per accepted input and visible focus.
- [ ] Scroll achievements through top, middle and end. Check that focus outlines
  stay visible at boundaries and that the footer does not overlap on the narrow
  supported layout. Check singular/plural labels at counts zero, one and several.
- [ ] Move between controller, mouse and touch where supported; equip/transfer/
  swap/unequip modules and drag loot. Expect consistent selection, no lost or
  duplicated items, no blocked dismissal, and preserved input focus.
- [ ] Play representative human sessions with timed Sudoku and ordinary mistakes.
  Record solve time, leaks, deaths, readability and frustration before proposing
  difficulty/economy changes. Oracle completion is not human acceptance.

### Real Steam awards and two-device saves

**Separate authorization and an appropriate acceptance account are required.**
No real account, Steamworks page, Cloud setting, or player save was changed by
the evidence above. Back up disposable test saves before beginning these steps.

- [ ] On the final candidate, naturally earn first placement, first clear, first
  boss, equipment/build conditions and a completion milestone. Compare in-game
  earned state, queued/acknowledged state, and Steam's actual unlock. Retain
  evidence without resetting or fabricating an achievement.
- [ ] Earn a new condition offline, quit, restart offline, then reconnect.
  Confirm the earned key survives and is acknowledged once. Verify a failed or
  timed-out store operation can reconcile after restart without losing evidence.
  Mock callbacks do not prove arbitrary duplication in later native batches:
  Steam's StoreStats callback has no request identifier.
- [ ] Switch between two authorized acceptance accounts with distinct synthetic
  progress. Confirm each reads its own scoped run and achievement profile; no
  inherited foreign unlock or legacy import may appear under the second account.
- [ ] With Cloud enabled for the acceptance configuration, finish a Windows
  session, quit normally, and wait for Steam to finish syncing. Start Deck and
  compare seed, round, phase, board, inventory, currency, family upgrades, earned
  keys and resumed combat. Repeat Deck-to-Windows. Do not play concurrently.
- [ ] Create a deliberate divergence using disposable saves. Inspect both
  choices in Saves & Steam, choose explicitly, and verify archived originals
  remain available. Confirm counters/evidence are retained for the correct
  account and no unchosen variant is silently destroyed.
- [ ] Repeat ordinary start/quit with Cloud disabled and with Steam unavailable.
  Confirm local progress remains usable and errors are visible. If forced Proton
  is supported, test its Windows-style path separately from native Linux.
- [ ] Test Deck suspend/resume on the final package. Dynamic Cloud Sync remains
  disabled: quit and wait for sync before continuing on the other device.
- [ ] Record all final results before any delivery decision. Keep the 0.3.19 hold
  and do not upload or activate a candidate merely because local checks pass.

## Evidence boundaries

All automated progression witnesses use redirected APPDATA/LOCALAPPDATA,
synthetic identities, and `--no-steam`. Retained snapshots are QA fixtures only.
The known certificate diagnostic is separate from the demonstrated poison
serialization defect. Browser gameplay approval remains pending in its original
task; native cursor and WSL operations retain their original denied status.
None was retried or bypassed. This document records usable local evidence and
remaining acceptance work; it is not a release approval.
