#!/usr/bin/env python3
"""Render the original 32-second Sudoku Defense trailer score.

Offline marketing utility; never shipped as a dependency of the game. Requires
Python, NumPy, SciPy and ffmpeg. All oscillators, percussion and sound effects
are synthesized here: there are no recordings, samples or licensed songs.

Usage: python marketing/create-audio.py --output /path/to/soundtrack.wav
"""

import argparse
import json
import math
from pathlib import Path
import re
import subprocess

import numpy as np
from scipy import signal
from scipy.io import wavfile


SR = 48_000
DURATION = 32
BPM = 120
BEAT = 60 / BPM
RNG = np.random.default_rng(61281)
MUSIC = np.zeros((SR * DURATION, 2), dtype=np.float64)
DRUMS = np.zeros_like(MUSIC)
FX = np.zeros_like(MUSIC)
SEND = np.zeros_like(MUSIC)


def timeline(duration):
    return np.arange(round(duration * SR)) / SR


def midi(note):
    return 440.0 * 2 ** ((note - 69) / 12)


def fade(x, attack=0.004, release=0.02):
    x = x.copy()
    a, r = min(len(x), round(attack * SR)), min(len(x), round(release * SR))
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if r:
        x[-r:] *= np.linspace(1, 0, r)
    return x


def put(buffer, x, when, gain=1, pan=0, send=0):
    start = round(when * SR)
    left = max(0, -start)
    start = max(0, start)
    length = min(len(x) - left, len(buffer) - start)
    if length <= 0:
        return
    x = x[left:left + length]
    p = (pan + 1) * math.pi / 4
    stereo = gain * x[:, None] * np.array([math.cos(p), math.sin(p)])
    buffer[start:start + length] += stereo
    if send:
        SEND[start:start + length] += stereo * send


def lowpass(x, hz):
    return signal.sosfilt(signal.butter(2, hz, fs=SR, output="sos"), x)


def bandpass(x, lo, hi):
    return signal.sosfilt(signal.butter(2, [lo, hi], btype="bandpass", fs=SR,
                                       output="sos"), x)


def pluck(note, duration=.37, bright=1):
    t = timeline(duration)
    f = midi(note)
    # A rounded, softly detuned instrument with a bell-like transient.
    out = np.sin(2 * np.pi * f * t) * np.exp(-t * 8)
    out += .29 * bright * np.sin(2 * np.pi * f * 2.003 * t) * np.exp(-t * 17)
    out += .13 * bright * np.sin(2 * np.pi * f * 3 * t) * np.exp(-t * 29)
    return fade(out, .003, .045)


def bass(note, duration=.23):
    t = timeline(duration)
    f = midi(note)
    envelope = np.minimum(t / .008, 1) * np.exp(-t * 4.4)
    out = np.sin(2 * np.pi * f * t)
    out += .34 * np.sin(2 * np.pi * f * 2 * t)
    out += .13 * np.sin(2 * np.pi * f * 3 * t)
    return fade(np.tanh(out * 1.3) * envelope, .004, .027)


def pad(notes, duration=2.3):
    t = timeline(duration)
    out = np.zeros(len(t))
    for n in notes:
        f = midi(n)
        for detune in [-.0022, .0022]:
            phase = 2 * np.pi * f * (1 + detune) * t
            out += np.sin(phase) + .22 * np.sin(phase * 2) + .1 * np.sin(phase * 3)
    envelope = np.minimum(t / .2, 1) * np.minimum((duration - t) / .36, 1)
    return out / len(notes) / 2 * envelope


def lead(note, duration=.44):
    t = timeline(duration)
    f = midi(note)
    phase = 2 * np.pi * f * t + .028 * np.sin(2 * np.pi * 5.3 * t)
    out = np.sin(phase) + .22 * np.sin(phase * 2) + .12 * np.sin(phase * 3)
    return fade(out * np.exp(-t * 3.2), .009, .065)


def kick():
    t = timeline(.37)
    freq = 47 + 99 * np.exp(-t * 37)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    body = np.sin(phase) * np.exp(-t * 12)
    click = bandpass(RNG.normal(0, 1, len(t)), 1500, 6000) * np.exp(-t * 190) * .19
    return fade(np.tanh(1.6 * (body + click)), .001, .06)


def snare():
    t = timeline(.25)
    noise = bandpass(RNG.normal(0, 1, len(t)), 900, 7500)
    body = np.sin(2 * np.pi * 182 * t) * np.exp(-t * 32) * .55
    return fade(noise * np.exp(-t * 29) * .8 + body, .001, .04)


def hat(opened=False):
    t = timeline(.18 if opened else .065)
    noise = bandpass(RNG.normal(0, 1, len(t)), 4800, 11800)
    return fade(noise * np.exp(-t * (25 if opened else 85)), .001, .018)


def impact(when, strength=1):
    t = timeline(.85)
    phase = 2 * np.pi * np.cumsum(39 + 115 * np.exp(-t * 16)) / SR
    sound = np.sin(phase) * np.exp(-t * 7)
    sound += bandpass(RNG.normal(0, 1, len(t)), 250, 5400) * np.exp(-t * 13) * .32
    put(FX, fade(sound, .001, .14), when, .33 * strength, send=.15)


