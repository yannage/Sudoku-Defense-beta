# Sudoku Defense — Godot edition

A native Godot 4.7.2 version of the pre-Unity Sudoku Defense game. The same GDScript game exports to Web, Windows x86-64, and Linux x86-64. No Electron, browser runtime wrapper, or Unity dependency is used by the desktop packages.

## Play

Open the published Godot edition in a current WebGL 2 browser. Version 0.3.1 adapts to portrait phones, wide landscape phones, and the Steam Deck screen. Portrait keeps the grid above a large number bar and four quick tabs; Tools reveals notes, hints, and reserve seeds. Management opens in a scrollable sheet, with the board still available for selecting towers. The launch page offers fullscreen and desktop downloads. For Windows, extract the ZIP and run `SudokuDefense.exe`. For Linux, extract the archive and run `sudoku-defense.x86_64`; the tar.gz also preserves execute permissions.

The browser export uses a lightweight voxel material with directional face colors, linear tone mapping, and no multisample resolve. Geometry, depth, aiming, tower growth, and chest animation remain native 3D. This addresses the reported all-black mobile board by avoiding the heavier rendering paths; the exact affected phone GPU still needs a retest. Desktop builds retain their standard lighting profile. Pass `--safe-graphics` to a desktop build to exercise the browser material profile.

The browser game saves automatically on that browser/device. Desktop builds save through Godot's `user://` storage. Browser and desktop saves do not synchronize. Steam Cloud and Steam achievements are not integrated in this version.

## The loop

1. **Solve:** select a square and enter a correct Sudoku number. Answers grow towers and earn credits. Notes show legal candidates. Plant roughly six to eight towers before the first easy wave.
2. **Prepare:** click a tower to inspect it, upgrade that tower or its whole number family, and attach up to five modules. Drag gear onto the board or workshop mini-grid, or select an item and choose a tower. Repeated modules stack.
3. **Defend:** recent correct placements shape the enemy route. Towers rotate toward targets. Reserve seeds can plant emergency towers even when a number is illegal; corruption strengthens remaining enemies. Open a management panel to pause the battle tactically.
4. **Loot:** use enemy energy fragments to open caches. Modules, family levels, credits, and passives persist through the run. Equipped gear returns to the bag on a new map. Salvage slots use fixed published odds and always grant common gear when the credit payout is below the stake.

Campaign lets you choose puzzle and combat difficulty each round, for up to fifty rounds. Locked In holds both difficulties for fifty rounds. Free Play is one round. Seeded puzzles have a unique solution; difficulty changes the clue count.

## Controls

| Action | Keyboard/mouse | Controller |
| --- | --- | --- |
| Select square | Click / arrows | D-pad / left stick |
| Choose number | Number bar / 1–9 | LB / RB |
| Plant or inspect | Click / number key | A |
| Open gear | Tab / Gear | X |
| Advance phase | Enter / phase button | Y |
| Back / menu | Escape | B |
| Pause / menu | P / Escape | Start |
| Fullscreen | F | Use desktop/window controls |

Dialogs and inventory support controller focus. A help screen and reduced-motion option are available in-game.

## Development

Import `project.godot` with Godot 4.7.2 standard (GDScript) edition. The Compatibility renderer is used to share visual assets with the WebGL 2 export. Install the matching official export templates.

```sh
godot --headless --path godot --script res://tests/test_run.gd
godot --headless --path godot --script res://tests/test_ui_flow.gd
python3 godot/scripts/build_exports.py --godot /path/to/godot
# On Linux with Xvfb/Mesa installed, require actual framebuffer validation too:
python3 godot/scripts/build_exports.py --godot /path/to/godot --render-check
```

Run these commands from the repository root. Output is in `godot/build/`. CI builds the same three exports on branch `godot-deck-edition` and on `godot-v*` tags. See `docs/GODOT-BUILDS.md` for packaging and Steam handoff.

## Validation and current limits

The simulation regression suite covers unique puzzles, first-wave survival, illegal placements, gear ownership, upgrades, cache accounting, fixed slot odds, deterministic mid-battle resume, and an automated fifty-wave medium campaign using earned gear and upgrades. UI flow tests exercise planting, inspection, equipment, panel bounds, tactical pause, and save/load at phone and Deck sizes. Real GLES framebuffer checks verify visible color on all 81 cells, digit contrast, board framing and picking, and visible voxel towers and chests. The render suite explicitly rejects dummy/headless rendering and captures the integrated phone and Deck HUD. The exported Linux executable must reach its ready marker without script errors.

These checks do not establish human campaign balance, physical Steam Deck controller behavior, GPU frame rate, or Windows execution. The current published Site requires owner sign-in that is unavailable in the test browser, so the exact phone/WebGL result remains unverified. GLES framebuffer tests use Mesa software rendering; they do not substitute for real mobile GPUs. This is a playable development build, not a Steam Deck Verified release. The existing Steam depot has not been replaced by this port.

Godot is MIT licensed; its copyright and third-party notices are included. Gameplay source, voxel meshes, UI, and synthesized audio were created for this project. See the parent repository for the earlier web reference and Unity work on their respective branches.
