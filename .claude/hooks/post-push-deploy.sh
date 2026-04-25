#!/bin/bash
# post-push-deploy.sh — PostToolUse hook for Bash
# Triggers forge-deploy after a successful `git push` in the forge repo.
#
# Called by Claude Code PostToolUse hook with the JSON payload on stdin.
# Payload shape: {"hook_event_name":"PostToolUse","tool_name":"Bash",
#                 "tool_input":{"command":"..."},"tool_response":{...}, ...}

set -euo pipefail

# Read the hook payload from stdin (Claude Code standard).
# Fallback to $1 for legacy / manual invocation.
INPUT_JSON="$(cat 2>/dev/null || true)"
[ -z "$INPUT_JSON" ] && INPUT_JSON="${1:-}"

# Extract tool_input.command (prefer jq for correctness with multi-line commands).
if command -v jq >/dev/null 2>&1; then
  CMD=$(printf '%s' "$INPUT_JSON" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
else
  CMD=$(printf '%s' "$INPUT_JSON" | sed -n 's/.*"tool_input":{[^}]*"command":"\([^"]*\)".*/\1/p')
fi

# Only trigger on git push commands (not --force, which is denied at policy layer)
if ! echo "$CMD" | grep -q 'git push'; then
  exit 0
fi

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# Only trigger in forge repo (not template repo or other repos)
if [ ! -f "$PROJECT_DIR/scripts/forge-deploy.sh" ]; then
  exit 0
fi

# Run deploy pipeline (skip forge push — it just happened)
echo ""
echo "[post-push-deploy] Triggering template build + push..."
bash "$PROJECT_DIR/scripts/forge-deploy.sh" --skip-push 2>&1
