# Sudoku Defense: Godot builds

The `godot/` project is the native Godot version. It uses Godot **4.7.2 stable**, GDScript, and the Compatibility renderer so the same game can export to Web, Windows, and Linux. It does not launch the previous web game inside a desktop wrapper.

## Local export

Install the official Godot 4.7.2 editor and matching export templates. Then run:

```sh
python3 godot/scripts/build_exports.py --godot /absolute/path/to/godot
```

Use `--targets web`, `--targets linux`, or `--targets windows` for a narrower build. Generated files stay under the ignored `godot/build/` directory. The helper imports resources, runs the simulation and UI-flow tests, fails on Godot script errors, exports the selected platforms, boots the Linux executable headlessly when selected, and creates packages plus SHA-256 checksums. Tests must print their success markers; the exported Linux game must print its ready marker after its board, run, and UI are initialized.

Use `--render-check` to additionally require the real GLES framebuffer suites. They run on the current display or use `xvfb-run` when no display is set; a dummy/headless renderer is rejected. Install Xvfb, xauth, Mesa OpenGL drivers, and EGL first. CI requires these checks and uploads screenshots from `godot/build/render-checks/` alongside the logs. The CanvasItem suite passes `--canvas-graphics` to exercise the browser's board path with 3D disabled; the spatial suite retains `--safe-graphics` coverage. Pixel checks validate visible board content instead of relying only on successful process exit. UI-flow checks also run with both board renderers.

Outputs:

| Output | Purpose |
| --- | --- |
| `godot/build/web/index.html` | Actual Godot WebAssembly game and minimal loading screen |
| `godot/build/web/downloads.html` | Windows, Linux, and source downloads for the published Site |
| `godot/build/windows/SudokuDefense.exe` | Windows x86-64 executable with embedded game data |
| `godot/build/linux/sudoku-defense.x86_64` | Linux x86-64 executable with embedded game data |
| `godot/build/downloads/` | ZIP packages, Linux tarball, source ZIP, checksums |
| `godot/build/logs/` | Import, export, and Linux boot logs |

## Browser hosting

Publish the contents of `godot/build/web/` as a static site over HTTPS. WebGL 2 is required. The export is single-threaded, so it does not require cross-origin isolation or special COOP/COEP response headers. The launch button provides a user interaction before the engine starts, which permits browser audio.

The standard Godot engine WASM exceeds the static host's 25 MiB per-file limit. The build helper splits that one asset into 10 MiB chunks and verifies that concatenating them produces the exact exported bytes. A narrowly scoped fetch adapter in `scripts/web_shell.html` reconstructs the original WASM response. `engine-manifest.json` records sizes and checksums. All gameplay remains GDScript in the actual Godot engine.

The build helper must be run after exporting in the Godot editor; simply copying the raw Web export would skip this hosting preparation. Test the published browser build visually and interactively in addition to headless checks.

The desktop download page reconstructs large ZIP packages from static chunks, verifies each chunk and the completed ZIP with SHA-256, and downloads a normal ZIP file. The small source ZIP is served directly. Download metadata lives in `web/downloads/manifest.json`. Use `--stage-downloads-only` to stage existing archives without exporting; this does not update their contents. For a release, export all targets together so downloadable packages match the browser game.

The web shell owns canvas sizing with resize policy `0`, a safe-area container, and a device-pixel-ratio cap of 2. Godot follows the actual canvas size while the HUD selects its logical layout by aspect ratio. Fullscreen starts from an explicit user tap. Engine graphics errors are retained locally behind an optional diagnostics panel; no telemetry is sent. Since 0.3.2 the browser disables viewport 3D entirely and draws projected voxel board/chest geometry through ordinary Godot CanvasItem commands. It uses no spatial shaders, viewport textures, or MultiMesh2D. This preserves the same gameplay while bypassing the black spatial output reported on a phone. Desktop uses native 3D by default; `--canvas-graphics` selects the compatible view there too.

Every desktop folder and browser distribution includes `GODOT-LICENSE.txt` and `GODOT-THIRD-PARTY.txt`. The download page links both notices. The build fails if either required notice is missing from the project.

## GitHub builds and downloads

`.github/workflows/godot.yml` builds the project on changes to the `godot-deck-edition` branch, on relevant pull requests, or by manual workflow dispatch. It downloads the official editor and templates and checks their published SHA-512 hashes before running them. Workflow artifacts contain Web, desktop, source, and validation logs.

Tags beginning with `godot-v` also create a GitHub release with the packages. Tag only a reviewed and tested commit; the workflow does not upload to Steam or change Steam's live build.

## Steam and Steam Deck

The Windows and Linux builds are separate deliverables from the same project. The Windows build is a candidate for testing through Proton. The Linux build runs natively and should use a Linux launch option without a forced Proton override.

