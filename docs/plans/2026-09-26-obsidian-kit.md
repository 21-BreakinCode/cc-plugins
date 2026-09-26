# obsidian-kit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `note-visualizer` into `obsidian-kit` 1.0.0: Excalidraw drawing, note formats by `note-type`, a one-time note migration, a tag audit, and a CLI primer hook.

**Architecture:** Skills hold workflows. Python scripts under `scripts/` hold every rule that a test can pin. Scripts talk to the running Obsidian app only through the `obsidian` CLI (`obsidian eval` for app APIs). Vault opinions live in the vault file `.obsidian-kit.json`, never in the plugin.

**Tech Stack:** Python 3 stdlib only, bash, Node (already used by the lint hook), the `obsidian` CLI 1.13.7, ExcalidrawAutomate.

**Spec:** `docs/specs/2026-09-26-obsidian-kit-design.md`

## Global Constraints

- Repo: `/Users/williamhung/Projects/PersonalPlugins`, branch `feat/obsidian-kit`. Vault: `/Users/williamhung/Projects/LifeOS`.
- Every bundled path in a skill or hook uses `${CLAUDE_PLUGIN_ROOT}`. No `find ~/.claude/plugins`. No reference to another plugin.
- Commands are `/obsidian-kit:<verb>-<noun>`: `create-excali`, `update-excali`, `format-note`, `migrate-notes`, `audit-tags`.
- Hidden skills set `user-invocable: false`: `obsidian-markdown`, `obsidian-bases`.
- `migrate-notes` and `audit-tags` set `disable-model-invocation: true`.
- The frontmatter key is `note-type`. Values: `map`, `concept`, `takeaway`, `literature`, `fleeting`.
- Map notes are named `00__map__<series-folder-name>.md`.
- False tags are wrapped in backticks in the body and removed from frontmatter `tags`.
- Scripts never read `excludedPaths` (the two Credentials folders and `04Archive`).
- Every bulk write: plan file → user approves → apply. Apply backs up every original file first.
- `obsidian` exits 0 on failure and prints `Error: ...`. Every CLI call goes through `run_cli`, which raises on that output.
- Version 1.0.0 in `obsidian-kit/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and a `CHANGELOG.md` entry.
- Never edit `CATALOG.md`, `*/README.md`, or `site/data/plugins.json`. Run `./scripts/cicd.sh GEN`.
- Tests are plain `assert` scripts, run as `python3 <path>/test_x.py`, the same style as `test_lint.py`.
- Shell: `cd` is zoxide. Use absolute paths or `git -C`.

## Review Focus

1. The CLI reports a missing file as `Error: File "x" not found.` with exit 0. Expected: the script stops and names the file. Test: `test_common.py` `parse_cli_output` cases (Task 2).
2. Obsidian closed or CLI missing. Expected: one line, "Open Obsidian, then run again.", and exit 1 before any write. Test: `test_common.py` runs with an empty `PATH` (Task 2).
3. A tag-like string in a code block, in inline code, in a URL fragment, or as the prefix of a longer tag. Expected: untouched. Test: `test_rewrite.py` (Task 9).
4. A word that looks like hex (`facade`, `decade`) is a real tag. Expected: not flagged as false. Test: `test_classify.py` (Task 9).
5. A map rename whose target already exists, or a note under an excluded path. Expected: no rename proposed and no read. Test: `test_migrate.py` (Task 8).

---

## File map

```
obsidian-kit/                         (renamed from note-visualizer/)
├─ .claude-plugin/plugin.json          T1
├─ CHANGELOG.md  NOTICE                T1, T4
├─ hooks/hooks.json                    T3, T5, T7
├─ hooks/excali-lint.sh                T3
├─ hooks/session-primer.py (+ test)    T5
├─ hooks/remind-format.py              T7 (replaces remind-visualize.py)
├─ references/excali-{principles,kit,rubric}.md   T3
├─ references/note-formats.md          T7
├─ references/visual-patterns.md       (kept)
├─ scripts/common/{vault,obsidian_eval,note_text}.py + test_common.py   T2
├─ scripts/excalidraw/*                T3 (moved from vault)
├─ scripts/notes/{infer_type,check_note,migrate}.py + tests   T6, T8
├─ scripts/tags/{classify,rewrite,taxonomy,plan,apply}.py + tests   T9, T10
└─ skills/{create-excali,update-excali,format-note,migrate-notes,audit-tags,
          obsidian-markdown,obsidian-bases}/SKILL.md          T3, T4, T7, T8, T10
```

---

### Task 1: Rename the plugin and set version 1.0.0

**Files:**
- Rename: `note-visualizer/` → `obsidian-kit/`
- Modify: `obsidian-kit/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json:69-75`, `content/plugins.content.json:87-93`, `obsidian-kit/CHANGELOG.md`

**Interfaces:**
- Produces: plugin name `obsidian-kit`, source `./obsidian-kit`.

- [ ] **Step 1: Move the directory**

```bash
git -C /Users/williamhung/Projects/PersonalPlugins mv note-visualizer obsidian-kit
```

- [ ] **Step 2: Replace `obsidian-kit/.claude-plugin/plugin.json`**

```json
{
  "name": "obsidian-kit",
  "description": "Work in an Obsidian vault with Claude Code: Excalidraw drawings in a house style, fixed note formats by note-type, a tag audit with one approved plan, and an obsidian CLI primer.",
  "version": "1.0.0",
  "author": {
    "name": "William Hung"
  }
}
```

- [ ] **Step 3: Replace the `note-visualizer` entry in `.claude-plugin/marketplace.json`**

```json
    {
      "name": "obsidian-kit",
      "source": "./obsidian-kit",
      "description": "Work in an Obsidian vault with Claude Code: Excalidraw drawings in a house style, fixed note formats by note-type, a tag audit with one approved plan, and an obsidian CLI primer.",
      "version": "1.0.0",
      "strict": true
    },
```

- [ ] **Step 4: Replace the `note-visualizer` key in `content/plugins.content.json`**

```json
    "obsidian-kit": {
      "tagline": "One plugin for the vault: draw, format, tag",
      "summary": "Five commands. create-excali and update-excali build Excalidraw drawings through ExcalidrawAutomate, lint the geometry, and review the real PNG render. format-note writes and checks notes by their note-type (map, concept, takeaway, literature, fleeting) and keeps the ASCII-diagram and callout rules of the old visualize skill. migrate-notes sets note-type across a vault and renames map notes, as one approved plan. audit-tags finds false, duplicate, typo, and off-taxonomy tags and applies one approved rename plan with backups. A SessionStart hook primes Claude to treat the obsidian CLI as the source of truth. Vault opinions live in the vault file .obsidian-kit.json. No cross-plugin deps.",
      "category": "content",
      "dependsOn": [],
      "config": []
    },
```

- [ ] **Step 5: Add the changelog entry at the top of `obsidian-kit/CHANGELOG.md`, under the title**

```markdown
## 1.0.0 — 2026-09-26

- **feat:** rename note-visualizer to obsidian-kit. The visualize skill becomes format-note.
- **feat:** add create-excali and update-excali, moved from the LifeOS vault skill excalidraw-refine.
- **feat:** add migrate-notes and audit-tags.
- **feat:** absorb obsidian-markdown and obsidian-bases from kepano/obsidian-skills (MIT).
- **feat:** add a SessionStart primer for the obsidian CLI and defuddle.
```

- [ ] **Step 6: Regenerate docs and make sure that they pass**

Run: `/Users/williamhung/Projects/PersonalPlugins/scripts/cicd.sh GEN && /Users/williamhung/Projects/PersonalPlugins/scripts/cicd.sh VERIFY`
Expected: GEN writes files. VERIFY passes. `obsidian-kit/README.md` exists.

- [ ] **Step 7: Commit**

```bash
git -C /Users/williamhung/Projects/PersonalPlugins add -A
git -C /Users/williamhung/Projects/PersonalPlugins commit -m "refactor: rename note-visualizer to obsidian-kit 1.0.0"
```

---

### Task 2: Shared vault and CLI helpers

**Files:**
- Create: `obsidian-kit/scripts/common/vault.py`, `obsidian-kit/scripts/common/obsidian_eval.py`, `obsidian-kit/scripts/common/note_text.py`
- Test: `obsidian-kit/scripts/common/test_common.py`

**Interfaces:**
- Produces:
  - `vault.VaultConfigError(RuntimeError)`
  - `vault.find_vault_root(start: Path) -> Path`
  - `vault.load_config(vault_root: Path) -> dict` (keys `taxonomyPath`, `noteFormatFolders`, `excludedPaths`, `typeFolders`)
  - `vault.is_under(path: str, folders: list[str]) -> bool`
  - `vault.is_excluded(path: str, config: dict) -> bool`
  - `vault.is_in_scope(path: str, config: dict) -> bool`
  - `vault.require_obsidian_running() -> None` (exits 1 with `OBSIDIAN_CLOSED_MESSAGE`)
  - `obsidian_eval.ObsidianCliError(RuntimeError)`
  - `obsidian_eval.parse_cli_output(stdout: str) -> str`
  - `obsidian_eval.run_cli(*args: str) -> str`
  - `obsidian_eval.run_app_script(js_body: str, args: dict) -> object`
  - `note_text.split_frontmatter(text: str) -> tuple[str, str]`
  - `note_text.read_property(frontmatter: str, key: str) -> str | None`
- Import pattern for other script folders: `sys.path.insert(0, str(Path(__file__).resolve().parents[1]))` then `from common.vault import ...`.

- [ ] **Step 1: Write the failing test `test_common.py`**

```python
"""Self-check for common helpers: python3 test_common.py"""
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.obsidian_eval import ObsidianCliError, parse_cli_output  # noqa: E402
from common.note_text import read_property, split_frontmatter  # noqa: E402
from common.vault import (VaultConfigError, find_vault_root, is_excluded,  # noqa: E402
                          is_in_scope, load_config)

CONFIG = {
    "taxonomyPath": "03Resource/About/tag-taxonomy.md",
    "noteFormatFolders": ["03Resource/Zettelkasten", "01Project/Leetcode"],
    "excludedPaths": ["03Resource/Credentials", "04Archive"],
    "typeFolders": {"03Resource/Zettelkasten/Permanent": "concept"},
}

# CLI output: exit code is 0 even on failure, so the text decides.
assert parse_cli_output("1.13.7 (installer 1.13.7)\n") == "1.13.7 (installer 1.13.7)"
try:
    parse_cli_output('Error: File "nope/missing.md" not found.\n')
    raise AssertionError("expected ObsidianCliError")
except ObsidianCliError as cli_error:
    assert "nope/missing.md" in str(cli_error)

# Scope and exclusion use folder boundaries, not string prefixes.
assert is_excluded("03Resource/Credentials/aws.md", CONFIG)
assert not is_excluded("03Resource/CredentialsGuide.md", CONFIG)
assert is_in_scope("03Resource/Zettelkasten/Permanent/a.md", CONFIG)
assert not is_in_scope("02Area/Journal/2026-09-26.md", CONFIG)

# Frontmatter split and property read.
note = "---\nnote-type: concept\ntags: [a]\n---\n#domain/llm\n\n## Title\n"
frontmatter, body = split_frontmatter(note)
assert frontmatter == "---\nnote-type: concept\ntags: [a]\n---\n"
assert body == "#domain/llm\n\n## Title\n"
assert read_property(frontmatter, "note-type") == "concept"
assert read_property(frontmatter, "type") is None
assert split_frontmatter("#tag\nbody") == ("", "#tag\nbody")

# Vault root and config loading.
with tempfile.TemporaryDirectory() as temp:
    vault_root = Path(temp)
    (vault_root / ".obsidian").mkdir()
    (vault_root / "a" / "b").mkdir(parents=True)
    assert find_vault_root(vault_root / "a" / "b") == vault_root
    try:
        load_config(vault_root)
        raise AssertionError("expected VaultConfigError for a missing config")
    except VaultConfigError as missing:
        assert ".obsidian-kit.json" in str(missing)
    (vault_root / ".obsidian-kit.json").write_text(json.dumps({"taxonomyPath": "t.md"}))
    try:
        load_config(vault_root)
        raise AssertionError("expected VaultConfigError for missing keys")
    except VaultConfigError as incomplete:
        assert "noteFormatFolders" in str(incomplete)

# Obsidian closed or CLI missing: one line, exit 1.
closed = subprocess.run(
    [sys.executable, "-c", "from common.vault import require_obsidian_running; require_obsidian_running()"],
    cwd=Path(__file__).resolve().parents[1], env={**os.environ, "PATH": ""}, capture_output=True, text=True,
)
assert closed.returncode == 1
assert closed.stderr.strip() == "Open Obsidian, then run again."

print("test_common: all passed")
```

- [ ] **Step 2: Run it to see it fail**

Run: `python3 /Users/williamhung/Projects/PersonalPlugins/obsidian-kit/scripts/common/test_common.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'common.obsidian_eval'`.

- [ ] **Step 3: Write `common/obsidian_eval.py`**

```python
"""Call the `obsidian` CLI. It exits 0 even on failure, so the output text decides."""
import json
import subprocess

CLI_TIMEOUT_SECONDS = 45
CLI_ERROR_PREFIX = "Error:"
EVAL_RESULT_PREFIX = "=> "


class ObsidianCliError(RuntimeError):
    pass


def parse_cli_output(stdout: str) -> str:
    output = stdout.strip()
    if output.startswith(CLI_ERROR_PREFIX):
        raise ObsidianCliError(output)
    return output


def run_cli(*args: str) -> str:
    try:
        completed = subprocess.run(["obsidian", *args], capture_output=True, text=True,
                                   timeout=CLI_TIMEOUT_SECONDS)
    except FileNotFoundError as missing_cli:
        raise ObsidianCliError("`obsidian` CLI not found on PATH") from missing_cli
    except subprocess.TimeoutExpired as timeout:
        raise ObsidianCliError(f"`obsidian {args[0]}` timed out after {CLI_TIMEOUT_SECONDS}s") from timeout
    if completed.returncode != 0:
        raise ObsidianCliError(completed.stderr.strip() or f"`obsidian {args[0]}` exited {completed.returncode}")
    return parse_cli_output(completed.stdout)


def run_app_script(js_body: str, args: dict) -> object:
    """Run `js_body` in the Obsidian window with `app` and `args` in scope. It must `return` JSON-able data."""
    wrapped_js = (
        "(async()=>{try{"
        f"const args={json.dumps(args)};"
        f"const result=await (async()=>{{{js_body}}})();"
        "return JSON.stringify({ok:true,result});"
        "}catch(e){return JSON.stringify({ok:false,error:String(e&&e.stack||e)});}})()"
    )
    output = run_cli("eval", f"code={wrapped_js}")
    result_lines = [line for line in output.splitlines() if line.startswith(EVAL_RESULT_PREFIX)]
    if not result_lines:
        raise ObsidianCliError(f"no result from `obsidian eval`: {output[-500:]}")
    payload = json.loads(result_lines[-1][len(EVAL_RESULT_PREFIX):])
    if not payload["ok"]:
        raise ObsidianCliError(payload["error"])
    return payload["result"]
```

- [ ] **Step 4: Write `common/note_text.py`**

```python
"""Split a note into frontmatter and body, and read one frontmatter property."""
import re

FRONTMATTER_OPEN = "---\n"
FRONTMATTER_CLOSE = "\n---\n"


def split_frontmatter(text: str) -> tuple[str, str]:
    if text.startswith(FRONTMATTER_OPEN):
        close_at = text.find(FRONTMATTER_CLOSE, len(FRONTMATTER_OPEN) - 1)
        if close_at != -1:
            body_start = close_at + len(FRONTMATTER_CLOSE)
            return text[:body_start], text[body_start:]
    return "", text


def read_property(frontmatter: str, key: str) -> str | None:
    match = re.search(rf"^{re.escape(key)}:[ \t]*(.*)$", frontmatter, re.MULTILINE)
    return match.group(1).strip() if match else None
```

- [ ] **Step 5: Write `common/vault.py`**

```python
"""Find the vault, load .obsidian-kit.json, and check that Obsidian is running."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.obsidian_eval import ObsidianCliError, run_cli  # noqa: E402

CONFIG_NAME = ".obsidian-kit.json"
REQUIRED_KEYS = ("taxonomyPath", "noteFormatFolders", "excludedPaths", "typeFolders")
OBSIDIAN_CLOSED_MESSAGE = "Open Obsidian, then run again."


class VaultConfigError(RuntimeError):
    pass


def find_vault_root(start: Path) -> Path:
    for folder in (start, *start.parents):
        if (folder / ".obsidian").is_dir():
            return folder
    raise VaultConfigError(f"no .obsidian/ folder at or above {start}")


def load_config(vault_root: Path) -> dict:
    config_path = vault_root / CONFIG_NAME
    if not config_path.is_file():
        raise VaultConfigError(f"create {config_path} first (see the spec's Vault config section)")
    config = json.loads(config_path.read_text(encoding="utf-8"))
    missing_keys = [key for key in REQUIRED_KEYS if key not in config]
    if missing_keys:
        raise VaultConfigError(f"{config_path} is missing keys: {', '.join(missing_keys)}")
    return config


def is_under(path: str, folders: list[str]) -> bool:
    return any(path == folder.rstrip("/") or path.startswith(folder.rstrip("/") + "/") for folder in folders)


def is_excluded(path: str, config: dict) -> bool:
    return is_under(path, config["excludedPaths"])


def is_in_scope(path: str, config: dict) -> bool:
    return is_under(path, config["noteFormatFolders"]) and not is_excluded(path, config)


def require_obsidian_running() -> None:
    try:
        run_cli("version")
    except ObsidianCliError:
        print(OBSIDIAN_CLOSED_MESSAGE, file=sys.stderr)
        sys.exit(1)
```

- [ ] **Step 6: Run the test to see it pass**

Run: `python3 /Users/williamhung/Projects/PersonalPlugins/obsidian-kit/scripts/common/test_common.py`
Expected: `test_common: all passed`

- [ ] **Step 7: Commit**

```bash
git -C /Users/williamhung/Projects/PersonalPlugins add obsidian-kit/scripts/common
git -C /Users/williamhung/Projects/PersonalPlugins commit -m "feat: add obsidian-kit vault and CLI helpers"
```

---

### Task 3: Move the Excalidraw skill, scripts, and hook

**Files:**
- Copy from `/Users/williamhung/Projects/LifeOS/03Resource/symlink/claude/`:
  - `scripts/excalidraw/{build,render,lint,ea_bridge,test_lint}.py`, `style_kit.js`, `style_kit_diagrams.js` → `obsidian-kit/scripts/excalidraw/` (no `__pycache__`)
  - `skills/excalidraw-refine/references/kit.md` → `obsidian-kit/references/excali-kit.md`
  - `skills/excalidraw-refine/references/rubric.md` → `obsidian-kit/references/excali-rubric.md`
  - `skills/excalidraw-refine/SKILL.md` lines 6-56 → `obsidian-kit/references/excali-principles.md`
  - `hooks/excalidraw-lint.sh` → `obsidian-kit/hooks/excali-lint.sh`
- Create: `obsidian-kit/skills/create-excali/SKILL.md`, `obsidian-kit/skills/update-excali/SKILL.md`
- Modify: `obsidian-kit/scripts/excalidraw/lint.py:1,200,229`, `obsidian-kit/hooks/hooks.json`

**Interfaces:**
- Consumes: nothing from Task 2. `ea_bridge.py` moves unchanged.
- Produces: `${CLAUDE_PLUGIN_ROOT}/scripts/excalidraw/{build,lint,render}.py` with the same CLI as today.

- [ ] **Step 1: Copy the files**

```bash
SRC=/Users/williamhung/Projects/LifeOS/03Resource/symlink/claude
DST=/Users/williamhung/Projects/PersonalPlugins/obsidian-kit
mkdir -p "$DST/scripts/excalidraw" "$DST/skills/create-excali" "$DST/skills/update-excali"
cp "$SRC"/scripts/excalidraw/{build,render,lint,ea_bridge,test_lint}.py "$SRC"/scripts/excalidraw/style_kit*.js "$DST/scripts/excalidraw/"
cp "$SRC/skills/excalidraw-refine/references/kit.md" "$DST/references/excali-kit.md"
cp "$SRC/skills/excalidraw-refine/references/rubric.md" "$DST/references/excali-rubric.md"
sed -n '6,56p' "$SRC/skills/excalidraw-refine/SKILL.md" > "$DST/references/excali-principles.md"
cp "$SRC/hooks/excalidraw-lint.sh" "$DST/hooks/excali-lint.sh"
```

- [ ] **Step 2: Run the moved lint test**

Run: `python3 /Users/williamhung/Projects/PersonalPlugins/obsidian-kit/scripts/excalidraw/test_lint.py`
Expected: the same pass output as in the vault. It needs no Obsidian.

- [ ] **Step 3: Fix the reference names in `lint.py`**

Replace `(excalidraw-refine skill)` on line 1 with `(obsidian-kit create-excali and update-excali)`. On lines 200 and 229, replace `references/rubric.md` with `references/excali-rubric.md`. Then change line 1 of `excali-principles.md` from `# excalidraw-refine` to `# Excalidraw principles`.

- [ ] **Step 4: Write `skills/create-excali/SKILL.md`**

```markdown
---
name: create-excali
description: Create a new Obsidian Excalidraw drawing in the vault house style, built with ExcalidrawAutomate in the running Obsidian app, then lint the geometry and look at the real PNG render. Trigger words are "excalidraw", "draw a diagram", "畫圖", and "畫一張". Also trigger it for any request that creates a .md drawing with `excalidraw-plugin:` frontmatter.
---

# create-excali

Read `${CLAUDE_PLUGIN_ROOT}/references/excali-principles.md` first. Every drawing follows it.

Scripts are in `${CLAUDE_PLUGIN_ROOT}/scripts/excalidraw/` (`$X` below). Run them from the
vault root. Obsidian must be open. Drawing paths are vault-relative.

1. **Plan.** Sketch the regions as an ASCII grid: region, column, heading, and role color.
   Check principle 1: one idea per region.
2. **Write the layout script** as a `.js` file in the scratchpad. `ea` and `kit` are in
   scope, `await` works, and the script must not call `ea.create`. Kit API:
   `${CLAUDE_PLUGIN_ROOT}/references/excali-kit.md`. Place every block from the returned
   sizes (`block.bottom + kit.TOKENS.blockGap`), never from guessed numbers.
3. **Build:** `python3 $X/build.py layout.js "<folder>/<name>.excalidraw.md"`. Never pass
   `--overwrite` here. If the file exists, pick another name or use update-excali.
4. **Lint:** `python3 $X/lint.py "<drawing>"`. Fix every `ERROR` in the layout script and
   rebuild with `--overwrite`, because Claude created this file in this session. Fix `WARN`
   lines unless the rubric says the case is intended.
5. **Look:** `python3 $X/render.py "<drawing>" <scratchpad>/<name>.png`, then Read the PNG.
   Score it with `${CLAUDE_PLUGIN_ROOT}/references/excali-rubric.md` as a strict reviewer.
   For each check, first look for its listed failure examples. If a check fails, fix the
   layout, rebuild, and render again. Stop at 10/10 or after 4 rounds. Report what still fails.

The excali-lint hook runs `lint.py` after each Write or Edit of a drawing and returns errors.
```

- [ ] **Step 5: Write `skills/update-excali/SKILL.md`**

```markdown
---
name: update-excali
description: Refine an existing Obsidian Excalidraw drawing into the vault house style, keeping every text, formula, relation, and element link, then lint and review the real PNG render. Trigger words are "refine this drawing", "整理這張 excalidraw", and "update the diagram". Also trigger it for any edit of a .md file with `excalidraw-plugin:` frontmatter, and when the excali-lint hook reports errors.
---

# update-excali

Read `${CLAUDE_PLUGIN_ROOT}/references/excali-principles.md` first.

Scripts are in `${CLAUDE_PLUGIN_ROOT}/scripts/excalidraw/` (`$X` below). Run them from the
vault root. Obsidian must be open. Drawing paths are vault-relative.

1. **Dump:** `python3 $X/lint.py "<drawing>" --dump` lists every element with its text,
   position, and link. Also render it (`python3 $X/render.py "<drawing>" <scratchpad>/before.png`)
   and look at it.
2. **Rewrite as a layout script.** Keep all content: every text, formula, relation, and
   element `link` such as `[[Note]]`. Set each link again with
   `ea.getElement(block.id).link = '[[Note]]'`. Change only the layout. Kit API:
   `${CLAUDE_PLUGIN_ROOT}/references/excali-kit.md`.
3. **Build to a draft path first:** `python3 $X/build.py layout.js "<folder>/<name>.draft.md"`.
4. **Lint and look** at the draft, as in create-excali steps 4 and 5.
5. **Replace.** If Claude did not create the original in this session, ask the user first.
   Then `python3 $X/build.py layout.js "<drawing>" --overwrite` (the old file goes to the
   system trash) and trash the draft with `obsidian delete path="<draft>"`.
```

- [ ] **Step 6: Point the hook at the plugin**

In `obsidian-kit/hooks/excali-lint.sh`, replace the block from `vault_root=` to `lint_script=` with:

```bash
vault_root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
[ -d "$vault_root/.obsidian" ] || exit 0
vault_relative_path="${file#"$vault_root"/}"
lint_script="${CLAUDE_PLUGIN_ROOT}/scripts/excalidraw/lint.py"
```

In the same file, replace each `skill excalidraw-refine` with `/obsidian-kit:update-excali` and `references/rubric.md` with `references/excali-rubric.md`. Replace the header comment's `excalidraw-refine geometry lint` with `obsidian-kit geometry lint`.

- [ ] **Step 7: Replace `obsidian-kit/hooks/hooks.json`**

```json
{
  "description": "obsidian-kit hooks: Excalidraw lint and the note-visualizer reminder.",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/remind-visualize.py",
            "timeout": 5
          },
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/excali-lint.sh",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 8: Check the hook skips non-vault projects**

Run: `printf '{"tool_input":{"file_path":"/tmp/x.md"}}' | CLAUDE_PROJECT_DIR=/tmp CLAUDE_PLUGIN_ROOT=/Users/williamhung/Projects/PersonalPlugins/obsidian-kit bash /Users/williamhung/Projects/PersonalPlugins/obsidian-kit/hooks/excali-lint.sh; echo "rc=$?"`
Expected: no output, `rc=0`.

- [ ] **Step 9: Commit**

```bash
git -C /Users/williamhung/Projects/PersonalPlugins add obsidian-kit
git -C /Users/williamhung/Projects/PersonalPlugins commit -m "feat: move excalidraw-refine into obsidian-kit as create-excali and update-excali"
```

---

### Task 4: Absorb kepano's markdown and bases skills

**Files:**
- Copy from `~/.claude/plugins/cache/obsidian-skills/obsidian/1.0.1/skills/`: `obsidian-markdown/` (with `references/`), `obsidian-bases/` (with `references/`) → `obsidian-kit/skills/`
- Create: `obsidian-kit/NOTICE`
- Modify: frontmatter of both copied `SKILL.md` files

- [ ] **Step 1: Copy**

```bash
KP=~/.claude/plugins/cache/obsidian-skills/obsidian/1.0.1
cp -R "$KP/skills/obsidian-markdown" "$KP/skills/obsidian-bases" /Users/williamhung/Projects/PersonalPlugins/obsidian-kit/skills/
```

- [ ] **Step 2: Hide both from the slash menu**

In each copied `SKILL.md`, add this line after the `description:` line:

```yaml
user-invocable: false
```

- [ ] **Step 3: Write `obsidian-kit/NOTICE`**

```text
skills/obsidian-markdown and skills/obsidian-bases come from
https://github.com/kepano/obsidian-skills (version 1.0.1), under the MIT License:

MIT License

Copyright (c) 2026 Steph Ango (@kepano)
```

Then append the rest of `$KP/LICENSE` from line 4 on: `sed -n '4,$p' "$KP/LICENSE" >> /Users/williamhung/Projects/PersonalPlugins/obsidian-kit/NOTICE`.

- [ ] **Step 4: Make sure that both are hidden**

Run: `grep -c "user-invocable: false" /Users/williamhung/Projects/PersonalPlugins/obsidian-kit/skills/obsidian-*/SKILL.md`
Expected: `1` for each file.

- [ ] **Step 5: Commit**

```bash
git -C /Users/williamhung/Projects/PersonalPlugins add obsidian-kit
git -C /Users/williamhung/Projects/PersonalPlugins commit -m "feat: absorb obsidian-markdown and obsidian-bases from kepano/obsidian-skills"
```

---

### Task 5: SessionStart primer hook

**Files:**
- Create: `obsidian-kit/hooks/session-primer.py`, `obsidian-kit/hooks/test_session_primer.py`
- Modify: `obsidian-kit/hooks/hooks.json`

**Interfaces:**
- Produces: if `<cwd>/.obsidian/` exists, stdout JSON `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": PRIMER}}`. Otherwise no output.