def sparkle(when, notes=(76, 79, 83, 88), gain=.095):
    for i, n in enumerate(notes):
        put(FX, pluck(n, .6, .6), when + i * .07, gain,
            pan=(-.38 if i % 2 else .38), send=.42)


def sweep(when, duration, gain=.065):
    t = timeline(duration)
    noise = bandpass(RNG.normal(0, 1, len(t)), 1500, 5800)
    rise = (t / duration) ** 2
    noise = noise * rise * (.65 + .35 * np.sin(2 * np.pi * 8 * t) ** 2)
    put(FX, fade(noise, .02, .006), when, gain, send=.2)


def generate():
    # Four harmonically connected voicings in E minor, repeated with evolving
    # instrumentation. Each bar is 2 seconds. Top notes provide a clear motif.
    progression = [([52, 59, 64, 67], 28), ([48, 55, 60, 64], 24),
                   ([47, 55, 59, 62], 31), ([50, 57, 62, 66], 26)]
    melody = [[76, 79, 78, 74], [76, 79, 83, 79],
              [74, 78, 79, 83], [81, 78, 74, 78]]
    kick_times = []
    for bar in range(16):
        when = bar * 2
        chord, root = progression[bar % 4]
        if bar >= 14:
            chord, root = [52, 59, 64, 67, 71], 28  # resolve the brand sting
        # Solve sequence leaves room for the board and its delicate clicks.
        delicate = 3 <= when < 9
        battle = 14 <= when < 25
        finale = when >= 28
        pad_gain = .042 if delicate else .072
        put(MUSIC, pad(chord), when, pad_gain, pan=-.12, send=.24)
        put(MUSIC, pad([n + 12 for n in chord], 2.22), when + .023,
            pad_gain * .4, pan=.24, send=.28)

        if finale:
            continue
        arp_notes = [chord[0] + 24, chord[1] + 12, chord[2] + 12,
                     chord[3] + 12, chord[1] + 24, chord[2] + 12,
                     chord[3] + 12, chord[2] + 12]
        for step, n in enumerate(arp_notes):
            at = when + step * .25
            if 25 <= at < 28 and step % 2:
                continue
            gain = .050 if delicate else .059
            put(MUSIC, pluck(n, .4, .7), at, gain * (1 if step % 2 == 0 else .8),
                pan=[-.4, -.12, .23, .43][step % 4], send=.34)

        bass_steps = [0, .375, .75, 1, 1.5, 1.75] if not delicate else [0, 1]
        for j, at in enumerate(bass_steps):
            n = root + (12 if j == len(bass_steps) - 1 and not delicate else 0)
            put(MUSIC, bass(n, .28), when + at, .153 if not delicate else .092)

        # Hook is stated immediately, returns at battle, then resolves at logo.
        if bar < 2 or battle:
            for j, n in enumerate(melody[bar % 4]):
                if bar == 12 and j > 1:
                    break
                put(MUSIC, lead(n), when + j * .5 + (.25 if j == 3 else 0),
                    .065, pan=.10, send=.25)
        if bar == 5 or bar == 6:
            for j, n in enumerate(melody[bar % 4][:2]):
                put(MUSIC, lead(n, .65), when + j, .037, pan=.12, send=.32)

        if when >= 26:
            continue
        kicks = [0, 1] if delicate else [0, .75, 1, 1.75]
        for beat in kicks:
            kt = when + beat
            kick_times.append(kt)
            put(DRUMS, kick(), kt, .24 if delicate else .38)
        for beat in [.5, 1.5]:
            put(DRUMS, snare(), when + beat, .063 if delicate else .133,
                pan=.03, send=.085)
        for step in range(8):
            at = when + step * .25
            velocity = .024 if step % 2 == 0 else .039
            if delicate:
                velocity *= .62
            put(DRUMS, hat(opened=step == 7 and not delicate), at, velocity,
                pan=-.25 if step % 2 == 0 else .3)
        if battle and bar % 2:
            for step in range(4):
                put(DRUMS, snare(), when + 1.5 + step * .125,
                    .028 + step * .012, pan=.14)

    # Short, synchronized affordance sounds: solving, fitting gear and combat.
    for when, note in [(3.1, 76), (4.15, 79), (5.1, 83), (6.15, 79),
                       (7.15, 86), (8.25, 88)]:
        put(FX, pluck(note, .22, .7), when, .081, pan=.15, send=.24)
    for when in [9.15, 10.35, 11.55, 12.75]:
        t = timeline(.12)
        click = np.sin(2 * np.pi * (280 + 90 * np.exp(-t * 38)) * t)
        put(FX, fade(click * np.exp(-t * 34), .001, .035), when, .08)
        sparkle(when + .04, (76, 83), .049)
    sweep(13.4, 1.6)
    impact(0, .72)
    impact(15)
    impact(21, .8)
    for when, n in [(16.1, 64), (17.2, 67), (18.3, 71), (19.5, 64),
                    (21.15, 71), (22.3, 67), (23.4, 64)]:
        t = timeline(.17)
        frequency = midi(n) * (1 + .65 * np.exp(-t * 24))
        phase = np.cumsum(frequency) * (2 * np.pi / SR)
        zap = np.sin(phase) * np.exp(-t * 27)
        put(FX, fade(zap, .003, .025), when, .045,
            pan=.35 if n % 2 else -.35, send=.12)
    sweep(24.6, .4, .045)
    sparkle(25.05, (76, 79, 83, 88), .12)
    sparkle(26.1, (79, 83, 86, 91), .076)
    sparkle(27.05, (83, 88, 91, 95), .062)

    # Brand cadence: E -> B -> high E, then a generous tail for the end card.
    impact(28, .78)
    for when, n, length, gain in [(28, 76, .72, .10), (28.5, 83, .70, .092),
                                 (29, 88, 1.9, .12)]:
        put(MUSIC, lead(n, length), when, gain, send=.48)
    put(MUSIC, bass(28, 1.6), 28, .21)
    put(MUSIC, pad([52, 59, 64, 67, 71], 3.8), 28, .07, send=.44)

    # Light kick ducking creates groove without the tiring deep pumping effect.
    duck = np.ones(len(MUSIC))
    for when in kick_times:
        start = round(when * SR)
        t = timeline(.24)
        end = min(len(duck), start + len(t))
        duck[start:end] *= 1 - .32 * np.exp(-t[:end - start] * 19)
    MUSIC[:] *= duck[:, None]
    # Deterministic short stereo reflections and lush, low-level diffuse tail.
    wet = np.zeros_like(MUSIC)
    for delay, gain, cross in [(0.117, .24, False), (.179, .18, True),
                               (.251, .14, False), (.337, .10, True),
                               (.463, .065, False), (.619, .043, True)]:
        n = round(delay * SR)
        source = SEND[:, ::-1] if cross else SEND
        wet[n:] += source[:-n] * gain
    audio = MUSIC + DRUMS + FX + wet
    audio = signal.sosfilt(signal.butter(2, 28, btype="highpass", fs=SR,
                                       output="sos"), audio, axis=0)
    audio = np.tanh(audio * 1.10) / 1.10
    # End in digital silence; no abrupt trailer loop or clipped ambience.
    fade_start = round(30.6 * SR)
    audio[fade_start:] *= np.linspace(1, 0, len(audio) - fade_start)[:, None] ** 1.35
    audio[:round(.008 * SR)] *= np.linspace(0, 1, round(.008 * SR))[:, None]
    return audio


