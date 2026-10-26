# Sudoku Defense 0.3.14

## Core gameplay

- Wave intel shows the exact upcoming enemy mix, each type's health, speed and
  core damage, spawn spacing, and a boss warning. The prep HUD keeps a compact
  summary; details open without covering the board during normal play.
- Towers can prioritize First (furthest along the route), Strongest (highest
  remaining health), or Nearest (distance from the tower). All modes respect
  range and exclude defeated enemies. Changes cost no credits.
- Target choices persist in run saves. Old or unknown priorities become First,
  preserving existing games. Management overlays tactically pause the run.
- Forecast and spawning share a deterministic blueprint. Existing enemy counts,
  difficulty curves, kind ordering, boss replacement, and corruption scaling are
  preserved; inspecting intel consumes no random numbers or simulation state.

This release includes the 0.3.13 health-bar alignment, voxel foundation assembly,
and persistent player preferences.

## Delivery scope

Continue `yannage/Sudoku-Defense-beta`, branch `godot-deck-edition`, with `godot/`
as the maintained source. Existing Steam app **3721150**, shared depot **3721151**,
must contain Windows and Linux together. The separate Playtest and public release
are outside this work. The last verified Steam default is **26205570** (0.3.12).

## Validation and publication

The tactical model passes 53,989 checks, including all 50 rounds, all three combat
difficulties, three corruption levels, exact spawn correspondence, independent
legacy balance formulas, RNG/state purity, actual target selection, and save
migration/replay. All 35 headless regression suites pass. The tactics UI passes
223 assertions per renderer across 1280×800, 1920×1080, 390×844, and 844×390,
including real controller/mouse/touch dispatch, visible forecast text, scrolling,
save/reload, tactical pause, and input isolation. Existing run simulation passes
1,338 checks. Godot 4.7.2 freshly exported Web, Linux, and Windows. The packaged
Linux executable starts successfully and reports version 0.3.14. ZIP central
directories, CRCs, and content hashes are verified by the packaging helper.

Automatic approval review rejected publication of the pending 0.3.13 source to
the public GitHub repository: continuing development was not considered explicit
permission to disclose new source publicly. No workaround was attempted. The
0.3.14 source therefore also remains local/private until direct authorization.
The existing CI pipeline includes rendered tactics captures and native Windows
startup, but cannot run against this source until publication is authorized.
No Steam upload or activation has occurred. Local GLES capture is unavailable
because Xvfb cannot open display sockets; physical device checks remain separate.