- [ ] **Step 1: Write the failing test**

```python
"""Self-check for session-primer.py: python3 test_session_primer.py"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

PRIMER_SCRIPT = Path(__file__).resolve().parent / "session-primer.py"


def run_primer(cwd: Path) -> str:
    completed = subprocess.run([sys.executable, str(PRIMER_SCRIPT)], input=json.dumps({"cwd": str(cwd)}),
                               capture_output=True, text=True, check=True)
    return completed.stdout


with tempfile.TemporaryDirectory() as temp:
    project = Path(temp)
    assert run_primer(project) == ""
    (project / ".obsidian").mkdir()
    context = json.loads(run_primer(project))["hookSpecificOutput"]
    assert context["hookEventName"] == "SessionStart"
    assert "obsidian help <cmd>" in context["additionalContext"]
    assert "defuddle parse <url> --md" in context["additionalContext"]

print("test_session_primer: all passed")
```

- [ ] **Step 2: Run it to see it fail**

Run: `python3 /Users/williamhung/Projects/PersonalPlugins/obsidian-kit/hooks/test_session_primer.py`
Expected: FAIL, `session-primer.py` does not exist.

- [ ] **Step 3: Write `hooks/session-primer.py`**

```python
#!/usr/bin/env python3
"""SessionStart: in an Obsidian vault, prime Claude to use the obsidian CLI as the source of truth."""
import json
import sys
from pathlib import Path

PRIMER = """This project is an Obsidian vault (obsidian-kit).
- The `obsidian` CLI is the source of truth for vault operations. If unsure or a command fails, run `obsidian help <cmd>`.
- It exits 0 even on failure: read the output for `Error:`.
- read: read, search, search:context, outline, links, backlinks, tags, properties
- write: create, append, prepend, property:set, property:remove
- organize: move, rename, delete (delete moves to trash; wikilinks auto-update)
- recover: history, history:read, history:restore, sync:history, sync:restore, diff
- inspect: orphans, deadends, unresolved, vault, file, wordcount
- develop: eval, dev:screenshot, dev:errors, dev:console, plugin:reload
- Before a bulk write, list the files you will change. Undo is `obsidian history:restore`.
- For a web page, prefer `defuddle parse <url> --md` over WebFetch (install: npm install -g defuddle)."""

try:
    working_directory = Path(json.load(sys.stdin).get("cwd", "."))
except (json.JSONDecodeError, AttributeError):
    sys.exit(0)

if (working_directory / ".obsidian").is_dir():
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": PRIMER}}))
```

