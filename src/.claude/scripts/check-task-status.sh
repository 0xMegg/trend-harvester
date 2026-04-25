#!/usr/bin/env bash
# Monitoring wrapper invoked every 60s from /task command.
# Replaces the inline `;`-separated bash that broke main-session permissions.
set -u
proj="${1:?usage: check-task-status.sh <PROJECT_NAME>}"
f="/tmp/${proj}-run/task-status"
if [ -f "$f" ]; then
  # shellcheck disable=SC1090  # status file path is computed at runtime
  ( . "$f"
    e=$(( $(date +%s) - ${START_EPOCH:-$(date +%s)} ))
    r="${ROLE:-?}"
    [ -n "${ITER:-}" ] && [ "${MAX_ITER:-1}" != "1" ] && r="$r(iter ${ITER}/${MAX_ITER})"
    printf "⏱ %dm%ds — %s" $((e/60)) $((e%60)) "$r"
    [ -n "${VERDICT:-}" ] && printf " [%s]" "$VERDICT"
    echo
  )
else
  echo "⏱ waiting for task to start..."
fi
