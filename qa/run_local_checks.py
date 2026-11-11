#!/usr/bin/env python3
"""Run the canonical build test list locally, with no export or Steam access.

This QA adapter collects jobs by replacing build_exports.run and
export_releases, rather than maintaining a second copy of the suite list.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import traceback
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot"
KNOWN_ENVIRONMENT_ERROR = "ERROR: Failed to read the root certificate store."
RESTRICTED_JOBS = {
    "controller-cursor-render-tests", "canvas-controller-cursor-render-tests",
    "loot-gear-render-tests", "canvas-loot-gear-render-tests",
}
RESTRICTION_REASON = "Native cursor access was denied by the sandbox desktop in prior diagnosis; do not retry. Requires ordinary Windows/Deck acceptance outside this task."


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_build_module():
    scripts = PROJECT / "scripts"
    sys.path.insert(0, str(scripts))
    spec = importlib.util.spec_from_file_location("sudoku_local_build_checks", scripts / "build_exports.py")
    if spec is None or spec.loader is None:
        raise RuntimeError("Cannot import canonical build helper")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def no_steam(command: list[str]) -> list[str]:
    result = command.copy()
    if "--" not in result:
        result.append("--")
    if "--no-steam" not in result:
        result.append("--no-steam")
    return result


def collect_jobs(module, godot: str, *, include_render: bool = True) -> list[dict]:
    """Execute main's job declarations only; no engine/export subprocess runs."""
    jobs: list[dict] = []

    def collect(command, log, expected=None):
        command = list(command)
        if os.name == "nt" and "--rendering-driver" in command:
            position = command.index("--rendering-driver") + 1
            if command[position] == "opengl3_es":
                command[position] = "opengl3"
        mode = "import" if "--editor" in command else "headless" if "--headless" in command else "render"
        jobs.append({"name": Path(log).stem, "mode": mode, "command": no_steam(command), "expected_marker": expected})

    def collect_version(command, **_kwargs):
        if list(command) != [godot, "--headless", "--version"]:
            raise RuntimeError(f"Unexpected subprocess during collection: {command!r}")
        # Collection is not verification. A separate isolated engine-version
        # job below validates the real executable before any test is launched.
        return module.EXPECTED_VERSION + ".collector-only"

    argv = [str(PROJECT / "scripts/build_exports.py"), "--godot", godot, "--targets", "windows", "--skip-smoke"]
    # The canonical builder checks display availability while declaring its
    # render jobs. Headless-only QA must not require that unused dependency.
    if include_render:
        argv.append("--render-check")
    display = {"DISPLAY": "windows-native-display"} if os.name == "nt" else {}
    with patch.object(sys, "argv", argv), patch.dict(os.environ, display), \
            patch.object(module, "run", collect), \
            patch.object(module, "export_releases", lambda *_args: None), \
            patch.object(module, "bootstrap_extension_cache", lambda: None), \
            patch.object(module.subprocess, "check_output", collect_version):
        module.main()
    names = [job["name"] for job in jobs]
    if len(names) != len(set(names)):
        raise RuntimeError("Canonical job names are not unique; refusing to overwrite logs")
    if any("--export-release" in job["command"] for job in jobs):
        raise RuntimeError("Collector unexpectedly included an export")
    return jobs


