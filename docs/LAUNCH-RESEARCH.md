# Sudoku Defense: alpha launch and market notes

Research checked October 24, 2026. Planning window: October 26–November 1, 2026, America/New_York. This is a recommendation, not a scheduled release or a record of changes made in Steamworks. Account-specific readiness is recorded separately in `STEAM-STORE-SETUP.md`.

## Recommended route

Run a **free, limited Steam Playtest** for the first public alpha. Keep the main game **Coming Soon** and use it to collect wishlists. Start with a small group we can actually support, then admit more players after the first fixes. A working target is 100–200 testers; that is a capacity choice, not a Valve requirement or a demand forecast.

The current build has a substantial loop: Sudoku placement, preparation, live tower defense, equipment, chests, a camp economy, seeded runs, three modes, and up to fifty rounds. It still needs independent players to test onboarding, balance, save continuity, and physical Deck/docked-controller behavior. That is a better fit for an alpha than asking customers to judge it as a paid release immediately.

**Price recommendation:** $0 for this Playtest; **$9.99 USD** as the working price for a later paid release or Early Access release once those tests are convincing. Do not charge for Playtest keys. Do not promise a future price increase. Recheck the price after observing actual play, and choose regional prices with Steam's current tools rather than a manual exchange-rate conversion.

Steam Playtest uses a separate child app, has a simplified review, and supports controlled admissions. It can use free keys even before the main store page is public. The main game's wishlists remain separate. [Valve: Steam Playtest](https://partner.steamgames.com/doc/features/playtest)

