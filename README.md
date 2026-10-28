# Sudoku Defense

## Current Godot edition — 0.3.15

The maintained game on this branch is **`godot/`**, built with Godot 4.7.2 for
native Windows, Linux / Steam Deck, and browser play. Start with
[the Godot README](godot/README.md) and [build instructions](docs/GODOT-BUILDS.md).
[Play the Godot edition](https://sudoku-defense-godot.yakstudios.chatgpt.site).

Version 0.3.15 adds a controller placement loop: press A on an empty square to
focus the number tray, choose with D-pad / left stick or LB / RB, then press A
to place the number and return to the original square. B returns without
placing; rejected answers keep the tray open for another choice. Wave forecasts,
tower priorities, aligned health bars, voxel foundations, and remembered
preferences remain included. The existing Steam target remains
app **3721150**, shared depot **3721151**; consult [the release record](docs/STEAM-RELEASE.md)
for the actually activated build.

The following sections describe the retained **legacy web/Electron reference**.
Do not use its `dist/` or Electron packaging as the current native game source.

## Legacy web reference

A Sudoku tower-defense roguelite alpha by Yak Studios. Solve a traditional grid, grow numbered seeds into voxel towers, fit them with loot, and defend an enemy route shaped by your recent answers.

[Play Sudoku Defense](https://gridfall.yakstudios.chatgpt.site) · [Player guide](docs/ROGUELITE-GUIDE.md)

Version **0.2.7** introduces the **Sudoku Defense** name, a matching game wordmark, and renamed Linux packages. Existing progress and settings are preserved.

The loot camp is rewarding and easy to navigate. Voxel slot reels have clearer outcomes, lower-cost spins, and equipment to keep on a losing spin. The workshop now uses a miniature board to select towers, showing their positions and fitted equipment before you upgrade or attach gear.

The compact play layout fits the viewport and shows all nine number buttons. Bag opens the equipment tray in place of the number rail while keeping the board visible. Secondary controls live in the collapsible quick bar; open trays and menus pause the game clock. The full inventory remains available through Details.

The game includes independent Sudoku and combat difficulties, a 50-round campaign, tower and number-family upgrades, five-slot equipment stacks, fragment-powered chests, consumables, passive upgrades, and a credit-only slot machine. The rendering foundation is stylized 2.5D Canvas. This is an evolving game framework and playable alpha; campaign balance has not undergone a full human playtest.

## Play

Choose **Free play** for one round, **Campaign** for 50 rounds with a fresh difficulty choice each round, or **Locked in** for 50 rounds with fixed difficulties. Set Sudoku and combat to Easy, Medium, or Hard independently.

1. **Solve:** correct answers plant towers, earn credits, and shape the route.
2. **War prep:** click a tower to upgrade it or all towers of its number. Equip up to five attachments per tower, buy reserve seeds, and open chests using fragments.
3. **Defend:** fight for drops and fragments. Emergency placements may break Sudoku rules, but raise corruption and expire after battle. Use consumables when the wave gets dangerous.
4. **Loot:** open earned chests, manage equipment, buy passive upgrades, or spend credits at the slot machine before choosing the next board.

All numbered towers start with basic bolts. During combat, their heads turn toward their firing targets. Attachments provide rapid fire, lightning, frost, explosions, poison, range, power, gravity, or nova effects. Repeated attachments stack. Number-family upgrades, items, resources, and passive purchases continue through the run; individual tower upgrades belong to the current board. Equipment returns to the inventory when a board ends.

Read the [player guide](docs/ROGUELITE-GUIDE.md) for progression, controls, and loot. Blackjack and poker are future additions; only slots are included in this alpha.

Use the bottom quick bar for **Tower / Bag / Chests / Notes / More**. Bag or a planted tower opens the equipment tray. Mouse users can drag an equipment card; on touch, drag its dotted handle or tap the card and then a tower. Drag a fitted slot onto another tower or back to Bag; tap it to return it without dragging. Drop spare gear onto a specific filled slot to swap it, keeping the previous item. Close the tray with its × button or Bag to resume playing. Other quick panels also collapse when you tap a blank board square. Loot camp and the casino are under More.

## Develop

Node.js 22 or newer is needed. The web game has no runtime npm dependencies and its assets are local.

```bash
npm run dev
npm test
npm run build
```

Open `http://127.0.0.1:4173`. `dist/` contains the deployable web game and readable source; no bundler is required. The build command checks the static files, and tests exercise the simulation, items, input, and desktop boundaries.

`dist/engine/` contains rendering, visual effects, procedural audio, and gamepad systems. `dist/game/simulation.js` owns Sudoku, economy, progression, and combat; `dist/game/items.js` defines equipment, rarity, and slot outcomes. `dist/app.js` connects the game to the board UI. `dist/quick-ui.js` owns the collapsible quick bar, `dist/loadout-ui.js` and `dist/loadout-ui.css` provide the board equipment tray, and `dist/cockpit.css` defines the compact game layout. `dist/command-ui.css` adds the field-console presentation. `dist/rogue-ui.js` owns the full inventory, loot, and run setup panels. `dist/voxel-art.js` and `dist/voxel-art.css` provide shared voxel illustrations for those interfaces. Another game can reuse the engine modules, art helpers, deployment, and desktop shell with its own simulation and UI.

## Web deployment

The playable preview is hosted with Sites. To deploy through Netlify, connect this repository and use `netlify.toml`: publish `dist`, build with `npm run build`. A Netlify account connection is still required; the config alone does not create hosting. The web build needs no desktop dependencies. GitHub Actions validates pushes and creates downloadable Linux artifacts.

## Linux and Steam Deck

```bash
npm ci
npm run desktop:dev
npm run desktop
npm run package:linux
```

Packaging produces `release/Sudoku-Defense-0.2.7-x64.AppImage` and `release/linux-unpacked/`. Run `release/linux-unpacked/sudoku-defense` directly or add it as a non-Steam game. Make the AppImage executable with `chmod +x release/*.AppImage`. The GitHub Actions artifact also contains a depot tarball that preserves executable permissions.

The Linux application embeds Electron and plays the web game offline. It uses the browser Gamepad API; start Deck testing with Steam Input's standard Gamepad layout. **F11** toggles desktop fullscreen. The shell serves local assets only on `127.0.0.1`, isolates web content from Node, blocks external navigation, and retains local data in the legacy `Gridfall` or `gridfall` directory under Electron's app-data directory so existing desktop saves and settings continue to work. Web save keys also remain unchanged. It does not upload player data.

The primary Steam target is app **3721150**, Linux depot **3721151**, and store package **1309913**. Version 0.2.7 has been uploaded as build **26122487**; branch activation, review status, and release status are verified separately in Steamworks. Future web/Electron updates use the checked-in `steam/` scripts, which do not automatically activate a branch. Physical Steam Deck testing, performance tuning, full controller-only playthroughs, and release review remain required. See the [Steam release checklist](docs/STEAM-RELEASE.md).

## Desktop dependencies

Electron **44.9.0** and electron-builder **26.17.0** remain pinned in `package.json` and `package-lock.json`. Keep the Electron runtime patched before a public desktop release.
