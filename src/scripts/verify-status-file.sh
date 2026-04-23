#!/bin/bash
# verify-status-file.sh — Regression test for E11/P0-6.
#
# write_status()/write_epic_status() must enforce single-line values
# so the status file stays `source`-able across repeated writes,
# including when TASK is a multiline markdown block.
#
# Exits 0 on pass, 1 on failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR="$(mktemp -d -t verify-status-file.XXXXXX)"

cleanup() { rm -rf "$TEST_DIR"; rm -rf /tmp/verify-status-file-run 2>/dev/null || true; }
trap cleanup EXIT

cp "$SCRIPT_DIR/run-task.sh" "$TEST_DIR/run-task.sh"

export PROJECT_NAME="verify-status-file"
export EPIC_LOG_DIR="/tmp/verify-status-file-run"
STATUS_FILE="/tmp/verify-status-file-run/task-status"

cd "$TEST_DIR"
git init -q
git config user.email test@test.com
git config user.name test

fail() { echo "FAIL: $1" >&2; exit 1; }

# ========================================================================
# Case 1 — single-line TASK: baseline
# ========================================================================
bash -euo pipefail run-task.sh --dry-run "Task 1 — single line" > /dev/null 2>&1 \
  || fail "case 1: dry-run exit non-zero on single-line TASK"
bash -c ". \"$STATUS_FILE\"" > /dev/null 2>&1 \
  || fail "case 1: status file not source-able after single-line TASK"

# ========================================================================
# Case 2 — multiline TASK with (parens) and backticks
# ========================================================================
# shellcheck disable=SC2016 # backticks are literal in the TASK string
MULTILINE_TASK="$(printf 'Line 1\nLine 2 with (parens)\nLine 3 with `backticks`')"
bash -euo pipefail run-task.sh --dry-run "$MULTILINE_TASK" > /dev/null 2>&1 \
  || fail "case 2: dry-run exit non-zero on multiline TASK"
bash -c ". \"$STATUS_FILE\"" > /dev/null 2>&1 \
  || fail "case 2: status file not source-able after multiline TASK"

# ========================================================================
# Case 3 — 5 repeated invocations, each with different multiline TASK
# ========================================================================
for i in 1 2 3 4 5; do
  TASK="$(printf "Task %d\nWith (parens)\nAnd backticks\nLine 4\nLine 5" "$i")"
  bash -euo pipefail run-task.sh --dry-run "$TASK" > /dev/null 2>&1 \
    || fail "case 3: run $i dry-run exit non-zero"
  bash -c ". \"$STATUS_FILE\"" > /dev/null 2>&1 \
    || fail "case 3: run $i status file not source-able"
done

# ========================================================================
# Case 4 — status file must not grow unbounded
# (multiline residue would add lines per invocation)
# ========================================================================
lines=$(wc -l < "$STATUS_FILE" | tr -d ' ')
if [ "$lines" -gt 20 ]; then
  fail "case 4: status file has $lines lines (expected ≤ 20, multiline leakage?)"
fi

# ========================================================================
# Case 5 — long value truncation
# ========================================================================
LONG=$(printf 'X%.0s' {1..200})
bash -euo pipefail run-task.sh --dry-run "$LONG" > /dev/null 2>&1 \
  || fail "case 5: dry-run exit non-zero on 200-char TASK"
bash -c ". \"$STATUS_FILE\"" > /dev/null 2>&1 \
  || fail "case 5: status file not source-able after long TASK"
grep -q "truncated" "$STATUS_FILE" \
  || fail "case 5: no truncation marker in status file (expected >120 char collapse)"

echo "verify-status-file: PASS (5 cases)"
