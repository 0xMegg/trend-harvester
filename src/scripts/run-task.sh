#!/bin/bash
# run-task.sh — Run Plan → Develop → Review in separate sessions
#
# Usage:
#   ./scripts/run-task.sh "Task 1 — Fix empty form submission bug in signup"
#   ./scripts/run-task.sh --max-iter 3 "Task 1 — Login UI"
#   ./scripts/run-task.sh --dry-run "Task 1 — Smoke test"
#
# Each phase runs as an independent claude -p session (clean context).
# With --max-iter N, Develop→Review loops up to N times on ITERATE verdict.
# With --dry-run, claude -p is stubbed (no tokens spent) — used for
# smoke testing the orchestrator and status file protocol.
# Stops on failure. Logs saved to /tmp/{{PROJECT_NAME}}-run/

set -euo pipefail

# ============================================================
# Configuration — adjust for your project
# ============================================================
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_NAME="${PROJECT_NAME:-$(basename "$PROJECT_DIR")}"
LOG_DIR="${EPIC_LOG_DIR:-/tmp/${PROJECT_NAME}-run}"

# ============================================================
# Argument parsing (order-independent flags, then task description)
# ============================================================
TASK_ID=""
HANDOFF_FILE="handoff/latest.md"
NO_COMMIT=false
DRY_RUN=false
MAX_ITER=1

while [ $# -gt 0 ]; do
  case "${1:-}" in
    --task-id)
      TASK_ID="${2:-}"
      HANDOFF_FILE="handoff/task-${TASK_ID}.md"
      LOG_DIR="${LOG_DIR}/task-${TASK_ID}"
      shift 2
      ;;
    --no-commit)
      NO_COMMIT=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --max-iter)
      MAX_ITER="${2:-}"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

if ! [[ "$MAX_ITER" =~ ^[0-9]+$ ]] || [ "$MAX_ITER" -lt 1 ]; then
  echo "Error: --max-iter must be a positive integer (got: $MAX_ITER)"
  exit 1
fi

TASK="$*"

if [ -z "$TASK" ]; then
  echo "Usage: $0 [--task-id <id>] [--no-commit] [--dry-run] [--max-iter N] <task description>"
  echo "Example: $0 Task 1 — Fix empty form submission bug in signup"
  echo "Example: $0 --task-id slice-1 Task 1 — Signup form"
  echo "Example: $0 --max-iter 3 Task 1 — Login UI (iterate up to 3 times)"
  echo "Example: $0 --dry-run Task 1 — Smoke test (no tokens spent)"
  exit 1
fi

mkdir -p "$LOG_DIR"

# ============================================================
# Branch isolation — create task/{id} branch if on main/master
# (skipped when parent epic already set up branch via TASK_ID,
#  or during dry-run, or in non-git dirs, or when HARVEST_ALLOW_MAIN=1)
# ============================================================
TASK_BRANCH=""
ORIGINAL_BRANCH=""

_slugify_task() {
  local s="$1"
  printf '%s' "$s" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' \
    | cut -c1-40
}

setup_task_branch() {
  # Skip in dry-run, parallel mode (EPIC_NAME came from epic env), or bypass
  if [ "$DRY_RUN" = true ]; then return 0; fi
  if [ -n "${EPIC_NAME:-}" ]; then return 0; fi   # inherit epic branch
  if [ "${HARVEST_ALLOW_MAIN:-0}" = "1" ]; then return 0; fi
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then return 0; fi

  ORIGINAL_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
  case "$ORIGINAL_BRANCH" in
    main|master) ;;
    *) return 0 ;;   # already on a non-main branch, assume user set up
  esac

  # Refuse dirty worktree to avoid carrying unrelated changes
  if [ -n "$(git status --porcelain)" ]; then
    echo "ERROR: working tree dirty on $ORIGINAL_BRANCH — commit/stash first or set HARVEST_ALLOW_MAIN=1" >&2
    exit 1
  fi

  local slug_source="${TASK_ID:-$(_slugify_task "$TASK")}"
  TASK_BRANCH="task/${slug_source}"

  if git show-ref --verify --quiet "refs/heads/${TASK_BRANCH}"; then
    git checkout "$TASK_BRANCH" >/dev/null 2>&1
  else
    git checkout -b "$TASK_BRANCH" >/dev/null 2>&1
  fi
  echo "[branch] ${ORIGINAL_BRANCH} → ${TASK_BRANCH}"
}

