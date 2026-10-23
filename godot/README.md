# Sudoku Defense — Godot edition

A native Godot 4.7.2 version of the pre-Unity Sudoku Defense game. The same GDScript game exports to Web, Windows x86-64, and Linux x86-64. No Electron, browser runtime wrapper, or Unity dependency is used by the desktop packages.

## Play

Open the published Godot edition in a current WebGL 2 browser. Version 0.3.3 adapts to portrait phones, wide landscape phones, and the Steam Deck screen. Portrait keeps the grid above a large number bar and four quick tabs; Tools reveals notes, hints, and reserve seeds. Management opens in a scrollable sheet, with the board still available for selecting towers. The launch page offers fullscreen and desktop downloads. For Windows, extract the ZIP and run `SudokuDefense.exe`. For Linux, extract the archive and run `sudoku-defense.x86_64`; the tar.gz also preserves execute permissions.

The browser export now projects the voxel board and animated chests with ordinary Godot CanvasItem polygons. This bypasses the entire spatial rendering pass that continued to show black on the affected phone, even with simpler materials. The same GDScript run drives tower growth, aiming, routes, equipment, combat, and loot. Desktop builds retain the native 3D scene; pass `--canvas-graphics` to use the browser's compatible voxel view on desktop. The older `--safe-graphics` option only simplifies desktop 3D materials and is no longer the web default. The exact phone still needs a retest; local framebuffer checks cannot establish its GPU behavior.

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
| Select square / navigate controls | Click / arrows | D-pad / left stick |
| Choose number on board | Number bar / 1–9 | LB / RB; A plants |
| Plant / inspect / confirm | Click / number key | A |
| Open gear | Tab / Gear | X |
| Switch management tabs | Click Tower / Bag / Loot / Camp | LB / RB |
| Advance phase from board | Enter / phase button | Y |
| Back / cancel selection | Escape | B |
| Pause / resume menu | P / Escape | Start / Menu |
| Help | ? | View / Back |
| Fullscreen | F | Use desktop/window controls |

Native desktop builds read gamepad buttons and sticks directly through Godot. A mouse is not required for the main game loop. Menu and inventory focus stays visible as lists scroll; gameplay input is isolated from open panels. Selecting a number with the shoulders does not plant it until A confirms. Equipment supports selecting a module, choosing its target tower, then confirming with A. The seed entry offers an in-game number pad for controller-only replay setup. Losing the active controller pauses the run. Touch and mouse controls remain available alongside the controller.

For Steam Deck testing, use the **Gamepad** Steam Input template so its controls reach the game as gamepad input. The older web wrapper's mouse/keyboard layout is not the intended layout for this Godot build. Steam's published default configuration has not been changed by these source updates. A help screen and reduced-motion option are available in-game.

## Development

Import `project.godot` with Godot 4.7.2 standard (GDScript) edition. The Compatibility renderer is used to share visual assets with the WebGL 2 export. Install the matching official export templates.

```sh
godot --headless --path godot --script res://tests/test_run.gd
godot --headless --path godot --script res://tests/test_ui_flow.gd
godot --headless --path godot --script res://tests/test_ui_flow.gd -- --canvas-graphics
godot --headless --path godot --script res://tests/test_controller_flow.gd
godot --headless --path godot --script res://tests/test_controller_flow.gd -- --canvas-graphics
python3 godot/scripts/build_exports.py --godot /path/to/godot
# On Linux with Xvfb/Mesa installed, require actual framebuffer validation too:
python3 godot/scripts/build_exports.py --godot /path/to/godot --render-check
```

Run these commands from the repository root. Output is in `godot/build/`. CI builds the same three exports on branch `godot-deck-edition` and on `godot-v*` tags. See `docs/GODOT-BUILDS.md` for packaging and Steam handoff.

## Validation and current limits

The simulation regression suite covers unique puzzles, first-wave survival, illegal placements, gear ownership, upgrades, cache accounting, fixed slot odds, deterministic mid-battle resume, and an automated fifty-wave medium campaign using earned gear and upgrades. UI flow tests run with both board renderers and exercise planting, inspection, equipment, panel bounds, tactical pause, and save/load at phone and Deck sizes. Controller tests send native joypad events through the scene to check board movement, focus navigation, confirmation, inventory, upgrades, and input isolation. Real GLES framebuffer checks cover both 3D and compatible CanvasItem voxels: visible cells and digits, board framing and picking, towers, chests, and the integrated phone/Deck HUD. The render suites reject dummy/headless rendering. The exported Linux executable must reach its ready marker without script errors.

These checks do not establish human campaign balance, physical Steam Deck controller behavior, GPU frame rate, or Windows execution. The current published Site requires owner sign-in that is unavailable in the test browser, so the exact phone/WebGL result remains unverified. GLES framebuffer tests use Mesa software rendering; they do not substitute for real mobile GPUs. This is a playable development build, not a Steam Deck Verified release. The existing Steam depot has not been replaced by this port.

Godot is MIT licensed; its copyright and third-party notices are included. Gameplay source, voxel meshes, UI, and synthesized audio were created for this project. See the parent repository for the earlier web reference and Unity work on their respective branches.
