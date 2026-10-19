/**
 * Seeded loot primitives. No wall-clock time or global randomness is used here.
 *
 * Rarity odds at luck 0: 58 / 27 / 10 / 4 / 1 percent.
 * Rarity odds at luck 1: 30 / 32 / 22 / 12 / 4 percent.
 * Intermediate luck linearly interpolates those distributions. Combat/map
 * difficulty and progression are converted into luck by the simulation.
 *
 * Attachment power = rarity multiplier × a uniform 0.90–1.10 roll ×
 * (1 + 0.006 × (round - 1)), with round clamped to 1–50. Stacking adds power;
 * it does not multiply previous attachments. Common/uncommon loot has a
 * 20%/15% consumable chance; rare or better loot is always an attachment.
 *
 * Slots cost 10 credits. Direct credit return averages 9.5 credits/spin:
 * 55% return the full stake or more, 25% make a credit profit, 45% award a
 * reusable common attachment, and 5% add a chest to a full stake refund.
 * Every return below the stake includes equipment deposited directly in the
 * bag, with no fragment cost. Reels display the actual prize category; there
 * are no empty outcomes, fabricated near-misses, or adaptive odds.
 */

export const RARITIES = Object.freeze([
  {id:'common',name:'Common',color:'#b7c7d9',multiplier:1,fragmentCost:5},
  {id:'uncommon',name:'Uncommon',color:'#91e8a6',multiplier:1.35,fragmentCost:7},
  {id:'rare',name:'Rare',color:'#77caff',multiplier:1.8,fragmentCost:10},
  {id:'epic',name:'Epic',color:'#c7a0ff',multiplier:2.4,fragmentCost:14},
  {id:'legendary',name:'Legendary',color:'#ffca69',multiplier:3.2,fragmentCost:20},
].map(Object.freeze));

export const ATTACHMENTS = Object.freeze([
  {id:'rapid',name:'Tempo Petal',color:'#6de8ff',description:'Accelerates firing. Repeated petals add attack speed.'},
  {id:'electric',name:'Livewire Crown',color:'#c6a0ff',description:'Chains lightning into extra enemies. Repeats improve reach, damage, and jumps.'},
  {id:'frost',name:'Rime Bud',color:'#a4c7ff',description:'Slows targets for 2 seconds. Repeats strengthen the chill, up to 70%.'},
  {id:'blast',name:'Cinder Pod',color:'#ffae68',description:'Adds explosive splash. Repeats increase the blast radius and damage.'},
  {id:'venom',name:'Spore Injector',color:'#9be878',description:'Poisons targets for 3 seconds. Repeats increase damage per second.'},
  {id:'range',name:'Horizon Tendril',color:'#ffe188',description:'Extends targeting range. Repeats extend it further, up to 4.75 cells.'},
  {id:'power',name:'Heartwood Reactor',color:'#fb86c3',description:'Amplifies bolt damage. Repeated reactors add damage bonuses.'},
  {id:'gravity',name:'Anchor Root',color:'#bb9bff',description:'Pulls struck enemies backward. Repeats deepen the pull, up to 0.8 cells.'},
  {id:'nova',name:'Sunburst Corolla',color:'#ff7289',description:'Adds a close-range pulse. Repeats strengthen its damage.'},
].map(Object.freeze));

export const CONSUMABLES = Object.freeze([
  {id:'overclock',name:'Rushbloom Capsule',color:'#6de8ff',duration:20,description:'All towers fire 2× as fast for 20 seconds. Battle only.'},
  {id:'overcharge',name:'Solar Sap Ampoule',color:'#ffe188',duration:20,description:'All towers deal 60% more damage for 20 seconds. Battle only.'},
  {id:'freeze',name:'Winterwake Flask',color:'#a4c7ff',duration:12,description:'All enemies move 60% slower for 12 seconds. Battle only.'},
  {id:'repair',name:'Coremend Nectar',color:'#91e8a6',duration:0,description:'Restores 10 core health, up to maximum health. Use during any active run phase.'},
].map(Object.freeze));

