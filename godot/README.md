# Sudoku Defense — Godot edition

A native Godot 4.7.2 version of the pre-Unity Sudoku Defense game. The same GDScript game exports to Web, Windows x86-64, and Linux x86-64. No Electron, browser runtime wrapper, or Unity dependency is used by the desktop packages.

## Play

Open the published Godot edition in a current WebGL 2 browser. Version 0.3.5 adapts to portrait phones, wide landscape phones, and the Steam Deck screen. Portrait keeps the grid above a large number bar and four quick tabs; Tools reveals notes, hints, and reserve seeds. Gear, Chests, and Camp use voxel icons with short labels and counts. Management opens in a scrollable sheet, with the board still available for selecting towers. The launch page offers fullscreen and desktop downloads. For Windows, extract the ZIP and run `SudokuDefense.exe`. For Linux, extract the archive and run `sudoku-defense.x86_64`; the tar.gz also preserves execute permissions.

The browser export now projects the voxel board and animated chests with ordinary Godot CanvasItem polygons. This bypasses the entire spatial rendering pass that continued to show black on the affected phone, even with simpler materials. The same GDScript run drives tower growth, aiming, routes, equipment, combat, and loot. Desktop builds retain the native 3D scene; pass `--canvas-graphics` to use the browser's compatible voxel view on desktop. The older `--safe-graphics` option only simplifies desktop 3D materials and is no longer the web default. The exact phone still needs a retest; local framebuffer checks cannot establish its GPU behavior.

The browser game saves automatically on that browser/device. Desktop builds save through Godot's `user://` storage. Browser and desktop saves do not synchronize. Steam Cloud and Steam achievements are not integrated in this version.

## The loop

1. **Solve:** tap an empty square, then a number, or drag a number from the bottom bar onto its square. Answers grow towers and earn credits. Bold borders separate the nine 3×3 boxes; the selected square has its own clear outline. Choosing a number highlights every matching clue and planted number. Notes show legal candidates. Plant roughly six to eight towers before the first easy wave.
2. **Prepare:** click a tower to inspect it, upgrade that tower or its whole number family, and attach up to five modules. Number badges identify planted towers; the workshop highlights the selected family's actual towers and shows how many an upgrade affects. Drag gear onto the board or workshop mini-grid, or select an item and choose a tower. Repeated modules stack.
3. **Defend:** recent correct placements shape the enemy route. Towers rotate toward targets. Cycle battle speed through **1×, 2×, and 4×**; the Sudoku solve countdown stays at normal speed. Reserve seeds can plant emergency towers even when a number is illegal; corruption strengthens remaining enemies. Open a management panel to pause the battle tactically.
4. **Loot:** use enemy energy fragments to open caches. Modules, family levels, credits, and passives persist through the run. Equipped gear returns to the bag on a new map. Salvage slots use fixed published odds and always grant common gear when the credit payout is below the stake.

Campaign lets you choose puzzle and combat difficulty each round, for up to fifty rounds. Locked In holds both difficulties for fifty rounds. Free Play is one round. Every generated puzzle is checked for valid rows, columns, and boxes, agreement with its complete solution, and exactly one solution. Difficulty changes the clue count. Restored saves are checked against the same Sudoku rules, while explicit emergency towers remain allowed during battle.

## Controls

| Action | Touch / keyboard / mouse | Controller |
| --- | --- | --- |
| Select square / navigate controls | Tap / click / arrows | D-pad / left stick |
| Choose number / highlight matches | Number bar / 1–9 | LB / RB; A plants |
| Plant / inspect / confirm | Tap square then number; drag number to square; tap tower to inspect | A |
| Open gear | Tab / Gear | X |
| Switch management tabs | Click Tower / Bag / Loot / Camp | LB / RB |
| Advance phase from board | Enter / phase button | Y |
| Back / cancel selection | Escape | B |
| Pause / resume menu | P / Escape | Start / Menu |
| Help | ? | View / Back |
| Fullscreen | F | Use desktop/window controls |

