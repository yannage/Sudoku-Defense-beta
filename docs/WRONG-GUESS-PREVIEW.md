# Wrong-guess time penalty preview

Based on the recoverable Godot 0.3.15 source at
`ec17ef2f722a34e4e50312e2b418e1bb5331d179`, on the separate
`feature/wrong-guess-time-penalty` branch. Version: `0.3.15-penalty.1`.
This browser feature preview must be merged into the current Steam source before
it is used to replace a newer Steam candidate.

## Behavior

- Each wrong answer on an empty square during Solve costs five seconds.
- Remaining time clamps at zero; the existing Solve-to-Prepare transition runs
  immediately, exactly once. No automatic jump into Battle.
- Feedback marks the affected square with a red outline and X, and displays
  `WRONG ANSWER` plus the actual time lost. If less than five seconds remained,
  the displayed deduction is the remaining amount. Repeated misses aggregate
  the recent loss for that square and show the number of guesses.
- Feedback follows the square through board rotation and the Prep camera change.
  It uses a shared, noninteractive layer for native 3D and browser Canvas voxels,
  with static markers suitable for reduced motion.
- The timer is saved even though the guessed answer is rejected, so resuming
  cannot restore the deducted time.
- Controller retries remain in the number tray while time remains. At zero,
  focus returns safely to the board. Mouse, touch, drag, and keyboard use the
  same model rule.
- Correct answers, hints, occupied-square interactions, malformed selections,
  and non-Solve errors do not receive this penalty. Battle reserve placement
  and corruption retain their existing rules.

## Checks

The build helper registers model regression tests and native/Canvas UI tests,
plus two real GLES feedback capture suites. Captures are written beneath
`godot/build/wrong-guess-checks/` and collected by GitHub Actions.

Physical Steam Deck/controller testing and browser GPU testing remain separate
from automated checks. This feature preview does not change Steam branches,
store settings, Cloud, or achievements.
