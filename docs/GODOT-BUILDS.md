# Sudoku Defense: Godot builds

The `godot/` project is the native Godot version. It uses Godot **4.7.2 stable**, GDScript, and the Compatibility renderer so the same game can export to Web, Windows, and Linux. It does not launch the previous web game inside a desktop wrapper.

## Local export

Install the official Godot 4.7.2 editor and matching export templates. Then run:

```sh
python3 godot/scripts/build_exports.py --godot /absolute/path/to/godot
```

Use `--targets web`, `--targets linux`, or `--targets windows` for a narrower build. Generated files stay under the ignored `godot/build/` directory. The helper imports resources, runs the simulation and UI-flow tests, fails on Godot script errors, exports the selected platforms, boots the Linux executable headlessly when selected, and creates packages plus SHA-256 checksums. Tests must print their success markers; the exported Linux game must print its ready marker after its board, run, and UI are initialized.

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

Every desktop folder and browser distribution includes `GODOT-LICENSE.txt` and `GODOT-THIRD-PARTY.txt`. The download page links both notices. The build fails if either required notice is missing from the project.

## GitHub builds and downloads

`.github/workflows/godot.yml` builds the project on changes to the `godot-defense` branch, on relevant pull requests, or by manual workflow dispatch. It downloads the official editor and templates and checks their published SHA-512 hashes before running them. Workflow artifacts contain Web, desktop, source, and validation logs.

Tags beginning with `godot-v` also create a GitHub release with the packages. Tag only a reviewed and tested commit; the workflow does not upload to Steam or change Steam's live build.

## Steam and Steam Deck

The Windows and Linux builds are separate deliverables from the same project. The Windows build is a candidate for testing through Proton. The Linux build runs natively and should use a Linux launch option without a forced Proton override.

For Steam, place the contents of the appropriate platform folder at that platform depot's root. Use `SudokuDefense.exe` for a Windows launch option and `sudoku-defense.x86_64` for a Linux launch option. Preserve executable permissions for Linux. Do not replace the live Steam depot until launch, controls, audio, save/resume, and performance have been tested on an actual Deck.

Headless import and executable boot checks detect packaging and script errors. They do not establish controller usability, graphics performance, Proton compatibility, or Steam Deck verification. Browser play is a convenient test surface; desktop and Deck testing remain separate release gates.

## Current source and verification

The port is developed on `godot-deck-edition`, based on the pre-Unity `gridfall-voxel-prototype` source. The original web build and Unity main branch remain available.

Build validation includes the simulation suite, actual main-scene UI flow tests, and exported Linux startup reaching `SUDOKU_DEFENSE_READY`. The automated campaign bot clears fifty medium rounds with earned gear/family upgrades; that is a progression sanity check, not human balancing evidence. Physical Steam Deck input/performance and Windows execution still need device testing. Do not market the game as Deck Verified based on these checks.

The published Godot Site serves this same Web export and a desktop download hub. Large engine and ZIP files are transported in 10 MiB parts; the original bytes are reconstructed, and desktop ZIPs are SHA256 checked before saving. This accommodates static host file limits without changing game behavior.

Do not replace Steam's current default branch until the target package has been installed and played on a physical Deck. A native Godot Linux executable and a Windows executable for Proton testing are both available from the same source. An app name or successful export alone does not validate Steam launch configuration.
