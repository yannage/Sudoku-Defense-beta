"""Create locally validated 0.3.27-dev candidate packages; never upload/activate.

Install this helper beside run_local_checks.py in the integration checkout's qa/
directory. Physical input, native Linux, and real Steam acceptance stay separate.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from types import SimpleNamespace

from run_local_checks import KNOWN_ENVIRONMENT_ERROR, hidden_startup, load_build_module, no_steam, source_snapshot

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot"
VERSION = "0.3.27-dev"
PIN_FILE = ROOT / "qa/final-source-commit.txt"
PIN_ENV = "SUDOKU_EXPECTED_SOURCE_COMMIT"
AGGREGATE = ROOT / "qa/karen-final/manifest.json"
BUILD_ROOT = PROJECT / f"build/unapproved-{VERSION}-native"
EVIDENCE = ROOT / f"qa/package-unapproved-{VERSION}-native"
EXPECTED_RESTRICTIONS = {
    "controller-cursor-render-tests", "canvas-controller-cursor-render-tests",
    "loot-gear-render-tests", "canvas-loot-gear-render-tests",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def expected_commit(cli_value: str | None = None) -> str:
    """Read an explicit frozen identity; never derive the expectation from HEAD."""
    pins = {}
    if cli_value is not None:
        pins["--expected-commit"] = cli_value.strip()
    if PIN_ENV in os.environ:
        pins[PIN_ENV] = os.environ[PIN_ENV].strip()
    if PIN_FILE.exists():
        pins[str(PIN_FILE)] = PIN_FILE.read_text(encoding="utf-8-sig").strip()
    require(bool(pins), f"Provide --expected-commit, {PIN_ENV}, or {PIN_FILE}")
    for name, value in pins.items():
        require(re.fullmatch(r"[0-9a-f]{40}", value) is not None,
                f"{name} must contain one complete lowercase 40-character source commit")
    require(len(set(pins.values())) == 1, "Conflicting source commit pins; resolve them before packaging")
    return next(iter(pins.values()))


def verify_source(commit: str) -> None:
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    require(head == commit, f"Source HEAD is {head}; expected frozen commit {commit}")
    changes = subprocess.check_output(
        ["git", "status", "--porcelain", "--untracked-files=all", "--", "godot"],
        cwd=ROOT, text=True).strip()
    require(not changes, "Godot source differs from the committed candidate: " + changes)
    version = re.search(r'^config/version="([^"]+)"$',
                        (PROJECT / "project.godot").read_text(encoding="utf-8"), re.M)
    require(version is not None and version.group(1) == VERSION, "Source project version differs from " + VERSION)


def verify_aggregate() -> dict:
    manifest = json.loads(AGGREGATE.read_text(encoding="utf-8"))
    require(manifest["status"] == "incomplete", "Wait for the completed permitted aggregate")
    require(not manifest["source_changed_during_run"] and not manifest["unrun_jobs"]
            and not manifest["failed_jobs"], "Aggregate has changed source, failures, or unrun jobs")
    require(manifest["tests_executed"] == 119, "Expected 119 executed final aggregate tests")
    require(set(manifest["restricted_unverified"]) == EXPECTED_RESTRICTIONS,
            "Aggregate exclusions differ from the four restricted native cursor/drag suites")
    results = manifest["results"]
    names = [result["name"] for result in results]
    require(len(names) == len(set(names)), "Duplicate aggregate result names")
    counts = Counter(result["mode"] for result in results if result["mode"] in {"headless", "render"})
    require(sum(counts.values()) == 119, "Expected 119 permitted renderer/headless suites")
    require(all(result["status"] in {"pass", "qualified_pass"} for result in results),
            "Aggregate contains a non-passing process")
    require(source_snapshot() == manifest["source_after"], "Source changed since the final aggregate")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("godot", type=Path, help="Existing approved Godot console executable")
    parser.add_argument("--expected-commit", help="Full frozen source commit; must agree with any other pin")
    args = parser.parse_args()
    commit = expected_commit(args.expected_commit)
    verify_source(commit)
    aggregate = verify_aggregate()
    godot = args.godot.resolve()
    require(godot.is_file(), "Godot executable is missing")
    require(godot == Path(aggregate["godot"]).resolve(), "Use the engine recorded in the final aggregate")
    templates_root = godot.parent / "templates"
    for name in ("windows_release_x86_64.exe", "linux_release.x86_64", "version.txt"):
        require((templates_root / name).is_file(), "Missing existing local export template: " + name)
    build_root = BUILD_ROOT.resolve()
    require(build_root.parent == (PROJECT / "build").resolve(), "Build path escaped the project build directory")
    require(not BUILD_ROOT.is_symlink() and not build_root.exists(), "Preserve any existing candidate packages")
    require(not EVIDENCE.exists() and not EVIDENCE.is_symlink(), "Preserve existing packaging evidence")
    for name in ("windows", "linux"):
        target = (build_root / name).resolve()
        require(target.parent == build_root and build_root.parent.parent == PROJECT.resolve(),
                "Export target escaped the candidate directory")
        require(not target.exists() and not target.is_symlink(), "Export target must be fresh")
    EVIDENCE.mkdir()
    (EVIDENCE / "UNAPPROVED-LOCAL-TEST-PACKAGE.txt").write_text(
        f"UNAPPROVED LOCAL {VERSION} TEST PACKAGES ONLY\n"
        f"Frozen source commit: {commit}\n"
        "Four native cursor/drag acceptance suites remain unverified (prior sandbox access denied).\n"
        "Any certificate-store startup diagnostic is retained, never disabled or repaired.\n"
        "This helper performs no Steam upload, activation, real-account unlock or real-save test.\n"
        "Linux is cross-built and statically validated; native Linux startup remains untested.\n",
        encoding="utf-8")
    results = []

    def run(command, log, expected=None):
        command = no_steam(list(command))
        env = os.environ.copy()
        with tempfile.TemporaryDirectory(prefix="sudoku-local-package-v27-") as temporary:
            for key in ("APPDATA", "LOCALAPPDATA"):
                folder = Path(temporary) / key.lower()
                folder.mkdir()
                env[key] = str(folder)
            if "--export-release" in command:
                templates = Path(env["APPDATA"]) / "Godot/export_templates/4.7.2.stable"
                templates.mkdir(parents=True)
                for name in ("windows_release_x86_64.exe", "linux_release.x86_64", "version.txt"):
                    shutil.copyfile(templates_root / name, templates / name)
            try:
                process = subprocess.run(command, cwd=PROJECT, env=env, stdout=subprocess.PIPE,
                                         stderr=subprocess.STDOUT, text=True, encoding="utf-8",
                                         errors="replace", timeout=240, **hidden_startup())
                raw, code, timed_out = process.stdout, process.returncode, False
            except subprocess.TimeoutExpired as error:
                raw = error.stdout or ""
                if isinstance(raw, bytes):
                    raw = raw.decode("utf-8", "replace")
                code, timed_out = None, True
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text(raw, encoding="utf-8")
        errors = [line for line in raw.splitlines()
                  if ("ERROR:" in line or "Parse Error:" in line or "FATAL:" in line)
                  and line.strip() != KNOWN_ENVIRONMENT_ERROR]
        qualified = raw.count(KNOWN_ENVIRONMENT_ERROR)
        passed = code == 0 and not errors and (not expected or expected in raw)
        results.append({"command": command, "log": str(log), "returncode": code,
                        "timed_out": timed_out, "other_errors": errors,
                        "known_environment_error_count": qualified, "expected_marker": expected,
                        "passed": passed, "steam_disabled": True, "isolated_profile": True,
                        "source_commit": commit, "version": VERSION})
        (EVIDENCE / "manifest.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
        if not passed:
            print(raw)
            raise RuntimeError(f"Local packaging failed: {log}")
        print(f"QUALIFIED_PASS: {log.name}" if qualified else f"PASS: {log.name}", flush=True)

    build = load_build_module()
    build.run = run
    build_root.mkdir()
    (build_root / ".gdignore").touch()
    downloads = build_root / "downloads"
    logs = EVIDENCE / "logs"
    downloads.mkdir()
    logs.mkdir()
    build.export_releases(SimpleNamespace(godot=str(godot), targets=["windows", "linux"], skip_smoke=True),
                          build_root, downloads, logs)
    run([str(build_root / "windows/SudokuDefense.exe"), "--headless", "--audio-driver", "Dummy",
         "--quit-after", "120", "--", "--smoke-test"],
        logs / "windows-export-boot.log", f"SUDOKU_DEFENSE_READY version={VERSION}")
    verify_source(commit)
    require(source_snapshot() == aggregate["source_after"], "Export changed tested source")
    print("UNAPPROVED local Windows/Linux packages created; Linux runtime, pointer and Steam acceptance remain unverified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
