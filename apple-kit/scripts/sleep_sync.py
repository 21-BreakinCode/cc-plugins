#!/usr/bin/env python3
"""Sync sleep nights from the iPhone "Health Export" Shortcut into a sleep log.

Input lines (one per Health sleep sample), written by the Shortcut:
    sleep,2026-11-11T03:38:04+07:00,2026-11-11T04:10:04+07:00,Core,Apple Watch

Output: a Markdown table, one row per night, oldest first. The export is the
truth for the nights it holds: their rows are rewritten. Every other row and
line is kept as it is. A night that the export window can cut is written only
when the log has no row for it yet, or when it holds more sleep than that row.

Usage: sleep_sync.py --config <vault>/.apple-kit.json
Prints nothing on success. Exit 1 when the export file cannot be read.
"""

import argparse
import json
import os
import sys
import tempfile
from datetime import datetime, timedelta
from pathlib import Path

LOG_COLUMNS = ("night", "bed", "wake", "asleep", "deep", "rem", "awake", "utc")
DURATION_KEYS = ("asleep", "deep", "rem", "awake")
LOG_HEADER = [
    "| " + " | ".join(LOG_COLUMNS) + " |",
    "|" + "---|" * len(LOG_COLUMNS),
]
ASLEEP_STAGES = {"Core", "Deep", "REM", "Asleep"}
SESSION_GAP = timedelta(hours=3)
NIGHT_SHIFT = timedelta(hours=12)  # 03:38 on 11-11 belongs to night 11-10
NAP_START_HOURS = range(12, 18)
TRUNCATION_WINDOW = timedelta(minutes=60)


def _is_asleep(stage: str) -> bool:
    return stage in ASLEEP_STAGES or stage.startswith("Asleep")


def _parse_samples(text: str) -> list[tuple[datetime, datetime, str]]:
    samples = []
    for line in text.splitlines():
        parts = [part.strip() for part in line.split(",")]
        if len(parts) != 5 or parts[0] != "sleep":
            continue
        try:
            start, end = datetime.fromisoformat(parts[1]), datetime.fromisoformat(parts[2])
        except ValueError:
            continue
        if start.tzinfo is None or end <= start:
            continue
        samples.append((start, end, parts[3]))
    return sorted(samples)


