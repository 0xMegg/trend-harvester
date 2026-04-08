#!/bin/bash
# run-epic.sh — Epic decomposition + automatic Slice execution
#
# Usage:
#   ./scripts/run-epic.sh "Epic 1 — 사용자 인증 시스템"
#
# Flow:
#   1. /plan Epic N → generates epic plan with Slice list
#   2. Parses Stages & Slices from the epic plan
#   3. Runs Slices — parallel within a Stage, sequential between Stages
#   4. Stops on first Stage failure
#
# Parallel support:
#   - Epic plans with "## Stage N" or "### Stage N" headings enable parallel execution
#   - Slices within the same Stage run in parallel (up to MAX_PARALLEL)
#   - Epic plans without Stage headings run all slices sequentially (backward compatible)

set -euo pipefail

# ============================================================
# Configuration
# ============================================================
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="${PROJECT_NAME:-$(basename "$PROJECT_DIR")}"
MAX_PARALLEL="${MAX_PARALLEL:-3}"
EPIC="$*"

if [ -z "$EPIC" ]; then
  echo "Usage: $0 <epic description>"
  echo "Example: $0 Epic 1 — 사용자 인증 시스템"
  exit 1
fi

# Epic-scoped log directory — prevents log pollution across runs
RUN_ID="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="/tmp/${PROJECT_NAME}-run/${EPIC// /-}-${RUN_ID}"
mkdir -p "$LOG_DIR"

# Symlink for convenience: /tmp/<project>-run/latest → this run
ln -sfn "$LOG_DIR" "/tmp/${PROJECT_NAME}-run/latest"

# Export so run-task.sh uses the same scoped directory
export EPIC_LOG_DIR="$LOG_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_phase() {
  echo ""
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo -e "${CYAN}  $1${NC}"
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo ""
}

