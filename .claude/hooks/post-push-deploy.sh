#!/bin/bash
# post-push-deploy.sh — PostToolUse hook for Bash
# Triggers forge-deploy after a successful `git push` in the forge repo.
#
# Called by Claude Code PostToolUse hook with $TOOL_INPUT as argument.
# Only fires when the tool input contains "git push" (not git push --force etc.)

set -euo pipefail

# DEBUG: temporary diagnostic — remove after diagnosing $TOOL_INPUT placeholder issue
{
  echo "==== $(date -u +%FT%TZ) ===="
  echo "argv: [$*]"
  echo "argc: $#"
  echo "stdin-peek: $(timeout 1 cat 2>/dev/null || echo '(empty/timeout)')"
  echo "env-CLAUDE: $(env | grep -E '^(CLAUDE|HOOK|TOOL)' || echo '(none)')"
} >> /tmp/post-push-deploy.log 2>&1

TOOL_INPUT="${1:-}"
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# Only trigger on git push commands (not --force, which is denied)
if ! echo "$TOOL_INPUT" | grep -qE '"command".*git push'; then
  exit 0
fi

# Only trigger in forge repo (not template repo or other repos)
if [ ! -f "$PROJECT_DIR/scripts/forge-deploy.sh" ]; then
  exit 0
fi

# Run deploy pipeline (skip forge push — it just happened)
echo ""
echo "[post-push-deploy] Triggering template build + push..."
bash "$PROJECT_DIR/scripts/forge-deploy.sh" --skip-push 2>&1