def _union_minutes(intervals: list[tuple[datetime, datetime]]) -> int:
    merged: list[list[datetime]] = []
    for start, end in sorted(intervals):
        if merged and start <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], end)
        else:
            merged.append([start, end])
    total = sum((end - start for start, end in merged), timedelta())
    return int(total.total_seconds() // 60)


def _sessions(asleep: list[tuple[datetime, datetime, str]]) -> list[list]:
    sessions: list[list] = []
    session_end = None
    for sample in asleep:
        if session_end is None or sample[0] - session_end > SESSION_GAP:
            sessions.append([])
            session_end = sample[1]
        sessions[-1].append(sample)
        session_end = max(session_end, sample[1])
    return sessions


def _night_row(session: list, awake_samples: list) -> dict:
    bed = session[0][0]
    wake = max(end for _, end, _ in session)
    stage_minutes = lambda stage: _union_minutes([(s, e) for s, e, st in session if st == stage])
    awake = [(max(s, bed), min(e, wake)) for s, e, _ in awake_samples if s < wake and e > bed]
    return {
        "night": (bed - NIGHT_SHIFT).strftime("%Y-%m-%d"),
        "bed": bed.strftime("%H:%M"),
        "wake": wake.strftime("%H:%M"),
        "asleep": _union_minutes([(s, e) for s, e, _ in session]),
        "deep": stage_minutes("Deep"),
        "rem": stage_minutes("REM"),
        "awake": _union_minutes(awake),
        "utc": bed.isoformat()[-6:],
        "_start": bed,
    }


def parse_export(text: str) -> tuple[dict[str, dict], str | None]:
    """Return nights keyed by night date, and the night the window can cut (or None)."""
    samples = _parse_samples(text)
    if not samples:
        return {}, None
    earliest = samples[0][0]
    asleep = [sample for sample in samples if _is_asleep(sample[2])]
    awake_samples = [sample for sample in samples if sample[2] == "Awake"]
    nights: dict[str, dict] = {}
    for session in _sessions(asleep):
        if session[0][0].hour in NAP_START_HOURS:
            continue
        row = _night_row(session, awake_samples)
        if row["night"] not in nights or row["asleep"] > nights[row["night"]]["asleep"]:
            nights[row["night"]] = row
    truncated = next((night for night, row in sorted(nights.items())
                      if row["_start"] - earliest < TRUNCATION_WINDOW), None)
    clean = {night: {k: v for k, v in row.items() if k != "_start"} for night, row in sorted(nights.items())}
    return clean, truncated


def _minutes(cell: str) -> int:
    hours, minutes = cell.split(":")
    return int(hours) * 60 + int(minutes)


def _parse_row(line: str) -> dict | None:
    cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
    if len(cells) != len(LOG_COLUMNS) or not cells[0][:4].isdigit():
        return None
    row: dict = dict(zip(LOG_COLUMNS, cells))
    try:
        datetime.strptime(row["night"], "%Y-%m-%d")  # a hand row like "2026-11-03 (est)" stays text
        for key in DURATION_KEYS:
            row[key] = _minutes(row[key])
    except ValueError:
        return None
    return row


def parse_log(text: str) -> tuple[list[str], list[dict]]:
    """Split the log into kept non-row lines and table rows."""
    kept, rows = [], []
    for line in text.splitlines():
        if line in LOG_HEADER:
            continue
        row = _parse_row(line) if line.startswith("|") else None
        if row is None:
            kept.append(line)
        else:
            rows.append(row)
    return kept, rows


def merge(rows: list[dict], nights: dict[str, dict], truncated: str | None) -> list[dict]:
    """Rows of the export's nights replace old rows. A cut night only fills a gap or grows."""
    logged = {row["night"]: row["asleep"] for row in rows}
    fresh = {night: row for night, row in nights.items()
             if night != truncated or row["asleep"] > logged.get(night, -1)}
    merged = [dict(row) for row in rows if row["night"] not in fresh] + [dict(row) for row in fresh.values()]
    return sorted(merged, key=lambda row: row["night"])


def _format_minutes(minutes: int) -> str:
    return f"{minutes // 60}:{minutes % 60:02d}"


def render_log(rows: list[dict], kept: list[str] | None = None) -> str:
    lines = list(LOG_HEADER)
    for row in rows:
        cells = [row["night"], row["bed"], row["wake"],
                 *(_format_minutes(row[key]) for key in DURATION_KEYS), row["utc"]]
        lines.append("| " + " | ".join(cells) + " |")
    if kept:
        lines += [""] + kept if kept[0].strip() else kept
    return "\n".join(lines) + "\n"


def _write_atomic(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        handle.write(text)
    os.replace(tmp, path)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Sync Health Export sleep samples into the sleep log.")
    parser.add_argument("--config", required=True, type=Path)
    args = parser.parse_args(argv)

    sleep = json.loads(args.config.read_text(encoding="utf-8"))["sleep"]
    export_path = Path(os.path.expanduser(sleep["export_path"]))
    log_path = args.config.parent / sleep["sleep_log"]

    try:
        export_text = export_path.read_text(encoding="utf-8")
    except OSError as error:  # missing, an iCloud placeholder, or blocked by macOS privacy
        print(f"apple-kit: sleep export not readable ({type(error).__name__}): {export_path}")
        return 1

    nights, truncated = parse_export(export_text)
    if not nights:
        return 0
    log_text = log_path.read_text(encoding="utf-8") if log_path.exists() else ""
    kept, rows = parse_log(log_text)
    new_text = render_log(merge(rows, nights, truncated), kept)
    if new_text != log_text:
        _write_atomic(log_path, new_text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
