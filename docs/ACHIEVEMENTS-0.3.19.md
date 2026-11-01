# Achievement rules and saved evidence

The canonical 26-entry catalog is `godot/data/achievements.json`. API IDs are
stable `SD_*` keys. Names, descriptions, and icon basenames are data rather than
Steam-specific code. `achievement_rules.gd.evaluate(run)` returns the earned
keys; it never calls Steam or awards anything to an account.

## Comparable games

Official Steam totals checked on November 1, 2026 are current totals, not claims
about the number available at each game's launch.

| Game | Current achievements | Official source |
| --- | ---: | --- |
| Isle of Arrows | 9 | [Steam achievement list](https://steamcommunity.com/stats/1946970/achievements) |
| Dungeon Warfare | 35 | [Steam achievement list](https://steamcommunity.com/stats/355980/achievements) |
| Tower Tactics: Liberation | 83 | [Steam achievement list](https://steamcommunity.com/stats/1709900/achievements) |
| Rogue Tower | 140 | [Steam achievement list](https://steamcommunity.com/stats/1843760/achievements) |
| Bloons TD 6 | 156 | [Steam achievement list](https://steamcommunity.com/stats/960090/achievements) |
| Sudoku by Popoko | 5 | [Steam store page](https://store.steampowered.com/app/4215050/Sudoku/) |

The closest puzzle/defense hybrid has a compact set. Large tower-defense content
catalogs support many more combinations, maps, and progression goals. Sudoku
Defense's 26 awards cover its existing actions, a few meaningful build choices,
and campaign milestones without inventing content or requiring long grind totals.

## Unlock conditions

| API ID | Successful action or outcome |
| --- | --- |
| `SD_FIRST_PLANT` | A legal placement made without a hint. |
| `SD_FIRST_UNIT` | A non-hint placement completes a row, column, or box. Starting clues and units completed by hints do not count. |
| `SD_FIRST_UPGRADE` | Purchase an individual tower upgrade. |
| `SD_FIRST_MODULE` | Equip, transfer, or swap a module onto a tower. |
| `SD_FIRST_CHEST` | Pay fragments and atomically open a chest. |
| `SD_FIRST_BOOST` | Successfully consume overclock, overcharge, or freeze in battle. Repair is excluded. |
| `SD_FIRST_CLEAR` | Settle a successfully cleared wave, including Free Play. |
| `SD_FIRST_BOSS` | Apply the actual killing damage to a boss. A boss reaching the core does not count. |
| `SD_ROUND_10` | Clear round 10 in Campaign or Locked In. |
| `SD_ROUND_25` | Clear round 25 in Campaign or Locked In. |
| `SD_CAMPAIGN_CLEAR` | Clear round 50 of a 50-round Campaign or Locked In run. Free Play's `won` state is excluded. |
| `SD_LOCKED_CLEAR` | Clear round 50 of a 50-round Locked In run. |
| `SD_FIRST_FAMILY` | Purchase a number-family upgrade. |
| `SD_FAMILY_FIVE` | Purchase a family upgrade that raises its level to at least 5. |
| `SD_TOWER_FIVE` | Purchase an individual tower upgrade that raises its own level to at least 5; family bonuses do not count. |
| `SD_FIVE_SOCKETS` | An equip, transfer, or swap leaves a tower with all five sockets occupied. |
| `SD_STACK_MODULES` | An equip, transfer, or swap leaves a tower with two or more modules of the same kind. |
| `SD_THREE_EFFECTS` | An equip, transfer, or swap leaves a tower with at least three different module kinds. |
| `SD_TARGET_LINEUP` | Clear a wave with legal towers collectively using First, Strongest, and Nearest targeting. |
| `SD_NINE_FAMILIES` | Clear a wave with legal towers collectively covering numbers 1 through 9. |
| `SD_HARD_GRID` | Make the placement that completes a Hard grid; hints are permitted. |
| `SD_NO_HINT_GRID` | Complete a grid whose full round history is known and contains zero successful hints. |
| `SD_BOSS_WAVE_CLEAN` | Clear a boss wave with a recorded boss kill and zero recorded leaks across its complete round history. |
| `SD_CORRUPT_CLEAR` | Clear a wave after at least three successful illegal emergency placements in that round. |
| `SD_UNFINISHED_CLEAR` | Clear a wave while the grid remains incomplete after illegal emergency towers are removed. |
| `SD_CLEAN_CAMPAIGN` | Clear all 50 recorded rounds in Campaign or Locked In with complete run history and zero illegal emergency placements. Rejected incorrect answers do not count as illegal placements. |

## Persistence, practice, and older saves

Facts are saved in the run's optional `achievement_stats` field. It includes an
application-supplied run ID, schema version, earned-key set, cumulative action
counters, maxima, observed equipment kinds, current-round evidence, and no more
than 50 completed-wave records. It is independent of the presentation-event
queue, which may be capped or drained. Duplicate damage, already-open chests,
failed purchases/equips, and repeated wave settlement cannot repeat the facts.
No achievement-specific randomness or combat/economy changes are introduced.

The application supplies `achievement_run_id` only for an actual player run.
Tests and guide/practice runs default to an empty ID. The rule evaluator returns
no awards for an empty ID. The application must also preserve its guide/test
exclusion when observing results and interacting with Steam.

Pre-0.3.19 saves remain playable. Missing or malformed optional achievement
metadata resets to empty evidence, no ID, and incomplete historical coverage.
`enable_achievement_tracking(id)` can attach a new ID for future observed actions;
it does not restore unknown history. Existing equipment and already-finished
results are not scanned to invent old awards. A newly performed equipment
action may satisfy its resulting layout, and an observed future campaign finish
can earn its completion award. A partially observed old board cannot earn
No Hint Grid or Boss Wave Clean; the next entirely observed board can. Clean
Campaign requires a new, completely observed 50-round run.

The separate achievement profile owns local unlock persistence, offline Steam
delivery, callback acknowledgements, and idempotence across run retries or save
recovery. The run's earned set is never consumed, so a profile write interruption
can be retried from persisted gameplay evidence.

## Verification

`test_achievement_rules.gd` exercises all 26 rules, including leaked bosses,
post-wave healing, Free Play victory, hints, cumulative corruption across
boards, individual versus family level, module stacks, failed operations,
duplicate settlement, JSON persistence, old saves, invalid optional metadata,
and empty-ID exclusion. Its synthetic run identities stay inside isolated tests;
the suite imports no Steam code and never calls a real account.

It also writes `user://achievement-rule-coverage.json` with an explicit positive
and a specific negative case for every catalog ID. These include the immediately
preceding round/upgrade/socket threshold, illegal-only family/target coverage,
Free Play's won state, hint-only completion, and a boss leak hidden by healing.
Custom seeds are eligible. A wrong answer and successful hint survive save/load
with the run identity and retain their distinct consequences.

### Controlled Chaos feasibility

`research_achievement_viability.gd` runs three paired actual-combat scenarios
with seeds 875, 1023, and 2046 on Easy puzzle/Easy combat round 1. Both sides
manually plant 30 correct answers, leaving three blanks. The variant fills those
blanks using three illegal starting reserve seeds. Neither side receives bought
upgrades, gear, extra credits, hints, or boosts. Ordinary 0.05-second simulation
updates run to completion, with no forced kills or wave completion.

All six simulations cleared: 10 kills, zero leaks, 30 final core health, 11
fragments, 33 credits earned during the wave, and 9.2 simulated battle seconds.
The achievement unlocked only in the three illegal-placement variants. Chest
counts were 2 in each baseline and 1, 1, and 3 in the variants respectively;
the additional tower creation advances normal gameplay randomness, so this is
not a claim that rewards or outcomes are identical.

This establishes that three illegal placements need not force a loss in an
accessible early scenario. It does not claim viability for every build/round,
human fun, or physical Deck performance. Exact scenario results are written to
`user://achievement-viability.json` in the isolated research profile.
