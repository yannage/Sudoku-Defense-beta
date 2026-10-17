import { ATTACHMENTS, RARITIES, itemDescription } from './game/items.js';
import { voxelArt } from './voxel-art.js';

const GEAR_PHASES = ['prep', 'loot', 'won'];
const ACTIVE_PHASES = ['solve', 'prep', 'battle', 'loot'];
const sameId = (a, b) => String(a) === String(b);
const el = (tag, className, text) => { const node = document.createElement(tag); if (className) node.className = className; if (text !== undefined) node.textContent = text; return node; };
const number = value => Number(value || 0).toFixed(1).replace(/\.0$/, '');
const briefEffect = item => {
  const power = Math.max(0, Number(item?.power) || 0);
  if (item?.type === 'consumable') return ({overclock:'2× fire rate · 20s', overcharge:'+60% damage · 20s', freeze:'60% enemy slow · 12s', repair:'Heal up to 10 core'})[item.kind] || 'Temporary boost';
  return ({
    rapid: `Fire rate +${number(20 * power)}%`, power: `Damage +${number(25 * power)}%`,
    range: `Range +${Number((.28 * power).toFixed(2))} cells`, electric: `Chain ${Math.min(7, 1 + Math.floor(power))} targets`,
    frost: `Slow ${number(Math.min(70, 18 * power))}%`, blast: `Splash ${number(Math.min(300, 35 * power))}% dmg`,
    venom: `Poison ${number(30 * power)}%/s`, gravity: `Pull ${Number(Math.min(.8, .14 * power).toFixed(2))} cells`,
    nova: `Pulse ${number(Math.min(250, 20 * power))}% dmg`
  })[item?.kind] || 'Tower attachment';
};
const location = cell => `R${Math.floor(cell / 9) + 1} · C${cell % 9 + 1}`;

