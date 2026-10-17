/**
 * Dependency-free Web Audio feedback and a small adaptive musical bed.
 *
 * const audio = new AudioEngine();
 * // Call from a pointer/keyboard gesture; browsers require user activation.
 * await audio.unlock();
 * audio.play('place');
 * audio.play({ type: 'shot', number: 3, pan: -.4 });
 * audio.update(deltaSeconds, 'solve'); // 'battle' / 'defend' also supported
 * audio.setMuted(true); audio.stop();
 *
 * stop() silences all sound and suspends the context. unlock() resumes it.
 * Missing audio support and browser playback restrictions are safe no-ops.
 */
export class AudioEngine {
  constructor({ volume = .65, music = true } = {}) {
    this.context = null;
    this.master = null;
    this.muted = false;
    this.volume = Math.max(0, Math.min(1, volume));
    this.musicEnabled = music;
    this.unlocked = false;
    this._voices = new Set();
    this._cooldowns = new Map();
    this._musicClock = 0;
    this._musicStep = 0;
    this._phase = 'solve';
    this._unlockPromise = null;
    this._noiseBuffer = null;
  }

  async unlock() {
    if (this._unlockPromise) return this._unlockPromise;
    this._unlockPromise = this._resume();
    try { return await this._unlockPromise; }
    finally { this._unlockPromise = null; }
  }

  async _resume() {
    try {
      if (!this.context || this.context.state === 'closed') {
        const Context = globalThis.AudioContext || globalThis.webkitAudioContext;
        if (!Context) return false;
        const ctx = this.context = new Context({ latencyHint: 'interactive' });
        this.master = ctx.createGain();
        const limiter = ctx.createDynamicsCompressor();
        limiter.threshold.value = -14;
        limiter.knee.value = 18;
        limiter.ratio.value = 5;
        limiter.attack.value = .004;
        limiter.release.value = .12;
        this.master.connect(limiter);
        limiter.connect(ctx.destination);
        this.master.gain.value = this.muted ? 0 : this.volume;
        this._noiseBuffer = ctx.createBuffer(1, Math.ceil(ctx.sampleRate * .6), ctx.sampleRate);
        const noise = this._noiseBuffer.getChannelData(0);
        for (let i = 0; i < noise.length; i++) noise[i] = Math.random() * 2 - 1;
      }
      if (this.context.state !== 'running') await this.context.resume();
      this.unlocked = this.context.state === 'running';
      return this.unlocked;
    } catch {
      this.unlocked = false;
      return false;
    }
  }

  setMuted(muted) {
    this.muted = Boolean(muted);
    if (this.master && this.context?.state !== 'closed') {
      this.master.gain.setTargetAtTime(this.muted ? 0 : this.volume, this.context.currentTime, .035);
    }
  }

  setMusicEnabled(enabled) { this.musicEnabled = Boolean(enabled); }

  _ready() {
    return this.unlocked && !this.muted && this.context?.state === 'running';
  }

  _route(source, gain, pan = 0, filter = null) {
    if (this._voices.size >= 56) return false;
    const ctx = this.context;
    const nodes = [source, gain];
    if (filter) { source.connect(filter); filter.connect(gain); nodes.push(filter); }
    else source.connect(gain);
    if (ctx.createStereoPanner) {
      const panner = ctx.createStereoPanner();
      panner.pan.value = Math.max(-.85, Math.min(.85, Number.isFinite(pan) ? pan : 0));
      gain.connect(panner);
      panner.connect(this.master);
      nodes.push(panner);
    } else gain.connect(this.master);
    this._voices.add(source);
    source.onended = () => {
      this._voices.delete(source);
      for (const node of nodes) { try { node.disconnect(); } catch {} }
    };
    return true;
  }

  _tone(frequency, duration, level, { delay = 0, type = 'sine', end, attack = .006, pan = 0, detune = 0 } = {}) {
    if (!this._ready() || this._voices.size >= 56) return;
    const ctx = this.context;
    const at = ctx.currentTime + Math.max(0, delay);
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(Math.max(20, frequency), at);
    osc.detune.value = detune;
    if (end) osc.frequency.exponentialRampToValueAtTime(Math.max(20, end), at + duration);
    gain.gain.setValueAtTime(.0001, at);
    gain.gain.exponentialRampToValueAtTime(Math.max(.0002, level), at + Math.min(attack, duration / 3));
    gain.gain.exponentialRampToValueAtTime(.0001, at + duration);
    if (!this._route(osc, gain, pan)) return;
    osc.start(at);
    osc.stop(at + duration + .025);
  }

  _noise(duration, level, { frequency = 1800, delay = 0, pan = 0, type = 'bandpass' } = {}) {
    if (!this._ready() || !this._noiseBuffer || this._voices.size >= 56) return;
    const ctx = this.context;
    const at = ctx.currentTime + delay;
    const source = ctx.createBufferSource();
    source.buffer = this._noiseBuffer;
    const filter = ctx.createBiquadFilter();
    filter.type = type;
    filter.frequency.value = frequency;
    filter.Q.value = .7;
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(.0001, at);
    gain.gain.linearRampToValueAtTime(level, at + .003);
    gain.gain.exponentialRampToValueAtTime(.0001, at + duration);
    if (!this._route(source, gain, pan, filter)) return;
    source.start(at);
    source.stop(at + duration + .02);
  }

