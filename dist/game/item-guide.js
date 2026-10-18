/** Player-facing equipment vocabulary. Read-only: never rolls loot or changes a save. */
import { RARITIES } from './items.js';

const display = (value, digits = 1) => Number(value.toFixed(digits)).toString();
const percent = value => `${display(value * 100)}%`;
const cells = value => `${display(value, 2)} cells`;
const MODULE_LIFETIME = 'Reusable · 1 of 5 tower slots · returns to your bag next round.';
const MODULES = {
  rapid: {
    name: 'Rapid Fire', role: 'Fire rate',
    effect: p => `+${percent(.20 * p)} fire rate`,
    purpose: 'Fire bolts more often and trigger equipped effects on every shot.',
    pairWith: 'Try Chain Lightning to send more chains through a group.',
    stack: 'Duplicates add fire-rate bonuses; they do not multiply each other.'
  },
  electric: {
    name: 'Chain Lightning', role: 'Crowd damage',
    effect: p => `Chains to ${Math.min(7, 1 + Math.floor(p))} extra targets`,
    purpose: 'Bolts jump between nearby enemies, losing damage with each jump.',
    pairWith: 'Try Rapid Fire for more chains, or Power for harder-hitting jumps.',
    stack: 'Duplicates strengthen chains: up to 7 jumps and 100% bolt damage on the first jump. Later jumps keep 75% of the previous damage.'
  },
  frost: {
    name: 'Frost', role: 'Crowd control',
    effect: p => `${percent(Math.min(.70, .18 * p))} slow · 2s`,
    purpose: 'Slow the struck enemy so your defenses have longer to attack it.',
    pairWith: 'Try Poison to keep a damaged enemy on the route longer.',
    stack: 'Duplicates add slow strength, up to 70%. Hits refresh the 2s duration.'
  },
  blast: {
    name: 'Splash', role: 'Crowd damage',
    effect: p => `${percent(Math.min(3, .35 * p))} bolt damage as splash`,
    purpose: 'Damage other enemies around the target whenever a bolt lands.',
    pairWith: 'Try Rapid Fire for repeated explosions, or Power for stronger splashes.',
    stack: 'Duplicates add blast power, up to 300% bolt damage and a 2.3-cell radius.'
  },
  venom: {
    name: 'Poison', role: 'Damage over time',
    effect: p => `${percent(.30 * p)} bolt damage/s · 3s`,
    purpose: 'Keep damaging a surviving target after your bolt lands.',
    pairWith: 'Try Power for stronger poison, or Frost to delay poisoned enemies.',
    stack: 'Duplicates add poison strength. Hits refresh 3s; repeated hits do not stack poison damage.'
  },
  range: {
    name: 'Long Range', role: 'Reach',
    effect: p => `+${cells(.28 * p)} of range`,
    purpose: 'Reach more of the route and start firing at enemies sooner.',
    pairWith: 'Try Power to hit harder from a tower covering a long stretch of route.',
    stack: 'Duplicates add targeting range, up to 4.75 cells. Effect radii stay unchanged.'
  },
  power: {
    name: 'Power', role: 'Damage',
    effect: p => `+${percent(.25 * p)} bolt damage`,
    purpose: 'Make bolts and damage effects based on those bolts hit harder.',
    pairWith: 'Try Poison, Splash, Chain Lightning, or Nova to amplify their damage too.',
    stack: 'Duplicates add damage bonuses; they do not multiply each other.'
  },
  gravity: {
    name: 'Gravity', role: 'Crowd control',
    effect: p => `Pull back ${cells(Math.min(.8, .14 * p))}`,
    purpose: 'Pull enemies near the impact backward along the route; bosses resist most of the pull.',
    pairWith: 'Try Rapid Fire to pull enemies back more often.',
    stack: 'Duplicates add pull strength, up to 0.8 cells per shot. Bosses take 30% of the pull.'
  },
  nova: {
    name: 'Nova', role: 'Close defense',
    effect: p => `${percent(Math.min(2.5, .20 * p))} bolt damage as pulse`,
    purpose: 'Each shot also damages enemies within 1.4 cells of this tower.',
    pairWith: 'Try Rapid Fire for more pulses; place this tower close to the route.',
    stack: 'Duplicates add pulse damage, up to 250% bolt damage. Radius stays at 1.4 cells.'
  }
};
const BOOSTS = {
  overclock: {
    name: 'Double Fire', role: 'All-tower boost', effect: 'All towers fire 2× as fast · 20s',
    purpose: 'Give your entire defense a burst of speed during battle.',
    pairWith: 'Use when many enemies are in tower range to get more shots from the timer.',
    stack: 'Using another refreshes the 20s timer; fire rate stays at 2×.', lifetime: 'Single use · battle only · lasts 20s.'
  },
  overcharge: {
    name: 'Damage Surge', role: 'All-tower boost', effect: 'All towers deal +60% damage · 20s',
    purpose: 'Temporarily strengthen every tower and its damage effects.',
    pairWith: 'Use while a boss or a tough group is inside your defenses.',
    stack: 'Using another refreshes the 20s timer; the bonus stays at +60%.', lifetime: 'Single use · battle only · lasts 20s.'
  },
  freeze: {
    name: 'Slow Field', role: 'Enemy slow', effect: 'All enemies move 60% slower · 12s',
    purpose: 'Slow the wave to give your towers more time to stop it.',
    pairWith: 'Use before enemies slip past your strongest towers.',
    stack: 'Using another refreshes the 12s timer. The strongest slow applies; slows do not multiply.', lifetime: 'Single use · battle only · lasts 12s.'
  },
  repair: {
    name: 'Core Repair', role: 'Healing', effect: 'Restore up to 10 core health',
    purpose: 'Recover health lost when enemies reached the core.',
    pairWith: 'Keep it until the core is damaged; it cannot be used at full health.',
    stack: 'Each use restores up to 10 health, without exceeding your maximum.', lifetime: 'Single use · any active run phase · instant.'
  }
};