/** A board-adjacent kit: every mutation stays in Game; pointer drags are previews until release. */
export class LoadoutTray {
  constructor({ game, renderer, getSelectedCell, onSelectCell, onChange, onClose, onLibrary, isBlocked = () => false }) {
    Object.assign(this, { game, renderer, getSelectedCell, onSelectCell, onChange, onClose, onLibrary, isBlocked });
    this.visible = false; this.filter = 'attachment'; this.itemId = null; this.drag = null; this.hoverCell = null; this.lastKey = ''; this.suppressClickUntil = 0;
    this.root = el('section', 'loadout-tray'); this.root.id = 'loadoutTray'; this.root.hidden = true; this.root.setAttribute('aria-label', 'Tower equipment tray');
    this.root.innerHTML = `<div class="loadout-head"><div class="loadout-tabs" role="tablist" aria-label="Item type"><button id="loadoutEquipment" role="tab" data-loadout-filter="attachment">Equipment <b></b></button><button id="loadoutBoosts" role="tab" data-loadout-filter="consumable">Boosts <b></b></button></div><span class="loadout-held">TIME HELD</span><button id="loadoutLibrary" class="loadout-library" title="Open full inventory">Details ↗</button><button id="loadoutClose" class="loadout-close" aria-label="Close equipment tray">×</button></div><div id="loadoutCards" class="loadout-cards" aria-label="Available items"></div><div class="loadout-preview"><span id="loadoutHint" role="status" aria-live="polite"></span><button id="loadoutEquip" hidden>Attach</button><button id="loadoutUse" hidden>Use boost</button><button id="loadoutCancel" hidden aria-label="Cancel selected attachment">Cancel</button></div><div id="loadoutTarget" class="loadout-target"><div class="loadout-tower-info"><strong id="loadoutTowerName">Tap a planted tower</strong><small id="loadoutTowerStats">Select a tower to inspect or upgrade it.</small></div><div id="loadoutSlots" class="loadout-slots" aria-label="Five attachment slots"></div><button id="loadoutUpgradeTower" class="loadout-upgrade" disabled></button><button id="loadoutUpgradeFamily" class="loadout-upgrade family" disabled></button></div>`;
    const arsenal = document.querySelector('.arsenal'); arsenal.parentNode.insertBefore(this.root, arsenal);
    this.$ = id => this.root.querySelector(`#${id}`);
    this.$('loadoutClose').onclick = () => this.close(true);
    this.$('loadoutLibrary').onclick = () => { this._cancelDrag(); this.onLibrary?.(this.itemId); };
    this.$('loadoutCancel').onclick = () => this._clearSelection();
    this.$('loadoutEquip').onclick = () => this._equip(this.getSelectedCell());
    this.$('loadoutUse').onclick = () => { if (this.isBlocked()) return; const item = this._item(); if (!item || item.type !== 'consumable') return; this._result(this.game.useItem(item.id)); };
    this.$('loadoutUpgradeTower').onclick = () => { if (!this.isBlocked()) this._result(this.game.upgradeTower(this.getSelectedCell())); };
    this.$('loadoutUpgradeFamily').onclick = () => { const tower = this._tower(); if (tower && !this.isBlocked()) this._result(this.game.upgradeFamily(tower.number)); };
    this.root.addEventListener('click', event => this._click(event));
    this.root.addEventListener('pointerdown', event => this._pointerDown(event));
    this.root.addEventListener('pointermove', event => this._pointerMove(event));
    this.root.addEventListener('pointerup', event => this._pointerUp(event));
    this.root.addEventListener('pointercancel', () => this._cancelDrag());
    this.root.addEventListener('lostpointercapture', () => { if (this.drag) this._cancelDrag(); });
    // Native synthetic clicks following a drag must never plant a seed or equip twice.
    document.addEventListener('click', event => { if (Date.now() < this.suppressClickUntil) { event.preventDefault(); event.stopImmediatePropagation(); } }, true);
    document.addEventListener('visibilitychange', () => { if (document.hidden) { this._cancelDrag(); this.itemId = null; this.lastKey = ''; } });
  }
  isOpen() { return this.visible; }
  open(options = {}) {
    this._cancelDrag(); const trigger = document.activeElement;
    this.returnFocus = trigger && !this.root.contains(trigger) && !trigger.closest?.('[hidden]') ? trigger : document.getElementById('quickInventory');
    this.visible = true; this.root.hidden = false;
    const requested = this.game.items.find(item => sameId(item.id, options.itemId));
    if (options.filter) this.filter = ['consumable', 'boosts'].includes(options.filter) ? 'consumable' : 'attachment';
    else if (requested) this.filter = requested.type;
    else this.filter = this.game.phase === 'battle' ? 'consumable' : 'attachment';
    this.itemId = requested?.id ?? null; this.hoverCell = null; this.lastKey = '';
    document.getElementById('app')?.classList.add('loadout-open'); this.refresh();
    if (requested) this._focusSelection(); else this.$(this.filter === 'consumable' ? 'loadoutBoosts' : 'loadoutEquipment').focus({ preventScroll: true });
  }
  close(restoreFocus = false) {
    if (!this.visible) return;
    this._cancelDrag(); this.visible = false; this.itemId = null; this.hoverCell = null; this.root.hidden = true;
    document.getElementById('app')?.classList.remove('loadout-open'); this.onClose?.();
    if (restoreFocus) (this.returnFocus?.isConnected && !this.returnFocus.closest?.('[hidden]') ? this.returnFocus : document.getElementById('quickInventory'))?.focus?.({ preventScroll: true });
  }
  toggle() { this.visible ? this.close(true) : this.open(); }
  _tower(cell = this.getSelectedCell()) { return Number.isInteger(cell) ? this.game.towers.find(tower => tower.cell === cell) : undefined; }
  _item() { return this.game.items.find(item => sameId(item.id, this.itemId)); }
  _canGear() { return GEAR_PHASES.includes(this.game.phase); }
  _items() { return this.game.items.filter(item => item.type === this.filter); }
  _choose(itemId) {
    const item = this.game.items.find(item => sameId(item.id, itemId)); if (!item) return;
    this.itemId = sameId(this.itemId, item.id) ? null : item.id; this.hoverCell = null; this.lastKey = ''; this.refresh();
    if (this.itemId !== null) this._focusSelection();
  }
  _focusSelection() {
    const item = this._item(); if (!item || this.drag) return;
    if (item.type === 'attachment') this.renderer.canvas.focus?.({ preventScroll: true });
    else if (!this.$('loadoutUse').disabled) this.$('loadoutUse').focus({ preventScroll: true });
    else [...this.$('loadoutCards').querySelectorAll('[data-loadout-item]')].find(button => sameId(button.dataset.loadoutItem, item.id))?.focus({ preventScroll: true });
  }
  _clearSelection() { this._cancelDrag(); this.itemId = null; this.hoverCell = null; this.lastKey = ''; this.refresh(); }
  _result(result) {
    if (result?.ok && !this._item()) this.itemId = null;
    this.lastKey = ''; this.refresh(); this.onChange?.(result);
    if (result?.message) this.$('loadoutHint').textContent = result.message;
    return result;
  }
  _equip(cell) {
    if (this.isBlocked()) return false;
    const item = this._item(); if (!item || item.type !== 'attachment') { this.refresh(); return false; }
    if (Number.isInteger(cell) && cell >= 0 && cell < 81) this.onSelectCell?.(cell);
    // The model revalidates phase, ownership, target, and capacity at release time.
    return this._result(this.game.equipItem(cell, item.id))?.ok || false;
  }
  handleCell(cell) {
    if (!this.visible) return false;
    if (this.isBlocked() || Date.now() < this.suppressClickUntil) return true;
    this.onSelectCell?.(cell);
    if (this._item()?.type === 'attachment') this._equip(cell);
    else { this.lastKey = ''; this.refresh(); }
    return true;
  }
  overlay() {
    const active = this.visible && !this.isBlocked(), selected = this._item()?.type === 'attachment';
    const towers = active && selected && this._canGear() ? this.game.towers : [];
    return { active, itemSelected: selected, validCells: towers.filter(t => t.attachments.length < 5).map(t => t.cell), fullCells: towers.filter(t => t.attachments.length >= 5).map(t => t.cell), hoverCell: this.hoverCell };
  }
  _click(event) {
    if (this.isBlocked()) return;
    const filter = event.target.closest('[data-loadout-filter]');
    if (filter) { this._cancelDrag(); this.filter = filter.dataset.loadoutFilter; this.itemId = null; this.lastKey = ''; this.refresh(); return; }
    const card = event.target.closest('[data-loadout-item], [data-loadout-drag]');
    if (card) { this._choose(card.dataset.loadoutItem ?? card.dataset.loadoutDrag); return; }
    const slot = event.target.closest('[data-loadout-slot]');
    if (slot && !slot.disabled) this._result(this.game.unequipItem(this.getSelectedCell(), Number(slot.dataset.loadoutSlot)));
  }
  _pointerDown(event) {
    if (!this.visible || this.isBlocked() || this.drag || event.isPrimary === false || (event.button !== undefined && event.button !== 0)) return;
    const handle = event.target.closest('[data-loadout-drag]'), card = event.target.closest('[data-loadout-item]');
    if (!handle && (!card || event.pointerType === 'touch' || event.pointerType === 'pen')) return;
    const id = handle?.dataset.loadoutDrag ?? card?.dataset.loadoutItem, item = this.game.items.find(item => sameId(item.id, id));
    if (!item || item.type !== 'attachment') return;
    this.drag = { pointerId: event.pointerId, id: item.id, item, x: event.clientX, y: event.clientY, active: false, previous: this.itemId };
    try { this.root.setPointerCapture?.(event.pointerId); } catch { /* DOM test and released pointers */ }
    if (handle) event.preventDefault();
  }
  _pointerMove(event) {
    const drag = this.drag; if (!drag || drag.pointerId !== event.pointerId) return;
    if (!this.visible || this.isBlocked()) { this._cancelDrag(); return; }
    if (!drag.active && Math.hypot(event.clientX - drag.x, event.clientY - drag.y) < 7) return;
    event.preventDefault();
    if (!drag.active) {
      const item = this.game.items.find(item => sameId(item.id, drag.id)); if (!item) { this._cancelDrag(); return; }
      drag.active = true; this.itemId = item.id;
      this.ghost = el('div', 'loadout-drag-ghost'); this.ghost.innerHTML = voxelArt(item.kind, { color: item.color, rarity: item.rarity });
      this.ghost.append(el('span', '', 'Choose a tower')); document.body.append(this.ghost); this.root.classList.add('dragging');
    }
    const cell = this._dropCell(event.clientX, event.clientY); this.hoverCell = cell;
    const tower = this._tower(cell), valid = this._canGear() && tower && tower.attachments.length < 5;
    this.ghost.style.transform = `translate(${event.clientX + 12}px, ${event.clientY - 76}px)`;
    this.ghost.classList.toggle('valid', !!valid);
    this.ghost.querySelector('span').textContent = !this._canGear() ? 'Equip in war prep' : !tower ? 'Drop on a planted tower' : valid ? `Attach · ${5 - tower.attachments.length} free` : 'Full · remove a module';
  }
  _dropCell(x, y) {
    const canvas = this.renderer.canvas, rect = canvas.getBoundingClientRect();
    if (x < rect.left || y < rect.top || x >= rect.right || y >= rect.bottom || rect.width <= 0 || rect.height <= 0) return null;
    const top = document.elementFromPoint?.(x, y); if (top && top !== canvas) return null;
    return this.renderer.towerAt?.(x, y) ?? this.renderer.cellAt(x, y);
  }
  _pointerUp(event) {
    const drag = this.drag; if (!drag || drag.pointerId !== event.pointerId) return;
    const active = drag.active, cell = active ? this._dropCell(event.clientX, event.clientY) : null;
    this.suppressClickUntil = Date.now() + 400; this._cancelDrag(false);
    if (!this.visible || this.isBlocked()) return;
    if (!this.game.items.includes(drag.item)) { this.itemId = null; this.lastKey = ''; this.refresh(); this.$('loadoutHint').textContent = 'That item is no longer in your bag.'; return; }
    if (!active) { this.itemId = drag.previous; this._choose(drag.id); return; }
    this.itemId = drag.id;
    if (cell === null) { this.lastKey = ''; this.refresh(); this.$('loadoutHint').textContent = 'Drop on a planted tower, or tap one with this item selected.'; return; }
    this._equip(cell);
  }
  _cancelDrag(refresh = true) {
    const drag = this.drag; this.drag = null; this.hoverCell = null;
    this.ghost?.remove(); this.ghost = null; this.root.classList.remove('dragging');
    if (drag) { try { this.root.releasePointerCapture?.(drag.pointerId); } catch { /* Pointer may already be released. */ } }
    if (drag && refresh) { this.lastKey = ''; this.refresh(); }
  }
  refresh() {
    if (!this.visible || this.drag) return;
    if (this.itemId !== null && !this._item()) this.itemId = null;
    const g = this.game, tower = this._tower(), selected = this._item();
    const key = JSON.stringify([g.items, tower, g.phase, g.credits, g.familyLevels, g.activeEffects, g.passives, g.health, this.itemId, this.filter, this.getSelectedCell()]);
    if (key === this.lastKey) return; this.lastKey = key;
    const cards = this.$('loadoutCards'), scroll = cards.scrollLeft;
    const focus = document.activeElement, focusedItem = focus?.dataset?.loadoutItem, focusedSlot = focus?.dataset?.loadoutSlot;
    cards.replaceChildren();
    for (const type of ['attachment', 'consumable']) {
      const tab = this.root.querySelector(`[data-loadout-filter="${type}"]`); tab.setAttribute('aria-selected', String(type === this.filter)); tab.querySelector('b').textContent = g.items.filter(item => item.type === type).length;
    }
    const items = this._items();
    for (const item of items) {
      const rarity = RARITIES.find(r => r.id === item.rarity), definition = ATTACHMENTS.find(a => a.id === item.kind), card = el('div', 'loadout-card');
      card.style.setProperty('--loot', rarity?.color || '#b7c7d9'); card.classList.toggle('selected', sameId(item.id, this.itemId));
      const button = el('button', 'loadout-select'); button.dataset.loadoutItem = item.id; button.setAttribute('aria-pressed', String(sameId(item.id, this.itemId))); button.title = `${item.name}\n${itemDescription(item)}`;
      const art = el('span', 'loadout-item-art'); art.innerHTML = voxelArt(item.kind, { color: item.color, rarity: item.rarity });
      const copy = el('span', 'loadout-item-copy'); copy.append(el('strong', '', briefEffect(item)), el('small', '', `${rarity?.name || item.rarity} · ${definition?.name || item.name}`)); button.append(art, copy); card.append(button);
      if (item.type === 'attachment') { const handle = el('button', 'loadout-drag', '⠿'); handle.dataset.loadoutDrag = item.id; handle.title = 'Drag to a tower (or tap to select)'; handle.setAttribute('aria-label', `Drag ${item.name} to a tower`); card.append(handle); }
      cards.append(card);
    }
    if (!items.length) cards.append(el('p', 'loadout-empty', this.filter === 'attachment' ? 'No spare modules. Open chests to find equipment, or tap a filled tower slot to return one.' : 'No boosts yet. Chests can contain temporary combat effects and healing.'));
    cards.scrollLeft = scroll;
    if (focusedItem !== undefined) [...cards.querySelectorAll('[data-loadout-item]')].find(button => sameId(button.dataset.loadoutItem, focusedItem))?.focus({ preventScroll: true });
    this._renderTarget(tower, selected);
    if (focusedSlot !== undefined) this.$('loadoutSlots').querySelector(`[data-loadout-slot="${focusedSlot}"]`)?.focus({ preventScroll: true });
    const hint = this.$('loadoutHint');
    hint.textContent = selected ? `${briefEffect(selected)} · ${selected.name} · ${itemDescription(selected)}` : this._canGear() ? 'Tap equipment → tap a tower. Or drag using ⠿. Filled slots return items.' : g.phase === 'battle' ? 'Gear changes in war prep. Select a boost, then press Use.' : 'Upgrades work now. Attach equipment after entering war prep.';
    hint.title = hint.textContent;
    const attach = this.$('loadoutEquip'), use = this.$('loadoutUse'), cancel = this.$('loadoutCancel');
    attach.hidden = selected?.type !== 'attachment' || !tower; attach.disabled = !this._canGear() || !tower || tower.attachments.length >= 5; attach.textContent = tower?.attachments.length >= 5 ? 'Full' : 'Attach';
    use.hidden = selected?.type !== 'consumable'; use.disabled = !selected || (selected.kind === 'repair' ? !ACTIVE_PHASES.includes(g.phase) || g.health >= g.maxHealth : g.phase !== 'battle'); use.title = selected?.kind === 'repair' && g.health >= g.maxHealth ? 'Core is already at full health' : g.phase !== 'battle' && selected?.kind !== 'repair' ? 'Available during battle' : 'Use this item';
    cancel.hidden = !selected;
  }
  _renderTarget(tower, selected) {
    const slots = this.$('loadoutSlots'); slots.replaceChildren();
    const stats = tower ? this.game.towerStats(tower) : null;
    this.$('loadoutTowerName').textContent = tower ? `Seed ${tower.number} · Lv ${stats.level} · ${location(tower.cell)}` : 'Tap a planted tower';
    let statText = tower ? `${number(stats.damage)} damage · ${number(stats.attackSpeed)}/s · ${number(stats.range)} range` : 'Choose a tower on the board.';
    if (tower && selected?.type === 'attachment' && tower.attachments.length < 5 && this._canGear()) {
      const next = this.game.towerStats({ ...tower, attachments: [...tower.attachments, selected] });
      const differences = [['damage', 'dmg'], ['attackSpeed', '/s'], ['range', 'range']].filter(([key]) => Math.abs(next[key] - stats[key]) > .00001).map(([key, label]) => `${number(stats[key])}→${number(next[key])} ${label}`);
      statText = differences.length ? differences.join(' · ') : `${statText} · +${selected.kind} effect`;
    }
    this.$('loadoutTowerStats').textContent = statText; this.$('loadoutTowerStats').title = statText;
    for (let index = 0; index < 5; index++) {
      const item = tower?.attachments[index], button = el('button', `loadout-slot${item ? ' filled' : ''}`); button.dataset.loadoutSlot = index;
      if (item) { button.innerHTML = voxelArt(item.kind, { color: item.color, rarity: item.rarity }); button.style.setProperty('--loot', item.color || '#8ee6c0'); }
      else button.textContent = '+';
      button.disabled = !item || !this._canGear(); button.title = item ? `${item.name} · Tap to return to bag${!this._canGear() ? ' during war prep' : ''}` : `Empty attachment slot ${index + 1}`;
      button.setAttribute('aria-label', button.title); slots.append(button);
    }
    const one = this.$('loadoutUpgradeTower'), all = this.$('loadoutUpgradeFamily');
    const cost = tower ? this.game.upgradeCost(tower.cell) : 0, familyCost = tower ? this.game.familyUpgradeCost(tower.number) : 0;
    one.replaceChildren(el('strong', '', tower ? `This tower → Lv ${stats.level + 1}` : 'This tower'), el('small', '', tower ? `ϟ ${cost} · this map` : 'Select a tower'));
    all.replaceChildren(el('strong', '', tower ? `All ${tower.number}s → Lv ${this.game.familyLevels[tower.number] + 1}` : 'All numbers'), el('small', '', tower ? `ϟ ${familyCost} · whole run` : 'Select a tower'));
    one.disabled = !tower || !ACTIVE_PHASES.includes(this.game.phase) || this.game.credits < cost;
    all.disabled = !tower || !ACTIVE_PHASES.includes(this.game.phase) || this.game.credits < familyCost;
    one.title = tower ? `Upgrade only this tower to effective level ${stats.level + 1}. Costs ${cost} credits. Lasts this map.` : 'Select a planted tower';
    all.title = tower ? `Raise family level to ${this.game.familyLevels[tower.number] + 1} for all current and future ${tower.number} towers. Costs ${familyCost} credits. Lasts the whole run.` : 'Select a planted tower';
  }
  handleController(action, dx = 0, dy = 0) {
    if (!this.visible) return false;
    if (action === 'back' || action === 'cancel') { if (this.drag || this.itemId !== null) this._clearSelection(); else this.close(true); return true; }
    if (this.isBlocked()) return true;
    if (action === 'number' || action === 'item') {
      const items = this._items(); if (items.length) { const index = items.findIndex(item => sameId(item.id, this.itemId)); this.itemId = items[index < 0 ? (dx < 0 ? items.length - 1 : 0) : (index + (dx < 0 ? -1 : 1) + items.length) % items.length].id; this.lastKey = ''; this.refresh(); this._focusSelection(); }
      return true;
    }
    if (action === 'move') {
      if (this._item()?.type === 'attachment') {
        const towers = [...this.game.towers].sort((a, b) => a.cell - b.cell), index = towers.findIndex(t => t.cell === this.getSelectedCell());
        if (towers.length) { const tower = towers[index < 0 ? ((dx || dy) < 0 ? towers.length - 1 : 0) : (index + ((dx || dy) < 0 ? -1 : 1) + towers.length) % towers.length]; this.onSelectCell?.(tower.cell); this.hoverCell = tower.cell; this.lastKey = ''; this.refresh(); this.renderer.canvas.focus?.({ preventScroll: true }); }
      } else {
        const targets = [...this.root.querySelectorAll('button:not([disabled])')].filter(button => !button.closest('[hidden]'));
        const index = targets.indexOf(document.activeElement); targets[(index + ((dx || dy) < 0 ? -1 : 1) + targets.length) % targets.length]?.focus({ preventScroll: true });
        document.activeElement?.closest('.loadout-card')?.scrollIntoView?.({ block: 'nearest', inline: 'nearest' });
      }
      return true;
    }
    if (['place', 'confirm', 'select'].includes(action)) {
      if (this._item()?.type === 'attachment') this._equip(this.getSelectedCell());
      else if (this.root.contains(document.activeElement)) document.activeElement.click();
      else this.root.querySelector('[data-loadout-item]')?.focus({ preventScroll: true });
      return true;
    }
    return true;
  }
}
