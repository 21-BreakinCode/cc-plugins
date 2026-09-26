"""Self-check for note-type inference and format checks: python3 test_notes.py"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

from check_note import check_note
from infer_type import infer_type

CHECK_NOTE_SCRIPT = Path(__file__).resolve().parent / "check_note.py"

TYPE_FOLDERS = {
    "03Resource/Zettelkasten/Permanent": "concept",
    "03Resource/Zettelkasten/Literature": "literature",
    "03Resource/Zettelkasten/Fleeting": "fleeting",
}
GO_SERIES = "03Resource/Zettelkasten/Literature/GoConcurrencyOOM"
GO_SIBLINGS = {"00__map__go__concurrency__OOM.md", "31__semaphore__Weighted__internals.md"}

# Rule 1: map names, in all five legacy styles.
assert infer_type(f"{GO_SERIES}/00__map__go__concurrency__OOM.md", GO_SIBLINGS, TYPE_FOLDERS) == ("map", "map-name")
assert infer_type("03Resource/Zettelkasten/Literature/AtomiHabitsReadingReview/原子習慣 MOC.md", set(), TYPE_FOLDERS)[0] == "map"
assert infer_type("01Project/Leetcode/Strategy/DP/DP__MoC.md", set(), TYPE_FOLDERS)[0] == "map"
assert infer_type("03Resource/Zettelkasten/Literature/GolangVersionCoupling/_index__Golang__version__coupling.md", set(), TYPE_FOLDERS)[0] == "map"
assert infer_type("03Resource/Zettelkasten/Permanent/connecting_remote_databases__index.md", set(), TYPE_FOLDERS)[0] == "map"
# __overview is not a map name.
assert infer_type("03Resource/Zettelkasten/Permanent/GraphQL__overview.md", set(), TYPE_FOLDERS) == (
    "concept", "folder:03Resource/Zettelkasten/Permanent")
# MOC/MoC must be tokens, not substrings.
assert infer_type("a/PROMOCODE.md", set(), {}) == (None, "unmatched")
assert infer_type("a/_indexOfDrawings.md", set(), {}) == (None, "unmatched")
# Rule 2: numbered note next to a map.
assert infer_type(f"{GO_SERIES}/31__semaphore__Weighted__internals.md", GO_SIBLINGS, TYPE_FOLDERS) == (
    "takeaway", "numbered-with-map")
# A numbered note without a map falls through to its folder.
assert infer_type("03Resource/Zettelkasten/Literature/X/31__a.md", {"31__a.md"}, TYPE_FOLDERS)[0] == "literature"
# Rule 4: no match. Leetcode problem names start with 4 digits and a dot.
assert infer_type("01Project/Leetcode/Tracks/0796.__rotate__string.md", set(), TYPE_FOLDERS) == (None, "unmatched")

CONCEPT_OK = "---\nnote-type: concept\n---\n#domain/llm\n\n## Claude Subagents\n**Subagents offload work.**\n\n- a\n\nRelated: [[Claude Code]]\nSources: [docs](https://x)\n"
assert check_note("concept", "Claude__subagents.md", CONCEPT_OK) == []
failures = check_note("concept", "x.md", "## Title\n" + "- line\n" * 50)
assert "missing note-type property" in failures
assert "line 1 is not a tag line" in failures
assert "missing bold one-sentence claim" in failures
assert any(failure.startswith("over one screen") for failure in failures)
assert "missing Related:" in failures and "missing Sources:" not in failures
# A bold claim may sit in a quote or a callout line.
for claim_line in ("> **Claim.**", "> [!danger] **Claim.**"):
    quoted = f"---\nnote-type: concept\n---\n#t\n\n## T\n{claim_line}\n\nRelated: [[a]]\n"
    assert check_note("concept", "x.md", quoted) == [], claim_line

TAKEAWAY = "---\nnote-type: takeaway\n---\n#lang/go\n\n## Title\n**Claim.**\n\n> [!example] From this session\n> x\n\nRelated: [[00__map__go]]\nSources: x\n"
assert check_note("takeaway", "31__x.md", TAKEAWAY) == []
assert "missing link back to the map" in check_note("takeaway", "31__x.md", TAKEAWAY.replace("[[00__map__go]]", "[[other]]"))

MAP = "---\nnote-type: map\n---\n#lang/go\n\n## Map\n**Claim.**\n\n```\na → b\n```\n- [[01__a]]: gloss\n"
assert check_note("map", "00__map__go.md", MAP) == []
assert "name must start with 00__map__" in check_note("map", "DP__MoC.md", MAP)
# A map directly in a type folder keeps its name (migrate-notes does not rename it).
assert check_note("map", "connecting__index.md", MAP, keep_map_name=True) == []

LITERATURE = "---\nnote-type: literature\n---\n#domain/psychology\n\n> Link: https://youtu.be/x\n\n# Title\n**Claim.**\n" + "- x\n" * 80
assert check_note("literature", "a.md", LITERATURE) == []
assert "missing > Link: <url> or > Source: <name>" in check_note(
    "literature", "a.md", LITERATURE.replace("> Link: https://youtu.be/x", ""))
assert check_note("literature", "a.md", LITERATURE.replace("> Link: https://youtu.be/x", "> Source: Atomic Habits")) == []
assert check_note("literature", "a.md", LITERATURE.replace("> Link: https://youtu.be/x", "") + "Sources: https://x\n") == []
assert check_note("literature", "a.md", LITERATURE.replace("> Link: https://youtu.be/x", ""), in_mapped_series=True) == []

assert check_note("fleeting", "a.md", "---\nnote-type: fleeting\n---\n#x\n\n## Title\nanything\n") == []

# M3: check_note.py main() must not report an Excalidraw drawing as an unset note-type.
with tempfile.TemporaryDirectory() as temp:
    vault_root = Path(temp)
    (vault_root / ".obsidian").mkdir()
    (vault_root / ".obsidian-kit.json").write_text(json.dumps({
        "taxonomyPath": "t.md", "noteFormatFolders": ["Z"], "excludedPaths": [], "typeFolders": {},
    }), encoding="utf-8")
    (vault_root / "Z").mkdir()
    (vault_root / "Z/drawing.md").write_text("---\nexcalidraw-plugin: parsed\n---\n", encoding="utf-8")
    completed = subprocess.run([sys.executable, str(CHECK_NOTE_SCRIPT), "Z/drawing.md"],
                               cwd=vault_root, capture_output=True, text=True)
    assert completed.returncode == 0, completed.stderr
    assert "0 of 1 notes fail" in completed.stdout
    assert "unset note-type" not in completed.stdout

print("test_notes: all passed")