Native desktop builds read gamepad buttons and sticks directly through Godot. A mouse is not required for the main game loop. Menu and inventory focus stays visible as lists scroll; gameplay input is isolated from open panels. Selecting a number with the shoulders does not plant it until A confirms. Equipment supports selecting a module, choosing its target tower, then confirming with A. The seed entry offers an in-game number pad for controller-only replay setup. Losing the active controller pauses the run. Touch and mouse controls remain available alongside the controller.

Version 0.3.5 accepts mouse-only touchscreen clicks, including emulated mouse events without a matching raw touch. Paired touch/mouse events share one gesture so a tap or drag acts once. Steamworks remains configured for **Left Mouse Click Emulation**; the project explicitly enables Godot mouse-from-touch emulation for menus. The automated input checks do not replace a physical Steam Deck test.

Touching an empty square selects it without planting the previously chosen number. A number-bar tap commits to the selected empty square; dragging previews the destination and only places on release. Dropping outside the board cancels. The same interactions work with physical touchscreen events, mouse input, and Steam Deck's touchscreen mouse emulation.

The number bar turns a digit gray after all nine correct placements are present. It remains available for highlighting matches, and a fresh puzzle recalculates completion from its own board. Incorrect emergency towers do not count toward completion. Number 9 uses a soft orchid color; red is reserved for danger and invalid actions.

For Steam Deck testing, use the **Generic Gamepad** Steam Input template published as this app's default so its controls reach the game as gamepad input. The older web wrapper's mouse/keyboard layout is not the intended layout for this Godot build. A help screen and reduced-motion option are available in-game.

## Development

Import `project.godot` with Godot 4.7.2 standard (GDScript) edition. The Compatibility renderer is used to share visual assets with the WebGL 2 export. Install the matching official export templates.

```sh
godot --headless --path godot --script res://tests/test_run.gd
godot --headless --path godot --script res://tests/test_sudoku.gd
godot --headless --path godot --script res://tests/test_ui_flow.gd
godot --headless --path godot --script res://tests/test_ui_flow.gd -- --canvas-graphics
godot --headless --path godot --script res://tests/test_controller_flow.gd
godot --headless --path godot --script res://tests/test_controller_flow.gd -- --canvas-graphics
godot --headless --path godot --script res://tests/test_touch_flow.gd
godot --headless --path godot --script res://tests/test_touch_flow.gd -- --canvas-graphics
godot --headless --path godot --script res://tests/test_family_workshop.gd
godot --headless --path godot --script res://tests/test_family_workshop.gd -- --canvas-graphics
python3 godot/scripts/build_exports.py --godot /path/to/godot
# On Linux with Xvfb/Mesa installed, require actual framebuffer validation too:
python3 godot/scripts/build_exports.py --godot /path/to/godot --render-check
```

Run these commands from the repository root. Output is in `godot/build/`. CI builds the same three exports on branch `godot-deck-edition` and on `godot-v*` tags. See `docs/GODOT-BUILDS.md` for packaging and Steam handoff.

## Validation and current limits

The simulation regression suite covers unique puzzles, first-wave survival, illegal placements, gear ownership, upgrades, cache accounting, fixed slot odds, deterministic mid-battle resume, and an automated fifty-wave medium campaign using earned gear and upgrades. UI flow tests run with both board renderers and exercise planting, inspection, equipment, panel bounds, tactical pause, and save/load at phone and Deck sizes. Controller tests send native joypad events through the scene to check board movement, focus navigation, confirmation, inventory, upgrades, and input isolation. Real GLES framebuffer checks cover both 3D and compatible CanvasItem voxels: visible cells and digits, board framing and picking, towers, chests, and the integrated phone/Deck HUD. The render suites reject dummy/headless rendering. The exported Linux executable must reach its ready marker without script errors.

These checks do not establish human campaign balance, physical Steam Deck controller behavior, GPU frame rate, or Windows execution. The exact phone/WebGL result still requires device testing. GLES framebuffer tests use Mesa software rendering; they do not substitute for real mobile GPUs. This is a playable development build, not a Steam Deck Verified release. The existing Steam depot now serves the native Godot port; see `docs/STEAM-RELEASE.md` for the verified build record.

Godot is MIT licensed; its copyright and third-party notices are included. Gameplay source, voxel meshes, UI, and synthesized audio were created for this project. See the parent repository for the earlier web reference and Unity work on their respective branches.
