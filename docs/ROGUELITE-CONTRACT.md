# Sudoku Defense 0.2 integration contract

Game(seed, options), reset(seed, options): options {mode:'campaign'|'freeplay'|'locked',sudokuDifficulty:'easy'|'medium'|'hard',combatDifficulty:'easy'|'medium'|'hard'}.
Phases: solve -> prep -> battle -> loot -> next board (solve); final battle -> won. Campaign/locked 50 rounds; freeplay 1. `wave` is current round, `maxWaves`, `mode`, `sudokuDifficulty`, `combatDifficulty` exposed. Existing board, givens, solution, inventory[1..9] for reserve seeds, towers, enemies, route, timer, health, credits, etc preserved.
Methods: endSolve(), startBattle(), nextWave({sudokuDifficulty,combatDifficulty}), place(cell,number), buy(number), hint(), update(dt), drainEvents(), candidates(cell). Returns {ok,message,...}.
New state: fragments, chests [{id,rarity,cost}], items [item], familyLevels keyed1..9, passives keyed power/salvage/vitality, activeEffects [{id,kind,name,remaining,duration}], maxHealth.
Towers: {id,cell,number,illegal,cooldown,level:1,attachments:[],growth:0..1}; number defines family/color, not innate elemental ability. All fire basic bolts initially. Attachments define abilities and form visual stack layers. Five slots max, repeats permitted. Effective level is individual level + familyLevels[number] - 1.
New methods: towerStats(cellOrTower) -> {level,damage,cooldown,range,effects,...}; upgradeTower(cell); upgradeFamily(number); upgradeCost(cell); familyUpgradeCost(number); equipItem(cell,itemId); unequipItem(cell,slotIndex); useItem(itemId); openChest(chestId); buyChest(rarity='common'); buyPassive(kind); passiveCost(kind); spinSlots(); exportSave(); static fromSave(data).
Upgrade single tower lasts current map, family level/passives/inventory persist for run. Attachments on all towers are returned to bag when next board starts; do not lose equipment on illegal cleanup. Consumables only usable in battle (repair may heal elsewhere). Active timed effects pause outside battle. Chest opening allowed in prep/loot; chest generator consumes fragments and returns {ok,message,rewards:[items],rarity}. Slots only in loot phase, cost10 credits; returns {ok,outcomeId,reels:[symbol IDs],credits,chestRarity,gearRarity,cost,netCredits,reward,message}; reward is {credits,chestRarity,chest,item}, with null absent chest/item. Rewards are charged/deposited exactly once in spinSlots(), before any UI animation. Real credits-only game economy, no purchases/cash out.
Items pure module game/items.js exports RARITIES array [{id,name,color,multiplier,fragmentCost}], ATTACHMENTS array [{id,name,color,description}], CONSUMABLES array definitions, generateItem(rng,rarity,round,id), generateAttachment(rng,rarity,round,id), rollRarity(rng,luck=0), rollChest(rng,round,id,luck=0), rollSlot(rng), itemDescription(item). Item {id,type:'attachment'|'consumable',kind,name,rarity,color,power,description}. Attachment kinds rapid/electric/frost/blast/venom/range/power/gravity/nova. Consumables overclock (2x fire for20sec), overcharge (+damage20sec), freeze (slow12sec), repair (+health). Rarities common/uncommon/rare/epic/legendary. rollSlot returns {outcomeId,reels:[symbol IDs],credits,chestRarity:null or rarity,gearRarity:null or common,message}; costs applied by simulation. Symbols are gear, credit, or chest-{rarity}; three matching symbols represent the actual reward category. SLOT_COST=10; SLOT_PAYTABLE rows expose id,probability,credits,gearRarity,chestRarity,symbol,label. Every slot outcome follows fixed advertised odds; no fake near-miss manipulation or adaptive losses. generateAttachment uses exactly four seeded draws and guarantees reusable equipment without rejection sampling; regular generateItem retains its existing draw order.
Events existing plus seed,upgrade,equip,chestDrop,fragment,chestOpen,itemUsed,slots. Event shapes carry cell/x/y,number,color,text,rarity as relevant.
RogueUI exported class in rogue-ui.js constructor({game,getSelectedCell,onChange,onNewRun,onInspect,onSound,isReducedMotion}); methods refresh(), open(tab='inventory'), close(), isOpen(), openSetup(), showChest(result), handleController(action,dx,dy), tick(dt). Owns dialogs and added DOM plus rogue-ui.css only. UI root owns main app/index/style. Setup dialog calls onNewRun(options). New controls open inventory, loot, casino; inventory items selectable then equip to currently selected tower. Main root selected tower panel upgrade and family buttons call game methods. RogueUI can provide full gear inspector modal via open('tower').

## Slots economy

Every spin costs 10 credits. Payouts below 10 credits always grant one common attachment directly to the bag: it can be equipped immediately without opening a chest or spending fragments. Consolation equipment uses standard common power (0.90–1.10 at round 1; up to 1.42 at round 50), never a temporary consumable or higher rarity. Items have no sale price or cash-out mechanic; the UI must not describe a fictitious credit resale value.

| Outcome | Probability | Credits returned | Extra reward |
| --- | ---: | ---: | --- |
| Salvage | 25% | 0 | Common attachment |
| Recovery | 20% | 5 | Common attachment |
| Stake back | 25% | 10 | — |
| Double | 20% | 20 | — |
| Triple | 5% | 30 | — |
| Common cache | 2% | 10 | Sealed common chest |
| Uncommon cache | 1.5% | 10 | Sealed uncommon chest |
| Rare cache | 1% | 10 | Sealed rare chest |
| Epic cache | 0.4% | 10 | Sealed epic chest |
| Legendary cache | 0.1% | 10 | Sealed legendary chest |

The expected direct credit return is 9.5 per spin (95% of the stake); equipment/chests are additional rewards. 55% of spins recover the full stake or more, 25% make a credit profit, 45% deliver immediate equipment, and 5% give a bonus chest. Chest rewards always refund the stake, but retain the normal fragment opening cost. Reopening the slots UI or skipping its animation must never grant or debit anything again; saved game state already includes the prize.
