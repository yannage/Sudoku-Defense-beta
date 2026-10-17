import { Game, TOWERS } from './game/simulation.js';
import { VoxelRenderer } from './engine/renderer.js';
import { AudioEngine } from './engine/audio.js';
import { GamepadInput } from './engine/input.js';
import { RogueUI } from './rogue-ui.js';
import { QuickBar } from './quick-ui.js';

const $ = id => document.getElementById(id);
const storage = {
  get(key, fallback) { try { return JSON.parse(localStorage.getItem(key)) ?? fallback; } catch { return fallback; } },
  set(key, value) { try { localStorage.setItem(key, JSON.stringify(value)); return true; } catch { return false; } }
};
const SAVE_KEY = 'gridfall-run-v2';
let game, restored = false;
try {
  const data = storage.get(SAVE_KEY, null);
  if (data) { game = Game.fromSave(data); restored = !['won', 'lost'].includes(game.phase); }
} catch { /* An old/incomplete save never prevents a fresh run. */ }
if (!game || !restored) game = new Game(`gridfall-${Date.now()}`, { mode: 'campaign', sudokuDifficulty: 'easy', combatDifficulty: 'easy' });
const audio = new AudioEngine();
let selectedCell = Math.max(0, game.board.findIndex(n => !n)), selectedNumber = 1;
let paused = false, started = restored, configured = restored, notes = true, muted = storage.get('gridfall-muted', true);
let reduced = storage.get('gridfall-motion', matchMedia('(prefers-reduced-motion: reduce)').matches);
let saveAvailable = true;
let lastPhase = game.phase, lastUI = '', toastTimer, bannerTimer, lastTime = 0, runEnded = false, saveClock = 0;
let rogue, quick;
const renderer = new VoxelRenderer($('gameCanvas'), { onCell: cell => {
  if (blocked()) return;
  selectedCell = cell;
  const tower = selectedTower();
  if (tower) { selectedNumber = tower.number; quick.open('tower'); }
  else quick.close();
  refresh();
} });
renderer.setReducedMotion(reduced);
audio.setMuted(muted);
document.body.classList.toggle('reduced-motion', reduced);
$('soundBtn').classList.toggle('sound-on', !muted);
$('soundBtn').setAttribute('aria-label', muted ? 'Enable sound' : 'Mute sound');

