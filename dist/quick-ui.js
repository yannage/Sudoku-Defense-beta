import { RARITIES } from './game/items.js';
import { voxelArt } from './voxel-art.js';
const $ = id => document.getElementById(id);
const artKinds = { tower: 'tower', inventory: 'bag', chests: 'chest', notes: 'notes', more: 'settings' };
const titles = { tower: 'Tower workshop', inventory: 'Your field kit', chests: 'Sealed chests', notes: 'Sudoku notes', more: 'Run & settings' };

/** Lightweight, mutually exclusive panels. Opening one holds the game clock. */
export class QuickBar {
  constructor({ game, onOpen, onToggle = () => {} }) {
    this.game = game; this.onOpen = onOpen; this.onToggle = onToggle;
    this.view = null; this.lastKey = '';
    this.buttons = [...document.querySelectorAll('[data-quick]')];
    for (const button of this.buttons) {
      button.querySelector('.quick-icon').innerHTML = voxelArt(artKinds[button.dataset.quick]);
      button.addEventListener('click', () => this.toggle(button.dataset.quick));
    }
    for (const element of document.querySelectorAll('[data-voxel]')) element.innerHTML = voxelArt(element.dataset.voxel);
    $('closeQuickPanel').addEventListener('click', () => this.close(true));
  }
  isOpen() { return this.view !== null; }
  toggle(view) { if (view === this.view) this.close(true); else this.open(view); }
  open(view) {
    if (!titles[view]) return;
    this.view = view; this.lastKey = '';
    $('quickPanelArt').innerHTML = voxelArt(artKinds[view]);
    $('quickPanel').hidden = false; $('quickPanelTitle').textContent = titles[view];
    for (const panel of document.querySelectorAll('[data-quick-view]')) panel.hidden = panel.dataset.quickView !== view;
    this._state(); this.refresh(); this.onToggle(true);
    // The close control is first in the pane and always visible to keyboard users.
    $('closeQuickPanel').focus({ preventScroll: true });
  }
  close(restoreFocus = false) {
    const previous = this.view;
    this.view = null; $('quickPanel').hidden = true;
    for (const panel of document.querySelectorAll('[data-quick-view]')) panel.hidden = true;
    this._state();
    if (previous) this.onToggle(false);
    if (restoreFocus) this.buttons.find(button => button.dataset.quick === previous)?.focus({ preventScroll: true });
  }
  _state() {
    $('app').classList.toggle('panel-open', this.isOpen());
    $('menuHold').hidden = !this.isOpen();
    for (const button of this.buttons) {
      const active = button.dataset.quick === this.view;
      button.setAttribute('aria-expanded', String(active)); button.classList.toggle('active', active);
    }
  }
  refresh() {
    if (!this.isOpen()) return;
    const g = this.game;
    const key = JSON.stringify([this.view, g.items, g.chests, g.fragments, g.phase]);
    if (key === this.lastKey) return;
    this.lastKey = key;
    if (this.view === 'inventory') {
      const gear = g.items.filter(i => i.type === 'attachment').length;
      const boosts = g.items.length - gear;
      $('quickBagSummary').textContent = `${gear} attachment${gear === 1 ? '' : 's'} · ${boosts} consumable${boosts === 1 ? '' : 's'}. ${g.phase === 'battle' ? 'Use a boost to turn the battle.' : 'Equip attachments during war prep.'}`;
      const list = $('quickItems'); list.replaceChildren();
      const items = [...g.items].sort((a,b) => (g.phase === 'battle' ? Number(b.type === 'consumable') - Number(a.type === 'consumable') : 0));
      for (const item of items.slice(0, 3)) {
        const r = RARITIES.find(r => r.id === item.rarity);
        const button = document.createElement('button'); button.className = 'quick-item';
        button.style.setProperty('--loot', r?.color || '#aabdc5');
        const type = document.createElement('small'); type.textContent = `${r?.name || item.rarity} · ${item.type}`;
        const name = document.createElement('strong'); name.textContent = item.name;
        const art = document.createElement('span'); art.className = 'quick-item-art'; art.innerHTML = voxelArt(item.kind, { color: item.color || r?.color, rarity: item.rarity });
        const copy = document.createElement('span'); copy.className = 'quick-item-copy'; copy.append(type, name);
        button.append(art, copy); button.onclick = () => this.onOpen('inventory', item.id); list.append(button);
      }
      if (!items.length) this.empty(list, 'Your next find is out there.', 'Defeat enemies for sealed chests. Their loot becomes your equipment.');
      $('inventoryBtn').firstChild.textContent = items.length > 3 ? `See all ${items.length} items ` : 'Manage inventory ';
    }
    if (this.view === 'chests') {
      const allowed = ['prep', 'loot', 'won'].includes(g.phase);
      $('quickChestSummary').textContent = `${g.chests.length} sealed · ${g.fragments} fragments. ${allowed ? 'Choose a chest to view its lock and rewards.' : 'Open your finds in war prep or loot camp.'}`;
      const list = $('quickChests'); list.replaceChildren();
      for (const chest of g.chests.slice(0, 3)) {
        const r = RARITIES.find(r => r.id === chest.rarity), cost = chest.cost ?? r?.fragmentCost ?? 5;
        const button = document.createElement('button'); button.className = 'quick-item'; button.style.setProperty('--loot', r?.color || '#aabdc5');
        const name = document.createElement('strong'); name.textContent = `${r?.name || chest.rarity} cache`;
        const desc = document.createElement('small'); desc.textContent = `◈ ${cost} to unlock · ${g.fragments < cost ? `${cost - g.fragments} more needed` : allowed ? 'Ready to open' : 'Wait for prep / camp'}`;
        const art = document.createElement('span'); art.className = 'quick-item-art chest'; art.innerHTML = voxelArt('chest', { rarity: chest.rarity });
        const copy = document.createElement('span'); copy.className = 'quick-item-copy'; copy.append(name, desc);
        button.append(art, copy); button.onclick = () => this.onOpen('chests'); list.append(button);
      }
      if (!g.chests.length) this.empty(list, 'No sealed chests yet.', 'Enemies drop chests and energy fragments. Survive a siege to claim your spoils.');
    }
  }
  empty(parent, title, description) {
    const element = document.createElement('div'); element.className = 'quick-empty';
    const art = document.createElement('span'); art.className = 'quick-empty-art'; art.innerHTML = voxelArt(this.view === 'chests' ? 'chest' : 'bag');
    element.append(art);
    const strong = document.createElement('strong'); strong.textContent = title;
    const copy = document.createElement('p'); copy.textContent = description; element.append(strong, copy); parent.append(element);
  }
  moveFocus(direction) {
    const targets = [...$('quickPanel').querySelectorAll('button:not([disabled]),select')].filter(el => !el.closest('[hidden]'));
    const index = targets.indexOf(document.activeElement);
    targets[(index + (direction < 0 ? -1 : 1) + targets.length) % targets.length]?.focus({ preventScroll: true });
  }
}
