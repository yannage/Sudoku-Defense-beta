# Pre-release balance and pacing experiment

Run on 2026-10-30 with Godot **4.7.2.stable.official.ed1daf0bf**, against the
unchanged combat/economy from source commit
`ec17ef2` (0.3.15). This is evidence for the 0.3.16 preparation pass, not a
human balance certification or a release approval.

**Three different allocation policies completed the existing 50 rounds on
all three combat difficulties in this small seeded sample. Stacked control
sometimes produced very slow late waves. Keep the current combat numbers
for this pass; test that pacing tradeoff with people before changing them.**

## Method and limits

`godot/tests/test_campaign_balance.gd` creates runs entirely in memory. It
never loads, writes or deletes a player save. Every purchase, equip, chest,
placement and consumable action goes through the actual simulation API.
There are no free credits, injected items, forced drops or skipped bosses.

The main matrix uses seeds **1023, 2046 and 4092**, medium Sudoku, and easy,
medium or hard combat. Each bot places **18 of the 45 missing answers per
round**, in the same fixed traversal, then launches. All policies use the
visible route to rank tower coverage. The policies are:

| Policy | Credit allocation | Equipment allocation |
| --- | --- | --- |
| `family_spread` | Buy the cheapest family level repeatedly, retaining upgrades across rounds | Spread earned modules over towers, breaking ties by route coverage |
| `tower_stack` | Upgrade the three towers with most base-range route coverage; these upgrades expire with the board | Fill the best-covered tower's five sockets, then the next |
| `power_spread` | Save credits for the global Power passive between rounds | Spread modules using the same rule as `family_spread` |

All policies open affordable earned chests, use available repairs after at
least 10 damage, and use at most one available boost of each kind per wave
after five seconds. They do not buy chests, gamble, use reserve seeds, alter
targeting, optimize rarity replacements, or reallocate gear mid-wave. The
separate control probe below deliberately tests targeting and unequipping.
Policies combine spending and equipment choices; their results do **not**
isolate the value of one upgrade type or establish viability of every
attachment archetype.

The bots know every Sudoku answer and place instantly without mistakes.
These are combat-only simulated times at 1x, excluding solving, menus,
reading, breaks and input time. A 50-round human run can be much longer.
Three seeds do not establish a win rate or difficulty for people. Core
health includes automatic healing and consumable repairs; **leak counts**,
not final full health, establish whether a run took hits.

## Complete matrix with a 600-second per-wave guard

All **27 partial-grid campaigns** and all **3 complete-grid references**
cleared 50/50. The full measurement run passed **315,158 harness integrity
checks** and exited 0. No campaign was censored at the 600-second guard.
One partial-grid campaign leaked enemies: hard `tower_stack`, seed 4092,
with 20 leaks beginning at round 44. Its earned repairs and clear healing
allowed it to finish. Every other sampled campaign had zero leaks.

