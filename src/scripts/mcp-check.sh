#!/bin/bash
# mcp-check.sh — Validate project MCP server configuration.
#
# MCP servers live in `.mcp.json` at the project root (not in Claude Code
# settings.json — that schema doesn't allow server definitions). This script
# scans `.mcp.json` and enforces:
#   1. Each server has a `command` field
#   2. No inline secret literals (GitHub ghp_*/gho_*, OpenAI sk-*, Slack xoxb-*/xoxp-*,
#      Anthropic sk-ant-*, AWS AKIA[0-9A-Z]{16})
#   3. env values use ${VAR} placeholders (or reference $HOME / other env vars)
#   4. args do not include a bare "/" or "~" (scope too wide)
#
# Usage:
#   bash scripts/mcp-check.sh                # checks ./.mcp.json
#   bash scripts/mcp-check.sh path/to/x.json # checks a specific file
#
# Exit 0 = clean (including "no .mcp.json" — nothing to validate),
# Exit 1 = violations (details printed to stderr).
# Bypass: HARVEST_ALLOW_MCP_UNSAFE=1

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.mcp.json" ] || [ -f "$SCRIPT_DIR/../.mcp.json.example" ]; then
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [ -f "$SCRIPT_DIR/../../.mcp.json" ] || [ -f "$SCRIPT_DIR/../../.mcp.json.example" ]; then
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
else
  ROOT="$(pwd)"
fi

TARGET="${1:-$ROOT/.mcp.json}"
issues=0
note()    { printf '[mcp-check] %s\n' "$1" >&2; }
problem() { printf '[mcp-check] VIOLATION: %s\n' "$1" >&2; issues=$((issues + 1)); }

if [ ! -f "$TARGET" ]; then
  note "skip — no .mcp.json at $TARGET (copy .mcp.json.example to start)"
  exit 0
fi

if [ "${HARVEST_ALLOW_MCP_UNSAFE:-0}" = "1" ]; then
  note "HARVEST_ALLOW_MCP_UNSAFE=1 — skipping validation"
  exit 0
fi

# Best-effort extract mcpServers block without jq (portable)
# We work in two passes:
#   (a) isolate the mcpServers block text between its opening brace and its
#       matching closing brace,
#   (b) run pattern checks on that block.
mcp_block=$(awk '
  BEGIN { in_block = 0; depth = 0; buf = "" }
  {
    if (!in_block && $0 ~ /"mcpServers"[[:space:]]*:[[:space:]]*\{/) {
      in_block = 1
      # count braces on the opening line
      line = $0
      for (i = 1; i <= length(line); i++) {
        c = substr(line, i, 1)
        if (c == "{") depth++
        else if (c == "}") depth--
      }
      buf = line "\n"
      if (depth == 0) { print buf; exit }
      next
    }
    if (in_block) {
      buf = buf $0 "\n"
      line = $0
      for (i = 1; i <= length(line); i++) {
        c = substr(line, i, 1)
        if (c == "{") depth++
        else if (c == "}") depth--
      }
      if (depth == 0) { print buf; exit }
    }
  }
' "$TARGET")

if [ -z "$mcp_block" ]; then
  note "no mcpServers block — nothing to validate"
  exit 0
fi

# --- 2. Inline secret detection ---
# GitHub: ghp_, gho_, ghu_, ghs_, ghr_ followed by 20+ base62 chars
if echo "$mcp_block" | grep -qE '"(gh[poursa]_[A-Za-z0-9]{20,})"'; then
  problem "inline GitHub token literal detected (ghX_...)"
fi
# OpenAI: sk- followed by 20+ base62, excluding sk-ant
if echo "$mcp_block" | grep -qE '"sk-(proj-)?[A-Za-z0-9]{20,}"'; then
  problem "inline OpenAI-style token detected (sk-...)"
fi
# Anthropic
if echo "$mcp_block" | grep -qE '"sk-ant-[A-Za-z0-9_-]{20,}"'; then
  problem "inline Anthropic token detected (sk-ant-...)"
fi
# Slack
if echo "$mcp_block" | grep -qE '"xox[baprs]-[A-Za-z0-9-]{10,}"'; then
  problem "inline Slack token detected (xoxX-...)"
fi
# AWS access key
if echo "$mcp_block" | grep -qE '"AKIA[0-9A-Z]{16}"'; then
  problem "inline AWS access key detected (AKIA...)"
fi

# --- 3. env values should be ${VAR} placeholders ---
# Extract env object lines — any "KEY": "value" pair where value does not start with ${
# (heuristic: flag values that look like secrets but aren't ${...})
while IFS= read -r line; do
  # crude env line pattern inside an `env` block: "KEY": "value"
  value=$(echo "$line" | sed -n 's/.*"[A-Z_][A-Z0-9_]*"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  [ -z "$value" ] && continue
  # shellcheck disable=SC2016
  case "$value" in
    '${'*'}'|'$'*|'') ;;  # placeholder form literal match — OK
    *)
      # only flag values that look like credentials (long, no spaces, contains mixed case/digits)
      if [ "${#value}" -ge 16 ] && echo "$value" | grep -qE '^[A-Za-z0-9_/+=.-]+$'; then
        problem "env value looks like a literal credential: ${value:0:8}... (use \"\${VAR_NAME}\" instead)"
      fi
      ;;
  esac
done < <(echo "$mcp_block" | grep -E '"[A-Z_][A-Z0-9_]*"[[:space:]]*:[[:space:]]*"[^"]*"')

# --- 1. Each server entry has `command` ---
# Count servers (top-level keys inside mcpServers) and commands
server_count=$(echo "$mcp_block" | grep -cE '^[[:space:]]{4}"[A-Za-z][A-Za-z0-9_-]*"[[:space:]]*:[[:space:]]*\{')
command_count=$(echo "$mcp_block" | grep -cE '"command"[[:space:]]*:[[:space:]]*"[^"]+')
if [ "$server_count" -gt 0 ] && [ "$command_count" -lt "$server_count" ]; then
  problem "mcpServers entries missing \"command\" field (${command_count}/${server_count})"
fi

# --- 4. Overly wide scope in args ---
if echo "$mcp_block" | grep -qE '"args"[[:space:]]*:[[:space:]]*\[[^]]*"\s*/\s*"'; then
  problem "filesystem server args include bare \"/\" (scope too wide)"
fi
if echo "$mcp_block" | grep -qE '"args"[[:space:]]*:[[:space:]]*\[[^]]*"\s*~\s*"'; then
  problem "filesystem server args include bare \"~\" (scope too wide)"
fi

if [ "$issues" -eq 0 ]; then
  note "clean (${server_count} server(s) checked)"
  exit 0
fi

note "$issues violation(s) — fix mcpServers block or set HARVEST_ALLOW_MCP_UNSAFE=1 to bypass"
exit 1
