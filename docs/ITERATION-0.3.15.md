# Sudoku Defense 0.3.15

## Controller placement

Nick's playtest feedback: selecting an empty Sudoku square should move controller
focus to the available numbers, then return to that exact square after placement.

- A on an empty square opens the number tray without placing the previous number.
- D-pad / left stick and LB / RB cycle available numbers. A places the highlighted
  number and returns board focus to the original square, including rotated views.
- B returns without placement. A rejected Solve answer leaves the tray open to
  retry. Fixed clues and existing tower inspection retain their behavior.
- Solve skips completed number families; Battle skips numbers without reserves.
  These are availability checks, not automatic Sudoku-answer assistance.
- Menus, phase changes, camera mode, focus loss, disconnects, and mouse/touch or
  right-stick cursor handoff cancel tray selection. A press cannot activate both
  the tray and the square beneath it. No new persistent save state is introduced.
- Mouse/touch and R3/RT cursor click/drag retain their existing placement flow.

## Validation and delivery

All 37 headless regression suites passed. The new native and Canvas controller
event tests each pass 292 checks at Deck and portrait sizes, including input
handoff, wrong-answer retry, cancellation, rotated-board targeting, focus loss,
disconnect/reconnect, and phase boundaries. Existing controller tests pass
113 native / 114 Canvas checks; touch passes 89 / 90; foundation tests pass
967 / 955. The packaged Linux executable starts with version 0.3.15.

Web, Linux, and Windows exports are prepared locally. The same regression is
registered for real-render CI and will capture Deck and portrait layouts.
Local real GLES rendering is unavailable in this environment. Native Windows
startup and real-render CI are pending public source publication. The browser
launch shell displays 0.3.15; the local preview browser could not start Godot
because it reported missing WebGL2 and secure-context support, so interactive
browser rendering was not verified in that preview.

The user has explicitly authorized public source publication and the Steam
build update. CI rendering, native Windows startup, and Steam delivery are in
progress. The browser preview is updated; the prior Steam default is 26208702
(0.3.14).

Review CI captures and stage the exact native-Windows-tested packages. Continue existing
Steam app 3721150 / shared depot 3721151 with Windows and Linux together.
Physical Steam Deck controller, suspend/resume, and install/update checks remain
separate from these automated checks.
