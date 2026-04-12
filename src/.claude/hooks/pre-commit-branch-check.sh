#!/bin/bash
# Hook: PreToolUse Bash — block `git commit` on protected branches.
#
# Protected branches: main, master, dev (dev is the staging branch — task
# branches are merged into it manually after review, never committed to
# directly).
#
# Exit 0: not a git commit, not on a protected branch, or bypass enabled → allow
# Exit 2: on a protected branch and attempting commit → block (Claude surfaces stderr)
#
# Bypass: HARVEST_ALLOW_MAIN=1 (emergency / template setup only — name kept
# for backwards compatibility; covers all protected branches).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

input="${1:-}"
if [ -z "$input" ]; then
  if [ -p /dev/stdin ] || [ ! -t 0 ]; then
    input=$(cat 2>/dev/null || true)
  fi
fi
[ -z "$input" ] && exit 0

# Extract the Bash command field (best-effort, no jq dep)
cmd=$(printf '%s' "$input" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -z "$cmd" ] && exit 0

# Fast exit unless this looks like a git commit
case "$cmd" in
  *"git commit"*|*"git  commit"*) ;;
  *) exit 0 ;;
esac

if [ "${HARVEST_ALLOW_MAIN:-0}" = "1" ]; then
  exit 0
fi

# Only enforce inside a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
case "$branch" in
  main|master|dev)
    printf '[branch-check] BLOCK: direct commit to "%s" is not allowed.\n' "$branch" >&2
    printf '[branch-check]   "%s" is a protected branch — task changes land here only via\n' "$branch" >&2
    printf '[branch-check]   manual merge of a reviewed task/* branch.\n' >&2
    printf '[branch-check]   Create a task branch first (run-task.sh handles this automatically).\n' >&2
    printf '[branch-check]   Emergency bypass: HARVEST_ALLOW_MAIN=1 git commit ...\n' >&2
    exit 2
    ;;
esac

exit 0
