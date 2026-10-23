# Sudoku Defense: Steam release target

## Current Steam testing build — Godot 0.3.4

On **October 23, 2026**, native **Godot 0.3.4** was uploaded to the existing Linux depot and build **26172969** was activated on **default** for the owner's Steam Deck testing. It updates the native Linux x86-64 game with clearer Sudoku grids and selection, touch tap/drag placement, matching-digit highlights, 4× battle speed, Sudoku validity guards, voxel tool icons, and family upgrade previews. The app remains an unreleased testing app; this build activation did not submit a Valve review or release the game publicly. The new build's Steam client installation and physical Deck play still require verification.

| Item | Value |
| --- | --- |
| Steam app | Sudoku Defense — **3721150** |
| Existing Linux depot | **3721151** |
| Developer Comp package | **1309911**; previously confirmed to include this app and depot |
| Beta-testing package | **1309912** |
| Store package | **1309913** |
| Uploaded version | **0.3.4** |
| Source branch | `godot-deck-edition` |
| Gameplay GitHub source commit | `c1e822dd4f7beabc238d1b4d98203d1a60d61b76` |
| Source tree | `aa2915e5dc1f582fd6cf73e8ba3007f53a4706a2` |
| Steam BuildID | **26172969** |
| Depot manifest | **4115335427358380818** |
| Active branch | **default** |
| Release state | **Unavailable (unreleased)** |
| Upload mode | Standard replacement |
| Uploaded ZIP | `Sudoku-Defense-Godot-Steam-Linux-0.3.4.zip` |
| ZIP bytes | **28,777,525** |
| ZIP SHA-256 | `8caaed9436cb19b42e17c43f93d04265f0ce0dd2f2dc62eee5501a202c6406b1` |

The uploaded manifest lists exactly three files: `sudoku-defense`, `GODOT-LICENSE.txt`, and `GODOT-THIRD-PARTY.txt`. Steam reports the binary as **74,008,280 bytes**, SHA-1 `d14b931f99282f6f12c1b3f53c3eb6d70282db26`; both match the local staging binary. Its SHA-256 is `21dd7911011f25bd943b2c257586fcb6564e454d19f2c80829bec50a01d8b516`. Steam's activation preview reports a **466.6 KB** update from the previous default build. The local ZIP records mode **0755** for the executable. Steamworks' manifest table displays an empty Flags cell, so that view alone does not verify the installed executable permission. Confirm the installed file and actual launch on the Deck before marking this test complete.

The previous Godot **0.3.3** build **26168101**, manifest **6934024902345045506**, remains in build history as the rollback candidate. Its source commit was `a9f84f561ef3fd6466e055335dbd2592b5fb77ee` and ZIP SHA-256 was `7b13f3d59420ee35ec0e3301cb1ba67eccdd02cba3e318a90f0f520af14438c4`. No launch or controller settings changed for 0.3.4; the existing native launch and Generic Gamepad template were checked before upload.

Package 1309913 is an entitlement, not an upload destination. Do not create a new app for this update. A Windows export exists separately, but no Windows depot is documented or assumed here; do not put a Windows executable into the Linux-only depot.

## Prepare the native Linux depot

Build the actual Godot releases and run the checks described in [GODOT-BUILDS.md](GODOT-BUILDS.md), then run from the repository root:

```sh
python3 steam/prepare_godot_linux.py --source-commit c1e822dd4f7beabc238d1b4d98203d1a60d61b76
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

The 0.3.4 source build passes **1,338 simulation checks** and **1,640 Sudoku audit checks across 264 puzzles**, plus the UI flow, controller, touch/drag, and family-upgrade suites in both board renderers. Real GLES rendering and native executable startup checks passed; the renamed Steam executable reaches its ready marker. These checks do not establish a successful Steam client installation or physical Deck hardware behavior.

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
