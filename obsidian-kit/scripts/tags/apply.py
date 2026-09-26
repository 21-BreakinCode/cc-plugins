"""Apply an approved tag plan: back up, rewrite frontmatter tags, rewrite body tags, update the taxonomy.

Usage (from the vault root): python3 apply.py <work-dir>
"""
import csv
import json
import shutil
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.note_text import read_property, split_frontmatter  # noqa: E402
from common.obsidian_eval import ObsidianCliError, run_app_script  # noqa: E402
from common.vault import (VaultConfigError, find_vault_root, is_excluded,  # noqa: E402
                          load_config, require_obsidian_running)
from rewrite import rewrite_body  # noqa: E402
from taxonomy import add_rows, has_sections, parse_taxonomy  # noqa: E402

VALID_ACTIONS = {"rename", "code", "keep"}
REWRITE_FRONTMATTER_JS = """
const falseTags = new Set(args.falseTags);
const renameTag = (tag) => {
  for (const [oldTag, newTag] of args.renames) {
    if (tag === oldTag || tag.startsWith(oldTag + '/')) return newTag + tag.slice(oldTag.length);
  }
  return tag;
};
const changed = [];
const failed = [];
for (const path of args.paths) {
  const file = app.vault.getAbstractFileByPath(path);
  if (!file) continue;
  try {
    await app.fileManager.processFrontMatter(file, (frontmatter) => {
      if (!frontmatter.tags) return;
      const before = (Array.isArray(frontmatter.tags) ? frontmatter.tags : String(frontmatter.tags).split(/[\\s,]+/))
        .filter(Boolean).map(tag => String(tag).replace(/^#/, ''));
      const after = [...new Set(before.filter(tag => !falseTags.has(tag)).map(renameTag))];
      if (JSON.stringify(before) !== JSON.stringify(after)) { frontmatter.tags = after; changed.push(path); }
    });
  } catch (e) {
    failed.push({path, error: String(e && e.stack || e)});
  }
}
return {changed, failed};
"""


class PlanError(ValueError):
    pass


def read_plan(plan_path: Path) -> tuple[dict[str, str], set[str], list[str]]:
    renames, false_tags, kept = {}, set(), []
    with plan_path.open(encoding="utf-8") as plan_file:
        for line_number, row in enumerate(csv.DictReader(plan_file, delimiter="\t"), start=2):
            if row["action"] is None or row["old"] is None or row["new"] is None:
                raise PlanError(f"line {line_number}: row is missing a column")
            action, old_tag, new_tag = row["action"].strip(), row["old"].strip().lstrip("#"), row["new"].strip().lstrip("#")
            if action not in VALID_ACTIONS:
                raise PlanError(f"line {line_number}: action must be one of {sorted(VALID_ACTIONS)}")
            if not old_tag:
                raise PlanError(f"line {line_number}: old tag is empty")
            if action == "rename" and not new_tag:
                raise PlanError(f"line {line_number}: rename of {old_tag} needs a new tag")
            if any(char.isspace() for char in new_tag):
                raise PlanError(f"line {line_number}: new tag {new_tag!r} has whitespace")
            if action == "rename":
                renames[old_tag] = new_tag
            elif action == "code":
                false_tags.add(old_tag)
            else:
                kept.append(old_tag)
    return renames, false_tags, kept


def affected_paths(inventory: dict[str, list[str]], tags: list[str]) -> list[str]:
    return sorted({path for tag, paths in inventory.items()
                   if any(tag == target or tag.startswith(target + "/") for target in tags) for path in paths})


def check_backup_dir(backup_dir: Path) -> str | None:
    if backup_dir.exists():
        return f"backup folder exists: {backup_dir}. Use a new work dir for each apply."
    return None


def paths_for_body_rewrite(paths: list[str], frontmatter_failed: list[dict]) -> list[str]:
    failed_paths = {entry["path"] for entry in frontmatter_failed}
    return [path for path in paths if path not in failed_paths]


def update_taxonomy(taxonomy_path: Path, renames: dict[str, str], kept: list[str]) -> None:
    text = taxonomy_path.read_text(encoding="utf-8")
    allowed, _ = parse_taxonomy(text)
    new_allowed = sorted({*renames.values(), *kept} - set(allowed))
    if new_allowed:
        text = add_rows(text, "Allowed", [[f"`{tag}`", ""] for tag in new_allowed])
    if renames:
        today = date.today().isoformat()
        text = add_rows(text, "Merged", [[f"`{old}`", f"`{new}`", today] for old, new in sorted(renames.items())])
    taxonomy_path.write_text(text, encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 1
    work_dir = Path(sys.argv[1])
    backup_dir = work_dir / "backup"
    backup_conflict = check_backup_dir(backup_dir)
    if backup_conflict:
        print(backup_conflict, file=sys.stderr)
        return 1
    require_obsidian_running()
    try:
        vault_root = find_vault_root(Path.cwd())
        config = load_config(vault_root)
        renames, false_tags, kept = read_plan(work_dir / "tag-plan.tsv")
        taxonomy_path = vault_root / config["taxonomyPath"]
        if not has_sections(taxonomy_path.read_text(encoding="utf-8")):
            raise VaultConfigError(f"taxonomy file needs ## Allowed and ## Merged sections: {taxonomy_path}")
    except (VaultConfigError, PlanError) as setup_error:
        print(setup_error, file=sys.stderr)
        return 1
    inventory = json.loads((work_dir / "inventory.json").read_text(encoding="utf-8"))
    paths = [path for path in affected_paths(inventory, [*renames, *false_tags]) if not is_excluded(path, config)]

    for path in paths:
        (backup_dir / path).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(vault_root / path, backup_dir / path)
    print(f"backup folder: {backup_dir}")

    ordered_renames = sorted(renames.items(), key=lambda pair: len(pair[0]), reverse=True)
    try:
        frontmatter_result = run_app_script(REWRITE_FRONTMATTER_JS, {
            "paths": paths, "renames": ordered_renames, "falseTags": sorted(false_tags)})
    except ObsidianCliError as cli_error:
        print(f"frontmatter step failed, no body changed: {cli_error}", file=sys.stderr)
        return 1
    frontmatter_changed, frontmatter_failed = frontmatter_result["changed"], frontmatter_result["failed"]

    body_changed, drawing_paths = [], []
    for path in paths_for_body_rewrite(paths, frontmatter_failed):
        note = vault_root / path
        frontmatter, body = split_frontmatter(note.read_text(encoding="utf-8"))
        if read_property(frontmatter, "excalidraw-plugin"):
            drawing_paths.append(path)
            continue
        new_body = rewrite_body(body, renames, false_tags)
        if new_body != body:
            note.write_text(frontmatter + new_body, encoding="utf-8")
            body_changed.append(path)

    log_lines = ["# audit-tags log", "", f"Backups: {backup_dir}", "",
                 "Undo one file: copy it back from the backup folder, or `obsidian history:restore path=<file> version=<n>`.", ""]
    log_lines += [f"- frontmatter: {path}" for path in frontmatter_changed]
    log_lines += [f"- FAILED frontmatter: {entry['path']}: {entry['error']}" for entry in frontmatter_failed]
    log_lines += [f"- body: {path}" for path in body_changed]
    log_lines += [f"- skipped drawing: {path}" for path in drawing_paths]
    (work_dir / "tag-log.md").write_text("\n".join(log_lines) + "\n", encoding="utf-8")

    update_taxonomy(taxonomy_path, renames, kept)
    print(f"changed {len(set(frontmatter_changed) | set(body_changed))} files; log at {work_dir / 'tag-log.md'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
