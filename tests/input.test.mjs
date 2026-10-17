import test from 'node:test';
import assert from 'node:assert/strict';
import { GamepadInput } from '../dist/engine/input.js';
import { AudioEngine } from '../dist/engine/audio.js';

function harness(t) {
  const original = Object.getOwnPropertyDescriptor(globalThis, 'navigator');
  const pad = {
    connected: true, index: 0, id: 'Standard controller', axes: [0, 0],
    buttons: Array.from({ length: 16 }, () => ({ pressed: false, value: 0 }))
  };
  let pads = [pad];
  Object.defineProperty(globalThis, 'navigator', {
    configurable: true, value: { getGamepads: () => pads }
  });
  t.after(() => {
    if (original) Object.defineProperty(globalThis, 'navigator', original);
    else delete globalThis.navigator;
  });
  const calls = [];
  const input = new GamepadInput({
    onMove: (x, y) => calls.push(['move', x, y]),
    onNumber: delta => calls.push(['number', delta]),
    onAction: action => calls.push(['action', action]),
    onPause: () => calls.push(['pause']),
    onHelp: () => calls.push(['help'])
  });
  return { pad, input, calls, pads: value => { pads = value; } };
}

test('standard buttons emit one action per press, including buying and closing dialogs', t => {
  const { pad, input, calls } = harness(t);
  input.update(1 / 60);
  const mappings = [
    [0, ['action', 'place']], [1, ['action', 'back']],
    [2, ['action', 'hint']], [3, ['action', 'phase']],
    [6, ['action', 'sound']], [7, ['action', 'buy']], [8, ['help']], [9, ['pause']]
  ];
  for (const [button, expected] of mappings) {
    pad.buttons[button].pressed = true;
    input.update(1 / 60);
    assert.deepEqual(calls.splice(0), [expected]);
    for (let i = 0; i < 90; i++) input.update(1 / 60);
    assert.deepEqual(calls, [], 'holding an action must not repeat a purchase or placement');
    pad.buttons[button].pressed = false;
    input.update(1 / 60);
  }
});

test('D-pad moves immediately, waits before repeating, and cancels on release', t => {
  const { pad, input, calls } = harness(t);
  pad.buttons[15].pressed = true;
  input.update(1 / 60);
  assert.deepEqual(calls.splice(0), [['move', 1, 0]]);
  for (let i = 0; i < 17; i++) input.update(1 / 60);
  assert.deepEqual(calls, []);
  for (let i = 0; i < 2; i++) input.update(1 / 60);
  assert.deepEqual(calls.splice(0), [['move', 1, 0]]);
  pad.buttons[15].pressed = false;
  for (let i = 0; i < 90; i++) input.update(1 / 60);
  assert.deepEqual(calls, []);
});

test('stick deadzone ignores drift and diagonal aim selects one cardinal cell', t => {
  const { pad, input, calls } = harness(t);
  pad.axes = [.12, -.08];
  input.update(.016);
  assert.deepEqual(calls, []);
  pad.axes = [-.85, .5];
  input.update(.016);
  assert.deepEqual(calls.splice(0), [['move', -1, 0]]);
  pad.axes = [-.6, -.95];
  input.update(.016);
  assert.deepEqual(calls.splice(0), [['move', 0, -1]]);
});

test('shoulders select numbers and analog RT purchases exactly once until released', t => {
  const { pad, input, calls } = harness(t);
  pad.buttons[4].pressed = true;
  input.update(.016);
  assert.deepEqual(calls.splice(0), [['number', -1]]);
  pad.buttons[4].pressed = false;
  pad.buttons[5].pressed = true;
  input.update(.016);
  assert.deepEqual(calls.splice(0), [['number', 1]]);
  pad.buttons[5].pressed = false;
  pad.buttons[7].value = .85;
  input.update(.016);
  assert.deepEqual(calls.splice(0), [['action', 'buy']]);
  input.update(.016);
  assert.deepEqual(calls, []);
  pad.buttons[7].value = .1;
  input.update(.016);
  pad.buttons[7].value = .8;
  input.update(.016);
  assert.deepEqual(calls.splice(0), [['action', 'buy']]);
});

test('controller remains stable, disconnects cleanly, and survives Gamepad API policy errors', t => {
  const { pad, input, calls, pads } = harness(t);
  input.update(.016);
  assert.equal(input.connected, true);
  assert.equal(input.id, pad.id);
  pads([{ ...pad, index: 1, id: 'Second controller' }, pad]);
  input.update(.016);
  assert.equal(input.index, 0);
  pads([]);
  input.update(.016);
  assert.equal(input.connected, false);
  assert.equal(input.index, -1);
  navigator.getGamepads = () => { throw new Error('Permissions Policy blocks gamepad'); };
  assert.doesNotThrow(() => input.update(.016));
  assert.deepEqual(calls, []);
});

test('audio gracefully declines playback when Web Audio is unavailable', async () => {
  const audio = new AudioEngine();
  assert.equal(await audio.unlock(), false);
  assert.doesNotThrow(() => {
    audio.play('place');
    audio.update(.016, 'battle');
    audio.setMuted(true);
    audio.stop();
  });
});
