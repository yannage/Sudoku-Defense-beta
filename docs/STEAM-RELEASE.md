# Sudoku Defense: Steam release target

## Current Steam testing build — Godot 0.3.14 tactics and placement

On **October 25, 2026 (America/New_York)**, build **26208702** was activated on
the main app's **default** branch for Windows and Linux. It adds exact upcoming
wave intel, First/Strongest/Nearest tower priorities, aligned enemy health bars,
number-to-tower voxel foundation assembly, and persistent player preferences.

| Item | Value |
| --- | --- |
| Main Steam app / shared depot | **3721150 / 3721151** |
| Active default BuildID | **26208702** |
| Depot manifest | **5771364799624707360** |
| Windows executable | `SudokuDefense.exe`, 109,991,904 bytes |
| Windows SHA-1 | `0e378b21736395855732df623feb1ce2cbe5f948` |
| Linux executable | `sudoku-defense`, 74,242,832 bytes |
| Linux SHA-1 | `ea5371dcb9c868dda477106c005eeb8809c80851` |
| Upload mode | Standard replacement of the complete four-file shared depot |
| Previous default / rollback | Build **26205570**, manifest **6626747563325911071** |

Both platform packages come from source commit
`c87e5b65f355286fde05c760fc50cef5501972e7`, workflow
[40264668345](https://github.com/yannage/Sudoku-Defense-beta/actions/runs/40264668345).
Exports/regression job **121384312185** and native Windows startup job
**121386702059** passed. All **35 headless suites** and **19 real GLES render
suites** passed. The tactical model includes 53,989 assertions; tactics UI
checks include 223 assertions per renderer across Deck, desktop, portrait,
and landscape layouts. Final captures were visually reviewed. Both exact
packaged executables report **0.3.14** at startup.

The combined archive is **67,555,558 bytes**, SHA-256
`9ea2a9f07352b391428c89e37b98a797a8e9f91738fe785c261de33c05651d5b`.
Steam's manifest contains exactly both executables and the two Godot license
notices. Every file size and SHA-1 matches the staging manifest. The branch
table and current-build row confirmed activation. Steam's preview reported a
**1.8 MB** update from the previous default build.

Existing launch paths and platform settings remain in use. The app remains
unreleased and available to eligible existing owners/testers; the separate
Playtest app was not changed. Automated checks do not replace a physical
Steam Deck/Windows controller, audio, performance, or Steam-client install pass.

## Previous Steam testing build — Godot 0.3.12 camera controls

On **October 25, 2026 (America/New_York)**, build **26205570** was activated on
the main app's **default** branch for Windows and Linux. It adds smooth 360°
board rotation with right-mouse dragging, Q/E, touch Camera mode, and L3/right
stick controller controls. Reset view eases back along the shortest arc. The
chosen angle persists through phase changes, and placement/navigation follow
the rotated board. Portrait controls and instructions fit without overlap.

| Item | Value |
| --- | --- |
| Main Steam app / shared depot | **3721150 / 3721151** |
| Active default BuildID | **26205570** |
| Depot manifest | **6626747563325911071** |
| Windows executable | `SudokuDefense.exe`, 109,951,272 bytes |
| Windows SHA-1 | `57637cf42d2a8639cfdc082a6027fb01b5cbc76d` |
| Linux executable | `sudoku-defense`, 74,202,200 bytes |
| Linux SHA-1 | `9c194ef7aca756c8a72670c7feefe08b886fdeb0` |
| Upload mode | Standard replacement of the complete four-file shared depot |
| Previous default / rollback | Build **26204484**, manifest **2564642636447194378** |

Both platform packages come from source commit
`56f0295d5184809f34018f163ebcdbd7f14208e9`, workflow
[40245799289](https://github.com/yannage/Sudoku-Defense-beta/actions/runs/40245799289).
Exports job **121326975628** and native Windows startup job **121328585588**
passed. The full regression/render pipeline passed without Godot errors:
camera checks include 1,252 headless assertions and 388 real GLES assertions
per renderer; transition suites passed 220 native and 166 Canvas checks.
Final Deck-size and portrait screenshots were visually reviewed for both
renderers. Both exact packaged executables report version **0.3.12** at startup.

The combined archive is **67,478,122 bytes**, SHA-256
`f3c0ad4ab8ee468c0363e7717c0f01f94c2308a9daa39a4f9ed755370bdab468`.
Steam's manifest contains exactly both executables and the two Godot license
notices, with all sizes and SHA-1 hashes matching the staging manifest. The
default branch table and current-build row confirmed activation. Steam's
preview reported a **1.7 MB** update from the previous default build.

Existing launch paths and platform settings remain in use. The app remains
unreleased and available to eligible existing owners/testers; the separate
Playtest app was not changed. Automated checks do not replace a physical
Steam Deck/Windows controller, audio, performance, or Steam-client install pass.

## Previous Steam testing build — Godot 0.3.11 for Windows and Linux

On **October 25, 2026 (America/New_York)**, build **26204484** was activated on
the main app's **default** branch. It adds native Windows x86-64 alongside the
existing Linux 0.3.11 executable, including the smooth board-camera transition.
Steam's branch table and current-build row confirmed the active build.
Windows/Linux launch and supported-platform configuration was published
successfully. The app remains unreleased; this build is available to existing
owners/testers whose packages permit access, not a public Steam launch.

| Item | Value |
| --- | --- |
| Main Steam app | **3721150** |
| Shared all-platform depot | **3721151** |
| Active default BuildID | **26204484** |
| Depot manifest | **2564642636447194378** |
| Windows executable | `SudokuDefense.exe`, 109,920,416 bytes |
| Linux executable | `sudoku-defense`, 74,171,344 bytes; unchanged |
| Upload mode | Merge With Baseline |
| Preserved Linux baseline | Build **26194379**, manifest **6413919482495814251** |
| Launch/platform configuration | Published; Windows64 `SudokuDefense.exe` and Linux64 `sudoku-defense` |
| Common supported platforms | OS list `windows,linux`; architecture `64` |

The final Windows package is the **exact native-Windows-CI-tested artifact**
from source commit `40e2d3b34490cd4a25e4360faa716239fb754798`, workflow
[40239124656](https://github.com/yannage/Sudoku-Defense-beta/actions/runs/40239124656),
Windows job **121308474297**. Startup passed with exit code 0, no Godot script
errors, and `SUDOKU_DEFENSE_READY version=0.3.11`. Its executable SHA-256 is
`c913a5d4bc8e8a2e4287bea842c5b106fe291beb483f197d6bd2b2832cf45a03`; SHA-1 is
`4a767919272ca236f2336a08db20a0e3dea640eb`. The ZIP is **38,513,069 bytes**, SHA-256
`9e4023940ef57f6a0fb131091f81de292508cedf3d60c383fece3219c2a3d59a`.

The Steam manifest contains exactly both executables and the two Godot license
notices. Its Windows SHA-1 and size match the CI artifact. Its Linux SHA-1 remains
`1b1f0c7e8b699013825d51ff4623c70fc054afc0`, matching the prior live build. Independent
package inspection validated the Windows PE format, all 135 embedded resource
checksums, and version 0.3.11. All 24 local headless regression suites passed;
all 45 compiled scripts match the CI artifact. The first local-only candidate,
build **26204388**, was superseded without activation when CI produced a different
generated scene binary. Native Windows CI establishes startup, not a complete
Steam client/controller/audio performance pass on the owner's PC.

## Windows addition and shared depot uploads

The Windows build uses the same Godot project and version as Linux. Export it
with `python3 godot/scripts/build_exports.py --targets windows --godot
/absolute/path/to/godot`. Its ZIP contains `SudokuDefense.exe` and the two Godot
license notices at the archive root. Use a Windows-only, 64-bit Steam launch
option pointing to `SudokuDefense.exe`; retain the Linux-only `sudoku-defense`
launch option.

On October 25, 2026, Steamworks inspection confirmed that existing depot
**3721151** is configured for **All platforms**. The Windows addition uses that
shared depot, rather than a separate Windows depot. The Linux baseline before
the addition was build **26194379**, manifest **6413919482495814251**, version
**0.3.11**. The current activation and source hashes are recorded above.

**For every future single-platform upload to this shared depot, choose Merge
With Baseline and select the current live build as the baseline.** A Standard
replacement using a Windows-only or Linux-only ZIP removes the other platform's
executable. Standard replacement is appropriate only for a complete archive
containing both `sudoku-defense` and `SudokuDefense.exe`, with their common
license notices. Verify both executables in the resulting Steam manifest before
activating the build, then verify the default branch points to it.

`steam/prepare_godot_linux.py` and `steam/app_build_3721150.vdf` still stage only
the Linux files. Their historical Standard-replacement instructions below
describe the former Linux-only contents; do not use those instructions to
replace the shared depot after Windows has been added. Use the Steamworks
Merge With Baseline flow for that single-platform ZIP, or stage both platforms
before using a full SteamPipe replacement upload.

## Historical Steam testing build — Godot 0.3.9

On **October 24, 2026 UTC**, native **Godot 0.3.9** was uploaded and activated on the main app's **default** branch for existing Steam testers. This version adds the seed planting/growth animation, clearer game copy, and the correct current-wave enemy count. The exact same native package is staged on the newly created separate Playtest's default branch. The main game remains unreleased, and the Playtest remains **Hidden / Not Playable / Limited**, with zero participants. No Valve review or public release was submitted.

| Item | Main game | Private Playtest |
| --- | --- | --- |
| App | 3721150 | 5500140 |
| Linux depot | 3721151 | 5500141 |
| Active default BuildID | **26177757** | **26177734** |
| Depot manifest | **339043110308378658** | **7723049983870519643** |
| Release state | Unavailable / unreleased | Not Playable / Hidden |
| Packages | Developer1309911; beta1309912; store1309913 | Developer1897424; signup1897425; Playtest1897426 |

Shared source provenance:

- Branch: `godot-deck-edition`
- Canonical/local source commit: `06f8a9e23e7b6b413559e1c3bee81407f27346c2`
- Source tree: `23103416e35d791e66e6ec9842e9eb38a1bf1a0e`
- ZIP: `release/Sudoku-Defense-Godot-Steam-Linux-0.3.9.zip`
- ZIP size: **28,919,736 bytes**
- ZIP SHA-256: `5129bc91961821df45d65b0b9e582934cd0ce4ce6d135b623deba050d432163a`
- Executable size: **74,155,592 bytes**
- Executable SHA-1: `02fd2f0c1613319e02f17e889af15e202c0f1a7e`
- Executable SHA-256: `43952c32b7b0cd23145d36e4dac3a0c8926d08e1898c07090b6d73e157ae7255`

Both Steam manifests were inspected and contain exactly `sudoku-defense`, `GODOT-LICENSE.txt` (1,149 bytes) and `GODOT-THIRD-PARTY.txt` (100,108 bytes). Steam's executable SHA-1 and size match the local package exactly. Total depot disk size is 74,256,849 bytes; compressed depot size is 26,985,920 bytes. The main activation preview reported a **610.4 KB** update from 0.3.8. The local ZIP preserves executable mode0755; Steam's empty Flags cell does not independently prove the installed permission. A new Steam-installed device pass is still needed.

The previous main build **26177165** / manifest **7518046249804221579** remains available for rollback. Both apps use the native Linux64 `sudoku-defense` launcher, Generic Gamepad template4, and Deck Left Mouse Click Emulation1. Main app icons and no-common-redistributables metadata were published; the Playtest's Linux launch/depot/platform/input/icons/dependency configuration was published. The Playtest developer package includes its new depot, but its own five-minute Steam play checklist remains outstanding.

The packaging agent verified all regression suites, seed-planting QA, ZIP CRC, execute permissions, exact binary match, and renamed-headless boot reporting `SUDOKU_DEFENSE_READY version=0.3.9`. These are build checks, not Steam Deck Verified certification or an end-to-end Steam client install test.

See [STEAM-STORE-SETUP.md](STEAM-STORE-SETUP.md) for the actual store/alpha readiness state and [STEAM-ASSET-UPLOAD.md](STEAM-ASSET-UPLOAD.md) for the remaining legacy drag-only media uploads.

## Previous Steam testing build — Godot 0.3.8

On **October 24, 2026 (America/New_York)**, native **Godot 0.3.8** was uploaded to the existing Linux depot and build **26177165** was activated on **default** for the owner's Steam Deck UI testing. It adds a voxel menu diorama, illustrated expedition choices, a compact pause menu, beveled management panels with icon tabs, and small voxel item-drag previews with socket markers. The app remains an unreleased testing app; this activation did not submit a Valve review or release the game publicly.

| Item | Value |
| --- | --- |
| Steam app | Sudoku Defense — **3721150** |
| Existing Linux depot | **3721151** |
| Developer Comp package | **1309911**; previously confirmed to include this app and depot |
| Beta-testing package | **1309912** |
| Store package | **1309913** |
| Uploaded version | **0.3.8** |
| Source branch | `godot-deck-edition` |
| Gameplay GitHub source commit | `79217f822f36bc6134de14553c554c4a66d8181b` |
| Source tree | `5654bc3a254f08b9b14569dca27bf8fd9a0017e6` |
| Steam BuildID | **26177165** |
| Depot manifest | **7518046249804221579** |
| Active branch | **default** |
| Release state | **Unavailable (unreleased)** |
| Upload mode | Standard replacement |
| Uploaded ZIP | `Sudoku-Defense-Godot-Steam-Linux-0.3.8.zip` |
| ZIP bytes | **28,894,468** |
| ZIP SHA-256 | `1c74bb432f64af32445488f00ecfc11ac7a80a4094cfdc790f4fd9c90737c0ba` |

The uploaded manifest lists exactly three files: `sudoku-defense`, `GODOT-LICENSE.txt`, and `GODOT-THIRD-PARTY.txt`. Steam reports the binary as **74,129,152 bytes**, SHA-1 `83081fb9ba99d78b6727c196c57a6783cc18d210`; both match the local staging binary. Its SHA-256 is `25f3e88f813c3b28f51c51252bda8fe2915660127c4f6b7db74f554738e61246`. Steam's activation preview reports a **585.1 KB** update from the previous default build. The local ZIP records mode **0755** for the executable. Steamworks' manifest table displays an empty Flags cell, so that view alone does not verify the installed executable permission. Confirm the installed file and actual launch on the Deck before marking this test complete.

The previous Godot **0.3.7** build **26176881**, manifest **6349129508851656728**, remains in build history as the rollback candidate. Its source commit was `1363fc3aac33b845e0a207c97875522fa22e7716` and ZIP SHA-256 was `edce2fd3a12c042a396ddb1b396140d9ff1fd94a15624fa8e794ff45ca5457b6`. No launch or controller settings changed for 0.3.8. The existing native Linux 64-bit launch, Generic Gamepad template, and **Left Mouse Click Emulation** touchscreen mode were preserved.

Package 1309913 is an entitlement, not an upload destination. Do not create a new app for this update. At this historical release, Windows exports were separate and no Windows Steam launch was configured. The former assumption that depot 3721151 was Linux-only is superseded by the October 25 inspection and shared-depot instructions above.

## Prepare the native Linux depot

Build the actual Godot releases and run the checks described in [GODOT-BUILDS.md](GODOT-BUILDS.md), then run from the repository root:

```sh
python3 steam/prepare_godot_linux.py --source-commit 06f8a9e23e7b6b413559e1c3bee81407f27346c2
```

For future releases, omit `--source-commit` when local HEAD is the canonical source commit, or supply the exact corresponding GitHub commit. Do not reuse this example SHA for new gameplay code.

The helper:

1. Validates the exported Linux x86-64 ELF and required license notices.
2. Copies the binary byte-for-byte from `godot/build/linux/sudoku-defense.x86_64` to `release/steam-godot-linux/sudoku-defense`, preserving the Steam launch filename used by the existing app.
3. Boots the renamed executable headlessly and requires `SUDOKU_DEFENSE_READY` with no script errors.
4. Creates `release/Sudoku-Defense-Godot-Steam-Linux-<version>.zip` with three files directly at its root: `sudoku-defense` (mode 0755), `GODOT-LICENSE.txt`, and `GODOT-THIRD-PARTY.txt`.
5. Verifies ZIP CRC and executable permissions, then writes SHA-256 hashes, source provenance, and pending-upload status to `release/steam-godot-linux-manifest.json`.

Use this Linux-only ZIP for a Steamworks **Merge With Baseline** upload to depot 3721151, selecting the current live build so `SudokuDefense.exe` remains present. A full Standard replacement requires both platform executables. The historical migration from Electron used replacement to remove obsolete libraries and `resources/app.asar`; Godot does not need those files. The ZIP is deliberately not nested under an extra directory. The normal desktop download keeps the filename `sudoku-defense.x86_64`; only the Steam staging copy uses `sudoku-defense`.

Keep binaries, Steam SDK files, credentials, login sessions, logs, and chunk caches out of Git. `release/` is ignored. The manifest and boot log are local packaging evidence, not depot content.

## SteamPipe configuration

- `steam/app_build_3721150.vdf` points to the prepared `release/steam-godot-linux/` directory. This is a Linux-only staging template, not a complete replacement for the shared depot. Add and verify the existing Windows executable before using it for a full upload; otherwise use Steamworks Merge With Baseline for the Linux ZIP.
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

## Validation and saves (0.3.8 historical detail; current checks above)

The 0.3.8 source build passes all required headless and actual GLES suites in the native and Canvas board renderers. Menu presentation checks pass **1,141 assertions per renderer run**, covering visible actions, content bounds, seed input, and pointer activation; controller-cursor checks pass **134 assertions** and controller flow passes **109**. Touch, pointer, and loot/gear regressions also pass. Release exports are written to unique temporary directories and checked before replacing prior outputs. The embedded Linux package contains version 0.3.8 and the new UI scripts, and its startup reports `SUDOKU_DEFENSE_READY version=0.3.8`; staging rejects a mismatched version. ZIP CRC and executable permissions were verified before upload. These checks do not establish a successful Steam client installation or physical docked Deck/Xbox-controller behavior.

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
