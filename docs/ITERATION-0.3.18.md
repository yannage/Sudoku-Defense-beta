# 0.3.18 long-wave pacing candidate

This development candidate starts from live 0.3.17 source
`241040d787f1f9e27ad1d3e75d37706fd36c2af6`. Steam default build `26349224`
remains live; this pass prepares and tests a candidate without uploading it.

## Player-selected fast-forward

After 45 battle seconds, once every enemy has spawned, the phase button offers
**Fast-forward 8x**. Tap it or press Y / Enter. Press again or B to stop.
The speed indicator reads 8x while active, and the wave panel shows the number
of enemies still on the route. These enemies can still damage the core:
fast-forward accelerates enemies and towers equally.

The selected normal speed remains 1x, 2x or 4x. A core hit immediately stops
further accelerated updates that frame. Opening menus, tower inspection, the
number picker or camera controls cancels fast-forward. Losing window focus
also cancels it. It never resumes automatically or carries into another wave.
The ordinary speed button cancels fast-forward and cycles normal speed.
Practice mode keeps its existing teaching flow.

There are no changes to control strength, damage, targeting, health, prices,
loot or save format. Fast-forward repeats the same ordinary update call in
a bounded loop. At the same frame cadence and normal speed this preserves the
simulation's existing update sequence; it does not promise identical results
across different frame rates. Existing simulation steps remain at most 0.05s.
The Sudoku timer and all unaccelerated gameplay follow the original update path.

## Why preserve control strength

The measured gravity-cap alternatives shortened some waves but caused serious
leaks and reduced kill rewards in others. The narrow change here gives players
control over waiting without weakening their towers. See
[the experiment and limitations](BALANCE-0.3.18.md) for exact scenarios and
before/after results. Estimated wall-clock savings assume immediate opt-in,
the stated normal speed and no pauses; they are not hardware benchmarks.

## Human acceptance on Steam Deck

- In a long wave, confirm the remaining-enemy count and 8x warning are readable.
  Use Y to start/stop and B to stop; enemies must remain understandable.
- Inspect a tower, open the number picker, pause, rotate the camera and
  suspend/resume. Fast-forward should stop and require a fresh opt-in.
- Try both a control-heavy and a damage-heavy late build. Judge whether the
  wait is acceptable and the faster animation/audio is comfortable.
- Check native Deck performance and the existing A / slot / module flow,
  nearest-tower selection, bumper cycling and B navigation.

Automated input, rendered software-GPU checks and dummy-audio startup cannot
establish physical Deck behavior, human enjoyment or audible mix quality.
Exact source, package hashes and final check outcomes accompany the candidate.
