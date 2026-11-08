#!/usr/bin/env python3
"""Capture six permitted Karen usability views; never export or contact Steam.

Install beside run_local_checks.py, or pass --repository to run the prepared
copy. This supplements the canonical aggregate checks. The four restricted
native cursor/drag render jobs are neither collected nor retried here.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import struct
import sys
import traceback

sys.dont_write_bytecode = True

# These tests were reviewed together with controller_input's binding dispatch,
# main's camera/controller activity handlers, and controller_cursor's activation.
# Karen controller uses only D-pad/face/shoulder/Start/L3 buttons. It does not
# activate the cursor; L3 only toggles camera mode and deactivates an idle cursor.
SAFETY_NOTE = (
    "Reviewed control-signal/focus tests and joypad-button-only controller flow; "
    "no mouse events, native cursor activation/warp, stick axes, triggers, or drags. "
    "No input implementation is patched or disabled by this runner."
)
FORBIDDEN_TEST_TOKENS = (
    "warp_mouse", "mouse_set", "Input.mouse_mode", "InputEventMouse",
    "InputEventScreenTouch", "InputEventScreenDrag", "InputEventJoypadMotion",
    "JOY_BUTTON_RIGHT_STICK", "JOY_AXIS_", "controller_cursor.",
    "force_drag", "gui_start_drag", "_claim_pointer", "_controller_pointer_activity",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def load_adapter(root: Path):
    path = root / "qa/run_local_checks.py"
    spec = importlib.util.spec_from_file_location("karen_safe_local_checks", path)
    require(spec is not None and spec.loader is not None, "Cannot load safe QA adapter")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def definitions() -> list[dict]:
    jobs = []
    for layout, size in [("deck", [1280, 800]), ("portrait", [600, 1066])]:
        jobs.append({
            "name": f"karen-dock-{layout}", "script": "test_karen_dock.gd",
            "flags": ["--capture-karen"] + (["--portrait"] if layout == "portrait" else []),
            "expected_marker": "FAILURES=0",
            "captures": [{"path": f"build/karen-checks/{layout}-{stage}.png", "size": size}
                         for stage in ["tower", "gear-batch", "gear-filters", "camp-slots"]],
        })
    for renderer in ["native", "canvas"]:
        jobs.append({
            "name": f"karen-controller-{renderer}", "script": "test_karen_controller.gd",
            "flags": ["--capture-karen"] + (["--canvas-graphics"] if renderer == "canvas" else []),
            "expected_marker": f"0 failures ({renderer})",
            "captures": [{"path": f"build/karen-checks/main-{renderer}-{stage}.png", "size": [1280, 800]}
                         for stage in ["start-menu", "battle", "reserves"]] + [{"path": f"build/karen-checks/main-{renderer}-reserves-portrait.png", "size": [390, 844]}],
        })
    for renderer in ["native", "canvas"]:
        jobs.append({
            "name": f"loot-batch-{renderer}", "script": "test_loot_batch.gd",
            "flags": ["--canvas-graphics"] if renderer == "canvas" else [],
            "expected_marker": "LOOT_BATCH_PASS:",
            "captures": [{"path": f"build/loot-batch-checks/{stage}.png", "size": size}
                         for stage, size in [("open-all-short", [1100, 400]),
                                             ("batch-rewards-short", [1100, 400]),
                                             ("batch-rewards-portrait", [680, 1050])]],
        })
    return jobs


def capture_state(path: Path) -> dict | None:
    if not path.is_file():
        return None
    payload = path.read_bytes()
    return {"mtime_ns": path.stat().st_mtime_ns, "bytes": len(payload),
            "sha256": hashlib.sha256(payload).hexdigest()}


def preserve_captures(job: dict, project: Path, output: Path, before: dict) -> list[dict]:
    records = []
    target = output / "captures" / job["name"]
    target.mkdir(parents=True, exist_ok=False)
    for expected in job["captures"]:
        path = project / expected["path"]
        record = {"source": str(path), "expected_dimensions": expected["size"]}
        try:
            state = capture_state(path)
            require(state is not None, f"Missing capture: {path}")
            require(state != before[expected["path"]], f"Capture was not refreshed by this job: {path}")
            payload = path.read_bytes()
            require(len(payload) > 32 and payload[:8] == b"\x89PNG\r\n\x1a\n" and payload[12:16] == b"IHDR",
                    f"Not a valid PNG header: {path}")
            dimensions = list(struct.unpack(">II", payload[16:24]))
            require(dimensions == expected["size"], f"Wrong capture dimensions {dimensions}: {path}")
            destination = target / path.name
            shutil.copy2(path, destination)
            require(hashlib.sha256(destination.read_bytes()).hexdigest() == state["sha256"],
                    f"Capture copy hash mismatch: {destination}")
            record.update(state)
            record.update({"copy": str(destination), "dimensions": dimensions, "status": "pass"})
        except Exception as error:
            record.update({"status": "fail", "error": str(error)})
        records.append(record)
    return records


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--output", type=Path, help="Fresh directory; defaults to qa/karen-visual")
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument("--list", action="store_true", help="Show plan without starting Godot or writing evidence")
    args = parser.parse_args()
    require(args.timeout > 0, "Timeout must be positive")
    root = args.repository.resolve()
    project = root / "godot"
    adapter = load_adapter(root)
    require(adapter.PROJECT == project, "Safe QA adapter project does not match requested repository")
    jobs = definitions()
    reviewed_scripts = {}
    for job in jobs:
        source = project / "tests" / job["script"]
        body = source.read_text(encoding="utf-8-sig")
        prohibited = [token for token in FORBIDDEN_TEST_TOKENS if token in body]
        require(not prohibited, f"Render test needs a fresh input safety review: {source}: {prohibited}")
        reviewed_scripts[job["script"]] = hashlib.sha256(source.read_bytes()).hexdigest()
        require(job["name"] not in adapter.RESTRICTED_JOBS, "Restricted job cannot be rendered")
        job.update({"mode": "render", "command": adapter.no_steam([
            args.godot, "--path", str(project), "--audio-driver", "Dummy", "--max-fps", "30",
            "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3",
            "--script", "res://tests/" + job["script"], "--", *job["flags"],
        ])})
    if args.list:
        print(json.dumps({"jobs": jobs, "safety_review": SAFETY_NOTE,
                          "restricted_unverified": sorted(adapter.RESTRICTED_JOBS)}, indent=2))
        return 0
    require((project / ".godot").is_dir(), "Run the canonical import/checks before supplemental captures")
    output = (args.output or root / "qa/karen-visual").resolve()
    output.mkdir(parents=True, exist_ok=False)
    (output / "logs").mkdir()
    initial_source = adapter.source_snapshot()
    manifest = {
        "started_at": adapter.utc_now(), "status": "running", "mode": "supplemental-render",
        "repository": str(root), "godot": args.godot, "render_workers": 1,
        "steam_disabled": True, "audio_driver": "Dummy", "rendering_driver": "opengl3", "max_fps": 30,
        "profiles": "Fresh temporary profile per process; removed after process exit",
        "safety_review": SAFETY_NOTE, "reviewed_test_sha256": reviewed_scripts,
        "restricted_unverified": sorted(adapter.RESTRICTED_JOBS),
        "restriction_reason": adapter.RESTRICTION_REASON,
        "acceptance_limit": "Framebuffer capture and automated assertions only; visual inspection, physical Deck, and real Steam/Cloud acceptance remain separate.",
        "source_before": initial_source, "planned_jobs": jobs, "results": [],
    }
    adapter.save_manifest(output, manifest)
    print(f"Evidence: {output}", flush=True)
    try:
        expected_version = adapter.load_build_module().EXPECTED_VERSION
        version_job = {"name": "engine-version", "mode": "setup",
                       "command": adapter.no_steam([args.godot, "--headless", "--version"]),
                       "expected_marker": expected_version + "."}
        version = adapter.execute(version_job, output, args.timeout)
        manifest["results"].append(version)
        adapter.save_manifest(output, manifest)
        if version["status"] != "fail":
            for job in jobs:
                before = {item["path"]: capture_state(project / item["path"]) for item in job["captures"]}
                result = adapter.execute(job, output, args.timeout)
                result["captures"] = preserve_captures(job, project, output, before)
                if any(item["status"] == "fail" for item in result["captures"]):
                    result["status"] = "fail"
                manifest["results"].append(result)
                adapter.save_manifest(output, manifest)
                print(f"{result['status'].upper()}: {job['name']} ({result['seconds']:.1f}s)", flush=True)
                if result["status"] == "fail":
                    print(f"  Inspect {result['log']} and manifest capture records", flush=True)
    except Exception:
        manifest["adapter_error"] = traceback.format_exc()
    final_source = adapter.source_snapshot()
    changed = sorted(path for path in set(initial_source) | set(final_source)
                     if initial_source.get(path) != final_source.get(path))
    failures = [result["name"] for result in manifest["results"] if result["status"] == "fail"]
    executed = {result["name"] for result in manifest["results"]}
    skipped = [job["name"] for job in jobs if job["name"] not in executed]
    warnings = sum(result["known_environment_error_count"] for result in manifest["results"])
    failed = bool(failures or skipped or changed or manifest.get("adapter_error"))
    manifest.update({
        "finished_at": adapter.utc_now(), "status": "fail" if failed else "qualified_pass" if warnings else "pass",
        "failed_jobs": failures, "unrun_jobs": skipped,
        "known_environment_error_count": warnings, "source_changed_during_run": changed,
        "source_after": final_source, "tests_executed": sum(result["mode"] == "render" for result in manifest["results"]),
    })
    adapter.save_manifest(output, manifest)
    print(f"{manifest['status'].upper()}: {manifest['tests_executed']} render jobs; {len(failures)} failed; {len(skipped)} unrun", flush=True)
    print(f"Manifest: {output / 'manifest.json'}", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
