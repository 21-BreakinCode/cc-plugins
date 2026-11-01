#!/usr/bin/env python3
"""Sync weight and body fat from the iPhone "Health Export" Shortcut into a body log.

Input lines (one per Health sample), written by the Shortcut:
    weight,2026-10-30T08:06:50+08:00,66.6,kg,Xiaomi Home
    body_fat,2026-10-30T08:06:50+08:00,18.9,%,Xiaomi Home

Output: a Markdown table, one row per reading, oldest first. The log is
machine-owned: rows are added, an empty cell can be filled, a value is never
changed, and every other line is kept as it is.

Usage: health_sync.py --config <vault>/.apple-kit.json
Prints nothing on success. Exit 1 when the export file cannot be read.
"""

import argparse
import json
import os
import sys
import tempfile
from datetime import date, datetime
from pathlib import Path

LOG_COLUMNS = ("date", "time", "weight_kg", "body_fat_pct", "source")
LOG_HEADER = [
    "| " + " | ".join(LOG_COLUMNS) + " |",
    "|" + "---|" * len(LOG_COLUMNS),
]
UNIT_BY_TYPE = {"weight": ("kg", "weight_kg"), "body_fat": ("%", "body_fat_pct")}
VALUE_KEYS = ("weight_kg", "body_fat_pct")
STALE_AFTER_DAYS = 8


def parse_export(text: str) -> tuple[dict, int]:
    """Return readings keyed by (date, time), and the count of skipped lines."""
    readings: dict[tuple[str, str], dict] = {}
    skipped = 0
    for line in text.splitlines():
        if not line.strip():
            continue
        parts = [part.strip() for part in line.split(",")]
        if len(parts) != 5 or parts[0] not in UNIT_BY_TYPE:
            skipped += 1
            continue
        kind, stamp, raw_value, unit, source = parts
        expected_unit, value_key = UNIT_BY_TYPE[kind]
        try:
            moment = datetime.fromisoformat(stamp)
            value = round(float(raw_value), 1)
        except ValueError:
            skipped += 1
            continue
        if unit != expected_unit:
            skipped += 1
            continue
        key = (moment.strftime("%Y-%m-%d"), moment.strftime("%H:%M"))
        reading = readings.setdefault(key, {
            "date": key[0], "time": key[1],
            "weight_kg": None, "body_fat_pct": None, "source": source})
        reading[value_key] = value
    return readings, skipped


def _parse_row(line: str) -> dict | None:
    cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
    if len(cells) != len(LOG_COLUMNS) or not cells[0][:4].isdigit():
        return None
    row: dict = dict(zip(LOG_COLUMNS, cells))
    try:
        for key in VALUE_KEYS:
            row[key] = float(row[key]) if row[key] else None
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


def merge(rows: list[dict], new: dict) -> tuple[list[dict], int, int]:
    """Add new readings and fill empty cells. Returns rows, added, filled."""
    merged = {(row["date"], row["time"]): dict(row) for row in rows}
    added = filled = 0
    for key, reading in new.items():
        current = merged.get(key)
        if current is None:
            merged[key] = dict(reading)
            added += 1
            continue
        for value_key in VALUE_KEYS:
            if current[value_key] is None and reading[value_key] is not None:
                current[value_key] = reading[value_key]
                filled += 1
    return [merged[key] for key in sorted(merged)], added, filled


def _format_value(value: float | None) -> str:
    return "" if value is None else f"{value:.1f}"


def render_log(rows: list[dict], kept: list[str] | None = None) -> str:
    lines = list(LOG_HEADER)
    for row in rows:
        cells = [row["date"], row["time"], _format_value(row["weight_kg"]),
                 _format_value(row["body_fat_pct"]), row["source"]]
        lines.append("| " + " | ".join(cells) + " |")
    if kept:
        lines += [""] + kept if kept[0].strip() else kept
    return "\n".join(lines) + "\n"


def stale_line(readings: dict, today: date) -> str | None:
    """One nudge on the day the newest reading turns exactly 8 days old."""
    if not readings:
        return None
    newest = max(day for day, _ in readings)
    if (today - date.fromisoformat(newest)).days != STALE_AFTER_DAYS:
        return None
    return f"apple-kit: no new weigh-in for {STALE_AFTER_DAYS} days (last {newest})"


def _write_atomic(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        handle.write(text)
    os.replace(tmp, path)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Sync Health Export readings into the body log.")
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--today", type=date.fromisoformat, default=date.today())
    args = parser.parse_args(argv)

    health = json.loads(args.config.read_text(encoding="utf-8"))["health"]
    export_path = Path(os.path.expanduser(health["export_path"]))
    log_path = args.config.parent / health["body_log"]

    try:
        export_text = export_path.read_text(encoding="utf-8")
    except OSError:  # missing, or an iCloud placeholder not downloaded yet
        print(f"apple-kit: health export not found: {export_path}")
        return 1

    readings, _ = parse_export(export_text)
    log_text = log_path.read_text(encoding="utf-8") if log_path.exists() else ""
    kept, rows = parse_log(log_text)
    merged, added, filled = merge(rows, readings)
    if added or filled or not log_path.exists():
        _write_atomic(log_path, render_log(merged, kept))

    nudge = stale_line(readings, args.today)
    if nudge:
        print(nudge)
    return 0


if __name__ == "__main__":
    sys.exit(main())
