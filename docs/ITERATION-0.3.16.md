# 0.3.16 release-preparation candidate

This local candidate continues the native Godot game from `ec17ef2` on
`godot-deck-edition` (0.3.15). It is not a Steam release or branch activation.
Steam remains at its separately verified 0.3.15 / build 26283775.

## Guided first round

Choose **Guided first round** on new-run setup, or **Play guided first round**
in How to play. A practice round uses the actual Sudoku, combat, gear and chest
systems. It teaches placement with the existing controller number picker,
route shaping, preparing with an unfinished puzzle, fitting a module, launching
the first wave and claiming its reward. The solve timer pauses while learning.
Help reopens the current step; every instruction card offers Skip guide.

Practice never writes a campaign save. Leaving restores an existing in-memory
run, its pause state and battle speed; entering from the title menu leaves any
disk save available to continue. A practice reward guarantees enough fragments
to learn opening one chest, without transferring rewards into a real run.

## Run recovery

Run writes are verified before a write-ahead journal becomes the commit point.
The prior valid snapshot remains as a last-good backup. Recovery understands an
interrupted journal promotion, a missing primary, invalid JSON and invalid nested
run data. Existing run JSON remains readable. Save failures have persistent
feedback, a retry action, and an explicit unsaved-progress choice on close.

Godot's Windows rename implementation removes an existing destination first;
a lone temporary-file rename would leave a failure window. The journal and
backup protect that window. FileAccess.flush and process-interruption tests do
not establish durability against a physical device suddenly losing power.

## Strategy, results and comfort

Placement and route previews, family upgrade consequences and wave coverage
make existing choices easier to understand. Results include observed combat
contributions and core damage, with a same-seed retry. Historical saves without
the new statistics must not invent past combat performance.

Audio settings offer saved Master, Music and Effects levels, separate from
mute. Five-percent buttons support D-pad, stick, pointer and touch navigation.
Existing mute, notes and reduced-motion preferences remain compatible.

## Pacing evidence

See [the balance experiment](BALANCE-0.3.16.md) for deterministic bot strategies,
seeded outcomes and limitations. The experiment does not establish human solve
time, fun, difficulty or accessibility. Combat tuning requires those playtests;
the pass does not add more modes, rounds, minigames or progression systems.

## Steam Deck acceptance checklist

Automated joypad dispatch and layout checks are not physical Deck testing.

- Start the guide with the controller. Place its first number using A, choose
  from the tray, and confirm return to the same square. Repeat with touch.
- Prepare before finishing the Sudoku. Fit gear via controller and via a
  workshop socket; dismiss guidance and launch using Y.
- Finish the wave, open a chest once, leave practice, and confirm the original
  run resumes. Skip/replay from Help and the title menu too.
- Play a run using only the controller: inventory, five sockets, chest reveal,
  targeting, family upgrades, pause, loss/victory and same-seed retry.
- Change all three audio levels; check 0%, mute/unmute and quit/relaunch.
- Save and relaunch during Solve, Prep, Battle and Loot. Suspend/resume during
  combat and while a panel or number tray is open. Check focus and held inputs.
- At 1280x800, check small text, board numbers, forecast explanations and result
  scrolling. Confirm no controls become unreachable after switching to touch.
- Play later boss rounds with spread damage, concentrated damage and control
  builds. Judge pacing at 1x/2x/4x and whether losses suggest a useful retry.

## Validation record

Final source hash, package checksums, passed suites and unrun checks are recorded
with the delivered candidate. Public GitHub publication, visual CI, Steam upload,
branch activation and paid release are outside this implementation pass.
