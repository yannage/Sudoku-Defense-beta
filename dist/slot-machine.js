import {voxelArt} from './voxel-art.js';
import {RARITIES, SLOT_COST, SLOT_PAYTABLE} from './game/items.js';
import {itemGuide} from './game/item-guide.js';

const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const percent = value => `${Number((value * 100).toFixed(3))}%`;
const quality = id => RARITIES.find(r => r.id === id) || RARITIES[0];
const credits = value => Math.round(Number(value) || 0).toLocaleString();

/** Presentation statistics are calculated from the same table used by the game. */
export function slotSummary() {
  const chance = predicate => SLOT_PAYTABLE.reduce((sum, row) => sum + (predicate(row) ? row.probability : 0), 0);
  return {
    stakeBack: chance(row => row.credits >= SLOT_COST),
    profit: chance(row => row.credits > SLOT_COST),
    gear: chance(row => Boolean(row.gearRarity)),
    chest: chance(row => Boolean(row.chestRarity)),
    creditReturn: SLOT_PAYTABLE.reduce((sum, row) => sum + row.probability * row.credits, 0) / SLOT_COST
  };
}

function reelFace(symbol, result) {
  if (String(symbol).startsWith('chest-')) {
    const rarity = quality(String(symbol).slice(6));
    return {art:voxelArt('chest', {rarity:rarity.id}), label:`${rarity.name} chest`, color:rarity.color};
  }
  if (symbol === 'credit') return {art:voxelArt('credit'), label:result ? `${credits(result.credits ?? result.reward?.credits)} credits` : 'Credits', color:'#ffbd7b'};
  const item = result?.reward?.item;
  if (symbol === 'gear' && item) {
    const guide = itemGuide(item);
    return {art:voxelArt(item.kind, {rarity:item.rarity}), label:guide.name, color:guide.color};
  }
  const kind = ['rapid','electric','frost','power'].includes(symbol) ? symbol : 'rapid';
  return {art:voxelArt(kind), label:symbol === 'gear' ? 'Common gear' : 'Equipment', color:'#9fe7c0'};
}

function rewardMarkup(game, result, spinning, ready) {
  if (spinning) return `<div class="sm-result-copy" role="status"><span class="sm-result-eyebrow">CIRCUIT ENGAGED</span><h4>Sorting your supplies…</h4><p>The reward will be added to your run automatically.</p><span class="sm-loading" aria-hidden="true"><i></i><i></i><i></i></span></div>`;
  if (!result) return `<div class="sm-result-copy" role="status"><span class="sm-result-eyebrow">NO EMPTY SPINS</span><h4>A little luck. Useful loot.</h4><p>${ready ? 'If you get back fewer credits than you spent, you also get a reusable Common attachment.' : 'Survive the battle to use the circuit at Loot Camp.'}</p><div class="sm-prize-preview" aria-hidden="true">${voxelArt('credit')}${voxelArt('rapid')}${voxelArt('chest',{rarity:'rare'})}</div><small>Credits · equipment · sealed chests</small></div>`;
  const reward = result.reward || {}, item = reward.item;
  const paid = Number(result.cost ?? SLOT_COST), returned = Number(reward.credits ?? result.credits ?? 0), net = returned - paid;
  const title = net > 0 ? `+${credits(net)} credits` : item ? 'Gear secured.' : reward.chestRarity ? 'A chest, on the house.' : 'Your stake is back.';
  const ledger = `Paid ${credits(paid)} · Returned ${credits(returned)} · Net ${net > 0 ? '+' : net < 0 ? '−' : ''}${credits(Math.abs(net))}`;
  let detail = '';
  if (item) {
    const guide = itemGuide(item), inBag = (game.items || []).some(entry => entry.id === item.id);
    const canEquip = ['prep','loot','won'].includes(game.phase) && inBag;
    detail = `<article class="sm-reward-item" style="--sm-prize:${guide.color}"><span class="sm-reward-art" aria-hidden="true">${voxelArt(item.kind,{rarity:item.rarity})}</span><div><small>${esc(guide.rarityName)} equipment</small><h4>${esc(guide.name)}</h4><p>${esc(guide.effect)}</p><span>${inBag ? 'Added to your field kit · reusable' : 'Kept in your run'}</span></div></article><button type="button" class="rg-secondary sm-equip" data-action="board-equip" data-item="${esc(item.id)}" data-focus="slot-equip" ${canEquip ? '' : 'disabled'}>Equip on the board <b>↗</b></button>`;
  } else if (reward.chestRarity) {
    const rarity = quality(reward.chestRarity), cost = reward.chest?.cost ?? rarity.fragmentCost;
    detail = `<article class="sm-reward-item" style="--sm-prize:${rarity.color}"><span class="sm-reward-art" aria-hidden="true">${voxelArt('chest',{rarity:rarity.id})}</span><div><small>${rarity.name} chest</small><h4>Supply cache</h4><p>${cost} fragments to open</p><span>Added to your chest inventory</span></div></article><button type="button" class="rg-secondary sm-equip" data-action="tab" data-tab="chests" data-focus="slot-chests">View your chests <b>↗</b></button>`;
  } else detail = `<div class="sm-credit-prize" aria-hidden="true">${voxelArt('credit')}<b>${credits(returned)}</b></div><p class="sm-deposited">Credits added to your balance.</p>`;
  return `<div class="sm-result-copy is-awarded" role="status" aria-live="polite"><span class="sm-result-eyebrow">${item ? 'EQUIPMENT RECOVERED' : reward.chestRarity ? 'BONUS CACHE' : net > 0 ? 'CREDIT PAYOUT' : 'CREDITS RECOVERED'}</span><h4>${title}</h4><p class="sm-ledger">${ledger}</p>${detail}</div>`;
}

