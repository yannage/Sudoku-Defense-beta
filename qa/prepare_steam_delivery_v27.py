"""Assemble a validated local Windows/Linux Steam candidate without uploading.

Install beside package_local_v27.py and run_local_checks.py in the integration
checkout's qa/ directory. Linux is cross-built and is not executed here.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import stat
import sys
import zipfile

import package_local_v27 as p
import run_local_checks as r

sys.path.insert(0, str(p.ROOT / "steam"))
from prepare_godot_desktop import read_package, validate_executables, verify_combined
from desktop_package import LIBRARIES, validate_payload

DEFAULT_OUTPUT = Path(
    "C:/Users/Yanni/Documents/Codex/2026-11-08/task/"
    "sudoku-defense-0.3.27-dev-steam-prepared"
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expected-commit", help="Frozen full source SHA; must agree with any other pin")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="Fresh delivery directory")
    parser.add_argument("--packaging-tests-log", type=Path,
                        default=p.ROOT / "qa/karen-packaging-tests.log",
                        help="Retained output from the completed desktop-package unit tests")
    args = parser.parse_args()
    commit = p.expected_commit(args.expected_commit)
    output = args.output.resolve()
    packaging_tests_log = args.packaging_tests_log.resolve()
    p.verify_source(commit)
    aggregate = p.verify_aggregate()
    p.require(not output.exists() and not output.is_symlink(), "Preserve previous delivery outputs")
    p.require(packaging_tests_log.is_file(), "Missing packaging-test evidence: " + str(packaging_tests_log))

    packages = {}
    source_packages = {}
    for platform, executable in [("windows", "SudokuDefense.exe"), ("linux", "sudoku-defense.x86_64")]:
        path = p.BUILD_ROOT / "downloads" / f"Sudoku-Defense-Godot-{platform.capitalize()}.zip"
        content, digest = read_package(path, executable)
        validate_payload(p.PROJECT, platform, content, version=p.VERSION, source_commit=commit)
        packages[platform] = content
        source_packages[platform] = {"path": str(path), "sha256": digest, "bytes": path.stat().st_size}
    windows, linux = packages["windows"], packages["linux"]
    validate_executables(linux["sudoku-defense.x86_64"], windows["SudokuDefense.exe"])
    for name in set(linux) & set(windows):
        p.require(linux[name] == windows[name], "Shared desktop files differ: " + name)

    executable = p.BUILD_ROOT / "windows/SudokuDefense.exe"
    p.require(sha(executable.read_bytes()) == sha(windows[executable.name]), "Archive executable differs")
    exports = json.loads((p.EVIDENCE / "manifest.json").read_text(encoding="utf-8"))
    p.require(len(exports) == 3 and all(
        entry["passed"] and entry["source_commit"] == commit and entry["version"] == p.VERSION
        and entry["steam_disabled"] and entry["isolated_profile"]
        and entry["returncode"] == 0 and not entry["timed_out"] and not entry["other_errors"]
        for entry in exports), "Export or headless startup evidence failed")

    rendered = p.EVIDENCE / "rendered-startup"
    p.require(not rendered.exists() and not rendered.is_symlink(), "Preserve prior rendered startup evidence")
    rendered.mkdir()
    (rendered / "logs").mkdir()
    job = {
        "name": "windows-export-rendered-startup", "mode": "render",
        "command": r.no_steam([
            str(executable), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
            "--rendering-driver", "opengl3", "--quit-after", "120", "--", "--smoke-test",
        ]),
        "expected_marker": f"SUDOKU_DEFENSE_READY version={p.VERSION}",
    }
    result = r.execute(job, rendered, 90)
    result.update(source_commit=commit, game_version=p.VERSION,
                  executable_sha256=sha(executable.read_bytes()),
                  archive_sha256=source_packages["windows"]["sha256"],
                  steam_disabled=True, isolated_profile=True)
    (rendered / "manifest.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    p.require(result["status"] in {"pass", "qualified_pass"}, "Windows rendered startup failed")

    content = {**linux, **windows}
    content["sudoku-defense"] = content.pop("sudoku-defense.x86_64")
    p.require(len(content) == 12 and "steam_appid.txt" not in content, "Wrong complete-depot payload")
    p.verify_source(commit)
    p.require(r.source_snapshot() == aggregate["source_after"], "Tested source changed")

    output.mkdir(parents=True)
    archive_path = output / f"Sudoku-Defense-Godot-Steam-Desktop-{p.VERSION}.zip"
    executable_names = {"sudoku-defense", *LIBRARIES["linux"]}
    with zipfile.ZipFile(archive_path, "x", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(content.items()):
            info = zipfile.ZipInfo(name, (2026, 11, 8, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | (0o755 if name in executable_names else 0o644)) << 16
            archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    verify_combined(archive_path, content)
    with zipfile.ZipFile(archive_path) as archive:
        p.require(archive.testzip() is None, "Combined ZIP CRC failure")
    p.verify_source(commit)
    p.require(r.source_snapshot() == aggregate["source_after"], "Tested source changed during packaging")

    evidence = [p.AGGREGATE, p.EVIDENCE / "manifest.json", rendered / "manifest.json", packaging_tests_log]
    manifest = {
        "schema_version": 1, "prepared_at": datetime.now(timezone.utc).isoformat(),
        "status": "PREPARED_LOCAL_ONLY", "version": p.VERSION, "source_commit": commit,
        "provenance": "Local Windows cross-build; no CI receipt claimed",
        "app_id": 3721150, "depot_id": 3721151, "complete_shared_depot": True,
        "upload_mode": "Standard replacement",
        "archive": str(archive_path), "archive_bytes": archive_path.stat().st_size,
        "archive_sha256": sha(archive_path.read_bytes()), "source_packages": source_packages,
        "launch_paths": {"windows": "SudokuDefense.exe", "linux": "sudoku-defense"},
        "linux_rename_preserves_bytes": True, "upload_performed": False, "activation_performed": False,
        "steam_build_id": None, "steam_depot_manifest_id": None,
        "windows_rendered_startup": result,
        "runtime_qualifications": {
            "linux": "NOT_RUN; cross-built and statically validated only",
            "four_native_pointer_suites": "NOT_RUN; prior sandbox denial; no retry",
            "physical_windows_and_steam_deck": "NOT_RUN; synthetic checks do not establish device acceptance",
            "real_steam_and_two_device_cloud": "NOT_RUN",
        },
        "aggregate": {key: aggregate[key] for key in [
            "status", "tests_executed", "failed_jobs", "unrun_jobs", "restricted_unverified",
            "known_environment_error_count", "source_changed_during_run",
        ]},
        "evidence": {str(path): sha(path.read_bytes()) for path in evidence},
        "files": [{
            "path": name, "bytes": len(data), "sha1": hashlib.sha1(data).hexdigest(),
            "sha256": sha(data), "mode": "0755" if name in executable_names else "0644",
        } for name, data in sorted(content.items())],
        "vdf_warning": "Existing checked-in VDF targets Linux-only content; do not invoke unchanged.",
    }
    (output / "steam-delivery-preflight.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    for source in source_packages.values():
        shutil.copyfile(source["path"], output / Path(source["path"]).name)
    shutil.copyfile(__file__, output / Path(__file__).name)
    shutil.copyfile(p.ROOT / "qa/package_local_v27.py", output / "package_local_v27.py")
    (output / "SHA256SUMS.txt").write_text("".join(
        f"{sha(path.read_bytes())}  {path.name}\n" for path in sorted(output.iterdir()) if path.is_file()
    ), encoding="utf-8")
    print(json.dumps({
        "archive": str(archive_path), "sha256": manifest["archive_sha256"],
        "bytes": manifest["archive_bytes"], "source_commit": commit,
        "tests": aggregate["tests_executed"], "windows_rendered": result["status"],
        "linux_runtime": "NOT_RUN", "upload_performed": False, "activation_performed": False,
    }, indent=2))


if __name__ == "__main__":
    main()
