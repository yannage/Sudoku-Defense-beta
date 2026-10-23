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
import subprocess
import tarfile
import zipfile

PROJECT = Path(__file__).resolve().parents[1]
EXPECTED_VERSION = "4.7.2"
CHUNK_BYTES = 10 * 1024 * 1024
STATIC_FILE_LIMIT = 25 * 1024 * 1024


def run(command: list[str], log: Path, expected: str | None = None) -> None:
    result = subprocess.run(command, cwd=PROJECT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
    log.write_text(result.stdout)
    problems = [line for line in result.stdout.splitlines() if "ERROR:" in line or "Parse Error:" in line]
    if result.returncode or problems or (expected is not None and expected not in result.stdout):
        print(result.stdout)
        if expected is not None and expected not in result.stdout:
            print(f"Missing required completion marker: {expected}")
        raise SystemExit(f"Build failed; inspect {log}")
    print(f"OK: {' '.join(command[-4:])}")


def make_web_shell(web: Path) -> None:
    """Preserve Godot's exported config; split only the large engine transport."""
    original = (web / "index.html").read_text()
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
    (web / "engine-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    engine_path.unlink()
    shell = (PROJECT / "scripts" / "web_shell.html").read_text()
    shell = shell.replace("__GODOT_CONFIG__", json.dumps(config, separators=(",", ":")))
    shell = shell.replace("__WASM_PARTS__", json.dumps(parts, separators=(",", ":")))
    shell = shell.replace("__WASM_BYTES__", str(len(payload)))
    (web / "index.html").write_text(shell)
    for path in web.rglob("*"):
        if path.is_file() and path.stat().st_size > STATIC_FILE_LIMIT:
            raise RuntimeError(f"Static hosting file limit exceeded: {path}")
    print(f"Web engine: {len(payload):,} bytes in {len(parts)} verified parts; every static asset is below 25 MiB")


def archive_directory(source: Path, target: Path) -> None:
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(source.rglob("*")):
            relative = path.relative_to(source)
            # Godot may leave a hidden temporary executable while exporting.
            # Only public output files belong in a downloadable distribution.
            if path.is_file() and not any(part.startswith(".") for part in relative.parts):
                archive.write(path, relative)


def copy_license_notices(destination: Path) -> None:
    for name in ("GODOT-LICENSE.txt", "GODOT-THIRD-PARTY.txt"):
        source = PROJECT / name
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
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    shell = (PROJECT / "scripts" / "downloads_shell.html").read_text()
    (web / "downloads.html").write_text(shell.replace("__DOWNLOAD_MANIFEST__", json.dumps(manifest, separators=(",", ":"))))
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
    if not args.skip_import:
        run([args.godot, "--headless", "--path", str(PROJECT), "--editor", "--import", "--quit"], logs / "import.log")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_run.gd"], logs / "simulation-tests.log", expected="PASS:")
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/test_ui_flow.gd"], logs / "ui-flow-tests.log", expected="UI_FLOW_PASS")
    if args.render_check:
        command = [args.godot, "--path", str(PROJECT), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_es", "--script", "res://tests/test_rendering.gd", "--", "--safe-graphics"]
        if not os.environ.get("DISPLAY"):
            xvfb = shutil.which("xvfb-run")
            if not xvfb:
                raise SystemExit("The render check requires a display or xvfb-run; headless rendering cannot validate pixels.")
            command = [xvfb, "-a", "-s", "-screen 0 1600x1200x24"] + command
        run(command, logs / "rendering-tests.log", expected="RENDER_PASS")
    targets = {"web": ("Web", "index.html"), "linux": ("Linux", "sudoku-defense.x86_64"), "windows": ("Windows", "SudokuDefense.exe")}
    for name in args.targets:
        folder = build / name
        if folder.exists():
            shutil.rmtree(folder)
        folder.mkdir()
        preset, executable = targets[name]
        output = folder / executable
        run([args.godot, "--headless", "--path", str(PROJECT), "--export-release", preset, str(output)], logs / f"export-{name}.log")
        if not output.exists() or output.stat().st_size == 0:
            raise RuntimeError(f"Missing export: {output}")
        copy_license_notices(folder)
        if name == "web":
            make_web_shell(folder)
        elif name == "linux":
            output.chmod(0o755)
            if not args.skip_smoke:
                run([str(output), "--headless", "--audio-driver", "Dummy", "--quit-after", "120", "--", "--smoke-test"], logs / "native-linux-boot.log", expected="SUDOKU_DEFENSE_READY")
            with tarfile.open(downloads / "Sudoku-Defense-Godot-Linux-x86_64.tar.gz", "w:gz") as archive:
                for path in sorted(folder.rglob("*")):
                    relative = path.relative_to(folder)
                    if path.is_file() and not any(part.startswith(".") for part in relative.parts):
                        archive.add(path, arcname=str(relative), recursive=False)
        if name != "web":
            archive_directory(folder, downloads / f"Sudoku-Defense-Godot-{name.capitalize()}.zip")
    with zipfile.ZipFile(downloads / "Sudoku-Defense-Godot-Source.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(PROJECT.rglob("*")):
            relative = path.relative_to(PROJECT)
            if path.is_file() and not any(part in {"build", ".godot", "__pycache__", ".git"} for part in relative.parts):
                archive.write(path, Path("Sudoku-Defense-Godot") / relative)
    stage_downloads(build)
    if (build / "web" / "index.html").exists():
        # The distributable browser ZIP also contains its desktop-download page.
        archive_directory(build / "web", downloads / "Sudoku-Defense-Godot-Web.zip")
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(downloads.glob("*")) if p.is_file() and p.name != "SHA256SUMS.txt"}
    (downloads / "SHA256SUMS.txt").write_text("".join(f"{digest}  {name}\n" for name, digest in hashes.items()))
    print(f"Completed: {downloads}")


if __name__ == "__main__":
    main()
