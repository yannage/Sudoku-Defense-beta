# Steam integration package contract (0.3.19)

Desktop exports use the ordinary Godot 4.7.2 templates with the pinned
GodotSteam 4.23.2 GDExtension. The Windows and native Linux release libraries
are exported **beside the executable**, along with the corresponding Steam
runtime. A separate minimal project confirmed this layout on both export
presets. Browser exports exclude the entire addon and continue using the normal
single-threaded Web template.

The existing launch names remain `SudokuDefense.exe` and `sudoku-defense` on
Steam. The downloadable Linux executable remains `sudoku-defense.x86_64`.

Each desktop ZIP has exactly eight files:

- Its executable.
- Its platform's GodotSteam release library and Steam runtime library.
- `GODOT-LICENSE.txt`, `GODOT-THIRD-PARTY.txt`, `GODOTSTEAM-LICENSE.txt` and
  `STEAMWORKS-NOTICE.txt`.
- `BUILD-METADATA-windows.json` or `BUILD-METADATA-linux.json`.

The combined shared-depot ZIP has twelve files: both executables, all four
native libraries, the four shared notices, and both metadata files. The
executable and both libraries for Linux retain Unix mode 0755 in ZIP and TAR,
including packages created on Windows. No `steam_appid.txt`, editor/debug
libraries or arbitrary extra files are accepted into a desktop release ZIP.

`godot/scripts/desktop_package.py` defines the exact allowlist and validates
runtime hashes against the checked-in upstream dependency lock. Metadata
records the source commit, game version and hash/size of every payload file.
Desktop packaging refuses uncommitted Godot sources. Steam preparation checks
both platforms against the requested source and version, validates their
metadata and pinned libraries, and requires the matching Windows startup
receipt. The shared-depot helper still only prepares an archive; it never
uploads or changes a branch.

All scripted engine launches append `--no-steam`. Unit tests and executable
smoke checks also use isolated profiles. Windows CI starts its smoke process
hidden. These checks can load the native extension and catch missing libraries
without connecting a real account or awarding achievements. They do **not**
validate two-device Cloud synchronization or real Steam achievement delivery.

Run the packaging regressions with:

```sh
python3 -m unittest discover -s tests -p test_desktop_package.py -v
```

The Godot aggregate additionally includes Cloud migration/journal tests,
achievement rules/profile tests, the mocked Steam platform adapter test and
native/Canvas platform UI checks. Linux QA must inspect the new shared
libraries' dependencies and ABI requirements and boot the exact exported
candidate; previous Godot executable checks do not establish compatibility of
new libraries. Physical Deck, Steam client and cross-device acceptance remain
separate tests.