finalize_task_branch() {
  # Called only on APPROVE. Pushes the task branch to origin and returns to
  # the original branch — does NOT merge to main or dev. The reviewer or user
  # is expected to merge the pushed task branch into `dev` manually after a
  # final visual review (and later promote `dev` → `main` as a release).
  #
  # Rationale: the auto-merge flow encouraged shipping unreviewed changes
  # straight to main. Push-only preserves the task branch as a review unit
  # while still landing the work on origin so it survives session resets.
  [ -z "$TASK_BRANCH" ] && return 0
  [ "$DRY_RUN" = true ] && return 0

  # Push the task branch to origin (preserve, do not merge)
  if git push -u origin "$TASK_BRANCH" >/dev/null 2>&1; then
    echo "[branch] pushed ${TASK_BRANCH} → origin (preserved for review)"
  else
    echo "WARN: failed to push ${TASK_BRANCH} to origin — push manually with:" >&2
    echo "  git push -u origin ${TASK_BRANCH}" >&2
  fi

  # Return to the original branch (typically main) but keep task branch alive
  if git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1; then
    echo "[branch] returned to ${ORIGINAL_BRANCH} (task branch ${TASK_BRANCH} preserved locally + on origin)"
  else
    echo "WARN: cannot return to $ORIGINAL_BRANCH — staying on $TASK_BRANCH" >&2
  fi

  echo "[branch] next step: review the task branch, then merge into dev manually:"
  echo "  git checkout dev && git merge --no-ff ${TASK_BRANCH} && git push"
  echo "  (or open a PR with: gh pr create --base dev --head ${TASK_BRANCH})"
}

