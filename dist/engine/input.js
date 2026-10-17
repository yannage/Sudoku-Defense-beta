/**
 * Standard Gamepad API adapter. Poll once per animation frame with seconds.
 * No global keyboard handlers are registered.
 *
 * const input = new GamepadInput({
 *   onMove: (dx, dy) => moveCursor(dx, dy),
 *   onNumber: delta => selectNumberDelta(delta), // UI owns selected number
 *   onAction: action => handleAction(action),
 *   onPause: () => togglePause(), onHelp: () => toggleHelp()
 * });
 * input.update(deltaSeconds);
 * input.connected; // boolean; input.id is the active controller label
 *
 * D-pad / left stick: cursor; LB / RB: previous / next number.
 * A: place; B: back / close dialog; X: hint; Y: switch phase.
 * RT: buy one reserve of the selected number.
 * Start / Menu: pause; Select / View: help.
 * Steam Deck should use the standard Gamepad controller layout.
 */
export class GamepadInput {
  constructor({ onMove, onNumber, onAction, onPause, onHelp, deadzone = .38, initialDelay = .3, repeatDelay = .105 } = {}) {
    this.onMove = onMove || (() => {});
    this.onNumber = onNumber || (() => {});
    this.onAction = onAction || (() => {});
    this.onPause = onPause || (() => {});
    this.onHelp = onHelp || (() => {});
    this.deadzone = deadzone;
    this.initialDelay = initialDelay;
    this.repeatDelay = repeatDelay;
    this.connected = false;
    this.id = '';
    this.index = -1;
    this._pressed = [];
    this._direction = '';
    this._moveClock = 0;
    this._numberDirection = 0;
    this._numberClock = 0;
  }

  _reset() {
    this._pressed = [];
    this._direction = '';
    this._moveClock = 0;
    this._numberDirection = 0;
    this._numberClock = 0;
  }

  update(dt) {
    let pads;
    try {
      if (!globalThis.navigator?.getGamepads) return this._disconnect();
      pads = Array.from(globalThis.navigator.getGamepads() || []);
    } catch { return this._disconnect(); }
    // Keep the current controller stable while other controllers connect.
    const pad = pads.find(item => item?.connected && item.index === this.index)
      || pads.find(item => item?.connected);
    if (!pad) return this._disconnect();
    const label = pad.id || 'Game controller';
    if (this.index !== pad.index || this.id !== label) this._reset();
    this.connected = true;
    this.index = pad.index;
    this.id = label;
    const elapsed = Math.max(0, Math.min(.1, Number(dt) || 0));
    const pressed = index => {
      const button = pad.buttons?.[index];
      return typeof button === 'number' ? button > .5 : Boolean(button?.pressed || button?.value > .5);
    };
    const buttons = Array.from({ length: 16 }, (_, index) => pressed(index));
    let dx = Number(buttons[15]) - Number(buttons[14]);
    let dy = Number(buttons[13]) - Number(buttons[12]);
    if (!dx && !dy) {
      const x = Number(pad.axes?.[0]) || 0;
      const y = Number(pad.axes?.[1]) || 0;
      // One cardinal cell per step is easier to aim on a 9 x 9 board.
      if (Math.max(Math.abs(x), Math.abs(y)) >= this.deadzone) {
        if (Math.abs(x) > Math.abs(y)) dx = Math.sign(x);
        else dy = Math.sign(y);
      }
    } else if (dx && dy) {
      // D-pad diagonals retain the last active axis where possible.
      if (this._direction.startsWith('x')) dy = 0;
      else dx = 0;
    }
    const direction = dx ? `x${dx}` : dy ? `y${dy}` : '';
    if (direction !== this._direction) {
      this._direction = direction;
      this._moveClock = this.initialDelay;
      if (direction) this.onMove(dx, dy);
    } else if (direction) {
      this._moveClock -= elapsed;
      if (this._moveClock <= 0) {
        this._moveClock = this.repeatDelay;
        this.onMove(dx, dy);
      }
    }
    const numberDirection = Number(buttons[5]) - Number(buttons[4]);
    if (numberDirection !== this._numberDirection) {
      this._numberDirection = numberDirection;
      this._numberClock = this.initialDelay;
      if (numberDirection) this.onNumber(numberDirection);
    } else if (numberDirection) {
      this._numberClock -= elapsed;
      if (this._numberClock <= 0) {
        this._numberClock = this.repeatDelay + .045;
        this.onNumber(numberDirection);
      }
    }
    const edge = index => buttons[index] && !this._pressed[index];
    if (edge(0)) this.onAction('place');
    if (edge(1)) this.onAction('back');
    if (edge(2)) this.onAction('hint');
    if (edge(3)) this.onAction('phase');
    if (edge(6)) this.onAction('sound');
    if (edge(7)) this.onAction('buy');
    if (edge(8)) this.onHelp();
    if (edge(9)) this.onPause();
    this._pressed = buttons;
  }

  _disconnect() {
    if (this.connected) this._reset();
    this.connected = false;
    this.id = '';
    this.index = -1;
  }
}
