# Steam Cloud save design

This describes the 0.3.19 candidate. Source changes and synthetic tests do not
establish that Steamworks settings were published or that two real devices
synchronized. The delivery receipt must state those separately.

## Files and paths

The configured mechanism is **Steam Auto-Cloud**, with exact file rules from
[`steam/cloud-config-0.3.19.json`](../steam/cloud-config-0.3.19.json). Windows uses
`WinAppDataRoaming`; native Linux/SteamOS uses the `LinuxXdgDataHome` root override.
Every rule is Cross-Platform and non-recursive. The SteamID path variable is
`{64BitSteamID}`. These settings follow Valve's documented account-specific paths
and root-override mechanism. Dynamic Cloud Sync remains disabled.

| Platform | Existing local data directory |
| --- | --- |
| Windows | `%APPDATA%/Godot/app_userdata/Sudoku Defense` |
| Native Linux / Steam Deck | `$XDG_DATA_HOME/godot/app_userdata/Sudoku Defense`, normally `~/.local/share/godot/app_userdata/Sudoku Defense` |
| Browser | Godot's browser-local IndexedDB; no Steam Cloud |

Inside the desktop directory, the current verified Steam identity uses
`steam/<SteamID64>/cloud/`. Only `run.json`, `achievements.json`, and each file's
`.pending` and `.bak` variants are synchronized. They contain portable game state
and earned achievement keys, without device paths, credentials, or settings.

Sound, presentation, accessibility choices, the migration claim, temporary writes,
conflict archives, logs, and caches stay local. Tutorial practice has no persistent
run or achievement writes. The run and profile journals each cap files at 8 MiB;
a 64 MiB quota and 32-file allowance cover all six committed files with headroom.

## Migration and account boundaries

`cloud_profile.gd` receives the identity verified by the Steam adapter. With no
identity it returns the original local run and local achievement paths, rather
than guessing the last Steam account. Steam offline mode can still supply its
current account identity; absence of a working Steam identity stays local.

When an account has no existing scoped save, the helper validates and copies its
legacy run and eligible local achievement profile. Original files are preserved
byte-for-byte. Existing scoped files take precedence and are never replaced by
an older legacy file. Achievement confirmations are cleared on migration so the
current account must acknowledge them again.

After each verified copy commits, an unsynchronized device-local claim records
which account received that legacy file. Another Steam account cannot import the
same legacy progress. If interruption occurs between copy and claim, the next
launch finishes the claim from the verified copy's migration evidence. An I/O
failure blocks startup of that profile with a visible error; it does not delete
either original or copy.

Returning to 0.3.18 leaves the new scoped files intact, but that older executable
reads the untouched legacy save from before migration. Returning to 0.3.19 reads
the scoped progress again. Do not copy cloud files over legacy files as an
automatic rollback step.

## Interrupted writes and conflicting progress

The shared `journal_store.gd` verifies a staged file before publishing `.pending`;
that publication remains the commit point. A last-good `.bak` survives ordinary
replacement. Staging is in `steam/<id>/local/staging/<kind>`, outside Cloud rules.

Each new snapshot records the SHA-256 of its prior committed snapshot. A pending
journal must match the current primary or name it as its parent. If the primary
is unreadable as JSON or missing, the same relationship is checked against a
valid backup. A stale journal therefore cannot silently replace a newer primary
or backup. Legacy files without metadata retain their pre-Cloud recovery order.

Files changed after loading block a stale in-memory autosave or New Run. A
future-version, oversized, or inaccessible committed file blocks loading,
writing, and recovery that could discard unknown progress. Ordinary malformed
JSON can still recover through the known-good journal or backup.

The player chooses a run explicitly in **Saves & Steam**. Recovery first copies
every original primary/journal/backup byte into the unsynchronized local
`conflicts` folder and verifies the copies. It then checks that the choices have
not changed before publishing the selected run. Achievement recovery uses the
same archive and replacement mechanism, with the profile manager's same-account,
monotonic-union validation. Timestamps are for presentation, not conflict winners.

## Acceptance still requiring Steam and two devices

1. Check Steamworks rule previews against a synthetic verified-account save on
   Windows and native Linux; verify the exact six names and no settings/temp files.
2. Start from a backed-up existing run, migrate once, quit normally, and wait for
   Steam's sync completion. On a second device, launch and compare seed, round,
   phase, inventory, RNG continuation, and earned achievement keys.
3. Play offline on each device, reconnect, and exercise Steam's conflict choice.
   Confirm that no unchosen variant is silently discarded by the game's journal.
4. Test Steam Cloud disabled, unavailable Steam, account switching, crash/restart,
   future-version files, and save-write failure. Test a real Deck suspend/resume;
   Dynamic Cloud Sync remains off, so quit before continuing on another device.
5. Validate forced Proton separately if supported; the native Linux path tests do
   not prove Proton's Windows-path mapping.

Automated coverage: `test_cloud_profile.gd` uses synthetic profiles only and tests
migration, account boundaries, interrupted claims, parent relationships, external
changes, archived explicit resolution, future schemas, oversized files and
injected inaccessible files. `test_run_save.gd` retains journal interruption,
last-good recovery, deterministic battle resume and visible failure/retry checks.

References: [Valve Steam Cloud](https://partner.steamgames.com/doc/features/cloud)
and [Godot user data paths](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html).
