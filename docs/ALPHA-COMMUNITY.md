# Alpha testing and community

Prepared October 24, 2026. Planning dates use America/New_York.

## Live task board

[Sudoku Defense — Alpha Launch](https://trello.com/b/IUoFHRhh/sudoku-defense-alpha-launch) is a private Trello board in YakStudios's workspace. It contains 15 cards across six lists: Start here, Owner decisions, Before alpha, Ready to share, Feedback & fixes, and Done. Nobody was invited and no social posts were sent.

The October 26–November 1 schedule is an internal testing target. It is not a public release announcement, scheduled post, or guarantee of Steam approval. The paid release cannot happen next week while the store has not begun its required public Coming Soon period. See `LAUNCH-RESEARCH.md` and `STEAM-STORE-SETUP.md` for the release route and observed Steam state.

All timed cards are due at 5 p.m. local time. The November 1 card correctly uses EST after the daylight-saving change; earlier dates use EDT.

| Target | Work |
| --- | --- |
| Monday, October 26 | Confirm the first free Playtest tester group and review the shipped build. Steam declarations and support details are complete. |
| Tuesday, October 27 | Review pricing and tags; approve current-gameplay trailer, screenshots and GIFs; finish the store checklist and prepare review submission. |
| Wednesday, October 28 | Check clean installation, saves, touch and controller paths; finish Discord setup if sign-in is available. |
| Thursday, October 29 | Prepare three social drafts; record a go/no-go decision for the first tester group. |
| Friday, October 30 | Run short first sessions if access and build checks passed. |
| Saturday, October 31 | Group reports, reproduce blockers, and choose the next patch. |
| Sunday, November 1 | Review what testers understood, where they stopped, and whether to widen testing. |

The board has a [reusable feedback template](https://trello.com/c/Xgecseg1/2-feedback-template-duplicate-for-each-report), a [go/no-go card](https://trello.com/c/NSqYrJRz/12-go-no-go-check-for-the-first-alpha-group), and an [owner decision card for alpha access](https://trello.com/c/gNbeLd5t/3-choose-alpha-access-route-and-tester-group). Cards have specific completion criteria and now reflect the completed work rather than the initial task list.

### Current board state

| List | Cards | Status |
| --- | ---: | --- |
| Start here | 2 | Current plan/build/access details and the reusable feedback template. |
| Owner decisions | 3 | Free Playtest rollout, later pricing decision, and Discord sign-in. |
| Before alpha | 3 | Owner media file drop, physical Playtest/input checks, and the go/no-go decision. |
| Ready to share | 2 | Completed media kit and three social drafts; both still need final owner review and a live destination before sharing. |
| Feedback & fixes | 3 | First sessions, report triage, and next-week review. |
| Done | 2 | Version 0.3.9 writing and seed fixes shipped; Steam survey, ratings, AI disclosure, requirements, and support completed. Both cards marked complete. |

Version **0.3.9** is shipped to the [web build](https://sudoku-defense-godot.yakstudios.chatgpt.site) and main Steam app **3721150**, default build **26177757**. The free Playtest app **5500140** has default build **26177734** uploaded. It remains **Hidden / Not Playable**, uses limited access, and has **zero admitted testers**. An uploaded build is not an open alpha.

The media kit is complete: a 32-second current-gameplay trailer, eight screenshots, three MP4/GIF loops, and Steam capsule/library artwork. The three About-section loops are uploaded to Steam. Main capsule/library/screenshot/trailer uploads still need the owner file drop described in `STEAM-ASSET-UPLOAD.md`; the available browser automation cannot complete that uploader.

- [Watch or download the trailer](https://chatgpt.com/library?file_id=libfile_c2bc498dcb488191ac6d4d184c2d682c&account_id=personal).
- [Download the complete Steam media kit and upload guide](https://chatgpt.com/library?file_id=libfile_d6daba6998d8819184956c36528a2da5&account_id=personal).

Twenty Steam tags are applied, led by Tower Defense, Puzzle, Roguelite, Strategy, and Logic. The alpha is free. **$9.99 USD** is a later paid-release recommendation, not a configured price.

The Content Survey is complete and ratings are published. AI-assisted text, procedural visuals, and synthesized audio are disclosed; no live generation runs in the game. Steam support details and Deck-baseline Linux requirements are saved. No additional owner-approval gate applies to these completed fields.

Public rollout remains on hold until the remaining assets are uploaded, the Playtest is installed and played through Steam under its own app ID for at least five minutes, and the required Valve reviews are approved. Tester-group/access decisions, later paid pricing, and optional Discord sign-in remain separate tasks. The board does not claim physical hardware validation, a public alpha launch, or a guaranteed date.

## Current alpha support

The public [GitHub issue tracker](https://github.com/yannage/Sudoku-Defense-beta/issues) is available for alpha bug reports while Discord setup awaits sign-in. The repository is public with issues enabled. Reports are public, so include the build, device, seed, and reproduction steps, but do not include personal information or access keys. No response-time guarantee is implied.

## Discord status

No server has been created yet. The authorized Discord page opened to a sign-in form; there was no verified signed-in account. Plugin discovery found no usable Discord integration. The separate Discord setup tab is retained for secure sign-in (cloud browser tab 11); Steamworks work uses a different tab. Do not publish an invite or claim that a server exists until creation and permissions are verified.

Proposed server name: **Sudoku Defense**. Keep the first version small:

| Channel | Purpose | Posting |
| --- | --- | --- |
| `start-here` | What the alpha includes, current build, access instructions, short rules, and where feedback goes. | Staff only. |
| `announcements` | Verified patch notes and testing updates. | Staff only. |
| `bug-reports` | One reproducible issue per thread, using the template below. | Testers. |
| `feedback` | First impressions, confusing moments, and balance suggestions. | Testers. |
| `deck-and-controls` | Handheld/docked setup and input-specific reports. | Testers. |
| `screenshots-and-builds` | Tower combinations and gameplay clips. | Testers. |

Do not grant testers administrator permissions, enable broad role mentions, add third-party bots, or publish private Steam keys. The server owner and any moderators must be chosen by the owner; no response-time promise is implied.

### Ready-to-use welcome copy

Welcome to the Sudoku Defense alpha. Solve a Sudoku board, turn your answers into towers, and equip them before the enemies arrive.

This is a work in progress. We are testing the controls, readability, balance, and how clearly the game explains itself. Bugs and unfinished details are expected.

Please include your build number and device when you report a problem. Tell us what you tried, what happened, and what you expected. A short clip helps. General impressions belong in `feedback`; input problems belong in `deck-and-controls`.

Be respectful, keep posts relevant, and do not share passwords, personal information, or private access keys. Critique the game without attacking other players.

### Bug report template

```text
Build/version:
Device and operating system:
Controls (touch, gamepad model, or mouse/keyboard):
Round / phase / difficulty / seed:

What I tried:
What happened:
What I expected:
Steps to reproduce:
Does it happen again?
Screenshot or short clip:
```

### First-session questions

1. What did you think you needed to do during the first minute?
2. Was there an action you wanted to take but could not find?
3. Did attaching gear change a tower in a way you could understand?
4. What was the most satisfying moment?
5. Did you want to start another run? Why or why not?

Avoid leading every tester toward new features. Log repeated problems first, then choose fixes that remove confusion or blocked play.

## Social copy drafts

These are unpublished drafts. Add the real, verified alpha or wishlist link only after it is available. Do not attach a paid launch date or a Steam Deck Verified claim.

**Core loop clip**

Sudoku, then tower defense. Every number you place grows a tower, and your recent moves help shape the enemy route. We're testing Sudoku Defense and looking for feedback on the first few rounds.

**Gear clip**

One tower, five gear slots. Add rapid fire, electricity, or a slow effect, then see what survives the next wave. This is Sudoku Defense. Which combination would you try first?

**Chest clip**

Clear a wave. Open a chest. Find something worth building around. We're testing the loot and tower upgrades in Sudoku Defense—tell us what feels good and what still gets in the way.

Use one call to action per post. If the alpha access route is not ready, ask for a wishlist only after the store is public; otherwise hold the draft. Review the crop, captions, audio level, and destination link before sharing.
