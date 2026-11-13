# 0.3.28-dev — directional tower selection and Deck input

Prepared November 12, 2026. Steam upload and physical Steam Deck acceptance are pending.

## Player controls

- During Prepare, Defend, Loot, or module targeting, aim the left stick toward a tower. A line and ring preview the target. Release the stick to select it once. Holding the stick does not repeatedly jump through towers.
- A while aiming selects the highlighted tower; the next A opens its module slots. B cancels the aim. Neither selection method buys upgrades or equips modules.
- Mouse or trackpad motion previews a directional target. Click a gap toward that tower to select it, or click the tower itself to customize it. Touch retains direct tower selection.
- D-pad stepping and LB/RB cycling remain available. Sudoku board edges wrap in the same row or column.
- Solve/menu analog navigation has diagonal hysteresis and a slower initial/repeat cadence. D-pad timing remains unchanged.
- Focus loss and the Steam overlay pause active gameplay and save. Return requires a deliberate resume. Controller navigation requires fresh release after interruptions. Quit to desktop is accessible from the controller menus.

## Build evidence

The Godot PR workflow runs native and canvas regression tests, rendered checks, Windows/Linux exports and startup validation. A final job combines both platforms into a shared Steam depot ZIP using byte-verified source metadata. CI success and artifact links must be recorded after the final commit is tested; this document does not claim a pass.

## Remaining Steam / Deck acceptance

Use app 3721150 from the normal Steam Library launch and record the new BuildID and displayed version. Before uploading, read the current default build and depot manifests; do not replace a newer build without reconciling its source. The Windows/Linux shared depot must receive the combined ZIP.

On a physical Steam Deck at 1280×800, check first launch with the default gamepad layout, left-stick aim/release and cancel, right-stick/trackpad pointer, touch, number tray, module sockets, Camp/Slots scrolling, reconnect, and Quit. Open/close the Steam overlay and suspend/resume during Solve and a busy combat wave; confirm timers stay paused until resume, sound returns, and input is not held. Check readable prompts and sustained performance at default settings, then run save/continue and offline launch checks.

Do not advertise Valve's Steam Deck Verified badge from automated tests. Valve's compatibility review is separate: https://partner.steamgames.com/doc/steamhardware/compat
