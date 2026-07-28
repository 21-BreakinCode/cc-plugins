#!/usr/bin/env bash
# Acceptance-criteria conformance harness for the adhd-review plugin.
#
# Simulates each AC situation (fresh install default-on, per-session disable,
# subagent-context guard, doc sync) and emits a machine-readable score line
# `ac_pass_rate: NN.N` that autoresearch's eval runner extracts, plus a
# per-check PASS/FAIL log for humans.
#
# Behavioral ACs that need a LIVE multi-agent session (real output-style
# application on the main thread, real subagent isolation) cannot be unit
# tested here — a platform guarantee, not our code. We assert their *evidence*:
# the style directives are present and the subagent stand-down guard is
# unambiguous. Those checks are tagged [proxy].
#
# Usage: bash adhd-review/tests/ac-eval.sh   (runnable from anywhere)
set -uo pipefail   # deliberately NOT -e: every check must run

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_DIR/.." && pwd)"
STYLE="$PLUGIN_DIR/output-styles/adhd-review.md"
SKILL="$PLUGIN_DIR/skills/adhd-review-mode/SKILL.md"
HOOK_JSON="$PLUGIN_DIR/hooks/hooks.json"
HOOK_SH="$PLUGIN_DIR/scripts/session-start.sh"
PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"
MARKET="$REPO_ROOT/.claude-plugin/marketplace.json"
CONTENT="$REPO_ROOT/content/plugins.content.json"

PASS=0; TOTAL=0
t() { # t "description" 'shell expression'
  local desc="$1" expr="$2"
  TOTAL=$((TOTAL + 1))
  if eval "$expr" >/dev/null 2>&1; then
    PASS=$((PASS + 1)); printf 'PASS  %s\n' "$desc"
  else
    printf 'FAIL  %s\n' "$desc"
  fi
}

# Run the hook with a given config dir, writing stdout to <outfile>.
# Returns the hook's exit code (a command-substitution subshell would swallow
# a global, so we write to a file and let `return` carry the code up).
run_hook() { # cfg outfile [extra VAR=val env assignments...]
  local cfg="$1" outfile="$2"; shift 2
  env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" CLAUDE_CONFIG_DIR="$cfg" "$@" bash "$HOOK_SH" >"$outfile" 2>/dev/null
  return $?
}

echo "── AC #1  structure ──────────────────────────────────────────"
t "plugin.json exists"                       "[ -f '$PLUGIN_JSON' ]"
t "output-styles/adhd-review.md exists"      "[ -f '$STYLE' ]"
t "skills/adhd-review-mode/SKILL.md exists"  "[ -f '$SKILL' ]"
t "hooks/hooks.json exists"                  "[ -f '$HOOK_JSON' ]"
t "scripts/session-start.sh exists"          "[ -f '$HOOK_SH' ]"
t "session-start.sh is executable"           "[ -x '$HOOK_SH' ]"
t "no per-plugin marketplace.json (repo has one)" "[ ! -f '$PLUGIN_DIR/.claude-plugin/marketplace.json' ]"

echo "── AC #2  strict validation ──────────────────────────────────"
if command -v claude >/dev/null 2>&1; then
  t "claude plugin validate --strict passes" "claude plugin validate '$PLUGIN_DIR' --strict"
else
  echo "SKIP  claude CLI not on PATH (validation not counted)"
fi

echo "── AC #4  Layer 1 per-reply shaping [proxy] ──────────────────"
t "L1: lead with action"        "grep -qi 'Lead with the answer or the next action' '$STYLE'"
t "L1: number multi-step work"  "grep -qi 'Number multi-step work' '$STYLE'"
t "L1: cut filler/preamble"     "grep -qi 'Cut filler' '$STYLE' && grep -qi 'preamble' '$STYLE'"
t "L1: matter-of-fact errors"   "grep -qi 'Errors are matter-of-fact' '$STYLE'"

echo "── AC #4  Layer 2 Review-Ready buckets [proxy] ───────────────"
t "L2: Done bucket ✅"           "grep -q '✅' '$STYLE'"
t "L2: Broken/Open bucket ⚠️"    "grep -q '⚠️' '$STYLE'"
t "L2: need-from-you bucket 🙋"  "grep -q '🙋' '$STYLE'"
t "L2: I'll-do bucket 🤖"        "grep -q '🤖' '$STYLE'"
t "L2: blockers before FYI (✅<⚠️<🙋<🤖 order)" '
  a=$(grep -n "✅" "'"$STYLE"'" | head -1 | cut -d: -f1)
  b=$(grep -n "⚠️" "'"$STYLE"'" | head -1 | cut -d: -f1)
  c=$(grep -n "🙋" "'"$STYLE"'" | head -1 | cut -d: -f1)
  d=$(grep -n "🤖" "'"$STYLE"'" | head -1 | cut -d: -f1)
  [ -n "$a" ] && [ -n "$b" ] && [ -n "$c" ] && [ -n "$d" ] &&
  [ "$a" -lt "$b" ] && [ "$b" -lt "$c" ] && [ "$c" -lt "$d" ]'
