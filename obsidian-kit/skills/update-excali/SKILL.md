---
name: update-excali
description: Refine an existing Obsidian Excalidraw drawing into the vault house style. Keep every text, formula, relation, and element link. Then lint and review the real PNG render. Trigger words are "refine this drawing", "整理這張 excalidraw", and "update the diagram". When editing a .md file with `excalidraw-plugin:` frontmatter, or when the excali-lint hook reports errors, also trigger it.
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
5. **Replace.** Ask the user before this step, unless Claude created the original earlier in this session.
   Then `python3 $X/build.py layout.js "<drawing>" --overwrite` (the old file goes to the
   system trash) and trash the draft with `obsidian delete path="<draft>"`.
