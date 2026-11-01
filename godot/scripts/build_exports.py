#!/usr/bin/env python3
"""Build actual Godot releases. No web reimplementation or desktop wrapper."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import tarfile
import tempfile
import zipfile

from desktop_package import GODOT_NOTICES, LIBRARIES, notice_sources, write_metadata

PROJECT = Path(__file__).resolve().parents[1]
EXPECTED_VERSION = "4.7.2"
CHUNK_BYTES = 10 * 1024 * 1024
STATIC_FILE_LIMIT = 25 * 1024 * 1024


def bootstrap_extension_cache(project: Path = PROJECT) -> None:
    """Load CORE-level GodotSteam at engine startup on a clean checkout.

    Discovery during the editor's first filesystem scan is too late for this
    extension's initialization level. This is generated cache, not a project
    export resource; retain any other extension registrations already present.
    """
    extension = "res://addons/godotsteam/godotsteam.gdextension"
    if not (project / extension.removeprefix("res://")).is_file():
        raise RuntimeError("The pinned GodotSteam extension must exist before importing")
    cache = project / ".godot/extension_list.cfg"
    existing = cache.read_text(encoding="utf-8-sig") if cache.exists() else ""
    if extension in {line.strip() for line in existing.splitlines()}:
        return
    cache.parent.mkdir(parents=True, exist_ok=True)
    separator = "\n" if existing and not existing.endswith("\n") else ""
    cache.write_text(existing + separator + extension + "\n", encoding="utf-8", newline="\n")


def run(command: list[str], log: Path, expected: str | None = None) -> None:
    # UI regressions exercise real save paths. A fresh profile per suite keeps
    # the developer's actual campaign untouched, including journal sidecars.
    command = command.copy()
    if "--" not in command:
        command.append("--")
    if "--no-steam" not in command:
        command.append("--no-steam")
    environment = os.environ.copy()
    with tempfile.TemporaryDirectory(prefix="sudoku-test-profile-") as profile:
        if "--script" in command or "--smoke-test" in command:
            for key in (["APPDATA", "LOCALAPPDATA"] if os.name == "nt" else ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]):
                folder = Path(profile) / key.lower()
                folder.mkdir()
                environment[key] = str(folder)
        result = subprocess.run(command, cwd=PROJECT, env=environment, text=True, encoding="utf-8", errors="replace", stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
    log.write_text(result.stdout, encoding="utf-8")
    problems = [line for line in result.stdout.splitlines() if "ERROR:" in line or "Parse Error:" in line]
    if result.returncode or problems or (expected is not None and expected not in result.stdout):
        print(result.stdout)
        if expected is not None and expected not in result.stdout:
            print(f"Missing required completion marker: {expected}")
        raise SystemExit(f"Build failed; inspect {log}")
    print(f"OK: {' '.join(command[-4:])}")


def make_web_shell(web: Path) -> None:
    """Preserve Godot's exported config; split only the large engine transport."""
    original = (web / "index.html").read_text(encoding="utf-8")
    match = re.search(r"const GODOT_CONFIG = (\{.*?\});", original)
    if not match:
        raise RuntimeError("Exported Godot HTML has no recognized engine config")
    config = json.loads(match.group(1))
    config["ensureCrossOriginIsolationHeaders"] = False
    # The shell owns safe-area and high-DPI sizing. Policy 2 would overwrite it
    # with window.innerWidth/innerHeight and the uncapped device pixel ratio.
    config["canvasResizePolicy"] = 0
    engine_path = web / "index.wasm"
    payload = engine_path.read_bytes()
    parts = []
    for position in range(0, len(payload), CHUNK_BYTES):
        name = f"index.wasm.part{len(parts):02d}"
        part = payload[position:position + CHUNK_BYTES]
        (web / name).write_bytes(part)
        parts.append({"name": name, "bytes": len(part), "sha256": hashlib.sha256(part).hexdigest()})
    reconstructed = b"".join((web / part["name"]).read_bytes() for part in parts)
    assert reconstructed == payload, "WASM chunk transport must be byte-identical"
    manifest = {"bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest(), "parts": parts}
    (web / "engine-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    engine_path.unlink()
    shell = (PROJECT / "scripts" / "web_shell.html").read_text(encoding="utf-8")
    version_match = re.search(r'^config/version="([^\"]+)"$', (PROJECT / "project.godot").read_text(encoding="utf-8"), re.MULTILINE)
    if not version_match:
        raise RuntimeError("Project version is required for the web launch page")
    shell = shell.replace("__GAME_VERSION__", version_match.group(1))
    shell = shell.replace("__GODOT_CONFIG__", json.dumps(config, separators=(",", ":")))
    shell = shell.replace("__WASM_PARTS__", json.dumps(parts, separators=(",", ":")))
    shell = shell.replace("__WASM_BYTES__", str(len(payload)))
    (web / "index.html").write_text(shell, encoding="utf-8")
    for path in web.rglob("*"):
        if path.is_file() and path.stat().st_size > STATIC_FILE_LIMIT:
            raise RuntimeError(f"Static hosting file limit exceeded: {path}")
    print(f"Web engine: {len(payload):,} bytes in {len(parts)} verified parts; every static asset is below 25 MiB")


def verify_archive(path: Path, expected: dict[str, str]) -> None:
    """Validate the ZIP directory, CRCs, and exact uncompressed file content."""
    with zipfile.ZipFile(path) as archive:
        if set(archive.namelist()) != set(expected) or len(archive.namelist()) != len(expected):
            raise RuntimeError(f"Unexpected or missing ZIP members: {path}")
        damaged = archive.testzip()
        if damaged is not None:
            raise RuntimeError(f"ZIP CRC failed for {damaged}: {path}")
        for name, digest in expected.items():
            if hashlib.sha256(archive.read(name)).hexdigest() != digest:
                raise RuntimeError(f"ZIP content changed for {name}: {path}")


def archive_directory(source: Path, target: Path, *, prefix: str = "", exclude_parts: set[str] | None = None, include_hidden: bool = False, executable_names: set[str] | None = None) -> None:
    # Build away from the public path so readers can never consume a partial
    # ZIP. Validate the central directory and every file before replacing it.
    target.parent.mkdir(parents=True, exist_ok=True)
    entries: list[tuple[Path, str]] = []
    expected: dict[str, str] = {}
    for path in sorted(source.rglob("*")):
        relative = path.relative_to(source)
        if not path.is_file() or (exclude_parts and any(part in exclude_parts for part in relative.parts)):
            continue
        if not include_hidden and any(part.startswith(".") for part in relative.parts):
            continue
        name = (Path(prefix) / relative).as_posix()
        entries.append((path, name))
        expected[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    with tempfile.NamedTemporaryFile(prefix=".sudoku-archive-", suffix=".zip", dir=target.parent, delete=False) as pending:
        temporary = Path(pending.name)
    try:
        with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for path, name in entries:
                if executable_names and name in executable_names:
                    info = zipfile.ZipInfo.from_file(path, name)
                    info.create_system = 3
                    info.external_attr = (stat.S_IFREG | 0o755) << 16
                    info.compress_type = zipfile.ZIP_DEFLATED
                    archive.writestr(info, path.read_bytes())
                else:
                    archive.write(path, name)
        verify_archive(temporary, expected)
        temporary.replace(target)
        verify_archive(target, expected)
    finally:
        temporary.unlink(missing_ok=True)


def copy_license_notices(destination: Path, *, native: bool = False) -> None:
    sources = notice_sources(PROJECT) if native else {name: PROJECT / name for name in GODOT_NOTICES}
    for name, source in sources.items():
        if not source.is_file():
            raise RuntimeError(f"Required distribution notice is missing: {source}")
        shutil.copyfile(source, destination / name)


def stage_downloads(build: Path) -> None:
    """Make ordinary desktop ZIP downloads available on small-file static hosts."""
    web = build / "web"
    if not (web / "index.html").exists():
        return
    destination = web / "downloads"
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir()
    packages = []
    for key, label, filename in [
        ("windows", "Windows", "Sudoku-Defense-Godot-Windows.zip"),
        ("linux", "Linux / Steam Deck", "Sudoku-Defense-Godot-Linux.zip"),
        ("source", "Godot project", "Sudoku-Defense-Godot-Source.zip"),
    ]:
        source = build / "downloads" / filename
        if not source.exists():
            continue
        data = source.read_bytes()
        package = {"id": key, "label": label, "filename": filename, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
        if len(data) <= STATIC_FILE_LIMIT:
            shutil.copyfile(source, destination / filename)
            package["url"] = "downloads/" + filename
        else:
            package["parts"] = []
            for position in range(0, len(data), CHUNK_BYTES):
                part = data[position:position + CHUNK_BYTES]
                name = f"{filename}.part{len(package['parts']):02d}"
                (destination / name).write_bytes(part)
                package["parts"].append({"url": "downloads/" + name, "bytes": len(part), "sha256": hashlib.sha256(part).hexdigest()})
            rebuilt = b"".join((web / part["url"]).read_bytes() for part in package["parts"])
            assert rebuilt == data, f"Download chunks changed {filename}"
        packages.append(package)
    manifest = {"godot_version": EXPECTED_VERSION, "built_at": datetime.now(timezone.utc).isoformat(), "packages": packages}
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    shell = (PROJECT / "scripts" / "downloads_shell.html").read_text(encoding="utf-8")
    (web / "downloads.html").write_text(shell.replace("__DOWNLOAD_MANIFEST__", json.dumps(manifest, separators=(",", ":"))), encoding="utf-8")
    for path in web.rglob("*"):
        if path.is_file() and path.stat().st_size > STATIC_FILE_LIMIT:
            raise RuntimeError(f"Static hosting file limit exceeded: {path}")
    print(f"Staged {len(packages)} downloadable packages at {web / 'downloads.html'}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--targets", nargs="+", choices=["web", "linux", "windows"], default=["web", "linux", "windows"])
    parser.add_argument("--skip-import", action="store_true")
    parser.add_argument("--skip-smoke", action="store_true", help="Skip Linux executable boot (for cross-platform builders only)")
    parser.add_argument("--render-check", action="store_true", help="Require real GLES pixel checks; uses Xvfb when no display is available")
    parser.add_argument("--stage-downloads-only", action="store_true", help="Prepare existing archives for static hosting without rebuilding")
    args = parser.parse_args()
    if args.stage_downloads_only:
        stage_downloads(PROJECT / "build")
        return
    version = subprocess.check_output([args.godot, "--headless", "--version"], text=True).strip()
    if not version.startswith(EXPECTED_VERSION + "."):
        raise SystemExit(f"Godot {EXPECTED_VERSION} required; found {version}")
    build = PROJECT / "build"
    logs = build / "logs"
    downloads = build / "downloads"
    logs.mkdir(parents=True, exist_ok=True)
    downloads.mkdir(parents=True, exist_ok=True)
    # Keep exported data out of subsequent resource scans and native packages.
    (build / ".gdignore").touch()
    bootstrap_extension_cache()
    if not args.skip_import:
        run([args.godot, "--headless", "--path", str(PROJECT), "--editor", "--import", "--quit"], logs / "import.log")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_run.gd"], logs / "simulation-tests.log", expected="PASS:")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_sudoku.gd"], logs / "sudoku-tests.log", expected="SUDOKU_PASS")
    for script, marker in [
        ("test_cloud_profile.gd", "CLOUD_PROFILE_PASS"),
        ("test_migration_faults.gd", "MIGRATION_FAULTS_PASS"),
        ("test_journal_faults.gd", "JOURNAL_FAULTS_PASS"),
        ("test_progression_resume.gd", "PROGRESSION_RESUME_PASS"),
        ("test_achievement_rules.gd", "ACHIEVEMENT_RULES_PASS"),
        ("test_achievement_profile.gd", "ACHIEVEMENT_PROFILE_PASS"),
        ("test_steam_platform.gd", "STEAM_PLATFORM_TESTS_OK"),
    ]:
        run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/" + script],
            logs / f"{script.removesuffix('.gd')}.log", expected=marker)
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_tactics.gd"], logs / "tactics-tests.log", expected="TACTICS_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_board_transition.gd"], logs / "board-transition-tests.log", expected="BOARD_TRANSITION_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_board_transition.gd", "--", "--canvas-graphics"], logs / "canvas-board-transition-tests.log", expected="BOARD_TRANSITION_PASS")
    for renderer, flags in [("native", []), ("canvas", ["--", "--canvas-graphics"])]:
        run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_hud_polish.gd"] + flags, logs / f"{renderer}-hud-polish-tests.log", expected="HUD_POLISH_PASS")
        run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_platform_ui.gd"] + flags, logs / f"{renderer}-platform-ui-tests.log", expected="PLATFORM_UI_PASS")
        for script, marker in [("test_recovery_controller.gd", "RECOVERY_CONTROLLER_PASS"), ("test_controller_edges.gd", "CONTROLLER_EDGES_PASS"), ("test_overlay_transitions.gd", "OVERLAY_TRANSITIONS_PASS")]:
            run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/" + script] + flags, logs / f"{renderer}-{script.removesuffix('.gd')}.log", expected=marker)
        run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_controller_upgrades.gd"] + flags, logs / f"{renderer}-controller-upgrades-tests.log", expected="CONTROLLER_UPGRADES_PASS")
        run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_cleanup_pacing.gd"] + flags, logs / f"{renderer}-cleanup-pacing-tests.log", expected="CLEANUP_PACING_PASS")
    for script, marker in [("test_run_save.gd", "RUN_SAVE_PASS"), ("test_strategy_feedback.gd", "STRATEGY_FEEDBACK_PASS"), ("test_results_ui.gd", "RESULTS_UI_PASS"), ("test_audio_settings.gd", "AUDIO_SETTINGS_PASS")]:
        for renderer, flags in [("native", []), ("canvas", ["--", "--canvas-graphics"])]:
            run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/" + script] + flags, logs / f"{renderer}-{script.removesuffix('.gd')}.log", expected=marker)
    for script, marker in [("test_camera_orbit.gd", "CAMERA_ORBIT_PASS"), ("test_camera_controls.gd", "CAMERA_CONTROLS_PASS"), ("test_enemy_health.gd", "ENEMY_HEALTH_PASS"), ("test_preferences.gd", "PREFERENCES_PASS"), ("test_tactics_ui.gd", "TACTICS_UI_PASS"), ("test_controller_number_picker.gd", "CONTROLLER_NUMBER_PICKER_PASS"), ("test_first_round_guide.gd", "FIRST_ROUND_GUIDE_PASS")]:
        for renderer, flags in [("native", []), ("canvas", ["--", "--canvas-graphics"])]:
            run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/" + script] + flags, logs / f"{renderer}-{script.removesuffix('.gd')}.log", expected=marker)
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_ui_flow.gd"], logs / "ui-flow-tests.log", expected="UI_FLOW_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_ui_flow.gd", "--", "--canvas-graphics"], logs / "canvas-ui-flow-tests.log", expected="UI_FLOW_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_menu_presentation.gd"], logs / "menu-presentation-tests.log", expected="MENU_PRESENTATION_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_menu_presentation.gd", "--", "--canvas-graphics"], logs / "canvas-menu-presentation-tests.log", expected="MENU_PRESENTATION_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_controller_flow.gd"], logs / "controller-tests.log", expected="CONTROLLER_FLOW_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_controller_flow.gd", "--", "--canvas-graphics"], logs / "canvas-controller-tests.log", expected="CONTROLLER_FLOW_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_controller_cursor.gd"], logs / "controller-cursor-tests.log", expected="CONTROLLER_CURSOR_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_controller_cursor.gd", "--", "--canvas-graphics"], logs / "canvas-controller-cursor-tests.log", expected="CONTROLLER_CURSOR_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_touch_flow.gd"], logs / "touch-tests.log", expected="TOUCH_FLOW_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_touch_flow.gd", "--", "--canvas-graphics"], logs / "canvas-touch-tests.log", expected="TOUCH_FLOW_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_seed_planting.gd"], logs / "seed-planting-tests.log", expected="SEED_PLANTING_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_seed_planting.gd", "--", "--canvas-graphics"], logs / "canvas-seed-planting-tests.log", expected="SEED_PLANTING_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_pointer_dispatch.gd"], logs / "pointer-dispatch-tests.log", expected="POINTER_DISPATCH_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_pointer_dispatch.gd", "--", "--canvas-graphics"], logs / "canvas-pointer-dispatch-tests.log", expected="POINTER_DISPATCH_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_family_workshop.gd"], logs / "family-workshop-tests.log", expected="FAMILY_WORKSHOP_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_family_workshop.gd", "--", "--canvas-graphics"], logs / "canvas-family-workshop-tests.log", expected="FAMILY_WORKSHOP_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_loot_table.gd"], logs / "loot-table-tests.log", expected="LOOT_TABLE_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_loot_table.gd", "--", "--canvas-graphics"], logs / "canvas-loot-table-tests.log", expected="LOOT_TABLE_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_loot_gear_flow.gd"], logs / "loot-gear-flow-tests.log", expected="LOOT_GEAR_FLOW_PASS")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_loot_gear_flow.gd", "--", "--canvas-graphics"], logs / "canvas-loot-gear-flow-tests.log", expected="LOOT_GEAR_FLOW_PASS")
    if args.render_check:
        render_failures: list[str] = []
        for script, flag, logfile, marker in [
            ("test_hud_polish.gd", "", "native-hud-polish-render-tests.log", "HUD_POLISH_PASS"),
            ("test_hud_polish.gd", "--canvas-graphics", "canvas-hud-polish-render-tests.log", "HUD_POLISH_PASS"),
            ("test_platform_ui.gd", "", "native-platform-ui-render-tests.log", "PLATFORM_UI_PASS"),
            ("test_platform_ui.gd", "--canvas-graphics", "canvas-platform-ui-render-tests.log", "PLATFORM_UI_PASS"),
            ("test_overlay_transitions.gd", "", "native-overlay-transitions-render-tests.log", "OVERLAY_TRANSITIONS_PASS"),
            ("test_overlay_transitions.gd", "--canvas-graphics", "canvas-overlay-transitions-render-tests.log", "OVERLAY_TRANSITIONS_PASS"),
            ("test_cleanup_pacing.gd", "", "native-cleanup-pacing-render-tests.log", "CLEANUP_PACING_PASS"),
            ("test_cleanup_pacing.gd", "--canvas-graphics", "canvas-cleanup-pacing-render-tests.log", "CLEANUP_PACING_PASS"),
            ("test_controller_upgrades.gd", "", "native-controller-upgrades-render-tests.log", "CONTROLLER_UPGRADES_PASS"),
            ("test_controller_upgrades.gd", "--canvas-graphics", "canvas-controller-upgrades-render-tests.log", "CONTROLLER_UPGRADES_PASS"),
            ("test_prerelease_render.gd", "", "native-prerelease-render-tests.log", "PRERELEASE_RENDER_PASS"),
            ("test_prerelease_render.gd", "--canvas-graphics", "canvas-prerelease-render-tests.log", "PRERELEASE_RENDER_PASS"),
            ("test_controller_number_picker.gd", "", "native-controller-number-picker-render-tests.log", "CONTROLLER_NUMBER_PICKER_PASS"),
            ("test_controller_number_picker.gd", "--canvas-graphics", "canvas-controller-number-picker-render-tests.log", "CONTROLLER_NUMBER_PICKER_PASS"),
            ("test_tactics_ui.gd", "", "native-tactics-render-tests.log", "TACTICS_UI_PASS"),
            ("test_tactics_ui.gd", "--canvas-graphics", "canvas-tactics-render-tests.log", "TACTICS_UI_PASS"),
            ("test_enemy_health.gd", "", "native-enemy-health-render-tests.log", "ENEMY_HEALTH_PASS"),
            ("test_enemy_health.gd", "--canvas-graphics", "canvas-enemy-health-render-tests.log", "ENEMY_HEALTH_PASS"),
            ("test_board_readability.gd", "", "native-readability-tests.log", "READABILITY_PASS"),
            ("test_board_readability.gd", "--canvas-graphics", "canvas-readability-tests.log", "READABILITY_PASS"),
            ("test_rendering.gd", "--safe-graphics", "rendering-tests.log", "RENDER_PASS"),
            ("test_canvas_rendering.gd", "--canvas-graphics", "canvas-rendering-tests.log", "CANVAS_RENDER_PASS"),
            ("test_chest_canvas.gd", "--canvas-graphics", "canvas-chest-tests.log", "0 failures (real GLES pixels)"),
            ("test_seed_planting.gd", "--safe-graphics", "seed-planting-render-tests.log", "SEED_PLANTING_PASS"),
            ("test_seed_planting.gd", "--canvas-graphics", "canvas-seed-planting-render-tests.log", "SEED_PLANTING_PASS"),
            ("test_menu_presentation.gd", "--safe-graphics", "menu-presentation-render-tests.log", "MENU_PRESENTATION_PASS"),
            ("test_menu_presentation.gd", "--canvas-graphics", "canvas-menu-presentation-render-tests.log", "MENU_PRESENTATION_PASS"),
            ("test_controller_cursor.gd", "--safe-graphics", "controller-cursor-render-tests.log", "CONTROLLER_CURSOR_PASS"),
            ("test_controller_cursor.gd", "--canvas-graphics", "canvas-controller-cursor-render-tests.log", "CONTROLLER_CURSOR_PASS"),
            ("test_camera_controls.gd", "--safe-graphics", "camera-controls-render-tests.log", "CAMERA_CONTROLS_PASS"),
            ("test_camera_controls.gd", "--canvas-graphics", "canvas-camera-controls-render-tests.log", "CAMERA_CONTROLS_PASS"),
            ("test_loot_gear_flow.gd", "--safe-graphics", "loot-gear-render-tests.log", "LOOT_GEAR_FLOW_PASS"),
            ("test_loot_gear_flow.gd", "--canvas-graphics", "canvas-loot-gear-render-tests.log", "LOOT_GEAR_FLOW_PASS"),
        ]:
            command = [args.godot, "--path", str(PROJECT), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_es", "--script", "res://tests/" + script]
            if flag:
                command += ["--", flag]
            if script == "test_camera_controls.gd":
                command += ["--capture-camera"]
            if script in ("test_controller_upgrades.gd", "test_cleanup_pacing.gd", "test_platform_ui.gd", "test_hud_polish.gd", "test_overlay_transitions.gd"):
                if not flag:
                    command += ["--"]
                command += ["--render-check"]
            if script == "test_tactics_ui.gd":
                if not flag:
                    command += ["--"]
                command += ["--capture-tactics"]
            if not os.environ.get("DISPLAY"):
                xvfb = shutil.which("xvfb-run")
                if not xvfb:
                    raise SystemExit("The render check requires a display or xvfb-run; headless rendering cannot validate pixels.")
                command = [xvfb, "-a", "-s", "-screen 0 1920x1600x24"] + command
            try:
                run(command, logs / logfile, expected=marker)
            except SystemExit as error:
                # Collect independent render failures and their screenshots in
                # one CI run, but never export a candidate unless every check passes.
                render_failures.append(logfile)
                print(error, flush=True)
        if render_failures:
            raise SystemExit("Rendering checks failed: " + ", ".join(render_failures))
    export_releases(args, build, downloads, logs)


def export_releases(args: argparse.Namespace, build: Path, downloads: Path, logs: Path) -> None:
    """Package the validated source; usable separately after packaging-only fixes."""
    match = re.search(r'^config/version="([^"]+)"$', (PROJECT / "project.godot").read_text(encoding="utf-8"), re.MULTILINE)
    if not match:
        raise RuntimeError("Project application version is required for package verification")
    app_version = match.group(1)
    targets = {"web": ("Web", "index.html"), "linux": ("Linux", "sudoku-defense.x86_64"), "windows": ("Windows", "SudokuDefense.exe")}
    for name in args.targets:
        folder = build / name
        if folder.exists():
            shutil.rmtree(folder)
        folder.mkdir()
        preset, executable = targets[name]
        # Never accept a prior executable after an exporter fails to replace it.
        # A unique directory starts empty and cannot contain a previous release.
        with tempfile.TemporaryDirectory(prefix=f"sudoku-export-{name}-") as staging:
            staged_output = Path(staging) / executable
            run([args.godot, "--headless", "--path", str(PROJECT), "--export-release", preset, str(staged_output)], logs / f"export-{name}.log")
            if not staged_output.exists() or staged_output.stat().st_size == 0:
                raise RuntimeError(f"Missing fresh export: {staged_output}")
            shutil.copytree(staging, folder, dirs_exist_ok=True)
        output = folder / executable
        copy_license_notices(folder, native=name != "web")
        if name == "web":
            if any(path.suffix.lower() in (".dll", ".so", ".gdextension") for path in folder.rglob("*")):
                raise RuntimeError("Browser export unexpectedly contains a native Steam dependency")
            make_web_shell(folder)
        else:
            write_metadata(PROJECT, folder, name, app_version)
        if name == "linux":
            output.chmod(0o755)
            if not args.skip_smoke:
                run([str(output), "--headless", "--audio-driver", "Dummy", "--quit-after", "120", "--", "--smoke-test"], logs / "native-linux-boot.log", expected=f"SUDOKU_DEFENSE_READY version={app_version}")
            with tarfile.open(downloads / "Sudoku-Defense-Godot-Linux-x86_64.tar.gz", "w:gz") as archive:
                for path in sorted(folder.rglob("*")):
                    relative = path.relative_to(folder)
                    if path.is_file() and not any(part.startswith(".") for part in relative.parts):
                        entry = archive.gettarinfo(str(path), arcname=relative.as_posix())
                        # Windows chmod cannot set POSIX execute bits. Preserve
                        # Linux launchability when cross-building on Windows.
                        if path == output or relative.as_posix() in LIBRARIES["linux"]:
                            entry.mode = 0o755
                        with path.open("rb") as payload:
                            archive.addfile(entry, payload)
        if name != "web":
            archive_directory(folder, downloads / f"Sudoku-Defense-Godot-{name.capitalize()}.zip",
                              executable_names={executable, *LIBRARIES["linux"]} if name == "linux" else None)
    archive_directory(
        PROJECT, downloads / "Sudoku-Defense-Godot-Source.zip",
        prefix="Sudoku-Defense-Godot", exclude_parts={"build", ".godot", "__pycache__", ".git"}, include_hidden=True,
    )
    stage_downloads(build)
    if (build / "web" / "index.html").exists():
        # The distributable browser ZIP also contains its desktop-download page.
        archive_directory(build / "web", downloads / "Sudoku-Defense-Godot-Web.zip")
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(downloads.glob("*")) if p.is_file() and p.name != "SHA256SUMS.txt"}
    (downloads / "SHA256SUMS.txt").write_text("".join(f"{digest}  {name}\n" for name, digest in hashes.items()), encoding="utf-8")
    print(f"Completed: {downloads}")


if __name__ == "__main__":
    main()
