# Steam store setup — October 24, 2026

## Current release plan

Prepare a free, limited Steam Playtest for the week of October 26–November 1, 2026. The paid main game remains unreleased. Valve review and outstanding store assets determine when access can actually open; do not advertise a confirmed date yet. The main page has not started its public Coming Soon period, so the paid game cannot launch next week.

## Steam IDs

| Item | App | Store item | Linux depot | Packages |
|---|---:|---:|---:|---|
| Sudoku Defense | 3721150 | 883740 | 3721151 | Developer 1309911; beta testing 1309912; paid store 1309913 |
| Sudoku Defense Playtest | 5500140 | 1402643 | 5500141 | Developer 1897424; signup 1897425; Playtest 1897426 |

## Saved in Steamworks

- Main English short description and About copy saved and verified against `docs/STEAM-STORE-COPY.md`. Three uploaded MP4 loops embedded in the relevant sections and visually checked in the Steamworks editor; descriptive alt text saved for all three. Final About source is 1,911 characters, short description 257.
- Twenty tags published, in this order: Tower Defense, Puzzle, Roguelite, Strategy, Logic, Loot, Inventory Management, Resource Management, Procedural Generation, Voxel, Real-Time with Pause, Tactical, Top-Down, 3D, Sci-fi, Colorful, Controller, Singleplayer, Indie, Replay Value.
- Main controller disclosure: Partial Controller Support / Xbox Controllers. Native input remains implemented; full support criteria need physical verification, including all menus, exit, glyphs and text entry. No Steam Deck Verified claim.
- App and shortcut icons uploaded to both apps and verified after reload.
- Separate Playtest created, with Limited signups, Hidden store visibility, Not Playable status, zero participants and no friend invites.
- Playtest native Linux configuration published: `sudoku-defense`, Linux + SteamOS, 64-bit launch. Depot 5500141 restricted to Linux, all languages, all architectures (single-depot configuration).
- Playtest Generic Gamepad default template (4), Deck Left Mouse Click Emulation (1), and native Linux app support published.
- Both apps' Common Redistributables marked none and published; this Linux native build does not require the listed Windows redistributables.
- Main 0.3.9 build26177757 / manifest339043110308378658 activated on default. Playtest build26177734 / manifest7723049983870519643 staged on default; access remains closed. Exact binary hashes checked in both Steam manifests.
- Content Survey completed and ratings published: simulated gambling environment and chance-based play with earned credits, cartoon/fantasy combat and fights without gore; no real-money stake, drug or sexual content. Generated ratings Brazil10 / Germany12. AI-assisted player-facing text, procedural visuals and synthesized audio disclosed; no live generation or third-party AI service during gameplay. No new legal attestation appeared in this submission.
- Support URL saved: https://github.com/yannage/Sudoku-Defense-beta/issues (public repository, Issues enabled, verified by root).
- Minimum Linux requirements saved using the actual user-tested Steam Deck baseline: SteamOS3 64-bit, AMD Zen2 APU4c/8t, integratedRDNA2 graphics,16GBRAM,500MBfree. Notes state1280×800 and other Linux PCs not yet validated. Hardware reference: https://www.steamdeck.com/en/tech/deck; this is a conservative current-alpha baseline, not a measured lower-bound PC benchmark or Valve verification.

## Store media and upload handoff

All assets are in `release/marketing/`, with the capsule set in `release/marketing/capsules/`. The distributable media kit is `release/Sudoku-Defense-Steam-Media-0.3.9.zip`.

Steam's current legacy Graphical Assets and trailer forms require dragging local files from a file manager. They expose no applicable Browse/file chooser, existing-asset selector, bulk image ZIP uploader, or WebMCP tool. The current browser automation supports file choosers but cannot perform native filesystem-to-browser dragging. Localization imports only JSON/CSV text, and the visible Choose File on Graphical Assets is for PDF manuals. App-icon, depot-build and About-animation uploaders do support file choosers.

