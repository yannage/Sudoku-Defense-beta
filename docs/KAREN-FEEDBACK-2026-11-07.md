> Historical source-candidate report supplied with Karen's patch. Its validation claims apply to the older 0.3.15 candidate. See [the 0.3.27 integration record](ITERATION-0.3.27-dev.md) for current provenance and acceptance.

# Karen playtest usability pass — 7 November 2026

## Integration status

This is an isolated **0.3.15-karen.1** candidate built on commit `36a84ac`
(`feature/wrong-guess-time-penalty`). It is **not a replacement for the newer
0.3.26 development build** and must not be activated on Steam as an upgrade.
The newer source was last recorded on the owner's Windows PC and was unavailable
in this workspace. Bring these changes into that source, preserve its controller
remapping and feedback features, and repeat validation before release.

## Changes for the next playtest

- Camp and Gear navigation includes controls below the scroll viewport. Moving
  back up no longer wraps to the top. Camp puts salvage slots first and explains
  the 10-credit cost and between-round restriction.
- Start opens direct Gear, Chests and Camp actions. Gear has an X prompt. Plain
  Gear and Chests labels replace unexplained numeric suffixes; unopened count
  and available inventory remain inside the relevant screens.
- Preparation and normal combat navigation move between planted towers. LB/RB
  cycle towers explicitly; solving keeps LB/RB number selection. Reserve planting
  remains available through an explicit Reserve seeds action and Start menu.
- Select several modules for one tower, then Install selected (Y). Selection
  respects free sockets and ownership; installation is all-or-nothing and stays
  on that tower. Single-module controller attachment returns to that tower's
  next empty socket. Slow, Range, Damage and Speed filters support build planning.
- Open All opens affordable chests in collected order, skipping chests that cost
  more fragments than remain. It grants each reward once and presents a combined
  reveal with pages for larger batches. Fragment prices and reward odds stay the
  same.
- Auto-open affordable chests is an optional, persistent setting available from
  the start. It waits for combat, dialogs, gear choices and active pointer
  gestures to finish; it does not overwrite an existing reward reveal.
- Combat hides fixed Sudoku clues, clue match highlights and the default number
  entry tray. Small tower-family badges remain useful for upgrades. The reserve
  action reveals the number tray when needed. Solving restores puzzle information.
- Help and the next-round screen explain that modules return to Gear on a new
  board and must be fitted to the new towers.

## Deliberately deferred

Shop/selling progression, harder enemy balance, super-hard mode, automatic module
distribution, and unlocking convenience settings after a victory. These need a
separate design/balance pass. Karen explicitly wants to keep choosing which
modules go on which towers.

## Validation completed

Godot 4.7.2 headless simulation/UI regressions pass in native and Canvas modes,
including the existing 1,338-check simulation/campaign suite, controller input,
touch/drag, camera navigation, preferences, loot, and new feedback-specific tests.
Targeted new coverage verifies atomic batch ownership, affordable chest costs,
duplicate inputs, scroll reversal, same-tower socket focus, explicit reserve
planting, and deferred automatic rewards. Updated prior tests retain cell-by-cell
navigation in Solve and test tower-only navigation in Prepare.

Real GLES screenshots under Xvfb/Mesa were inspected at Deck and portrait sizes
for Camp, batch gear, rewards, the menu, and both board renderers. These are
software-rendered checks, not a physical device test.

The final validation sweep has 47/47 passing headless suite/renderer combinations.
Linux and Windows exports completed and their ZIP contents were verified. The
exported Linux game reached `SUDOKU_DEFENSE_READY version=0.3.15-karen.1` without
errors. Windows execution was not tested. No build was deployed.

## Hardware retest

On Steam Deck or a controller, test Camp scrolling in both directions, a paid
spin, a multi-module install, Open All, a new round with returned modules, and
reserve planting during combat. Automated joypad and software-rendered tests
cannot establish physical Deck input or GPU behavior.