Paid Early Access is also legitimate for a playable alpha, but the build must be worth its price now. Valve asks developers to explain its current state and avoid promises that buyers are effectively funding. It does not remove ordinary store/build release requirements. [Valve: Early Access](https://partner.steamgames.com/doc/store/earlyaccess)

## Comparable products and pricing

These are **USD base-game list prices observed in Steam's indexed store pages**, checked on the research date. Sale prices are kept separate. Steam responses can be cached or regional, so an undated/expired offer is not represented as a live checkout quote. Bundles and DLC are excluded. These products establish a positioning range; they do not establish how many copies Sudoku Defense will sell.

| Game | Observed USD list | Promotion evidence | Why it matters |
| --- | ---: | --- | --- |
| [Isle of Arrows](https://store.steampowered.com/app/1946970/Isle_of_Arrows/) | $12.99 | No base-game discount in the USD result | Closest genre comparison: puzzle placement, player-built paths, tower defense, runs. |
| [Tower Tactics: Liberation](https://store.steampowered.com/app/1709900/Tower_Tactics%3A_Liberation/) | $12.99 | $4.41 at 66% off appeared in a cached offer ending October 22; expired before this research date | Tower defense combined with a familiar tabletop system and build choices. |
| [Rogue Tower](https://store.steampowered.com/app/1843760/Rogue_Tower/) | $14.99 | $8.99 at 40% off; retrieved offer says it ends November 3 | A route players influence, towers, upgrades, and roguelike structure. |
| [Thronefall](https://store.steampowered.com/app/2239150/Thronefall/) | $12.99 | No base-game discount in the USD result | A readable, compact defense game. Useful presentation/control benchmark. |
| [Luck be a Landlord](https://store.steampowered.com/app/1404850/Luck_be_a_Landlord/) | $9.99 | No base-game discount in the USD result | Familiar rules turned into a run with item synergies. Our slot machine is secondary, not the main promise. |
| [Balatro](https://store.steampowered.com/app/2379780/Balatro/) | $14.99 | A cached $11.99 offer has no reliable end date; a fresher USD result shows $14.99 | Useful bar for clarity, feedback, and replayability. Its exceptional success is not a sales forecast for this project. |
| [Sudoku Dungeon](https://store.steampowered.com/app/4175970/Sudoku_Dungeon/) | $9.99 | No base-game discount in the USD result | Direct Sudoku/combat hybrid: a different turn-based design with an 80-puzzle campaign. |
| [Cozy Sudoku](https://store.steampowered.com/app/3194140/) | $2.99 | $2.09 at 30% off; retrieved offer says it ends October 26 | Shows the lower-price expectation for a conventional Sudoku product. Our page must demonstrate the defense and equipment layer immediately. |

The closest tower-defense hybrids cluster at $12.99–$14.99. A $9.99 target gives Sudoku Defense room below those established products while being clearly more than a basic puzzle collection. The price depends on an enjoyable, understandable run and reliable controls; fifty rounds alone do not prove value. A later 10% launch offer would be $8.99, but there is no reason to configure a discount for a free alpha.

Do not infer revenue, conversion rates, or audience size from review counts. Several direct Sudoku hybrids have little public review evidence. That argues for testing the hook and onboarding before treating this as a validated niche.

## Positioning and tags

Lead with **Sudoku that becomes a tower-defense battle**. The second promise is building towers with collected modules. Explain the changing route in footage; it is the most unusual connection between the two phases. Keep slots and the camp economy lower on the page so the game does not look like a gambling title.

Recommended order for the Steam Tag Wizard:

| Rank | Tag | Reason |
| ---: | --- | --- |
| 1 | Tower Defense | The core combat and placement decisions. |
| 2 | Puzzle | Solving the board is a substantial part of play. |
| 3 | Roguelite | Runs, randomized rewards, and build choices. |
| 4 | Strategy | Resource spending and defense planning. |
| 5 | Logic | Sudoku is the distinctive puzzle system. |
| 6 | Loot | Chests and module drops change builds. |
| 7 | Inventory Management | Five sockets per tower and moving equipment. |
| 8 | Resource Management | Credits, fragments, seeds, and upgrade choices. |
| 9 | Procedural Generation | Validated generated puzzles and seeded runs. |
| 10 | Voxel | The board, towers, enemies, and chests. |
| 11 | Tactical | Where and how towers are equipped matters. |
| 12 | Real-Time with Pause | Battles run in real time and management panels pause them. |
| 13 | Top-Down | Board-led camera and play. |
| 14 | 3D | The native Steam build's world. |
| 15 | Sci-fi | High-tech towers, energy, and modules. |
| 16 | Colorful | Restrained bright tower/module palette. |
| 17 | Replay Value | Seeds, difficulties, modes, and loot combinations. |
| 18 | Controller | Native controls, including the right-stick cursor. |
| 19 | Singleplayer | Accurate player count. |
| 20 | Indie | Broad category, kept below specific information. |

These labels are present in Steam's [tag vocabulary](https://store.steampowered.com/tag/browse/en/). “Sudoku” did not appear there, so use the title, short description, and About text for that term rather than assuming a selectable tag. Do not add Deckbuilder, Card Battler, Multiplayer, Open World, or Relaxing merely because a successful comparison uses them. Do not claim Steam Deck Verified; that is Valve's status, not a tag we grant ourselves.

Valve recommends a relevant set of up to twenty tags. The top five should describe the product clearly, and order affects weighting. After applying the list, inspect the wizard's comparable titles; if the game is placed mainly beside conventional Sudoku apps or unrelated loot RPGs, adjust the relative weight of the core genre tags. [Valve: Steam Tags](https://partner.steamgames.com/doc/store/tags)

## What can actually happen next week

Public testing is the target, but **October 26–November 1 is not a confirmed launch window**. The account audit must establish what is already approved and how long Coming Soon has been public.

| Requirement | What to establish |
| --- | --- |
| Store and build review | Valve lists 3–5 business days for each and recommends allowing at least seven business days, including time for changes. A fresh submission on Monday does not give a safe next-week guarantee. |
| Paid base-game release | Store and build approval plus at least two weeks of public Coming Soon are required. A new Coming Soon page next week cannot also be a paid release next week. |
| Existing app onboarding | Confirm all account/app gates are clear. The current onboarding documentation lists a 21-day app-fee waiting period for first titles; do not rely on older 30-day guidance. |
| Playtest | Create/configure the child app, library/community assets, build, launch options, and Steam Input template. Complete its simplified review before setting it playable. |
| Store claims | Match screenshots, platform support, controls, and features to the actual current build. Windows export success alone is not evidence of Windows execution. |
| Disclosure | Review the content survey accurately, including simulated slots, generated player-facing art/audio/text, and any other applicable content. Do not guess attestations. |

Sources: [Review Process](https://partner.steamgames.com/doc/store/review_process), [Release Process](https://partner.steamgames.com/doc/store/releasing), [Onboarding](https://partner.steamgames.com/doc/gettingstarted/onboarding), [Content Survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey).

Keep the game unreleased during this alpha. A Playtest preserves eligibility for a future Steam Next Fest; a paid Early Access release would make the base game ineligible. Next Fest also requires a public demo and allows each game to participate once. Pick a future edition when the demo is ready. [Valve: Next Fest](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest)

Next week overlaps Steam Scream V, October 26–November 2. It is for horror or explicitly Halloween-centric games, which this game is not. Do not change tags or presentation to chase that event. Check a genuinely relevant future event after the alpha. [Valve: upcoming events](https://partner.steamgames.com/doc/marketing/upcoming_events)

## Store assets and page structure

Use current Godot gameplay, with the HUD visible enough to explain the actions. Retire the earlier web/Unity trailer if it shows different visuals or mechanics. Suggested page order:

1. Short description: the Sudoku/defense connection in one or two sentences.
2. First trailer: 30–45 seconds of actual play, showing a number become a tower in the first few seconds.
3. About section: solve and grow towers, followed by a short placement/transformation loop.
4. About section: shape the route and defend, followed by a combat loop.
5. About section: collect modules and equip towers, followed by a chest/equipment loop.
6. A short factual modes/control list and a clearly labeled alpha state note where applicable.

Steam supports GIF, WEBP, MP4, and WEBM animations in About This and Special Announcement sections. Its current guidance recommends 1170-pixel-wide assets and limits animations to twelve seconds. Export quiet 5–8-second loops; supply GIFs as requested and MP4 equivalents for size/quality. Add meaningful alt text. [Valve: extra assets](https://partner.steamgames.com/doc/store/page/assets)

A Steam trailer should primarily show gameplay, work without audio, and use a standard 16:9 size up to 1920×1080. Use H.264 video, AAC stereo audio, 30 or 60 fps, and 44/48 kHz audio. Upload early: an in-progress transcode blocks release. The automatically generated microtrailer uses clips from the first trailer, so distribute compelling gameplay throughout it. [Valve: trailers](https://partner.steamgames.com/doc/store/trailer)

Screenshots should be unembellished gameplay, not title cards. Capsules need a readable game title; avoid promotional claims and discount copy. Verify crop legibility at the actual small sizes. [Valve: graphical asset rules](https://partner.steamgames.com/doc/store/assets/rules)

## Alpha acceptance checks

Treat these as the team's quality gates, not Valve requirements:

- A new player can plant several towers, start a battle, open a chest, and equip a module without a developer explaining the controls.
- Touch, Deck controls, and a docked Xbox controller can reach every required action. Confirm scrolling, drag release/cancel, and returning from the menus on physical hardware.
- Save/reload and sleep/resume preserve an active run. Record the tested build ID and any known exception.
- Several people play beyond the opening rounds. Collect where they stop, what feels repetitive, and whether difficulty labels match their experience.
- No known run-stopping defect remains. A rollback build is ready, and one feedback channel is visible to every tester.
- The store does not claim Cloud, achievements, multiplayer, localization, or Deck Verified unless those features/statuses are actually present.

Ask after the first session: “What was confusing?”, “When did you start having fun?”, “What made you stop?”, and “Would you start another run?” Ask price/value only after play. Do not lead with the $9.99 recommendation in the feedback question.

## Practical promotion plan

| Day / gate | Task | Done when |
| --- | --- | --- |
| Oct 24–25 | Finish copy/assets, test the first-run flow, audit Steam checklists | Page preview and candidate build are internally reviewed. |
| Oct 26 | Submit the completed materials for the appropriate review when the owner has resolved required declarations | Submission is recorded; no promise of an approval date. |
| Oct 27–28 | Prepare short gameplay posts, a one-page press kit, and a small list of relevant puzzle/strategy/Deck creators | Files and individual outreach drafts are ready. No bulk unsolicited sending. |
| When approved | Publish Coming Soon/Playtest signup as appropriate; invite the first supported batch | Store links, signup/access, install, and feedback flow are verified externally. |
| First 24–48 hours | Triage installation, controls, onboarding, and save problems before balance requests | Blocking issues have an owner and reproducible report. |
| End of first test week | Share a concise changelog and choose the next test batch | Feedback themes and next three priorities are recorded. |

Use one primary call to action per post: request Playtest access when it is open; otherwise wishlist. A Discord can have just announcements, bug reports, feedback, and general chat at first. Avoid launching with a large set of empty channels. A Trello board should separate launch blockers, ready-to-publish material, live feedback, and completed work.

Give each external Steam link a source-specific UTM parameter. Example, after the page is public: `https://store.steampowered.com/app/3721150/?utm_source=instagram&utm_medium=social&utm_campaign=alpha_2026_10&utm_content=solve_to_defend`. Compare traffic and wishlists by creative; do not use raw views as evidence that the game is selling. Steam's UTM reporting is aggregated and conversions finalize after four days. [Valve: UTM Analytics](https://partner.steamgames.com/doc/marketing/utm_analytics)

Before the eventual paid launch, review the $9.99 target against the tested experience, regional prices, refund-sensitive onboarding problems, and actual player feedback. This research has not set prices, enrolled the game in an event, scheduled posts, contacted creators, or released the game.
