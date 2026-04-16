#!/bin/bash
# epic-monitor.sh — Display epic progress from status files
#
# Usage:
#   ./scripts/epic-monitor.sh                # One-shot status check
#   ./scripts/epic-monitor.sh --loop [SEC]   # Loop mode (default: 45s)
#
# Reads epic-status and task-status files from /tmp/<project>-run/latest/
# and prints a compact progress line.

set -euo pipefail

# Determine log directory
PROJECT_NAME="${PROJECT_NAME:-$(basename "$(pwd)")}"
LOG_BASE="/tmp/${PROJECT_NAME}-run/latest"

# Parse args
LOOP=false
INTERVAL=45
if [ "${1:-}" = "--loop" ]; then
  LOOP=true
  [ -n "${2:-}" ] && INTERVAL="$2"
fi

print_status() {
  if [ ! -f "$LOG_BASE/epic-status" ]; then
    echo "⏱ waiting for epic to start..."
    return 1
  fi

  # Read epic-level status
  local epic_name="" stage="" stage_total=""
  # shellcheck source=/dev/null
  source "$LOG_BASE/epic-status" 2>/dev/null || true

  local elapsed=0
  if [ -n "${START_EPOCH:-}" ]; then
    elapsed=$(( $(date +%s) - START_EPOCH ))
  fi
  local mins=$((elapsed / 60))
  local secs=$((elapsed % 60))

  local line="⏱ ${mins}m${secs}s | ${EPIC_NAME:-${epic_name:-?}} | Stage ${STAGE:-${stage:-?}}/${STAGE_TOTAL:-${stage_total:-?}}"

  # Read task-slice statuses
  local tasks=""
  for d in "$LOG_BASE"/task-slice-*/; do
    [ -d "$d" ] || continue
    [ -f "$d/task-status" ] || continue
    local sname
    sname=$(basename "$d")
    local role="" verdict=""
    # shellcheck source=/dev/null
    source "$d/task-status" 2>/dev/null || true
    local r="${ROLE:-${role:-?}}"
    [ -n "${VERDICT:-${verdict:-}}" ] && r="${r}[${VERDICT:-${verdict}}]"
    tasks="${tasks} | ${sname}:${r}"
    # Reset for next iteration
    unset ROLE VERDICT ITER 2>/dev/null || true
  done

  # Check for sequential task status
  if [ -f "$LOG_BASE/task-status" ]; then
    local role="" verdict="" task_index=""
    # shellcheck source=/dev/null
    source "$LOG_BASE/task-status" 2>/dev/null || true
    local r="${ROLE:-${role:-?}}"
    [ -n "${VERDICT:-${verdict:-}}" ] && r="${r}[${VERDICT:-${verdict}}]"
    local idx="${TASK_INDEX:-${task_index:-?}}"
    tasks="${tasks} | seq-${idx}:${r}"
  fi

  echo "${line}${tasks}"
}

if $LOOP; then
  while true; do
    print_status || true
    sleep "$INTERVAL"
  done
else
  print_status
fi