t "L2: has 'when NOT to apply' clause"  "grep -qi 'When NOT to' '$STYLE'"

echo "── AC  Visual Layer [proxy] ──────────────────────────────────"
t "VL: section present"                  "grep -qi 'Visual Layer' '$STYLE'"
t "VL: triggers on flow-shaped concepts" "grep -qi 'flow-shaped' '$STYLE'"
t "VL: fence-the-diagram rule"           "grep -qi 'fence' '$STYLE'"
t "VL: anti-noise (no diagram for linear/trivial)" "grep -qi 'diagram the linear or the trivial' '$STYLE'"

echo "── AC #7  subagent stand-down guard [proxy] ──────────────────"
t "guard: human-facing-thread-only scope"      "grep -qi 'human-facing thread only' '$STYLE'"
t "guard: tells subagent to ignore it"         "grep -qi 'you are a subagent' '$STYLE' && grep -qi 'ignore' '$STYLE'"
t "guard: demands complete/full-detail return" "grep -Eqi 'complete, full-detail|full-detail|complete findings' '$STYLE'"

echo "── AC #6/#8  hook situations (dynamic) ───────────────────────"
TMP="$(mktemp -d)"
mkdir -p "$TMP/cfg"

# Default (no disable var): on → emits the style body.
run_hook "$TMP/cfg" "$TMP/default.out"; rc_default=$?
# Disabled for the session: CLAUDE_ADHD_REVIEW=0 → silent no-op.
run_hook "$TMP/cfg" "$TMP/off.out" CLAUDE_ADHD_REVIEW=0; rc_off=$?

t "default (no var): emits body"                 "[ -s '$TMP/default.out' ]"
t "default (no var): exit 0"                      "[ '$rc_default' = 0 ]"
t "disabled (CLAUDE_ADHD_REVIEW=0): silent"       "[ ! -s '$TMP/off.out' ]"
t "disabled (CLAUDE_ADHD_REVIEW=0): exit 0"       "[ '$rc_off' = 0 ]"
# Frontmatter stripped: injected context must not carry the YAML meta lines.
t "frontmatter stripped from injected body" \
  "! head -1 '$TMP/default.out' | grep -qE '^(---|name:|description:)' && grep -q 'human-facing thread only' '$TMP/default.out'"
# Robustness: even active-by-default, an unset CLAUDE_PLUGIN_ROOT must stay a
# clean silent no-op — never a `set -u` abort. (Regression for the guard fix.)
env -u CLAUDE_PLUGIN_ROOT CLAUDE_CONFIG_DIR="$TMP/cfg" bash "$HOOK_SH" >"$TMP/noroot.out" 2>/dev/null
rc_noroot=$?
t "active but CLAUDE_PLUGIN_ROOT unset: silent + exit 0" \
  "[ ! -s '$TMP/noroot.out' ] && [ '$rc_noroot' = 0 ]"

echo "── plugin-rules compliance ───────────────────────────────────"
t "hook command uses \${CLAUDE_PLUGIN_ROOT}"   "grep -q 'CLAUDE_PLUGIN_ROOT' '$HOOK_JSON'"
# The forbidden needle is split so this harness never contains it contiguously
# (else a self-scan false-positives on the very check that enforces the rule).
needle='find ~/.claude/''plugins'
t "no plugin-dir find()-sourcing anywhere"      "! grep -rqF '$needle' '$PLUGIN_DIR'"
t "no hardcoded /Users absolute path in script" "! grep -q '/Users/' '$HOOK_SH'"
t "version lockstep (plugin.json == marketplace entry)" '
  pv=$(python3 -c "import json;print(json.load(open(\"'"$PLUGIN_JSON"'\"))[\"version\"])")
  mv=$(python3 -c "import json;d=json.load(open(\"'"$MARKET"'\"));print(next(p[\"version\"] for p in d[\"plugins\"] if p[\"name\"]==\"adhd-review\"))")
  [ -n "$pv" ] && [ "$pv" = "$mv" ]'
t "content/plugins.content.json has adhd-review entry" \
  "python3 -c \"import json,sys;d=json.load(open('$CONTENT'));sys.exit(0 if 'adhd-review' in d['plugins'] else 1)\""

echo "── generated docs in sync ────────────────────────────────────"
t "./scripts/cicd.sh CHECK passes" "( cd '$REPO_ROOT' && ./scripts/cicd.sh CHECK )"

echo "──────────────────────────────────────────────────────────────"
RATE="$(python3 -c "print(round(100*$PASS/$TOTAL, 1) if $TOTAL else 0.0)")"
echo "ac_passed: $PASS"
echo "ac_total: $TOTAL"
echo "ac_pass_rate: $RATE"
exit 0
