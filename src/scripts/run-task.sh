#!/bin/bash
# run-task.sh — Run Plan → Develop → Review in separate sessions
#
# Usage:
#   ./scripts/run-task.sh "Task 1 — 회원가입 폼 빈값 제출 버그 수정"
#   ./scripts/run-task.sh --max-iter 3 "Task 1 — 로그인 UI"
#
# Each phase runs as an independent claude -p session (clean context).
# With --max-iter N, Develop→Review loops up to N times on ITERATE verdict.
# Stops on failure. Logs saved to /tmp/{{PROJECT_NAME}}-run/

set -euo pipefail

# ============================================================
# Configuration — adjust for your project
# ============================================================
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_NAME="${PROJECT_NAME:-$(basename "$PROJECT_DIR")}"
LOG_DIR="${EPIC_LOG_DIR:-/tmp/${PROJECT_NAME}-run}"

# Optional: --task-id <id> for parallel execution isolation
TASK_ID=""
HANDOFF_FILE="handoff/latest.md"
if [ "${1:-}" = "--task-id" ] && [ -n "${2:-}" ]; then
  TASK_ID="$2"
  HANDOFF_FILE="handoff/task-${TASK_ID}.md"
  LOG_DIR="${LOG_DIR}/task-${TASK_ID}"
  shift 2
fi

# Optional: --no-commit to skip git commit/push in Review phase
# Used by run-epic.sh for parallel Stages (consolidated commit after Stage completes)
NO_COMMIT=false
if [ "${1:-}" = "--no-commit" ]; then
  NO_COMMIT=true
  shift
fi

# Optional: --max-iter N for iterative refinement loop (Develop→Review up to N times)
# On ITERATE verdict, the Developer refines and Reviewer re-evaluates.
# Default: 1 (no iteration — backward compatible)
MAX_ITER=1
if [ "${1:-}" = "--max-iter" ] && [ -n "${2:-}" ]; then
  MAX_ITER="$2"
  shift 2
fi

if ! [[ "$MAX_ITER" =~ ^[0-9]+$ ]] || [ "$MAX_ITER" -lt 1 ]; then
  echo "Error: --max-iter must be a positive integer (got: $MAX_ITER)"
  exit 1
fi

TASK="$*"

if [ -z "$TASK" ]; then
  echo "Usage: $0 [--task-id <id>] [--no-commit] [--max-iter N] <task description>"
  echo "Example: $0 Task 1 — 회원가입 폼 빈값 제출 버그 수정"
  echo "Example: $0 --task-id slice-1 Task 1 — 회원가입 폼"
  echo "Example: $0 --max-iter 3 Task 1 — 로그인 UI (iterate up to 3 times)"
  exit 1
fi

mkdir -p "$LOG_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================
# Helper functions
# ============================================================
log_phase() {
  echo ""
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo ""
}

log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_fail()    { echo -e "${RED}✗ $1${NC}"; }
log_warn()    { echo -e "${YELLOW}! $1${NC}"; }

run_claude() {
  local phase="$1"
  local command="$2"
  local log_file="${LOG_DIR}/${phase}.log"

  # When running in parallel (--task-id), override handoff file via prompt
  if [ -n "$TASK_ID" ]; then
    command="${command} (IMPORTANT: Use '${HANDOFF_FILE}' instead of 'handoff/latest.md' for all handoff reads and writes in this task.)"
  fi

  # When --no-commit is set, tell Reviewer not to git commit/push
  if [ "$NO_COMMIT" = true ] && [ "$phase" = "review" ]; then
    command="${command} (IMPORTANT: Do NOT run git commit or git push. Only write the review report and update the handoff file. Git will be handled by the orchestrator after all parallel slices complete.)"
  fi

  cd "$PROJECT_DIR"
  echo "Running: claude -p \"$command\""
  echo "Log: $log_file"
  echo ""

  if "$CLAUDE_BIN" -p "$command" \
    --output-format text \
    2>&1 | tee "$log_file"; then
    return 0
  else
    return 1
  fi
}

