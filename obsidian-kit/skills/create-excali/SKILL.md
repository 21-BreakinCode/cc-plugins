---
name: create-excali
description: Create a new Obsidian Excalidraw drawing in the vault house style. Build it with ExcalidrawAutomate in the running Obsidian app. Then lint the geometry and look at the real PNG render. Trigger words are "excalidraw", "draw a diagram", "畫圖", and "畫一張". Also trigger it for any request that creates a .md drawing with `excalidraw-plugin:` frontmatter.
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
