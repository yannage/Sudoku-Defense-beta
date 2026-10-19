# Sudoku Defense — gameplay sizzle

Two 32-second cuts share the same story and original soundtrack. The vertical
cut is separately composed; it is not a crop of the Steam version.

| Export | Picture | Video | Audio |
| --- | --- | --- | --- |
| Steam trailer | 1920 × 1080, 16:9, 30 fps | H.264, 10 Mbps CBR, YUV 4:2:0 | AAC stereo, 192 Kbps, 48 kHz |
| Instagram vertical | 1080 × 1920, 9:16, 30 fps | H.264, 8 Mbps CBR, YUV 4:2:0 | AAC stereo, 192 Kbps, 48 kHz |

Both MP4s have web playback metadata at the beginning of the file. Main
messages are burned in and understandable without sound. The vertical ending
asks “What will you build?”; it does not invent a Steam listing, account handle,
release date, or public demo destination.

## Story

| Time | Beat |
| --- | --- |
| 0–3 s | Combat immediately: “What if Sudoku fought back?” |
| 3–9 s | Correct answers grow towers on an actual Sudoku grid. |
| 9–14 s | Earned equipment creates towers with different weapons. |
| 14–20 s | The latest moves shape the path through the battlefield. |
| 20–25 s | Two purchased illegal placements add emergency towers and corruption. |
| 25–28 s | Illustrated chest and equipment showcase: loot, upgrade, go again. |
| 28–32 s | Sudoku Defense title and “A little logic. A lot of firepower.” |

`gameplay.mjs` runs the shipping simulation and renderer. It plays nine complete
campaign rounds to earn the inventory shown, then solves, equips, and defends
round ten using public game actions. There are no synthetic enemies, invented
statistics, or modified combat rules. Titles, camera composition, loot artwork,
and the compact HUD are trailer graphics, rather than a recording of the full
application interface. The loot beat is an illustrated feature montage.

`create-audio.py` synthesizes the music and sound design from scratch without
external songs or samples. It is a 120 BPM electronic score in E minor, with
solve plucks, module clicks, combat impacts, loot chimes, and a closing sting.
The master measures approximately −14.4 LUFS and −1.2 dBTP.

## Rebuild

On Linux, install Node 22+, FFmpeg (with libx264), Python with NumPy and SciPy,
and DejaVu Sans fonts. Marketing dependencies are isolated from the game.

```bash
npm --prefix marketing install
python marketing/create-audio.py --output marketing/output/soundtrack.wav
node marketing/render-trailer.mjs --out=marketing/output
node marketing/render-trailer.mjs --vertical --out=marketing/output
```

For a quick visual proof:

```bash
node marketing/render-trailer.mjs --stills --out=marketing/output
node marketing/render-trailer.mjs --stills --vertical --out=marketing/output
```

The renderer writes title-frame posters alongside the videos. You can instead
choose a gameplay frame when uploading a Steam thumbnail. Keep video masters
and audio outputs out of Git; the reproducible sources live here.

Steam export settings follow the [official trailer documentation](https://partner.steamgames.com/doc/store/trailer).
Instagram's vertical composition leaves room for surrounding interface elements;
check the actual placement preview when creating an ad. Neither export has been
submitted to Steamworks or published as a paid ad.
