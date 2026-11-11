"""QA job selection must preserve headless operation and real render checks."""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("local_checks", ROOT / "qa/run_local_checks.py")
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)


class LocalCheckSelectionTests(unittest.TestCase):
    def plan(self, mode: str, *, display: str = "") -> dict:
        # No engine, display server, or native input is launched by --list.
        with tempfile.TemporaryDirectory() as temporary, \
                patch.dict(os.environ, {"DISPLAY": display}), \
                patch("shutil.which", return_value=None), \
                patch.object(sys, "argv", ["run_local_checks.py", "--mode", mode, "--list"]):
            module = checks.load_build_module()
            with patch.object(module, "PROJECT", Path(temporary)), \
                    patch.object(checks, "load_build_module", return_value=module), \
                    contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(checks.main(), 0)
            return json.loads(output.getvalue())

    def test_headless_plan_needs_neither_display_nor_xvfb(self):
        plan = self.plan("headless")
        names = {job["name"] for job in plan["runnable"]}
        self.assertIn("simulation-tests", names)
        self.assertIn("test_progression_resume", names)
        self.assertIn("native-test_karen_controller", names)
        self.assertTrue(all(job["mode"] in {"import", "headless"} for job in plan["runnable"]))
        self.assertTrue(all("--no-steam" in job["command"] for job in plan["runnable"]))

    def test_render_and_all_keep_same_render_suite_and_exclusions(self):
        render = self.plan("render", display=":qa-list-only")
        all_modes = self.plan("all", display=":qa-list-only")
        render_names = {job["name"] for job in render["runnable"] if job["mode"] == "render"}
        all_render_names = {job["name"] for job in all_modes["runnable"] if job["mode"] == "render"}
        self.assertEqual(render_names, all_render_names)
        self.assertIn("native-prerelease-render-tests", render_names)
        self.assertIn("canvas-prerelease-render-tests", render_names)
        self.assertEqual(set(render["restricted_unverified"]), checks.RESTRICTED_JOBS)
        self.assertEqual(set(all_modes["restricted_unverified"]), checks.RESTRICTED_JOBS)
        self.assertFalse(any(job["mode"] == "headless" for job in render["runnable"]))
        self.assertTrue(any(job["mode"] == "headless" for job in all_modes["runnable"]))

    @unittest.skipIf(os.name == "nt", "Windows uses its native display")
    def test_render_still_requires_display_or_xvfb(self):
        for mode in ["render", "all"]:
            with self.subTest(mode=mode), self.assertRaisesRegex(SystemExit, "requires a display or xvfb-run"):
                self.plan(mode)


if __name__ == "__main__":
    unittest.main()