export const SLOT_COST = 10;
export const SLOT_PAYTABLE = Object.freeze([
  {id:'salvage',probability:.25,credits:0,gearRarity:'common',chestRarity:null,symbol:'gear',label:'Common module'},
  {id:'recovery',probability:.20,credits:5,gearRarity:'common',chestRarity:null,symbol:'gear',label:'5 credits + common module'},
  {id:'refund',probability:.25,credits:10,gearRarity:null,chestRarity:null,symbol:'credit',label:'10 credits'},
  {id:'double',probability:.20,credits:20,gearRarity:null,chestRarity:null,symbol:'credit',label:'20 credits'},
  {id:'triple',probability:.05,credits:30,gearRarity:null,chestRarity:null,symbol:'credit',label:'30 credits'},
  {id:'chest-common',probability:.02,credits:10,gearRarity:null,chestRarity:'common',symbol:'chest-common',label:'10 credits + common chest'},
  {id:'chest-uncommon',probability:.015,credits:10,gearRarity:null,chestRarity:'uncommon',symbol:'chest-uncommon',label:'10 credits + uncommon chest'},
  {id:'chest-rare',probability:.01,credits:10,gearRarity:null,chestRarity:'rare',symbol:'chest-rare',label:'10 credits + rare chest'},
  {id:'chest-epic',probability:.004,credits:10,gearRarity:null,chestRarity:'epic',symbol:'chest-epic',label:'10 credits + epic chest'},
  {id:'chest-legendary',probability:.001,credits:10,gearRarity:null,chestRarity:'legendary',symbol:'chest-legendary',label:'10 credits + legendary chest'},
].map(Object.freeze));

const BASE_ODDS = [.58,.27,.10,.04,.01];
const LUCKY_ODDS = [.30,.32,.22,.12,.04];
const PREFIXES = {
  common:['Workshop','Coppervein','Waking','Rainwashed','Scrappy'],
  uncommon:['Verdant','Stormfed','Overgrown','Spirited','Brightroot'],
  rare:['Thunderbloom','Moonforged','Wildheart','Dawnforged','Glassgarden'],
  epic:['Violet Eclipse','Astral Orchard','Hollow Star','Midnight Engine','Chronobloom'],
  legendary:['Last Sunrise','Garden of Tomorrow','Zero Hour','Thousand Summers','Impossible Spring'],
};
const SUFFIXES = ['Mk. I','Mk. II','Mk. III','Delta','Prime','Wildtype'];
const clamp = (value,min,max)=>Math.max(min,Math.min(max,value));
const roundTo = (value,digits=2)=>Number(value.toFixed(digits));
const pct = value=>`${roundTo(value*100,1)}%`;
const cells = value=>roundTo(value,2);

function random(rng) {
  if(typeof rng!=='function')throw new TypeError('A seeded random function is required.');
  const value=rng();
  if(!Number.isFinite(value)||value<0||value>=1)throw new RangeError('Random values must be in [0, 1).');
  return value;
}
const choose = (rng,values)=>values[Math.floor(random(rng)*values.length)];

export function getRarity(rarity='common') {
  const id=typeof rarity==='object'&&rarity?rarity.id:rarity;
  const found=RARITIES.find(entry=>entry.id===id);
  if(!found)throw new RangeError(`Unknown rarity: ${String(id)}`);
  return found;
}

/** Returns a rarity ID. luck is normalized to the interval 0–1. */
export function rollRarity(rng,luck=0) {
  const boost=clamp(Number(luck)||0,0,1),draw=random(rng);let cumulative=0;
  for(let i=0;i<RARITIES.length;i++) {
    cumulative+=BASE_ODDS[i]+(LUCKY_ODDS[i]-BASE_ODDS[i])*boost;
    if(draw<cumulative||i===RARITIES.length-1)return RARITIES[i].id;
  }
}

/** A sealed chest requires fragments; opening/reward count belongs to Game. */
export function rollChest(rng,round=1,id='chest',luck=0) {
  // The simulation already includes round progression in luck. Do not apply it
  // twice here; keeping the argument maintains the shared generation interface.
  void round;
  const rarity=getRarity(rollRarity(rng,luck));
  return {id,rarity:rarity.id,cost:rarity.fragmentCost};
}