| Seed | Combat | Policy | Rounds cleared | Leaks | Total battle minutes | Longest wave, seconds |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| 1023 | easy | family_spread | 50 | 0 | 17.22 | 38.0 |
| 1023 | easy | tower_stack | 50 | 0 | 22.80 | 93.8 |
| 1023 | easy | power_spread | 50 | 0 | 18.00 | 50.0 |
| 1023 | medium | family_spread | 50 | 0 | 19.53 | 46.2 |
| 1023 | medium | tower_stack | 50 | 0 | 31.15 | 109.6 |
| 1023 | medium | power_spread | 50 | 0 | 24.47 | 83.8 |
| 1023 | hard | family_spread | 50 | 0 | 24.30 | 76.4 |
| 1023 | hard | tower_stack | 50 | 0 | 38.77 | 226.5 |
| 1023 | hard | power_spread | 50 | 0 | 31.26 | 224.3 |
| 2046 | easy | family_spread | 50 | 0 | 16.31 | 50.3 |
| 2046 | easy | tower_stack | 50 | 0 | 29.98 | 374.3 |
| 2046 | easy | power_spread | 50 | 0 | 18.03 | 64.9 |
| 2046 | medium | family_spread | 50 | 0 | 18.59 | 49.6 |
| 2046 | medium | tower_stack | 50 | 0 | 30.67 | 132.1 |
| 2046 | medium | power_spread | 50 | 0 | 21.22 | 61.7 |
| 2046 | hard | family_spread | 50 | 0 | 22.81 | 59.7 |
| 2046 | hard | tower_stack | 50 | 0 | 33.05 | 152.7 |
| 2046 | hard | power_spread | 50 | 0 | 28.51 | 131.1 |
| 4092 | easy | family_spread | 50 | 0 | 14.67 | 30.3 |
| 4092 | easy | tower_stack | 50 | 0 | 19.68 | 57.0 |
| 4092 | easy | power_spread | 50 | 0 | 16.40 | 49.1 |
| 4092 | medium | family_spread | 50 | 0 | 20.54 | 67.6 |
| 4092 | medium | tower_stack | 50 | 0 | 36.60 | 210.0 |
| 4092 | medium | power_spread | 50 | 0 | 25.41 | 97.8 |
| 4092 | hard | family_spread | 50 | 0 | 22.14 | 42.5 |
| 4092 | hard | tower_stack | 50 | 20 | 35.43 | 112.2 |
| 4092 | hard | power_spread | 50 | 0 | 27.02 | 76.6 |

For comparison, completing all 45 missing answers and using `family_spread`
on medium combat produced 50/50 clears with no leaks:

| Seed | Battle minutes | Longest wave, seconds |
| --- | ---: | ---: |
| 1023 | 15.45 | 28.6 |
| 2046 | 15.63 | 30.5 |
| 4092 | 15.86 | 26.5 |

Completing the grid produces more towers, credits and unit-completion
rewards, so this reference is an upper-resource comparison, not an equal
effort alternative. The sampled medium campaign remains feasible without
finishing the Sudoku.

## Initial 180-second guard: four censored outcomes

The first matrix used the harness's default **180-second** exploratory pacing
guard. It exited 1 because four waves were still in progress at that limit.
These are **censored duration observations, not defeats or proof of an
endless stall**. Their final outcomes were determined by the 600-second run
above; all eventually cleared without losing the run.

| Seed | Combat | Policy | First wave censored at 180s | Rounds cleared before censoring |
| --- | --- | --- | ---: | ---: |
| 1023 | hard | tower_stack | 44 | 43 |
| 1023 | hard | power_spread | 48 | 47 |
| 2046 | easy | tower_stack | 45 | 44 |
| 4092 | medium | tower_stack | 33 | 32 |

The longest observed wave was **374.3 simulated seconds** for seed 2046's
easy `tower_stack` campaign. Even at the existing 4x speed this is roughly
94 seconds of real time, before player pauses. That is a concrete pacing
case for a human playtest, especially when only a few enemies remain.

## Same-snapshot control experiment

The harness restores the exact start-of-battle snapshot from seed 1023,
medium Sudoku, hard combat, `tower_stack`, round 44. Board, route, upgrades,
inventory and RNG are identical. Only the stated intervention changes.

| Intervention | Wave seconds | Leaks | Outcome |
| --- | ---: | ---: | --- |
| Unchanged | 226.5 | 0 | Cleared |
| Return gravity modules to the bag | 57.2 | 13 | Cleared using earned repairs |
| Return gravity and frost modules to the bag | 54.1 | 19 | Cleared using earned repairs |
| Keep all modules; switch all towers to Strongest after 60 seconds | 193.8 | 0 | Cleared |

The current gravity/frost setup prevents damage but extends combat. Removing
control wholesale shortens the wave and makes many enemies leak. This is
why the pass does **not** silently nerf gravity or raise enemy health.
Existing Strongest targeting helps this particular tail but does not fully
solve its pacing. The final four-treatment probe passed **10,657 checks**.

## Starter probes and curve checks

