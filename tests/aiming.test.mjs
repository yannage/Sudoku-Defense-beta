import test from 'node:test';
import assert from 'node:assert/strict';
import { Game } from '../dist/game/simulation.js';
import { VoxelRenderer, towerAimAngle, turnToward, towerMuzzle } from '../dist/engine/renderer.js';

const close = (a, b, epsilon = 1e-10) => assert.ok(Math.abs(a - b) < epsilon, `${a} should equal ${b}`);
function renderer(state = {}) {
  const r = Object.create(VoxelRenderer.prototype);
  Object.assign(r, { state, _aims: new Map(), _lastAimClock: null, beams: [], reducedMotion: false });
  return r;
}
function scenario() {
  const g = new Game('aim-regression');
  const cell = g.board.findIndex(n => !n); g.place(cell, g.solution[cell]);
  const t = g.towers[0]; t.growth = 1; t.cell = 40; t.cooldown = 0;
  g.phase = 'battle'; g._waveCount = 100; g._spawnClock = 100;
  g.enemies = [{ id: 200, x: 5, y: 4, hp: 100, maxHp: 100, kind: 'grunt', progress: 4, speed: 0, slowTime: 0, poisonTime: 0, poisonDps: 0 }, { id: 201, x: 5, y: 5, hp: 100, maxHp: 100, kind: 'grunt', progress: 3, speed: 0, slowTime: 0, poisonTime: 0, poisonDps: 0 }];
  g.drainEvents(); return g;
}

test('turret aim and muzzle transform cover every cardinal direction and quadrant', () => {
  for (let i = 0; i < 8; i++) {
    const a = i * Math.PI / 4, heading = towerAimAngle(4, 4, 4 + Math.cos(a), 4 + Math.sin(a));
    close(Math.cos(heading), Math.cos(a)); close(Math.sin(heading), Math.sin(a));
    const muzzle = towerMuzzle(4, 4, heading, 5);
    close(muzzle.x, 4 + Math.cos(a) * .39 + Math.sin(a) * .015);
    close(muzzle.y, 4 + Math.sin(a) * .39 - Math.cos(a) * .015);
    close(muzzle.z, 1.3875);
  }
  close(towerAimAngle(4, 4, 4, 4, .8), .8);
  close(towerAimAngle(4, 4, NaN, 4, .8), .8);
  assert.ok(Object.values(towerMuzzle(NaN, Infinity, NaN, NaN)).every(Number.isFinite));
});

test('tracking takes the shortest turn across pi and reduced motion snaps to aim', () => {
  const from = Math.PI - .1, to = -Math.PI + .1;
  const result = turnToward(from, to, .01);
  assert.ok(result > from && result < Math.PI, 'must turn 0.2 radians through pi, not spin backward almost a full circle');
  close(turnToward(from, to, 0, true), to);
  close(turnToward(.7, 2, 0), .7);
  assert.ok(Number.isFinite(turnToward(NaN, Infinity, NaN)));
});

test('primary shot captures actual target before death; lightning hops cannot re-aim the tower', () => {
  const g = scenario(), tower = g.towers[0], target = g.enemies[0];
  tower.attachments = [{ kind: 'electric', power: 1 }]; target.hp = 1;
  const r = renderer(g); r._updateAim(g, .016);
  g._fire(tower, target);
  const shots = g.drainEvents().filter(e => e.type === 'shot');
  assert.equal(tower.aimTargetId, target.id); assert.equal(tower.aimX, 5); assert.equal(tower.aimY, 4); close(tower.aimAngle, 0);
  assert.ok(target.hp <= 0); assert.equal(shots.length, 2);
  for (const event of shots) r.burst(event);
  close(r._aims.get(tower.id).angle, 0);
  assert.equal(shots[1].towerId, undefined); assert.equal(shots[1].cell, undefined);
  close(r.beams[0].x, 4.39); close(r.beams[0].y, 3.985); close(r.beams[0].height, .6675);
  close(r.beams[1].x, 5); close(r.beams[1].y, 4);
  r._updateAim(g, .05); close(r._aims.get(tower.id).angle, 0);
});

test('live targets are tracked, paused simulation clocks hold facing, dead targets hold last heading', () => {
  const tower = { id: 1, cell: 40, number: 1, aimAngle: 0, aimTargetId: 10 };
  const target = { id: 10, x: 4, y: 6, hp: 10 };
  const state = { phase: 'battle', towers: [tower], enemies: [target], _clock: 1 };
  const r = renderer(state); r._updateAim(state, .02);
  const first = r._aims.get(1).angle; assert.ok(first > 0 && first < Math.PI / 2);
  r._updateAim(state, .05); close(r._aims.get(1).angle, first);
  state._clock += .05; r._updateAim(state, .05); assert.ok(r._aims.get(1).angle > first);
  target.hp = 0; const last = r._aims.get(1).angle;
  state._clock += .05; r._updateAim(state, .05); close(r._aims.get(1).angle, last);
  target.hp = 10; r.reducedMotion = true; state._clock += .05; r._updateAim(state, .05); close(r._aims.get(1).angle, Math.PI / 2);
  state.towers = [{ id: 1, cell: 40, number: 1 }]; r._updateAim(state, .05); close(r._aims.get(1).angle, 0);
  state.towers = []; r._updateAim(state, .05); assert.equal(r._aims.size, 0);
});

test('legacy saves without aiming metadata restore and fire; aim metadata cannot change combat or RNG', () => {
  const old = scenario(), modern = Game.fromSave(old.exportSave());
  const restored = Game.fromSave(JSON.stringify(old.exportSave()));
  assert.equal(restored.towers[0].aimAngle, undefined);
  const r = renderer(restored); r._updateAim(restored, .016); close(r._aims.get(restored.towers[0].id).angle, 0);
  Object.assign(modern.towers[0], { aimTargetId: -100, aimX: -500, aimY: 800, aimAngle: -2 });
  const rng = old.rng.getState();
  old._fire(old.towers[0], old.enemies[0]); modern._fire(modern.towers[0], modern.enemies[0]);
  assert.equal(old.rng.getState(), rng, 'visual aiming cannot draw random numbers');
  assert.deepEqual(old.exportSave(), modern.exportSave()); assert.deepEqual(old.drainEvents(), modern.drainEvents());
  for (let i = 0; i < 40; i++) { old.update(.05); modern.update(.05); }
  assert.deepEqual(old.exportSave(), modern.exportSave()); assert.deepEqual(old.drainEvents(), modern.drainEvents());
  const saved = Game.fromSave(old.exportSave()); assert.deepEqual(saved.exportSave(), old.exportSave());
});