- [ ] **Step 4: Run the test to see it pass**

Run: `python3 /Users/williamhung/Projects/PersonalPlugins/obsidian-kit/hooks/test_session_primer.py`
Expected: `test_session_primer: all passed`

- [ ] **Step 5: Add the SessionStart entry to `hooks/hooks.json`**

Add this key next to `"PostToolUse"` inside `"hooks"`:

```json
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/session-primer.py",
            "timeout": 5
          }
        ]
      }
    ],
```

Run: `python3 -m json.tool /Users/williamhung/Projects/PersonalPlugins/obsidian-kit/hooks/hooks.json > /dev/null && echo ok`
Expected: `ok`

- [ ] **Step 6: Commit**

```bash
git -C /Users/williamhung/Projects/PersonalPlugins add obsidian-kit/hooks
git -C /Users/williamhung/Projects/PersonalPlugins commit -m "feat: add obsidian-kit SessionStart primer for the obsidian CLI"
```

---

### Task 6: Note-type inference and format checker

**Files:**
- Create: `obsidian-kit/scripts/notes/infer_type.py`, `obsidian-kit/scripts/notes/check_note.py`
- Test: `obsidian-kit/scripts/notes/test_notes.py`

**Interfaces:**
- Consumes: `common.note_text.split_frontmatter`, `common.note_text.read_property`, `common.vault.*` (Task 2).
- Produces:
  - `infer_type.MAP_NAME: re.Pattern`, `infer_type.MAP_PREFIX = "00__map__"`
  - `infer_type.infer_type(path: str, sibling_names: set[str], type_folders: dict[str, str]) -> tuple[str | None, str]` returning `(note_type, rule)`. The rule is `map-name`, `numbered-with-map`, `folder:<folder>`, or `unmatched`
  - `check_note.check_note(note_type: str, file_name: str, text: str) -> list[str]` (empty list = passes)
  - CLI: `python3 check_note.py <vault-relative path or folder>`, run from the vault root. Exit codes: 0 all pass, 2 some fail.

