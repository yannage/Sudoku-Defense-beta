# 0.3.19 Steam saves and achievements

Based on live 0.3.18 source `699c4a04b7c56fd728592e1e957ba0d8741c5482`,
Steam app 3721150 / default build 26354046. This candidate does not activate
itself or release the game for sale.

## Player changes

- Steam-launched native builds use the current account's save folder. Valid
  earlier local progress migrates once, with its original files retained.
  Auto-Cloud synchronizes only the run and permanent achievement journal,
  committed pending files and last-good backups. Preferences stay local.
- Saves protect against future formats, interrupted writes, unexpected external
  changes and divergent cloud journals. Saves & Steam offers explicit run
  recovery; recovery archives every original before using the chosen run.
- Twenty-six achievements cover learning, tower and module choices, Sudoku
  accomplishments and the 50-round campaign. Practice is excluded; notes,
  accessibility options and battle speeds never disqualify a run.
- Unlock evidence persists before Steam submission. Failed or unavailable
  Steam submissions remain queued; duplicate callbacks and account changes
  cannot clear another account's queue. Conflicting achievement evidence can
  be explicitly combined after archiving the originals.
- Achievements and Saves & Steam are available from the starting and pause
  menus, with controller focus, scrolling and Back navigation.

See [all unlock rules and research](ACHIEVEMENTS-0.3.19.md),
[save schema and path rules](STEAM-CLOUD.md),
[pinned Steam dependency](STEAM-INTEGRATION.md), and
[package validation](STEAM-PACKAGING-0.3.19.md).

## Acceptance still required on Steam and two physical devices

Automated tests use isolated profiles and mocked Steam APIs. They never award
test achievements to a real account. Native extension loading and exported
startup are separate from a working authenticated Steam session.

1. On the tested candidate launched normally from Steam, confirm account saves
   migrate, Continue resumes correctly, and no device settings changed.
2. Quit and wait for Steam's Up to date status. Launch the same Steam account
   on the other Windows/Linux/Deck device and compare seed, round, phase,
   gear, health, inventory and achievement progress. Repeat in the other
   direction. Preserve a manual backup for this acceptance run.
3. Play offline and earn an ordinary achievement naturally. Reconnect and
   verify it appears once in Steam, without replay or a duplicate award.
4. With disposable acceptance profiles, exercise divergent device progress,
   interrupted writes and explicit conflict recovery. Never substitute a
   test fixture for production saves or unlock achievements just to test APIs.
5. On Deck, check the 26-icon list, text, scrolling, A/B navigation, quick
   module flow and 8x controls. Test controller reconnect and suspend/resume.

Dynamic suspend/resume Cloud sync stays disabled. Normal launch/exit sync
requires closing the game before changing devices. Physical Deck behavior,
audible mix, actual Steam overlay/unlocks and two-device Cloud synchronization
cannot be established by headless or software-rendered QA.
