# Achievement artwork

These 26 original geometric illustrations use Sudoku Defense's navy panels,
mint voxel towers and amber highlights. They have no external image, font or
stock-art dependency. The vector shapes and pixel numerals are defined in
`generate_icons.gd`; the game's existing palette and voxel motifs are reused.

Each achievement has a colored achieved icon and a muted unachieved icon.
The muted version retains the same silhouette and adds a small lock, so color
is not the only state cue. The game should also show the achievement name and
earned/locked text; icons alone are not descriptions of unlock requirements.

## Outputs and reproducibility

- `godot/assets/achievements/<catalog icon>.svg` and `_locked.svg` are the
  in-game sources. Their basenames match `godot/data/achievements.json`.
- `steam/achievements/icons/<SD_ID>_ACHIEVED.png` and
  `<SD_ID>_UNACHIEVED.png` are the 256 × 256 Steam bulk-upload files.
  Supply both images and leave automatic grayscale conversion unchecked.
- `icon-manifest.json` records all 52 PNG hashes, dimensions, stable IDs and
  source paths.
- `contact-sheet.png` shows achieved icons in the first four rows and
  unachieved icons in the final four rows, in catalog order. The two empty
  cells at the end of each half are intentional.
- `contact-sheet-64.png` is the same layout at 64 × 64 per icon for a small
  size readability check.

From the repository root, run the generator with the project's pinned Godot
editor and an isolated user profile:

```sh
godot --headless --path godot --script ../steam/achievements/generate_icons.gd
```

The generator requires all 26 catalog entries to have a motif, renders both
variants through Godot's SVG renderer, checks 256 × 256 dimensions, rejects
duplicate image hashes and writes `ACHIEVEMENT_ICONS_PASS count=52 size=256x256`.
Re-running it on the same engine and catalog produces the same image hashes.

## Visual review

The full contact sheet and its 64-pixel counterpart were reviewed during the
0.3.19 implementation. Every achievement has a distinct motif: first actions,
campaign milestones, tower/family growth, module combinations, target
priorities, puzzle goals and challenge completions. Tower level and family
level use different silhouettes; ordinary and boss clears use separate crown
shapes; the incomplete-grid goal visibly retains empty cells.

This is artifact readability review, not a claim of physical Steam Deck or
Steam overlay acceptance. The final in-game achievement list still needs its
own rendered layout check with names and descriptions.
