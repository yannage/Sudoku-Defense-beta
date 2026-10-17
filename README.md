# Gridfall — Sudoku Siege

A Sudoku tower-defense roguelite alpha by Yak Studios. Solve a traditional grid, grow numbered seeds into voxel towers, fit them with loot, and defend an enemy route shaped by your recent answers.

[Play Gridfall](https://gridfall.yakstudios.chatgpt.site) · [Player guide](docs/ROGUELITE-GUIDE.md)

Version **0.2.1** gives the board more room with a compact layout that fits the viewport, keeps all nine number buttons visible, and moves secondary controls into a collapsible quick bar. Tower, Bag, Chests, Notes, and More share one panel; opening it pauses the game clock. The inventory also has a compact item list and focused item details for smaller screens.

The game includes independent Sudoku and combat difficulties, a 50-round campaign, tower and number-family upgrades, five-slot equipment stacks, fragment-powered chests, consumables, passive upgrades, and a credit-only slot machine. The rendering foundation is stylized 2.5D Canvas. This is an evolving game framework and playable alpha; campaign balance has not undergone a full human playtest.

## Play

Choose **Free play** for one round, **Campaign** for 50 rounds with a fresh difficulty choice each round, or **Locked in** for 50 rounds with fixed difficulties. Set Sudoku and combat to Easy, Medium, or Hard independently.

1. **Solve:** correct answers plant towers, earn credits, and shape the route.
2. **War prep:** click a tower to upgrade it or all towers of its number. Equip up to five attachments per tower, buy reserve seeds, and open chests using fragments.
3. **Defend:** fight for drops and fragments. Emergency placements may break Sudoku rules, but raise corruption and expire after battle. Use consumables when the wave gets dangerous.
4. **Loot:** open earned chests, manage equipment, buy passive upgrades, or spend credits at the slot machine before choosing the next board.

All numbered towers start with basic bolts. Attachments provide rapid fire, lightning, frost, explosions, poison, range, power, gravity, or nova effects. Repeated attachments stack. Number-family upgrades, items, resources, and passive purchases continue through the run; individual tower upgrades belong to the current board. Equipment returns to the inventory when a board ends.

Read the [player guide](docs/ROGUELITE-GUIDE.md) for progression, controls, and loot. Blackjack and poker are future additions; only slots are included in this alpha.

Use the bottom quick bar for **Tower / Bag / Chests / Notes / More**. Tap the active tab again, use the close button, or tap a blank board square to collapse it. Only one quick panel opens at a time; the board and number buttons remain the main play surface. Full inventory management opens from Bag, while Loot camp and the casino are under More.

## Develop

Node.js 22 or newer is needed. The web game has no runtime npm dependencies and its assets are local.

```bash
npm run dev
npm test
npm run build
```

Open `http://127.0.0.1:4173`. `dist/` contains the deployable web game and readable source; no bundler is required. The build command checks the static files, and tests exercise the simulation, items, input, and desktop boundaries.

`dist/engine/` contains rendering, visual effects, procedural audio, and gamepad systems. `dist/game/simulation.js` owns Sudoku, economy, progression, and combat; `dist/game/items.js` defines equipment, rarity, and slot outcomes. `dist/app.js` connects the game to the board UI. `dist/quick-ui.js` owns the collapsible quick bar, `dist/cockpit.css` defines the compact game layout, and `dist/rogue-ui.js` owns the inventory, loot, and run setup panels. Another game can reuse the engine modules, deployment, and desktop shell with its own simulation and UI.

## Web deployment

The playable preview is hosted with Sites. To deploy through Netlify, connect this repository and use `netlify.toml`: publish `dist`, build with `npm run build`. A Netlify account connection is still required; the config alone does not create hosting. The web build needs no desktop dependencies. GitHub Actions validates pushes and creates downloadable Linux artifacts.

## Linux and Steam Deck

```bash
npm ci
npm run desktop:dev
npm run desktop
npm run package:linux
```

Packaging produces `release/Gridfall-0.2.1-x64.AppImage` and `release/linux-unpacked/`. Run `release/linux-unpacked/gridfall` directly or add it as a non-Steam game. Make the AppImage executable with `chmod +x release/*.AppImage`. The GitHub Actions artifact also contains a depot tarball that preserves executable permissions.

The Linux application embeds Electron and plays the web game offline. It uses the browser Gamepad API; start Deck testing with Steam Input's standard Gamepad layout. **F11** toggles desktop fullscreen. The shell serves local assets only on `127.0.0.1`, isolates web content from Node, blocks external navigation, and retains local data under Electron's user-data directory. It does not upload player data.

Physical Steam Deck testing, performance tuning, full controller-only playthroughs, and Steamworks submission remain release work. This is not a Steam Deck compatibility certification. See the [Steam release checklist](docs/STEAM-RELEASE.md).

## Desktop dependencies

Electron **44.9.0** and electron-builder **26.17.0** remain pinned in `package.json` and `package-lock.json`. Keep the Electron runtime patched before a public desktop release.
