# Sudoku Defense Demo

From the repository root, run `python steam/demo/build.py` with Godot 4.7.2 and its matching Linux and Windows export templates installed. Use `--godot <path>` to select the editor, or `--check-only` to run both renderer tests without exporting. The tests play the guided wave through its chest reward, replay on a fresh board, and check that demo play does not create campaign saves or achievements.

The builder stages a temporary Godot project with the **Sudoku Defense Demo** user-data directory. Only preferences persist. Both play modes end after one wave. Steam opens the base-game store page from the results screen. The demo ships without the Steam native extension or an app ID file.

Upload `release/demo/Sudoku-Defense-Demo-Depot-5670271.zip` to depot **5670271** under demo App ID **5670270**. The root launch paths are `SudokuDefenseDemo.exe` (Windows) and `sudoku-defense-demo.x86_64` (Linux). Platform-specific ZIPs are alongside the combined depot.
