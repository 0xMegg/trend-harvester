#!/bin/bash
# handoff-freshness-check.sh — SessionEnd hook
#
# Warns when HEAD commit is newer than handoff/latest.md mtime, i.e.
# post-task activities (PR merge, branch cleanup, upstream feedback,
# env setup) happened in this session but handoff was not updated.
# Addresses kody P1-4 / E10 "post-task handoff gap".
#
# Non-blocking: prints to stderr, always exits 0 so it does not
# interfere with SessionEnd flow.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
HANDOFF="$PROJECT_DIR/handoff/latest.md"

# No handoff (fresh install or not yet set up) — nothing to check
[ -f "$HANDOFF" ] || exit 0

# Not a git repo — skip
git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1 || exit 0

# No commits yet — skip
HEAD_TS=$(git -C "$PROJECT_DIR" log -1 --format=%at 2>/dev/null || echo "")
[ -n "$HEAD_TS" ] || exit 0

# handoff file mtime (Unix timestamp)
if [[ "$OSTYPE" == "darwin"* ]]; then
  HANDOFF_TS=$(stat -f %m "$HANDOFF")
else
  HANDOFF_TS=$(stat -c %Y "$HANDOFF")
fi

# 60s tolerance — Reviewer's APPROVE commit includes handoff; their
# mtimes may differ by a few seconds depending on commit granularity.
if [ "$HEAD_TS" -gt "$((HANDOFF_TS + 60))" ]; then
  cat >&2 <<EOF

⚠ handoff/latest.md may be stale
    HEAD commit:   $(date -r "$HEAD_TS" '+%Y-%m-%d %H:%M:%S')
    handoff mtime: $(date -r "$HANDOFF_TS" '+%Y-%m-%d %H:%M:%S')

  If post-task work happened after APPROVE (PR merge, branch cleanup,
  propagation to another repo, env setup, upstream feedback), append
  it to handoff/latest.md under a '## Post-task activities' section
  so the next session enters with accurate state.

EOF
fi
exit 0
