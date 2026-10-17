# Gridfall 0.2.3 player guide

Gridfall mixes timed Sudoku with tower defense and a run-long collection of equipment. Your numbers create the towers; your loot determines how they fight.

## The board and quick bar

The play screen keeps the board, phase action, and all **nine number buttons** in the viewport. Tap a blank square, then a number to plant it. Bag replaces the number rail with an equipment tray while keeping the board visible; close the tray to return to planting. Secondary controls live in the bottom quick bar:

| Tab | What it opens |
| --- | --- |
| Tower | The selected tower's equipment tray; seed controls and reserve purchase when no tower is selected |
| Bag | The Equipment / Boosts tray with direct access to the board |
| Chests | Sealed chests, fragment requirements, and the chest collection |
| Notes | Legal candidates, smart notes, and the paid hint |
| More | Run details, Loot camp, casino, help, and fullscreen |

Only **one quick panel or equipment tray** opens at a time. Quick panels collapse when you tap their tab again, press the close button or Escape, or tap a blank board square. Clicking a planted tower opens its equipment tray. Close that tray using × or Bag; Escape cancels a selected item first, then closes the tray. The game clock and combat pause while a tray, quick panel, or full menu is open.

For the full inventory, open Bag → **Details**. On smaller screens it uses a compact item list. Select an item to inspect its effect and equipment action; **Back to items** returns to the list.

Chests, equipment, and quick-bar controls use matching voxel artwork. Item names, rarity labels, costs, and descriptions remain available alongside the art.

## Choose a run

| Mode | Length | Difficulty choices |
| --- | --- | --- |
| Free play | One board and battle | Choose at the start |
| Campaign | 50 rounds | Choose again before each new board |
| Locked in | 50 rounds | Starting choices stay fixed |

Sudoku and combat each have their own **Easy / Medium / Hard** setting. Harder Sudoku starts with fewer given numbers and offers more blanks to solve, stronger solve income, and better rarity luck. The generator targets 48 / 36 / 27 clues while retaining one solution; these are clue-density settings, not ratings from a human Sudoku solver. Combat difficulty changes enemy pressure and rewards. The 50-round progression is initial alpha tuning, not a claim of fully playtested balance.

## Solve, prepare, defend, collect

**Solve.** Select a blank square and enter a number. Each row, column, and 3×3 box must contain 1–9. Correct answers plant numbered seeds and earn credits; completed groups award bonuses. Your recent correct answers bend the upcoming enemy route. You can advance before finishing the entire puzzle.

**War prep.** The board becomes a battlefield and seeds grow into high-tech towers. Click an existing tower to inspect its stats, upgrade it, or open its equipment. Open chests, fit attachments, and buy reserve seeds before launching combat.

**Defend.** The route is fixed for this battle. Tower heads rotate toward their firing targets, making their aim easier to follow. Spend reserves to put extra towers in empty cells. An illegal Sudoku placement still fights, but increases corruption and disappears after the wave. Its equipment is returned. Enemies provide credits, energy fragments, and occasional chests. Keep the core alive and use temporary items when needed.

**Loot.** Spend fragments to unlock chests, collect equipment and consumables, buy passives, or try the slot machine. In Campaign, choose the next board's Sudoku and combat difficulties. Locked in keeps your original choices. A new board starts each round; your collection and run upgrades continue.

## Click a tower to upgrade it

| Upgrade | What it affects | How long it lasts |
| --- | --- | --- |
| Individual tower | Only the selected tower | Current board |
| Number family | All towers with that number, including new ones | Current run |
| Attachment | The tower wearing it | Until removed; returned between boards |
| Passive purchase | The run as described by its shop card | Current run |

Individual and family levels combine. For example, upgrading the **1 family** raises every 1 tower, while upgrading one selected 1 gives that tower an additional level. Prices are shown before purchase.

The nine numbers are tower families and colors. They all fire basic bolts initially. Equipment adds the special effects, so any number can become your lightning, frost, or rapid-fire build.

## Inventory and five attachment slots

Open **Bag → Equipment** during War prep or Loot. The tray sits alongside the board so you equip the actual towers:

- **Mouse:** drag an equipment card onto a planted tower.
- **Touch:** drag the card's dotted handle, or tap the card and then tap the tower. Swipe the card list to browse more equipment.
- **Selected tower:** tap a tower first, select an equipment card, then use **Attach**. Valid towers and full towers are marked on the board while an attachment is selected.

