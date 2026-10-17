/**
 * GRIDFALL / voxel canvas renderer
 * A dependency-free, resolution-independent presentation layer. The simulation
 * owns the state; this module owns projection, picking, and short-lived FX.
 */
const PALETTE = ['#6de8ff', '#a4c7ff', '#c6a0ff', '#ffae68', '#fb86c3', '#9be878', '#ffe188', '#bb9bff', '#ff7289'];
const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const lerp = (a, b, t) => a + (b - a) * t;
const ease = t => t * t * (3 - 2 * t);
const finite = (v, fallback = 0) => Number.isFinite(v) ? v : fallback;
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
    this.particles = []; this.rings = []; this.labels = []; this.beams = [];
    this.state = {}; this.shake = 0; this.flash = 0; this.reducedMotion = false;
    this._frame = 0; this._lastPhase = null;
    this._click = event => { const cell = this.cellAt(event.clientX, event.clientY); if (cell !== null && this.onCell) this.onCell(cell); };
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
    this.flatSize = Math.max(12, Math.min((this.w - (compact ? 24 : 66)) / 9, (this.h - 74) / 9));
    this.isoSize = Math.max(10, Math.min((this.w - (compact ? 24 : 60)) / 18, (this.h - 96) / 10.6));
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

  _glow(x, y, radius, color, opacity = .4) {
    if (radius < .5 || opacity <= 0) return;
    const c = this.ctx, g = c.createRadialGradient(x, y, 0, x, y, radius);
    g.addColorStop(0, alpha(color, opacity)); g.addColorStop(.3, alpha(color, opacity * .4)); g.addColorStop(1, alpha(color, 0));
    c.fillStyle = g; c.fillRect(x - radius, y - radius, radius * 2, radius * 2);
  }

  burst(event = {}) {
    const type = event.type || 'hit', cell = Number.isInteger(event.cell) ? event.cell : null;
    const x = finite(event.x, cell === null ? 4 : cell % 9), y = finite(event.y, cell === null ? 4 : Math.floor(cell / 9));
    const color = event.color || PALETTE[(event.number || 2) - 1] || '#66eafa';
    if (type === 'shot') {
      this.beams.push({ x, y, tx: finite(event.targetX, x), ty: finite(event.targetY, y), color, number: event.number || 1, age: 0, life: event.number === 5 ? .3 : .18 });
      return;
    }
    const big = ['kill', 'explosion', 'wave', 'win'].includes(type);
    const invalid = type === 'invalid';
    if (type === 'phase' || type === 'path' || type === 'buy') return;
    const finalColor = invalid ? '#ff6e87' : color;
    const count = this.reducedMotion ? (big ? 5 : 2) : big ? 24 : type === 'place' ? 14 : 7;
    for (let i = 0; i < count && this.particles.length < 320; i++) {
      const seed = ++this._frame * 3.721 + i;
      const angle = hash(seed) * Math.PI * 2, speed = .4 + hash(seed + 7) * (big ? 2.3 : 1.25);
      this.particles.push({ x, y, z: type === 'place' ? .04 : .35, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed, vz: 1.2 + hash(seed + 13) * 2.6, color: finalColor, size: .035 + hash(seed + 2) * .09, age: 0, life: .45 + hash(seed + 1) * .55, cube: i % 3 !== 0 });
    }
    if (big || type === 'place' || invalid || type === 'leak') this.rings.push({ x, y, color: finalColor, age: 0, life: big ? .65 : .42, size: Number.isFinite(event.radius) ? event.radius : big ? 1.8 : .85, inward: event.number === 8 });
    if (event.text) this.labels.push({ x, y, text: String(event.text), color: finalColor, age: 0, life: 1.1 });
    if (!this.reducedMotion) {
      if (type === 'explosion' || type === 'leak') this.shake = Math.max(this.shake, type === 'leak' ? 5 : 3);
      if (type === 'wave' || type === 'win') this.flash = .13;
    }
  }

  render(state = {}, dt = 1 / 60, time = 0) {
    this.state = state;
    if (dt > 2) dt /= 1000;
    dt = clamp(dt, 0, .05);
    this.time += dt;
    const battle = ['battle', 'reward', 'lost', 'won'].includes(state.phase);
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
    if (this.flash > .002) { c.fillStyle = alpha('#c9f5ff', this.flash); c.fillRect(0, 0, this.w, this.h); this.flash *= Math.exp(-dt * 10); }
    this._lastPhase = state.phase;
  }

  _background() {
    const c = this.ctx, w = this.w, h = this.h;
    c.fillStyle = '#09111c'; c.fillRect(0, 0, w, h);
    const glow = c.createRadialGradient(w * .51, h * .47, 20, w * .5, h * .5, Math.max(w, h) * .7);
    glow.addColorStop(0, '#172b3a'); glow.addColorStop(.5, '#0d1b28'); glow.addColorStop(1, '#08101a');
    c.fillStyle = glow; c.fillRect(0, 0, w, h);
    // A quiet coordinate field keeps the board grounded without a costly texture.
    c.fillStyle = 'rgba(132,173,182,.11)';
    for (let x = 22; x < w; x += 28) for (let y = 18; y < h; y += 28) c.fillRect(x, y, 1, 1);
    for (let i = 0; i < 28; i++) {
      const speed = this.reducedMotion ? 0 : this.time * (1.5 + hash(i + 800) * 3);
      const x = hash(i + 101) * w, y = (hash(i + 200) * h - speed % h + h) % h;
      const flicker = .1 + .15 * Math.sin(this.time * .5 + i);
      c.fillStyle = alpha(i % 4 ? '#86b5c9' : '#ffcc83', Math.max(.03, flicker));
      c.fillRect(x, y, i % 5 === 0 ? 2 : 1, i % 5 === 0 ? 2 : 1);
    }
  }

  _board(state) {
    const c = this.ctx, t = this.mix;
    const towerMap = new Map((state.towers || []).map(tower => [tower.cell, tower]));
    const selected = Number.isInteger(state.selectedCell) ? state.selectedCell : -1;
    const sx = selected % 9, sy = Math.floor(selected / 9);
    const recent = new Set((state.recentMoves || []).map(m => typeof m === 'number' ? m : m.cell));
    const selectedNumber = state.selectedNumber || (state.board || [])[selected];
    const corners = [this._project(-.62, -.62), this._project(8.62, -.62), this._project(8.62, 8.62), this._project(-.62, 8.62)];

    // Ambient shadow, then the sculpted floating-island foundation.
    const groundY = this.cy + this.isoSize * 2.8 * t;
    c.save(); c.translate(this.cx, groundY); c.scale(1, lerp(1, .31, t));
    const shadow = c.createRadialGradient(0, 0, 0, 0, 0, this.flatSize * 5.1);
    shadow.addColorStop(0, 'rgba(0,0,0,.64)'); shadow.addColorStop(1, 'rgba(0,0,0,0)');
    c.fillStyle = shadow; c.fillRect(-this.flatSize * 5.1, -this.flatSize * 5.1, this.flatSize * 10.2, this.flatSize * 10.2); c.restore();
    this._poly(corners, mix('#59717d', '#284557', t), alpha('#a7d8df', .25), 1);
    if (t > .01) {
      c.globalAlpha = t;
      for (let i = 0; i < 9; i++) {
        this._cube(i, 8, -.46 - hash(i + 4) * .2, .99, .99, .43 + hash(i + 4) * .2, i % 3 === 0 ? '#345a67' : '#284553');
        this._cube(8, 8 - i, -.46 - hash(i + 81) * .2, .99, .99, .43 + hash(i + 81) * .2, i % 3 === 1 ? '#345a67' : '#243d50');
      }
      for (let i = 0; i < 5; i++) {
        const p = this._project(i * 1.65 + .3, 8.3, -.55 - .12 * hash(i + 40));
        this._glow(p.x, p.y, this.isoSize * .44, i % 2 ? '#4acbbd' : '#6b9ad3', .13);
      }
      c.globalAlpha = 1;
    }

    for (let depth = 0; depth <= 16; depth++) {
      for (let y = 0; y < 9; y++) {
        const x = depth - y; if (x < 0 || x > 8) continue;
        const cell = y * 9 + x, value = (state.board || [])[cell] || 0, tower = towerMap.get(cell);
        const block = (Math.floor(x / 3) + Math.floor(y / 3)) % 2;
        const isSelected = cell === selected;
        const allied = selected >= 0 && (x === sx || y === sy || (Math.floor(x / 3) === Math.floor(sx / 3) && Math.floor(y / 3) === Math.floor(sy / 3)));
        let flatColor = block ? '#e3eae7' : '#f0f1e8';
        if (allied) flatColor = block ? '#c9e1df' : '#d5e8e2';
        if (selectedNumber && value === selectedNumber) flatColor = '#b9dedc';
        if (isSelected) flatColor = '#96d8d5';
        let combatColor = block ? '#355561' : '#40636a';
        if (!value) combatColor = block ? '#254451' : '#2c4c55';
        if (tower) combatColor = tower.illegal ? '#603d52' : '#48666b';
        if (isSelected) combatColor = '#4a9295';
        const inset = .012 + t * .026;
        const pts = this._tile(x, y, inset);
        this._poly(pts, mix(flatColor, combatColor, t));
        if (t > .3) {
          c.globalAlpha = t * .5;
          c.beginPath(); c.moveTo(pts[3].x, pts[3].y); c.lineTo(pts[0].x, pts[0].y); c.lineTo(pts[1].x, pts[1].y);
          c.strokeStyle = '#73958c'; c.lineWidth = 1; c.stroke(); c.globalAlpha = 1;
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
      }
    }

    // True 3×3 separators remain recognizable during the projection change.
    for (const n of [-.5, 2.5, 5.5, 8.5]) {
      for (const points of [[this._project(n, -.5), this._project(n, 8.5)], [this._project(-.5, n), this._project(8.5, n)]]) {
        c.beginPath(); c.moveTo(points[0].x, points[0].y); c.lineTo(points[1].x, points[1].y);
        c.lineWidth = lerp(2.2, 2.7, t); c.strokeStyle = mix('#41656a', '#142b3c', t); c.stroke();
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
    const phase = this.reducedMotion ? 0 : Math.sin(this.time * 3 + tower.cell * .7);
    const dark = '#405564', mid = shade(color, .73);
    const base = this._project(x, y, .025);
    c.fillStyle = 'rgba(3,12,24,.25)'; c.beginPath(); c.ellipse(base.x, base.y + 3, this.isoSize * .46, this.isoSize * .2, 0, 0, Math.PI * 2); c.fill();
    this._cube(x, y, .035, .61, .61, .1, dark, true);
    this._cube(x, y, .135, .47, .47, .085, mid, true);
    const cube = (dx, dy, z, w, d, h, col = color) => this._cube(x + dx, y + dy, z, w, d, h, col, true);
    let tip = .85;
    switch (n) {
      case 1: // Bolt: amber brass turret with a square muzzle.
        cube(0, 0, .22, .27, .27, .32, dark);
        cube(0, 0, .52, .39, .34, .2);
        cube(.27, -.03, .56, .42, .14, .11, mid);
        cube(.47, -.03, .555, .055, .18, .13, '#ffeaa7');
        tip = .74; break;
      case 2: // Frost: glowing stepped ice crystal.
        cube(0, 0, .22, .27, .27, .2, dark);
        cube(0, 0, .42, .32, .32, .24);
        cube(0, 0, .66, .21, .21, .24, '#cbfcff');
        cube(0, 0, .9, .105, .105, .13);
        cube(-.2, .05, .3, .1, .1, .27, mid); tip = 1.04; break;
      case 4: // Mortar: squat twin launcher and hot core.
        cube(0, 0, .22, .4, .4, .24, dark);
        cube(-.12, -.1, .44, .19, .2, .31, mid);
        cube(.13, .12, .44, .19, .2, .31);
        cube(-.12, -.1, .75, .14, .15, .045, '#392c38');
        cube(.13, .12, .75, .14, .15, .045, '#ffddb2'); tip = .8; break;
      case 3: // Arc: spire with a floating charged prism.
        cube(0, 0, .22, .17, .17, .54, dark);
        cube(0, 0, .34, .38, .38, .08, mid);
        cube(0, 0, .65, .33, .33, .085);
        cube(0, 0, .85 + phase * .035, .24, .24, .22, '#dfc9ff'); tip = 1.12; break;
      case 6: // Venom: glass flask carried in a metal cage.
        cube(0, 0, .22, .31, .31, .38, mid);
        cube(0, 0, .6, .18, .18, .2);
        cube(0, 0, .8, .29, .29, .075, '#d6ffc1');
        cube(-.2, -.2, .22, .075, .075, .47, dark);
        cube(.2, .2, .22, .075, .075, .47, dark); tip = .9; break;
      case 7: // Beacon: a cross-shaped radiant amplifier.
        cube(0, 0, .22, .19, .19, .45, dark);
        cube(0, 0, .5, .5, .18, .15);
        cube(0, 0, .5, .18, .5, .15);
        cube(0, 0, .65, .18, .18, .29, '#fff0ba'); tip = .95; break;
      case 5: // Prism: a long-range beam on a high watchtower.
        cube(0, 0, .22, .2, .2, .63, dark);
        cube(0, 0, .58, .35, .35, .09, mid);
        cube(.08, 0, .84, .48, .23, .16);
        cube(.37, 0, .89, .34, .095, .07, '#d0e7ff'); tip = 1.02; break;
      case 8: { // Gravity: dark suspended core and four orbiting blocks.
        cube(0, 0, .22, .2, .2, .28, dark);
        cube(0, 0, .56 + phase * .045, .28, .28, .28, mid);
        const spin = this.reducedMotion ? .3 : this.time * .7;
        for (let i = 0; i < 4; i++) {
          const a = spin + i * Math.PI / 2;
          cube(Math.cos(a) * .32, Math.sin(a) * .32, .69 + Math.sin(a) * .1, .11, .11, .11, color);
        }
        tip = .98; break;
      }
      case 9: // Nova: radiant core suspended between two pylons.
        cube(-.2, -.1, .22, .12, .13, .62, mid);
        cube(.2, .1, .22, .12, .13, .62, mid);
        cube(0, 0, .68 + phase * .055, .29, .29, .29, '#f5eaff');
        cube(0, 0, .96 + phase * .055, .14, .14, .14); tip = 1.12; break;
    }
    const top = this._project(x, y, tip);
    this._glow(top.x, top.y, this.isoSize * .54, color, .13 + (phase + 1) * .035);
    // Number badge keeps the transformation tactically legible.
    const badge = this._project(x, y + .31, .08);
    const radius = Math.max(5, this.isoSize * .15);
    c.fillStyle = '#102536'; c.beginPath(); c.arc(badge.x, badge.y, radius, 0, Math.PI * 2); c.fill();
    c.fillStyle = color; c.font = `800 ${Math.max(7, this.isoSize * .24)}px "Space Grotesk", system-ui`; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText(n, badge.x, badge.y + .3);
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
    for (let i = this.beams.length - 1; i >= 0; i--) {
      const b = this.beams[i]; b.age += dt; if (b.age >= b.life) { this.beams.splice(i, 1); continue; }
      const p = this._project(b.x, b.y, .75), q = this._project(b.tx, b.ty, .22), fade = 1 - b.age / b.life;
      c.save(); c.globalAlpha = fade * this.mix; c.lineCap = 'round';
      c.beginPath(); c.moveTo(p.x, p.y);
      if (b.number === 3) {
        for (let s = 1; s < 5; s++) { const f = s / 5; c.lineTo(lerp(p.x, q.x, f) + (s % 2 ? 1 : -1) * 5, lerp(p.y, q.y, f) + (s % 2 ? -1 : 1) * 3); }
      }
      c.lineTo(q.x, q.y);
      c.strokeStyle = alpha(b.color, .18); c.lineWidth = b.number === 5 ? 9 : 6; c.stroke();
      c.strokeStyle = b.color; c.lineWidth = b.number === 5 ? 2.7 : 1.5; c.stroke();
      c.strokeStyle = '#f3fff8'; c.lineWidth = .7; c.stroke();
      this._glow(q.x, q.y, 15, b.color, .38); c.restore();
    }
    for (let i = this.rings.length - 1; i >= 0; i--) {
      const r = this.rings[i]; r.age += dt; if (r.age >= r.life) { this.rings.splice(i, 1); continue; }
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

  _annotations(state) {
    const c = this.ctx, t = this.mix;
    c.textAlign = 'center'; c.textBaseline = 'middle';
    c.font = '600 9px "Space Grotesk", system-ui';
    if (t < .9) {
      c.globalAlpha = (1 - t) * .6;
      c.fillStyle = '#99b2b9';
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
