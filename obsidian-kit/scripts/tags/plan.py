"""Scan vault tags and write a refactor plan for the user to edit.

Usage (from the vault root): python3 plan.py <work-dir>
"""
import csv
import json
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from classify import classify  # noqa: E402
from common.obsidian_eval import ObsidianCliError, run_app_script  # noqa: E402
from common.vault import VaultConfigError, find_vault_root, load_config, require_obsidian_running  # noqa: E402
from taxonomy import has_sections, parse_taxonomy  # noqa: E402

PLAN_COLUMNS = ["old", "kind", "action", "new", "files"]
SCAN_TAGS_JS = """
const isExcluded = (path) => args.excluded.some(folder => path === folder || path.startsWith(folder + '/'));
const filesByTag = {};
for (const file of app.vault.getMarkdownFiles()) {
  if (isExcluded(file.path)) continue;
  const cache = app.metadataCache.getFileCache(file);
  if (!cache) continue;
  const tags = new Set((cache.tags || []).map(entry => entry.tag.slice(1)));
  const frontmatterTags = cache.frontmatter && cache.frontmatter.tags;
  if (frontmatterTags) {
    (Array.isArray(frontmatterTags) ? frontmatterTags : String(frontmatterTags).split(/[\\s,]+/))
      .filter(Boolean).forEach(tag => tags.add(String(tag).replace(/^#/, '')));
  }
  tags.forEach(tag => (filesByTag[tag] = filesByTag[tag] || []).push(file.path));
}
return filesByTag;
"""


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 1
    require_obsidian_running()
    try:
        vault_root = find_vault_root(Path.cwd())
        config = load_config(vault_root)
        taxonomy_path = vault_root / config["taxonomyPath"]
        if not taxonomy_path.is_file():
            raise VaultConfigError(f"create the taxonomy file {taxonomy_path} first")
        taxonomy_text = taxonomy_path.read_text(encoding="utf-8")
        if not has_sections(taxonomy_text):
            raise VaultConfigError(f"taxonomy file needs ## Allowed and ## Merged sections: {taxonomy_path}")
        excluded = [folder.rstrip("/") for folder in config["excludedPaths"]]
        files_by_tag = run_app_script(SCAN_TAGS_JS, {"excluded": excluded})
    except (VaultConfigError, ObsidianCliError) as setup_error:
        print(setup_error, file=sys.stderr)
        return 1
    allowed, merged = parse_taxonomy(taxonomy_text)
    counts = {tag: len(paths) for tag, paths in files_by_tag.items()}
    findings = classify(counts, set(allowed), merged)

    work_dir = Path(sys.argv[1])
    work_dir.mkdir(parents=True, exist_ok=True)
    (work_dir / "inventory.json").write_text(json.dumps(files_by_tag, ensure_ascii=False, indent=1), encoding="utf-8")
    with (work_dir / "tag-plan.tsv").open("w", encoding="utf-8", newline="") as plan_file:
        writer = csv.writer(plan_file, delimiter="\t")
        writer.writerow(PLAN_COLUMNS)
        for item in findings:
            writer.writerow([item["tag"], item["kind"], item["action"], item["new"], counts[item["tag"]]])
    kind_counts = Counter(item["kind"] for item in findings)
    print(f"{len(counts)} tags scanned, {len(findings)} need a decision: "
          + ", ".join(f"{kind} {count}" for kind, count in kind_counts.most_common()))
    print(f"plan: {work_dir / 'tag-plan.tsv'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
