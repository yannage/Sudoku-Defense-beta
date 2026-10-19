/**
 * Scripted capture of the shipping game, using its unmodified simulation and
 * renderer. The campaign setup is earned by playing nine complete rounds;
 * every visible seed and module is placed through the game's public actions.
 * No synthetic enemies, reward drops, damage, or combat statistics are used.
 */
import { createRequire } from 'node:module';
import { Game, TOWERS } from '../dist/game/simulation.js';
import { VoxelRenderer } from '../dist/engine/renderer.js';

const require = createRequire(import.meta.url);
let savedCampaign;

function nativeCanvas() {
  try { return require('@napi-rs/canvas').createCanvas; } catch {}
  const modules = process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES;
  if (modules) return require(`${modules}/@napi-rs/canvas`).createCanvas;
  throw new Error('Install @napi-rs/canvas to render the trailer.');
}

function assertAction(result, action) {
  if (!result?.ok) throw new Error(`Capture action ${action}: ${result?.message}`);
  return result;
}

/** Play normal rounds to earn the inventory shown in the capture. */
function campaign() {
  if (savedCampaign) return Game.fromSave(savedCampaign);
  const game = new Game('sudoku-defense-sizzle-2026', {
    mode: 'campaign', sudokuDifficulty: 'medium', combatDifficulty: 'medium',
  });
  while (game.wave < 10) {
    for (let cell = 0; cell < 81; cell++) {
      if (!game.board[cell]) assertAction(game.place(cell, game.solution[cell]), 'campaign solve');
    }
    assertAction(game.endSolve(), 'campaign preparation');
    assertAction(game.startBattle(), 'campaign battle');
    for (let frame = 0; frame < 7200 && game.phase === 'battle'; frame++) {
      game.update(1 / 30);
      game.drainEvents();
    }
    if (game.phase !== 'loot') throw new Error(`Campaign setup failed at round ${game.wave}.`);
    // Purchases and unlocks spend credits and fragments earned by these rounds.
    if (game.credits > 320 && game.fragments >= 14) assertAction(game.buyChest('epic'), 'campaign cache');
    for (const chest of [...game.chests].sort((a, b) => b.cost - a.cost)) {
      if (game.fragments >= chest.cost) assertAction(game.openChest(chest.id), 'campaign unlock');
    }
    assertAction(game.nextWave(), 'campaign advance');
  }
  game.drainEvents();
  savedCampaign = game.exportSave();
  return Game.fromSave(savedCampaign);
}

function placementOrder(game) {
  // Spread real solved squares across the board. Recent moves steer the road.
  const anchors = [10, 22, 46, 58, 30, 52, 67, 16, 37, 61, 73, 25, 41, 55, 7, 69];
  const remaining = new Set(game.board.flatMap((number, cell) => number ? [] : [cell]));
  return anchors.map(anchor => {
    const x = anchor % 9, y = Math.floor(anchor / 9);
    const cell = [...remaining].sort((a, b) => {
      const da = Math.hypot(a % 9 - x, Math.floor(a / 9) - y);
      const db = Math.hypot(b % 9 - x, Math.floor(b / 9) - y);
      return da - db || a - b;
    })[0];
    remaining.delete(cell);
    return cell;
  });
}

export const GAMEPLAY_TIMING = Object.freeze({ solve: 0, prep: 6, battle: 11 });

/**
 * Advance monotonically with step(seconds); renderAt resets when seeking back.
 * Canvas is the actual VoxelRenderer output. Metadata is available for titles,
 * HUD overlays, sound synchronization, and optional editorial closeups.
 */
