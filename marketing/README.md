# Sudoku Defense — Steam media

The current Steam kit uses **the native Godot game**, with its real interface,
voxel board, module drag, enemies, projectiles and chest animation. It replaces
the older web-engine sizzle. Do not upload the legacy `render-trailer.mjs`
output as footage of the Godot edition.

## Deliverables

All generated media goes in ignored `release/marketing/`. Keep the reproducible
capture/edit sources in Git; upload the finished files to Steam and durable
artifact storage.

| Asset | File | Format |
| --- | --- | --- |
| Steam trailer | `sudoku-defense-steam-trailer.mp4` | 32 seconds, 1920×1080, 30fps, H.264 CBR8Mbps target, BT.709, AAC stereo 48kHz |
| Solve/transform loop | `01-solve-loop.mp4` / `.gif` | 9 seconds |
| Module-drag loop | `02-build-loop.mp4` / `.gif` | 6 seconds |
| Combat/chest loop | `03-defend-loot-loop.mp4` / `.gif` | 9 seconds |
| Trailer thumbnail | `trailer-poster.jpg` | Actual gameplay frame |
| Store screenshots | `01-solve-the-grid.png` through `08-combat-effects.png` | Actual 1920×1080 game captures |
| Capsule/library art | `capsules/` | Separate game-native artwork and title composition |

Embedded page MP4s are silent 1170px-wide H.264 BT.709, each below the 12-second
limit. GIF alternatives are 780px-wide at 12fps with a 112-color optimized palette.
Use the MP4 versions when supported for clearer motion at a smaller file size.
Screenshots and embedded loops contain no added marketing copy. The solve
and gear loops crop toward the board and inventory for legibility inside the
Steam description; screenshots remain full-frame.

## Trailer edit

| Time | Actual gameplay beat | Caption |
| --- | --- | --- |
|0–3s|Native combat immediately|Sudoku meets tower defense.|
|3–9s|Correct Sudoku placements|Every answer is a tower.|
|9–11s|Board becomes a voxel battlefield|Solve first. Fight next.|
|11–16s|Drag earned modules onto a tower|Build the tower you need.|
|16–24s|Enemies follow the route and towers fight|Your moves shape the battlefield.|
|24–28s|Open a legendary chest and show all rewards|Open chests. Keep building.|
|28–32s|Game-native voxel art and logo|Solve first. Fight next. / Coming to Steam|

Captions cover only the lower input strip in the trailer. They are editorial
overlays, not part of the game. There is no announced launch date, price,
Steam Deck Verified claim, or unimplemented feature claim.

## Capture provenance

`godot/tests/capture_store_gameplay.gd` loads the shipping native scene. A seeded
automated player completes nine campaign rounds through public game actions,
solves the next board, equips earned items, buys upgrades, clears the wave and
opens a chest purchased with earned credits. It does not invent loot, enemies,
stats or damage. Actions are staged and the final trailer rearranges these
real clips. `capture-manifest.json` records the engine/build, seed, and exact
frame marks; `media-manifest.json` records the final edit.

`create-audio.py` synthesizes the original 32-second score from oscillators,
noise and percussion. It uses no external recordings, songs or licensed samples.
The final trailer uses that score, not a captured physical controller session.
Offline rendering is not a performance benchmark or hardware certification.

## Rebuild

Requires Godot matching the project, FFmpeg with libx264, Pillow, NumPy, SciPy,
and DejaVu fonts. Use an isolated capture profile so marketing playback does
not replace a player's save. Choose an unused X display number.

```bash
mkdir -p release/marketing
python marketing/capture-godot-media.py --godot "$GODOT_BIN" --display 231
python marketing/create-audio.py --output release/marketing/soundtrack.wav
# Generate the capsule/library artwork before the edit's closing card:
python marketing/render-godot-media.py
```

Use the capture helper's `--stills-only` option for a shorter visual proof.
MovieWriter fixes resolution before scripts run, so the helper creates an
isolated project copy with a 1920×1080 initial viewport. This is the same
responsive layout as resizing the shipping game. It changes no gameplay,
assets, rendering quality, or UI source.
Inspect the rendered trailer contact sheet, screenshot images, dimensions,
codec, duration, audio loudness and loop sizes before upload.

Steam requirements: [Trailers](https://partner.steamgames.com/doc/store/trailer),
[Graphical assets](https://partner.steamgames.com/doc/store/assets),
[Store descriptions](https://partner.steamgames.com/doc/store/page/description).