For the existing Steam app 3721150/Linux depot 3721151, run `python3 steam/prepare_godot_linux.py` after exporting. It copies the Godot ELF byte-for-byte to a staging directory with the stable Steam launch filename `sudoku-defense`, includes the license notices, tests the renamed executable, and creates a Standard-replacement ZIP. The normal Linux download still uses `sudoku-defense.x86_64`. See [STEAM-RELEASE.md](STEAM-RELEASE.md) for the exact staging paths, current Steam upload record, and existing depot configuration. The Windows download uses `SudokuDefense.exe`; do not assume a Windows Steam depot exists. Verify launch, controls, audio, save/resume, and performance on an installed testing build before promoting it for a wider audience.

### Controller setup for this port

Godot's desktop exports use its native gamepad input; receiving the Deck's buttons and sticks does not require a browser wrapper or the Steam Input API. Godot has used SDL 3 for desktop controllers since 4.5. The web export uses a different controller backend, so a browser pass is not a substitute for testing the installed Deck build. See [Godot controller support](https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html).

The built-in **Generic Gamepad** Steam Input template was published as this app's default on October 23, 2026, with touchscreen Left Mouse Click Emulation preserved. The template supplies ordinary gamepad events; test it against the installed executable and check that the entire game works without holding the Steam button to emulate a mouse. A custom Steam Input action manifest is not part of this build. For future releases, recheck the current published configuration. Valve describes the template choices in [Gamepad Emulation Best Practices](https://partner.steamgames.com/doc/features/steam_controller/steam_input_gamepad_emulation_bestpractices).