- [ ] **Step 1: Write the failing test `test_notes.py`**

```python
"""Self-check for note-type inference and format checks: python3 test_notes.py"""
from check_note import check_note
from infer_type import infer_type

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
assert "missing Related:" in failures and "missing Sources:" in failures

TAKEAWAY = "---\nnote-type: takeaway\n---\n#lang/go\n\n## Title\n**Claim.**\n\n> [!example] From this session\n> x\n\nRelated: [[00__map__go]]\nSources: x\n"
assert check_note("takeaway", "31__x.md", TAKEAWAY) == []
assert "missing link back to the map" in check_note("takeaway", "31__x.md", TAKEAWAY.replace("[[00__map__go]]", "[[other]]"))

MAP = "---\nnote-type: map\n---\n#lang/go\n\n## Map\n**Claim.**\n\n```\na → b\n```\n- [[01__a]]: gloss\n"
assert check_note("map", "00__map__go.md", MAP) == []
assert "name must start with 00__map__" in check_note("map", "DP__MoC.md", MAP)

LITERATURE = "---\nnote-type: literature\n---\n#domain/psychology\n\n> Link: https://youtu.be/x\n\n# Title\n**Claim.**\n" + "- x\n" * 80
assert check_note("literature", "a.md", LITERATURE) == []
assert "missing > Link: <url>" in check_note("literature", "a.md", LITERATURE.replace("> Link: https://youtu.be/x", ""))

assert check_note("fleeting", "a.md", "---\nnote-type: fleeting\n---\n#x\n\n## Title\nanything\n") == []

print("test_notes: all passed")
```

- [ ] **Step 2: Run it to see it fail**

Run: `python3 /Users/williamhung/Projects/PersonalPlugins/obsidian-kit/scripts/notes/test_notes.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'check_note'`.

- [ ] **Step 3: Write `notes/infer_type.py`**

```python
"""Infer a note's note-type from its name, its siblings, and the configured type folders."""
import re
from pathlib import PurePosixPath

MAP_PREFIX = "00__map__"
MAP_NAME = re.compile(r"^(00__map__.*|_index.*|.*__index|.*MOC.*|.*MoC.*)\.md$")
NUMBERED_NAME = re.compile(r"^\d{2}__.+\.md$")


def infer_type(path: str, sibling_names: set[str], type_folders: dict[str, str]) -> tuple[str | None, str]:
    file_name = PurePosixPath(path).name
    if MAP_NAME.match(file_name):
        return "map", "map-name"
    has_map_sibling = any(MAP_NAME.match(sibling) for sibling in sibling_names if sibling != file_name)
    if NUMBERED_NAME.match(file_name) and has_map_sibling:
        return "takeaway", "numbered-with-map"
    for folder, note_type in type_folders.items():
        if path.startswith(folder.rstrip("/") + "/"):
            return note_type, f"folder:{folder}"
    return None, "unmatched"
```

- [ ] **Step 4: Write `notes/check_note.py`**

```python
"""Check notes against their note-type format.

Usage (from the vault root): python3 check_note.py <vault-relative path or folder>
Exit 0 = all pass, 2 = some notes fail, 1 = could not run.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.note_text import read_property, split_frontmatter  # noqa: E402
from common.vault import VaultConfigError, find_vault_root, is_in_scope, load_config  # noqa: E402

ONE_SCREEN_LINES = 45
TAG_LINE = re.compile(r"^#[^\s#]")
TITLE_LINE = re.compile(r"^#{1,2} \S")
BOLD_CLAIM = re.compile(r"^\*\*.+\*\*")
FENCED_BLOCK = re.compile(r"^```", re.MULTILINE)
LITERATURE_LINK = re.compile(r"^> Link: https?://", re.MULTILINE)
SESSION_CALLOUT = "> [!example] From this session"
ONE_SCREEN_TYPES = {"concept", "takeaway"}
CLAIM_TYPES = {"map", "concept", "takeaway", "literature"}
RELATED_TYPES = {"concept", "takeaway"}


def check_note(note_type: str, file_name: str, text: str) -> list[str]:
    frontmatter, body = split_frontmatter(text)
    body_lines = body.strip("\n").split("\n")
    failures = []
    if read_property(frontmatter, "note-type") is None:
        failures.append("missing note-type property")
    if not TAG_LINE.match(body_lines[0]):
        failures.append("line 1 is not a tag line")
    if not any(TITLE_LINE.match(line) for line in body_lines):
        failures.append("missing # or ## title")
    if note_type in CLAIM_TYPES and not any(BOLD_CLAIM.match(line) for line in body_lines):
        failures.append("missing bold one-sentence claim")
    if note_type in ONE_SCREEN_TYPES and len(body_lines) > ONE_SCREEN_LINES:
        failures.append(f"over one screen: {len(body_lines)} lines > {ONE_SCREEN_LINES}")
    if note_type in RELATED_TYPES:
        failures += [f"missing {label}" for label in ("Related:", "Sources:") if label not in body]
    if note_type == "takeaway":
        if SESSION_CALLOUT not in body:
            failures.append(f"missing {SESSION_CALLOUT}")
        if "[[00__map__" not in body:
            failures.append("missing link back to the map")
    if note_type == "map":
        if not file_name.startswith("00__map__"):
            failures.append("name must start with 00__map__")
        if not FENCED_BLOCK.search(body):
            failures.append("missing overview diagram")
        if "[[" not in body:
            failures.append("missing ordered [[links]]")
    if note_type == "literature" and not LITERATURE_LINK.search(body):
        failures.append("missing > Link: <url>")
    return failures


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 1
    try:
        vault_root = find_vault_root(Path.cwd())
        config = load_config(vault_root)
    except VaultConfigError as config_error:
        print(config_error, file=sys.stderr)
        return 1
    target = vault_root / sys.argv[1]
    notes = sorted(target.rglob("*.md")) if target.is_dir() else [target]
    failing_count = 0
    for note in notes:
        relative_path = note.relative_to(vault_root).as_posix()
        if not is_in_scope(relative_path, config):
            continue
        text = note.read_text(encoding="utf-8")
        note_type = read_property(split_frontmatter(text)[0], "note-type")
        if note_type is None:
            print(f"{relative_path}\tunset note-type (run /obsidian-kit:migrate-notes)")
            failing_count += 1
            continue
        failures = check_note(note_type, note.name, text)
        if failures:
            failing_count += 1
            print(f"{relative_path}\t{note_type}\t" + "; ".join(failures))
    print(f"{failing_count} of {len(notes)} notes fail")
    return 2 if failing_count else 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: Run the test to see it pass**

