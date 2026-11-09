# Continue development from 0.3.27-dev

## Source and setup

Repository: https://github.com/yannage/Sudoku-Defense-beta

Use branch `integration/karen-on-0.3.26`, not the older default branch or
`godot-deck-edition`. Game source commit:
`822fdcd61dc59f89c6f342096243e23bad94032e`. Subsequent handoff documentation
does not change the game payload.

```sh
git clone --branch integration/karen-on-0.3.26 https://github.com/yannage/Sudoku-Defense-beta.git
cd Sudoku-Defense-beta
```

The maintained game is `godot/`, using Godot **4.7.2 stable** and the
Compatibility renderer. Legacy web/Electron files are retained as references.
Use Python 3 for build and QA helpers. Windows/Linux GodotSteam extensions,
their dependency lock, and licenses are tracked. No Steam credentials are
needed for isolated development checks. See `docs/GODOT-BUILDS.md` and
`.github/workflows/godot.yml` for editor/template verification and Linux
graphics dependencies (Xvfb, xauth, Mesa OpenGL and EGL).

Karen's usability changes were integrated onto the latest controller mappings
and verified feedback-form route. Wrong-guess penalties, save recovery,
account separation and achievements remain included. See
`docs/ITERATION-0.3.27-dev.md` for scope and provenance.

## Verified Steam state

Inspected in Steamworks on 2026-11-09:

| Field | Value |
| --- | --- |
| App | 3721150 |
| Active branch | default |
| Build | 26532795 |
| Description | Karen feedback |
| Shared depot | 3721151 |
| Manifest | 598503614629367540 |
| Windows launch | SudokuDefense.exe, Windows, 64-bit |
| Linux launch | sudoku-defense, Linux + SteamOS, 64-bit |

All 12 Steam manifest file SHA-1 hashes and sizes match the prepared local
0.3.27-dev package, including both platform metadata records and executables.
The depot is configured for all OSes, architectures, languages and platforms.
The existing web upload method supports ZIP files with Standard replacement;
the verified package is a complete shared-depot payload. **Do not use the
checked-in Linux-only VDF unchanged**, or upload a single-platform archive as
a Standard replacement of this shared depot.

Exact uploaded package: `Sudoku-Defense-Godot-Steam-Desktop-0.3.27-dev.zip`
(71,873,628 bytes), SHA-256:
`2846e05e638d4d93fa773beb764b469418a017a645e05334ea2e1047c9f63af9`.

The user uploaded/activated this build; the follow-up audit verified it and
did not re-upload or change the active branch. No paid release, pricing,
keys, agreements or credentials were changed. Older delivery statements in
iteration notes are historical, not the current Steam state.

## Validation and remaining work

Recorded local validation for the game commit: 119/119 permitted aggregate
jobs (86 headless, 33 rendered), six supplemental rendered checks with 22
screenshots, 16 packaging tests, and Windows exported startup checks passed.
These are prior local results, not new cloud CI results.

```sh
python3 -m unittest discover -s tests -p test_desktop_package.py
python3 qa/run_local_checks.py --godot /path/to/godot --mode headless --output qa/cloud-headless
```

Use a fresh output directory for each run. The canonical adapter uses isolated
profiles and disables Steam. Render checks require a real graphics environment;
review `qa/run_local_checks.py` before selecting them. Four native pointer/drag
suites remain excluded following prior sandbox denials. Do not treat a
headless or synthetic pass as physical device acceptance.

Still unverified: Linux runtime, physical Steam Deck and ordinary physical
Windows input/audio/performance acceptance, real Steam achievements and
two-device Steam Cloud, and the four excluded native pointer suites. Abrupt
forced shutdown during active startup audio retains a warning; the unchanged
Windows executable passed the five-second rendered startup check. A portrait
battle status wrapping issue remains documented as nonblocking.

Full local QA captures, raw logs and prepared binary ZIPs are not included in
this source branch. Rebuild and record fresh cloud evidence; do not claim
those local artifacts are available merely because the source was cloned.
The local packaging helpers include PC-specific defaults and frozen evidence
requirements; adapt paths explicitly instead of assuming those directories
exist in a cloud checkout. Existing CI runs automatically for the older
`godot-deck-edition` branch or relevant pull requests, and supports manual
dispatch; pushing this integration branch alone does not establish CI success.

For future work, create a development branch from this integration branch.
Preserve the shipped commit and treat source pushes, builds, Steam uploads,
branch activation, and paid public release as separate operations.
