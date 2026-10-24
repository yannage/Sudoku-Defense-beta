# Steam artwork and trailer upload

Use the files in `Sudoku-Defense-Steam-Media-0.3.9.zip`. The screenshots and video show the native Godot game; capsule artwork is a separate illustration based on its voxel diorama.

Steamworks' current Graphical Assets and trailer editors accept a file dragged from a file manager. The connected browser controls do not support that operating-system file drag. The files are finished; these fields need a manual drop. Do not use the PDF/manual upload field for images.

## Main game: Sudoku Defense, app 3721150

Open **Edit Store Page → Graphical Assets**. Drag each image from the extracted `capsules` folder into its matching slot and save:

| File | Field | Pixels |
| --- | --- | --- |
| `header-capsule.png` | Header Capsule | 920 × 430 |
| `small-capsule.png` | Small Capsule | 462 × 174 |
| `main-capsule.png` | Main Capsule | 1232 × 706 |
| `vertical-capsule.png` | Vertical Capsule | 748 × 896 |
| `library-capsule.png` | Library Capsule | 600 × 900 |
| `library-header.png` | Library Header | 920 × 430 |
| `library-hero.png` | Library Hero | 3840 × 1240 |
| `library-logo.png` | Library Logo | 1280 × 500, transparent |

Place the logo over the hero's open area on the left. `page-background.png` is an optional store background. Icons have been prepared separately; see the account setup record for which are already uploaded.

Upload the eight numbered gameplay PNGs as screenshots, starting with `05-defend-your-towers.png`, `01-solve-the-grid.png`, `03-equip-modules.png`, `07-loot-reveal.png`, and `08-combat-effects.png`. They are unembellished 1920 × 1080 captures. Do not upload the contact sheet, poster, or capsule illustrations as screenshots.

Open **Trailers** and drop `sudoku-defense-steam-trailer.mp4` into the existing **Sudoku Defense — Gameplay Trailer** slot. Make it the first trailer, wait for Steam's processing to finish, and preview it. The current empty slot is not an uploaded trailer.

The three numbered `*-loop.mp4` files are already uploaded and embedded in **About This Game**, with alt text. GIF alternatives are supplied in the kit; do not duplicate the existing animations.

## Free testing app: Sudoku Defense Playtest, app 5500140

Upload the matching capsule and library images to the Playtest's required artwork slots. Keep the name clearly identified as the Playtest in Steamworks. The main game and Playtest are separate apps; filling one app's slots does not fill the other automatically.

Keep Playtest access hidden and not playable until the build, required metadata, and simplified review are complete. The launch record identifies the configured depot and build. A real installation/launch test is still required.

## Before any public announcement

Confirm the store preview displays the right artwork, working trailer, screenshots, and animations. Verify the access link from a tester account, then use either **request Playtest access** or **wishlist** as the call to action, depending on what is actually live. No release date is baked into these assets.
