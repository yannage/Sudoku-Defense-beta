# 0.3.18 pacing decision and measured limits

The production combat, control, reward and economy values remain unchanged.
The narrow improvement is optional **8x fast-forward** after every enemy has
spawned and the wave has lasted at least 45 simulated seconds. These enemies
are still dangerous. Fast-forward makes time pass faster; it does not skip
combat, kill enemies, guarantee victory or grant rewards early.

The experiment below supports preserving gravity/frost and improving player
control of waiting. It does **not** establish human difficulty, enjoyment,
full-run fatigue, physical Deck performance or a Steam release approval.

## Why a gravity cap was rejected

The previous report found a 374.3-second wave and substantial leaks after
removing control entirely. This pass tested a narrower counterfactual:
leave all effects unchanged for 60 simulated seconds, then limit each enemy
to either 8 or 24 additional route units of cumulative gravity pushback.
Frost, damage, tower positions, route, inventory, RNG and initial state were
unchanged. The counterfactual lives only in the opt-in research test.

| Exact starting snapshot | Treatment | Wave seconds | Leaks | Core damage | Kills | Credits earned | Fragments earned | Chests earned |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2046 / easy / tower_stack / round 45 | Unchanged | 374.3 | 0 | 0 | 32 | 148 | 43 | 5 |
| Same | 8-unit budget after 60s | 89.5 | 0 | 0 | 32 | 148 | 43 | 5 |
| Same | 24-unit budget after 60s | 113.8 | 0 | 0 | 32 | 148 | 43 | 5 |
| 1023 / hard / tower_stack / round 50 | Unchanged | 178.4 | 0 | 0 | 47 | 217 | 60 | 9 |
| Same | 8-unit budget after 60s | 102.5 | 27 | 32 | 20 | 185 | 28 | 6 |
| Same | 24-unit budget after 60s | 119.6 | 17 | 17 | 30 | 200 | 43 | 8 |

The easy case alone would have suggested a harmless improvement. The hard
boss wave reveals lost protection and lost loot. Earned repairs let both
counterfactuals finish that wave; final full core health in one treatment
does not mean no damage occurred. These observations do not support shipping
either cap. They also do not prove every possible bounded control rule is bad.

## Why the fast-forward gate is not restricted to three enemies

The long waits are not always a lone survivor. In the 374.3-second case,
25 enemies remained at both 45 and 60 seconds. Only three remained at
287.1 seconds. Waiting for three would save only an estimated 10.9 wall-clock
seconds from an existing 4x run. The all-spawned, 45-second gate addresses
more of the wait while leaving activation with the player.

| Seed / combat / policy / round | Wave seconds | Enemies at 45s / 60s | Existing 4x estimated wall seconds | 4x then optional 8x estimated wall seconds |
| --- | ---: | ---: | ---: | ---: |
| 2046 / easy / tower_stack / 45 | 374.3 | 25 / 25 | 93.58 | 52.43 |
| 1023 / hard / tower_stack / 44 | 226.5 | 39 / 34 | 56.63 | 33.95 |

The gate first appears at 45.1 seconds in this harness because it observes
the state after each 0.1-second update. These estimates assume immediate
activation, no pauses and sufficient rendering/CPU throughput. They are
derived from simulated time, **not measured human or Deck wall-clock time**.
The full wave still takes the same simulated time, with the same outcomes.
On leaking cases these estimates are optimistic: production fast-forward
stops on core damage, and the player would need to choose whether to resume.
The research estimate assumes uninterrupted acceleration after eligibility.

## Complete campaign observations

All nine baseline campaigns cleared 50/50 rounds. The final run passed
**89,304 research integrity checks**, with zero failures and no wave censored
at the 600-second guard. All 81 grouped-update comparisons matched exactly.
The only baseline campaign with leaks was the previously observed hard
tower-stack seed 4092; it had 20 leaks and used earned repairs.

| Seed | Combat | Policy | Leaks | Simulated battle seconds | Eligible waves / 50 | Existing 4x estimated wall seconds | Optional 8x estimated wall seconds |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 2046 | easy | tower_stack | 0 | 1799.9 | 9 | 450.0 | 391.4 |
| 1023 | hard | tower_stack | 0 | 2326.4 | 18 | 581.6 | 508.4 |
| 4092 | medium | tower_stack | 0 | 2196.2 | 16 | 549.1 | 481.7 |
| 4092 | hard | tower_stack | 20 | 2125.6 | 17 | 531.4 | 483.8* |
| 1023 | easy | family_spread | 0 | 1034.5 | 0 | 258.6 | 258.6 |
| 2046 | medium | family_spread | 0 | 1116.2 | 1 | 279.0 | 278.5 |
| 4092 | hard | family_spread | 0 | 1329.6 | 0 | 332.4 | 332.4 |
| 1023 | hard | power_spread | 0 | 1875.8 | 10 | 469.0 | 433.1 |
| 2046 | easy | power_spread | 0 | 1082.9 | 1 | 270.7 | 268.3 |