def ffmpeg_json(stderr):
    blocks = re.findall(r'\{\s*"input_i".*?\}', stderr, re.S)
    if not blocks:
        raise RuntimeError("ffmpeg did not return loudness measurements")
    return json.loads(blocks[-1])


def run_ffmpeg(*args):
    return subprocess.run(["ffmpeg", "-hide_banner", "-nostdin", "-y", *args],
                          check=True, capture_output=True, text=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("soundtrack.wav"))
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    raw = args.output.with_name(args.output.stem + "-premaster.wav")
    audio = generate()
    wavfile.write(raw, SR, audio.astype(np.float32))
    target = "loudnorm=I=-14:TP=-1.2:LRA=8"
    first = run_ffmpeg("-i", str(raw), "-af", target + ":print_format=json",
                       "-f", "null", "-")
    measured = ffmpeg_json(first.stderr)
    norm = (target + ":linear=true:print_format=json"
            + f":measured_I={measured['input_i']}"
            + f":measured_TP={measured['input_tp']}"
            + f":measured_LRA={measured['input_lra']}"
            + f":measured_thresh={measured['input_thresh']}"
            + f":offset={measured['target_offset']}")
    run_ffmpeg("-i", str(raw), "-af", norm, "-ar", str(SR), "-ac", "2",
               "-c:a", "pcm_s24le", str(args.output))
    final = run_ffmpeg("-i", str(args.output), "-af", target + ":print_format=json",
                       "-f", "null", "-")
    final_metrics = ffmpeg_json(final.stderr)
    report = {"title": "Sudoku Defense — Grow / Gear / Guard",
              "composer": "YAK Studios (original procedural composition)",
              "duration_seconds": DURATION, "bpm": BPM, "key": "E minor",
              "sample_rate": SR, "channels": 2,
              "integrated_lufs": float(final_metrics["input_i"]),
              "true_peak_dbtp": float(final_metrics["input_tp"]),
              "loudness_range_lu": float(final_metrics["input_lra"]),
              "external_samples": False,
              "rights_note": "Original synthesis and sequencing; no third-party recordings.",
              "sections": [{"time": "0–3", "cue": "immediate melodic hook"},
                           {"time": "3–9", "cue": "solve: delicate pluck pulse"},
                           {"time": "9–15", "cue": "equip: build and gear clicks"},
                           {"time": "15–25", "cue": "battle: full groove and impacts"},
                           {"time": "25–28", "cue": "loot: cascading reward chimes"},
                           {"time": "28–32", "cue": "brand: resolved melodic sting"}]}
    args.output.with_suffix(".json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"path": str(args.output), **report}, indent=2))


if __name__ == "__main__":
    main()