Run: `python3 /Users/williamhung/Projects/PersonalPlugins/obsidian-kit/scripts/notes/test_notes.py`
Expected: `test_notes: all passed`

- [ ] **Step 6: Commit**

```bash
git -C /Users/williamhung/Projects/PersonalPlugins add obsidian-kit/scripts/notes
git -C /Users/williamhung/Projects/PersonalPlugins commit -m "feat: add note-type inference and format checker"
```

---

### Task 7: format-note skill, formats reference, and reminder hook

**Files:**
- Create: `obsidian-kit/skills/format-note/SKILL.md`, `obsidian-kit/references/note-formats.md`, `obsidian-kit/hooks/remind-format.py`
- Delete: `obsidian-kit/skills/visualize/`, `obsidian-kit/hooks/remind-visualize.py`
- Modify: `obsidian-kit/hooks/hooks.json`

**Interfaces:**
- Consumes: `check_note.py` CLI (Task 6), `common.vault` (Task 2).

- [ ] **Step 1: Write `references/note-formats.md`**

````markdown
# Note formats by note-type

Every in-scope note has `note-type:` in frontmatter and inline tags from the taxonomy
on line 1 of the body. Tags come only from the `## Allowed` table of the taxonomy file
(`taxonomyPath` in `.obsidian-kit.json`). If no tag fits, propose one and ask the user.

## map

Name: `00__map__<series-folder-name>.md`, inside the series folder.

```
#tag/a #tag/b

## <Topic>: learning path
**One sentence: what the series explains and why.**

<fenced ASCII overview of the sections>

**0: <section name>**
- [[01__first__note]]: one-line gloss.
- [[02__second__note]]: one-line gloss.
```

## concept

Any name. One screen: 45 body lines at most.

```
#tag/a

## <Title>
**One-sentence claim.**

<fenced ASCII diagram, only if the idea has shape>

- bullet
- bullet

Related: [[Other Note]]
Sources: [name](url)
```

## takeaway

Name: `NN__<slug>.md`. Tens are the section and units are the step. Same body and
budget as concept, plus:

```
> [!example] From this session
> What happened in the session that taught this.
```

`Related:` links back to the series map `[[00__map__<series>]]`.

## literature

Any name. No line budget.

```
#tag/a

> Link: https://source

# <Title>
**One-sentence claim.**

free notes
```

For a web page source, get the body with `defuddle parse <url> --md`, then trim it.

## fleeting

Tags on line 1 and a title. Anything goes below.
````

- [ ] **Step 2: Write `skills/format-note/SKILL.md`**

It keeps the old visualize skill's diagram rules by pointing at `visual-patterns.md`.

```markdown
---
name: format-note
description: Write or check Obsidian notes by their note-type (map, concept, takeaway, literature, fleeting) so each type has one fixed format, with compact ASCII diagrams and callouts that make notes scannable. Use proactively when creating or editing a note inside the vault's noteFormatFolders, such as Zettelkasten notes. Also trigger on "format note", "check note format", "visualize", "add diagrams", "加圖", "refine notes", or "make scannable".
argument-hint: "[vault-relative path or folder]"
---

# format-note

Read `${CLAUDE_PLUGIN_ROOT}/references/note-formats.md` and
`${CLAUDE_PLUGIN_ROOT}/references/visual-patterns.md` first.

## Inline mode: while writing a note

1. Pick the note-type. The folder rules are in `.obsidian-kit.json` (`typeFolders`). A
   `00__map__` name is a map. A `NN__` name next to a map is a takeaway.
2. Write the note in that type's format and set `note-type:` in frontmatter.
3. Take tags only from the taxonomy file's `## Allowed` table. If none fits, propose a
   new tag and ask the user. Never add a tag silently.
4. For map, concept, and takeaway notes, apply visual-patterns: diagram before prose,
   at most one callout, and skip diagrams for flat or linear content.

## Check mode: `/obsidian-kit:format-note <path|folder>`

1. From the vault root, run
   `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/notes/check_note.py "<path|folder>"`.
