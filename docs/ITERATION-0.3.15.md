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

All 37 headless and 21 real GLES render suites passed. The new native and Canvas
controller event tests each pass 292 checks, both headlessly and with real GLES,
at Deck and portrait sizes, including input
handoff, wrong-answer retry, cancellation, rotated-board targeting, focus loss,
disconnect/reconnect, and phase boundaries. Existing controller tests pass
113 native / 114 Canvas checks; touch passes 89 / 90; foundation tests pass
967 / 955. Eight controller captures showing the tray and return to the board
at Deck-size and portrait layouts were visually reviewed in both renderers.

The tested source is public at
`f9b8b7175932c3bb5a1429da7d0f45d29caa6c0b` on `godot-deck-edition`.
Workflow [40781236912](https://github.com/yannage/Sudoku-Defense-beta/actions/runs/40781236912)
passed exports/regression job **123143148330** and native Windows startup job
**123147874016**. Both exact packaged executables report version **0.3.15**.
The prepared Site assets and downloadable packages use the successful CI Web
and desktop artifacts.

On **October 28, 2026 (America/New_York)**, Steam build **26283775**, depot manifest
**8369338940309472302**, was verified live on the existing app **3721150** default
branch. Shared depot **3721151** contains Windows and Linux together with both
Godot notices; all four uploaded file sizes and SHA-1 hashes match staging.
Steam preview reported a **1.8 MB** update. Previous default build **26208702**,
manifest **5771364799624707360**, remains available for rollback. The separate
Playtest and public-release state were not changed. Full package provenance is
recorded in [STEAM-RELEASE.md](STEAM-RELEASE.md).

Local real GLES rendering is unavailable in this environment; CI supplies the
rendered evidence. The local browser preview displayed the 0.3.15 launch shell
but could not start Godot because it reported missing WebGL2 and secure-context
support. Interactive browser rendering was therefore not verified in that
preview. Physical Steam Deck controller, suspend/resume, audio, performance,
and Steam-client install/update checks remain separate from automated validation.
