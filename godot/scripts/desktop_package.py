"""Exact desktop payload contract shared by exports and Steam staging.

Native dependencies are pinned to the checked-in upstream acquisition record.
Nothing here initializes Steam or accepts an arbitrary library from an archive.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import subprocess

GODOT_NOTICES = ("GODOT-LICENSE.txt", "GODOT-THIRD-PARTY.txt")
STEAM_NOTICES = ("GODOTSTEAM-LICENSE.txt", "STEAMWORKS-NOTICE.txt")
NOTICES = GODOT_NOTICES + STEAM_NOTICES
EXECUTABLES = {"linux": "sudoku-defense.x86_64", "windows": "SudokuDefense.exe"}
LIBRARIES = {
    "linux": {
        "libgodotsteam.linux.template_release.x86_64.so": "linux64/libgodotsteam.linux.template_release.x86_64.so",
        "libsteam_api.so": "linux64/libsteam_api.so",
    },
    "windows": {
        "libgodotsteam.windows.template_release.x86_64.dll": "win64/libgodotsteam.windows.template_release.x86_64.dll",
        "steam_api64.dll": "win64/steam_api64.dll",
    },
}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def metadata_name(platform: str) -> str:
    return f"BUILD-METADATA-{platform}.json"


def expected_names(platform: str) -> set[str]:
    return {EXECUTABLES[platform], *NOTICES, *LIBRARIES[platform], metadata_name(platform)}


def notice_sources(project: Path) -> dict[str, Path]:
    addon = project / "addons/godotsteam"
    return {**{name: project / name for name in GODOT_NOTICES},
            "GODOTSTEAM-LICENSE.txt": addon / "license.md",
            "STEAMWORKS-NOTICE.txt": addon / "STEAMWORKS-NOTICE.txt"}


def locked_native_sources(project: Path, platform: str) -> dict[str, bytes]:
    addon = project / "addons/godotsteam"
    lock = json.loads((addon / "dependency-lock.json").read_text(encoding="utf-8-sig"))
    if lock.get("version") != "4.23.2" or lock.get("steamworks_sdk") != "1.65":
        raise ValueError("Review package allowlists before changing the pinned Steam integration")
    records = {entry["path"]: entry for entry in lock["files"]}
    result = {}
    for target, source in LIBRARIES[platform].items():
        payload = (addon / source).read_bytes()
        record = records.get(source, {})
        if record.get("sha256") != digest(payload) or record.get("bytes") != len(payload):
            raise ValueError(f"Pinned native dependency changed: {source}")
        result[target] = payload
    return result


def validate_payload(project: Path, platform: str, content: dict[str, bytes], *,
                     version: str | None = None, source_commit: str | None = None) -> dict:
    if set(content) != expected_names(platform):
        raise ValueError(f"Unexpected {platform} package members: {sorted(set(content) ^ expected_names(platform))}")
    for name, source in notice_sources(project).items():
        if content[name] != source.read_bytes():
            raise ValueError(f"Distribution notice differs from the source: {name}")
    for name, payload in locked_native_sources(project, platform).items():
        if content[name] != payload:
            raise ValueError(f"Native dependency differs from the pinned source: {name}")
    metadata = json.loads(content[metadata_name(platform)].decode("utf-8"))
    if not isinstance(metadata, dict) or metadata.get("schema_version") != 1 or metadata.get("platform") != platform:
        raise ValueError(f"Invalid {platform} build metadata")
    if not re.fullmatch(r"[0-9a-f]{40}", str(metadata.get("source_commit", ""))):
        raise ValueError("Missing full source commit in build metadata")
    if version is not None and metadata.get("game_version") != version:
        raise ValueError(f"{platform} package game version differs from candidate")
    if source_commit is not None and metadata.get("source_commit") != source_commit:
        raise ValueError(f"{platform} package source commit differs from candidate")
    expected = {name: {"bytes": len(data), "sha256": digest(data)}
                for name, data in content.items() if name != metadata_name(platform)}
    if metadata.get("files") != expected:
        raise ValueError(f"{platform} package bytes differ from its build metadata")
    return metadata


def write_metadata(project: Path, folder: Path, platform: str, version: str) -> None:
    expected = expected_names(platform) - {metadata_name(platform)}
    actual = {path.relative_to(folder).as_posix() for path in folder.rglob("*") if path.is_file()}
    if actual != expected:
        raise ValueError(f"Unexpected native export layout: {sorted(actual ^ expected)}")
    repository = project.resolve().parent
    git = ["git", "-c", f"safe.directory={repository.as_posix()}", "-C", str(repository)]
    changes = subprocess.check_output([*git, "status", "--porcelain", "--untracked-files=all", "--", project.name], cwd=repository, text=True).strip()
    if changes:
        raise ValueError("Commit the candidate Godot source before producing versioned desktop packages")
    commit = subprocess.check_output([*git, "rev-parse", "HEAD"], cwd=repository, text=True).strip()
    metadata = {"schema_version": 1, "platform": platform, "game_version": version,
                "source_commit": commit, "godotsteam_version": "4.23.2", "steamworks_sdk": "1.65",
                "files": {name: {"bytes": (folder / name).stat().st_size,
                                  "sha256": digest((folder / name).read_bytes())}
                          for name in sorted(expected)}}
    (folder / metadata_name(platform)).write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    validate_payload(project, platform, {path.name: path.read_bytes() for path in folder.iterdir() if path.is_file()},
                     version=version, source_commit=commit)
