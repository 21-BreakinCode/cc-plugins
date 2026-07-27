---
name: adhd-review-mode
description: Use to toggle the adhd-review output style for the current session — turn ADHD-friendly, action-first, blocker-before-FYI reply shaping on or off. Triggers on "adhd mode", "review-ready output", "stop adhd mode" / "normal mode", or questions about the always-on flag or subagent safety.
---

# adhd-review-mode

Toggle the `adhd-review` output style for **this session** — the human-facing thread.

## Turn it ON

When the user asks for adhd mode / review-ready output:

1. Read the style at `${CLAUDE_PLUGIN_ROOT}/output-styles/adhd-review.md`.
2. Follow it for every reply for the rest of the session (Layer 1 always; Layer 2 on
   substantial multi-step wrap-ups).
3. Confirm in **exactly one line**, e.g.
   `adhd-review on — action-first replies, blockers before FYI.`

Built-in equivalent: the user can run `/output-style adhd-review` instead of this skill.

## Turn it OFF

On "stop adhd mode" / "normal mode": drop the style and reply `Back to normal.` in one line.

## Always-on (opt-in, survives across new sessions)

The style is per-session by default. To auto-apply it to **every new session**, flip a flag
file that a `SessionStart` hook watches:

- Enable:  `touch "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.adhd-review-always"`
- Disable: `rm "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.adhd-review-always"`

Without the flag, installing the plugin changes nothing. The hook injects the style into the
**main session only**.

## Why this is human-facing only (the load-bearing design)

These shaping rules are tuned for a **human** reader with limited attention. A **subagent** is
the opposite kind of reader: it starts from a fresh, isolated context and needs *more* detail,
not less. Compressing an agent-to-agent handoff into these buckets starves the next agent.

So the shaping must hit the human boundary and **never leak into subagent hops**. Two Claude
Code mechanics make that automatic:

- A subagent runs its **own** system prompt and does **not** inherit the main conversation's
  output style.
- `SessionStart` fires for the **main session only**; subagents don't inherit its injected
  context.

By contrast, `CLAUDE.md` and `~/.claude/rules/*.md` **are** inherited by subagents — which is
exactly why this shaping ships as an **output style + SessionStart hook**, not as CLAUDE.md
rules. Shipping it as a rule would leak the human-summary format into every subagent return.

Defense in depth: the style text opens with a scope guard telling any subagent that happens to
read it to stand down and return complete findings. The guard is the soft backstop behind the
hard mechanism.

## Verify it works

1. **Style applies (main thread).** After `/output-style adhd-review` (or this skill), replies
   lead with the next action, number multi-step work, and drop preamble/recap/closers. A
   substantial multi-step wrap-up renders ✅ / ⚠️ / 🙋 / 🤖 with blockers above FYI.
2. **Subagent isolation (the core check).** With the style active, delegate a task. The
   subagent's **return** should be full, unshaped findings — NOT the ✅/⚠️/🙋 buckets. Only the
   orchestrator's final message to you carries the buckets. Confirm via the subagent transcript
   (`/tasks`, or `~/.claude/projects/{project}/{sessionId}/subagents/agent-{id}.jsonl`).
3. **Always-on is opt-in.** With no flag file, a fresh session is not auto-shaped. After
   `touch ~/.claude/.adhd-review-always`, a new session starts shaped; after `rm`, it stops.
   Honors `$CLAUDE_CONFIG_DIR`.
4. **Hook is inert without the flag.** `scripts/session-start.sh` exits 0 and emits nothing when
   the flag is absent; emits the frontmatter-stripped style body when it's present.