Eight legal towers with **no equipment, upgrades or boosts** cleared the
first easy/easy wave on seeds 1023, 2046 and 4092 without a leak, in 9.4,
13.4 and 12.3 simulated seconds respectively. These are separate targeted
easy-puzzle runs; the main matrix's nine starter probes deliberately keep
medium Sudoku fixed. Those nine also cleared, with no leaks, in 10.1–22.4
seconds across combat difficulties. The tutorial's actual input and teaching
sequence still requires its own UI and human checks.

Enemy base health increases each round, counts never decrease, and the boss
cadence remains every fifth round through 50. For medium combat the first
wave has 12 enemies at 28 base health; round 50 has 40 at 645.98 base health,
with the boss replacing its last enemy. No extra content is needed to
establish the existing campaign length.

## Reproduce

Run from the repository root with the matching official Godot 4.7.2
console executable. Use an isolated environment even though the harness
itself does no file I/O. The following PowerShell example redirects all
engine user files and logs into a scratch directory:

```powershell
$godot = 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe'
$balanceScratch = Join-Path $env:TEMP 'sudoku-balance-0.3.16'
New-Item -ItemType Directory -Force -Path $balanceScratch | Out-Null
$env:APPDATA = $balanceScratch
$env:LOCALAPPDATA = $balanceScratch
$env:TEMP = $balanceScratch
$env:TMP = $balanceScratch

# Initial pacing experiment: expected to report four 180s guard failures
# for the source version documented here, while retaining every outcome.
& $godot --headless --path godot --script res://tests/test_campaign_balance.gd `
  *> "$balanceScratch\balance-180.log"

# Follow those censored observations through to completion.
& $godot --headless --path godot --script res://tests/test_campaign_balance.gd `
  -- --battle-limit=600 *> "$balanceScratch\balance-600.log"

# Exact control/targeting comparison, using an in-memory round-44 snapshot.
& $godot --headless --path godot --script res://tests/test_campaign_balance.gd `
  -- '--case=1023,hard,tower_stack,18,medium' --battle-limit=600 --control-probe `
  *> "$balanceScratch\control-probe.log"

# Separate onboarding combat probes using easy Sudoku as well as easy combat.
foreach ($probeSeed in @(1023,2046,4092)) {
  & $godot --headless --path godot --script res://tests/test_campaign_balance.gd `
    -- "--case=$probeSeed,easy,starter,8,easy" `
    *> "$balanceScratch\starter-$probeSeed.log"
}
```

`--quick` restricts the main matrix to seed 1023. `--case` accepts
`seed,combat,policy,placement_budget,puzzle`. The console retains per-case
JSON, milestone snapshots, remaining enemies when censored, aggregate
counts, and integrity results. The default guard is intentionally a pacing
diagnostic; do not register its expected failures as routine export failures.

The Windows sandbox used for these measurements printed
`ERROR: Failed to read the root certificate store.` at engine startup.
This is retained in the evidence; the harness performs no HTTPS requests.
The 600-second matrix, control probe and easy/easy probes exited 0 with
their completion markers and no GDScript errors. The initial 180-second
matrix exited 1 for the four explicitly reported pacing guards.

Simulation SHA-256 references for the measured source:

- `scripts/run.gd`: `94b8bc2d95d93622983d19936c2a56ee1367e3b3b7147527ae75b994cc38b4de`
- `scripts/loot.gd`: `72751d5596b151361cad4abf6482ba1f85bad66e41eac71cee0f800d2b5c1d0a`
- `scripts/sudoku.gd`: `b7241d3e654ac7d94a9925241545fb549f90063952b4ed8f7ca48f2c80c7efc5`

## Release follow-up

Keep combat/economy values unchanged for this pass. Playtest at least one
family-focused and one control-heavy run with real players, record actual
solve/prep/battle time, and ask whether the late-wave wait feels like a
worthwhile strategic tradeoff. Include seeds 1023 and 2046 above so the slow
case is reproducible. Check that players find 2x/4x speed and can interpret
remaining threats and targeting. If the tail remains tedious, prototype a
bounded pushback rule with visible feedback, then repeat both survival and
same-snapshot comparisons before shipping a control nerf.

Fresh-player completion, human strategic variety, full-run fatigue,
physical Deck performance and suspend/resume remain unverified here.
