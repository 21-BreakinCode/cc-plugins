"""Tests for apple-kit/scripts/health_sync.py. Run: python3 -B -m unittest discover -s apple-kit/tests -v"""

import contextlib
import importlib.util
import io
import json
import tempfile
import unittest
from datetime import date
from pathlib import Path

TESTS_DIR = Path(__file__).resolve().parent
FIXTURES = TESTS_DIR / "fixtures"
SCRIPT = TESTS_DIR.parent / "scripts" / "health_sync.py"

spec = importlib.util.spec_from_file_location("health_sync", SCRIPT)
assert spec is not None and spec.loader is not None, SCRIPT
health_sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(health_sync)

LOG_HEADER = "| date | time | weight_kg | body_fat_pct | source |\n|---|---|---|---|---|\n"


def read_fixture(name):
    return (FIXTURES / name).read_text(encoding="utf-8")


class TempVault:
    """A temp vault folder holding .apple-kit.json, an export file, and the body log."""

    def __init__(self, export_text, log_text=None):
        self._dir = tempfile.TemporaryDirectory()
        self.root = Path(self._dir.name)
        self.export = self.root / "health-latest.txt"
        self.log = self.root / "Body" / "body-log.md"
        if export_text is not None:
            self.export.write_text(export_text, encoding="utf-8")
        if log_text is not None:
            self.log.parent.mkdir(parents=True)
            self.log.write_text(log_text, encoding="utf-8")
        self.config = self.root / ".apple-kit.json"
        self.config.write_text(json.dumps({"health": {
            "export_path": str(self.export), "body_log": "Body/body-log.md"}}))

    def run(self, today="2026-11-02"):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = health_sync.main(["--config", str(self.config), "--today", today])
        return code, out.getvalue()

    def rows(self):
        return health_sync.parse_log(self.log.read_text(encoding="utf-8"))[1]

    def row(self, day):
        return next(r for r in self.rows() if r["date"] == day)

    def cleanup(self):
        self._dir.cleanup()


class ParseExportTest(unittest.TestCase):
    def test_six_line_export_gives_three_readings(self):
        readings, skipped = health_sync.parse_export(read_fixture("export-6.txt"))
        self.assertEqual(skipped, 0)
        self.assertEqual(readings[("2026-10-30", "08:06")], {
            "date": "2026-10-30", "time": "08:06", "weight_kg": 66.6,
            "body_fat_pct": 18.9, "source": "Xiaomi Home"})
        self.assertEqual(readings[("2026-11-01", "13:10")]["weight_kg"], 65.0)
        self.assertEqual(readings[("2026-11-01", "13:10")]["body_fat_pct"], 18.2)
        self.assertEqual(len(readings), 3)

    def test_fifteen_line_export_still_three_readings(self):
        readings, _ = health_sync.parse_export(read_fixture("export-15.txt"))
        self.assertEqual(len(readings), 3)

    def test_lb_weight_is_skipped(self):
        readings, skipped = health_sync.parse_export(
            "weight,2026-10-30T08:06:50+08:00,146.8,lb,Xiaomi Home")
        self.assertEqual(readings, {})
        self.assertEqual(skipped, 1)

    def test_malformed_line_is_skipped_and_counted(self):
        readings, skipped = health_sync.parse_export(
            "garbage\n\nweight,2026-10-30T08:06:50+08:00,66,kg,X")
        self.assertEqual(len(readings), 1)
        self.assertEqual(skipped, 1)

    def test_local_date_uses_timestamp_offset(self):
        readings, _ = health_sync.parse_export("weight,2026-10-30T23:30:00-05:00,66,kg,X")
        self.assertIn(("2026-10-30", "23:30"), readings)


class SyncTest(unittest.TestCase):
    def test_second_run_adds_nothing(self):
        vault = TempVault(read_fixture("export-6.txt"))
        self.addCleanup(vault.cleanup)
        self.assertEqual(vault.run()[0], 0)
        first = vault.log.read_text(encoding="utf-8")
        self.assertEqual(vault.run()[0], 0)
        self.assertEqual(vault.log.read_text(encoding="utf-8"), first)
        self.assertEqual(len(vault.rows()), 3)

    def test_rows_are_written_oldest_first(self):
        vault = TempVault(read_fixture("export-6.txt"))
        self.addCleanup(vault.cleanup)
        vault.run()
        self.assertEqual([r["date"] for r in vault.rows()],
                         ["2026-10-30", "2026-10-31", "2026-11-01"])
        self.assertIn("| 2026-10-30 | 08:06 | 66.6 | 18.9 | Xiaomi Home |",
                      vault.log.read_text(encoding="utf-8"))

    def test_late_body_fat_fills_empty_cell(self):
        weight_only = "weight,2026-11-01T13:10:14+08:00,65,kg,Xiaomi Home"
        vault = TempVault(weight_only)
        self.addCleanup(vault.cleanup)
        vault.run()
        self.assertIsNone(vault.row("2026-11-01")["body_fat_pct"])
        vault.export.write_text(read_fixture("export-6.txt"), encoding="utf-8")
        vault.run()
        self.assertEqual(vault.row("2026-11-01")["body_fat_pct"], 18.2)

    def test_never_changes_a_cell_with_a_value(self):
        log = LOG_HEADER + "| 2026-10-30 | 08:06 | 70.0 | 18.9 | Xiaomi Home |\n"
        vault = TempVault(read_fixture("export-6.txt"), log)
        self.addCleanup(vault.cleanup)
        vault.run()
        self.assertEqual(vault.row("2026-10-30")["weight_kg"], 70.0)

    def test_hand_added_row_and_blank_line_survive(self):
        log = LOG_HEADER + "| 2026-10-01 | 07:00 | 67.0 |  | hand |\n\nnote kept\n"
        vault = TempVault(read_fixture("export-6.txt"), log)
        self.addCleanup(vault.cleanup)
        vault.run()
        text = vault.log.read_text(encoding="utf-8")
        self.assertIn("| 2026-10-01 | 07:00 | 67.0 |  | hand |", text)
        self.assertIn("note kept", text)
        self.assertEqual(len(vault.rows()), 4)

    def test_missing_export_exits_1_with_path(self):
        vault = TempVault(None)
        self.addCleanup(vault.cleanup)
        code, out = vault.run()
        self.assertEqual(code, 1)
        self.assertIn("health-latest.txt", out)

    def test_silent_on_success(self):
        vault = TempVault(read_fixture("export-6.txt"))
        self.addCleanup(vault.cleanup)
        self.assertEqual(vault.run(today="2026-11-02"), (0, ""))


class StaleLineTest(unittest.TestCase):
    def test_one_nudge_exactly_eight_days_after_newest_reading(self):
        readings, _ = health_sync.parse_export(read_fixture("export-6.txt"))
        self.assertIsNone(health_sync.stale_line(readings, date(2026, 11, 8)))
        self.assertIn("2026-11-01", health_sync.stale_line(readings, date(2026, 11, 9)))
        self.assertIsNone(health_sync.stale_line(readings, date(2026, 11, 10)))


if __name__ == "__main__":
    unittest.main()