# ============================================================
# Phase 1: Plan
# ============================================================
log_phase "PHASE 1/3: PLAN"

if ! run_claude "plan" "/plan $TASK"; then
  log_fail "Plan phase failed. Check ${LOG_DIR}/plan.log"
  exit 1
fi

log_success "Plan phase complete"

# ============================================================
# Phase 2-3: Develop → Review (with iteration loop)
# ============================================================
ITER=1
VERDICT=""

while [ "$ITER" -le "$MAX_ITER" ]; do
  # --- Develop ---
  if [ "$ITER" -eq 1 ]; then
    log_phase "PHASE 2/3: DEVELOP"
    DEVELOP_PROMPT="/develop $TASK"
  else
    log_phase "ITERATION ${ITER}/${MAX_ITER}: DEVELOP (refinement)"
    DEVELOP_PROMPT="/develop $TASK — ITERATE 피드백 반영 (iteration ${ITER})"
  fi

  DEVELOP_LOG="${LOG_DIR}/develop-iter${ITER}.log"
  # Override log file for iteration tracking
  if ! run_claude "develop-iter${ITER}" "$DEVELOP_PROMPT"; then
    log_fail "Develop phase failed (iter ${ITER}). Check ${DEVELOP_LOG}"
    exit 1
  fi
  log_success "Develop phase complete (iter ${ITER})"

  # --- Review ---
  if [ "$ITER" -eq 1 ]; then
    log_phase "PHASE 3/3: REVIEW"
  else
    log_phase "ITERATION ${ITER}/${MAX_ITER}: REVIEW"
  fi

  REVIEW_LOG="${LOG_DIR}/review-iter${ITER}.log"
  if ! run_claude "review-iter${ITER}" "/review $TASK"; then
    log_fail "Review phase failed (iter ${ITER}). Check ${REVIEW_LOG}"
    exit 1
  fi

  # Check verdict
  if grep -qi "REQUEST_CHANGES\|request.changes" "$REVIEW_LOG" 2>/dev/null; then
    log_fail "Review verdict: REQUEST_CHANGES (iter ${ITER})"
    echo ""
    echo "Review output: $REVIEW_LOG"
    echo ""
    echo "Next steps:"
    echo "  1. Read the review: cat $REVIEW_LOG"
    echo "  2. Fix: /develop $TASK — REQUEST_CHANGES 수정"
    echo "  3. Re-review: /review $TASK"
    exit 1
  fi

  if grep -qi "ITERATE" "$REVIEW_LOG" 2>/dev/null; then
    if [ "$ITER" -lt "$MAX_ITER" ]; then
      log_warn "Review verdict: ITERATE (iter ${ITER}/${MAX_ITER}) — refining..."
      ITER=$((ITER + 1))
      continue
    else
      log_warn "Review verdict: ITERATE but max iterations reached (${MAX_ITER})"
      log_warn "Accepting current state. Manual refinement may be needed."
      VERDICT="ITERATE_EXHAUSTED"
      break
    fi
  fi

  if grep -qi "APPROVE" "$REVIEW_LOG" 2>/dev/null; then
    log_success "Review verdict: APPROVE (iter ${ITER})"
    VERDICT="APPROVE"
    break
  fi

  # No recognized verdict — treat as done
  log_warn "No clear verdict detected in review log"
  VERDICT="UNKNOWN"
  break
done

# ============================================================
# Done
# ============================================================
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}  TASK COMPLETE: $TASK${NC}"
if [ "$ITER" -gt 1 ]; then
  echo -e "${GREEN}  Iterations: ${ITER} (verdict: ${VERDICT})${NC}"
fi
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
if [ -n "$TASK_ID" ]; then
  echo "Logs: $LOG_DIR/ (task-id: $TASK_ID)"
else
  echo "Logs: $LOG_DIR/"
fi
