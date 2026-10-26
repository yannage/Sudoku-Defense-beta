# Sudoku Defense 0.3.13

## Requested changes

- Keep enemy health foreground and background aligned during enemy movement and camera rotation.
- Replace the disconnected brown seed animation with a clear number-to-tower action.
- Continue related polish while preserving the existing game and Steam deployment scope.

## Behavior

Correct Sudoku placement commits and displays its number immediately. Four
family-colored voxel brackets assemble around it, leaving the digit readable.
The foundation remains in the square and connects visually to the tower that
grows during preparation. The animation lasts 0.50 seconds and does not hold up
input or other placements. Reduced motion shows the final result immediately.

Enemy health bars use one native camera-facing surface, so the track and fill
share one plane. The fill shrinks from the right inside a consistent border.
The compatible Canvas renderer uses the same inset geometry and colors.

Sound, reduced-motion, and notes settings persist on the current device/browser,
separately from game progress. A new run retains the player's settings.

## Delivery scope

Source of truth: `yannage/Sudoku-Defense-beta`, branch `godot-deck-edition`,
directory `godot/`. Continue existing Steam app **3721150** and shared depot
**3721151**. The previous verified default build is **26205570** (0.3.12).
Any replacement must contain both Windows and Linux executables plus notices.
The separate Playtest and public-release status are outside this iteration.

## Validation and publication

The full build helper passed all 32 headless suites and freshly exported Web,
Linux, and Windows with Godot 4.7.2. Linux startup reported version 0.3.13.
Placement passed 966 native / 954 Canvas assertions, health-bar geometry passed
226 native / 194 Canvas checks, and preference persistence passed 21 per
renderer. Existing camera, input, UI, loot, and campaign regressions passed.

Local GLES capture is unavailable because Xvfb cannot open its display sockets.
The existing CI workflow includes both new suites and rendered health/placement
captures, but GitHub source publication was blocked by automatic approval review
requesting direct user authorization. No new CI run, Windows execution validation,
or Steam upload/activation has occurred. The previous Steam build remains the
last verified live build. Physical Steam Deck/controller/phone checks remain
separate from automated validation.