2. Show the failing notes grouped by rule.
3. Propose the fixes for each note. Write only after the user approves.
4. A note with an unset note-type needs `/obsidian-kit:migrate-notes` first.
```

- [ ] **Step 3: Write `hooks/remind-format.py`**

```python
#!/usr/bin/env python3
"""PostToolUse: after a note inside noteFormatFolders is written, remind Claude of format-note."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from common.vault import VaultConfigError, find_vault_root, is_in_scope, load_config  # noqa: E402

REMINDER = ("This edit touched a note inside noteFormatFolders. Apply /obsidian-kit:format-note: "
            "keep its note-type format, take tags only from the taxonomy, and use compact ASCII "
            "diagrams (never Mermaid) for concepts with shape.")

try:
    file_path = Path(json.load(sys.stdin).get("tool_input", {}).get("file_path", ""))
except (json.JSONDecodeError, AttributeError):
    sys.exit(0)
if file_path.suffix != ".md" or not file_path.is_absolute():
    sys.exit(0)
try:
    vault_root = find_vault_root(file_path.parent)
    config = load_config(vault_root)
except VaultConfigError:
    sys.exit(0)
if is_in_scope(file_path.relative_to(vault_root).as_posix(), config):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": REMINDER}}))
```

- [ ] **Step 4: Swap the hook in `hooks/hooks.json`**

Replace `remind-visualize.py` with `remind-format.py` in the PostToolUse command, and set the `description` to `"obsidian-kit hooks: CLI primer, note-format reminder, Excalidraw lint."`. Then delete the old files:

```bash
git -C /Users/williamhung/Projects/PersonalPlugins rm -r obsidian-kit/skills/visualize obsidian-kit/hooks/remind-visualize.py
```

- [ ] **Step 5: Check the reminder in and out of scope**

```bash
V=$(mktemp -d); mkdir -p "$V/.obsidian" "$V/Z/P"
printf '{"taxonomyPath":"t.md","noteFormatFolders":["Z"],"excludedPaths":[],"typeFolders":{}}' > "$V/.obsidian-kit.json"
H=/Users/williamhung/Projects/PersonalPlugins/obsidian-kit/hooks/remind-format.py
printf '{"tool_input":{"file_path":"%s/Z/P/a.md"}}' "$V" | python3 "$H"
printf '{"tool_input":{"file_path":"%s/Other/a.md"}}' "$V" | python3 "$H"; echo "[end]"
```

Expected: one JSON line with `format-note`, then `[end]` with nothing before it for the second call.

- [ ] **Step 6: Commit**

```bash
git -C /Users/williamhung/Projects/PersonalPlugins add -A obsidian-kit
git -C /Users/williamhung/Projects/PersonalPlugins commit -m "feat: replace visualize with format-note and its reminder hook"
```

---

### Task 8: migrate-notes

**Files:**
- Create: `obsidian-kit/scripts/notes/migrate.py`, `obsidian-kit/skills/migrate-notes/SKILL.md`
- Test: `obsidian-kit/scripts/notes/test_migrate.py`

**Interfaces:**
- Consumes: `infer_type.infer_type`, `infer_type.MAP_NAME`, `infer_type.MAP_PREFIX` (Task 6); `common.*` (Task 2).
- Produces:
  - `migrate.collect_notes(vault_root: Path, config: dict) -> list[str]` (vault-relative, sorted, in scope, not drawings, no `note-type` yet)
  - `migrate.build_rows(note_paths: list[str], existing_paths: set[str], type_folders: dict) -> list[dict]` with keys `path`, `note_type`, `rule`, `new_path`
  - CLI: `python3 migrate.py plan <work-dir>` writes `<work-dir>/migrate-plan.tsv`; `python3 migrate.py apply <work-dir>` applies it and writes `<work-dir>/migrate-log.md`

- [ ] **Step 1: Write the failing test**

```python
"""Self-check for migrate.py: python3 test_migrate.py"""
import tempfile
from pathlib import Path

from migrate import build_rows, collect_notes

TYPE_FOLDERS = {"Z/Literature": "literature"}

rows = {row["path"]: row for row in build_rows(
    ["Z/Literature/Go/_index.md", "Z/Literature/Go/01__a.md", "Z/Literature/Habits/原子習慣 MOC.md",
     "Z/Literature/Old/00__map__Old.md", "L/0796.__rotate.md"],
    existing_paths={"Z/Literature/Habits/00__map__Habits.md"}, type_folders=TYPE_FOLDERS)}
assert rows["Z/Literature/Go/_index.md"] == {
    "path": "Z/Literature/Go/_index.md", "note_type": "map", "rule": "map-name",
    "new_path": "Z/Literature/Go/00__map__Go.md"}
assert rows["Z/Literature/Go/01__a.md"]["note_type"] == "takeaway"
# The target exists, so no rename is proposed.
assert rows["Z/Literature/Habits/原子習慣 MOC.md"]["new_path"] == ""
assert rows["Z/Literature/Habits/原子習慣 MOC.md"]["rule"] == "map-name (rename target exists)"
# An already-correct map name is not renamed.
assert rows["Z/Literature/Old/00__map__Old.md"]["new_path"] == ""
assert rows["L/0796.__rotate.md"]["note_type"] == ""

with tempfile.TemporaryDirectory() as temp:
    vault_root = Path(temp)
    for relative_path, text in {
        "Z/a.md": "#x\n## A\n",
        "Z/typed.md": "---\nnote-type: concept\n---\n#x\n",
        "Z/drawing.md": "---\nexcalidraw-plugin: parsed\n---\n",
        "Z/Credentials/secret.md": "never read",
        "Journal/2026-09-26.md": "#daily\n",
    }.items():
        (vault_root / relative_path).parent.mkdir(parents=True, exist_ok=True)
        (vault_root / relative_path).write_text(text, encoding="utf-8")
    (vault_root / "Z/Credentials/secret.md").chmod(0)  # reading it would raise PermissionError
    config = {"noteFormatFolders": ["Z"], "excludedPaths": ["Z/Credentials"], "typeFolders": {}}
    assert collect_notes(vault_root, config) == ["Z/a.md"]
    (vault_root / "Z/Credentials/secret.md").chmod(0o600)

print("test_migrate: all passed")
```

- [ ] **Step 2: Run it to see it fail**

Run: `python3 /Users/williamhung/Projects/PersonalPlugins/obsidian-kit/scripts/notes/test_migrate.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'migrate'`.

- [ ] **Step 3: Write `notes/migrate.py`**

```python
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
```

- [ ] **Step 4: Run the test to see it pass**

Run: `python3 /Users/williamhung/Projects/PersonalPlugins/obsidian-kit/scripts/notes/test_migrate.py`
Expected: `test_migrate: all passed`

- [ ] **Step 5: Write `skills/migrate-notes/SKILL.md`**

```markdown
---
name: migrate-notes
description: One-time vault migration that sets the note-type property on every in-scope note and renames map notes to 00__map__<folder>.md, as one plan the user approves. Run only when the user invokes /obsidian-kit:migrate-notes.
disable-model-invocation: true
---

# migrate-notes

Run every command from the vault root. Obsidian must be open. `$N` is
`${CLAUDE_PLUGIN_ROOT}/scripts/notes`. `<work>` is a folder in the scratchpad.

1. **Plan:** `python3 $N/migrate.py plan <work>`. It writes `<work>/migrate-plan.tsv`.
2. **Show the plan** to the user: counts by note_type, every map rename, every
   `rename target exists` row, and every unset row. Ask the user to decide the unset
   rows: a type, or leave empty to skip.
3. Edit the TSV with the user's decisions. Do not apply until the user approves the
   whole plan once.
4. **Apply:** `python3 $N/migrate.py apply <work>`. `obsidian move` updates wikilinks.
5. Report the log path `<work>/migrate-log.md`. Each move line carries its undo command.
   If apply stops on an error, report the failing row and ask before running again.
```

- [ ] **Step 6: Commit**

```bash
git -C /Users/williamhung/Projects/PersonalPlugins add obsidian-kit/scripts/notes obsidian-kit/skills/migrate-notes
git -C /Users/williamhung/Projects/PersonalPlugins commit -m "feat: add migrate-notes for note-type and map renames"
```

---

### Task 9: Tag rules: classify, rewrite, taxonomy

**Files:**
- Create: `obsidian-kit/scripts/tags/classify.py`, `obsidian-kit/scripts/tags/rewrite.py`, `obsidian-kit/scripts/tags/taxonomy.py`
- Test: `obsidian-kit/scripts/tags/test_tags.py`

**Interfaces:**
- Produces:
  - `classify.is_false_tag(tag: str) -> bool` (tag without `#`)
  - `classify.is_allowed(tag: str, allowed: set[str]) -> bool` (an entry `lc/*` allows every `lc/...` tag)
  - `classify.classify(counts: dict[str, int], allowed: set[str], merged: dict[str, str]) -> list[dict]`, each `{"tag", "kind", "action", "new"}`; kind ∈ `false`, `merged-back`, `typo`, `duplicate`, `singleton`, `off-taxonomy`; action ∈ `code`, `rename`, `keep`
  - `rewrite.rewrite_body(body: str, renames: dict[str, str], false_tags: set[str]) -> str`
  - `taxonomy.parse_taxonomy(text: str) -> tuple[dict[str, str], dict[str, str]]` (allowed tag → meaning, merged old → new)
  - `taxonomy.add_rows(text: str, section: str, rows: list[list[str]]) -> str`

- [ ] **Step 1: Write the failing test `test_tags.py`**

```python
"""Self-check for tag rules: python3 test_tags.py"""
from classify import classify, is_allowed, is_false_tag
from rewrite import rewrite_body
from taxonomy import add_rows, parse_taxonomy

# False tags from the LifeOS scan: hex color, commit hash, Jira number, list marker.
for false_tag in ("0c8599", "4f67687", "13，我卻把", "1-", "3：IAInvLev", "124/126"):
    assert is_false_tag(false_tag), false_tag
for real_tag in ("facade", "decade", "domain/db", "中文/閱讀", "lang/go"):
    assert not is_false_tag(real_tag), real_tag

assert is_allowed("lc/topic/DP", {"lc/*"})
assert not is_allowed("lcx", {"lc/*"})

findings = {finding["tag"]: finding for finding in classify(
    {"0c8599": 1, "domain/db": 30, "domain/database": 32, "system-deisgn": 2, "system-design": 10,
     "old/tag": 3, "domain/llm": 25, "one-off": 1, "lc/topic/DP": 26, "domain/os": 13},
    allowed={"domain/llm", "lc/*", "domain/os"}, merged={"old/tag": "new/tag"})}
assert findings["0c8599"] == {"tag": "0c8599", "kind": "false", "action": "code", "new": ""}
assert findings["old/tag"] == {"tag": "old/tag", "kind": "merged-back", "action": "rename", "new": "new/tag"}
assert findings["domain/db"] == {"tag": "domain/db", "kind": "duplicate", "action": "rename", "new": "domain/database"}
assert findings["domain/database"]["kind"] == "off-taxonomy"
assert findings["system-deisgn"] == {"tag": "system-deisgn", "kind": "typo", "action": "rename", "new": "system-design"}
assert findings["one-off"]["kind"] == "singleton" and findings["one-off"]["action"] == "keep"
assert "domain/llm" not in findings and "lc/topic/DP" not in findings
# Short tags are never typo candidates: db vs os is distance 2 but not a typo.
assert "domain/os" not in findings and findings["domain/db"]["kind"] != "typo"

body = "\n".join([
    "#domain/db #domain/db/query #domain/dbx",
    "color `#0c8599` and #0c8599, see https://x.com/a#0c8599",
    "```",
    "#domain/db stays in code",
    "```",
    "ticket #13，我卻把 done",
])
assert rewrite_body(body, {"domain/db": "domain/database"}, {"0c8599", "13，我卻把"}) == "\n".join([
    "#domain/database #domain/database/query #domain/dbx",
    "color `#0c8599` and `#0c8599`, see https://x.com/a#0c8599",
    "```",
    "#domain/db stays in code",
    "```",
    "ticket `#13，我卻把` done",
])
assert rewrite_body(body, {}, set()) == body

TAXONOMY = "# Tag taxonomy\n\n## Allowed\n\n| tag | meaning |\n|---|---|\n| `lc/*` | Leetcode |\n| `domain/llm` | LLMs |\n\n## Merged\n\n| old | new | date |\n|---|---|---|\n| `domain/db` | `domain/database` | 2026-09-26 |\n"
allowed, merged = parse_taxonomy(TAXONOMY)
assert allowed == {"lc/*": "Leetcode", "domain/llm": "LLMs"}
assert merged == {"domain/db": "domain/database"}
updated = add_rows(TAXONOMY, "Allowed", [["`domain/os`", ""]])
assert parse_taxonomy(updated)[0]["domain/os"] == ""
assert updated.index("`domain/os`") < updated.index("## Merged")

print("test_tags: all passed")
```

- [ ] **Step 2: Run it to see it fail**

Run: `python3 /Users/williamhung/Projects/PersonalPlugins/obsidian-kit/scripts/tags/test_tags.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'classify'`.

- [ ] **Step 3: Write `tags/classify.py`**

```python
"""Classify vault tags into false, merged-back, typo, duplicate, singleton, and off-taxonomy."""
import re

HEX_WITH_DIGIT = re.compile(r"^(?=.*\d)[0-9a-f]{6,7}$", re.IGNORECASE)
CJK_PUNCTUATION = re.compile(r"[，。、：；！？（）「」『』]")
TYPO_MAX_DISTANCE = 2
TYPO_MIN_LENGTH = 5
DUPLICATE_MIN_LEAF = 2


def is_false_tag(tag: str) -> bool:
    return tag[:1].isdigit() or bool(HEX_WITH_DIGIT.match(tag)) or bool(CJK_PUNCTUATION.search(tag))


def is_allowed(tag: str, allowed: set[str]) -> bool:
    if tag in allowed:
        return True
    parts = tag.split("/")
    return any("/".join(parts[:depth]) + "/*" in allowed for depth in range(1, len(parts)))


def edit_distance(first: str, second: str) -> int:
    previous_row = list(range(len(second) + 1))
    for row_index, first_char in enumerate(first, 1):
        current_row = [row_index]
        for column_index, second_char in enumerate(second, 1):
            current_row.append(min(previous_row[column_index] + 1, current_row[column_index - 1] + 1,
                                   previous_row[column_index - 1] + (first_char != second_char)))
        previous_row = current_row
    return previous_row[-1]


def find_typo_target(tag: str, candidates: list[str]) -> str | None:
    # Compare leaves under the same parent: "domain/db" vs "domain/os" differ by 2 but are not typos.
    parent, _, leaf = tag.rpartition("/")
    if len(leaf) < TYPO_MIN_LENGTH:
        return None
    for candidate in candidates:
        candidate_parent, _, candidate_leaf = candidate.rpartition("/")
        if candidate != tag and candidate_parent == parent and len(candidate_leaf) >= TYPO_MIN_LENGTH \
                and edit_distance(leaf, candidate_leaf) <= TYPO_MAX_DISTANCE:
            return candidate
    return None


def find_duplicate_target(tag: str, counts: dict[str, int]) -> str | None:
    parent, _, leaf = tag.rpartition("/")
    for other in sorted(counts):
        other_parent, _, other_leaf = other.rpartition("/")
        if other == tag or other_parent != parent or min(len(leaf), len(other_leaf)) < DUPLICATE_MIN_LEAF:
            continue
        if (other_leaf.startswith(leaf) or leaf.startswith(other_leaf)) and counts[other] > counts[tag]:
            return other
    return None


def finding(tag: str, kind: str, action: str, new: str = "") -> dict:
    return {"tag": tag, "kind": kind, "action": action, "new": new}


def classify(counts: dict[str, int], allowed: set[str], merged: dict[str, str]) -> list[dict]:
    plain_allowed = sorted(entry for entry in allowed if not entry.endswith("/*"))
    findings = []
    for tag in sorted(counts):
        if is_false_tag(tag):
            findings.append(finding(tag, "false", "code"))
            continue
        if tag in merged:
            findings.append(finding(tag, "merged-back", "rename", merged[tag]))
            continue
        if is_allowed(tag, allowed):
            continue
        more_used = [other for other in sorted(counts) if counts[other] > counts[tag] and not is_false_tag(other)]
        typo_target = find_typo_target(tag, plain_allowed + more_used)
        if typo_target:
            findings.append(finding(tag, "typo", "rename", typo_target))
            continue
        duplicate_target = find_duplicate_target(tag, counts)
        if duplicate_target:
            findings.append(finding(tag, "duplicate", "rename", duplicate_target))
            continue
        findings.append(finding(tag, "singleton" if counts[tag] == 1 else "off-taxonomy", "keep"))
    return findings
```

- [ ] **Step 4: Write `tags/rewrite.py`**

```python
"""Rewrite inline tags in a note body: rename tags and wrap false tags in backticks.

