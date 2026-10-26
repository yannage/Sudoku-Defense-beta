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
are outside this work. Steam default is **26208702** (0.3.14), with
**26205570** (0.3.12) retained for rollback.

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

After direct user authorization, source was published to the public repository.
Tested source: `c87e5b65f355286fde05c760fc50cef5501972e7`, workflow
[40264668345](https://github.com/yannage/Sudoku-Defense-beta/actions/runs/40264668345).
The exports/regression job **121384312185** and native Windows startup job
**121386702059** both passed. All 19 real GLES render suites passed, alongside
all 35 headless suites. Both exact packaged executables report version 0.3.14.

The first CI run passed all headless suites, both rendered tactics suites, and
native health-bar rendering. Its Canvas health test mistook neighboring gold
route pixels for health fill at two angles. The captured bars were aligned;
the test now matches the actual fill color and checks every fill, empty-track,
and border pixel. All 16 captured Canvas frames pass the corrected criteria.
This correction changes test code only. Deck, desktop, portrait, and landscape
tactics captures have been visually reviewed in both renderers.

The second CI attempt exposed a readability-test sample that landed on the new
foundation brackets. The floor sample now avoids those brackets; the required
4.5 contrast threshold is unchanged. Final minimum digit contrast is 5.54 native
and 4.66 Canvas. The render runner executes every suite, collects failures, and
still blocks exports if any fail. Final health, tactics, foundation, and
readability captures were visually reviewed in both renderers. Minor overlapping
Canvas reward labels during simultaneous rewards remain a future polish item.

Steam build **26208702**, depot manifest **5771364799624707360**, is verified live
on the existing default branch. All four uploaded file sizes and SHA-1 hashes
match the staging manifest. The update from 0.3.12 is approximately 1.8 MB.
The browser build and downloadable packages use the successful CI artifacts.
Local GLES capture remains unavailable because Xvfb cannot open display sockets;
CI supplies the rendered evidence. Physical Steam Deck/controller/phone checks
remain separate.

## Device playtest

- On Steam Deck, open Start → Wave intel during Solve or Prepare; scroll with
  the D-pad/left stick, read the boss profile, and return with B.
- Select a tower, choose Strongest or Nearest, then resume a saved run and
  confirm that tower retains its choice. Check touch and a docked controller.
- Rotate the board during battle and inspect full, partial, and nearly empty
  enemy health bars. Place several numbers quickly during Solve and inspect
  the immediate digits and short foundation assembly.
- Check Steam-client installation/update, audio, frame rate, suspend/resume,
  and controller reconnect on the physical device.
