# Sudoku Defense: Steam release target

## Current Steam testing build — Godot 0.3.7

On **October 24, 2026 (America/New_York)**, native **Godot 0.3.7** was uploaded to the existing Linux depot and build **26176881** was activated on **default** for the owner's docked Steam Deck and Xbox-controller testing. It adds a free cursor controlled by the right stick, right-stick-click (R3) selection, right-trigger hold/drag, left-trigger precision movement, and safe handoff between pointer and focus navigation. The app remains an unreleased testing app; this activation did not submit a Valve review or release the game publicly.

| Item | Value |
| --- | --- |
| Steam app | Sudoku Defense — **3721150** |
| Existing Linux depot | **3721151** |
| Developer Comp package | **1309911**; previously confirmed to include this app and depot |
| Beta-testing package | **1309912** |
| Store package | **1309913** |
| Uploaded version | **0.3.7** |
| Source branch | `godot-deck-edition` |
| Gameplay GitHub source commit | `1363fc3aac33b845e0a207c97875522fa22e7716` |
| Source tree | `48a7438a2dd78226bce0298ce23d366935e8ab61` |
| Steam BuildID | **26176881** |
| Depot manifest | **6349129508851656728** |
| Active branch | **default** |
| Release state | **Unavailable (unreleased)** |
| Upload mode | Standard replacement |
| Uploaded ZIP | `Sudoku-Defense-Godot-Steam-Linux-0.3.7.zip` |
| ZIP bytes | **28,867,678** |
| ZIP SHA-256 | `edce2fd3a12c042a396ddb1b396140d9ff1fd94a15624fa8e794ff45ca5457b6` |

The uploaded manifest lists exactly three files: `sudoku-defense`, `GODOT-LICENSE.txt`, and `GODOT-THIRD-PARTY.txt`. Steam reports the binary as **74,101,352 bytes**, SHA-1 `d8e2dce639d0344612f5a8407ca57ee5e1905952`; both match the local staging binary. Its SHA-256 is `41c5c7ee23f6285552e37d66d0d3ffd23aaf2ef7419b5c3e4edf6b5100158509`. Steam's activation preview reports a **558.7 KB** update from the previous default build. The local ZIP records mode **0755** for the executable. Steamworks' manifest table displays an empty Flags cell, so that view alone does not verify the installed executable permission. Confirm the installed file and actual launch on the Deck before marking this test complete.

The previous Godot **0.3.6** build **26174861**, manifest **2872677615394352674**, remains in build history as the rollback candidate. Its source commit was `ee33012963a0fc5a549a85b746056d77787beddf` and ZIP SHA-256 was `491a6e0b87198dafbf30e8bb478f4aaacac09b6e6ac2f34e64d29ff50f08f2b6`. No launch or controller settings changed for 0.3.7. The existing native Linux 64-bit launch, Generic Gamepad template, and **Left Mouse Click Emulation** touchscreen mode were preserved.

Package 1309913 is an entitlement, not an upload destination. Do not create a new app for this update. A Windows export exists separately, but no Windows depot is documented or assumed here; do not put a Windows executable into the Linux-only depot.

## Prepare the native Linux depot

Build the actual Godot releases and run the checks described in [GODOT-BUILDS.md](GODOT-BUILDS.md), then run from the repository root:

```sh
python3 steam/prepare_godot_linux.py --source-commit 1363fc3aac33b845e0a207c97875522fa22e7716
```

For future releases, omit `--source-commit` when local HEAD is the canonical source commit, or supply the exact corresponding GitHub commit. Do not reuse this example SHA for new gameplay code.

The helper:

1. Validates the exported Linux x86-64 ELF and required license notices.
2. Copies the binary byte-for-byte from `godot/build/linux/sudoku-defense.x86_64` to `release/steam-godot-linux/sudoku-defense`, preserving the Steam launch filename used by the existing app.
3. Boots the renamed executable headlessly and requires `SUDOKU_DEFENSE_READY` with no script errors.
4. Creates `release/Sudoku-Defense-Godot-Steam-Linux-<version>.zip` with three files directly at its root: `sudoku-defense` (mode 0755), `GODOT-LICENSE.txt`, and `GODOT-THIRD-PARTY.txt`.
5. Verifies ZIP CRC and executable permissions, then writes SHA-256 hashes, source provenance, and pending-upload status to `release/steam-godot-linux-manifest.json`.

Use this ZIP for a Steamworks **Standard replacement** upload to depot 3721151. Replacing the depot contents removes obsolete Electron libraries and `resources/app.asar`; those files are not needed by Godot. The ZIP is deliberately not nested under an extra directory. The normal desktop download keeps the filename `sudoku-defense.x86_64`; only the Steam staging copy uses `sudoku-defense`.