*Optimistic lower bound on waiting because the production safety stop
disables 8x after core damage. All wall times exclude puzzle solving,
preparation, menus, rendering cost and human reaction time. Eligibility
does not mean the wave is harmless or that the player should accelerate it.

The feature leaves short early waves and fast damage builds alone; it is
offered most often to the slow tower-stack policies. This result motivates
a situational control rather than globally increasing game speed.

## Method

`godot/tests/research_pacing.gd` extends the existing campaign harness. All
runs and snapshots stay in memory. No player saves are read or written.
The source base is live 0.3.17 commit
`241040d787f1f9e27ad1d3e75d37706fd36c2af6`; the simulation is unchanged in
this candidate. Godot is `4.7.2.stable.official.ed1daf0bf`.

Nine earned 50-wave campaigns cover seeds 1023, 2046 and 4092, all three
combat difficulties and the family-spread, tower-stack and power-spread
allocation policies. Each campaign uses medium Sudoku and 18 legal answers
per round, real earned items, real upgrades, real chest rewards and the
existing repair/boost policy. The selected combinations include the known
slow cases and the baseline campaign with leaks. This is a selected sample,
not a full Cartesian matrix or a human win-rate estimate.

Every campaign supplies exact pre-wave snapshots for rounds
1, 5, 10, 25, 33, 44, 45, 48 and 50: **81 comparisons**. Each snapshot runs
unchanged, with each pushback budget, and with the same 0.1-second update
stream grouped into pairs. All 81 paired streams match their baseline's
entire serialized final run state, including RNG, damage, kills, leaks,
inventory, credits, fragments and chests. The report also checks explicit
reward accounting. Across these 81 snapshots the 8-unit cap changes wave
duration in ten cases; the 24-unit cap changes it in seven. The hard round
50 case above is the observed survival/reward counterexample for both.

Grouped updates establish simulation equivalence only when the constituent
update calls remain identical. Simply enlarging delta time changes the
substep grid and can change combat. The production UI repeats the ordinary
update calls and has separate frame-rate, pause, input and rendered tests.
This research harness does not substitute for those runtime tests.

The policies spend and allocate gear differently; they do not isolate pure
damage-only and control-only archetypes. Bots know every Sudoku answer,
place instantly, use earned repairs automatically and skip human reading,
solving and management time. Their boosts are checked on every simulated
update; a human reacting at 8x may choose differently. The UI must therefore
keep fast-forward optional, show remaining threats and make stopping easy.

## Reproduce

From the repository root, with a fresh isolated user-data directory:

```powershell
$pacingProfile = Join-Path $env:TEMP 'sudoku-pacing-research'
New-Item -ItemType Directory -Force -Path $pacingProfile | Out-Null
$env:APPDATA = $pacingProfile
$env:LOCALAPPDATA = $pacingProfile
$env:TEMP = $pacingProfile
$env:TMP = $pacingProfile
& 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe' --headless `
  --path godot --script res://tests/research_pacing.gd
# Or one exact campaign:
# ... -- --research-case=2046,easy,tower_stack
```

This explicit research test is not an automatic export-suite requirement.
The 600-second per-wave guard is an observation limit, not a change to game
rules. The Windows environment logs `Failed to read the root certificate
store` at startup; the harness uses no HTTPS or external services.

Final evidence: `qa-pacing-research/pacing-final.log` in the task workspace,
SHA-256 `3d57587bc945848c047e15cc41a39c2644c12cc0282464a61b4f6bff2c2b112d`.
Research script SHA-256:
`c71d55451751a8ea8a29924183eb0f67d25fa3421a1196e024f07aee15d4cfd2`.
Unchanged simulation file SHA-256:
`98153e40f4c5a8b682683de3c7527c3b8fc3f5f960fc975c144e6e2b4318cbf5`.

The remaining human acceptance is to play a control-heavy late wave and a
damage-focused wave, choose when to speed up, stop to change tactics, and
judge whether the resulting pace and readability feel comfortable. Hardware
frame rate, physical controller behavior and audible mix still need real
device testing.
