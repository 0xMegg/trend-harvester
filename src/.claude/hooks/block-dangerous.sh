#!/bin/bash
# Hook: Block dangerous commands before execution (PreToolUse)
#
# Blocks: rm -rf, git push --force, git reset --hard,
#         chmod 777, remote script piping, DROP TABLE, etc.

INPUT="$1"

DANGEROUS_PATTERNS=(
  "rm -rf /"
  "rm -rf \*"
  "rm -rf ."
  "git push --force"
  "git push -f "
  "git reset --hard"
  "git clean -fd"
  "chmod 777"
  "curl.*|.*bash"
  "curl.*|.*sh"
  "wget.*|.*bash"
  "wget.*|.*sh"
  "DROP TABLE"
  "DROP DATABASE"
  "truncate "
  "> /dev/sd"
  "mkfs\."
  ":(){ :|:& };:"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$INPUT" | grep -qiE "$pattern"; then
    echo "BLOCKED: Dangerous command detected matching pattern: $pattern"
    echo "Command: $INPUT"
    echo "Ask the user for explicit permission before running this command."
    exit 1
  fi
done

exit 0
