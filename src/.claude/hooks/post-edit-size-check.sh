#!/bin/bash
# Hook: Warn when an edited file exceeds the size budget defined in
# context/working-rules.md "파일 크기 상한".
#
# Warning only — never blocks. Use HARVEST_ALLOW_OVERSIZE=1 to silence.

set -u

input="${1:-}"
if [ -z "$input" ]; then
  if [ -p /dev/stdin ] || [ ! -t 0 ]; then
    input=$(cat 2>/dev/null || true)
  fi
fi
[ -z "$input" ] && exit 0

# Extract file_path from Write/Edit TOOL_INPUT JSON (best-effort, no jq dep)
file_path=$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -z "$file_path" ] && exit 0
[ -f "$file_path" ] || exit 0

if [ "${HARVEST_ALLOW_OVERSIZE:-0}" = "1" ]; then
  exit 0
fi

lines=$(wc -l < "$file_path" 2>/dev/null | tr -d ' ')
[ -z "$lines" ] && exit 0

limit=0
case "$file_path" in
  */context/decision-log.md) limit=0 ;;   # excluded by policy
  */CLAUDE.md)               limit=200 ;;
  */.claude/rules/*.md)      limit=50 ;;
  */context/*.md)            limit=150 ;;
esac

if [ "$limit" -gt 0 ] && [ "$lines" -gt "$limit" ]; then
  printf '[size-check] WARN: %s has %d lines (limit %d). See context/working-rules.md "파일 크기 상한".\n' \
    "$file_path" "$lines" "$limit" >&2
fi

exit 0
