#!/usr/bin/env python3
"""Stage the tested Godot Linux export for the existing Steam depot.

This prepares files only. It does not authenticate, upload, or activate a build.
The stable Steam executable name keeps existing launch options and old branches
compatible while the normal desktop download retains its .x86_64 filename.
The depot also contains Windows. Upload this Linux-only archive with Steamworks
Merge With Baseline against the current live build to preserve that executable.
"""
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
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "godot/scripts"))
from desktop_package import LIBRARIES, expected_names, validate_payload  # noqa: E402

SOURCE = ROOT / "godot" / "build" / "linux"
RELEASE = ROOT / "release"
STAGE = RELEASE / "steam-godot-linux"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-commit", help="Canonical GitHub source commit, if different from this equivalent local checkout")
    args = parser.parse_args()
    if args.source_commit and not re.fullmatch(r"[0-9a-f]{40}", args.source_commit):
        raise SystemExit("--source-commit must be a full 40-character commit SHA")
    match = re.search(r'^config/version="([^"]+)"$', (ROOT / "godot" / "project.godot").read_text(), re.MULTILINE)
    if not match or not re.fullmatch(r"[A-Za-z0-9._-]+", match.group(1)):
        raise SystemExit("Project has no safe package version")
    version = match.group(1)
    git = ["git", "-c", f"safe.directory={ROOT.as_posix()}", "-C", str(ROOT)]
    local_commit = subprocess.check_output([*git, "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    source_commit = args.source_commit or local_commit
    actual = {path.relative_to(SOURCE).as_posix() for path in SOURCE.rglob("*") if path.is_file()}
    if actual != expected_names("linux"):
        raise SystemExit("Linux export contains missing or unexpected payload files")
    content = {name: (SOURCE / name).read_bytes() for name in actual}
    validate_payload(ROOT / "godot", "linux", content, version=version, source_commit=source_commit)
    original = SOURCE / "sudoku-defense.x86_64"
    header = original.read_bytes()[:20]
    if header[:6] != b"\x7fELF\x02\x01" or int.from_bytes(header[18:20], "little") != 62:
        raise SystemExit("Expected the exported Linux x86-64 ELF, not a wrapper or Windows executable")
    RELEASE.mkdir(exist_ok=True)
    if STAGE.exists():
        shutil.rmtree(STAGE)
    STAGE.mkdir()
    executable = STAGE / "sudoku-defense"
    content["sudoku-defense"] = content.pop("sudoku-defense.x86_64")
    for name, payload in content.items():
        target = STAGE / name
        target.write_bytes(payload)
        target.chmod(0o755 if name in {"sudoku-defense", *LIBRARIES["linux"]} else 0o644)
    if digest(original) != digest(executable):
        raise SystemExit("Renaming for Steam must not change executable bytes")
    with tempfile.TemporaryDirectory(prefix=".linux-stage-profile-", dir=RELEASE) as profile:
        environment = os.environ.copy()
        for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            folder = Path(profile) / key.lower()
            folder.mkdir()
            environment[key] = str(folder)
        result = subprocess.run(
            [str(executable), "--headless", "--audio-driver", "Dummy", "--quit-after", "120", "--", "--smoke-test", "--no-steam"],
            cwd=STAGE, env=environment, text=True, encoding="utf-8", errors="replace", stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90,
        )
    boot_log = RELEASE / "steam-godot-linux-boot.log"
    boot_log.write_text(result.stdout)
    if result.returncode or "ERROR:" in result.stdout or f"SUDOKU_DEFENSE_READY version={version}" not in result.stdout:
        raise SystemExit(f"Renamed executable failed startup; inspect {boot_log}")
    archive_path = RELEASE / f"Sudoku-Defense-Godot-Steam-Linux-{version}.zip"
    with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(STAGE.iterdir()):
            info = zipfile.ZipInfo.from_file(path, path.name)
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | (0o755 if path.name in {"sudoku-defense", *LIBRARIES["linux"]} else 0o644)) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, path.read_bytes())
    with zipfile.ZipFile(archive_path) as archive:
        if archive.testzip() is not None or set(archive.namelist()) != set(content) or len(archive.namelist()) != len(content):
            raise SystemExit("Steam archive contents or CRC verification failed")
        for name, payload in content.items():
            if archive.read(name) != payload:
                raise SystemExit(f"Steam archive changed {name}")
        for name in {"sudoku-defense", *LIBRARIES["linux"]}:
            if (archive.getinfo(name).external_attr >> 16) & 0o777 != 0o755:
                raise SystemExit(f"Steam archive lost executable permissions: {name}")
    tree = subprocess.check_output([*git, "rev-parse", "HEAD^{tree}"], cwd=ROOT, text=True).strip()
    manifest = {
        "app_id": "3721150", "depot_id": "3721151", "game_version": version,
        "source_commit": args.source_commit or local_commit, "local_source_commit": local_commit,
        "source_tree": tree, "prepared_at": datetime.now(timezone.utc).isoformat(),
        "upload_status": "pending", "steam_build_id": None, "steam_depot_manifest_id": None,
        "upload_mode": "Merge With Baseline", "baseline_requirement": "Current live build; preserve Windows executable", "launch_executable": "sudoku-defense",
        "archive": str(archive_path), "archive_bytes": archive_path.stat().st_size,
        "archive_sha256": digest(archive_path),
        "files": [{"path": path.name, "bytes": path.stat().st_size, "sha256": digest(path), "mode": oct(path.stat().st_mode & 0o777)} for path in sorted(STAGE.iterdir())],
    }
    manifest_path = RELEASE / "steam-godot-linux-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"stage": str(STAGE), "archive": str(archive_path), "sha256": manifest["archive_sha256"], "manifest": str(manifest_path), "boot": f"SUDOKU_DEFENSE_READY version={version}", "upload_status": "pending", "upload_mode": manifest["upload_mode"], "baseline_requirement": manifest["baseline_requirement"]}, indent=2))


if __name__ == "__main__":
    main()
