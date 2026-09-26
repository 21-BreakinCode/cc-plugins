"""One-time migration: set note-type and rename map notes, as plan → approve → apply.

Usage (from the vault root):
  python3 migrate.py plan <work-dir>    writes <work-dir>/migrate-plan.tsv for the user to edit
  python3 migrate.py apply <work-dir>   applies the edited plan, writes <work-dir>/migrate-log.md
"""
import csv
import sys
from pathlib import Path, PurePosixPath

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.note_text import read_property, split_frontmatter  # noqa: E402
from common.obsidian_eval import ObsidianCliError, run_cli  # noqa: E402
from common.vault import (VaultConfigError, find_vault_root, is_excluded,  # noqa: E402
                          is_under, load_config, require_obsidian_running)
from infer_type import MAP_PREFIX, infer_type  # noqa: E402

PLAN_NAME = "migrate-plan.tsv"
LOG_NAME = "migrate-log.md"
PLAN_COLUMNS = ["path", "note_type", "rule", "new_path"]
VALID_TYPES = {"map", "concept", "takeaway", "literature", "fleeting"}


def collect_notes(vault_root: Path, config: dict) -> list[str]:
    collected = []
    for folder in config["noteFormatFolders"]:
        for note in (vault_root / folder).rglob("*.md"):
            relative_path = note.relative_to(vault_root).as_posix()
            if is_excluded(relative_path, config):
                continue
            frontmatter = split_frontmatter(note.read_text(encoding="utf-8"))[0]
            if read_property(frontmatter, "excalidraw-plugin") or read_property(frontmatter, "note-type"):
                continue
            collected.append(relative_path)
    return sorted(set(collected))


def build_rows(note_paths: list[str], existing_paths: set[str], type_folders: dict) -> list[dict]:
    names_by_folder: dict[str, set[str]] = {}
    for path in note_paths:
        names_by_folder.setdefault(str(PurePosixPath(path).parent), set()).add(PurePosixPath(path).name)
    rows = []
    for path in note_paths:
        folder = PurePosixPath(path).parent
        note_type, rule = infer_type(path, names_by_folder[str(folder)], type_folders)
        new_path = ""
        if note_type == "map" and not folder.name == "" and not PurePosixPath(path).name.startswith(MAP_PREFIX):
            target = str(folder / f"{MAP_PREFIX}{folder.name}.md")
            if target in existing_paths or target in note_paths:
                rule = "map-name (rename target exists)"
            else:
                new_path = target
        rows.append({"path": path, "note_type": note_type or "", "rule": rule, "new_path": new_path})
    return rows


def write_plan(work_dir: Path, vault_root: Path, config: dict) -> int:
    note_paths = collect_notes(vault_root, config)
    existing_paths = {note.relative_to(vault_root).as_posix()
                      for folder in config["noteFormatFolders"] for note in (vault_root / folder).rglob("*.md")}
    rows = build_rows(note_paths, existing_paths, config["typeFolders"])
    work_dir.mkdir(parents=True, exist_ok=True)
    with (work_dir / PLAN_NAME).open("w", encoding="utf-8", newline="") as plan_file:
        writer = csv.DictWriter(plan_file, fieldnames=PLAN_COLUMNS, delimiter="\t")
        writer.writeheader()
        writer.writerows(rows)
    unset_count = sum(1 for row in rows if not row["note_type"])
    rename_count = sum(1 for row in rows if row["new_path"])
    print(f"wrote {work_dir / PLAN_NAME}: {len(rows)} notes, {rename_count} map renames, {unset_count} unset")
    return 0


def apply_plan(work_dir: Path, vault_root: Path, config: dict) -> int:
    with (work_dir / PLAN_NAME).open(encoding="utf-8") as plan_file:
        rows = list(csv.DictReader(plan_file, delimiter="\t"))
    bad_rows = [row["path"] for row in rows if row["note_type"] and row["note_type"] not in VALID_TYPES]
    if bad_rows:
        print(f"invalid note_type in plan for: {', '.join(bad_rows)}", file=sys.stderr)
        return 1
    log_lines = ["# migrate-notes log", ""]
    for row in rows:
        if not row["note_type"] or not is_under(row["path"], config["noteFormatFolders"]) \
                or is_excluded(row["path"], config):
            continue
        try:
            run_cli("property:set", "name=note-type", f"value={row['note_type']}", f"path={row['path']}")
            log_lines.append(f"- set note-type={row['note_type']}: {row['path']}")
            if row["new_path"]:
                run_cli("move", f"path={row['path']}", f"to={row['new_path']}")
                log_lines.append(f"  - moved to {row['new_path']} "
                                 f"(undo: obsidian move path=\"{row['new_path']}\" to=\"{row['path']}\")")
        except ObsidianCliError as cli_error:
            log_lines.append(f"- FAILED {row['path']}: {cli_error}")
            print(f"stopped at {row['path']}: {cli_error}", file=sys.stderr)
            (work_dir / LOG_NAME).write_text("\n".join(log_lines) + "\n", encoding="utf-8")
            return 1
    (work_dir / LOG_NAME).write_text("\n".join(log_lines) + "\n", encoding="utf-8")
    print(f"applied; log at {work_dir / LOG_NAME}")
    return 0


def main() -> int:
    if len(sys.argv) != 3 or sys.argv[1] not in ("plan", "apply"):
        print(__doc__, file=sys.stderr)
        return 1
    require_obsidian_running()
    try:
        vault_root = find_vault_root(Path.cwd())
        config = load_config(vault_root)
    except VaultConfigError as config_error:
        print(config_error, file=sys.stderr)
        return 1
    work_dir = Path(sys.argv[2])
    return (write_plan if sys.argv[1] == "plan" else apply_plan)(work_dir, vault_root, config)


if __name__ == "__main__":
    sys.exit(main())
