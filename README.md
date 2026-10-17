# Gridfall — Sudoku Siege

A playable Sudoku tower-defense prototype and a small reusable web-game foundation by Yak Studios. Solve a traditional grid, watch it rise into a voxel battlefield, and defend a route shaped by your recent placements. The renderer is a stylized 2.5D Canvas voxel foundation. This is an initial game framework, not a finished general-purpose editor, volumetric world engine, or a Steam-certified release.

## Play and develop

Node.js 22 or newer is needed for development. The web game has no runtime npm dependencies and its assets are local.

```bash
npm run dev
```

Open `http://127.0.0.1:4173`. The `dist/` directory is the deployable web game and its readable source; no bundler is required. `npm run build` checks the static build. `npm test` runs deterministic game, input, and desktop tests.

## The game loop

1. **Solve:** enter correct Sudoku numbers to create permanent towers and earn coins. Completing rows, columns, and boxes awards bonuses. Your newest placements reshape the next enemy route.
2. **Defend:** the flat board transforms into a battlefield. Buy reserve pieces, then place them in empty cells during the wave. Wrong Sudoku entries work as temporary emergency towers but add corruption that strengthens enemies. The current route stays fixed during a wave; new correct moves affect the next one.
3. **Regroup:** temporary illegal pieces clear between waves. Strengthen the board and survive the five-wave run.

| Number | Tower | Effect |
| --- | --- | --- |
| 1 | Pulse | Rapid single-target bolts |
| 2 | Frost | Slows enemies |
| 3 | Arc | Chain lightning |
| 4 | Mortar | Area explosions |
| 5 | Prism | Piercing beam |
| 6 | Venom | Damage over time |
| 7 | Beacon | Speeds up nearby towers |
| 8 | Gravity | Pulls enemies backward |
| 9 | Nova | Burst against all enemies in range |

See the game's Help panel for the current keyboard and gamepad mappings. The game uses the browser Gamepad API; choose Steam Input's standard Gamepad layout for initial Deck testing. The desktop shell uses **F11** to toggle fullscreen.

## Reuse the foundation

`dist/engine/` contains the reusable rendering, effects, procedural audio, and gamepad systems. `dist/game/simulation.js` owns Sudoku rules, economy, route generation, and combat independently of rendering. `dist/app.js` connects the game model to the UI. To build another game, replace the simulation and UI while retaining the engine modules, static deployment, and desktop shell. This separation makes the mechanics testable without a browser.

## Web deployment

Connect this GitHub repository in Netlify and use the included `netlify.toml`: publish directory `dist`, build command `npm run build`. The web build works without installing desktop development dependencies. GitHub Actions validates pushes and prepares downloadable Linux artifacts. Deployment needs an authorized Netlify account connection; a config file alone does not create a hosted site.

## Desktop and Steam Deck

```bash
npm ci
npm run desktop:dev
npm run desktop
npm run package:linux
```

Linux packaging produces `release/Gridfall-0.1.0-x86_64.AppImage` and `release/linux-unpacked/`. Run `release/linux-unpacked/gridfall` directly or add it as a non-Steam game. For an AppImage, mark it executable first with `chmod +x release/*.AppImage`. For Steam depots, distribute the unpacked directory with executable permissions intact; the CI artifact includes a tar archive for this purpose.

The Linux executable embeds Chromium/Electron and renders the same web game offline. It is a native Linux **application package**, not a separate native graphics renderer. It requires no Netlify connection or web browser installation to play. The shell binds its asset server only to `127.0.0.1`, isolates the renderer from Node, prevents external navigation, and preserves local settings across launches under Electron's user-data directory. It does not upload player data.

Packaging configuration and automated checks do not establish Steam Deck compatibility. Actual device testing, performance tuning, controller-only coverage, and Steamworks submission remain release work. Read [the Steam release checklist](docs/STEAM-RELEASE.md).

## Dependency pins

Desktop-only development dependencies are Electron **44.9.0** and electron-builder **26.17.0**, verified against [Electron's stable releases](https://releases.electronjs.org/release?channel=stable) and the [electron-builder official releases](https://github.com/electron-userland/electron-builder/releases) on October 17, 2026. `package-lock.json` pins transitive dependencies. Keep the Electron runtime patched before public desktop releases.