# Create an evaluation stub for the just-finished task. Only fires when the
# task touched CODE (src/.claude/, src/scripts/, scripts/, src/context/) — pure
# META tasks (handoff/README/baseline/gitignore) are exempt per the working
# rules' Evaluation Loop policy. The Reviewer fills in the qualitative fields.
# See outputs/proposals/proposal-b-eval-enforcement-dry-run.md for why this
# fires at task-completion instead of commit-time.
write_evaluation_stub() {
  [ "$DRY_RUN" = true ] && return 0
  [ -z "${TASK_NUM:-}" ] && return 0

  # Determine the diff range. New push-only workflow: the task branch is
  # preserved (not merged into ORIGINAL_BRANCH), so the range is simply
  # ORIGINAL_BRANCH..TASK_BRANCH. Fall back to HEAD~1..HEAD if either ref is
  # missing (degenerate / repaired state).
  local diff_range
  if [ -n "${TASK_BRANCH:-}" ] \
     && git rev-parse --verify "${TASK_BRANCH}" >/dev/null 2>&1 \
     && git rev-parse --verify "${ORIGINAL_BRANCH}" >/dev/null 2>&1; then
    diff_range="${ORIGINAL_BRANCH}..${TASK_BRANCH}"
  else
    diff_range="HEAD~1..HEAD"
  fi

  local files
  files=$(git diff --name-only "$diff_range" 2>/dev/null || true)
  [ -z "$files" ] && return 0

  if ! echo "$files" | grep -qE '^(src/\.claude/|src/scripts/.+\.sh|scripts/.+\.sh|src/context/)'; then
    echo "[eval] task touched no CODE paths — evaluation stub skipped (META-only)"
    return 0
  fi

  local eval_dir="$PROJECT_DIR/outputs/evaluations"
  mkdir -p "$eval_dir"
  local date_str
  date_str=$(date +%Y-%m-%d)
  local slug
  slug=$(echo "${TASK:-task}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed -E 's/^-|-$//g' | cut -c1-40)
  local eval_file="${eval_dir}/${date_str}-task-${TASK_NUM}-${slug}.md"

  if [ -f "$eval_file" ]; then
    echo "[eval] stub already exists: $eval_file (skipped)"
    return 0
  fi

  local file_count
  file_count=$(echo "$files" | wc -l | tr -d ' ')
  local diff_stat
  diff_stat=$(git diff --shortstat "$diff_range" 2>/dev/null | sed -E 's/^ +//' || echo "n/a")
  local top_files
  top_files=$(echo "$files" | head -5 | tr '\n' ',' | sed -E 's/,$//')

  local template="$PROJECT_DIR/src/templates/evaluation.md"
  [ -f "$template" ] || template="$PROJECT_DIR/templates/evaluation.md"
  if [ -f "$template" ]; then
    cp "$template" "$eval_file"
    # Best-effort metadata patch (Mac sed). Failures are non-fatal.
    sed -i.bak "s|\[YYYY-MM-DD\]|${date_str}|" "$eval_file" 2>/dev/null || true
    sed -i.bak "s|\[task/N\]|${TASK_BRANCH:-n/a}|" "$eval_file" 2>/dev/null || true
    sed -i.bak "s|Files touched: \[N\]|Files touched: ${file_count}|" "$eval_file" 2>/dev/null || true
    sed -i.bak "s|Diff size: \[+lines / -lines\]|Diff size: ${diff_stat}|" "$eval_file" 2>/dev/null || true
    sed -i.bak "s|\[comma-separated list, top 5\]|${top_files}|" "$eval_file" 2>/dev/null || true
    rm -f "${eval_file}.bak"
  else
    {
      echo "# Task ${TASK_NUM} — ${TASK:-untitled} (evaluation stub)"
      echo ""
      echo "- Date: ${date_str}"
      echo "- Files touched: ${file_count}"
      echo "- Diff size: ${diff_stat}"
      echo "- Files: ${top_files}"
      echo ""
      echo "## Lessons Learned"
      echo "- "
    } > "$eval_file"
  fi
  echo "[eval] stub written: $eval_file"
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# Helper functions
# ============================================================
log_phase() {
  echo ""
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}════════════════════════════════════════${NC}"
  print_status_line
  echo ""
}

log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_fail()    { echo -e "${RED}✗ $1${NC}"; }
log_warn()    { echo -e "${YELLOW}! $1${NC}"; }

# ============================================================
# Status file protocol — writes KEY=VALUE lines to $STATUS_FILE
# so external monitors (epic.md, task.md) can read current state.
# ============================================================
STATUS_FILE="${LOG_DIR}/task-status"

_quote_val() {
  # Escape a value for safe `source` in bash 3.2+/zsh: wrap in single quotes
  # and replace any internal single quote with the '\'' dance.
  local v="$1"
  local repl="'\\''"   # the 4-char sequence: ' \ ' '
  local escaped="${v//\'/$repl}"
  printf "'%s'" "$escaped"
}

write_status() {
  # Merge new KEY=VAL pairs into the status file atomically.
  # Values are single-quoted so `source` works identically in bash 3.2+ and zsh.
  local tmp="${STATUS_FILE}.tmp.$$"
  local pair key val

  # Start from existing file, or empty
  if [ -f "$STATUS_FILE" ]; then
    cp "$STATUS_FILE" "$tmp"
  else
    : > "$tmp"
  fi

  # For each new pair, strip any existing line with that key, then append
  for pair in "$@"; do
    key="${pair%%=*}"
    val="${pair#*=}"
    grep -v "^${key}=" "$tmp" > "${tmp}.new" 2>/dev/null || true
    mv "${tmp}.new" "$tmp"
    echo "${key}=$(_quote_val "$val")" >> "$tmp"
  done

  # Refresh UPDATED_EPOCH
  grep -v "^UPDATED_EPOCH=" "$tmp" > "${tmp}.new" 2>/dev/null || true
  mv "${tmp}.new" "$tmp"
  echo "UPDATED_EPOCH=$(date +%s)" >> "$tmp"

  mv -f "$tmp" "$STATUS_FILE"
}

print_status_line() {
  # Print a compact one-line status summary to stdout.
  [ -f "$STATUS_FILE" ] || return 0
  # shellcheck disable=SC1090
  ( source "$STATUS_FILE"
    local now
    now=$(date +%s)
    local elapsed=$(( now - ${START_EPOCH:-$now} ))
    local mm=$((elapsed/60))
    local ss=$((elapsed%60))
    local prefix=""
    if [ -n "${EPIC_NAME:-}" ]; then
      prefix="[${EPIC_NAME}] "
    fi
    local task_display="${TASK_NAME:-?}"
    if [ -n "${TASK_INDEX:-}" ] && [ -n "${TASK_TOTAL:-}" ]; then
      task_display="(${TASK_INDEX}/${TASK_TOTAL}) ${TASK_NAME}"
    fi
    local role_display="${ROLE:-?}"
    if [ -n "${ITER:-}" ] && [ "${MAX_ITER:-1}" != "1" ]; then
      role_display="${role_display} (iter ${ITER}/${MAX_ITER})"
    fi
    echo -e "  ${CYAN}📋 ${prefix}${task_display} | Role: ${role_display} | ⏱ ${mm}m${ss}s${NC}"
  )
}

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

  # ----- Dry-run short-circuit: stub claude -p, simulate work, write artifacts -----
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] stub: claude -p \"$command\""
    echo "[DRY-RUN] log:  $log_file"
    echo ""
    sleep 1  # simulate work so status file has non-zero elapsed time
    {
      echo "[DRY-RUN] phase=$phase"
      echo "[DRY-RUN] command=$command"
      if [[ "$phase" == review* ]]; then
        echo "VERDICT: APPROVE"
      fi
    } > "$log_file"
    dry_run_write_artifacts "$phase"
    return 0
  fi

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
# Dry-run artifact stub writer — creates the files that each role
# normally produces, so downstream phases have something to read.
# ============================================================
dry_run_write_artifacts() {
  local phase="$1"
  # Extract "Task N" from $TASK description for file naming; fallback to dry-run
  local task_num
  task_num=$(echo "$TASK" | grep -oE "[Tt]ask[[:space:]]+[0-9]+" | grep -oE "[0-9]+" | head -1)
  task_num="${task_num:-dryrun}"

  local plan_file="$PROJECT_DIR/outputs/plans/task-${task_num}-plan.md"
  local verify_file="$PROJECT_DIR/outputs/plans/task-${task_num}-verify.md"
  local review_file="$PROJECT_DIR/outputs/reviews/task-${task_num}-review.md"
  local target_file="$PROJECT_DIR/DRYRUN-NOTES.md"
  local handoff_path="$PROJECT_DIR/${HANDOFF_FILE}"

  mkdir -p "$(dirname "$plan_file")" "$(dirname "$review_file")" "$(dirname "$handoff_path")"

  case "$phase" in
    plan)
      cat > "$plan_file" <<EOF
