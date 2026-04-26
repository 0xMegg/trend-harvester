#!/bin/bash
# run-review.sh — Run only the Review phase of a task.
#
# Thin wrapper around `run-task.sh --phase review`. Assumes the working tree
# already carries the Develop output. Used to recover from a crash between
# Develop and Review (e.g. honbabseoul Epic 3 scope-leak grep regression
# blocked Review from launching despite Plan/Develop succeeding).
exec "$(dirname "$0")/run-task.sh" --phase review "$@"