  play(event, options = {}) {
    if (!this._ready()) return;
    const details = typeof event === 'string' ? { ...options, type: event } : event || {};
    const name = details.type || details.name;
    const now = this.context.currentTime;
    const cooldown = { shot: .065, kill: .07, invalid: .12, leak: .15 }[name] || .025;
    if (now - (this._cooldowns.get(name) ?? -100) < cooldown) return;
    this._cooldowns.set(name, now);
    const pan = details.pan || 0;
    const digit = Math.max(1, Math.min(9, Math.round(Number(details.number ?? details.digit ?? details.value) || 1)));
    const scale = [0, 2, 3, 5, 7, 9, 10, 12, 14];
    const pitch = 293.665 * 2 ** (scale[digit - 1] / 12);
    const tone = (frequency, duration, level, extra = {}) => this._tone(frequency, duration, level, { pan, ...extra });
    const noise = (duration, level, extra = {}) => this._noise(duration, level, { pan, ...extra });
    switch (name) {
      case 'place':
        tone(pitch, .17, .17, { type: 'triangle' });
        tone(pitch * 2, .22, .07, { delay: .036 });
        noise(.023, .075, { frequency: 3200 });
        break;
      case 'invalid':
        tone(135, .2, .15, { type: 'triangle', end: 82 });
        tone(143, .15, .07, { type: 'triangle', end: 86 });
        noise(.075, .035, { frequency: 700 });
        break;
      case 'shot':
        tone(pitch * 1.4, .065, .046, { end: pitch * .72, type: 'triangle' });
        noise(.025, .021, { frequency: 2300 });
        break;
      case 'kill':
        tone(660, .11, .075, { end: 1100 });
        tone(1320, .13, .027, { delay: .025 });
        noise(.07, .065, { frequency: 1600 });
        break;
      case 'wave':
        tone(73.416, .65, .22, { end: 55, attack: .025 });
        [146.832, 220, 293.665].forEach((n, i) => tone(n, .7, .045, { type: 'triangle', delay: i * .07, attack: .04 }));
        noise(.3, .07, { frequency: 900, type: 'lowpass' });
        break;
      case 'reward':
        [1, 1.25, 1.5, 2].forEach((n, i) => tone(587.33 * n, .34, .1, { delay: i * .068 }));
        tone(293.665, .42, .06, { type: 'triangle' });
        break;
      case 'buy':
        [440, 587.33, 880].forEach((n, i) => tone(n, .23, .09, { delay: i * .045, type: 'triangle' }));
        noise(.025, .05, { frequency: 4000 });
        break;
      case 'leak':
        tone(240, .27, .13, { type: 'triangle', end: 70 });
        tone(60, .32, .12);
        noise(.15, .09, { frequency: 550, type: 'lowpass' });
        break;
      default: break;
    }
  }

  update(dt, phase = 'solve') {
    if (!this._ready() || !this.musicEnabled) return;
    // Do not catch up missed musical beats after a background tab resumes.
    const elapsed = Math.max(0, Math.min(.1, Number(dt) || 0));
    const battle = /battle|defen|combat|wave/i.test(String(phase));
    this._phase = battle ? 'battle' : 'solve';
    this._musicClock -= elapsed;
    if (this._musicClock > 0) return;
    this._musicClock = battle ? .27 : .36;
    const step = this._musicStep++;
    const chords = [[50, 57, 60, 64], [46, 53, 57, 60], [53, 60, 64, 69], [48, 55, 58, 62]];
    const chord = chords[Math.floor(step / 16) % chords.length];
    const hz = midi => 440 * 2 ** ((midi - 69) / 12);
    if (step % 16 === 0) {
      chord.slice(0, 3).forEach((note, i) => {
        this._tone(hz(note), battle ? 2.8 : 4.2, .014, { attack: .4, pan: (i - 1) * .45 });
        this._tone(hz(note), battle ? 2.8 : 4.2, .006, { attack: .45, detune: 5, pan: (1 - i) * .45 });
      });
    }
    if (step % (battle ? 2 : 4) === 0) {
      const pattern = [0, 2, 1, 3, 2, 1, 3, 2];
      const note = chord[pattern[Math.floor(step / 2) % pattern.length]] + 12;
      this._tone(hz(note), .55, battle ? .019 : .014, { type: 'sine', pan: step % 4 ? -.25 : .25 });
    }
    if (battle && step % 4 === 0) this._tone(72, .13, .038, { end: 43 });
    if (battle && step % 4 === 2) this._noise(.04, .009, { frequency: 3800 });
  }

  stop() {
    this.unlocked = false;
    this._musicClock = 0;
    this._musicStep = 0;
    this._cooldowns.clear();
    for (const voice of this._voices) { try { voice.stop(); } catch {} }
    this._voices.clear();
    if (this.context && this.context.state !== 'closed') {
      try { this.context.suspend().catch(() => {}); } catch {}
    }
  }
}