The required device pass is: launch from the Deck library; use D-pad/stick and A to select a mode/difficulty and start; plant numbers with LB/RB and A; inspect/upgrade a tower; select and equip gear; open a cache and use an item; visit camp; move to another round; pause/resume and resume a save. Test a controller disconnect/reconnect and Deck suspend/resume too. Confirm every menu can be exited with B and no open panel sends button presses through to the board. The default configuration must expose the entire game, as described by [Valve's Deck recommendations](https://partner.steamgames.com/doc/steamhardware/recommendations).

The controller regression suite injects joypad button/axis events through the actual scene for both board renderers. It checks the application's routing and focus behavior, not SDL hardware discovery or physical Deck mappings. Keep the native Deck pass as a release requirement before claiming Steam's Full Controller Support or Deck Verified status.

Headless import and executable boot checks detect packaging and script errors. They do not establish controller usability, graphics performance, Proton compatibility, or Steam Deck verification. Browser play is a convenient test surface; desktop and Deck testing remain separate release gates.

## Current source and verification

Version **0.3.9** revises player-facing instructions, tooltips, loot descriptions, and menu copy. Runs, rounds, Gear, modules, boosts, and chests use consistent terms. Chest rewards show the same effect names as the inventory. Help explains Sudoku rules, reserve seeds, corruption, and progression directly; the slot machine lists actual credit returns. Loot tooltips derive current descriptions from item stats so saved gear uses the revised copy too. The battle HUD now reports enemies left in the current wave instead of comparing run-wide kills with a single wave total. A regression covers later-round and portrait counters.

Version **0.3.8** refreshes the menus with a Canvas-rendered voxel diorama, illustrated expedition choices, beveled surfaces, and a compact pause menu that keeps Resume prominent. The replay-seed label and input are separated so the label cannot collapse into a vertical string. Equipment drags use a 56-pixel voxel token instead of a text card, while tower targets show socket pips and a small valid/full mark. The workshop, inventory, and camp share illustrated tabs and clearer action hierarchy. The menu regression checks content bounds and primary-action reachability at Deck, docked, and portrait layouts, including real pointer Start/Resume activation.

Version **0.3.7** adds a free cursor controlled by the right stick, with R3 or RT as a held left click and LT for precision. Cursor clicks reach the board, number bar, quick panels, menus, and chests; holding RT also drags seeds and equipment. Lists scroll when the cursor rests near their vertical edges. Left-stick/D-pad focus navigation and the existing shortcuts remain available. Pointer events generated by the controller retain gamepad hints and do not cancel themselves through the physical-input handoff code. Focus loss, controller loss, and navigation takeover cancel a held gesture without committing its click or drop.

The cursor uses the same GUI pointer paths as mouse/touch input. Native builds synchronize the operating-system cursor before injecting mouse events, while Web updates Godot's input position directly. The cursor regression drives joystick events through the main scene at Deck and docked display sizes, including real GUI seed/module drags; physical Xbox-controller and docked-Deck behavior still needs device testing.

Version **0.3.6** replaces the chest list with a dedicated voxel loot table. Chests display their fragment costs, animate open, and reveal all earned items together. Rewards are granted atomically before presentation, and the reveal survives panel refresh or closing/reopening without spending twice. Up to six chests render per page; hidden native chest viewports stop updating. Reduced motion shortens the opening and removes the reward bounce.

Gear now uses visual tiles with Attack, Support, and Items filters, direct effect summaries, and a selected-module comparison. The reveal's gear action brings earned items to the front with NEW badges, without equipping or consuming them. The workshop puts five visible sockets near its top. A drag previews the target's next layer and free slot; dropping onto an occupied workshop socket swaps the old module back into the bag. The actual equipped layer snaps into place. Unselected tower number badges are smaller and translucent while selected/family previews remain readable. The management sheet also owns input above covered HUD buttons, preventing the phone's Tools button from intercepting inventory taps.

New table and integration suites cover exactly-once rewards, raw touch and mouse dragging, tap/controller equipment, inventory ownership, full stacks, and phone/Deck bounds in both render paths. The rendered synthetic drag fixture synchronizes the operating-system cursor because Godot's injected input events do not move it; separate headless checks exercise raw touch without that fixture adjustment. These checks do not establish physical Deck touchscreen behavior.

Version **0.3.5** fixes an input-routing gap: standalone emulated mouse events were previously discarded on the board and number bar. They now work as direct pointer clicks, even without a raw touch event. When a device sends both touch and mouse events, one gesture owns selection/placement, preventing duplicate actions. Canceled clicks do not commit, and mouse/touch can take over immediately after controller input. Godot mouse-from-touch is explicitly enabled, while mouse-to-touch remains disabled. Steamworks was rechecked with **Left Mouse Click Emulation** selected; no Steam configuration change was needed.

The additional pointer-dispatch regression uses `Input.parse_input_event` through Godot's full emulation pipeline. It covers native touch plus its generated mouse, mouse-only emulation, clicks without preceding motion, menus, board selection, seed placement/dragging, and controller handoff. The suite passes 30 assertions in each renderer, both headlessly and with a real GLES framebuffer. The previous source fails standalone emulated mouse selection, placement, and controller handoff. This fixes a reproducible application gap; the exact input events produced by the owner's Deck have not been captured, so a physical retest remains necessary.

Version **0.3.4** adds bold 3×3 Sudoku separators, a stronger selected-square outline, and matching-number highlights for both printed clues and planted towers. Number 9 uses soft orchid instead of an error-like red. Completed number families turn gray and reset on every fresh puzzle. Touch or mouse taps select an empty square without planting; tapping a number commits it, and dragging a number previews its destination before release. The battle-speed control now cycles **1× → 2× → 4× → 1×**, while the solve countdown runs at normal speed. Tower cooldowns preserve elapsed overshoot so higher speed does not reduce rapid-fire damage. These changes apply to the native 3D board and the browser's compatible CanvasItem board.

The touch regression suite sends mouse and physical-touch events through the actual main scene in both render modes. It covers tap selection and placement, drag/drop, invalid targets, multitouch ownership, overlay isolation, controller takeover, responsive coordinates, matching-digit selection, and battle versus solve timing at 4×. This exercises input routing without claiming a physical touchscreen hardware test.

The workshop identifies towers with persistent number badges, previews the selected family's planted towers on the main board and mini-grid, and states the affected tower count beside the upgrade cost. Fixed Sudoku clues are excluded from that preview. Gear, Chests, and Camp have procedural voxel icons while retaining labels, counts, and controller focus.

Sudoku generation validates each complete solution and every returned puzzle, including uniqueness. A separate audit uses an independent backtracking solver and direct row/column/box checks across 264 seeded puzzles, including campaign-round seeds and all difficulties. Save loading rejects invalid Sudoku solutions or clues before changing the active run. Solve-phase placements must satisfy both the solution and current board rules; intentionally illegal emergency placements remain a battle mechanic. The audit did not reproduce an invalid fresh board in the earlier generator, so these guards are not presented as a confirmed diagnosis of the reported duplicate.

The port is developed on `godot-deck-edition`, based on the pre-Unity `gridfall-voxel-prototype` source. The original web build and Unity main branch remain available.

Build validation includes the simulation suite, actual main-scene UI flow tests, and exported Linux startup reaching `SUDOKU_DEFENSE_READY`. The automated campaign bot clears fifty medium rounds with earned gear/family upgrades; that is a progression sanity check, not human balancing evidence. Physical Steam Deck input/performance and Windows execution still need device testing. Do not market the game as Deck Verified based on these checks.

The published Godot Site serves this same Web export and a desktop download hub. Large engine and ZIP files are transported in 10 MiB parts; the original bytes are reconstructed, and desktop ZIPs are SHA256 checked before saving. This accommodates static host file limits without changing game behavior.

At the owner's request, native Linux **0.3.8**, build **26177165**, depot manifest **7518046249804221579**, was activated on the unreleased app's **default** branch on October 24, 2026 (America/New_York) for Steam Deck menu and item-drag UI testing. It matches source commit `79217f822f36bc6134de14553c554c4a66d8181b`. Steam's uploaded binary size and SHA-1 match the locally tested staging binary, whose startup confirms version 0.3.8. The existing `sudoku-defense` Linux 64-bit launch, Generic Gamepad template, and touchscreen Left Mouse Click Emulation were preserved. Physical Deck validation remains required before a public release or compatibility claim. A Windows executable for separate Proton testing is also available from the same source. An app name or successful export alone does not validate Steam launch configuration.