export function createGameplay({ width = 1280, height = 800, fps = 30, createCanvas = nativeCanvas() } = {}) {
  if (!(width > 0 && height > 0 && fps > 0)) throw new Error('Positive capture dimensions and FPS are required.');
  const canvas = createCanvas(width, height);
  canvas.getBoundingClientRect = () => ({ width, height, left: 0, top: 0 });
  canvas.addEventListener = () => {};
  canvas.removeEventListener = () => {};
  let game, renderer, schedule, cursor, frame, selectedCell, selectedNumber, lastEvents, allEvents;

  function reset() {
    renderer?.destroy();
    game = campaign();
    renderer = new VoxelRenderer(canvas);
    const cells = placementOrder(game);
    selectedCell = cells[0]; selectedNumber = game.solution[selectedCell];
    cursor = 0; frame = 0; lastEvents = []; allEvents = [];
    schedule = cells.map((cell, index) => ({
      at: .3 + index * .34,
      action() {
        selectedCell = cell; selectedNumber = game.solution[cell];
        assertAction(game.place(cell, selectedNumber), 'visible seed');
      },
    }));
    schedule.push({ at: 6, action: () => assertAction(game.endSolve(), 'visible preparation') });
    // Choose earned modules by effect, so several real weapon styles are visible.
    const available = [...game.items].filter(item => item.type === 'attachment');
    const kinds = ['electric', 'rapid', 'frost', 'blast', 'venom', 'gravity', 'nova', 'range', 'power'];
    const modules = [];
    for (let pass = 0; pass < 2; pass++) for (const kind of kinds) {
      const index = available.findIndex(item => item.kind === kind);
      if (index >= 0) modules.push(available.splice(index, 1)[0]);
    }
    modules.slice(0, 18).forEach((item, index) => {
      // Two modules per tower create the physical stack shown in the real UI.
      const cell = cells[index % 8];
      schedule.push({ at: 6.75 + index * .2, action() {
        selectedCell = cell; selectedNumber = game.solution[cell];
        assertAction(game.equipItem(cell, item.id), 'visible module');
      } });
    });
    schedule.push({ at: 11, action: () => assertAction(game.startBattle(), 'visible battle') });
    for (const at of [17.15, 18.2]) schedule.push({ at, action() {
      const entrance = game.route[0];
      const blanks = game.board.flatMap((number, cell) => number ? [] : [cell]);
      const distanceFromEntrance = cell => Math.hypot(cell % 9 - entrance.x, Math.floor(cell / 9) - entrance.y);
      const cell = blanks.sort((a, b) => distanceFromEntrance(a) - distanceFromEntrance(b) || a - b)[0];
      if (cell === undefined) throw new Error('The capture needs a blank for an emergency seed.');
      // Duplicate an existing row number so this visibly breaks Sudoku rules.
      // The normal purchase and battle-placement APIs charge the seed and apply
      // corruption; enemies retain their ordinary model-generated statistics.
      const rowStart = Math.floor(cell / 9) * 9;
      const number = game.board.slice(rowStart, rowStart + 9).find(value => value && value !== game.solution[cell]);
      if (!number) throw new Error('The emergency seed needs a conflicting row number.');
      assertAction(game.buy(number), 'emergency reserve purchase');
      const result = assertAction(game.place(cell, number), 'emergency seed');
      if (!result.illegal) throw new Error('The emergency seed must incur corruption.');
      selectedCell = cell; selectedNumber = number;
    } });
    schedule.sort((a, b) => a.at - b.at);
    render(0, 0);
  }

  function render(dt, time) {
    renderer.render({ ...game, selectedCell, selectedNumber, towerColors: TOWERS.map(tower => tower.color) }, dt, time);
  }

  function step(seconds) {
    const target = Math.max(0, Math.round(seconds * fps));
    if (target < frame) throw new Error('Use renderAt(time) to seek backward.');
    lastEvents = [];
    while (frame < target) {
      frame++;
      const time = frame / fps;
      while (cursor < schedule.length && schedule[cursor].at <= time + 1e-8) {
        schedule[cursor++].action();
      }
      game.update(1 / fps);
      const events = game.drainEvents();
      for (const event of events) {
        const recorded = { ...event, time };
        lastEvents.push(recorded); allEvents.push(recorded);
        renderer.burst({ ...event, text: event.type === 'equip' ? '' : ({ chestOpen: 'LOOT RECOVERED', itemUsed: 'BOOST ACTIVATED' })[event.type] || event.text });
      }
      render(1 / fps, time);
    }
    return { phase: game.phase, selectedCell, selectedNumber, events: lastEvents, time: frame / fps };
  }

  reset();
  return {
    canvas,
    get game() { return game; },
    get renderer() { return renderer; },
    get events() { return allEvents; },
    get selectedCell() { return selectedCell; },
    get selectedNumber() { return selectedNumber; },
    step,
    renderAt(seconds) { if (Math.round(seconds * fps) < frame) reset(); return step(seconds); },
    pointForCell(cell, height = 0) { return renderer._project(cell % 9, Math.floor(cell / 9), height); },
    summary() {
      return {
        time: frame / fps, phase: game.phase, wave: game.wave,
        towers: game.towers.length, enemies: game.enemies.length,
        shots: allEvents.filter(event => event.type === 'shot').length,
        kills: allEvents.filter(event => event.type === 'kill').length,
        drops: allEvents.filter(event => event.type === 'chestDrop').length,
        modules: game.towers.reduce((sum, tower) => sum + tower.attachments.length, 0),
        equippedKinds: [...new Set(game.towers.flatMap(tower => tower.attachments.map(item => item.kind)))],
        health: game.health, fragments: game.fragments, chests: game.chests.length,
        illegalTowers: game.towers.filter(tower => tower.illegal).length, corruption: game.corruption,
      };
    },
  };
}