Keep binaries, Steam SDK files, credentials, login sessions, logs, and chunk caches out of Git. `release/` is ignored. The manifest and boot log are local packaging evidence, not depot content.

## SteamPipe configuration

- `steam/app_build_3721150.vdf` points to the prepared `release/steam-godot-linux/` directory.
- `steam/depot_build_3721151.vdf` maps its contents recursively to the existing depot root.
- `SetLive` is empty: an upload does not activate a branch automatically.
- `Preview` is `0` for upload; use a temporary local copy with `Preview` set to `1` for a file-mapping dry run.

Use the Steamworks SDK's SteamCMD with an authorized build account. Authenticate interactively or with its supported cached session; never put a password or Steam Guard code in Git. At the SteamCMD prompt:

```text
run_app_build /absolute/path/to/Sudoku-Defense-beta/steam/app_build_3721150.vdf
```

After uploading, inspect [app 3721150's builds](https://partner.steamgames.com/apps/builds/3721150), activate the intended testing branch, and record the actual BuildID, depot manifest, branch, source commit, and archive checksum together. Do not fill those fields with a local archive ID or a guessed value. Configuration semantics follow Valve's [SteamPipe documentation](https://partner.steamgames.com/doc/sdk/uploading).

## Linux launch configuration

| Steamworks field | Value for the staged Godot build |
| --- | --- |
| Executable | `sudoku-defense` |
| Operating system | Linux |
| Architecture | 64-bit |
| Arguments | Empty |
| Working directory | Empty (installation root) |
| Installation folder | `Sudoku Defense` |
| Steam Input starting template | Generic Gamepad (`templateindex` 4), published October 23, 2026 |
| Touchscreen behavior | Left Mouse Click Emulation (`1`), preserved |

Retaining the existing launch filename avoids changing a shared launch option that older branches also use. The `sudoku-defense` Linux 64-bit launch option was verified in Steamworks on October 23, 2026. Recheck the other fields before future configuration changes. Launch the native Linux build without a forced Proton override. Preserve the executable bit, and ensure depot 3721151 remains included in the owner's testing entitlement.

The staged executable is the same Godot binary as the tested download; renaming does not wrap it in a shell or browser. Native controller routing includes menus, number selection, tower placement/upgrades, inventory targeting, chest use, seed entry, and disconnect pause. The Steam Input default was changed from None Selected to **Generic Gamepad** and published successfully on October 23, 2026; touchscreen Left Mouse Click Emulation was preserved. Steamworks returned `Publish to steam OK` and `Publishing successful!`. Physical controller behavior still needs the installed-device pass below.

## Validation and saves

The 0.3.7 source build passes all required headless and actual GLES suites in the native and Canvas board renderers. The new controller-cursor suite passes **134 assertions per renderer**, covering cursor movement, click/drag, precision control, input ownership, and focus-safe handoff. Linux export startup and the renamed Steam staging executable reach the ready marker; ZIP CRC and executable permissions were verified before upload. These checks do not establish a successful Steam client installation or physical docked Deck/Xbox-controller behavior.

Test the Steam-installed candidate for cold start offline, audio, solving, placement, upgrades, inventory, purchases, menus, save/resume, controller-only navigation, and Deck suspend/resume. Godot stores its run in `user://sudoku-defense-run.json`; saves from the older Electron/Gridfall version are not migrated into the Godot port. Existing legacy save files are not removed by this packaging step.

Achievements, Steam Cloud, native Steam Input API glyphs, and Steamworks API integration are not implemented. No public release, Valve review submission, or Deck verification is implied by a testing upload. Keep the store checklist and compatibility claims consistent with actual validation.

## Previously confirmed Steam baseline

The owner's Steamworks session on October 21, 2026 confirmed the following **older Electron build**, now superseded on default by the Godot build above:

| Item | Historical value |
| --- | --- |
| Build on default branch | **26122487** |
| Depot manifest | **7230280511147299521** |
| Game version | **0.2.7** |
| Source branch | `gridfall-voxel-prototype` |
| Source commit | `a6ba368b09dff0236b7cc70aeac280c07281b44f` |
| Source CI run | [39249279780](https://github.com/yannage/Sudoku-Defense-beta/actions/runs/39249279780) |
| ZIP SHA-256 | `0ed3e96daf3f6333f6c58f935bf00e6baeda9ada83d5d0a7d9b61c20c0172917` |

That upload contained 72 Electron depot files. The app configuration was published then, and the developer package's release override was enabled. These are historical observations; current state must come from Steamworks.

The English store description and developer/publisher information had been saved. The trailer entry still required uploading `Sudoku-Defense-Steam-Trailer.mp4`; no Valve review or public release was submitted during that migration. See Valve's [release process](https://partner.steamgames.com/doc/store/releasing) and [Deck compatibility requirements](https://partner.steamgames.com/doc/steamhardware/compat).