/** Markup only. Game.spinSlots owns spending and awarding exactly once. */
export function renderSlotMachine({game, spin = null}) {
  const ready = game.phase === 'loot', spinning = Boolean(spin && !spin.done);
  const result = spin?.done ? spin.result : null, odds = slotSummary();
  const symbols = result?.reels || ['rapid','credit','chest-rare'];
  const reelDescription = spinning ? 'Reels spinning' : result ? `Reward: ${result.message || 'Supplies awarded'}` : 'Equipment, credits and a rare chest on three voxel reels';
  const reels = symbols.map((symbol, index) => {
    const face = reelFace(symbol, result), rolling = ['rapid','credit','chest-rare','electric','rapid'];
    return `<div class="sm-reel" style="--sm-reel:${index};--sm-symbol:${face.color}"><div class="sm-reel-window"><div class="sm-reel-track" aria-hidden="true">${(spinning ? rolling : [symbol]).map(id => `<span class="sm-reel-face">${reelFace(id, spinning ? null : result).art}</span>`).join('')}</div></div><span class="sm-reel-caption">${spinning ? 'Rolling…' : esc(face.label)}</span></div>`;
  }).join('');
  const shortfall = Math.max(0, SLOT_COST - (Number(game.credits) || 0));
  return `<section class="sm-casino"><div class="sm-intro"><div><span class="rg-eyebrow">LOOT CAMP / SUPPLY ARCADE</span><h3>Lucky Circuit</h3></div><span class="sm-guarantee"><i aria-hidden="true"></i>Something every spin</span></div><div class="sm-layout"><section class="sm-cabinet ${spinning ? 'is-spinning' : ''} ${result ? 'has-result' : ''}" aria-label="Voxel slot machine"><div class="sm-cabinet-crown"><span>YAK SUPPLY CO.</span><b>LUCKY CIRCUIT</b><span>MODEL 03</span></div><div class="sm-cabinet-face"><div class="sm-machine-status"><span><i></i>${spinning ? 'CIRCUIT ACTIVE' : ready ? 'READY TO SPIN' : 'CAMP ACCESS'}</span><span>REWARDS SECURED</span></div><div class="sm-reels" role="img" aria-label="${esc(reelDescription)}">${reels}</div><div class="sm-machine-plaque"><span>ONE SPIN<strong>${SLOT_COST} credits</strong></span><span class="sm-plaque-rule"></span><span>SAFETY NET<strong>Gear on a loss</strong></span></div></div><div class="sm-cabinet-base"><div class="sm-vent" aria-hidden="true"></div><span>GROW YOUR ARSENAL</span><div class="sm-vent" aria-hidden="true"></div></div></section><section class="sm-reward-panel" aria-label="Spin reward">${rewardMarkup(game, result, spinning, ready)}<button type="button" class="rg-primary sm-spin-button" data-action="spin" data-focus="spin" ${ready && !shortfall && !spinning ? '' : 'disabled'}><span>${spinning ? 'Reels rolling…' : result ? 'Spin again' : 'Spin the circuit'}</span><b>${SLOT_COST}<small> credits</small><i aria-hidden="true">↻</i></b></button><p class="sm-spin-note">${!ready ? 'Available at Loot Camp between maps.' : shortfall ? `Need ${shortfall} more credits to spin.` : 'Optional · spend earned credits, keep your loot.'}</p></section></div><div class="sm-odds-strip" aria-label="Slot chances"><div><strong>${percent(odds.stakeBack)}</strong><span>Full stake back or more</span></div><div><strong>${percent(odds.profit)}</strong><span>Finish with more credits</span></div><div><strong>Every loss</strong><span>Gets a Common attachment</span></div></div><details class="sm-odds"><summary data-focus="odds"><span>Exact odds & payouts</span><b>+</b></summary><p>One independent outcome per spin. Matching voxel reels show your reward; credit amounts below are the total returned from your ${SLOT_COST}-credit stake.</p><table><thead><tr><th scope="col">You receive</th><th scope="col">Chance</th></tr></thead><tbody>${SLOT_PAYTABLE.map(outcome => `<tr><td>${esc(outcome.label)}</td><td>${percent(outcome.probability)}</td></tr>`).join('')}</tbody></table><p>Average credit return: <strong>${percent(odds.creditReturn)}</strong> over many spins, plus equipment or chests. ${percent(odds.gear)} of spins add reusable Common gear directly to your bag. ${percent(odds.chest)} add a sealed chest; chests still need fragments. Individual results vary.</p><p class="sm-game-only">In-game credits only. No real money or cash out.</p></details></section>`;
}
