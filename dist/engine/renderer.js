/**
 * GRIDFALL / voxel canvas renderer
 * A dependency-free, resolution-independent presentation layer. The simulation
 * owns the state; this module owns projection, picking, and short-lived FX.
 */
const PALETTE = ['#6de8ff', '#a4c7ff', '#c6a0ff', '#ffae68', '#fb86c3', '#9be878', '#ffe188', '#bb9bff', '#ff7289'];
// Digits identify families. Equipment, never the digit, defines a weapon's FX.
const MODULES = {
  rapid: { color: '#6de8ff', glyph: '»' }, electric: { color: '#c6a0ff', glyph: 'ϟ' },
  frost: { color: '#a4c7ff', glyph: '❄' }, blast: { color: '#ffae68', glyph: '✹' },
  venom: { color: '#9be878', glyph: '●' }, range: { color: '#ffe188', glyph: '⊕' },
  power: { color: '#fb86c3', glyph: '+' }, gravity: { color: '#bb9bff', glyph: '◉' },
  nova: { color: '#ff7289', glyph: '✦' }
};
const RARITY_COLORS = { common: '#c4d2da', uncommon: '#8ee8a5', rare: '#78b6ff', epic: '#ca91ff', legendary: '#ffcb6b' };
const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const lerp = (a, b, t) => a + (b - a) * t;
const ease = t => t * t * (3 - 2 * t);
const finite = (v, fallback = 0) => Number.isFinite(v) ? v : fallback;
// World-plane headings are independent of the flat/isometric camera morph.
export function towerAimAngle(x, y, targetX, targetY, fallback = 0) {
  if (![x, y, targetX, targetY].every(Number.isFinite)) return finite(fallback);
  const dx = targetX - x, dy = targetY - y;
  return dx * dx + dy * dy > 1e-12 ? Math.atan2(dy, dx) : finite(fallback);
}
export function turnToward(angle, target, dt, snap = false) {
  angle = finite(angle); target = finite(target, angle);
  const delta = Math.atan2(Math.sin(target - angle), Math.cos(target - angle));
  const result = angle + delta * (snap ? 1 : 1 - Math.exp(-Math.max(0, finite(dt)) * 22));
  return Math.atan2(Math.sin(result), Math.cos(result));
}
export function towerMuzzle(x, y, angle = 0, attachments = 0, recoil = 0) {
  const length = .39 - finite(recoil), a = finite(angle);
  return { x: finite(x) + Math.cos(a) * length + Math.sin(a) * .015, y: finite(y) + Math.sin(a) * length - Math.cos(a) * .015, z: .4875 + clamp(finite(attachments), 0, 5) * .18 };
}
function rgb(hex) {
  if (typeof hex === 'string' && hex.startsWith('rgb')) {
    const channels = hex.match(/[\d.]+/g);
    if (channels?.length >= 3) return channels.slice(0, 3).map(Number);
  }
  if (!hex || typeof hex !== 'string' || !hex.startsWith('#')) return [107, 229, 239];
  let s = hex.slice(1); if (s.length === 3) s = s.split('').map(c => c + c).join('');
  const n = parseInt(s, 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
function shade(hex, amount) { const c = rgb(hex); return `rgb(${c.map(v => Math.round(clamp(v * amount, 0, 255))).join(',')})`; }
function alpha(hex, a) { return `rgba(${rgb(hex).join(',')},${clamp(a)})`; }
function mix(a, b, t) { const x = rgb(a), y = rgb(b); return `rgb(${x.map((v, i) => Math.round(lerp(v, y[i], t))).join(',')})`; }
function hash(i) { const n = Math.sin(i * 127.1 + 311.7) * 43758.5453; return n - Math.floor(n); }

export class VoxelRenderer {
  constructor(canvas, { onCell } = {}) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d', { alpha: false });
    this.onCell = onCell;
    this.w = 0; this.h = 0; this.dpr = 1;
    this.morph = 0; this.mix = 0; this.time = 0;
    this.particles = []; this.rings = []; this.labels = []; this.beams = []; this.pickups = []; this.gearFX = [];
    this.state = {}; this.shake = 0; this.flash = 0; this.reducedMotion = false;
    this._frame = 0; this._lastPhase = null; this._towerHits = [];
    this._aims = new Map(); this._lastAimClock = null;
    this._click = event => { const cell = this.towerAt(event.clientX, event.clientY) ?? this.cellAt(event.clientX, event.clientY); if (cell !== null && this.onCell) this.onCell(cell); };
    canvas.addEventListener('click', this._click);
    this._observer = typeof ResizeObserver !== 'undefined' ? new ResizeObserver(() => this.resize()) : null;
    this._observer?.observe(canvas);
    this.resize();
  }

  resize() {
    const r = this.canvas.getBoundingClientRect();
    this.w = Math.max(1, r.width || this.canvas.clientWidth || 800);
    this.h = Math.max(1, r.height || this.canvas.clientHeight || 640);
    this.dpr = Math.min(globalThis.devicePixelRatio || 1, 2);
    const width = Math.round(this.w * this.dpr), height = Math.round(this.h * this.dpr);
    if (this.canvas.width !== width || this.canvas.height !== height) { this.canvas.width = width; this.canvas.height = height; }
    this._layout();
  }

  _layout() {
    const compact = this.w < 560;
    this.flatSize = Math.max(12, Math.min((this.w - (compact ? 24 : 66)) / 9, (this.h - (compact ? 44 : 74)) / 9));
    // Reserve headroom for a fully equipped five-module tower on the back row.
    this.isoSize = Math.max(9, Math.min((this.w - (compact ? 28 : 60)) / 18.4, (this.h - 96) / 11.4));
    this.cx = this.w * .5;
    this.cy = lerp(this.h * .49, this.h * .55, this.mix);
    this.unit = lerp(this.flatSize, this.isoSize, this.mix);
  }

  setReducedMotion(value) { this.reducedMotion = !!value; if (value) this.shake = 0; }
  destroy() { this._observer?.disconnect(); this.canvas.removeEventListener('click', this._click); }

  _project(x, y, z = 0) {
    const a = this.isoSize, s = this.flatSize, t = this.mix;
    return { x: this.cx + lerp((x - 4) * s, (x - y) * a, t), y: this.cy + lerp((y - 4) * s, (x + y - 8) * a * .5, t) - z * a * t };
  }

  cellAt(clientX, clientY) {
    const r = this.canvas.getBoundingClientRect();
    const px = (clientX - r.left) * this.w / (r.width || this.w) - this.cx;
    const py = (clientY - r.top) * this.h / (r.height || this.h) - this.cy;
    const t = this.mix, s = this.flatSize, a = this.isoSize;
    const A = lerp(s, a, t), B = -a * t, C = a * .5 * t, D = lerp(s, a * .5, t);
    const det = A * D - B * C;
    if (!det) return null;
    const x = (D * px - B * py) / det + 4, y = (-C * px + A * py) / det + 4;
    if (x < -.5 || y < -.5 || x >= 8.5 || y >= 8.5) return null;
    return Math.floor(y + .5) * 9 + Math.floor(x + .5);
  }

  towerAt(clientX, clientY) {
    if (this.mix < .7) return null;
    const rect = this.canvas.getBoundingClientRect();
    const x = (clientX - rect.left) * this.w / (rect.width || this.w), y = (clientY - rect.top) * this.h / (rect.height || this.h);
    for (let i = this._towerHits.length - 1; i >= 0; i--) {
      const hit = this._towerHits[i];
      if (x >= hit.left && x <= hit.right && y >= hit.top && y <= hit.bottom) return hit.cell;
    }
    return null;
  }

  // DOM gear cards use this public projection when snapping to a socket. It
  // returns viewport coordinates and never expands the canvas picking region.
  attachmentDropPoint(cell) {
    const tower = (this.state.towers || []).find(tower => tower.cell === cell);
    if (!tower || !Number.isInteger(cell) || cell < 0 || cell > 80) return null;
    const height = .7 + Math.min(5, tower.attachments?.length || 0) * .18;
    const point = this._project(cell % 9, Math.floor(cell / 9), height);
    const rect = this.canvas.getBoundingClientRect();
    return { x: rect.left + point.x * rect.width / this.w, y: rect.top + point.y * rect.height / this.h };
  }

  _poly(points, fill, stroke = null, lineWidth = 1) {
    const c = this.ctx;
    c.beginPath(); points.forEach((p, i) => i ? c.lineTo(p.x, p.y) : c.moveTo(p.x, p.y)); c.closePath();
    if (fill) { c.fillStyle = fill; c.fill(); }
    if (stroke) { c.strokeStyle = stroke; c.lineWidth = lineWidth; c.stroke(); }
  }

  _tile(x, y, inset = 0, z = 0) {
    const d = .5 - inset;
    return [this._project(x - d, y - d, z), this._project(x + d, y - d, z), this._project(x + d, y + d, z), this._project(x - d, y + d, z)];
  }

  _cube(x, y, z, w, d, h, color, edge = false) {
    const p = [this._project(x - w / 2, y - d / 2, z + h), this._project(x + w / 2, y - d / 2, z + h), this._project(x + w / 2, y + d / 2, z + h), this._project(x - w / 2, y + d / 2, z + h)];
    const b = [this._project(x - w / 2, y - d / 2, z), this._project(x + w / 2, y - d / 2, z), this._project(x + w / 2, y + d / 2, z), this._project(x - w / 2, y + d / 2, z)];
    this._poly([p[1], b[1], b[2], p[2]], shade(color, .52));
    this._poly([p[2], b[2], b[3], p[3]], shade(color, .73));
    this._poly(p, shade(color, 1.09), edge ? alpha('#ffffff', .18) : null, .65);
  }

  _rotatedCube(x, y, z, w, d, h, angle, color) {
    const ca = Math.cos(angle), sa = Math.sin(angle);
    const corners = [[-w / 2, -d / 2], [w / 2, -d / 2], [w / 2, d / 2], [-w / 2, d / 2]];
    const points = corners.map(([dx, dy]) => ({ x: x + dx * ca - dy * sa, y: y + dx * sa + dy * ca }));
    const top = points.map(p => this._project(p.x, p.y, z + h)), bottom = points.map(p => this._project(p.x, p.y, z));
    // Draw only faces looking toward the isometric camera, regardless of yaw.
    for (let i = 0; i < 4; i++) {
      const j = (i + 1) % 4, dx = corners[j][0] - corners[i][0], dy = corners[j][1] - corners[i][1];
      const nx = dy * ca + dx * sa, ny = dy * sa - dx * ca, length = Math.hypot(nx, ny);
      if (nx + ny > 1e-8) this._poly([top[i], bottom[i], bottom[j], top[j]], shade(color, .52 + .21 * Math.max(0, ny / length)));
    }
    this._poly(top, shade(color, 1.09), alpha('#ffffff', .18), .65);
  }

  _updateAim(state, dt) {
    // The simulation clock stops under every menu; turret tracking stops too.
    const clock = state._clock;
    const step = Number.isFinite(clock) && this._lastAimClock !== null ? clamp(clock - this._lastAimClock, 0, .05) : dt;
    this._lastAimClock = Number.isFinite(clock) ? clock : null;
    const enemies = new Map((state.enemies || []).filter(e => e.hp > 0).map(e => [e.id, e]));
    const active = new Set();
    for (const tower of state.towers || []) {
      active.add(tower.id);
      let aim = this._aims.get(tower.id);
      if (!aim || aim.source !== tower) {
        aim = { source: tower, angle: finite(tower.aimAngle), shotAge: 1, color: PALETTE[(tower.number || 1) - 1] };
        this._aims.set(tower.id, aim);
      }
      const enemy = state.phase === 'battle' ? enemies.get(tower.aimTargetId) : null;
      if (enemy && aim.shotAge > 0) aim.angle = turnToward(aim.angle, towerAimAngle(tower.cell % 9, Math.floor(tower.cell / 9), enemy.x, enemy.y, aim.angle), step, this.reducedMotion);
      // With no live target, retain the last facing direction. Old saves safely
      // begin at their previous fixed +X facing and acquire aim on their first shot.
      aim.shotAge = Math.min(1, aim.shotAge + step);
    }
    for (const id of this._aims.keys()) if (!active.has(id)) this._aims.delete(id);
  }

  _glow(x, y, radius, color, opacity = .4) {
    if (radius < .5 || opacity <= 0) return;
    const c = this.ctx, g = c.createRadialGradient(x, y, 0, x, y, radius);
    g.addColorStop(0, alpha(color, opacity)); g.addColorStop(.3, alpha(color, opacity * .4)); g.addColorStop(1, alpha(color, 0));
    c.fillStyle = g; c.fillRect(x - radius, y - radius, radius * 2, radius * 2);
  }

  burst(event = {}) {
    const type = event.type || 'hit', cell = Number.isInteger(event.cell) ? event.cell : null;
    const x = finite(event.x, cell === null ? 4 : cell % 9), y = finite(event.y, cell === null ? 4 : Math.floor(cell / 9));
    const effect = event.effect || event.kind || 'basic';
    const color = event.color || MODULES[effect]?.color || RARITY_COLORS[event.rarity] || PALETTE[(event.number || 2) - 1] || '#66eafa';
    if (['gearLift', 'gearHover', 'gearLand', 'gearReturn', 'gearReject'].includes(type)) {
      // Invalid drops outside the board have no world-space target. The tray
      // owns their return flight; do not flash an unrelated center square.
      if (cell === null || cell < 0 || cell > 80) return;
      const life = type === 'gearLand' ? .62 : type === 'gearReturn' ? .38 : type === 'gearReject' ? .3 : .22;
      if (this.gearFX.length >= 24) this.gearFX.shift();
      this.gearFX.push({ type, cell, x, y, color: type === 'gearReject' ? '#ffabb3' : color, age: 0, life });
      return;
    }
    if (type === 'upgrade' && event.family) {
      for (const tower of this.state.towers || []) if (tower.number === event.number && this.rings.length < 50) {
        this.rings.push({ x: tower.cell % 9, y: Math.floor(tower.cell / 9), color, age: 0, life: .85, size: .7 });
      }
    }
    if (type === 'shot') {
      let origin = { x, y, z: finite(event.height, .65) };
      // Chain-lightning hops deliberately have no towerId/cell: only the actual
      // muzzle event is allowed to turn a head or trigger recoil.
      if (cell !== null && event.towerId !== undefined) {
        const angle = finite(event.aimAngle, towerAimAngle(x, y, event.targetX, event.targetY));
        origin = { ...towerMuzzle(x, y, angle), z: finite(event.height, .4875) };
        const tower = (this.state.towers || []).find(t => t.id === event.towerId);
        if (tower) this._aims.set(tower.id, { source: tower, angle, shotAge: 0, color: MODULES[effect]?.color || color });
      }
      if (this.beams.length < 100) this.beams.push({ x: origin.x, y: origin.y, tx: finite(event.targetX, x), ty: finite(event.targetY, y), color: MODULES[effect]?.color || color, effect, height: origin.z, age: 0, life: effect === 'range' ? .26 : .16 });
      return;
    }
    if (type === 'fragment' || type === 'chestDrop') {
      if (this.pickups.length < 36) this.pickups.push({ x, y, age: 0, life: type === 'chestDrop' ? 1.8 : .9, chest: type === 'chestDrop', amount: event.amount || 1, color: type === 'fragment' ? '#8effd1' : color });
      if (type === 'fragment') return;
    }
    const reward = ['upgrade', 'equip', 'chestOpen', 'itemUsed', 'slots', 'chestReveal'].includes(type);
    const big = ['kill', 'explosion', 'wave', 'win', 'chestOpen', 'chestReveal'].includes(type);
    const planting = type === 'seed' || type === 'place';
    const invalid = type === 'invalid';
    if (type === 'phase' || type === 'path' || type === 'buy') return;
    const finalColor = invalid ? '#ff6e87' : color;
    const count = this.reducedMotion ? (big ? 5 : 2) : big ? 24 : reward ? 20 : planting ? 12 : 7;
    for (let i = 0; i < count && this.particles.length < 320; i++) {
      const seed = ++this._frame * 3.721 + i;
      const angle = hash(seed) * Math.PI * 2, speed = .4 + hash(seed + 7) * (big ? 2.3 : 1.25);
      this.particles.push({ x, y, z: planting ? .04 : reward ? .75 : .35, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed, vz: 1.2 + hash(seed + 13) * 2.6, color: finalColor, size: .035 + hash(seed + 2) * .09, age: 0, life: .45 + hash(seed + 1) * .55, cube: i % 3 !== 0 });
    }
    if ((big || planting || invalid || reward || type === 'leak') && this.rings.length < 50) {
      this.rings.push({ x, y, color: finalColor, age: 0, life: reward ? .9 : big ? .65 : .42, size: Number.isFinite(event.radius) ? event.radius : big ? 1.8 : .85, inward: effect === 'gravity' });
      if (reward && !this.reducedMotion && this.rings.length < 50) this.rings.push({ x, y, color: '#f8ffe8', age: -.12, life: .7, size: .68 });
    }
    if (event.text && this.labels.length < 30) this.labels.push({ x, y, text: String(event.text), color: finalColor, age: 0, life: reward ? 1.5 : 1.1 });
    if (!this.reducedMotion) {
      if (type === 'explosion' || type === 'leak') this.shake = Math.max(this.shake, type === 'leak' ? 5 : 3);
      if (type === 'wave' || type === 'win') this.flash = .13;
      if (type === 'chestOpen' && event.rarity === 'legendary') this.flash = .11;
    }
  }

  render(state = {}, dt = 1 / 60, time = 0) {
    this.state = state;
    if (dt > 2) dt /= 1000;
    dt = clamp(dt, 0, .05);
    this._updateAim(state, dt);
    this.time += dt;
    const battle = ['prep', 'battle', 'loot', 'reward', 'lost', 'won'].includes(state.phase);
    const target = battle ? 1 : 0;
    const morphStep = dt * (this.reducedMotion ? 5 : 1.2);
    this.morph = target > this.morph ? Math.min(target, this.morph + morphStep) : Math.max(target, this.morph - morphStep);
    this.mix = ease(this.morph);
    this._layout();
    const c = this.ctx;
    c.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    c.globalAlpha = 1; c.globalCompositeOperation = 'source-over';
    this._background();
    c.save();
    if (this.shake > .1 && !this.reducedMotion) { c.translate(Math.sin(this.time * 89) * this.shake, Math.cos(this.time * 117) * this.shake * .6); this.shake *= Math.exp(-dt * 13); }
    this._board(state);
    this._effects(dt);
    c.restore();
    this._annotations(state);
    this._pickups(dt);
    if (this.flash > .002) { c.fillStyle = alpha('#c9f5ff', this.flash); c.fillRect(0, 0, this.w, this.h); this.flash *= Math.exp(-dt * 10); }
    this._lastPhase = state.phase;
  }

  _background() {
    const c = this.ctx, w = this.w, h = this.h, t = this.mix;
    c.fillStyle = '#091915'; c.fillRect(0, 0, w, h);
    const glow = c.createRadialGradient(w * .5, h * .43, 20, w * .5, h * .5, Math.max(w, h) * .7);
    glow.addColorStop(0, '#244139'); glow.addColorStop(.5, '#102b28'); glow.addColorStop(1, '#081713');
    c.fillStyle = glow; c.fillRect(0, 0, w, h);
    // An etched work surface around the machine, rather than an unbounded sky.
    c.fillStyle = 'rgba(149,193,165,.065)';
    for (let x = 22; x < w; x += 32) for (let y = 18; y < h; y += 32) c.fillRect(x, y, 1, 1);
    if (t > .05) {
      c.save();
      // These are decorative contours outside the playable grid. They share its
      // projection but cannot alter the board's geometry or pointer hit region.
      for (let i = 0; i < 3; i++) {
        const edge = .98 + i * .42;
        const points = [[-edge, -edge], [8 + edge, -edge], [8 + edge, 8 + edge], [-edge, 8 + edge]].map(([x, y]) => this._project(x, y, -.6));
        this._poly(points, null, alpha('#8bd5af', (.105 - i * .026) * t), .7);
      }
      c.lineWidth = 1;
      for (let i = 0; i < 6; i++) {
        const x = .25 + i * 1.48, y = i % 2 ? -1.2 : 9.2, sign = i % 2 ? -1 : 1;
        const points = [[x, y], [x, y + sign * .45], [x + .35, y + sign * .8], [x + .7, y + sign * .8]].map(([px, py]) => this._project(px, py, -.6));
        c.strokeStyle = alpha('#9fb88b', .17 * t); c.beginPath();
        points.forEach((p, n) => n ? c.lineTo(p.x, p.y) : c.moveTo(p.x, p.y)); c.stroke();
        const end = points[points.length - 1];
        c.fillStyle = alpha('#a1d9b7', .34 * t); c.fillRect(end.x - 1, end.y - 1, 2, 2);
      }
      c.restore();
    }
    // A few drifting seed motes soften the machine without competing with loot.
    for (let i = 0; i < 16; i++) {
      const speed = this.reducedMotion ? 0 : this.time * (1 + hash(i + 800) * 2);
      const x = hash(i + 101) * w, y = (hash(i + 200) * h - speed % h + h) % h;
      const opacity = this.reducedMotion ? .12 : .09 + .06 * Math.sin(this.time * .5 + i);
      c.fillStyle = alpha(i % 4 ? '#a4dcc2' : '#d4ad72', opacity);
      c.fillRect(x, y, i % 5 === 0 ? 2 : 1, i % 5 === 0 ? 2 : 1);
    }
  }

  _boardMount() {
    const c = this.ctx, t = this.mix;
    const plane = (x1, y1, x2, y2, z = 0) => [this._project(x1, y1, z), this._project(x2, y1, z), this._project(x2, y2, z), this._project(x1, y2, z)];
    // Three shallow machined layers keep the ceramic grid seated in a physical
    // object. Their footprint fits the existing margins; projection is unchanged.
    this._cube(4, 4, -.48, 9.36, 9.36, .17, '#122b26');
    this._cube(4, 4, -.31, 9.38, 9.38, .075, '#927654');
    this._cube(4, 4, -.235, 9.32, 9.32, .22, '#365b4e');
    this._poly(plane(-.61, -.61, 8.61, 8.61), '#19372f', alpha('#b9c9aa', .52), .8);
    this._poly(plane(-.535, -.535, 8.535, 8.535), '#4b7665', alpha('#a9ddbf', .55), .7);
    if (t > .01) {
      c.save(); c.globalAlpha = t;
      // Recessed mint status inlays and copper separators on the two front faces.
      for (let i = 0; i < 9; i++) {
        const color = i % 3 === 1 ? '#a0d8b7' : '#5b8d73';
        const front = [this._project(i - .3, 8.665, -.12), this._project(i + .3, 8.665, -.12), this._project(i + .3, 8.665, -.19), this._project(i - .3, 8.665, -.19)];
        const side = [this._project(8.665, i - .3, -.12), this._project(8.665, i + .3, -.12), this._project(8.665, i + .3, -.19), this._project(8.665, i - .3, -.19)];
        this._poly(front, color); this._poly(side, shade(color, .77));
      }
      for (const n of [2.5, 5.5]) {
        this._cube(n, 8.625, -.285, .11, .065, .2, '#b48b59');
        this._cube(8.625, n, -.285, .065, .11, .2, '#b48b59');
      }
      c.restore();
    }
    // L-shaped brass clamps sit outside the Sudoku surface, never over a digit.
    for (const [x, y, dx, dy] of [[-.68, -.68, 1, 1], [8.68, -.68, -1, 1], [8.68, 8.68, -1, -1], [-.68, 8.68, 1, -1]]) {
      const points = [[x, y], [x + dx * .72, y], [x + dx * .72, y + dy * .105], [x + dx * .105, y + dy * .105], [x + dx * .105, y + dy * .72], [x, y + dy * .72]].map(([px, py]) => this._project(px, py, .012));
      this._poly(points, '#b49564', '#d7bd8d', .55);
      const screw = this._project(x + dx * .048, y + dy * .048, .013), radius = Math.max(.8, this.unit * .026);
      c.fillStyle = '#354435'; c.beginPath(); c.ellipse(screw.x, screw.y, radius, radius * lerp(1, .6, t), 0, 0, Math.PI * 2); c.fill();
    }
  }

  _board(state) {
    this._towerHits = [];
    const c = this.ctx, t = this.mix;
    const towerMap = new Map((state.towers || []).map(tower => [tower.cell, tower]));
    const selected = Number.isInteger(state.selectedCell) ? state.selectedCell : -1;
    const sx = selected % 9, sy = Math.floor(selected / 9);
    const recent = new Set((state.recentMoves || []).map(m => typeof m === 'number' ? m : m.cell));
    const selectedNumber = state.selectedNumber || (state.board || [])[selected];
    // Equipment placement stays a presentation-only overlay. The caller owns
    // eligibility; a filled/given square can never masquerade as a target.
    const preview = state.equipPreview;
    this._equipFeedback = preview?.active ? {
      placing: !!preview.itemSelected,
      valid: new Set((preview.validCells || []).filter(cell => towerMap.has(cell))),
      full: new Set((preview.fullCells || []).filter(cell => towerMap.has(cell))),
      hover: Number.isInteger(preview.hoverCell) ? preview.hoverCell : -1,
      dragging: !!preview.dragActive, kind: preview.dragKind,
      color: preview.color || MODULES[preview.dragKind]?.color || '#8ef8d4',
      source: Number.isInteger(preview.sourceCell) ? preview.sourceCell : -1
    } : null;
    // A grounded shadow under the layered botanical machine chassis.
    const groundY = this.cy + this.isoSize * 2.8 * t;
    c.save(); c.translate(this.cx, groundY); c.scale(1, lerp(1, .31, t));
    const shadow = c.createRadialGradient(0, 0, 0, 0, 0, this.flatSize * 5.1);
    shadow.addColorStop(0, 'rgba(0,0,0,.64)'); shadow.addColorStop(1, 'rgba(0,0,0,0)');
    c.fillStyle = shadow; c.fillRect(-this.flatSize * 5.1, -this.flatSize * 5.1, this.flatSize * 10.2, this.flatSize * 10.2); c.restore();
    this._boardMount();

    for (let depth = 0; depth <= 16; depth++) {
      for (let y = 0; y < 9; y++) {
        const x = depth - y; if (x < 0 || x > 8) continue;
        const cell = y * 9 + x, value = (state.board || [])[cell] || 0, tower = towerMap.get(cell);
        const block = (Math.floor(x / 3) + Math.floor(y / 3)) % 2;
        const isSelected = cell === selected;
        const allied = selected >= 0 && (x === sx || y === sy || (Math.floor(x / 3) === Math.floor(sx / 3) && Math.floor(y / 3) === Math.floor(sy / 3)));
        let flatColor = block ? '#e4e8d9' : '#f1efdd';
        if (allied) flatColor = block ? '#ccdec9' : '#d9e5cd';
        if (selectedNumber && value === selectedNumber) flatColor = '#badfc7';
        if (isSelected) flatColor = '#9ed9bd';
        let combatColor = block ? '#345649' : '#416958';
        if (!value) combatColor = block ? '#243e35' : '#2c4b3e';
        if (tower) combatColor = tower.illegal ? '#603d52' : '#4b6f58';
        if (isSelected) combatColor = '#518c6d';
        const inset = .012 + t * .026;
        const pts = this._tile(x, y, inset);
        this._poly(pts, mix(flatColor, combatColor, t));
        if (t > .3) {
          c.globalAlpha = t * .5;
          c.beginPath(); c.moveTo(pts[3].x, pts[3].y); c.lineTo(pts[0].x, pts[0].y); c.lineTo(pts[1].x, pts[1].y);
          c.strokeStyle = '#86a890'; c.lineWidth = 1; c.stroke(); c.globalAlpha = 1;
          if (!value && hash(cell + 91) > .74) {
            const p = this._project(x + .19, y + .13);
            c.fillStyle = alpha('#80a19a', .15 * t); c.fillRect(p.x, p.y, 3, 1.5);
          }
        }
        if (recent.has(cell) && !isSelected) this._poly(this._tile(x, y, .065), null, alpha('#efa74c', lerp(.43, .8, t)), lerp(1.7, 1.4, t));
        if (isSelected) this._poly(this._tile(x, y, .02), null, lerp(0, 1, t) > .5 ? '#9df8e6' : '#157f89', 2.6);
        if (tower?.illegal) {
          this._poly(this._tile(x, y, .09), null, alpha('#ff678a', .65), 1.6);
          const p = this._project(x + .31, y - .28);
          c.fillStyle = '#bd335c'; c.font = `700 ${Math.max(8, this.flatSize * .2)}px system-ui`; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText('!', p.x, p.y);
        }
        const equip = this._equipFeedback;
        if (equip?.placing) {
          const valid = equip.valid.has(cell), full = equip.full.has(cell), hover = equip.hover === cell;
          if (valid || full || hover) {
            const color = valid ? '#8ef8d4' : hover ? '#ff8e99' : '#b9717d';
            this._poly(this._tile(x, y, hover ? .025 : .065), hover ? alpha(color, .16) : null, alpha(color, hover ? 1 : valid ? .8 : .55), hover ? 2.8 : valid ? 1.6 : 1.1);
            if (hover && !valid) {
              // Invalid empty/given cells get a quiet cross as well as color.
              const p = this._project(x, y), size = Math.max(3, this.unit * .12);
              c.strokeStyle = '#ffb7bd'; c.lineWidth = 1.5; c.beginPath();
              c.moveTo(p.x - size, p.y - size); c.lineTo(p.x + size, p.y + size);
              c.moveTo(p.x + size, p.y - size); c.lineTo(p.x - size, p.y + size); c.stroke();
            }
          }
        }
      }
    }

    // True 3×3 separators remain recognizable during the projection change.
    for (const n of [-.5, 2.5, 5.5, 8.5]) {
      for (const points of [[this._project(n, -.5), this._project(n, 8.5)], [this._project(-.5, n), this._project(8.5, n)]]) {
        c.beginPath(); c.moveTo(points[0].x, points[0].y); c.lineTo(points[1].x, points[1].y);
        c.lineWidth = lerp(2.2, 2.7, t); c.strokeStyle = mix('#4a6956', '#142b23', t); c.stroke();
      }
    }
    this._route(state.route || []);

    // Flat Sudoku typography cross-fades to engraved tactical tile numbers.
    for (let cell = 0; cell < 81; cell++) {
      const number = (state.board || [])[cell] || 0; if (!number) continue;
      const x = cell % 9, y = Math.floor(cell / 9), tower = towerMap.get(cell);
      const given = (state.givens || [])[cell];
      const p = this._project(x, y);
      const opacity = tower ? 1 - t : lerp(1, .35, t);
      if (opacity < .02) continue;
      c.globalAlpha = opacity;
      c.fillStyle = tower?.illegal ? '#b63f62' : given ? mix('#2c4956', '#c1ded7', t) : '#087d89';
      c.textAlign = 'center'; c.textBaseline = 'middle';
      c.font = `${given ? 500 : 700} ${Math.round(lerp(this.flatSize * .52, this.isoSize * .4, t))}px "Space Grotesk", "Segoe UI", system-ui, sans-serif`;
      c.fillText(number, p.x, p.y + this.flatSize * .025);
      if (tower && t < .7) {
        // Keep the solve board a regular Sudoku board. The little split seed is
        // a promise of the machine that grows when preparation begins.
        const seed = this._project(x + .29, y + .28), r = Math.max(2, this.flatSize * .075);
        c.fillStyle = tower.illegal ? '#b43f67' : '#368c70';
        c.beginPath(); c.ellipse(seed.x, seed.y, r * .8, r * 1.1, -.45, 0, Math.PI * 2); c.fill();
        c.strokeStyle = '#b5f4d4'; c.lineWidth = 1; c.beginPath(); c.moveTo(seed.x - r * .25, seed.y + r * .65); c.lineTo(seed.x + r * .2, seed.y - r * .5); c.stroke();
        if (this._equipFeedback) {
          const count = Math.min(5, tower.attachments?.length || 0);
          const slot = Math.max(1.4, this.flatSize * .052), gap = Math.max(2.4, this.flatSize * .09);
          const origin = this._project(x - .32, y + .32);
          for (let i = 0; i < 5; i++) {
            c.fillStyle = i < count ? '#147b79' : '#98b6b4';
            c.fillRect(origin.x + gap * i - slot / 2, origin.y - slot / 2, slot, slot);
          }
        }
      }
      c.globalAlpha = 1;
    }

    if (t > .025) {
      c.globalAlpha = Math.min(1, t * 1.3);
      const entities = [];
      for (const tower of state.towers || []) if (Number.isInteger(tower.cell)) entities.push({ ...tower, _kind: 'tower', x: tower.cell % 9, y: Math.floor(tower.cell / 9) });
      for (const enemy of state.enemies || []) if (Number.isFinite(enemy.x) && Number.isFinite(enemy.y)) entities.push({ ...enemy, _kind: 'enemy' });
      entities.sort((a, b) => a.x + a.y - b.x - b.y);
      for (const entity of entities) entity._kind === 'tower' ? this._tower(entity) : this._enemy(entity);
      c.globalAlpha = 1;
    }
    if (state.phase === 'battle') this._projectiles(state.projectiles || []);
    this._attachmentGhost(towerMap);
  }

  _route(route) {
    if (route.length < 2) return;
    const c = this.ctx, t = this.mix, points = route.map(p => this._project(finite(p.x), finite(p.y), .012));
    const line = () => { c.beginPath(); points.forEach((p, i) => i ? c.lineTo(p.x, p.y) : c.moveTo(p.x, p.y)); };
    c.save(); c.lineJoin = 'round'; c.lineCap = 'round';
    if (t > .1) { line(); c.strokeStyle = alpha('#ffab5a', .13 * t); c.lineWidth = this.isoSize * .3 + 6; c.stroke(); }
    line(); c.strokeStyle = alpha('#ffb85a', lerp(.14, .94, t)); c.lineWidth = lerp(3, this.isoSize * .17 + 1, t); c.stroke();
    line(); c.strokeStyle = alpha('#ffe4a7', lerp(.1, .95, t)); c.lineWidth = lerp(1.2, 1.3, t); c.stroke();
    c.setLineDash([3, 10]); c.lineDashOffset = this.reducedMotion ? 0 : -this.time * 15;
    line(); c.strokeStyle = alpha('#fff2c9', t * .9); c.lineWidth = 2.1; c.stroke(); c.setLineDash([]);
    if (t > .15) {
      const start = points[0], end = points[points.length - 1];
      this._glow(start.x, start.y, this.isoSize * .8, '#ff765e', .36 * t);
      this._glow(end.x, end.y, this.isoSize * .85, '#58efdf', .45 * t);
      for (const [p, color] of [[start, '#ff9a71'], [end, '#77f6e3']]) {
        c.strokeStyle = color; c.lineWidth = 1.8; c.beginPath(); c.ellipse(p.x, p.y, this.isoSize * .3, this.isoSize * .15, 0, 0, Math.PI * 2); c.stroke();
      }
    }
    c.restore();
  }

  _tower(tower) {
    const c = this.ctx, { x, y } = tower, n = clamp(Number(tower.number) || 1, 1, 9);
    const color = tower.illegal ? '#ff6a9a' : (this.state.towerColors || [])[n - 1] || PALETTE[n - 1];
    const selected = tower.cell === this.state.selectedCell;
    const phase = this.reducedMotion ? 0 : Math.sin(this.time * 3 + tower.cell * .7);
    const attachments = (tower.attachments || []).slice(0, 5);
    const level = Math.max(1, finite(tower.level, 1) + finite(this.state.familyLevels?.[n], 1) - 1);
    const growth = this.reducedMotion ? 1 : Math.min(clamp(finite(tower.growth, 1)), clamp((this.mix - .08) / .8));
    const landed = this.gearFX.findLast(fx => fx.cell === tower.cell && fx.type === 'gearLand');
    const pop = landed && !this.reducedMotion ? Math.sin(Math.PI * clamp(landed.age / .32)) * .065 : 0;
    const build = ease(clamp((growth - .22) / .78)) * (1 + pop);
    const dark = '#364d5c', mid = shade(color, .72);
    const base = this._project(x, y, .025);
    c.fillStyle = 'rgba(3,12,24,.32)'; c.beginPath(); c.ellipse(base.x, base.y + 3, this.isoSize * .44, this.isoSize * .2, 0, 0, Math.PI * 2); c.fill();
    if (selected) {
      const radius = this.isoSize * (.6 + phase * .025);
      this._glow(base.x, base.y, radius * 1.6, color, .2);
      c.strokeStyle = '#cefff1'; c.lineWidth = 1.8; c.beginPath(); c.ellipse(base.x, base.y, radius, radius * .44, 0, 0, Math.PI * 2); c.stroke();
    }
    if (growth < .98) {
      // A split seed becomes a living circuit stalk; metal plates unfurl around it.
      const sprout = ease(clamp(growth / .5)), stem = .12 + sprout * .42;
      this._cube(x - .09, y, .015, .17, .29, .14 * (1 - build) + .04, '#6caa77');
      this._cube(x + .09, y, .015, .17, .29, .11 * (1 - build) + .04, '#3e8c68');
      this._cube(x, y, .07, .065, .065, stem, '#b3f3ba');
      this._cube(x - .11 * sprout, y, stem * .57, .24 * sprout + .01, .085, .055, '#89d995');
      this._cube(x + .11 * sprout, y, stem * .76, .2 * sprout + .01, .09, .06, '#75d0a9');
    }
    if (build > .01) {
      const cube = (dx, dy, z, w, d, h, col = color) => this._cube(x + dx, y + dy, z * build, w, d, h * build, col, true);
      // Every number starts as this same seed-grown kinetic cannon.
      cube(0, 0, .035, .6, .6, .095, dark);
      cube(0, 0, .13, .47, .47, .065, mid);
      cube(0, 0, .195, .26, .26, .19, dark);
      cube(0, 0, .25, .3, .3, .055, color);
      for (let i = 0; i < attachments.length; i++) this._module(tower, attachments[i], i, build);
      const head = .385 + attachments.length * .18;
      const aim = this._aims.get(tower.id), angle = finite(aim?.angle, finite(tower.aimAngle));
      const recoil = this.reducedMotion ? 0 : .055 * clamp(1 - finite(aim?.shotAge, 1) / .14);
      const ca = Math.cos(angle), sa = Math.sin(angle);
      const parts = [[0, 0, head, .33, .31, .18, color], [.21, -.015, head + .055, .29, .11, .095, mid], [.37, -.015, head + .06, .04, .145, .085, '#e8ffec'], [-.12, -.1, head + .18, .065, .065, .065, '#d6ffdf']]
        .map(([dx, dy, z, w, d, h, col]) => ({ x: x + (dx - recoil) * ca - dy * sa, y: y + (dx - recoil) * sa + dy * ca, z, w, d, h, col }));
      parts.sort((a, b) => a.x + a.y - b.x - b.y);
      for (const part of parts) this._rotatedCube(part.x, part.y, part.z * build, part.w, part.d, part.h * build, angle, part.col);
      const muzzle = towerMuzzle(x, y, angle, attachments.length, recoil), muzzleScreen = this._project(muzzle.x, muzzle.y, muzzle.z * build);
      if (!this.reducedMotion && aim?.shotAge < .09) {
        const flash = 1 - aim.shotAge / .09;
        this._glow(muzzleScreen.x, muzzleScreen.y, this.isoSize * .38 * flash, aim.color, .8 * flash);
        this._rotatedCube(muzzle.x, muzzle.y, muzzle.z * build - .04, .09 * flash, .09 * flash, .08 * flash, angle, '#f3ffe8');
      }
      const tip = this._project(x, y, (head + .25) * build);
      this._glow(tip.x, tip.y, this.isoSize * .36, color, .13 + (phase + 1) * .022);
      const rarities = ['common', 'uncommon', 'rare', 'epic', 'legendary'];
      const highest = attachments.reduce((best, item) => Math.max(best, rarities.indexOf(item?.rarity)), 0);
      if (highest >= 2) {
        const aura = RARITY_COLORS[rarities[highest]];
        this._glow(tip.x, tip.y + this.isoSize * .28, this.isoSize * .85, aura, .09 + highest * .014);
        // Rarity sparks are deterministic ambient accents, not gameplay pickups.
        if (!this.reducedMotion) for (let i = 0; i < highest - 1; i++) {
          const a = this.time * .8 + tower.cell + i * 2.3, p = this._project(x + Math.cos(a) * .29, y + Math.sin(a) * .29, head * build + .1 + Math.sin(a * 1.7) * .22);
          c.fillStyle = aura; c.fillRect(p.x - 1, p.y - 1, 2, 2);
        }
      }
      // Hit region follows the visible raised machine; ground-cell picking remains
      // a separate precise inverse projection for keyboard/controller navigation.
      this._towerHits.push({ cell: tower.cell, left: Math.min(base.x - this.isoSize * .29, muzzleScreen.x - 3), right: Math.max(base.x + this.isoSize * .35, muzzleScreen.x + 3), top: Math.min(tip.y - 3, muzzleScreen.y - 3), bottom: base.y + 4 });
      if (selected || level > 1) {
        const badgeX = tip.x - this.isoSize * .25, badgeY = tip.y - 8;
        const label = `L${level}`, fontSize = Math.max(8, Math.min(10, this.isoSize * .27));
        c.font = `800 ${fontSize}px "Space Grotesk", system-ui`; c.textAlign = 'center'; c.textBaseline = 'middle';
        const w = c.measureText(label).width + 8;
        c.fillStyle = '#102536'; c.fillRect(badgeX - w / 2, badgeY - 6, w, 12);
        c.fillStyle = selected ? '#d9fff0' : color; c.fillText(label, badgeX, badgeY + .3);
      }
    }
    // Digit identity stays grounded and readable even under a five-item stack.
    const badge = this._project(x, y + .33, .08);
    const radius = Math.max(5, this.isoSize * .16);
    c.fillStyle = '#102536'; c.beginPath(); c.arc(badge.x, badge.y, radius, 0, Math.PI * 2); c.fill();
    if (selected) { c.strokeStyle = '#c9ffef'; c.lineWidth = 1; c.stroke(); }
    c.fillStyle = color; c.font = `800 ${Math.max(8, this.isoSize * .25)}px "Space Grotesk", system-ui`; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText(n, badge.x, badge.y + .3);
    if (this._equipFeedback) this._equipmentBadge(tower);
  }

  _attachmentGhost(towerMap) {
    const equip = this._equipFeedback;
    if (!equip?.dragging || !equip.placing || !equip.valid.has(equip.hover) || this.mix < .7) return;
    const tower = towerMap.get(equip.hover); if (!tower) return;
    const x = tower.cell % 9, y = Math.floor(tower.cell / 9);
    const z = .87 + Math.min(5, tower.attachments?.length || 0) * .18;
    const c = this.ctx, p = this._project(x, y, z), socket = this._project(x, y, z - .18);
    c.save();
    this._glow(p.x, p.y, this.isoSize * .55, equip.color, .16);
    c.strokeStyle = alpha(equip.color, .66); c.lineWidth = 1; c.setLineDash([2, 3]);
    c.beginPath(); c.moveTo(p.x, p.y); c.lineTo(socket.x, socket.y + 3); c.stroke(); c.setLineDash([]);
    c.globalAlpha = .68;
    this._cube(x, y, z, .31, .31, .07, equip.color, true);
    this._cube(x, y, z + .07, .16, .16, .1, shade(equip.color, 1.15), true);
    c.restore();
  }

  _gearEffects(dt) {
    const c = this.ctx;
    for (let i = this.gearFX.length - 1; i >= 0; i--) {
      const fx = this.gearFX[i]; fx.age += dt;
      if (fx.age >= fx.life) { this.gearFX.splice(i, 1); continue; }
      const t = clamp(fx.age / fx.life), fade = 1 - t;
      const tower = (this.state.towers || []).find(tower => tower.cell === fx.cell);
      const z = .48 + Math.min(5, tower?.attachments?.length || 0) * .18;
      const p = this._project(fx.x, fx.y, z), base = this._project(fx.x, fx.y, .03);
      c.save();
      if (this.reducedMotion) {
        this._poly(this._tile(fx.x, fx.y, .055), null, alpha(fx.color, fade * .85), 2);
        c.restore(); continue;
      }
      if (fx.type === 'gearLand') {
        this._glow(p.x, p.y, this.isoSize * (.55 + t * .4), fx.color, fade * .32);
        const radius = this.isoSize * (.2 + t * .68);
        c.strokeStyle = alpha(fx.color, fade * .8); c.lineWidth = 2 * fade + .5;
        c.beginPath(); c.ellipse(base.x, base.y, radius, radius * .46, 0, 0, Math.PI * 2); c.stroke();
        // Eight bounded voxel chips form a compact socket-lock celebration.
        for (let j = 0; j < 8; j++) {
          const angle = j * Math.PI / 4 + fx.cell, travel = t * .52;
          const q = this._project(fx.x + Math.cos(angle) * travel, fx.y + Math.sin(angle) * travel, z + Math.sin(Math.PI * t) * .33);
          const size = Math.max(1, this.isoSize * .07 * fade);
          c.fillStyle = alpha(j % 3 ? fx.color : '#efffeb', fade);
          c.fillRect(q.x - size / 2, q.y - size / 2, size, size);
        }
      } else if (fx.type === 'gearReject') {
        this._poly(this._tile(fx.x, fx.y, .055), null, alpha(fx.color, fade * .8), 2);
      } else {
        const inward = fx.type === 'gearReturn', radius = this.isoSize * (inward ? .54 - t * .28 : .24 + t * .2);
        c.strokeStyle = alpha(fx.color, fade * .55); c.lineWidth = 1.4;
        c.beginPath(); c.ellipse(p.x, p.y - (inward ? t * 6 : 0), radius, radius * .45, 0, 0, Math.PI * 2); c.stroke();
      }
      c.restore();
    }
  }

  _equipmentBadge(tower) {
    const c = this.ctx, equip = this._equipFeedback;
    const used = Math.min(5, tower.attachments?.length || 0), valid = equip.valid.has(tower.cell);
    const hover = equip.placing && equip.hover === tower.cell;
    const tint = equip.placing && used >= 5 ? '#ffb2bb' : valid ? '#abffe0' : '#c0d2d8';
    // The family digit sits on the left of the base; occupancy sits to its
    // right, away from the rotating head and the individual-level badge.
    const p = this._project(tower.x + .44, tower.y - .06, -.05);
    const font = Math.max(8, Math.min(10, this.isoSize * .27));
    c.font = `800 ${font}px "Space Grotesk", system-ui`; c.textAlign = 'center'; c.textBaseline = 'middle';
    const label = `${used}/5`, width = c.measureText(label).width + 4, height = font + 3;
    c.fillStyle = valid && used === 0 ? '#154137' : '#102536';
    c.fillRect(p.x - width / 2, p.y - height / 2, width, height);
    if (hover || tower.cell === this.state.selectedCell) {
      c.strokeStyle = hover && !valid ? '#ff8e99' : '#b6ffe4'; c.lineWidth = 1;
      c.strokeRect(p.x - width / 2, p.y - height / 2, width, height);
    }
    c.fillStyle = tint; c.fillText(label, p.x, p.y + .4);
    // A tiny ready lamp makes unused towers identifiable without another icon
    // or a moving effect on the compact isometric board.
    if (valid && used === 0) { c.fillStyle = '#8ef8d4'; c.fillRect(p.x + width / 2 - 2, p.y - height / 2 - 2, 2, 2); }
  }

  _module(tower, item, slot, growth) {
    const { x, y } = tower, kind = item?.kind || 'power';
    const color = MODULES[kind]?.color || item?.color || '#9ad2dd';
    const z = .385 + slot * .18, pulse = this.reducedMotion ? 0 : Math.sin(this.time * 4 + slot + tower.cell);
    const cube = (dx, dy, dz, w, d, h, col = color) => this._cube(x + dx, y + dy, (z + dz) * growth, w, d, h * growth, col, true);
    cube(0, 0, 0, .37, .37, .045, '#294653');
    cube(0, 0, .045, .32, .32, .105, shade(color, .82));
    cube(0, 0, .15, .39, .39, .025, color);
    switch (kind) {
      case 'rapid':
        cube(-.2, 0, .05, .105, .3, .08); cube(.2, 0, .05, .105, .3, .08); break;
      case 'electric':
        cube(-.18, -.18, .04, .08, .08, .19); cube(.18, .18, .04, .08, .08, .19, '#e7dbff'); break;
      case 'frost':
        cube(-.15, -.18, .05, .105, .105, .19, '#c4f9ff'); cube(.18, .14, .065, .1, .1, .14); break;
      case 'blast':
        cube(-.18, .05, .045, .12, .22, .13); cube(.18, -.05, .045, .12, .22, .13, '#ffe2b4'); break;
      case 'venom':
        cube(-.17, .16, .03, .14, .14, .18, '#c3ff8e'); cube(.15, -.17, .03, .13, .13, .18); break;
      case 'range':
        cube(.21, 0, .07, .22, .075, .065); cube(-.2, 0, .07, .16, .075, .065); break;
      case 'power':
        cube(0, 0, .09, .48, .13, .07); cube(0, 0, .09, .13, .48, .07); break;
      case 'gravity': {
        const a = this.reducedMotion ? .45 : this.time * .8 + slot;
        cube(Math.cos(a) * .25, Math.sin(a) * .25, .06, .1, .1, .1, '#d2c5ff');
        cube(-Math.cos(a) * .25, -Math.sin(a) * .25, .06, .1, .1, .1); break;
      }
      case 'nova':
        cube(-.2, -.2, .035, .085, .085, .17); cube(.2, .2, .035, .085, .085, .17, '#fff4c5'); break;
    }
    // A front-face status lamp makes repeated modules countable on Deck's screen.
    const lamp = this._project(x, y + .18, (z + .095) * growth);
    this.ctx.fillStyle = color; this.ctx.fillRect(lamp.x - 1.4, lamp.y - 1, 2.8, 2);
    if (tower.cell === this.state.selectedCell) this._glow(lamp.x, lamp.y, this.isoSize * .14, color, .2 + pulse * .03);
  }

  _enemy(enemy) {
    const c = this.ctx, { x, y } = enemy, kind = enemy.kind || 'runner';
    const tank = kind === 'tank' || kind === 'boss', boss = kind === 'boss';
    const color = boss ? '#ff607f' : tank ? '#bb6cb6' : kind === 'swarm' ? '#f7a06c' : '#ef8276';
    const scale = boss ? .5 : tank ? .38 : kind === 'swarm' ? .2 : .27;
    const bob = this.reducedMotion ? 0 : Math.abs(Math.sin(this.time * (tank ? 9 : 17) + finite(enemy.id) * 2)) * .04;
    const p = this._project(x, y);
    c.fillStyle = 'rgba(3,10,20,.4)'; c.beginPath(); c.ellipse(p.x, p.y, this.isoSize * scale * .8, this.isoSize * scale * .33, 0, 0, Math.PI * 2); c.fill();
    this._cube(x, y, .025 + bob, scale, scale, scale * .7, color, true);
    this._cube(x, y, .025 + bob + scale * .7, scale * .7, scale * .7, scale * .35, shade(color, 1.22));
    if (tank) {
      this._cube(x - scale * .35, y - scale * .35, scale + bob, scale * .2, scale * .2, scale * .26, '#ffba9c');
      this._cube(x + scale * .35, y + scale * .35, scale + bob, scale * .2, scale * .2, scale * .26, '#ffba9c');
    }
    const face = this._project(x + scale * .18, y + scale * .42, scale * .58 + bob);
    c.fillStyle = '#fff2c6'; c.fillRect(face.x - 3, face.y, 2, 2); c.fillRect(face.x + 2, face.y - 1, 2, 2);
    if (enemy.hp < enemy.maxHp || boss) {
      const top = this._project(x, y, scale * 1.4 + .12), width = this.isoSize * scale * 1.7;
      c.fillStyle = '#101b28'; c.fillRect(top.x - width / 2 - 1, top.y - 1, width + 2, 4);
      c.fillStyle = boss ? '#ff9d78' : '#ffd3ab'; c.fillRect(top.x - width / 2, top.y, width * clamp(enemy.hp / (enemy.maxHp || 1)), 2);
    }
    if (enemy.slow || enemy.slowed || enemy.slowTimer > 0 || enemy.slowTime > 0) {
      c.strokeStyle = alpha('#95eeff', .8); c.lineWidth = 1;
      c.beginPath(); c.ellipse(p.x, p.y, this.isoSize * scale, this.isoSize * scale * .45, 0, 0, Math.PI * 2); c.stroke();
    }
  }

  _projectiles(projectiles) {
    const c = this.ctx;
    for (const shot of projectiles) {
      if (!Number.isFinite(shot.x) || !Number.isFinite(shot.y)) continue;
      const p = this._project(shot.x, shot.y, .35), color = shot.color || '#ffdf98';
      this._glow(p.x, p.y, 9, color, .5); c.fillStyle = color; c.fillRect(p.x - 2, p.y - 2, 4, 4);
    }
  }

  _effects(dt) {
    const c = this.ctx;
    this._gearEffects(dt);
    for (let i = this.beams.length - 1; i >= 0; i--) {
      const b = this.beams[i]; b.age += dt; if (b.age >= b.life) { this.beams.splice(i, 1); continue; }
      const p = this._project(b.x, b.y, b.height), q = this._project(b.tx, b.ty, .22), fade = 1 - b.age / b.life;
      c.save(); c.globalAlpha = fade * this.mix; c.lineCap = 'round';
      c.beginPath(); c.moveTo(p.x, p.y);
      if (b.effect === 'electric') {
        for (let s = 1; s < 5; s++) { const f = s / 5; c.lineTo(lerp(p.x, q.x, f) + (s % 2 ? 1 : -1) * 5, lerp(p.y, q.y, f) + (s % 2 ? -1 : 1) * 3); }
      }
      const heavy = ['range', 'power', 'nova'].includes(b.effect);
      c.lineTo(q.x, q.y);
      c.strokeStyle = alpha(b.color, .18); c.lineWidth = heavy ? 9 : 5; c.stroke();
      c.strokeStyle = b.color; c.lineWidth = heavy ? 2.7 : 1.4; c.stroke();
      c.strokeStyle = '#f3fff8'; c.lineWidth = .7; c.stroke();
      if (['frost', 'blast', 'gravity', 'nova'].includes(b.effect)) {
        const radius = (1 - fade) * (b.effect === 'blast' || b.effect === 'nova' ? 15 : 8) + 2;
        c.beginPath(); c.ellipse(q.x, q.y, radius, radius * .5, 0, 0, Math.PI * 2); c.strokeStyle = b.color; c.lineWidth = 1.4; c.stroke();
      }
      this._glow(q.x, q.y, 15, b.color, .38); c.restore();
    }
    for (let i = this.rings.length - 1; i >= 0; i--) {
      const r = this.rings[i]; r.age += dt; if (r.age >= r.life) { this.rings.splice(i, 1); continue; }
      if (r.age < 0) continue;
      const f = r.age / r.life, p = this._project(r.x, r.y, .035), radius = this.unit * r.size * (r.inward ? 1.2 - f : .2 + f);
      c.strokeStyle = alpha(r.color, (1 - f) * .8); c.lineWidth = 2 * (1 - f) + .5;
      c.beginPath(); c.ellipse(p.x, p.y, radius, radius * lerp(1, .48, this.mix), 0, 0, Math.PI * 2); c.stroke();
    }
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i]; p.age += dt; if (p.age >= p.life) { this.particles.splice(i, 1); continue; }
      p.x += p.vx * dt; p.y += p.vy * dt; p.z += p.vz * dt; p.vz -= 7 * dt;
      const fade = 1 - p.age / p.life, pos = this._project(p.x, p.y, Math.max(.03, p.z));
      const size = Math.max(1.2, this.unit * p.size * fade);
      c.globalAlpha = fade;
      c.fillStyle = p.color;
      if (p.cube) { c.fillRect(pos.x - size / 2, pos.y - size / 2, size, size); c.fillStyle = alpha('#ffffff', .5); c.fillRect(pos.x - size / 2, pos.y - size / 2, size, Math.max(1, size * .25)); }
      else { c.beginPath(); c.arc(pos.x, pos.y, size * .6, 0, Math.PI * 2); c.fill(); }
    }
    c.globalAlpha = 1;
    for (let i = this.labels.length - 1; i >= 0; i--) {
      const label = this.labels[i]; label.age += dt; if (label.age >= label.life) { this.labels.splice(i, 1); continue; }
      const f = label.age / label.life, p = this._project(label.x, label.y, .9);
      c.globalAlpha = Math.min(1, (1 - f) * 3);
      c.font = `800 ${Math.max(12, this.flatSize * .28)}px "Space Grotesk", system-ui`; c.textAlign = 'center'; c.textBaseline = 'middle';
      c.lineWidth = 4; c.strokeStyle = '#102536'; c.strokeText(label.text, p.x, p.y - f * 26 - 12);
      c.fillStyle = label.color; c.fillText(label.text, p.x, p.y - f * 26 - 12);
    }
    c.globalAlpha = 1;
  }

  _pickups(dt) {
    const c = this.ctx;
    for (let i = this.pickups.length - 1; i >= 0; i--) {
      const pickup = this.pickups[i]; pickup.age += dt;
      if (pickup.age >= pickup.life) { this.pickups.splice(i, 1); continue; }
      const f = pickup.age / pickup.life, p = this._project(pickup.x, pickup.y, .35);
      // Feedback flies toward the resource / inventory rail; it never creates a
      // second interactive chest or changes when the simulation grants a drop.
      const travel = this.reducedMotion ? 0 : ease(clamp((f - (pickup.chest ? .56 : .18)) / (pickup.chest ? .44 : .82)));
      const x = lerp(p.x, this.w - 25, travel), y = lerp(p.y, 22, travel) - (this.reducedMotion ? 0 : Math.sin(Math.PI * f) * (pickup.chest ? 22 : 15));
      const fade = Math.min(1, (1 - f) * (pickup.chest ? 5 : 3));
      c.save(); c.globalAlpha = fade;
      this._glow(x, y, pickup.chest ? 27 : 12, pickup.color, pickup.chest ? .35 : .24);
      if (pickup.chest) {
        const size = 12 * (1 - travel * .5), bounce = this.reducedMotion ? 1 : 1 + Math.sin(f * Math.PI * 5) * .08 * (1 - f);
        c.translate(x, y); c.scale(bounce, 2 - bounce);
        c.fillStyle = '#13273a'; c.fillRect(-size, -size * .5, size * 2, size * 1.3);
        c.strokeStyle = pickup.color; c.lineWidth = 1.7; c.strokeRect(-size, -size * .5, size * 2, size * 1.3);
        c.fillStyle = pickup.color; c.fillRect(-size, -size * .56, size * 2, size * .3); c.fillRect(-2, -1, 4, 7);
        if (f < .55) {
          c.font = '800 9px "Space Grotesk", system-ui'; c.textAlign = 'center'; c.fillStyle = '#eefced'; c.fillText('CHEST FOUND', 0, -size - 8);
        }
      } else {
        const s = 3.5 * (1 - travel * .45);
        this._poly([{ x, y: y - s * 1.6 }, { x: x + s, y }, { x, y: y + s * 1.6 }, { x: x - s, y }], pickup.color);
      }
      c.restore();
    }
  }

  _annotations(state) {
    const c = this.ctx, t = this.mix;
    c.textAlign = 'center'; c.textBaseline = 'middle';
    c.font = '600 9px "Space Grotesk", system-ui';
    if (t < .9) {
      c.globalAlpha = (1 - t) * .6;
      c.fillStyle = '#afc9b3';
      for (let i = 0; i < 9; i++) {
        const top = this._project(i, -.5), left = this._project(-.5, i);
        c.fillText(String(i + 1).padStart(2, '0'), top.x, top.y - 14);
        if (this.w > 400) c.fillText(String.fromCharCode(65 + i), left.x - 15, left.y);
      }
    }
    if (t > .7 && state.route?.length > 1) {
      c.globalAlpha = (t - .7) / .3;
      const first = state.route[0], last = state.route[state.route.length - 1];
      const start = this._project(first.x, first.y), end = this._project(last.x, last.y);
      const pill = (p, label, color) => {
        c.font = '700 8px "Space Grotesk", system-ui';
        const width = c.measureText(label).width + 13;
        const x = clamp(p.x, width / 2 + 2, this.w - width / 2 - 2), y = clamp(p.y + 21, 12, this.h - 12);
        c.fillStyle = '#0b1a28'; c.fillRect(x - width / 2, y - 8, width, 16);
        c.fillStyle = color; c.fillText(label, x, y);
      };
      pill(start, 'BREACH', '#ffb085'); pill(end, 'CORE', '#83eed7');
    }
    c.globalAlpha = 1;
  }
}

export { PALETTE as TOWER_COLORS };