Each tower accepts **five attachments**. You can repeat a type—five electric attachments, for example—or mix rapid fire, lightning, and frost. Each attachment becomes a visible layer of the tower stack. Dropping on a blank, a printed clue, or a full tower does not consume the item.

Select a tower to see its five slots in the tray. Tap an occupied slot to return that attachment to the bag. **This tower** buys an upgrade for this map; **All Ns** raises that number's family level for the whole run. Equipment changes retain the existing War prep / Loot restriction; opening the tray during battle does not allow re-equipping.

| Attachment | Role |
| --- | --- |
| Rapid fire | Faster attacks |
| Electric | Chain lightning |
| Frost | Slow enemies |
| Blast | Splash damage |
| Venom | Damage over time |
| Range | Reach farther |
| Power | Stronger hits |
| Gravity | Disrupt enemy movement |
| Nova | Area bursts |

Items have **Common, Uncommon, Rare, Epic, or Legendary** rarity. Rarity and rolled power affect their strength; compare the displayed stats rather than color alone. Remove attachments to move them to another tower. Equipped items return to the bag when you advance to a new board, including equipment from illegal emergency towers.

Consumables remain in the inventory until used. Open **Bag → Boosts**, select an item, and press **Use boost** to consume it. Selecting or dragging a card does not activate a boost. Close the tray to resume battle and the effect timer. Combat effects count down during battle, not while paused in a menu; using the same effect again refreshes its duration.

| Consumable | Effect |
| --- | --- |
| Rushbloom Capsule | All towers fire 2× as fast for 20 seconds |
| Solar Sap Ampoule | All towers deal 60% more damage for 20 seconds |
| Winterwake Flask | All enemies move 60% slower for 12 seconds |
| Coremend Nectar | Repair up to 10 core health, including outside battle |

## Chests, fragments, and credits

These are separate resources:

- **Credits** pay for reserves, tower levels, family levels, passive upgrades, chest purchases, and slot spins.
- **Energy fragments** come from combat and pay a chest's opening cost.
- **Chests** stay in the inventory until opened. Finding or buying one does not bypass its fragment requirement.

Open chests in War prep or Loot. Check the displayed rarity and fragment cost, unlock the chest, then reveal its rewards. Higher rarities can produce stronger equipment. A lucky chest is a choice about how to build your towers, not an automatic upgrade to every tower.

The between-round shop offers passive upgrades for damage, salvage, and core survival. These compete for the same credits you could spend on towers or the casino.

## Slot machine

The slot machine is available during Loot and costs **20 credits** per spin. Open More → **Loot camp & casino**, then choose **Slots**. Outcomes can return credits or award a chest; a losing spin consumes the stake. Chests won here still need fragments to open. Odds and payouts are shown in the casino.

These are earned game credits with no purchase or cash-out system. This alpha includes slots only. Blackjack and NPC poker are planned possibilities, not playable modes yet.

## Controls

| Action | Keyboard / mouse | Standard gamepad |
| --- | --- | --- |
| Select a square | Click or arrow keys | D-pad / left stick |
| Select a number | Click its numbered button | LB / RB |
| Place selected number | Number keys 1–9 | A |
| Inspect a tower | Click an occupied square | Select tower and press A |
| Open equipment tray | I or Bag | B or View / Select on the board |
| Buy a reserve | B or Buy reserve | RT |
| Next phase | Enter or phase button | Y |
| Sound | Sound button | LT |
| Pause | Space | Start / Menu |
| Close a panel | Escape | B |

Use **I** to toggle Bag and **U** for the selected tower's tray or seed controls. In the tray, **LB / RB** cycles items. With an attachment selected, the **D-pad** cycles towers and **A** attaches it. **B** cancels the item selection first, then closes the tray. Open **Details** for the full inventory.

The in-game Help panel under More is the source of truth for the complete mapping. Menus use directional controls to move focus and A to activate the focused choice. For Steam Deck, begin with Steam Input's standard Gamepad layout.

## Alpha scope

The game includes an autosaved run on the current device. Browser data clearing or switching devices does not transfer that run; this is not Steam Cloud. Starting a new run resets the run's collection and progression.

The 50-round economy, enemy scaling, and drop rates are an initial design that needs real play sessions. The Linux build supports offline testing, but has not yet been validated on physical Steam Deck hardware or submitted to Steam.
