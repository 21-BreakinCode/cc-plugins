"""Tests for apple-kit/scripts/sleep_sync.py. Run: python3 -B -m unittest discover -s apple-kit/tests -v"""

import contextlib
import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path

TESTS_DIR = Path(__file__).resolve().parent
FIXTURES = TESTS_DIR / "fixtures"
SCRIPT = TESTS_DIR.parent / "scripts" / "sleep_sync.py"

spec = importlib.util.spec_from_file_location("sleep_sync", SCRIPT)
assert spec is not None and spec.loader is not None, SCRIPT
sleep_sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sleep_sync)

LOG_HEADER = "| night | bed | wake | asleep | deep | rem | awake | utc |\n|---|---|---|---|---|---|---|---|\n"


def sample(start, end, stage="Core", offset="+07:00"):
    return f"sleep,{start}:00{offset},{end}:00{offset},{stage},"


class TempVault:
    """A temp vault folder holding .apple-kit.json, a sleep export, and the sleep log."""

    def __init__(self, export_text, log_text=None):
        self._dir = tempfile.TemporaryDirectory()
        self.root = Path(self._dir.name)
        self.export = self.root / "sleep-latest.txt"
        self.log = self.root / "Sleep" / "sleep-log.md"
        if export_text is not None:
            self.export.write_text(export_text, encoding="utf-8")
        if log_text is not None:
            self.log.parent.mkdir(parents=True)
            self.log.write_text(log_text, encoding="utf-8")
        self.config = self.root / ".apple-kit.json"
        self.config.write_text(json.dumps({"sleep": {
            "export_path": str(self.export), "sleep_log": "Sleep/sleep-log.md"}}))

    def run(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = sleep_sync.main(["--config", str(self.config)])
        return code, out.getvalue()

    def rows(self):
        return {row["night"]: row for row in sleep_sync.parse_log(self.log.read_text(encoding="utf-8"))[1]}

    def cleanup(self):
        self._dir.cleanup()


class ParseExportTest(unittest.TestCase):
    def test_real_export_nights(self):
        nights, truncated = sleep_sync.parse_export((FIXTURES / "sleep-188.txt").read_text(encoding="utf-8"))
        self.assertEqual(truncated, "2026-11-07")
        expected = {
            "2026-11-08": ("03:43", "08:23", 262),
            "2026-11-09": ("00:42", "09:22", 442),
            "2026-11-10": ("03:38", "12:01", 502),
        }
        for night, (bed, wake, asleep) in expected.items():
            self.assertEqual((nights[night]["bed"], nights[night]["wake"], nights[night]["asleep"]),
                             (bed, wake, asleep), night)
            self.assertEqual(nights[night]["utc"], "+07:00")

    def test_nap_ignored(self):
        text = "\n".join([
            sample("2026-11-10T01:00", "2026-11-10T08:00"),
            sample("2026-11-10T14:00", "2026-11-10T15:30"),
        ])
        nights, _ = sleep_sync.parse_export(text)
        self.assertEqual(list(nights), ["2026-11-09"])
        self.assertEqual(nights["2026-11-09"]["asleep"], 420)

    def test_zone_change(self):
        text = "\n".join([
            sample("2026-11-15T01:00", "2026-11-15T08:00", offset="+07:00"),
            sample("2026-11-17T00:30", "2026-11-17T07:30", offset="+08:00"),
        ])
        nights, _ = sleep_sync.parse_export(text)
        self.assertEqual(nights["2026-11-14"]["utc"], "+07:00")
        self.assertEqual(nights["2026-11-16"]["utc"], "+08:00")
        self.assertEqual(nights["2026-11-16"]["bed"], "00:30")

    def test_awake_and_in_bed_not_asleep(self):
        text = "\n".join([
            sample("2026-11-10T00:00", "2026-11-10T09:00", "In Bed"),
            sample("2026-11-10T01:00", "2026-11-10T03:00", "Deep"),
            sample("2026-11-10T03:00", "2026-11-10T03:30", "Awake"),
            sample("2026-11-10T03:30", "2026-11-10T05:00", "REM"),
        ])
        nights, _ = sleep_sync.parse_export(text)
        night = nights["2026-11-09"]
        self.assertEqual((night["bed"], night["wake"]), ("01:00", "05:00"))
        self.assertEqual((night["asleep"], night["deep"], night["rem"], night["awake"]), (210, 120, 90, 30))


class SyncTest(unittest.TestCase):
    def setUp(self):
        self.vaults = []

    def tearDown(self):
        for vault in self.vaults:
            vault.cleanup()

    def vault(self, export_text, log_text=None):
        vault = TempVault(export_text, log_text)
        self.vaults.append(vault)
        return vault

    def test_first_sync_writes_all_nights_with_truncated(self):
        vault = self.vault((FIXTURES / "sleep-188.txt").read_text(encoding="utf-8"))
        self.assertEqual(vault.run(), (0, ""))
        self.assertEqual(list(vault.rows()), ["2026-11-07", "2026-11-08", "2026-11-09", "2026-11-10"])
        self.assertIn("| 2026-11-10 | 03:38 | 12:01 | 8:22 |", vault.log.read_text(encoding="utf-8"))

    def test_truncated_night_written_only_when_absent(self):
        old_row = "| 2026-11-07 | 23:00 | 08:00 | 9:00 | 1:00 | 2:00 | 0:10 | +07:00 |\n"
        export = "\n".join([
            sample("2026-11-08T06:00", "2026-11-08T08:00"),
            sample("2026-11-09T01:00", "2026-11-09T08:00"),
        ])
        vault = self.vault(export, LOG_HEADER + old_row)
        vault.run()
        self.assertEqual(vault.rows()["2026-11-07"]["asleep"], 540)
        self.assertEqual(vault.rows()["2026-11-08"]["asleep"], 420)

    def test_rewrite_nights_in_export(self):
        log = LOG_HEADER + (
            "| 2026-10-01 | 01:00 | 08:00 | 7:00 | 1:00 | 1:30 | 0:20 | +08:00 |\n"
            "| 2026-11-10 | 03:38 | 07:38 | 4:00 | 0:30 | 0:40 | 0:05 | +07:00 |\n")
        export = "\n".join([
            sample("2026-11-09T22:00", "2026-11-09T22:30"),
            sample("2026-11-11T03:38", "2026-11-11T12:00"),
        ])
        vault = self.vault(export, log)
        vault.run()
        rows = vault.rows()
        self.assertEqual(rows["2026-11-10"]["asleep"], 502)
        self.assertEqual(rows["2026-10-01"]["asleep"], 420)

    def test_empty_export_no_change(self):
        log = LOG_HEADER + "| 2026-11-10 | 03:38 | 12:01 | 8:22 | 1:00 | 2:00 | 0:30 | +07:00 |\n"
        vault = self.vault("", log)
        self.assertEqual(vault.run(), (0, ""))
        self.assertEqual(vault.log.read_text(encoding="utf-8"), log)

    def test_kept_lines(self):
        log = LOG_HEADER + "| 2026-11-01 | 01:00 | 08:00 | 7:00 | 1:00 | 1:30 | 0:20 | +08:00 |\n\nhand note\n"
        vault = self.vault(sample("2026-11-10T01:00", "2026-11-10T02:00") + "\n"
                           + sample("2026-11-11T01:00", "2026-11-11T08:00"), log)
        vault.run()
        text = vault.log.read_text(encoding="utf-8")
        self.assertIn("hand note", text)
        self.assertIn("| 2026-11-10 | 01:00 | 08:00 | 7:00 |", text)

    def test_unreadable_export_exit_1(self):
        vault = self.vault(None)
        code, out = vault.run()
        self.assertEqual(code, 1)
        self.assertIn("apple-kit: sleep export not readable (FileNotFoundError)", out)


if __name__ == "__main__":
    unittest.main()
