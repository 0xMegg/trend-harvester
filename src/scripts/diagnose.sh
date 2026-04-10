#!/bin/bash
# Diagnose hardness-related failure states.
# Exit 0 = clean, 1 = issues found (details printed to stderr).
#
# Matches the 5 scenarios in docs/troubleshooting.md.

set -u

issues=0
note() { printf '[diagnose] %s\n' "$1" >&2; }
problem() {
  printf '[diagnose] ISSUE: %s\n' "$1" >&2
  issues=$((issues + 1))
}

# Resolve project root (script is in src/scripts/ or scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$SCRIPT_DIR/../harvest" ]; then
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [ -d "$SCRIPT_DIR/../../harvest" ]; then
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
else
  ROOT="$(pwd)"
fi
cd "$ROOT" || exit 0

PROJECT_NAME="${PROJECT_NAME:-$(basename "$ROOT")}"
TASK_STATUS="/tmp/${PROJECT_NAME}-run/task-status"
STALE_SECONDS=600

# 1. run-task.sh stale status
if [ -f "$TASK_STATUS" ]; then
  mtime=$(stat -f %m "$TASK_STATUS" 2>/dev/null || stat -c %Y "$TASK_STATUS" 2>/dev/null || echo 0)
  now=$(date +%s)
  age=$((now - mtime))
  if [ "$age" -gt "$STALE_SECONDS" ]; then
    problem "run-task.sh status stale (${age}s since last update): $TASK_STATUS — see troubleshooting.md §1"
  fi
fi

# 2. REQUEST_CHANGES loop — same task id with 2+ review files
if [ -d outputs/reviews ]; then
  loops=$(find outputs/reviews -maxdepth 1 -type f -name 'task-*-review.md' 2>/dev/null \
    | sed 's/.*task-\([0-9][0-9]*\).*/\1/' \
    | sort | uniq -c | awk '$1 > 1 {print $2}')
  if [ -n "$loops" ]; then
    problem "Reviewer loop detected for task(s): $(echo "$loops" | tr '\n' ' ')— see troubleshooting.md §2"
  fi
fi

# 3. Parallel slice residuals — worktrees and heavy stash
if command -v git >/dev/null 2>&1 && [ -d .git ]; then
  wt_count=$(git worktree list 2>/dev/null | wc -l | tr -d ' ')
  if [ "${wt_count:-0}" -gt 1 ]; then
    problem "residual git worktrees ($wt_count) — see troubleshooting.md §3"
  fi
  stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
  if [ "${stash_count:-0}" -gt 3 ]; then
    problem "high stash count ($stash_count) — see troubleshooting.md §3"
  fi
fi

# 4. Hook executability
if [ -d .claude/hooks ]; then
  for h in .claude/hooks/*.sh; do
    [ -f "$h" ] || continue
    if [ ! -x "$h" ]; then
      problem "hook not executable: $h — see troubleshooting.md §4"
    fi
  done
fi

# 5. Harvest lock staleness
if [ -f harvest/.lock ]; then
  lmtime=$(stat -f %m harvest/.lock 2>/dev/null || stat -c %Y harvest/.lock 2>/dev/null || echo 0)
  lnow=$(date +%s)
  lage=$((lnow - lmtime))
  if [ "$lage" -gt 3600 ]; then
    problem "harvest/.lock stale (${lage}s) — see troubleshooting.md §5"
  fi
fi

if [ "$issues" -eq 0 ]; then
  note "clean (5/5 checks pass)"
  exit 0
fi

note "$issues issue(s) found — see stderr messages above and docs/troubleshooting.md"
exit 1
