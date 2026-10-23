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

For Steam, place the contents of the appropriate platform folder at that platform depot's root. Use `SudokuDefense.exe` for a Windows launch option and `sudoku-defense.x86_64` for a Linux launch option. Preserve executable permissions for Linux. Do not replace the live Steam depot until launch, controls, audio, save/resume, and performance have been tested on an actual Deck.

### Controller setup for this port

Godot's desktop exports use its native gamepad input; receiving the Deck's buttons and sticks does not require a browser wrapper or the Steam Input API. Godot has used SDL 3 for desktop controllers since 4.5. The web export uses a different controller backend, so a browser pass is not a substitute for testing the installed Deck build. See [Godot controller support](https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html).

When preparing the Steam release, select the built-in **Gamepad** template as the app's recommended Steam Input configuration and test it against the actual executable. This supplies ordinary gamepad events. Retire a mouse/keyboard configuration left over from the older web wrapper; avoid requiring the player to hold the Steam button to emulate a mouse. A custom Steam Input action manifest is not part of this build. This document does not change the account's published controller configuration. Valve describes the template choices in [Gamepad Emulation Best Practices](https://partner.steamgames.com/doc/features/steam_controller/steam_input_gamepad_emulation_bestpractices).

The required device pass is: launch from the Deck library; use D-pad/stick and A to select a mode/difficulty and start; plant numbers with LB/RB and A; inspect/upgrade a tower; select and equip gear; open a cache and use an item; visit camp; move to another round; pause/resume and resume a save. Test a controller disconnect/reconnect and Deck suspend/resume too. Confirm every menu can be exited with B and no open panel sends button presses through to the board. The default configuration must expose the entire game, as described by [Valve's Deck recommendations](https://partner.steamgames.com/doc/steamhardware/recommendations).

The controller regression suite injects joypad button/axis events through the actual scene for both board renderers. It checks the application's routing and focus behavior, not SDL hardware discovery or physical Deck mappings. Keep the native Deck pass as a release requirement before claiming Steam's Full Controller Support or Deck Verified status.

Headless import and executable boot checks detect packaging and script errors. They do not establish controller usability, graphics performance, Proton compatibility, or Steam Deck verification. Browser play is a convenient test surface; desktop and Deck testing remain separate release gates.

## Current source and verification

The port is developed on `godot-deck-edition`, based on the pre-Unity `gridfall-voxel-prototype` source. The original web build and Unity main branch remain available.

Build validation includes the simulation suite, actual main-scene UI flow tests, and exported Linux startup reaching `SUDOKU_DEFENSE_READY`. The automated campaign bot clears fifty medium rounds with earned gear/family upgrades; that is a progression sanity check, not human balancing evidence. Physical Steam Deck input/performance and Windows execution still need device testing. Do not market the game as Deck Verified based on these checks.

The published Godot Site serves this same Web export and a desktop download hub. Large engine and ZIP files are transported in 10 MiB parts; the original bytes are reconstructed, and desktop ZIPs are SHA256 checked before saving. This accommodates static host file limits without changing game behavior.

Do not replace Steam's current default branch until the target package has been installed and played on a physical Deck. A native Godot Linux executable and a Windows executable for Proton testing are both available from the same source. An app name or successful export alone does not validate Steam launch configuration.
