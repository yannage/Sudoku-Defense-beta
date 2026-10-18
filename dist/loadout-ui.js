import { itemGuide, towerBuild } from './game/item-guide.js';
import { voxelArt } from './voxel-art.js';

const GEAR_PHASES = ['prep', 'loot', 'won'];
const ACTIVE_PHASES = ['solve', 'prep', 'battle', 'loot'];
const sameId = (a, b) => String(a) === String(b);
const el = (tag, className, text) => { const node = document.createElement(tag); if (className) node.className = className; if (text !== undefined) node.textContent = text; return node; };
const number = value => Number(value || 0).toFixed(1).replace(/\.0$/, '');
const location = cell => `R${Math.floor(cell / 9) + 1} · C${cell % 9 + 1}`;

/** A board-adjacent kit: every mutation stays in Game; pointer drags are previews until release. */
export class LoadoutTray {
  constructor({ game, renderer, getSelectedCell, onSelectCell, onChange, onClose, onLibrary, isBlocked = () => false, onFeedback = () => {}, isReducedMotion = () => false }) {
    Object.assign(this, { game, renderer, getSelectedCell, onSelectCell, onChange, onClose, onLibrary, isBlocked, onFeedback, isReducedMotion });
    this.visible = false; this.filter = 'attachment'; this.itemId = null; this.drag = null; this.hoverCell = null; this.lastKey = ''; this.suppressClickUntil = 0; this.fx = new Set(); this.hoverTarget = null;
    this.root = el('section', 'loadout-tray'); this.root.id = 'loadoutTray'; this.root.hidden = true; this.root.setAttribute('aria-label', 'Tower equipment tray');
    this.root.innerHTML = `<div class="loadout-head"><div class="loadout-tabs" role="tablist" aria-label="Item type"><button id="loadoutEquipment" role="tab" data-loadout-filter="attachment">Gear <b></b></button><button id="loadoutBoosts" role="tab" data-loadout-filter="consumable">Boosts <b></b></button></div><span class="loadout-held">TIME HELD</span><button id="loadoutLibrary" class="loadout-library" title="Open full inventory">Details ↗</button><button id="loadoutClose" class="loadout-close" aria-label="Close equipment tray">×</button></div><div id="loadoutCards" class="loadout-cards" aria-label="Bag: available items; drop equipped gear here to return it"></div><div class="loadout-preview"><span id="loadoutHint" role="status" aria-live="polite"></span><button id="loadoutEquip" hidden>Attach</button><button id="loadoutUse" hidden>Use boost</button><button id="loadoutCancel" hidden aria-label="Cancel selected attachment">Cancel</button></div><div id="loadoutTarget" class="loadout-target"><div class="loadout-tower-info"><strong id="loadoutTowerName">Tap a planted tower</strong><small id="loadoutTowerStats">Select a tower to inspect or upgrade it.</small></div><div id="loadoutSlots" class="loadout-slots" aria-label="Five attachment slots"></div><button id="loadoutUpgradeTower" class="loadout-upgrade" disabled></button><button id="loadoutUpgradeFamily" class="loadout-upgrade family" disabled></button></div>`;
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
    document.addEventListener('visibilitychange', () => { if (document.hidden) { this._cancelDrag(); this._clearEffects(); this.itemId = null; this.lastKey = ''; } });
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
    this._cancelDrag(); this._clearEffects(); this.visible = false; this.itemId = null; this.hoverCell = null; this.root.hidden = true;
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
    const result = this.game.equipItem(cell, item.id);
    this._feedback(result?.ok ? 'gearLand' : 'gearReject', item, { cell, operation: 'attach' });
    if (result?.ok) this._pop(this._towerPoint(cell), item);
    return this._result(result)?.ok || false;
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
    const active = this.visible && !this.isBlocked(), selected = this.drag?.active || this._item()?.type === 'attachment';
    const towers = active && selected && this._canGear() ? this.game.towers : [];
    return { active, itemSelected: selected, validCells: towers.filter(t => t.attachments.length < 5 && t.cell !== this.drag?.sourceCell).map(t => t.cell), fullCells: towers.filter(t => t.attachments.length >= 5).map(t => t.cell), hoverCell: this.hoverCell, dragActive: !!this.drag?.active, dragKind: this.drag?.item.kind, color: this.drag ? itemGuide(this.drag.item).color : null, sourceCell: this.drag?.sourceCell };
  }
  _click(event) {
    if (this.isBlocked()) return;
    const filter = event.target.closest('[data-loadout-filter]');
    if (filter) { this._cancelDrag(); this.filter = filter.dataset.loadoutFilter; this.itemId = null; this.lastKey = ''; this.refresh(); return; }
    const card = event.target.closest('[data-loadout-item], [data-loadout-drag]');
    if (card) { this._choose(card.dataset.loadoutItem ?? card.dataset.loadoutDrag); return; }
    const slot = event.target.closest('[data-loadout-slot]');
    if (slot && !slot.disabled) this._slotAction(Number(slot.dataset.cell), Number(slot.dataset.loadoutSlot), slot.dataset.itemId);
  }
  _slotAction(cell, index, expectedItemId) {
    const item = this._tower(cell)?.attachments[index];
    if (!item || (expectedItemId !== undefined && !sameId(item.id, expectedItemId))) return this._result({ ok: false, message: 'That slot changed. Choose it again.' });
    const result = this.game.unequipItem(cell, index);
    this._feedback(result?.ok ? 'gearReturn' : 'gearReject', item, { cell, operation: 'return' });
    if (result?.ok) this._pop(this._nodePoint(this.$('loadoutCards')), item);
    return this._result(result);
  }
  _reduced() { return this.isReducedMotion() || (typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches); }
  _feedback(type, item, extra = {}) { this.onFeedback?.(type, { kind: item?.kind, color: itemGuide(item).color, rarity: item?.rarity, ...extra }); }
  _nodePoint(node) {
    const rect = node?.getBoundingClientRect?.();
    return rect?.width ? { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 } : null;
  }
  _towerPoint(cell) {
    if (!Number.isInteger(cell)) return null;
    if (this.renderer.attachmentDropPoint) return this.renderer.attachmentDropPoint(cell);
    const tower = this._tower(cell), point = this.renderer._project?.(cell % 9, Math.floor(cell / 9), tower ? .8 + .13 * tower.attachments.length : 0), rect = this.renderer.canvas.getBoundingClientRect();
    return point ? { x: rect.left + point.x * rect.width / this.renderer.w, y: rect.top + point.y * rect.height / this.renderer.h } : null;
  }
  _animate(node, frames, options) {
    if (this._reduced() || typeof node.animate !== 'function') { node.remove(); return; }
    while (this.fx.size >= 16) { const oldest = this.fx.values().next().value; oldest.animation?.cancel(); oldest.remove(); this.fx.delete(oldest); }
    this.fx.add(node);
    const animation = node.animate(frames, { fill: 'forwards', ...options }); node.animation = animation;
    const cleanup = () => { node.remove(); this.fx.delete(node); };
    animation.onfinish = cleanup; animation.oncancel = cleanup;
  }
  _clearEffects() { for (const node of [...this.fx]) { node.animation?.cancel(); node.remove(); } this.fx.clear(); }
  _pop(point, item) {
    if (!point || this._reduced() || !this.visible) return;
    const ring = el('div', 'loadout-land-pop'); ring.style.setProperty('--loot', itemGuide(item).color); ring.style.left = `${point.x}px`; ring.style.top = `${point.y}px`; document.body.append(ring);
    this._animate(ring, [{ transform: 'translate(-50%,-50%) scale(.3)', opacity: 1 }, { transform: 'translate(-50%,-50%) scale(1.5)', opacity: 0 }], { duration: 330, easing: 'cubic-bezier(.2,.7,.3,1)' });
  }
  _trail(x, y, drag) {
    if (this._reduced() || Date.now() - (drag.lastTrail || 0) < 65 || this.fx.size >= 9) return;
    drag.lastTrail = Date.now();
    const mote = el('i', 'loadout-drag-mote'); mote.style.setProperty('--loot', itemGuide(drag.item).color); mote.style.left = `${x}px`; mote.style.top = `${y - 22}px`; document.body.append(mote);
    this._animate(mote, [{ transform: 'translate(-50%,-50%) rotate(45deg) scale(1)', opacity: .8 }, { transform: 'translate(-50%,12px) rotate(90deg) scale(.1)', opacity: 0 }], { duration: 300, easing: 'ease-out' });
  }
  _ownsDrag(drag) {
    return drag.sourceCell === undefined ? this.game.items.includes(drag.item) : this._tower(drag.sourceCell)?.attachments[drag.slotIndex] === drag.item;
  }
  _pointerDown(event) {
    if (!this.visible || this.isBlocked() || this.drag || event.isPrimary === false || (event.button !== undefined && event.button !== 0)) return;
    const slot = event.target.closest('[data-loadout-slot]'), handle = event.target.closest('[data-loadout-drag]'), card = event.target.closest('[data-loadout-item]');
    if (!slot && !handle && (!card || event.pointerType === 'touch' || event.pointerType === 'pen')) return;
    if (slot?.disabled) return;
    const sourceCell = slot ? Number(slot.dataset.cell) : undefined, slotIndex = slot ? Number(slot.dataset.loadoutSlot) : undefined;
    const id = handle?.dataset.loadoutDrag ?? card?.dataset.loadoutItem;
    const item = slot ? this._tower(sourceCell)?.attachments[slotIndex] : this.game.items.find(item => sameId(item.id, id));
    if (!item || item.type !== 'attachment') return;
    this.drag = { pointerId: event.pointerId, id: item.id, item, sourceCell, slotIndex, x: event.clientX, y: event.clientY, lastX: event.clientX, active: false, previous: this.itemId, phase: this.game.phase, sourceNode: slot || card?.closest('.loadout-card') || handle?.closest('.loadout-card') };
    try { this.root.setPointerCapture?.(event.pointerId); } catch { /* Pointer may already be released. */ }
    if (handle || slot) event.preventDefault();
  }
  _pointerMove(event) {
    const drag = this.drag; if (!drag || drag.pointerId !== event.pointerId) return;
    if (!this.visible || this.isBlocked() || !this._ownsDrag(drag) || drag.phase !== this.game.phase) { this._cancelDrag(); return; }
    if (!drag.active && Math.hypot(event.clientX - drag.x, event.clientY - drag.y) < 7) return;
    event.preventDefault();
    if (!drag.active) {
      drag.active = true; this.itemId = drag.sourceCell === undefined ? drag.id : null;
      this.ghost = el('div', 'loadout-drag-ghost'); this.ghost.style.setProperty('--loot', itemGuide(drag.item).color); this.ghost.innerHTML = voxelArt(drag.item.kind, { color: drag.item.color, rarity: drag.item.rarity });
      this.ghost.append(el('span', '', 'Choose a tower')); document.body.append(this.ghost); this.root.classList.add('dragging'); drag.sourceNode?.classList.add('drag-source');
      this._feedback('gearLift', drag.item, { cell: drag.sourceCell, operation: drag.sourceCell === undefined ? 'attach' : 'move' });
    }
    const target = this._dropTarget(event.clientX, event.clientY, drag); this.hoverTarget = target; this.hoverCell = target.cell ?? null;
    this._markTarget(target);
    const key = `${target.operation}:${target.cell}:${target.slotIndex}:${target.valid}`;
    if (key !== drag.hoverKey) { drag.hoverKey = key; if (target.valid) this._feedback('gearHover', drag.item, { cell: target.cell, operation: target.operation }); }
    const tilt = this._reduced() ? 0 : Math.max(-10, Math.min(10, (event.clientX - drag.lastX) * .4)); drag.lastX = event.clientX;
    const anchor = target.valid ? this._targetPoint(target) : null;
    const magnet = anchor && Math.hypot(anchor.x - event.clientX, anchor.y - event.clientY) < 75 ? .18 : 0;
    const x = event.clientX + (anchor ? (anchor.x - event.clientX) * magnet : 0), y = event.clientY + (anchor ? (anchor.y - event.clientY) * magnet : 0);
    this.ghost.style.transform = `translate(${x + 10}px, ${y - 76}px) rotate(${tilt}deg)`;
    this.ghost.classList.toggle('valid', !!target.valid); this.ghost.classList.toggle('invalid', !target.valid);
    this.ghost.querySelector('span').textContent = target.message;
    this._trail(event.clientX, event.clientY, drag);
  }
  _markTarget(target) {
    this.root.querySelectorAll('.drop-ready, .drop-replace').forEach(node => node.classList.remove('drop-ready', 'drop-replace'));
    this.root.classList.toggle('returning-gear', target.operation === 'return');
    if (target.valid && target.node) target.node.classList.add(target.operation === 'swap' ? 'drop-replace' : 'drop-ready');
  }
  _dropTarget(x, y, drag) {
    const top = document.elementFromPoint?.(x, y), slot = top?.closest?.('[data-loadout-slot]');
    if (!this._canGear()) return { valid: false, message: 'Gear changes in War Prep' };
    if (slot && this.root.contains(slot)) {
      const cell = Number(slot.dataset.cell), index = Number(slot.dataset.loadoutSlot), tower = this._tower(cell), old = tower?.attachments[index];
      if (drag.sourceCell !== undefined) return { valid: false, message: 'Drop on another tower or into Bag' };
      if (!tower) return { valid: false, message: 'Select a planted tower first' };
      if (slot.dataset.itemId !== undefined && !sameId(old?.id, slot.dataset.itemId)) return { valid: false, message: 'That slot changed. Try again.' };
      return { valid: true, operation: old ? 'swap' : 'attach', cell, slotIndex: index, expectedItemId: old?.id, node: slot, message: old ? `Swap ${itemGuide(old).name} → Bag` : 'Snap into tower' };
    }
    const bag = top?.closest?.('#loadoutCards, #loadoutEquipment');
    if (bag && this.root.contains(bag) && drag.sourceCell !== undefined) return { valid: true, operation: 'return', node: bag, message: 'Return to Bag · keep this gear' };
    const cell = this._dropCell(x, y), tower = this._tower(cell);
    if (!tower) return { valid: false, cell, message: drag.sourceCell === undefined ? 'Drop on a planted tower' : 'Drop on another tower or into Bag' };
    if (cell === drag.sourceCell) return { valid: false, cell, message: 'Already on this tower' };
    if (tower.attachments.length >= 5) return { valid: false, cell, message: '5/5 full · use a slot to swap' };
    return { valid: true, cell, operation: drag.sourceCell === undefined ? 'attach' : 'move', message: `Snap on · ${tower.attachments.length + 1}/5 slots` };
  }
  _targetPoint(target) { return target.node ? this._nodePoint(target.node) : this._towerPoint(target.cell); }
  _dropCell(x, y) {
    const canvas = this.renderer.canvas, rect = canvas.getBoundingClientRect();
    if (x < rect.left || y < rect.top || x >= rect.right || y >= rect.bottom || rect.width <= 0 || rect.height <= 0) return null;
    const top = document.elementFromPoint?.(x, y); if (top && top !== canvas) return null;
    return this.renderer.towerAt?.(x, y) ?? this.renderer.cellAt(x, y);
  }
  _finishGhost(drag, point, ok) {
    const ghost = this.ghost; if (!ghost) return; this.ghost = null;
    ghost.className = 'loadout-flight'; ghost.querySelector('span')?.remove();
    const endpoint = ok && point ? point : { x: drag.x, y: drag.y };
    this._animate(ghost, [{ transform: ghost.style.transform, opacity: 1 }, { transform: `translate(${endpoint.x - 27}px, ${endpoint.y - 27}px) scale(${ok ? .25 : .75}) rotate(${ok ? 9 : -5}deg)`, opacity: 0 }], { duration: ok ? 210 : 290, easing: ok ? 'cubic-bezier(.3,.8,.2,1)' : 'cubic-bezier(.35,1.5,.65,1)' });
  }
  _pointerUp(event) {
    const drag = this.drag; if (!drag || drag.pointerId !== event.pointerId) return;
    const active = drag.active, target = active ? this._dropTarget(event.clientX, event.clientY, drag) : null;
    const safe = this.visible && !this.isBlocked() && this._ownsDrag(drag) && drag.phase === this.game.phase;
    this.suppressClickUntil = Date.now() + 400;
    if (!active) {
      this._cancelDrag(false);
      if (!safe) { this.lastKey = ''; this.refresh(); return; }
      if (drag.sourceCell !== undefined) this._slotAction(drag.sourceCell, drag.slotIndex, drag.id);
      else { this.itemId = drag.previous; this._choose(drag.id); }
      return;
    }
    let result;
    if (!safe) result = { ok: false, message: 'That item changed. Your gear stayed where it belongs.' };
    else if (!target?.valid) result = { ok: false, message: target?.message || 'Drop on a planted tower.' };
    else if (target.operation === 'return') result = this.game.unequipItem(drag.sourceCell, drag.slotIndex);
    else if (target.operation === 'move') result = this.game.moveAttachment(drag.sourceCell, drag.slotIndex, target.cell, drag.id);
    else if (target.operation === 'swap') result = this.game.swapAttachment(target.cell, target.slotIndex, drag.id, target.expectedItemId);
    else result = this.game.equipItem(target.cell, drag.id);
    const point = target ? this._targetPoint(target) : null;
    this._finishGhost(drag, point, result?.ok); this._cancelDrag(false);
    if (!this.visible) return;
    if (result?.ok) {
      this.itemId = null;
      if (Number.isInteger(target?.cell)) this.onSelectCell?.(target.cell);
      this._pop(point, drag.item);
    }
    this._feedback(result?.ok ? (target.operation === 'return' ? 'gearReturn' : 'gearLand') : 'gearReject', drag.item, { cell: target?.cell, operation: target?.operation });
    this._result(result);
  }
  _cancelDrag(refresh = true) {
    const drag = this.drag; this.drag = null; this.hoverCell = null; this.hoverTarget = null;
    this.ghost?.remove(); this.ghost = null; this.root.classList.remove('dragging', 'returning-gear');
    this.root.querySelectorAll('.drag-source, .drop-ready, .drop-replace').forEach(node => node.classList.remove('drag-source', 'drop-ready', 'drop-replace'));
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
      const guide = itemGuide(item), card = el('div', 'loadout-card');
      card.style.setProperty('--loot', guide.color); card.classList.toggle('selected', sameId(item.id, this.itemId));
      const button = el('button', 'loadout-select'); button.dataset.loadoutItem = item.id; button.setAttribute('aria-pressed', String(sameId(item.id, this.itemId))); button.title = `${guide.name} · ${guide.rarityName}\n${guide.effect}\n${guide.purpose}\n${guide.lifetime}\n${item.name}`;
      const art = el('span', 'loadout-item-art'); art.innerHTML = voxelArt(item.kind, { color: item.color, rarity: item.rarity });
      const copy = el('span', 'loadout-item-copy'); copy.append(el('strong', '', guide.name), el('small', 'loadout-effect', guide.effect), el('small', 'loadout-rarity', guide.rarityName)); button.append(art, copy); card.append(button);
      if (item.type === 'attachment') { const handle = el('button', 'loadout-drag', '⠿'); handle.dataset.loadoutDrag = item.id; handle.title = 'Drag to a tower (or tap to select)'; handle.setAttribute('aria-label', `Drag ${guide.name} to a tower`); card.append(handle); }
      cards.append(card);
    }
    if (!items.length) cards.append(el('p', 'loadout-empty', this.filter === 'attachment' ? 'Your spare gear goes here. Open chests to find more; drag a filled tower slot here to keep it in your Bag.' : 'One-use boosts go here. Find them in chests, then use them when you need an edge.'));
    cards.scrollLeft = scroll;
    if (focusedItem !== undefined) [...cards.querySelectorAll('[data-loadout-item]')].find(button => sameId(button.dataset.loadoutItem, focusedItem))?.focus({ preventScroll: true });
    this._renderTarget(tower, selected);
    if (focusedSlot !== undefined) this.$('loadoutSlots').querySelector(`[data-loadout-slot="${focusedSlot}"]`)?.focus({ preventScroll: true });
    const hint = this.$('loadoutHint');
    const guide = selected ? itemGuide(selected) : null;
    hint.textContent = guide ? `${guide.effect} · ${guide.pairWith || guide.purpose}` : this._canGear() ? 'Drag gear to a tower. Drag a filled slot to move it; return it here to Bag.' : g.phase === 'battle' ? 'Gear changes in War Prep. Boosts are one use: choose one, then Use.' : 'Plant towers now. In War Prep, drag gear onto them.';
    hint.title = guide ? `${guide.effect} ${guide.purpose} ${guide.stack} ${guide.lifetime}` : hint.textContent;
    const attach = this.$('loadoutEquip'), use = this.$('loadoutUse'), cancel = this.$('loadoutCancel');
    attach.hidden = selected?.type !== 'attachment' || !tower; attach.disabled = !this._canGear() || !tower || tower.attachments.length >= 5; attach.textContent = tower?.attachments.length >= 5 ? '5/5 full' : 'Attach';
    use.hidden = selected?.type !== 'consumable'; use.disabled = !selected || (selected.kind === 'repair' ? !ACTIVE_PHASES.includes(g.phase) || g.health >= g.maxHealth : g.phase !== 'battle'); use.title = selected?.kind === 'repair' && g.health >= g.maxHealth ? 'Core is already at full health' : g.phase !== 'battle' && selected?.kind !== 'repair' ? 'Available during battle' : 'Use this item';
    cancel.hidden = !selected;
  }
  _renderTarget(tower, selected) {
    const slots = this.$('loadoutSlots'); slots.replaceChildren();
    const stats = tower ? this.game.towerStats(tower) : null;
    const build = tower ? towerBuild(tower) : null;
    this.$('loadoutTowerName').textContent = tower ? `${tower.number} · ${build.name} · Lv ${stats.level} · ${tower.attachments.length}/5` : 'Tap a planted tower';
    this.$('loadoutTowerName').title = tower ? `${location(tower.cell)} · ${build.summary}` : '';
    let statText = tower ? `${number(stats.damage)} dmg · ${number(stats.attackSpeed)}/s · ${number(stats.range)} range` : 'Choose a tower on the board.';
    if (tower && selected?.type === 'attachment' && tower.attachments.length < 5 && this._canGear()) {
      const next = this.game.towerStats({ ...tower, attachments: [...tower.attachments, selected] });
      const differences = [['damage', 'dmg'], ['attackSpeed', '/s'], ['range', 'range']].filter(([key]) => Math.abs(next[key] - stats[key]) > .00001).map(([key, label]) => `${number(stats[key])}→${number(next[key])} ${label}`);
      statText = differences.length ? differences.join(' · ') : itemGuide(selected).effect;
      const nextBuild = towerBuild({ ...tower, attachments: [...tower.attachments, selected] });
      this.$('loadoutTowerName').textContent = `${tower.number} · ${nextBuild.name} · ${tower.attachments.length}→${tower.attachments.length + 1}/5`;
    }
    this.$('loadoutTowerStats').textContent = statText; this.$('loadoutTowerStats').title = statText;
    for (let index = 0; index < 5; index++) {
      const item = tower?.attachments[index], button = el('button', `loadout-slot${item ? ' filled' : ''}`); button.dataset.loadoutSlot = index; if (tower) button.dataset.cell = tower.cell; if (item) button.dataset.itemId = item.id;
      if (item) { button.innerHTML = voxelArt(item.kind, { color: item.color, rarity: item.rarity }); button.style.setProperty('--loot', itemGuide(item).color); }
      else button.textContent = '+';
      button.disabled = !item || !this._canGear(); button.title = item ? `${itemGuide(item).name} · ${itemGuide(item).effect}. Drag to move; tap to return to Bag${!this._canGear() ? ' during War Prep' : ''}. Drop spare gear here to swap.` : `Empty attachment slot ${index + 1}`;
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
      if (document.activeElement?.dataset?.loadoutSlot !== undefined && this.root.contains(document.activeElement)) document.activeElement.click();
      else if (this._item()?.type === 'attachment') this._equip(this.getSelectedCell());
      else if (this.root.contains(document.activeElement)) document.activeElement.click();
      else this.root.querySelector('[data-loadout-item]')?.focus({ preventScroll: true });
      return true;
    }
    return true;
  }
}
