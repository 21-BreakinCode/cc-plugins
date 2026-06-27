#!/usr/bin/env bash
# Unified entry point for docs/catalog generation + verification.
# Local dev, the pre-commit hook, and GitHub Actions all call this the same way.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEN="$ROOT/scripts/generate-docs.mjs"

cmd="$(printf '%s' "${1:-help}" | tr '[:upper:]' '[:lower:]')"

run_gen()   { node "$GEN"; }
run_check() { node "$GEN" --check; }
run_test()  { node --test "$ROOT"/scripts/*.test.mjs; }

case "$cmd" in
  gen|generate|catalog) run_gen ;;
  check)                run_check ;;
  test)                 run_test ;;
  verify)               run_test; run_check ;;       # full CI gate
  serve)                cd "$ROOT/site" && python3 -m http.server "${2:-8000}" ;;
  help|-h|--help)
    cat <<'EOF'
usage: ./scripts/cicd.sh <command>

  gen | catalog   Regenerate CATALOG.md, per-plugin READMEs, and site/data/plugins.json
  check           Fail if any generated file is out of sync (used by CI + pre-commit)
  test            Run the generator unit tests
  verify          test + check — the full CI gate
  serve [port]    Preview the site locally (default port 8000)
EOF
    ;;
  *) echo "unknown command: '$cmd' (try: ./scripts/cicd.sh help)" >&2; exit 2 ;;
esac