# Work Plan

## Task
${task_num} — ${TASK}

## Goal
[DRY-RUN] Stub plan for smoke test.

## Scope
- Files to modify: DRYRUN-NOTES.md
- Files NOT to touch: everything else

## Approach
1. Append a dry-run marker line to DRYRUN-NOTES.md

## Acceptance Criteria
- [x] Dry-run artifact stub created
EOF
      cat > "$verify_file" <<EOF
# Verification Plan

## Task
${task_num} — ${TASK}

## Checks
- [x] plan.md exists
- [x] Dry-run stub complete
EOF
      cat > "$handoff_path" <<EOF
# Session Handoff

## Current State
- Task: ${task_num} — ${TASK}
- Phase: Plan → ready for Develop

## Last Action
- [DRY-RUN] Planner stub created plan + verify files

## Plan & Review Locations
- Plan: outputs/plans/task-${task_num}-plan.md
- Verify: outputs/plans/task-${task_num}-verify.md
EOF
      ;;
    develop*)
      echo "- [DRY-RUN] Task ${task_num} — $(date +%Y-%m-%dT%H:%M:%S)" >> "$target_file"
      cat > "$handoff_path" <<EOF
# Session Handoff

## Current State
- Task: ${task_num} — ${TASK}
- Phase: Develop → ready for Review

## Last Action
- [DRY-RUN] Developer stub appended line to DRYRUN-NOTES.md

## Files Changed
- DRYRUN-NOTES.md — dry-run marker

## Verification Status
- Lint: SKIPPED (dry-run)
- Test: SKIPPED (dry-run)
EOF
      ;;
    review*)
      cat > "$review_file" <<EOF
# Review Report

## Task
${task_num} — ${TASK}

## Verdict
APPROVE

## Notes
[DRY-RUN] Review stub — no actual inspection performed.
EOF
      cat > "$handoff_path" <<EOF
# Session Handoff

## Current State
- Task: ${task_num} — ${TASK}
- Phase: Done

## Last Action
- Verdict: APPROVE
- [DRY-RUN] Reviewer stub wrote review file

## Plan & Review Locations
- Plan: outputs/plans/task-${task_num}-plan.md
- Review: outputs/reviews/task-${task_num}-review.md
EOF
      ;;
  esac
}

