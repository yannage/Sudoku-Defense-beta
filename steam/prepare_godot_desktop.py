#!/usr/bin/env python3
"""Combine verified Linux and Windows CI exports for the existing Steam depot.

Use both desktop ZIPs from the same successful workflow run and its Windows
startup-validation JSON. This prepares a complete replacement archive; it does
not authenticate, upload, activate a Steam build, or publish app configuration.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import stat
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
RELEASE = ROOT / "release"
STAGE = RELEASE / "steam-godot-desktop"
NOTICES = ("GODOT-LICENSE.txt", "GODOT-THIRD-PARTY.txt")
LINUX_NAME = "sudoku-defense.x86_64"
WINDOWS_NAME = "SudokuDefense.exe"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_package(path: Path, executable: str) -> tuple[dict[str, bytes], str]:
    """Read an exact, flat release package without extracting any ZIP paths."""
    raw = path.read_bytes()
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != 3 or set(names) != {executable, *NOTICES}:
            raise ValueError(f"Expected only {executable} and both Godot notices: {path}")
        for info in archive.infolist():
            file_type = stat.S_IFMT(info.external_attr >> 16)
            if info.is_dir() or info.flag_bits & 1 or file_type not in (0, stat.S_IFREG):
                raise ValueError(f"ZIP member is not an ordinary unencrypted file: {info.filename}")
            limit = 512 * 1024 * 1024 if info.filename == executable else 2 * 1024 * 1024
            if not 0 < info.file_size <= limit:
                raise ValueError(f"Unexpected ZIP member size: {info.filename}")
        # ZipFile.read checks each member's CRC while reading it.
        content = {name: archive.read(name) for name in names}
    return content, sha256(raw)


def validate_executables(linux: bytes, windows: bytes) -> None:
    if len(linux) < 64 or linux[:6] != b"\x7fELF\x02\x01" or int.from_bytes(linux[18:20], "little") != 62:
        raise ValueError("Linux export must be a native x86-64 ELF executable")
    if len(windows) < 64 or windows[:2] != b"MZ":
        raise ValueError("Windows export is missing its DOS/PE header")
    offset = int.from_bytes(windows[60:64], "little")
    if (offset < 64 or offset + 26 > len(windows)
            or windows[offset:offset + 4] != b"PE\0\0"
            or int.from_bytes(windows[offset + 4:offset + 6], "little") != 0x8664
            or int.from_bytes(windows[offset + 24:offset + 26], "little") != 0x20B):
        raise ValueError("Windows export must be a native x86-64 PE32+ executable")


def verify_combined(path: Path, content: dict[str, bytes]) -> None:
    with zipfile.ZipFile(path) as archive:
        if len(archive.namelist()) != 4 or set(archive.namelist()) != set(content):
            raise ValueError("Combined Steam ZIP must contain both executables and both notices")
        for name, original in content.items():
            if archive.read(name) != original:
                raise ValueError(f"Combined ZIP changed bytes for {name}")
        if (archive.getinfo("sudoku-defense").external_attr >> 16) & 0o777 != 0o755:
            raise ValueError("Combined ZIP lost Linux executable permissions")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--linux-archive", type=Path, required=True)
    parser.add_argument("--windows-archive", type=Path, required=True)
    parser.add_argument("--windows-validation", type=Path, required=True)
    parser.add_argument("--source-commit", required=True, help="Exact source SHA of the successful CI workflow")
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.source_commit):
        raise SystemExit("--source-commit must be a full lowercase 40-character SHA")
    match = re.search(r'^config/version="([A-Za-z0-9._-]+)"$', (ROOT / "godot/project.godot").read_text(), re.MULTILINE)
    if not match:
        raise SystemExit("Project has no safe package version")
    version = match.group(1)
    marker = f"SUDOKU_DEFENSE_READY version={version}"
    try:
        linux, linux_archive_hash = read_package(args.linux_archive, LINUX_NAME)
        windows, windows_archive_hash = read_package(args.windows_archive, WINDOWS_NAME)
        validate_executables(linux[LINUX_NAME], windows[WINDOWS_NAME])
        validation_bytes = args.windows_validation.read_bytes()
        validation = json.loads(validation_bytes.decode("utf-8-sig"))
        expected = {
            "status": "passed", "source_commit": args.source_commit,
            "game_version": version, "ready_marker": marker,
            "archive_sha256": windows_archive_hash,
            "executable_sha256": sha256(windows[WINDOWS_NAME]),
        }
        for key, value in expected.items():
            if not isinstance(validation, dict) or validation.get(key) != value:
                raise ValueError(f"Windows startup validation does not match {key}")
        for name in NOTICES:
            if linux[name] != windows[name] or linux[name] != (ROOT / "godot" / name).read_bytes():
                raise ValueError(f"Linux, Windows, and project notices differ: {name}")
        content = {"sudoku-defense": linux[LINUX_NAME], WINDOWS_NAME: windows[WINDOWS_NAME],
                   **{name: linux[name] for name in NOTICES}}
        RELEASE.mkdir(exist_ok=True)
        archive_path = RELEASE / f"Sudoku-Defense-Godot-Steam-Desktop-{version}.zip"
        manifest_path = RELEASE / "steam-godot-desktop-manifest.json"
        boot_log = RELEASE / "steam-godot-desktop-linux-boot.log"
        with tempfile.TemporaryDirectory(prefix=".desktop-stage-", dir=RELEASE) as temporary:
            pending = Path(temporary)
            stage = pending / "content"
            stage.mkdir()
            for name, data in content.items():
                target = stage / name
                target.write_bytes(data)
                target.chmod(0o755 if name == "sudoku-defense" else 0o644)
            result = subprocess.run(
                [str(stage / "sudoku-defense"), "--headless", "--audio-driver", "Dummy",
                 "--quit-after", "120", "--", "--smoke-test"], cwd=stage,
                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90,
            )
            boot_log.write_text(result.stdout)
            if result.returncode or "ERROR:" in result.stdout or "Parse Error:" in result.stdout or marker not in result.stdout.splitlines():
                raise ValueError(f"Renamed Linux export failed startup; inspect {boot_log}")
            packed = pending / "desktop.zip"
            with zipfile.ZipFile(packed, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
                for path in sorted(stage.iterdir()):
                    archive.write(path, path.name)
            verify_combined(packed, content)
            manifest = {
                "schema_version": 1, "app_id": "3721150", "depot_id": "3721151",
                "game_version": version, "source_commit": args.source_commit,
                "prepared_at": datetime.now(timezone.utc).isoformat(),
                "upload_status": "pending", "steam_build_id": None,
                "steam_depot_manifest_id": None, "upload_mode": "Standard replacement",
                "complete_shared_depot": True,
                "archive": str(archive_path), "archive_bytes": packed.stat().st_size,
                "archive_sha256": sha256(packed.read_bytes()),
                "source_packages": {
                    "linux": {"path": str(args.linux_archive.resolve()), "sha256": linux_archive_hash},
                    "windows": {"path": str(args.windows_archive.resolve()), "sha256": windows_archive_hash},
                },
                "windows_startup_validation": {**expected, "evidence_sha256": sha256(validation_bytes)},
                "linux_startup": {"status": "passed", "ready_marker": marker, "log": str(boot_log)},
                "files": [{"path": name, "bytes": len(data), "sha1": hashlib.sha1(data).hexdigest(),
                           "sha256": sha256(data), "mode": "0o755" if name == "sudoku-defense" else "0o644"}
                          for name, data in sorted(content.items())],
            }
            pending_manifest = pending / "manifest.json"
            pending_manifest.write_text(json.dumps(manifest, indent=2) + "\n")
            if STAGE.exists():
                shutil.rmtree(STAGE)
            stage.replace(STAGE)
            packed.replace(archive_path)
            pending_manifest.replace(manifest_path)
        print(json.dumps({"stage": str(STAGE), "archive": str(archive_path),
                          "sha256": manifest["archive_sha256"], "manifest": str(manifest_path),
                          "upload_status": "pending", "upload_mode": manifest["upload_mode"],
                          "boot": marker}, indent=2))
    except (OSError, ValueError, zipfile.BadZipFile, subprocess.TimeoutExpired) as error:
        raise SystemExit(f"Desktop staging failed: {error}") from error


if __name__ == "__main__":
    main()