Fenced code blocks and inline code are never changed.
"""
import re

FENCE = re.compile(r"^\s*(```|~~~)")
INLINE_CODE = re.compile(r"(`+[^`]*`+)")
TAG_STOP_CHARS = r"\s,.;:!?\"'()\[\]{}<>"


def build_tag_pattern(tags: list[str]) -> re.Pattern:
    alternatives = "|".join(re.escape(tag) for tag in sorted(tags, key=len, reverse=True))
    return re.compile(rf"(?<![\w/#&])#(?P<tag>{alternatives})(?P<child>/[^{TAG_STOP_CHARS}]*)?(?=$|[{TAG_STOP_CHARS}])")


def rewrite_body(body: str, renames: dict[str, str], false_tags: set[str]) -> str:
    if not renames and not false_tags:
        return body
    tag_pattern = build_tag_pattern([*renames, *false_tags])

    def replace_tag(match: re.Match) -> str:
        tag, child = match["tag"], match["child"] or ""
        if tag in false_tags:
            return match[0] if child else f"`{match[0]}`"
        return f"#{renames[tag]}{child}"

    rewritten_lines = []
    inside_fence = False
    for line in body.split("\n"):
        if FENCE.match(line):
            inside_fence = not inside_fence
            rewritten_lines.append(line)
            continue
        if inside_fence:
            rewritten_lines.append(line)
            continue
        segments = INLINE_CODE.split(line)
        rewritten_lines.append("".join(segment if index % 2 else tag_pattern.sub(replace_tag, segment)
                                       for index, segment in enumerate(segments)))
    return "\n".join(rewritten_lines)
```

- [ ] **Step 5: Write `tags/taxonomy.py`**

```python
"""Read and extend the vault tag taxonomy file (## Allowed and ## Merged tables)."""
HEADER_FIRST_CELLS = {"tag", "old"}


def table_cells(line: str) -> list[str]:
    return [cell.strip().strip("`").lstrip("#") for cell in line.strip().strip("|").split("|")]


def is_separator(line: str) -> bool:
    return set(line.strip()) <= set("|-: ")


def parse_taxonomy(text: str) -> tuple[dict[str, str], dict[str, str]]:
    allowed, merged, section = {}, {}, ""
    for line in text.splitlines():
        if line.startswith("## "):
            section = line[3:].strip().lower()
            continue
        if not line.startswith("|") or is_separator(line):
            continue
        cells = table_cells(line)
        if cells[0] in HEADER_FIRST_CELLS:
            continue
        if section == "allowed":
            allowed[cells[0]] = cells[1] if len(cells) > 1 else ""
        elif section == "merged" and len(cells) >= 2:
            merged[cells[0]] = cells[1]
    return allowed, merged


def add_rows(text: str, section: str, rows: list[list[str]]) -> str:
    lines = text.split("\n")
    heading = f"## {section}".lower()
    section_start = next((index for index, line in enumerate(lines) if line.strip().lower() == heading), None)
    if section_start is None:
        raise ValueError(f"taxonomy file has no '## {section}' section")
    insert_at = section_start + 1
    for index in range(section_start + 1, len(lines)):
        if lines[index].startswith("## "):
            break
        if lines[index].startswith("|"):
            insert_at = index + 1
    new_lines = ["| " + " | ".join(row) + " |" for row in rows]
    return "\n".join(lines[:insert_at] + new_lines + lines[insert_at:])
```

- [ ] **Step 6: Run the test to see it pass**

Run: `python3 /Users/williamhung/Projects/PersonalPlugins/obsidian-kit/scripts/tags/test_tags.py`
Expected: `test_tags: all passed`

- [ ] **Step 7: Commit**

```bash
git -C /Users/williamhung/Projects/PersonalPlugins add obsidian-kit/scripts/tags
git -C /Users/williamhung/Projects/PersonalPlugins commit -m "feat: add tag classify, rewrite, and taxonomy rules"
```

---

### Task 10: audit-tags plan and apply

**Files:**
- Create: `obsidian-kit/scripts/tags/plan.py`, `obsidian-kit/scripts/tags/apply.py`, `obsidian-kit/skills/audit-tags/SKILL.md`
- Test: `obsidian-kit/scripts/tags/test_apply.py`

**Interfaces:**
- Consumes: Task 2 helpers, Task 9 functions.
- Produces:
  - `plan.py <work-dir>` writes `<work-dir>/inventory.json` (`{tag: [paths]}`) and `<work-dir>/tag-plan.tsv` (columns `old`, `kind`, `action`, `new`, `files`)
  - `apply.read_plan(plan_path: Path) -> tuple[dict[str, str], set[str], list[str]]` returning renames, false tags, kept tags
  - `apply.affected_paths(inventory: dict[str, list[str]], tags: list[str]) -> list[str]` (includes child tags)
  - `apply.py <work-dir>` backs up, rewrites frontmatter then body, updates the taxonomy, writes `<work-dir>/tag-log.md`

- [ ] **Step 1: Write the failing test**

```python
"""Self-check for apply.py plan parsing: python3 test_apply.py"""
import tempfile
from pathlib import Path

from apply import PlanError, affected_paths, read_plan

inventory = {"domain/db": ["a.md"], "domain/db/query": ["b.md"], "domain/dbx": ["c.md"], "0c8599": ["d.md"]}
assert affected_paths(inventory, ["domain/db"]) == ["a.md", "b.md"]
assert affected_paths(inventory, ["domain/db", "0c8599"]) == ["a.md", "b.md", "d.md"]

with tempfile.TemporaryDirectory() as temp:
    plan_path = Path(temp) / "tag-plan.tsv"
    plan_path.write_text("old\tkind\taction\tnew\tfiles\n"
                         "domain/db\tduplicate\trename\tdomain/database\t30\n"
                         "0c8599\tfalse\tcode\t\t1\n"
                         "one-off\tsingleton\tkeep\t\t1\n", encoding="utf-8")
    assert read_plan(plan_path) == ({"domain/db": "domain/database"}, {"0c8599"}, ["one-off"])
    plan_path.write_text("old\tkind\taction\tnew\tfiles\ndomain/db\tduplicate\trename\t\t30\n", encoding="utf-8")
    try:
        read_plan(plan_path)
        raise AssertionError("expected PlanError for a rename without a new tag")
    except PlanError as plan_error:
        assert "line 2" in str(plan_error)

print("test_apply: all passed")
```

- [ ] **Step 2: Run it to see it fail**

Run: `python3 /Users/williamhung/Projects/PersonalPlugins/obsidian-kit/scripts/tags/test_apply.py`
Expected: FAIL with `ModuleNotFoundError: No module named 'apply'`.

- [ ] **Step 3: Write `tags/plan.py`**

```python
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
from taxonomy import parse_taxonomy  # noqa: E402

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
        files_by_tag = run_app_script(SCAN_TAGS_JS, {"excluded": config["excludedPaths"]})
    except (VaultConfigError, ObsidianCliError) as setup_error:
        print(setup_error, file=sys.stderr)
        return 1
    allowed, merged = parse_taxonomy(taxonomy_path.read_text(encoding="utf-8"))
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
```

- [ ] **Step 4: Write `tags/apply.py`**

Frontmatter goes first through Obsidian. The body is rewritten after, from the file on disk. The reverse order would let Obsidian write back a stale body.

```python
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
from common.note_text import split_frontmatter  # noqa: E402
from common.obsidian_eval import ObsidianCliError, run_app_script  # noqa: E402
from common.vault import (VaultConfigError, find_vault_root, is_excluded,  # noqa: E402
                          load_config, require_obsidian_running)
from rewrite import rewrite_body  # noqa: E402
from taxonomy import add_rows, parse_taxonomy  # noqa: E402

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
for (const path of args.paths) {
  const file = app.vault.getAbstractFileByPath(path);
  if (!file) continue;
  await app.fileManager.processFrontMatter(file, (frontmatter) => {
    if (!frontmatter.tags) return;
    const before = (Array.isArray(frontmatter.tags) ? frontmatter.tags : String(frontmatter.tags).split(/[\\s,]+/))
      .filter(Boolean).map(tag => String(tag).replace(/^#/, ''));
    const after = [...new Set(before.filter(tag => !falseTags.has(tag)).map(renameTag))];
    if (JSON.stringify(before) !== JSON.stringify(after)) { frontmatter.tags = after; changed.push(path); }
  });
}
return changed;
"""


class PlanError(ValueError):
    pass


def read_plan(plan_path: Path) -> tuple[dict[str, str], set[str], list[str]]:
    renames, false_tags, kept = {}, set(), []
    with plan_path.open(encoding="utf-8") as plan_file:
        for line_number, row in enumerate(csv.DictReader(plan_file, delimiter="\t"), start=2):
            action, old_tag, new_tag = row["action"].strip(), row["old"].strip(), row["new"].strip()
            if action not in VALID_ACTIONS:
                raise PlanError(f"line {line_number}: action must be one of {sorted(VALID_ACTIONS)}")
            if action == "rename" and not new_tag:
                raise PlanError(f"line {line_number}: rename of {old_tag} needs a new tag")
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
    require_obsidian_running()
    work_dir = Path(sys.argv[1])
    try:
        vault_root = find_vault_root(Path.cwd())
        config = load_config(vault_root)
        renames, false_tags, kept = read_plan(work_dir / "tag-plan.tsv")
    except (VaultConfigError, PlanError) as setup_error:
        print(setup_error, file=sys.stderr)
        return 1
    inventory = json.loads((work_dir / "inventory.json").read_text(encoding="utf-8"))
    paths = [path for path in affected_paths(inventory, [*renames, *false_tags]) if not is_excluded(path, config)]

    backup_dir = work_dir / "backup"
    for path in paths:
        (backup_dir / path).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(vault_root / path, backup_dir / path)

    ordered_renames = sorted(renames.items(), key=lambda pair: len(pair[0]), reverse=True)
    try:
        frontmatter_changed = run_app_script(REWRITE_FRONTMATTER_JS, {
            "paths": paths, "renames": ordered_renames, "falseTags": sorted(false_tags)})
    except ObsidianCliError as cli_error:
        print(f"frontmatter step failed, no body changed: {cli_error}", file=sys.stderr)
        return 1

    body_changed = []
    for path in paths:
        note = vault_root / path
        frontmatter, body = split_frontmatter(note.read_text(encoding="utf-8"))
        new_body = rewrite_body(body, renames, false_tags)
        if new_body != body:
            note.write_text(frontmatter + new_body, encoding="utf-8")
            body_changed.append(path)

    update_taxonomy(vault_root / config["taxonomyPath"], renames, kept)
    log_lines = ["# audit-tags log", "", f"Backups: {backup_dir}", "",
                 "Undo one file: copy it back from the backup folder, or `obsidian history:restore path=<file> version=<n>`.", ""]
    log_lines += [f"- frontmatter: {path}" for path in frontmatter_changed]
    log_lines += [f"- body: {path}" for path in body_changed]
    (work_dir / "tag-log.md").write_text("\n".join(log_lines) + "\n", encoding="utf-8")
    print(f"changed {len(set(frontmatter_changed) | set(body_changed))} files; log at {work_dir / 'tag-log.md'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: Run the test to see it pass**

Run: `python3 /Users/williamhung/Projects/PersonalPlugins/obsidian-kit/scripts/tags/test_apply.py`
Expected: `test_apply: all passed`

- [ ] **Step 6: Write `skills/audit-tags/SKILL.md`**

```markdown
---
name: audit-tags
description: Audit the vault's tags against the approved taxonomy and apply one approved refactor plan. It finds false tags (hex colors, hashes, ticket numbers), merged tags that came back, typos, duplicates, singletons, and off-taxonomy tags. Run only when the user invokes /obsidian-kit:audit-tags.
disable-model-invocation: true
---

# audit-tags

Run every command from the vault root. Obsidian must be open. `$T` is
`${CLAUDE_PLUGIN_ROOT}/scripts/tags`. `<work>` is a folder in the scratchpad.

1. **Plan:** `python3 $T/plan.py <work>`. It writes `<work>/tag-plan.tsv` and
   `<work>/inventory.json`.
2. **Show the plan** grouped by kind: false, merged-back, typo, duplicate, then the
   singleton and off-taxonomy counts with the 20 most used off-taxonomy tags.
3. **Propose merges** for off-taxonomy tags that mean the same thing, for example two
   `domain/*` leaves for one topic. Put each proposal in the TSV as `rename` with its `new`
   tag. Every row ends as `rename`, `code`, or `keep`.
4. Get one approval for the whole plan. Do not apply before it.
5. **Apply:** `python3 $T/apply.py <work>`. It backs up every affected file to
   `<work>/backup/`, fixes frontmatter tags, then body tags, then adds new rows to the
   taxonomy file's `## Allowed` and `## Merged` tables.
6. Report the log `<work>/tag-log.md`, and ask the user to fill the empty `meaning`
   cells of new Allowed rows.
```

- [ ] **Step 7: Commit**

```bash
git -C /Users/williamhung/Projects/PersonalPlugins add obsidian-kit/scripts/tags obsidian-kit/skills/audit-tags
git -C /Users/williamhung/Projects/PersonalPlugins commit -m "feat: add audit-tags plan and apply"
```

---

### Task 11: Release checks

**Files:**
- Modify: none, unless a check fails.

- [ ] **Step 1: Run every test**

```bash
P=/Users/williamhung/Projects/PersonalPlugins/obsidian-kit
for test in scripts/common/test_common.py scripts/excalidraw/test_lint.py scripts/notes/test_notes.py \
            scripts/notes/test_migrate.py scripts/tags/test_tags.py scripts/tags/test_apply.py hooks/test_session_primer.py; do
  python3 "$P/$test" || echo "FAILED: $test"
done
```

Expected: 7 pass lines, no `FAILED`.

- [ ] **Step 2: Run the plugin-rules checklist**

Run: `grep -rn -e 'find ~/.claude/plugins' -e 'LifeOS' -e '03Resource' -e 'excalidraw-refine' -e 'note-visualizer' /Users/williamhung/Projects/PersonalPlugins/obsidian-kit --include='*.md' --include='*.py' --include='*.sh' --include='*.json' | grep -v CHANGELOG.md`
Expected: no output.

- [ ] **Step 3: Regenerate and verify docs**

Run: `/Users/williamhung/Projects/PersonalPlugins/scripts/cicd.sh GEN && /Users/williamhung/Projects/PersonalPlugins/scripts/cicd.sh VERIFY`
Expected: pass. `obsidian-kit/README.md` lists the 5 user commands.

- [ ] **Step 4: Commit the generated docs if they changed**

```bash
git -C /Users/williamhung/Projects/PersonalPlugins add -A
git -C /Users/williamhung/Projects/PersonalPlugins commit -m "docs: regenerate catalog for obsidian-kit"
```

---

### Task 12: Vault cutover (user-gated, run inline, not by a subagent)

Each step changes the LifeOS vault or the Claude Code install. Ask the user before each step.

- [ ] **Step 1: Install the plugin from the local branch**

Ask the user to run `/plugin marketplace update 21-breakincode`, then `/plugin install obsidian-kit@21-breakincode`, then restart Claude Code in the vault. The marketplace source must point at this branch or at the local directory. Confirm that with the user before the install.

- [ ] **Step 2: Create the vault config and taxonomy (approval required)**

Write `/Users/williamhung/Projects/LifeOS/.obsidian-kit.json` with the JSON from the spec's Vault config section. Write `/Users/williamhung/Projects/LifeOS/03Resource/About/tag-taxonomy.md`:

```markdown
# Tag taxonomy

Allowed tags for notes in the obsidian-kit noteFormatFolders. Leetcode tags follow
`.claude/rules/lc-tag-taxonomy.md`.

## Allowed

| tag | meaning |
|---|---|
| `lc/*` | Leetcode notes, see lc-tag-taxonomy.md |

## Merged

| old | new | date |
|---|---|---|
```

- [ ] **Step 3: Smoke test**

From the vault root:

1. `/obsidian-kit:create-excali` for a small two-box diagram at `03Resource/Assets/obsidian-kit-smoke.excalidraw.md`. Expected: build, lint, and render succeed.
2. `python3 <plugin-root>/scripts/tags/plan.py <scratchpad>/tags`. Expected: a plan with false tags such as `0c8599`. Do not apply.
3. `python3 <plugin-root>/scripts/notes/migrate.py plan <scratchpad>/migrate`. Expected: a plan with map renames. Do not apply.
4. Start a new session in the vault. Expected: the primer text is in context.
5. Ask before trashing the smoke drawing with `obsidian delete`.

- [ ] **Step 4: Remove the vault copies (approval required)**

Move to trash: `.claude/skills/excalidraw-refine`, `03Resource/symlink/claude/skills/excalidraw-refine/`, `03Resource/symlink/claude/scripts/excalidraw/`, `03Resource/symlink/claude/hooks/excalidraw-lint.sh`. Remove the excalidraw-lint entry from `.claude/settings.local.json`.

- [ ] **Step 5: Uninstall the replaced plugins (approval required)**

Ask the user to run `/plugin uninstall obsidian@obsidian-skills` and `/plugin uninstall note-visualizer@21-breakincode`.

- [ ] **Step 6: Update vault docs and memory (approval required)**

In `/Users/williamhung/Projects/LifeOS/CLAUDE.md`, change the task-routing row `| .base / .canvas / Obsidian-flavored markdown | skills \`obsidian:*\` |` to `| .base / Obsidian-flavored markdown / Excalidraw / tags | plugin \`obsidian-kit:*\` |`. Update the memory `excalidraw-refine-plugin-plan.md` to say the move is done.

- [ ] **Step 7: Run the real migrations only on the user's request**

`/obsidian-kit:migrate-notes` and `/obsidian-kit:audit-tags` are the user's next steps. They are not part of this plan.
