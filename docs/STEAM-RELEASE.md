# Sudoku Defense: Steam release target

Confirmed in the owner's Steamworks session on October 21, 2026 (America/New_York). The primary Steam build is this repository's offline web game wrapped in Electron for Linux x86-64. The Unity experiment is a separate prototype.

## Existing app and uploaded baseline

| Item | Verified value |
| --- | --- |
| Steam app | Sudoku Defense — **3721150** |
| Linux depot | **3721151** |
| Store package | **1309913** |
| Uploaded build | **26122487** |
| Depot manifest | **7230280511147299521** |
| Game version | **0.2.7** |
| Source branch | `gridfall-voxel-prototype` |
| Uploaded source commit | `a6ba368b09dff0236b7cc70aeac280c07281b44f` |
| Source CI run | [39249279780](https://github.com/yannage/Sudoku-Defense-beta/actions/runs/39249279780) |

The Linux ZIP was uploaded as a Standard replacement and committed in Steamworks. An upload record does not establish that a particular branch is active, that store/build review passed, or that the game has released. Check those states in the live dashboard.

Keep future updates on this same app and depot. Package 1309913 is a store entitlement, not an upload destination or depot ID. Do not create a new Steam app for routine updates.

The uploaded ZIP SHA-256 is `0ed3e96daf3f6333f6c58f935bf00e6baeda9ada83d5d0a7d9b61c20c0172917`. It contains 72 depot files directly at its root, including `sudoku-defense` and `resources/app.asar`; executable permissions were preserved and the archive passed CRC checks.

## Prepare each update

1. Work on `gridfall-voxel-prototype`, preserve save compatibility, and record the exact source commit.
2. Run `npm test` and `npm run build`; then package with `npm ci` and `npm run package:linux` on Linux.
3. Use the complete `release/linux-unpacked/` contents for Steam. The CI `Sudoku-Defense-linux-depot.tar.gz` preserves permissions. The AppImage is for direct testing.
4. Keep binaries, Steam SDK files, credentials, login sessions, logs, and chunk caches out of Git. The existing `release/` ignore covers build output.
5. Record the resulting Steam BuildID, depot manifest, source commit, and artifact checksum together after each successful upload.

The October 21 upload used the successful CI artifact for the uploaded source commit above. This documentation/configuration update does not modify its game code or version.

## SteamPipe configuration

The checked-in scripts are:

- `steam/app_build_3721150.vdf`: app, content root, output directory, and depot mapping.
- `steam/depot_build_3721151.vdf`: recursive mapping of the Linux build into the depot root.

Paths are relative to the app script, so the expected content directory is `release/linux-unpacked/` in this checkout. `SetLive` is empty: uploading does not automatically activate any branch. `Preview` is `0` for upload; use a temporary local copy with `Preview` set to `1` to inspect file mappings first.

Use the Steamworks SDK's SteamCMD with an authorized build account. Authenticate interactively or with the documented cached session; never put a password or Steam Guard code in Git. At the SteamCMD prompt, run:

```text
run_app_build /absolute/path/to/Sudoku-Defense-beta/steam/app_build_3721150.vdf
```

After upload, inspect [app 3721150's builds](https://partner.steamgames.com/apps/builds/3721150), choose a testing branch, and verify an installation before activating an update for its intended audience. Keep activation separate from upload.

Configuration semantics follow Valve's [SteamPipe documentation](https://partner.steamgames.com/doc/sdk/uploading).

## Linux launch configuration

| Steamworks field | Value for this build |
| --- | --- |
| Executable | `sudoku-defense` |
| Operating system | Linux |
| Architecture | 64-bit |
| Arguments | Empty |
| Working directory | Empty (installation root) |

Use the exact filename without a leading slash or `./`. The executable, Electron libraries, and `resources/` directory must share the same installed layout. Ensure depot 3721151 is included in the store and developer testing packages.

The shell starts fullscreen at 1280 × 800; F11 toggles fullscreen and `--windowed` is a development option. Launch this Linux build directly without forcing Proton. Retain executable permissions during packaging and verify the installed launch configuration on Linux.

## Validate before release

The app plays offline, serves its local assets only on 127.0.0.1, and keeps saves in the legacy `Gridfall` or `gridfall` app-data directory. Preserve that location and the established web save keys during updates.

Test an actual Steam installation for cold start with Wi-Fi disabled, audio, solving, tower placement, inventory/attachments, purchases, menus, fullscreen, closing/reopening, save retention, and suspend/resume. Test controller-only navigation and frame rate on physical Steam Deck hardware. Start Steam Input testing with its standard Gamepad template.

The initial package was validated against the CI artifact and inspected for its Linux executable, bundled app name/version, file contents, and permissions. This does not substitute for a successful Steam client install or physical Deck playthrough.

Achievements, Steam Cloud, native Steam Input API glyphs, and Steamworks overlay integration are not implemented. Do not advertise these features or a Deck compatibility rating without the corresponding work and verification.

Complete the store assets and content survey accurately, resolve the live store/build review checklist, and select a release date using the app's actual dashboard state. See Valve's [release process](https://partner.steamgames.com/doc/store/releasing) and [Deck compatibility requirements](https://partner.steamgames.com/doc/steamhardware/compat).