rogue = new RogueUI({
  game,
  getSelectedCell: () => selectedCell,
  onChange: result => { if (result?.message) notify(result.message, result.ok === false); syncPhase(); refresh(); save(); },
  onNewRun: options => newRun(options),
  onInspect: cell => { selectedCell = cell; selectedNumber = selectedTower()?.number || selectedNumber; refresh(); },
  onSound: (type, data = {}) => { if (!muted) { audio.unlock(); audio.play({ type, ...data }); } },
  isReducedMotion: () => reduced
});
quick = new QuickBar({ game, onOpen: openRogue, onToggle: () => { audio.stop(); save(); } });
function openRogue(tab = 'inventory', itemId = null) {
  quick?.close(true);
  if (tab === 'inventory') { rogue.filter = 'all'; rogue.selectedItem = itemId; }
  rogue.open(tab);
}
const deck = $('towerDeck');
for (const t of TOWERS) {
  const button = document.createElement('button');
  button.className = 'tower-card'; button.dataset.number = t.number;
  button.style.setProperty('--tower-color', t.color);
  button.setAttribute('aria-label', `Plant number ${t.number}. Basic bolt seed. Add attachments to customize.`);
  button.innerHTML = `<span class="tower-num">${t.number}</span><span class="tower-reserve">×1</span><strong>Seed ${t.number}</strong><small>Family level 1</small><span class="shortcut">${t.number}</span>`;
  button.addEventListener('click', () => { selectNumber(t.number); place(); });
  deck.append(button);
}
function selectedTower() { return game.towers.find(t => t.cell === selectedCell); }
function blocked() { return paused || rogue?.isOpen() || $('helpDialog').open || $('pauseDialog').open; }
function engageAudio() { if (!muted) audio.unlock(); }
function save() { if (configured && typeof game.exportSave === 'function') { const ok = storage.set(SAVE_KEY, game.exportSave()); if (!ok && saveAvailable) notify('This browser cannot save progress. Keep this tab open.', true); saveAvailable = ok; } }
function notify(message, error = false) {
  if (!message) return;
  $('statusMessage').textContent = message;
  $('toast').textContent = message; $('toast').classList.toggle('error', error); $('toast').classList.add('visible');
  clearTimeout(toastTimer); toastTimer = setTimeout(() => $('toast').classList.remove('visible'), 2600);
}
function banner(text) {
  $('floatingBanner').textContent = text; $('floatingBanner').classList.add('show');
  clearTimeout(bannerTimer); bannerTimer = setTimeout(() => $('floatingBanner').classList.remove('show'), 1600);
}
function after(result) { if (result?.message) notify(result.message, result.ok === false); refresh(); save(); return result; }
function selectNumber(number) { selectedNumber = ((number - 1 + 9) % 9) + 1; refresh(); }
function place() {
  if (blocked()) return;
  if (selectedTower()) { quick.open('tower'); return; }
  quick.close();
  if (game.phase === 'prep') { notify('War prep: click a tower to equip or upgrade it. Launch when ready.'); return; }
  engageAudio(); $('gameCanvas').focus({ preventScroll: true });
  const result = game.place(selectedCell, selectedNumber);
  if (result.ok) {
    started = configured = true;
    $('statusMessage').textContent = result.message;
    if (game.phase === 'solve') selectedCell = nextBlank(selectedCell);
  } else notify(result.message, true);
  refresh(); save();
}
function nextBlank(cell) { for (let i = 1; i <= 81; i++) { const n = (cell + i) % 81; if (!game.board[n]) return n; } return cell; }
function move(dx, dy) {
  if (rogue.isOpen()) { rogue.handleController('move', dx, dy); return; }
  if ($('helpDialog').open || $('pauseDialog').open) { moveModal(dy || dx); return; }
  if (paused) return;
  quick.close();
  selectedCell = ((Math.floor(selectedCell / 9) + dy + 9) % 9) * 9 + (selectedCell % 9 + dx + 9) % 9;
  refresh();
}
function moveModal(delta) {
  const dialog = $('helpDialog').open ? $('helpDialog') : $('pauseDialog');
  const buttons = [...dialog.querySelectorAll('button:not([disabled])')].filter(b => !b.hidden);
  const current = buttons.indexOf(document.activeElement);
  buttons[(current + (delta < 0 ? -1 : 1) + buttons.length) % buttons.length]?.focus();
}
function hint() {
  if (blocked()) return;
  engageAudio(); const result = game.hint();
  if (result.ok) { started = configured = true; selectedCell = result.cell; selectedNumber = result.number; }
  after(result);
}
function phaseAction() {
  if (rogue.isOpen()) { rogue.handleController('phase'); return; }
  if ($('helpDialog').open) { closeHelp(); return; }
  if ($('pauseDialog').open) { if (runEnded) setup(); else togglePause(); return; }
  if (paused) return;
  quick.close(); engageAudio(); let result;
  if (game.phase === 'solve') { started = configured = true; result = game.endSolve(); }
  else if (game.phase === 'prep') { started = configured = true; result = game.startBattle(); }
  else if (game.phase === 'loot') { openRogue('loot'); return; }
  else if (['won', 'lost'].includes(game.phase)) { setup(); return; }
  else { openRogue('inventory'); return; }
  after(result); syncPhase(); $('gameCanvas').focus({ preventScroll: true });
}
function buyReserve() { if (blocked()) return; engageAudio(); after(game.buy(selectedNumber)); $('gameCanvas').focus({ preventScroll: true }); }
function upgradeOne() { if (blocked()) return; const tower = selectedTower(); if (tower) after(game.upgradeTower(tower.cell)); }
function upgradeFamily() { if (blocked()) return; after(game.upgradeFamily(selectedTower()?.number || selectedNumber)); }
function togglePause() {
  if (rogue.isOpen()) { rogue.handleController('back'); return; }
  if ($('helpDialog').open) { closeHelp(); return; }
  if (runEnded) return;
  quick.close();
  paused = !paused;
  if (paused) {
    $('pauseTitle').textContent = 'Expedition on hold.';
    $('pauseText').textContent = `Round ${game.wave} of ${game.maxWaves}. Your progress is saved on this device.`;
    $('resumeBtn').textContent = 'Resume expedition →'; $('spoilsBtn').hidden = true;
    $('pauseDialog').showModal(); audio.stop(); save();
  } else { $('pauseDialog').close(); engageAudio(); }
  refresh();
}
function openHelp() { if ($('pauseDialog').open || rogue.isOpen()) return; quick.close(true); $('helpDialog').showModal(); audio.stop(); }
function closeHelp() { $('helpDialog').close(); $('quickMore').focus({ preventScroll: true }); engageAudio(); }
function setup() { quick.close(); $('pauseDialog').close(); paused = false; rogue.openSetup(); }
function newRun(options) {
  quick.close(); game.reset(`gridfall-${Date.now()}`, options);
  paused = false; started = false; configured = true; restored = false; runEnded = false; lastPhase = game.phase;
  selectedCell = game.board.findIndex(n => !n); selectedNumber = 1;
  $('pauseDialog').close(); renderer.particles = []; renderer.labels = []; renderer.rings = []; renderer.pickups = []; renderer.beams = [];
  engageAudio(); notify('Expedition started. Plant your first answer when ready.'); refresh(); save();
}
function showEnd() {
  runEnded = true; save();
  const won = game.phase === 'won'; const best = Math.max(game.score, storage.get('gridfall-best', 0));
  storage.set('gridfall-best', best);
  $('pauseTitle').textContent = won ? (game.mode === 'freeplay' ? 'Siege secured.' : 'Expedition complete.') : 'The garden fell.';
  $('pauseText').textContent = `${won ? `${game.maxWaves} round${game.maxWaves === 1 ? '' : 's'} survived.` : `Your expedition reached round ${game.wave}.`} ${game.score.toLocaleString()} points. ${game.chests.length} sealed chests collected.`;
  $('resumeBtn').textContent = 'Choose a new expedition →'; $('spoilsBtn').hidden = !won;
  $('bestScore').textContent = `BEST SCORE ${best.toLocaleString()}`; $('pauseDialog').showModal();
}
function syncPhase() {
  if (game.phase === lastPhase) return;
  const previous = lastPhase; lastPhase = game.phase; quick.close();
  if (game.phase === 'solve') { started = false; selectedCell = game.board.findIndex(n => !n); if (selectedCell < 0) selectedCell = 0; }
  if (game.phase === 'prep') { banner('WAR PREP · GROW YOUR ARSENAL'); $('statusMessage').textContent = 'Click a tower to upgrade or equip. No timer during preparation.'; }
  if (game.phase === 'loot' && previous === 'battle') { banner('SECTOR SECURED'); openRogue('loot'); }
  if (['won', 'lost'].includes(game.phase)) showEnd();
  save(); refresh();
}
function inspectTower() {
  const tower = selectedTower(), number = tower?.number || selectedNumber, def = TOWERS[number - 1];
  const stats = tower ? game.towerStats(tower) : null;
  const family = game.familyLevels[number] || 1;
  document.documentElement.style.setProperty('--selected', def.color);
  $('app').classList.toggle('tower-selected', !!tower); $('app').classList.toggle('seed-selected', !tower);
  $('inspectorEyebrow').textContent = tower ? 'SELECTED TOWER' : 'SELECTED SEED';
  $('towerName').textContent = tower ? `Tower ${number} · Lv ${stats.level}` : `Seed ${number}`;
  $('towerGlyph').textContent = number;
  $('towerType').className = 'tower-type-level';
  $('towerType').textContent = tower ? `${Math.round(stats.damage * 10) / 10} DMG · ${(1 / stats.cooldown).toFixed(1)} SHOTS/SEC` : `FAMILY LEVEL ${family} · BASIC BOLT`;
  $('stockValue').textContent = `${game.inventory[number]} RESERVE SEEDS`;
  $('towerDescription').textContent = tower ? `Individual upgrades last this board. Family upgrades carry through your expedition.${tower.illegal ? ' Emergency seed: recovered after this battle.' : ''}` : 'Every seed starts with a basic bolt. Stack attachments to create its weapon.';
  $('towerUpgradePanel').hidden = !tower;
  if (tower) {
    const slots = $('stackSlots'); slots.replaceChildren();
    for (let i = 0; i < 5; i++) {
      const item = tower.attachments[i], b = document.createElement('button');
      b.className = item ? 'filled' : ''; b.style.setProperty('--item-color', item?.color || '#526d80');
      b.textContent = item ? ({ rapid: '»', electric: 'ϟ', frost: '❄', blast: '✹', venom: '◉', range: '◎', power: '▲', gravity: '◌', nova: '✦' })[item.kind] || '◆' : '+';
      b.title = item ? `${item.name} · ${item.description}` : `Empty slot ${i + 1}. Equip an attachment.`;
      b.setAttribute('aria-label', b.title); b.onclick = () => openRogue('tower'); slots.append(b);
    }
    $('gearBtn').innerHTML = `Manage attachments <span>${tower.attachments.length} / 5 slots</span>`;
    const cost = game.upgradeCost(tower.cell);
    $('upgradeTowerBtn').innerHTML = `This tower → Lv ${stats.level + 1} <span>ϟ ${cost}</span>`;
    $('upgradeTowerBtn').disabled = !Number.isFinite(cost) || game.credits < cost || ['won', 'lost'].includes(game.phase);
  }
  const familyCost = game.familyUpgradeCost(number);
  $('upgradeFamilyBtn').innerHTML = `All ${number}s → family Lv ${family + 1} <span>ϟ ${familyCost}</span>`;
  $('upgradeFamilyBtn').disabled = !Number.isFinite(familyCost) || game.credits < familyCost || ['won', 'lost'].includes(game.phase);
  $('costValue').textContent = `ϟ ${TOWERS[selectedNumber - 1].cost}`;
  $('buyBtn').disabled = game.credits < TOWERS[selectedNumber - 1].cost || ['won', 'lost'].includes(game.phase);
}
function refresh() {
  const phase = game.phase, battle = phase === 'battle', prep = phase === 'prep', loot = phase === 'loot', finished = ['won', 'lost'].includes(phase);
  for (const p of ['battle', 'prep', 'loot']) $('app').classList.toggle(p, phase === p);
  $('app').classList.toggle('low-health', game.health <= 6);
  for (const [p, id] of [['solve', 'navSolve'], ['prep', 'navPrep'], ['battle', 'navBattle'], ['loot', 'navLoot']]) $(id).classList.toggle('active', phase === p);
  $('runLabel').textContent = `${game.mode === 'locked' ? 'LOCKED IN' : game.mode === 'freeplay' ? 'FREE PLAY' : 'CAMPAIGN'} · ${game.sudokuDifficulty.toUpperCase()} GRID / ${game.combatDifficulty.toUpperCase()} SIEGE`;
  $('waveValue').innerHTML = `${String(game.wave).padStart(2, '0')}<span>/ ${String(game.maxWaves).padStart(2, '0')}</span>`;
  $('healthValue').textContent = game.health; $('healthBar').style.width = `${game.health / game.maxHealth * 100}%`;
  $('healthValue').nextElementSibling.textContent = `/ ${game.maxHealth}`;
  $('creditsValue').textContent = game.credits; $('fragmentsValue').textContent = game.fragments;
  $('chestsValue').textContent = game.chests.length; $('bagCount').textContent = game.items.length + game.chests.length;
  $('scoreValue').textContent = String(game.score).padStart(4, '0');
  $('corruptionValue').textContent = `${Math.round(game.corruption * 7.5)}%`; $('corruptionValue').style.color = game.corruption ? '#ffad7b' : '';
  $('timer').textContent = battle ? `${game.enemies.length} LIVE` : prep ? '∞' : loot ? 'CLEAR' : finished ? 'END' : `${String(Math.floor(Math.ceil(game.timer) / 60)).padStart(2, '0')}:${String(Math.ceil(game.timer) % 60).padStart(2, '0')}`;
  $('phaseChip').textContent = battle ? 'DEFEND' : prep ? 'WAR PREP' : loot ? 'LOOT CAMP' : finished ? 'RUN COMPLETE' : 'SOLVE';
  $('objectiveTitle').textContent = battle ? 'Make every tower count.' : prep ? 'Your build. Your rules.' : loot ? 'A moment to regroup.' : 'Build your advantage.';
  $('objectiveText').textContent = battle ? 'Use items from your bag. Plant reserve seeds in blanks to reinforce the line.' : prep ? 'Equip up to five modules per tower. Repeated modules stack their effects.' : loot ? 'Open chests, buy passives, or try your luck before the next map.' : 'Correct answers grow towers and earn credits. Harder puzzles offer more planting space.';
  $('boardMode').textContent = battle ? 'LIVE BATTLEFIELD' : prep ? 'WAR PREP · CLICK A TOWER' : loot ? 'SECTOR SECURED' : 'TACTICAL GRID';

  const total = game.givens.filter(n => !n).length;
  $('solveCount').textContent = `${game.roundSolvedCount ?? game.solvedCount} / ${total} PLANTED`; $('comboValue').textContent = `${game.combo} STREAK`;
  $('solveProgress').style.width = `${(game.roundSolvedCount ?? game.solvedCount) / total * 100}%`;
  $('phaseButtonText').textContent = battle ? 'Open bag'  : prep ? 'Launch siege' : loot ? 'Enter loot camp' : finished ? 'New expedition' : 'Enter war prep';
  $('phaseBtn').disabled = false;
  $('phaseBtn').setAttribute('aria-label', battle ? 'Open inventory for combat items' : $('phaseButtonText').textContent);
  $('phaseHint').innerHTML = battle ? 'Open your bag for usable combat boosts.' : prep ? 'No timer. Build your tower stacks. <kbd>Enter</kbd>' : loot ? 'Equipment carries to your next board.' : !started ? 'Clock starts with your first answer.' : 'Solve, then prepare. <kbd>Enter</kbd>';
  $('selectedLabel').textContent = `R${Math.floor(selectedCell / 9) + 1} · C${selectedCell % 9 + 1}`;
  $('notesSelectedLabel').textContent = $('selectedLabel').textContent;
  const tower = selectedTower(), filled = game.board[selectedCell];
  $('intelTitle').textContent = tower ? 'PLANTED TOWER' : battle ? 'EMERGENCY SEED' : 'FIELD NOTES';
  $('intelText').textContent = tower ? 'Open Tower to upgrade this seed or every matching number.' : filled ? 'A printed clue. Plant seeds in empty squares.' : battle ? 'Any reserve seed can go here. Wrong answers add +7.5% enemy health.' : prep ? 'Prep your planted towers. New legal seeds are planted during solving.' : notes ? 'Legal candidates for this square:' : 'Use each digit once per row, column and 3×3 box.';
  $('candidateList').replaceChildren();
  if (notes && !filled && phase === 'solve') for (const n of game.candidates(selectedCell)) {
    const b = document.createElement('button'); b.textContent = n; b.title = `Plant ${n}`;
    b.onclick = () => { selectNumber(n); place(); }; $('candidateList').append(b);
  }
  $('hintBtn').disabled = phase !== 'solve' || game.credits < 6;
  for (const button of deck.children) {
    const n = Number(button.dataset.number); button.classList.toggle('active', n === selectedNumber);
    button.setAttribute('aria-pressed', String(n === selectedNumber));
    button.querySelector('.tower-reserve').textContent = `×${game.inventory[n]}`;
    button.querySelector('small').textContent = `Family level ${game.familyLevels[n] || 1}`;
  }
  $('activeEffects').replaceChildren();
  for (const effect of game.activeEffects) { const el = document.createElement('span'); el.className = 'buff-pill'; el.textContent = `${effect.name} · ${Math.ceil(effect.remaining)}s`; $('activeEffects').append(el); }
  $('selectionHint').textContent = tower ? `Tower ${tower.number} · tap to upgrade` : filled ? 'Printed clue · choose a blank' : `${battle ? 'Plant a reserve' : prep ? 'Tap a tower to upgrade' : 'Tap a number to plant'}`;
  $('boardTip').textContent = battle ? 'Your latest moves shaped this route' : prep ? 'Tap a tower · equip & upgrade' : loot ? 'Loot camp is ready' : 'Tap a square, then a number';
  $('boardNotesState').textContent = notes ? 'NOTES ON' : 'NOTES OFF';
  $('seedRailLabel').textContent = battle ? 'RESERVE SEEDS' : prep || loot ? 'NUMBER FAMILIES' : 'PLANT A NUMBER';
  $('railHint').textContent = battle ? 'Any blank · illegal seeds add danger' : prep ? 'Tap a planted tower to build its stack' : 'Tap a tower for upgrades';
  const legal = notes && !filled && phase === 'solve' ? game.candidates(selectedCell) : [];
  for (const b of deck.children) b.classList.toggle('candidate', legal.includes(Number(b.dataset.number)));
  $('campBtn').hidden = !['prep', 'loot', 'won'].includes(phase);
  inspectTower(); rogue.refresh(); quick?.refresh();
  $('motionBtn').textContent = `Reduce motion: ${reduced ? 'on' : 'off'}`;
  $('bestScore').textContent = `BEST SCORE ${storage.get('gridfall-best', 0).toLocaleString()}`;
}
function toggleSound() {
  muted = !muted; storage.set('gridfall-muted', muted); audio.setMuted(muted); if (!muted) audio.unlock();
  $('soundBtn').classList.toggle('sound-on', !muted); $('soundBtn').title = muted ? 'Enable sound' : 'Mute sound';
  $('soundBtn').setAttribute('aria-label', $('soundBtn').title); notify(muted ? 'Sound muted.' : 'Sound on. Headphones recommended.');
}
$('phaseBtn').onclick = phaseAction; $('hintBtn').onclick = hint; $('buyBtn').onclick = buyReserve;
$('upgradeTowerBtn').onclick = upgradeOne; $('upgradeFamilyBtn').onclick = upgradeFamily; $('gearBtn').onclick = () => openRogue('tower');
$('inventoryBtn').onclick = () => openRogue('inventory'); $('campBtn').onclick = () => openRogue('loot'); $('chestsBtn').onclick = () => openRogue('chests');
$('helpBtn').onclick = openHelp; $('closeHelp').onclick = closeHelp; $('pauseBtn').onclick = togglePause;
$('resumeBtn').onclick = () => runEnded ? setup() : togglePause(); $('restartBtn').onclick = setup;
$('spoilsBtn').onclick = () => { $('pauseDialog').close(); openRogue('inventory'); };
$('soundBtn').onclick = toggleSound;
$('notesBtn').onclick = () => { notes = !notes; $('notesBtn').textContent = `◈ Smart notes ${notes ? 'on' : 'off'}`; $('notesBtn').setAttribute('aria-pressed', String(notes)); refresh(); };
$('motionBtn').onclick = () => { reduced = !reduced; storage.set('gridfall-motion', reduced); renderer.setReducedMotion(reduced); document.body.classList.toggle('reduced-motion', reduced); refresh(); };
function fullscreen() { if (document.fullscreenElement) document.exitFullscreen?.().catch(() => {}); else document.documentElement.requestFullscreen?.().catch(() => notify('Fullscreen is unavailable in this browser.')); }
$('fullscreenBtn').onclick = fullscreen;
$('pauseDialog').addEventListener('cancel', event => { event.preventDefault(); if (!runEnded) togglePause(); });
$('helpDialog').addEventListener('cancel', event => { event.preventDefault(); closeHelp(); });
document.addEventListener('keydown', event => {
  if (event.ctrlKey || event.metaKey || event.altKey || (event.repeat && !event.key.startsWith('Arrow'))) return;
  if (rogue.isOpen()) return;
  const key = event.key;
  if (key === 'Escape' && quick.isOpen()) { event.preventDefault(); quick.close(true); return; }
  if (key === 'Escape') { if ($('helpDialog').open) { event.preventDefault(); closeHelp(); } else if (!$('pauseDialog').open) { event.preventDefault(); togglePause(); } return; }
  if (key === ' ') { if (document.activeElement?.tagName === 'BUTTON') return; event.preventDefault(); if (!$('helpDialog').open) togglePause(); return; }
  if (key.toLowerCase() === 'h') { event.preventDefault(); if ($('helpDialog').open) closeHelp(); else openHelp(); return; }
  if (key === 'Enter' && document.activeElement?.tagName !== 'BUTTON') { event.preventDefault(); phaseAction(); return; }
  if (blocked()) return;
  if (key.toLowerCase() === 'i') { event.preventDefault(); openRogue('inventory'); return; }
  if (key.toLowerCase() === 'u') { event.preventDefault(); quick.toggle('tower'); return; }
  if (key.toLowerCase() === 'f') { fullscreen(); return; }
  if (key.toLowerCase() === 'b') { event.preventDefault(); buyReserve(); return; }
  if (/^[1-9]$/.test(key)) { event.preventDefault(); selectNumber(Number(key)); place(); return; }
  const dirs = { ArrowUp: [0, -1], ArrowDown: [0, 1], ArrowLeft: [-1, 0], ArrowRight: [1, 0] };
  if (dirs[key]) { event.preventDefault(); move(...dirs[key]); }
});
const controller = new GamepadInput({
  onMove: (dx, dy) => { if (quick.isOpen() && !rogue.isOpen()) quick.moveFocus(dy || dx); else move(dx, dy); },
  onNumber: delta => { if (rogue.isOpen()) rogue.handleController('number', delta); else if (!blocked()) selectNumber(selectedNumber + delta); },
  onAction: action => {
    if (action === 'sound') { toggleSound(); return; }
    if (quick.isOpen() && !rogue.isOpen()) {
      if (action === 'back') quick.close(true);
      else if (action === 'place') document.activeElement?.click?.();
      else if (action === 'phase') phaseAction();
      return;
    }
    if (rogue.isOpen()) { rogue.handleController(action); return; }
    if ($('helpDialog').open || $('pauseDialog').open) {
      if (action === 'place') document.activeElement?.click?.();
      else if (action === 'back') { if ($('helpDialog').open) closeHelp(); else if (!runEnded) togglePause(); }
      return;
    }
    if (action === 'phase') phaseAction(); else if (action === 'place') place(); else if (action === 'hint') hint();
    else if (action === 'buy') buyReserve(); else if (action === 'back') openRogue('inventory');
  },
  onPause: togglePause,
  onHelp: () => { if (rogue.isOpen()) rogue.handleController('back'); else openRogue('inventory'); }
});
document.addEventListener('visibilitychange', () => { if (document.hidden) { save(); if (started && !blocked() && !runEnded) togglePause(); } });
window.addEventListener('pagehide', save);
function frame(ms) {
  const dt = Math.min((ms - lastTime) / 1000 || 0, .06); lastTime = ms;
  controller.update(dt); rogue.tick(dt);
  const stopped = blocked() || quick.isOpen();
  if (!stopped && started) game.update(dt);
  if (!stopped && !muted) audio.update(dt, game.phase);
  for (const event of game.drainEvents()) {
    renderer.burst({ ...event, text: ({ equip: 'LAYER EQUIPPED', chestOpen: 'LOOT RECOVERED', itemUsed: 'BOOST ACTIVATED' })[event.type] || event.text });
    if (!muted) audio.play({ ...event, type: ({ waveComplete: 'reward', combo: 'reward', win: 'reward', lose: 'leak' })[event.type] || event.type });
    if (event.type === 'wave') banner(`ROUND ${game.wave} · INCOMING`);
    if (event.type === 'chestDrop') $('statusMessage').textContent = `${event.rarity || ''} sealed chest recovered. Fragments open it at camp.`;
    if (event.type === 'combo') notify(event.text?.replace('coins', 'credits'));
    if (event.type === 'leak') $('statusMessage').textContent = 'Core hit! Reinforce the exit or use a combat item.';
  }
  renderer.render({ ...game, selectedCell, selectedNumber, towerColors: TOWERS.map(t => t.color) }, paused ? 0 : dt, ms / 1000);
  syncPhase();
  const key = [game.phase, game.wave, Math.ceil(game.timer), game.credits, game.fragments, game.health, game.score, game.enemies.length, game.corruption, game.combo, game.solvedCount, game.roundSolvedCount, game.chests.length, game.items.length, game.activeEffects.map(e => Math.ceil(e.remaining)).join(','), controller.connected].join('|');
  if (key !== lastUI) { refresh(); lastUI = key; }
  saveClock += dt; if (saveClock >= 5) { saveClock = 0; save(); }
  $('performanceLabel').textContent = controller.connected ? 'CONTROLLER CONNECTED' : configured ? (saveAvailable ? 'AUTOSAVE ON · WEB / DESKTOP' : 'SAVES UNAVAILABLE') : 'WEB / DESKTOP';
  requestAnimationFrame(frame);
}
refresh();
if (restored) togglePause(); else rogue.openSetup();
requestAnimationFrame(frame);