if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}════════════════════════════════════════${NC}"
  echo -e "${YELLOW}  [DRY-RUN] No claude -p calls will be made${NC}"
  echo -e "${YELLOW}════════════════════════════════════════${NC}"
fi

# ============================================================
# Set up task branch before any work (standalone mode only)
# ============================================================
setup_task_branch

# ============================================================
# Initialize status file (inherits EPIC_NAME/TASK_INDEX/TASK_TOTAL from env
# when launched by run-epic.sh; otherwise runs in standalone task mode)
# ============================================================
write_status \
  "TASK_NAME=${TASK}" \
  "TASK_ID=${TASK_ID:-}" \
  "EPIC_NAME=${EPIC_NAME:-}" \
  "TASK_INDEX=${TASK_INDEX:-}" \
  "TASK_TOTAL=${TASK_TOTAL:-}" \
  "ROLE=init" \
  "ITER=1" \
  "MAX_ITER=${MAX_ITER}" \
  "VERDICT=" \
  "START_EPOCH=$(date +%s)" \
  "PID=$$"

# ============================================================
# Phase 1: Plan
# ============================================================
write_status "ROLE=plan" "ITER=1"
log_phase "PHASE 1/3: PLAN"

if ! run_claude "plan" "/plan $TASK"; then
  log_fail "Plan phase failed. Check ${LOG_DIR}/plan.log"
  write_status "ROLE=failed" "VERDICT=PLAN_FAILED"
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
  write_status "ROLE=develop" "ITER=${ITER}"
  if [ "$ITER" -eq 1 ]; then
    log_phase "PHASE 2/3: DEVELOP"
    DEVELOP_PROMPT="/develop $TASK"
  else
    log_phase "ITERATION ${ITER}/${MAX_ITER}: DEVELOP (refinement)"
    DEVELOP_PROMPT="/develop $TASK — ITERATE apply feedback (iteration ${ITER})"
  fi

  DEVELOP_LOG="${LOG_DIR}/develop-iter${ITER}.log"
  # Override log file for iteration tracking
  if ! run_claude "develop-iter${ITER}" "$DEVELOP_PROMPT"; then
    log_fail "Develop phase failed (iter ${ITER}). Check ${DEVELOP_LOG}"
    write_status "ROLE=failed" "VERDICT=DEVELOP_FAILED"
    exit 1
  fi
  log_success "Develop phase complete (iter ${ITER})"

  # --- Review ---
  write_status "ROLE=review" "ITER=${ITER}"
  if [ "$ITER" -eq 1 ]; then
    log_phase "PHASE 3/3: REVIEW"
  else
    log_phase "ITERATION ${ITER}/${MAX_ITER}: REVIEW"
  fi

  REVIEW_LOG="${LOG_DIR}/review-iter${ITER}.log"
  if ! run_claude "review-iter${ITER}" "/review $TASK"; then
    log_fail "Review phase failed (iter ${ITER}). Check ${REVIEW_LOG}"
    write_status "ROLE=failed" "VERDICT=REVIEW_FAILED"
    exit 1
  fi

  # Check verdict
  if grep -qi "REQUEST_CHANGES\|request.changes" "$REVIEW_LOG" 2>/dev/null; then
    log_fail "Review verdict: REQUEST_CHANGES (iter ${ITER})"
    write_status "ROLE=done" "VERDICT=REQUEST_CHANGES"
    echo ""
    echo "Review output: $REVIEW_LOG"
    echo ""
    echo "Next steps:"
    echo "  1. Read the review: cat $REVIEW_LOG"
    echo "  2. Fix: /develop $TASK — REQUEST_CHANGES fix"
    echo "  3. Re-review: /review $TASK"
    exit 1
  fi

  if grep -qi "ITERATE" "$REVIEW_LOG" 2>/dev/null; then
    if [ "$ITER" -lt "$MAX_ITER" ]; then
      log_warn "Review verdict: ITERATE (iter ${ITER}/${MAX_ITER}) — refining..."
      write_status "VERDICT=ITERATE"
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

write_status "ROLE=done" "VERDICT=${VERDICT}"

# ============================================================
# Finalize task branch on APPROVE (auto-merge back to original)
# ============================================================
if [ "$VERDICT" = "APPROVE" ]; then
  finalize_task_branch
  write_evaluation_stub
fi

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