The remaining manual media upload is therefore concrete:

1. Open main app **Edit Store Page → Graphical Assets**, drag the relevant PNGs below into its drop area, confirm English and the matching category, then Upload/Save.
2. Under Screenshot assets, upload at least five actual gameplay screenshots; recommended order: `05-defend-your-towers.png`, `01-solve-the-grid.png`, `03-equip-modules.png`, `07-loot-reveal.png`, `08-combat-effects.png`, then the other three.
3. Upload the library assets; set library-logo placement on the lower-left empty area of the hero background.
4. Repeat the required capsule and library assets for Playtest app5500140.
5. Main **Trailers** already has the slot **Sudoku Defense — Gameplay Trailer**. Drop `sudoku-defense-steam-trailer.mp4` there, wait for transcoding, review playback and keep it first. The empty old slot is not an uploaded trailer.

| Steam field | File in capsules/ | Dimensions |
|---|---|---|
| Header Capsule | header-capsule.png | 920×430 |
| Small Capsule | small-capsule.png | 462×174 |
| Main Capsule | main-capsule.png | 1232×706 |
| Vertical Capsule | vertical-capsule.png | 748×896 |
| Library Capsule | library-capsule.png | 600×900 |
| Library Header | library-header.png | 920×430 |
| Library Hero | library-hero.png | 3840×1240 |
| Library Logo | library-logo.png | 1280×500, transparent |
| Page Background | page-background.png | 1438×810 |
| App/Shortcut icons | shortcut-icon.png | 512×512, already uploaded |

All eight gameplay screenshots are 1920×1080. The trailer is 32 seconds, 1920×1080 at 30fps, H.264/AAC stereo, with approximately 8 Mbps video. Three About loops are 1170px wide, 9/6/9 seconds; MP4 is preferred for efficient playback, GIF alternatives are supplied.

## Remaining launch gates

- Required capsule/library images and main gameplay screenshots still need the drag-upload step above.
- Main trailer upload/transcode still needs the drag-upload step above.
- Broader Linux PC minimum hardware testing remains; current requirements use the tested Deck baseline. Windows export existence alone is not a tested Windows release; current Steam delivery is native Linux only.
- Main paid-game planned release date and pricing remain unset. Research working target is $9.99 USD later; alpha Playtest is free.
- Main store and build reviews have not been submitted or approved. Main Coming Soon visibility has not started.
- Playtest must be installed and played through Steam for at least five minutes using its own app ID after a build is configured.
- Playtest review/approval and an explicit access-opening step remain. Hidden/Not Playable is intentional while preparing.
- Main paid release requires its Coming Soon period and approved pricing/reviews; the Playtest is a distinct alpha route.

See `docs/LAUNCH-RESEARCH.md` for researched timing, tags and pricing rationale, and `docs/STEAM-RELEASE.md` for exact uploaded build/manifest records.

## Final verification notes

The main Steamworks checklist now marks Basic Info, Descriptions, Content Survey, System Requirements, Controller Support, Support Info, Developer/Publisher, Tags, Icons, App Configuration, Build, Depot and Common Redistributables complete. Remaining main mandatory fields are planned paid-release date, graphical media, trailer, and approved pricing; reviews/Coming Soon follow. The separate Playtest has a configured build but still needs capsule/library graphics and five minutes of Steam play before review/release.

The standalone storefront beta preview encountered a separate Steam Store sign-in wall; no account switch was attempted. Saved source embeds and rendered videos were verified in the authenticated Steamworks visual editor. The page remains an unpublished store draft while required assets are missing.

Verified admin URLs:

- Main builds: https://partner.steamgames.com/apps/builds/3721150
- Main store editor: https://partner.steamgames.com/admin/game/edit/883740?activetab=tab_description
- Playtest management: https://partner.steamgames.com/apps/playtest/5500140
- Main content survey: https://partner.steamgames.com/contentsurvey/edit/3721150/