function rarityOf(value) {
  const id = value && typeof value === 'object' ? value.rarity || value.id : value;
  return RARITIES.find(rarity => rarity.id === id) || RARITIES[0];
}

/** Plain primary labels leave generated loot names available as flavor text in item.name. */
export function itemGuide(item) {
  const rarity = rarityOf(item?.rarity);
  const boost = item?.type === 'consumable';
  const catalogue = boost ? BOOSTS : MODULES;
  const definition = Object.hasOwn(catalogue, item?.kind) ? catalogue[item.kind] : null;
  const rawPower = Number(item?.power);
  const power = Number.isFinite(rawPower) && rawPower > 0 ? rawPower : 1;
  const unknown = {
    name: boost ? 'Unknown Boost' : 'Unknown Module', role: boost ? 'Boost' : 'Equipment',
    effect: 'Details unavailable', purpose: 'Inspect this item before using it.',
    pairWith: 'Choose an item with a known effect to plan a build.',
    stack: 'Stacking details unavailable.', lifetime: boost ? 'Single-use item.' : MODULE_LIFETIME
  };
  const guide = definition || unknown;
  return {
    name: guide.name, role: guide.role,
    effect: typeof guide.effect === 'function' ? guide.effect(power) : guide.effect,
    purpose: guide.purpose, pairWith: guide.pairWith, stack: guide.stack,
    lifetime: guide.lifetime || MODULE_LIFETIME,
    rarityName: rarity.name, rarityRank: RARITIES.indexOf(rarity), color: rarity.color
  };
}

const SOLO_BUILDS = {
  rapid: ['Quickshot', 'Fires bolts more often.'],
  electric: ['Storm Spire', 'Chains damage through nearby enemies.'],
  frost: ['Frost Guard', 'Slows struck enemies to buy time.'],
  blast: ['Blast Cannon', 'Damages groups around each bolt impact.'],
  venom: ['Poison Spire', 'Leaves poison on surviving targets.'],
  range: ['Longshot', 'Covers more of the enemy route.'],
  power: ['Power Spire', 'Hits harder with each bolt.'],
  gravity: ['Gravity Well', 'Pulls nearby enemies backward along the route.'],
  nova: ['Pulse Turret', 'Adds a pulse around the tower to every shot.']
};
const PAIR_BUILDS = [
  ['rapid', 'electric', 'Storm Battery', 'More frequent shots chain damage through groups.'],
  ['frost', 'venom', 'Frostbite', 'Slows struck enemies and poisons survivors.'],
  ['gravity', 'nova', 'Pulse Anchor', 'Pulls enemies back and pulses around the tower.'],
  ['frost', 'blast', 'Chill Blaster', 'Slows the main target and blasts nearby enemies.'],
  ['range', 'power', 'Longshot Cannon', 'Harder-hitting bolts cover more of the route.'],
  ['rapid', 'blast', 'Barrage Turret', 'More frequent bolts create more explosions.']
];

/** Build names describe equipped effects; no set bonus is implied or applied. */
export function towerBuild(tower) {
  const attachments = Array.isArray(tower?.attachments) ? tower.attachments : [];
  const kinds = Object.keys(MODULES).filter(kind => attachments.some(item => item?.type !== 'consumable' && item?.kind === kind));
  if (!attachments.length) return {name: 'Basic Bolt', summary: '0/5 slots · Add modules to shape this tower’s role.', kinds};
  let name, description;
  const pair = PAIR_BUILDS.find(([a, b]) => kinds.includes(a) && kinds.includes(b));
  if (pair) [,, name, description] = pair;
  else if (kinds.length === 1) [name, description] = SOLO_BUILDS[kinds[0]];
  else if (kinds.includes('frost') || kinds.includes('gravity')) [name, description] = ['Crowd Control', 'Delays enemies while the defense attacks.'];
  else [name, description] = ['Modular Tower', 'Combines its equipped effects on each shot.'];
  const count = attachments.length;
  return {name, summary: `${count}/5 slots · ${description}`, kinds};
}

/** Guarantees describe existing Game.openChest rules, including exact rarity. */
export function chestGuide(rarity) {
  const quality = rarityOf(rarity);
  const count = {common: 1, uncommon: 1, rare: 2, epic: 2, legendary: 3}[quality.id];
  const boostChance = quality.id === 'common' ? 20 : quality.id === 'uncommon' ? 15 : 0;
  return {
    count,
    contents: `${count} ${quality.name} ${boostChance ? 'item' : `module${count === 1 ? '' : 's'}`}`,
    cost: quality.fragmentCost,
    explanation: boostChance
      ? `${100 - boostChance}% module · ${boostChance}% single-use boost. Reward matches the chest’s rarity.`
      : `Guaranteed ${quality.name} modules. Each uses one tower slot; duplicates can stack.`
  };
}