# ============================================================
# Git repo discovery (multi-repo support)
# ============================================================
# If PROJECT_DIR is a git repo, returns PROJECT_DIR only.
# Otherwise, finds immediate child directories that are git repos.
discover_git_repos() {
  if [ -d "$PROJECT_DIR/.git" ] || git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    echo "$PROJECT_DIR"
    return
  fi

  local repos=()
  for dir in "$PROJECT_DIR"/*/; do
    if [ -d "${dir}.git" ]; then
      repos+=("${dir%/}")
    fi
  done

  if [ ${#repos[@]} -eq 0 ]; then
    echo -e "${RED}WARNING: No git repos found under $PROJECT_DIR${NC}" >&2
    return 1
  fi

  printf '%s\n' "${repos[@]}"
}

IS_MULTI_REPO=false
if ! [ -d "$PROJECT_DIR/.git" ] && ! git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  IS_MULTI_REPO=true
fi

# ============================================================
# Normalize input: bare number → "Epic N"
# ============================================================
if [[ "$EPIC" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  EPIC_NUM="$EPIC"
  EPIC="Epic $EPIC_NUM"
fi

cd "$PROJECT_DIR"

# ============================================================
# Phase 0: Epic Decomposition (skip if plan already exists)
# ============================================================
EPIC_PLAN=""
if [[ -n "${EPIC_NUM:-}" ]]; then
  EPIC_PLAN=$(find "$PROJECT_DIR/outputs/plans" -name "epic-${EPIC_NUM}*plan*.md" 2>/dev/null | sort | tail -1)
fi

if [ -n "$EPIC_PLAN" ]; then
  log_phase "EPIC PLAN FOUND: $EPIC"
  echo -e "${GREEN}✓ Using existing plan: $(basename "$EPIC_PLAN")${NC}"
else
  log_phase "EPIC DECOMPOSITION: $EPIC"

  EPIC_LOG="${LOG_DIR}/epic-plan.log"
  echo "Running: claude -p \"/plan $EPIC\""

  if ! "$CLAUDE_BIN" -p "/plan $EPIC" \
    --output-format text \
    2>&1 | tee "$EPIC_LOG"; then
    echo -e "${RED}✗ Epic planning failed. Check $EPIC_LOG${NC}"
    exit 1
  fi

  echo -e "${GREEN}✓ Epic plan created${NC}"

  EPIC_PLAN=$(find "$PROJECT_DIR/outputs/plans" -name "epic*plan*.md" -mmin -10 2>/dev/null | sort | tail -1)
fi

if [ -z "$EPIC_PLAN" ]; then
  echo -e "${RED}✗ Could not find epic plan file in outputs/plans/${NC}"
  echo "Run slices manually with: ./scripts/run-task.sh \"Task N — description\""
  exit 1
fi

echo "Epic plan: $EPIC_PLAN"

# ============================================================
# Parse Stages & Slices from Epic Plan
# ============================================================

# Detect if plan uses explicit Stage headings
HAS_STAGES=false
if grep -qiE "^#{2,3}\s+Stage\s+[0-9]" "$EPIC_PLAN" 2>/dev/null; then
  HAS_STAGES=true
fi

# Arrays: SLICES[i] = description, SLICE_STAGE[i] = stage number
SLICES=()
SLICE_STAGE=()
CURRENT_STAGE=1
STAGE_COUNT=1

while IFS= read -r line; do
  # Detect Stage headings: ## Stage N or ### Stage N
  if [[ "$line" =~ ^#{2,3}[[:space:]]+[Ss]tage[[:space:]]+([0-9]+) ]]; then
    CURRENT_STAGE="${BASH_REMATCH[1]}"
    if (( CURRENT_STAGE > STAGE_COUNT )); then
      STAGE_COUNT=$CURRENT_STAGE
    fi
    continue
  fi

  # Detect Slice/Task lines (existing pattern)
  if echo "$line" | grep -qiE "^[[:space:]]*[-*|#0-9].*\b(Task|Slice|태스크|슬라이스)\s+[0-9]"; then
    SLICE_DESC=$(echo "$line" | sed -E '
      s/^[[:space:]]*[-*|]+[[:space:]]*//;
      s/\|[[:space:]]*$//;
      s/^[0-9]+\.[[:space:]]*//;
      s/^#+[[:space:]]*//;
      s/[[:space:]]+$//
    ')
    if [ -n "$SLICE_DESC" ]; then
      SLICES+=("$SLICE_DESC")
      if $HAS_STAGES; then
        SLICE_STAGE+=("$CURRENT_STAGE")
      else
        # No explicit stages → each slice is its own sequential "stage"
        SLICE_STAGE+=("${#SLICES[@]}")
        STAGE_COUNT=${#SLICES[@]}
      fi
    fi
  fi
done < "$EPIC_PLAN"

if [ ${#SLICES[@]} -eq 0 ]; then
  echo -e "${YELLOW}! Could not auto-parse Slices from epic plan${NC}"
  echo "Run slices manually: ./scripts/run-task.sh \"Task N — description\""
  exit 0
fi

TOTAL=${#SLICES[@]}

# ============================================================
# Display parsed structure
# ============================================================
if $HAS_STAGES; then
  echo -e "${BLUE}Found $TOTAL slices across $STAGE_COUNT stages:${NC}"
  for stage_num in $(seq 1 "$STAGE_COUNT"); do
    stage_slices=""
    for i in "${!SLICES[@]}"; do
      if [ "${SLICE_STAGE[$i]}" = "$stage_num" ]; then
        stage_slices="${stage_slices}  $((i+1)). ${SLICES[$i]}\n"
      fi
    done
    if [ -n "$stage_slices" ]; then
      echo -e " ${CYAN}Stage $stage_num:${NC}"
      echo -e "$stage_slices"
    fi
  done
else
  echo -e "${BLUE}Found $TOTAL slices (sequential):${NC}"
  for i in "${!SLICES[@]}"; do
    echo "  $((i+1)). ${SLICES[$i]}"
  done
fi
echo ""

# ============================================================
# Parallel execution helpers
# ============================================================

# Commit all changes from a parallel stage in one consolidated commit
# Args: stage_number slice_indices...
# Multi-repo: commits to each git repo that has changes independently
commit_stage() {
  local stage_num="$1"
  shift
  local indices=("$@")

  echo -e "${BLUE}Committing Stage $stage_num changes...${NC}"

  # Build slice summaries for commit message
  local slice_summaries=""
  for idx in "${indices[@]}"; do
    local desc="${SLICES[$idx]}"
    local short_desc
    short_desc=$(echo "$desc" | sed -E 's/^(Slice|Task|태스크|슬라이스)\s+[0-9]+\s*[-—:]\s*//')
    if [ -n "$slice_summaries" ]; then
      slice_summaries="${slice_summaries} + ${short_desc}"
    else
      slice_summaries="$short_desc"
    fi
  done

  local committed=false

  # Commit in each git repo that has changes
  while IFS= read -r repo_dir; do
    cd "$repo_dir"

    if [ -z "$(git status --porcelain)" ]; then
      if $IS_MULTI_REPO; then
        echo -e "  ${YELLOW}[$(basename "$repo_dir")] No changes${NC}"
      fi
      continue
    fi

    local repo_name
    repo_name=$(basename "$repo_dir")
    local commit_msg
    if $IS_MULTI_REPO; then
      commit_msg="feat: Stage ${stage_num} [${repo_name}] — ${slice_summaries}"
    else
      commit_msg="feat: Stage ${stage_num} — ${slice_summaries}"
    fi

    git add -A
    if ! git commit -m "$commit_msg"; then
      echo -e "${RED}✗ Git commit failed in ${repo_name} for Stage $stage_num${NC}"
      cd "$PROJECT_DIR"
      return 1
    fi

    if git push; then
      echo -e "${GREEN}✓ [${repo_name}] Stage $stage_num committed and pushed${NC}"
      echo "  Commit: $(git rev-parse --short HEAD)"
    else
      echo -e "${YELLOW}! [${repo_name}] Git push failed — commit exists locally${NC}"
      echo "  Run 'cd ${repo_dir} && git push' manually."
    fi
    committed=true
  done < <(discover_git_repos)

  if ! $committed; then
    echo -e "${YELLOW}! No changes to commit for Stage $stage_num${NC}"
  fi

  cd "$PROJECT_DIR"
}

# Optional post-commit deploy hook
# If scripts/deploy-hook.sh exists and is executable, run it after each stage commit
run_deploy_hook() {
  local stage_num="$1"
  local hook="$PROJECT_DIR/scripts/deploy-hook.sh"
  if [ -x "$hook" ]; then
    echo -e "${BLUE}Running deploy hook for Stage $stage_num...${NC}"
    if "$hook" "$stage_num"; then
      echo -e "${GREEN}✓ Deploy hook complete${NC}"
    else
      echo -e "${YELLOW}! Deploy hook failed (non-blocking)${NC}"
    fi
  fi
}

# Run a single stage's slices in parallel
# Args: stage_number slice_indices...
run_parallel_stage() {
  local stage_num="$1"
  shift
  local indices=("$@")
  local count=${#indices[@]}

  echo -e "${CYAN}Stage $stage_num: $count slices in parallel (max $MAX_PARALLEL concurrent)${NC}"

  # Prepare per-task handoff files
  for idx in "${indices[@]}"; do
    local handoff_file="$PROJECT_DIR/handoff/task-slice-${idx}.md"
    if [ -f "$PROJECT_DIR/handoff/latest.md" ]; then
      cp "$PROJECT_DIR/handoff/latest.md" "$handoff_file"
    else
      touch "$handoff_file"
    fi
    echo "<!-- PARALLEL_TASK_START slice-${idx} -->" >> "$handoff_file"
  done

  # Launch slices in batches of MAX_PARALLEL
  local batch_start=0
  local all_ok=true
  local failed_slices=()

  while (( batch_start < count )); do
    local batch_end=$(( batch_start + MAX_PARALLEL ))
    if (( batch_end > count )); then
      batch_end=$count
    fi

    local pids=()
    local pid_to_idx=()

    for (( b = batch_start; b < batch_end; b++ )); do
      local idx="${indices[$b]}"
      local slice_desc="${SLICES[$idx]}"
      local task_log_dir="${LOG_DIR}/task-slice-${idx}"
      mkdir -p "$task_log_dir"

      echo -e "  ${BLUE}Starting: Slice $((idx+1)) — ${slice_desc}${NC}"

      "$SCRIPT_DIR/run-task.sh" --task-id "slice-${idx}" --no-commit "$slice_desc" \
        > "${task_log_dir}/stdout.log" 2>&1 &

      pids+=($!)
      pid_to_idx+=("$idx")
    done

    echo -e "  Logs: ${LOG_DIR}/task-slice-{...}/"
    echo "  Waiting for batch to complete..."

    # Wait for all PIDs in this batch (|| true prevents set -e from killing us)
    for p_idx in "${!pids[@]}"; do
      local pid="${pids[$p_idx]}"
      local s_idx="${pid_to_idx[$p_idx]}"
      local wait_rc=0

      wait "$pid" || wait_rc=$?

      if [ "$wait_rc" -eq 0 ]; then
        echo -e "  ${GREEN}✓ Slice $((s_idx+1)) complete${NC}"
      else
        echo -e "  ${RED}✗ Slice $((s_idx+1)) failed (exit $wait_rc)${NC}"
        all_ok=false
        failed_slices+=("$s_idx")
      fi
    done

    batch_start=$batch_end
  done

  # Report results
  if $all_ok; then
    echo -e "${GREEN}Stage $stage_num COMPLETE ($count/$count)${NC}"
  else
    echo -e "${RED}Stage $stage_num FAILED (${#failed_slices[@]} slice(s) failed)${NC}"
    echo ""
    echo "Failed slices:"
    for idx in "${failed_slices[@]}"; do
      echo -e "  ${RED}✗ Slice $((idx+1)): ${SLICES[$idx]}${NC}"
      echo "    Log: ${LOG_DIR}/task-slice-${idx}/stdout.log"
    done
    echo ""
    echo "To retry failed slices:"
    for idx in "${failed_slices[@]}"; do
      echo "  $SCRIPT_DIR/run-task.sh \"${SLICES[$idx]}\""
    done
    return 1
  fi
}

# Merge parallel handoff files back into handoff/latest.md
# Args: stage_number slice_indices...
merge_stage_handoffs() {
  local stage_num="$1"
  shift
  local indices=("$@")

  echo "" >> "$PROJECT_DIR/handoff/latest.md"
  echo "## Stage $stage_num Results (parallel)" >> "$PROJECT_DIR/handoff/latest.md"

  for idx in "${indices[@]}"; do
    local handoff_file="$PROJECT_DIR/handoff/task-slice-${idx}.md"
    if [ -f "$handoff_file" ]; then
      # Extract content after the PARALLEL_TASK_START marker
      local marker_content
      marker_content=$(sed -n '/<!-- PARALLEL_TASK_START/,$ p' "$handoff_file" | tail -n +2)
      if [ -n "$marker_content" ]; then
        echo "" >> "$PROJECT_DIR/handoff/latest.md"
        echo "### Slice $((idx+1)): ${SLICES[$idx]}" >> "$PROJECT_DIR/handoff/latest.md"
        echo "$marker_content" >> "$PROJECT_DIR/handoff/latest.md"
      fi
      rm -f "$handoff_file"
    fi
  done
}

# ============================================================
# Execute Stages
# ============================================================
COMPLETED_STAGES=0

for stage_num in $(seq 1 "$STAGE_COUNT"); do
  # Collect slice indices for this stage
  stage_indices=()
  for i in "${!SLICES[@]}"; do
    if [ "${SLICE_STAGE[$i]}" = "$stage_num" ]; then
      stage_indices+=("$i")
    fi
  done

  # Skip empty stages
  if [ ${#stage_indices[@]} -eq 0 ]; then
    continue
  fi

  stage_slice_count=${#stage_indices[@]}

  log_phase "STAGE $stage_num/$STAGE_COUNT ($stage_slice_count slice(s))"

  if ! $HAS_STAGES || [ "$stage_slice_count" -eq 1 ]; then
    # Sequential execution: single slice or no explicit stages
    local_idx="${stage_indices[0]}"
    SLICE="${SLICES[$local_idx]}"

    echo -e "${BLUE}Running: Slice $((local_idx+1)) — ${SLICE}${NC}"

    if "$SCRIPT_DIR/run-task.sh" --no-commit "$SLICE"; then
      echo -e "${GREEN}✓ Slice $((local_idx+1)) complete${NC}"

      # Orchestrator handles commit (same as parallel stages)
      if ! commit_stage "$stage_num" "$local_idx"; then
        echo -e "${RED}✗ Stage $stage_num commit failed${NC}"
        echo "Changes are in the working directory. Commit manually:"
        if $IS_MULTI_REPO; then
          while IFS= read -r repo_dir; do
            echo "  cd $repo_dir && git add -A && git commit -m 'feat: Stage ${stage_num}' && git push"
          done < <(discover_git_repos)
        else
          echo "  git add -A && git commit -m 'feat: Stage ${stage_num}' && git push"
        fi
        exit 1
      fi
      run_deploy_hook "$stage_num"
    else
      echo -e "${RED}✗ Slice $((local_idx+1)) failed: $SLICE${NC}"
      echo ""
      echo "Completed stages: $COMPLETED_STAGES/$STAGE_COUNT"
      echo ""
      echo "To resume from this slice:"
      echo "  $SCRIPT_DIR/run-task.sh \"$SLICE\""
      echo ""
      # Show remaining stages
      if (( stage_num < STAGE_COUNT )); then
        echo "Remaining stages after this one:"
        for remaining_stage in $(seq $((stage_num+1)) "$STAGE_COUNT"); do
          for ri in "${!SLICES[@]}"; do
            if [ "${SLICE_STAGE[$ri]}" = "$remaining_stage" ]; then
              echo "  $SCRIPT_DIR/run-task.sh \"${SLICES[$ri]}\""
            fi
          done
        done
      fi
      exit 1
    fi
  else
    # Parallel execution: multiple slices in this stage
    if ! run_parallel_stage "$stage_num" "${stage_indices[@]}"; then
      echo ""
      echo "Completed stages: $COMPLETED_STAGES/$STAGE_COUNT"
      exit 1
    fi

    # Merge parallel handoff files back
    merge_stage_handoffs "$stage_num" "${stage_indices[@]}"

    # Consolidated git commit for all parallel slices in this stage
    if ! commit_stage "$stage_num" "${stage_indices[@]}"; then
      echo -e "${RED}✗ Stage $stage_num commit failed${NC}"
      echo "Changes are in the working directory. Commit manually:"
      if $IS_MULTI_REPO; then
        while IFS= read -r repo_dir; do
          echo "  cd $repo_dir && git add -A && git commit -m 'feat: Stage ${stage_num}' && git push"
        done < <(discover_git_repos)
      else
        echo "  git add -A && git commit -m 'feat: Stage ${stage_num}' && git push"
      fi
      exit 1
    fi

    # Run deploy hook after successful commit
    run_deploy_hook "$stage_num"
  fi

  COMPLETED_STAGES=$((COMPLETED_STAGES+1))
done

echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}  EPIC COMPLETE: $EPIC${NC}"
echo -e "${GREEN}  All $STAGE_COUNT stage(s), $TOTAL slice(s) finished${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
