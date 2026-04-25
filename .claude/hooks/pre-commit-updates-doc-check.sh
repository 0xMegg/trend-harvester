#!/bin/bash
# pre-commit-updates-doc-check.sh — PreToolUse hook for Bash
# Blocks `git commit` when src/ changes are staged without anything staged
# under src/docs/updates/. Convention source: src/docs/updates/README.md.
#
# Called by Claude Code PreToolUse hook with $TOOL_INPUT as argument.
#
# Escape hatch: HARNESS_SKIP_UPDATE_DOC_CHECK=1 on the Claude Code process env.
# Inline `HARNESS_SKIP_UPDATE_DOC_CHECK=1 git commit ...` does NOT work
# (PreToolUse reads parent env, not the inline command — same caveat as
# HARVEST_ALLOW_MAIN, see src/.claude/rules/base/git.md).

set -euo pipefail

TOOL_INPUT="${1:-}"

# Only fire on git commit
if ! echo "$TOOL_INPUT" | grep -qE '"command".*git commit'; then
  exit 0
fi

# Escape hatch
if [ "${HARNESS_SKIP_UPDATE_DOC_CHECK:-0}" = "1" ]; then
  exit 0
fi

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# Forge guard — only fire in the forge repo
if [ ! -d "$PROJECT_DIR/src/docs/updates" ]; then
  exit 0
fi

cd "$PROJECT_DIR"

# Staged src/ changes excluding src/docs/updates/
staged_src=$(git diff --cached --name-only -- 'src/' ':(exclude)src/docs/updates/' 2>/dev/null || true)

if [ -z "$staged_src" ]; then
  exit 0
fi

# Anything staged under src/docs/updates/ (new file or modify, INDEX.md included)
staged_updates=$(git diff --cached --name-only -- 'src/docs/updates/' 2>/dev/null || true)

if [ -n "$staged_updates" ]; then
  exit 0
fi

cat >&2 <<MSG

✗ pre-commit-updates-doc-check: src/ change without companion update doc

Staged src/ paths (outside src/docs/updates/):
$(echo "$staged_src" | sed 's/^/  /')

Convention (src/docs/updates/README.md):
  Any forge commit that modifies src/ must include
  src/docs/updates/<short-hash>.md + a new row in INDEX.md, in the same commit.

Resolve:
  1) Stage docs:  git add src/docs/updates/<hash>.md src/docs/updates/INDEX.md
  2) Or set HARNESS_SKIP_UPDATE_DOC_CHECK=1 on the Claude Code process env
     and restart (inline export does NOT work — same caveat as HARVEST_ALLOW_MAIN).

MSG

exit 1
