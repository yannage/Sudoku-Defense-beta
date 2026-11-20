#!/usr/bin/env python3
"""Export the one-wave demo with a separate user-data identity and no Steam SDK."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
RETAIL = HERE.parents[1] / "godot"
sys.path.insert(0, str(RETAIL / "scripts"))
from build_exports import EXPECTED_VERSION, archive_directory
from desktop_package import GODOT_NOTICES

PLATFORMS = {"linux": ("Linux", "sudoku-defense-demo.x86_64"),
             "windows": ("Windows", "SudokuDefenseDemo.exe")}


def stage_project(project: Path) -> None:
    shutil.copytree(RETAIL, project, ignore=shutil.ignore_patterns(
        ".godot", "build", "addons", "tests", "__pycache__", "*.md", "*.py"))
    config = project / "project.godot"
    settings = config.read_text(encoding="utf-8")
    old_name = 'config/name="Sudoku Defense"'
    if settings.count(old_name) != 1:
        raise RuntimeError("Verify the base game's project identity before exporting the demo")
    config.write_text(settings.replace(old_name, 'config/name="Sudoku Defense Demo"'), encoding="utf-8")
    # Keep the only launch scene wired to the demo (including manual scene reloads).
    scene = project / "scenes/main.tscn"
    content = scene.read_text(encoding="utf-8")
    if content.count("res://scripts/main.gd") != 1:
        raise RuntimeError("Verify the base game's launch scene before exporting the demo")
    scene.write_text(content.replace("res://scripts/main.gd", "res://demo/demo_main.gd"), encoding="utf-8")
    (project / "demo").mkdir()
    for name in ("demo_main.gd", "demo_guide.gd"):
        shutil.copyfile(HERE / name, project / "demo" / name)


def run(godot: str, project: Path, args: list[str], env: dict, marker: str = "") -> None:
    command = [godot, "--headless", "--path", str(project), *args]
    result = subprocess.run(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, encoding="utf-8", errors="replace", timeout=240)
    if result.returncode or "ERROR:" in result.stdout or marker not in result.stdout:
        raise RuntimeError("Demo command failed: " + " ".join(command) + "\n" + result.stdout)
    print(marker or " ".join(args), flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--check-only", action="store_true", help="Run the demo flow without exporting")
    parser.add_argument("--output", type=Path, default=RETAIL.parent / "release" / "demo")
    parser.add_argument("--targets", nargs="+", choices=list(PLATFORMS), default=list(PLATFORMS))
    args = parser.parse_args()
    version = subprocess.check_output([args.godot, "--version"], text=True).strip()
    if not version.startswith(EXPECTED_VERSION + ".stable"):
        parser.error(f"Expected Godot {EXPECTED_VERSION} stable, found {version}")
    with tempfile.TemporaryDirectory(prefix="sudoku-defense-demo-") as staging:
        root = Path(staging)
        project = root / "project"
        stage_project(project)
        # Keep template discovery in the user's normal Godot data directory during export.
        run(args.godot, project, ["--editor", "--import"], os.environ.copy())
        checks = os.environ.copy()
        for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "APPDATA", "LOCALAPPDATA"):
            checks[key] = str(root / "profile" / key)
        shutil.copyfile(HERE / "test_demo.gd", project / "demo" / "test_demo.gd")
        for renderer in ([], ["--", "--canvas-graphics"]):
            run(args.godot, project, ["--script", "res://demo/test_demo.gd", *renderer], checks, "DEMO_FLOW_PASS")
        (project / "demo/test_demo.gd").unlink()
        if args.check_only:
            return
        depot = root / "depot"
        depot.mkdir()
        for notice in GODOT_NOTICES:
            shutil.copyfile(RETAIL / notice, depot / notice)
        for target in dict.fromkeys(args.targets):
            preset, filename = PLATFORMS[target]
            payload = root / target
            payload.mkdir()
            executable = payload / filename
            run(args.godot, project, ["--export-release", preset, str(executable)], os.environ.copy())
            if not executable.is_file() or not executable.stat().st_size or {p.name for p in payload.iterdir()} != {filename}:
                raise RuntimeError(f"Unexpected {preset} demo export contents")
            if (sys.platform.startswith("linux") and target == "linux") or (os.name == "nt" and target == "windows"):
                result = subprocess.run([str(executable), "--headless", "--quit-after", "8", "--", "--smoke-test"],
                                        cwd=payload, env=checks, capture_output=True, text=True,
                                        encoding="utf-8", errors="replace", timeout=60)
                log = result.stdout + result.stderr
                if result.returncode or "ERROR:" in log or "SUDOKU_DEFENSE_DEMO_READY" not in log:
                    raise RuntimeError(f"Packaged {preset} demo failed to boot:\n{log}")
            for notice in GODOT_NOTICES:
                shutil.copyfile(RETAIL / notice, payload / notice)
            archive = args.output / f"Sudoku-Defense-Demo-{preset}.zip"
            archive_directory(payload, archive, executable_names={filename} if target == "linux" else None)
            print(archive, flush=True)
            shutil.copyfile(executable, depot / filename)
        if set(args.targets) == set(PLATFORMS):
            depot_archive = args.output / "Sudoku-Defense-Demo-Depot-5670271.zip"
            archive_directory(depot, depot_archive, executable_names={PLATFORMS["linux"][1]})
            print(depot_archive, flush=True)


if __name__ == "__main__":
    main()
