import test from 'node:test';
import assert from 'node:assert/strict';
import { itemGuide, towerBuild, chestGuide } from '../dist/game/item-guide.js';
import { ATTACHMENTS, CONSUMABLES, RARITIES } from '../dist/game/items.js';
import { Game } from '../dist/game/simulation.js';

const module = (kind, power = 2) => ({type: 'attachment', kind, power, rarity: 'rare'});

test('every item has a plain effect, honest lifetime, and actionable build guidance', () => {
  for (const definition of [...ATTACHMENTS, ...CONSUMABLES]) {
    const consumable = CONSUMABLES.includes(definition);
    const input = Object.freeze({...module(definition.id), type: consumable ? 'consumable' : 'attachment'});
    const guide = itemGuide(input);
    assert.equal(Object.keys(guide).length, 10);
    for (const field of ['name', 'role', 'effect', 'purpose', 'pairWith', 'stack', 'lifetime', 'rarityName', 'color']) assert.ok(guide[field].length > 2, `${definition.id}: ${field}`);
    assert.ok(!guide.effect.includes('unavailable'));
    assert.match(guide.lifetime, consumable ? /Single use/ : /Reusable.*1 of 5.*next round/);
    assert.equal(guide.rarityName, 'Rare'); assert.equal(guide.rarityRank, 2);
  }
});

test('equipment preview numbers agree with combat stats and enforced effect caps', () => {
  const game = new Game('item-guide-stats');
  const base = {number: 1, level: 1, attachments: []};
  const start = game.towerStats(base);
  const rapid = game.towerStats({...base, attachments: [module('rapid')]});
  assert.ok(Math.abs(rapid.attackSpeed / start.attackSpeed - 1.4) < 1e-9);
  assert.equal(itemGuide(module('rapid')).effect, '+40% fire rate');
  assert.equal(game.towerStats({...base, attachments: [module('power')]}).damage / start.damage, 1.5);
  assert.equal(itemGuide(module('power')).effect, '+50% bolt damage');
  assert.equal(itemGuide(module('range')).effect, '+0.56 cells of range');
  assert.equal(itemGuide(module('electric')).effect, 'Chains to 3 extra targets');
  assert.equal(itemGuide(module('frost', 10)).effect, '70% slow · 2s');
  assert.equal(itemGuide(module('blast', 10)).effect, '300% bolt damage as splash');
  assert.equal(itemGuide(module('venom')).effect, '60% bolt damage/s · 3s');
  assert.equal(itemGuide(module('gravity', 10)).effect, 'Pull back 0.8 cells');
  assert.equal(itemGuide(module('nova', 20)).effect, '250% bolt damage as pulse');
  assert.match(itemGuide(module('range')).stack, /4.75.*radii stay unchanged/);
  assert.match(itemGuide(module('gravity')).stack, /Bosses take 30%/);
});

test('boost guides distinguish durations, scope, and refresh rules', () => {
  const boost = kind => itemGuide({type: 'consumable', kind});
  assert.equal(boost('overclock').effect, 'All towers fire 2× as fast · 20s');
  assert.match(boost('overclock').stack, /refreshes.*stays at 2×/);
  assert.equal(boost('overcharge').effect, 'All towers deal +60% damage · 20s');
  assert.equal(boost('freeze').effect, 'All enemies move 60% slower · 12s');
  assert.match(boost('freeze').stack, /strongest slow.*do not multiply/);
  assert.match(boost('repair').effect, /up to 10 core health/);
  assert.match(boost('repair').lifetime, /any active run phase.*instant/);
});

test('chest explanations match the real opening counts, rarity, and fragment charge', () => {
  for (const rarity of RARITIES) {
    const game = new Game(`guide-${rarity.id}`); game.endSolve(); game.fragments = 100;
    const chest = game._addChest(rarity.id), guide = chestGuide(rarity.id);
    const result = game.openChest(chest.id);
    assert.equal(guide.count, result.rewards.length);
    assert.equal(guide.cost, 100 - game.fragments);
    assert.ok(result.rewards.every(item => item.rarity === rarity.id));
    assert.match(guide.contents, new RegExp(`${guide.count} ${rarity.name}`));
    if (['rare', 'epic', 'legendary'].includes(rarity.id)) {
      assert.ok(result.rewards.every(item => item.type === 'attachment'));
      assert.match(guide.explanation, /Guaranteed/);
    }
  }
  assert.match(chestGuide('common').explanation, /80% module · 20% single-use boost/);
  assert.match(chestGuide('uncommon').explanation, /85% module · 15% single-use boost/);
});

test('build identities describe actual modules without changing items or promising bonuses', () => {
  const tower = {attachments: [module('rapid'), module('rapid'), module('electric')]};
  const before = JSON.stringify(tower);
  assert.deepEqual(towerBuild(tower), {name: 'Storm Battery', summary: '3/5 slots · More frequent shots chain damage through groups.', kinds: ['rapid', 'electric']});
  assert.equal(towerBuild({attachments: [module('frost'), module('venom')]}).name, 'Frostbite');
  assert.equal(towerBuild({attachments: [module('range'), module('power')]}).name, 'Longshot Cannon');
  assert.equal(JSON.stringify(tower), before);
  assert.equal(towerBuild().name, 'Basic Bolt');
});

test('old or incomplete item data gets safe presentation fallbacks', () => {
  for (const item of [null, undefined, {}, {kind: 'missing', rarity: 'future'}, {kind: 'rapid', power: Infinity}, {kind: 'range', power: NaN}]) {
    const guide = itemGuide(item);
    assert.equal(typeof guide.effect, 'string');
    assert.doesNotMatch(guide.effect, /NaN|Infinity|undefined/);
  }
  assert.deepEqual(chestGuide({rarity: 'rare'}), chestGuide('rare'));
  assert.deepEqual(chestGuide('future'), chestGuide('common'));
  assert.doesNotThrow(() => towerBuild({attachments: [null, {}, module('rapid')]}));
});
