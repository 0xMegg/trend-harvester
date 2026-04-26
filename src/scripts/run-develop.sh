#!/bin/bash
# run-develop.sh — Run only the Develop phase of a task.
#
# Thin wrapper around `run-task.sh --phase develop`. Assumes a Plan artifact
# already exists at outputs/plans/task-N-plan.md (typically from a prior
# `run-plan.sh` call). Exits after Develop completes — Review must be run
# via `run-review.sh "$TASK"` or `run-task.sh --resume`.
exec "$(dirname "$0")/run-task.sh" --phase develop "$@"