/** Generates one exact-shape inventory item using only the caller's RNG. */
export function generateItem(rng,rarity='common',round=1,id='item') {
  const quality=getRarity(rarity);
  const consumableChance=quality.id==='common'?.20:quality.id==='uncommon'?.15:0;
  const isConsumable=random(rng)<consumableChance;
  const definition=choose(rng,isConsumable?CONSUMABLES:ATTACHMENTS);
  return makeItem(rng,quality,definition,isConsumable,round,id);
}

/** Guaranteed reusable equipment, without rerolling or consuming variable RNG. */
export function generateAttachment(rng,rarity='common',round=1,id='item') {
  const quality=getRarity(rarity),definition=choose(rng,ATTACHMENTS);
  return makeItem(rng,quality,definition,false,round,id);
}

function makeItem(rng,quality,definition,isConsumable,round,id) {
  const stage=clamp(Math.floor(Number(round)||1),1,50);
  const power=isConsumable?1:roundTo(quality.multiplier*(.9+random(rng)*.2)*(1+.006*(stage-1)));
  const name=isConsumable?definition.name:`${choose(rng,PREFIXES[quality.id])} ${definition.name} ${choose(rng,SUFFIXES)}`;
  const item={id,type:isConsumable?'consumable':'attachment',kind:definition.id,name,rarity:quality.id,color:quality.color,power,description:''};
  item.description=itemDescription(item);
  return item;
}

/**
 * Values below describe this module by itself. The simulation sums power for
 * each repeated kind before applying caps; five modules occupy five slots.
 */
export function itemDescription(item) {
  if(!item||typeof item!=='object')return 'Unknown item.';
  if(item.type==='consumable')return CONSUMABLES.find(def=>def.id===item.kind)?.description||'Unknown consumable.';
  const power=Math.max(0,Number(item.power)||0);
  let text;
  switch(item.kind) {
    case 'rapid':text=`+${pct(.20*power)} attack speed.`;break;
    case 'power':text=`+${pct(.25*power)} bolt damage.`;break;
    case 'range':text=`+${cells(.28*power)} cells of range (4.75-cell total cap).`;break;
    case 'electric':text=`Lightning chains to ${Math.min(7,1+Math.floor(power))} extra targets; first jump deals ${pct(Math.min(1,.30+.12*power))} bolt damage, each further jump retains 75%. Jump reach ${cells(1.5+.06*power)} cells.`;break;
    case 'frost':text=`Slows targets by ${pct(Math.min(.70,.18*power))} for 2 seconds (70% slow cap).`;break;
    case 'blast':text=`Splash deals ${pct(Math.min(3,.35*power))} bolt damage in ${cells(Math.min(2.3,.65+.12*power))} cells. Stacks cap at 300% damage and 2.3 cells.`;break;
    case 'venom':text=`Poison deals ${pct(.30*power)} bolt damage per second for 3 seconds.`;break;
    case 'gravity':text=`Pulls targets back ${cells(Math.min(.8,.14*power))} cells per cast (0.8-cell cap).`;break;
    case 'nova':text=`Adds a pulse dealing ${pct(Math.min(2.5,.20*power))} bolt damage within 1.4 cells (250% cap).`;break;
    default:return 'Unknown attachment.';
  }
  return `${text} Stackable · uses 1 of 5 slots.`;
}

/** Draws the advertised prize; Game owns charging, depositing, and chest IDs. */
export function rollSlot(rng) {
  // Integer probability units keep advertised boundaries exact (including
  // the 0.1% legendary row) rather than accumulating floating-point drift.
  const draw=random(rng)*1000;let cumulative=0,prize=SLOT_PAYTABLE.at(-1);
  for(const outcome of SLOT_PAYTABLE) {
    cumulative+=Math.round(outcome.probability*1000);
    if(draw<cumulative){prize=outcome;break;}
  }
  const reels=[prize.symbol,prize.symbol,prize.symbol];
  const message=prize.chestRarity?`${prize.label}! Stake returned; fragments unlock the bonus chest.`:prize.gearRarity?`${prize.credits?`${prize.credits} credits returned + a`:'A'} common module added to your bag. Ready to equip.`:`${prize.credits} credits returned${prize.credits>SLOT_COST?` · +${prize.credits-SLOT_COST} profit`: ' · stake recovered'}.`;
  return {outcomeId:prize.id,reels,credits:prize.credits,chestRarity:prize.chestRarity,gearRarity:prize.gearRarity,message};
}
