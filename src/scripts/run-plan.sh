#!/bin/bash
# run-plan.sh — Run only the Plan phase of a task.
#
# Thin wrapper around `run-task.sh --phase plan`. Useful when the full
# Plan→Develop→Review pipeline cannot fit inside Claude Code's 10-minute
# Bash tool timeout (divebase Task 52.1 was killed mid-run for this reason).
# The next call should be `run-develop.sh "$TASK"` or `run-task.sh --resume`.
exec "$(dirname "$0")/run-task.sh" --phase plan "$@"