def source_snapshot() -> dict[str, str]:
    """Detect source changes during a pass without hashing generated caches."""
    extensions = {".gd", ".godot", ".tscn", ".tres", ".json", ".cfg", ".py", ".gdextension"}
    result = {}
    for path in sorted(PROJECT.rglob("*")):
        relative = path.relative_to(PROJECT)
        if not path.is_file() or any(part in {".godot", "build", "__pycache__"} for part in relative.parts):
            continue
        if path.suffix in extensions:
            result[relative.as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def hidden_startup() -> dict:
    if os.name != "nt":
        return {}
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = subprocess.SW_HIDE
    return {"startupinfo": startup}


def execute(job: dict, output: Path, timeout: int) -> dict:
    started = time.monotonic()
    result = {**job, "started_at": utc_now()}
    log = output / "logs" / (job["name"] + ".log")
    result["log"] = str(log)
    environment = os.environ.copy()
    raw = ""
    code = None
    problem = None
    try:
        with tempfile.TemporaryDirectory(prefix="sudoku-local-check-") as temporary:
            keys = ("APPDATA", "LOCALAPPDATA") if os.name == "nt" else ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME")
            for key in keys:
                folder = Path(temporary) / key.lower()
                folder.mkdir()
                environment[key] = str(folder)
            process = subprocess.run(job["command"], cwd=PROJECT, env=environment,
                                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                     encoding="utf-8", errors="replace", text=True,
                                     timeout=timeout, **hidden_startup())
            raw, code = process.stdout, process.returncode
    except subprocess.TimeoutExpired as error:
        raw = error.stdout or ""
        if isinstance(raw, bytes):
            raw = raw.decode("utf-8", errors="replace")
        problem = f"Timed out after {timeout} seconds"
    except Exception:
        problem = traceback.format_exc()
    # Preserve subprocess output verbatim. Adapter failures live in the manifest.
    log.write_text(raw, encoding="utf-8", newline="")
    lines = raw.splitlines()
    known = [line for line in lines if line.strip() == KNOWN_ENVIRONMENT_ERROR]
    errors = [line for line in lines
              if ("ERROR:" in line or "Parse Error:" in line or line.startswith(("FATAL:", "CRITICAL:")))
              and line.strip() != KNOWN_ENVIRONMENT_ERROR]
    marker = job["expected_marker"]
    marker_found = marker is None or marker in raw
    passed = code == 0 and not errors and marker_found and problem is None
    result.update({
        "finished_at": utc_now(), "seconds": round(time.monotonic() - started, 3),
        "returncode": code, "expected_marker_found": marker_found,
        "known_environment_error_count": len(known), "other_errors": errors,
        "adapter_error": problem,
        "status": "qualified_pass" if passed and known else "pass" if passed else "fail",
        "completion_lines": [line for line in lines if marker and marker in line],
    })
    return result


def save_manifest(output: Path, manifest: dict) -> None:
    temporary = output / "manifest.pending.json"
    temporary.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    temporary.replace(output / "manifest.json")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--mode", choices=["headless", "render", "all"], default="all")
    parser.add_argument("--output", type=Path, help="Fresh evidence directory; must not already exist")
    parser.add_argument("--jobs", type=int, choices=[1, 2], default=2, help="Headless concurrency only; renders are always sequential")
    parser.add_argument("--timeout", type=int, default=240, help="Per-process timeout in seconds")
    parser.add_argument("--skip-import", action="store_true", help="Use an already imported checkout")
    parser.add_argument("--list", action="store_true", help="Print the collected job plan without starting any subprocess")
    parser.add_argument("--only", nargs="+", help="Run these exact canonical job names only")
    parser.add_argument("--render-barrier", type=Path, help="Wait for an earlier local pass to finish before starting framebuffer jobs")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    module = load_build_module()
    collected = collect_jobs(module, args.godot, include_render=args.mode != "headless")
    jobs = [job for job in collected
            if (job["mode"] == "import" and not args.skip_import)
            or (job["mode"] != "import" and args.mode in {"all", job["mode"]})]
    if args.only:
        unknown = set(args.only) - {job["name"] for job in jobs}
        if unknown:
            parser.error("Unknown jobs in selected mode: " + ", ".join(sorted(unknown)))
        jobs = [job for job in jobs if job["name"] in args.only or job["mode"] == "import"]
    restricted = [job["name"] for job in jobs if job["name"] in RESTRICTED_JOBS]
    jobs = [job for job in jobs if job["name"] not in RESTRICTED_JOBS]
    if args.list:
        print(json.dumps({"runnable":jobs,"restricted_unverified":restricted}, indent=2))
        return 0
    output = (args.output or ROOT / "qa" / (datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + args.mode)).resolve()
    output.mkdir(parents=True, exist_ok=False)
    (output / "logs").mkdir()
    initial_source = source_snapshot()
    manifest = {
        "started_at": utc_now(), "status": "running", "mode": args.mode,
        "repository": str(ROOT), "godot": args.godot,
        "canonical_test_list": "godot/scripts/build_exports.py:main",
        "windows_render_driver_override": "opengl3_es -> opengl3" if os.name == "nt" else None,
        "known_environment_error_exception": KNOWN_ENVIRONMENT_ERROR,
        "headless_workers": args.jobs, "render_workers": 1,
        "steam_disabled": True, "profiles": "Fresh temporary profile per process; removed after process exit",
        "source_before": initial_source, "planned_jobs": jobs, "results": [],
        "restricted_unverified": restricted,
        "restriction_reason": RESTRICTION_REASON if restricted else None,
        "selected_jobs": args.only,
    }
    save_manifest(output, manifest)
    print(f"Evidence: {output}", flush=True)

    def record(result: dict) -> None:
        manifest["results"].append(result)
        save_manifest(output, manifest)
        print(f"{result['status'].upper()}: {result['name']} ({result['seconds']:.1f}s; known environment errors={result['known_environment_error_count']})", flush=True)
        if result["status"] == "fail":
            print(f"  Inspect {result['log']}", flush=True)
            if result["adapter_error"]:
                print(result["adapter_error"], flush=True)

    version = {"name": "engine-version", "mode": "setup", "command": no_steam([args.godot, "--headless", "--version"]), "expected_marker": module.EXPECTED_VERSION + "."}
    record(execute(version, output, args.timeout))
    setup_failed = manifest["results"][-1]["status"] == "fail"
    if not setup_failed:
        module.bootstrap_extension_cache()
        for job in [job for job in jobs if job["mode"] == "import"]:
            record(execute(job, output, args.timeout))
            setup_failed = manifest["results"][-1]["status"] == "fail"
            if setup_failed:
                break
    if not setup_failed:
        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            futures = [pool.submit(execute, job, output, args.timeout) for job in jobs if job["mode"] == "headless"]
            for future in as_completed(futures):
                record(future.result())
        if args.render_barrier and any(job["mode"] == "render" for job in jobs):
            deadline = time.monotonic() + args.timeout
            while json.loads(args.render_barrier.read_text(encoding="utf-8"))["status"] == "running":
                if time.monotonic() >= deadline:
                    raise RuntimeError("Prior render pass did not finish; refusing overlapping framebuffer tests")
                print("Waiting for prior local framebuffer pass to finish", flush=True)
                time.sleep(5)
        for job in [job for job in jobs if job["mode"] == "render"]:
            record(execute(job, output, args.timeout))
    final_source = source_snapshot()
    changed = sorted(path for path in set(initial_source) | set(final_source) if initial_source.get(path) != final_source.get(path))
    failures = [result["name"] for result in manifest["results"] if result["status"] == "fail"]
    warnings = sum(result["known_environment_error_count"] for result in manifest["results"])
    executed = {result["name"] for result in manifest["results"]}
    skipped = [job["name"] for job in jobs if job["name"] not in executed]
    status = "fail" if failures or changed or skipped else "incomplete" if restricted else "qualified_pass" if warnings else "pass"
    manifest.update({"finished_at": utc_now(), "status": status, "failed_jobs": failures,
                     "unrun_jobs": skipped, "known_environment_error_count": warnings,
                     "source_changed_during_run": changed, "source_after": final_source,
                     "tests_executed": sum(result["mode"] in {"headless", "render"} for result in manifest["results"])})
    save_manifest(output, manifest)
    print(f"{status.upper()}: {manifest['tests_executed']} tests; {len(failures)} failed; {len(skipped)} unrun; {warnings} known environment errors", flush=True)
    print(f"Manifest: {output / 'manifest.json'}", flush=True)
    return 1 if status == "fail" else 2 if status == "incomplete" else 0


if __name__ == "__main__":
    raise SystemExit(main())
