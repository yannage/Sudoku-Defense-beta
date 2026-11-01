# Steam runtime integration

The game retains the official Godot 4.7.2 engine and normal export templates.
Only native Windows/Linux x86-64 exports load the pinned GodotSteam GDExtension
4.23.2, built against Steamworks SDK 1.65. The complete addon is excluded from
Web exports. The upstream editor updater and unsupported platform binaries are
not included. The application can run without Steam and without the extension.

## Dependency provenance

The [maintainer's 4.23.2 GDExtension release](https://codeberg.org/godotsteam/godotsteam/releases/tag/v4.23.2-gde)
declares Godot 4.4+ compatibility and is not marked prerelease. Acquisition on
2026-11-01 used its HTTPS asset, 28,292,972 bytes, SHA-256
`0c935ac86bdb881a71009a0352140a043812c438745979e1b246416a9282e414`.
This is an independently recorded acquisition hash, not an author signature.
`godot/addons/godotsteam/dependency-lock.json` pins the archive and each selected
unmodified binary. The local `.gdextension` descriptor restricts the upstream
platform list to the two supported architectures.

Retain `license.md` for the MIT-licensed wrapper and `STEAMWORKS-NOTICE.txt` for
the separate Valve runtime attribution in desktop packages. The official asset
contains the wrapper's MIT license, not a standalone grant to redistribute all
Valve SDK materials. No SDK headers, credentials, partner tools or account data
are distributed. [Valve documents the required runtime files](https://partner.steamgames.com/doc/sdk/api).

## Safe initialization

`scripts/steam_platform.gd` is the sole production gateway. Project settings
must retain:

```ini
[steam]
initialization/app_data/app_id=0
initialization/processes/initialize_on_startup=false
initialization/processes/embed_callbacks=false
```

The wrapper initializes only an exported Windows/Linux executable launched
with Steam's app 3721150 environment. Editor, headless, scripts, smoke tests,
custom startup/profile arguments and `SUDOKU_DISABLE_STEAM=1` disable it. Only
existing graphics/window flags are allowed. Tests inject a fake gateway; the
real Steam singleton cannot be passed to bypass the gate. Loading the native
extension alone does not initialize Steam or award anything.

The adapter calls `steamInitEx(0, false)`, then verifies both the API's app ID
and nonzero Steam ID. It never invents a launch context, ships `steam_appid.txt`,
restarts through Steam, or changes account settings. Steam API initialization
failure leaves the local game usable. A Steam restart could launch the old
installed build, so it is deliberately omitted. Call `pump(delta)` each frame
and `shutdown()` on exit. Achievement calls and callbacks recheck identity;
an account change disables writes for that session. The account ID is a decimal
string to avoid precision loss in JSON.

## Achievement acknowledgement

Steamworks 1.65 loads stats before launch; its old `RequestCurrentStats` call is
deprecated. Each key is still checked with `GetAchievement` before attempting
an unlock, so missing/unpublished definitions fail without breaking gameplay.
Only `user_stats_stored` with the correct app and success result acknowledges
the in-flight batch. A successful `SetAchievement` or `StoreStats` return alone
does not do so. Already staged in-memory unlocks are reported as pending, not as
remote success. The durable profile keeps them queued through write failure.

Known failed stores and explicit failure callbacks back off for 60 seconds.
An unanswered store after 30 seconds pauses further achievement writes until
the next launch: Steam's callback lacks a request ID, so a late response must
not acknowledge a newer batch. Local earned progress remains available and the
durable queue retries safely on a future session. Duplicate success callbacks,
other-app responses and changed-account responses cannot acknowledge a batch.
No reset/clear-achievement API is exposed.

The adapter reports both account-level and app-level Cloud enabled flags. Save
selection, journals and Auto-Cloud migration are owned by the Cloud profile
layer; querying these flags does not upload or download a save. Current official
references: [Steam achievements](https://partner.steamgames.com/doc/features/achievements),
[ISteamUserStats](https://partner.steamgames.com/doc/api/ISteamUserStats), and
[Steam Cloud](https://partner.steamgames.com/doc/features/cloud).

## Verification boundary

`tests/test_steam_platform.gd` exercises the real native extension loader without
Steam initialization, then uses mocks for all API behavior. It checks launch
exclusions, identity changes, disabled Cloud, unknown keys, duplicate callbacks,
failed storage/backoff, timeouts and late callbacks. Isolated Windows testing
passed 90 assertions with no real-account API calls or awards. Actual client
unlock/overlay behavior and two-device Cloud synchronization require a supported
human acceptance run; automated mocks do not prove these outcomes.
