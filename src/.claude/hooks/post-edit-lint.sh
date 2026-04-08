#!/bin/bash
# Hook: Auto-run lint after file edits (PostToolUse)
#
# Auto-detects project type and runs the appropriate lint command.
# Only shows the last few lines to keep tool output budget small.
# Exit 0 always — lint failures are warnings, not blockers.

MAX_LINES=10

run_lint() {
  local cmd="$1"
  echo "--- auto-lint: $cmd ---"
  eval "$cmd" 2>&1 | tail -n "$MAX_LINES"
  local exit_code=${PIPESTATUS[0]}
  if [ $exit_code -ne 0 ]; then
    echo "⚠ lint exited with code $exit_code (showing last $MAX_LINES lines)"
  fi
}

# Detect project type and run lint
if [ -f "pubspec.yaml" ]; then
  run_lint "dart analyze --no-fatal-infos"
elif [ -f "package.json" ]; then
  if grep -q '"lint"' package.json 2>/dev/null; then
    run_lint "npm run lint"
  elif [ -f "node_modules/.bin/eslint" ]; then
    run_lint "npx eslint --quiet ."
  fi
elif [ -f "go.mod" ]; then
  run_lint "go vet ./..."
elif [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
  if command -v ruff &>/dev/null; then
    run_lint "ruff check ."
  elif command -v flake8 &>/dev/null; then
    run_lint "flake8 --max-line-length=120 ."
  fi
elif [ -f "Cargo.toml" ]; then
  run_lint "cargo clippy --quiet 2>&1"
fi

exit 0
