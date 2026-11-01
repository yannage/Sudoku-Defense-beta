"""Packaging boundaries: pinned runtimes, exact provenance and safe test launches."""
from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import warnings
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot"
sys.path.insert(0, str(PROJECT / "scripts"))
import desktop_package as contract
import build_exports

spec = importlib.util.spec_from_file_location("desktop_staging", ROOT / "steam/prepare_godot_desktop.py")
staging = importlib.util.module_from_spec(spec)
spec.loader.exec_module(staging)
COMMIT = "a" * 40


def package(platform: str) -> dict[str, bytes]:
    content = {name: path.read_bytes() for name, path in contract.notice_sources(PROJECT).items()}
    content.update(contract.locked_native_sources(PROJECT, platform))
    if platform == "linux":
        executable = bytearray(128)
        executable[:6] = b"\x7fELF\x02\x01"
        executable[18:20] = (62).to_bytes(2, "little")
    else:
        executable = bytearray(256)
        executable[:2] = b"MZ"
        executable[60:64] = (128).to_bytes(4, "little")
        executable[128:132] = b"PE\0\0"
        executable[132:134] = (0x8664).to_bytes(2, "little")
        executable[152:154] = (0x20B).to_bytes(2, "little")
    content[contract.EXECUTABLES[platform]] = bytes(executable)
    metadata = {"schema_version": 1, "platform": platform, "game_version": "0.3.19", "source_commit": COMMIT,
                "files": {name: {"bytes": len(data), "sha256": contract.digest(data)} for name, data in content.items()}}
    content[contract.metadata_name(platform)] = json.dumps(metadata).encode()
    return content


class DesktopPackagingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.linux = package("linux")
        cls.windows = package("windows")

    def test_exact_source_and_dependencies_pass(self):
        for platform, content in [("linux", self.linux), ("windows", self.windows)]:
            self.assertEqual(len(content), 8)
            contract.validate_payload(PROJECT, platform, content, version="0.3.19", source_commit=COMMIT)
        staging.validate_executables(self.linux[contract.EXECUTABLES["linux"]], self.windows[contract.EXECUTABLES["windows"]])

    def test_wrong_version_or_commit_rejected(self):
        for options in [{"version": "0.3.18"}, {"source_commit": "b" * 40}]:
            with self.assertRaises(ValueError):
                contract.validate_payload(PROJECT, "linux", self.linux, **options)

    def test_runtime_tampering_rejected_even_with_matching_metadata(self):
        content = self.windows.copy()
        content["steam_api64.dll"] += b"changed"
        metadata = json.loads(content[contract.metadata_name("windows")])
        metadata["files"]["steam_api64.dll"] = {"bytes": len(content["steam_api64.dll"]), "sha256": contract.digest(content["steam_api64.dll"])}
        content[contract.metadata_name("windows")] = json.dumps(metadata).encode()
        with self.assertRaisesRegex(ValueError, "pinned"):
            contract.validate_payload(PROJECT, "windows", content)

    def test_changed_executable_rejected_by_metadata(self):
        content = self.windows.copy()
        content["SudokuDefense.exe"] += b"changed"
        with self.assertRaisesRegex(ValueError, "metadata"):
            contract.validate_payload(PROJECT, "windows", content)

    def test_wrong_notice_rejected(self):
        content = self.windows.copy()
        content["GODOTSTEAM-LICENSE.txt"] = b"incorrect"
        with self.assertRaisesRegex(ValueError, "notice"):
            contract.validate_payload(PROJECT, "windows", content)

    def test_no_debug_library_or_appid_override_in_release(self):
        for extra in ["steam_appid.txt", "libgodotsteam.windows.template_debug.x86_64.dll", "../outside"]:
            content = {**self.windows, extra: b"3721150"}
            with self.assertRaisesRegex(ValueError, "members"):
                contract.validate_payload(PROJECT, "windows", content)

    def test_missing_runtime_rejected(self):
        content = self.linux.copy()
        del content["libsteam_api.so"]
        with self.assertRaises(ValueError):
            contract.validate_payload(PROJECT, "linux", content)

    def test_archive_duplicate_and_symlink_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive_path = Path(temporary) / "test.zip"
            for bad in ["duplicate", "symlink"]:
                with zipfile.ZipFile(archive_path, "w") as archive:
                    for name, data in self.windows.items():
                        info = zipfile.ZipInfo(name)
                        info.create_system = 3
                        info.external_attr = (stat.S_IFLNK if bad == "symlink" and name == "steam_api64.dll" else stat.S_IFREG | 0o644) << 16
                        archive.writestr(info, data)
                    if bad == "duplicate":
                        with warnings.catch_warnings():
                            warnings.simplefilter("ignore", UserWarning)
                            archive.writestr("steam_api64.dll", b"other")
                with self.assertRaises(ValueError):
                    staging.read_package(archive_path, "SudokuDefense.exe")

    def test_combined_archive_preserves_all_linux_modes(self):
        content = {**self.linux, **self.windows}
        content["sudoku-defense"] = content.pop("sudoku-defense.x86_64")
        self.assertEqual(len(content), 12)
        with tempfile.TemporaryDirectory() as temporary:
            archive_path = Path(temporary) / "combined.zip"
            for bad in [False, True]:
                with zipfile.ZipFile(archive_path, "w") as archive:
                    for name, data in content.items():
                        info = zipfile.ZipInfo(name)
                        info.create_system = 3
                        mode = 0o755 if name in {"sudoku-defense", *contract.LIBRARIES["linux"]} else 0o644
                        if bad and name == "libsteam_api.so": mode = 0o644
                        info.external_attr = (stat.S_IFREG | mode) << 16
                        archive.writestr(info, data)
                if bad:
                    with self.assertRaisesRegex(ValueError, "permissions"):
                        staging.verify_combined(archive_path, content)
                else:
                    staging.verify_combined(archive_path, content)

    def test_build_commands_disable_steam_without_losing_user_flags(self):
        with tempfile.TemporaryDirectory() as temporary:
            for flags in [[], ["--", "--canvas-graphics"]]:
                original = ["godot", "--headless", "--script", "test.gd", *flags]
                with patch.object(build_exports.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "DONE")) as execute:
                    build_exports.run(original, Path(temporary) / "log", expected="DONE")
                command = execute.call_args.args[0]
                self.assertIn("--no-steam", command[command.index("--") + 1:])
                self.assertEqual(command.count("--"), 1)
                self.assertEqual(original, ["godot", "--headless", "--script", "test.gd", *flags])
                profile_key = "APPDATA" if os.name == "nt" else "XDG_DATA_HOME"
                self.assertIn("sudoku-test-profile-", execute.call_args.kwargs["env"][profile_key])

    def test_linux_zip_modes_survive_windows_packaging(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary) / "content"
            folder.mkdir()
            (folder / "game").write_bytes(b"executable")
            archive_path = Path(temporary) / "game.zip"
            build_exports.archive_directory(folder, archive_path, executable_names={"game"})
            with zipfile.ZipFile(archive_path) as archive:
                self.assertEqual((archive.getinfo("game").external_attr >> 16) & 0o777, 0o755)

    def test_metadata_requires_committed_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            for name, data in self.windows.items():
                if name != contract.metadata_name("windows"):
                    (folder / name).write_bytes(data)
            with patch.object(contract.subprocess, "check_output", return_value=" M scripts/main.gd\n"):
                with self.assertRaisesRegex(ValueError, "Commit"):
                    contract.write_metadata(PROJECT, folder, "windows", "0.3.19")
            self.assertFalse((folder / contract.metadata_name("windows")).exists())

    def test_metadata_records_exact_committed_payload(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            for name, data in self.windows.items():
                if name != contract.metadata_name("windows"):
                    (folder / name).write_bytes(data)
            with patch.object(contract.subprocess, "check_output", side_effect=["", COMMIT + "\n"]):
                contract.write_metadata(PROJECT, folder, "windows", "0.3.19")
            content = {path.name: path.read_bytes() for path in folder.iterdir()}
            metadata = contract.validate_payload(PROJECT, "windows", content, version="0.3.19", source_commit=COMMIT)
            self.assertEqual(metadata["godotsteam_version"], "4.23.2")


if __name__ == "__main__":
    unittest.main()
