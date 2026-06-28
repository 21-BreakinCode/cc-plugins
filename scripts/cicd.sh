#!/usr/bin/env bash
# Unified entry point for docs/catalog generation + verification.
# Local dev, the pre-commit hook, and GitHub Actions all call this the same way.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEN="$ROOT/scripts/generate-docs.mjs"

cmd="$(printf '%s' "${1:-HELP}" | tr '[:lower:]' '[:upper:]')"

run_gen()   { node "$GEN"; }
run_check() { node "$GEN" --check; }
run_test()  { node --test "$ROOT"/scripts/*.test.mjs; }
run_serve() { cd "$ROOT/site" && python3 -m http.server "${1:-8000}"; }

# Regenerate, open the default browser, then serve the latest site.
run_preview() {
  local port="${1:-8000}" url
  run_gen
  url="http://localhost:${port}"
  echo "Opening ${url} (Ctrl-C to stop) …"
  ( sleep 1
    if   command -v open     >/dev/null 2>&1; then open "$url"
    elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$url"
    else echo "Open ${url} in your browser."; fi ) &
  run_serve "$port"
}

case "$cmd" in
  GEN|GENERATE|CATALOG) run_gen ;;
  CHECK)                run_check ;;
  TEST)                 run_test ;;
  VERIFY)               run_test; run_check ;;       # full CI gate
  SERVE)                run_serve "${2:-8000}" ;;
  PREVIEW)              run_preview "${2:-8000}" ;;
  HOOKS)                git -C "$ROOT" config core.hooksPath .githooks && echo "✓ pre-commit hook enabled (core.hooksPath=.githooks)" ;;
  HELP|-H|--HELP)
    cat <<'EOF'
usage: ./scripts/cicd.sh <COMMAND>

  GEN | CATALOG   Regenerate CATALOG.md, per-plugin READMEs, and site/data/plugins.json
  CHECK           Fail if any generated file is out of sync (used by CI + pre-commit)
  TEST            Run the generator unit tests
  VERIFY          TEST + CHECK — the full CI gate
  SERVE [PORT]    Serve the existing site locally (default port 8000)
  PREVIEW [PORT]  Regenerate, open your browser, and serve the site (default port 8000)
  HOOKS           Enable the repo's pre-commit hook (git config core.hooksPath .githooks)

Commands are case-insensitive — GEN and gen both work.
EOF
    ;;
  *) echo "unknown command: '$cmd' (try: ./scripts/cicd.sh HELP)" >&2; exit 2 ;;
esac
