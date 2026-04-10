#!/bin/bash
# run-epic.sh — Epic decomposition + automatic Slice execution
#
# Usage:
#   ./scripts/run-epic.sh "Epic 1 — User authentication system"
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

# ============================================================
# Argument parsing (flags first, then epic description)
# ============================================================
DRY_RUN=false
while [ $# -gt 0 ]; do
  case "${1:-}" in
    --dry-run)
      DRY_RUN=true
      shift
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

EPIC="$*"

if [ -z "$EPIC" ]; then
  echo "Usage: $0 [--dry-run] <epic description>"
  echo "Example: $0 Epic 1 — User authentication system"
  echo "Example: $0 --dry-run Epic 1 — Smoke test (no tokens spent)"
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

# ============================================================
# Epic branch isolation — create epic/{RUN_ID} branch off main
# (skipped for dry-run, non-git, or HARVEST_ALLOW_MAIN=1)
# ============================================================
EPIC_BRANCH=""
EPIC_ORIGINAL_BRANCH=""

setup_epic_branch() {
  if [ "$DRY_RUN" = true ]; then return 0; fi
  if [ "${HARVEST_ALLOW_MAIN:-0}" = "1" ]; then return 0; fi
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then return 0; fi

  EPIC_ORIGINAL_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
  case "$EPIC_ORIGINAL_BRANCH" in
    main|master) ;;
    *) return 0 ;;   # already on a non-main branch
  esac

  if [ -n "$(git status --porcelain)" ]; then
    echo "ERROR: working tree dirty on $EPIC_ORIGINAL_BRANCH — commit/stash first or set HARVEST_ALLOW_MAIN=1" >&2
    exit 1
  fi

  EPIC_BRANCH="epic/${RUN_ID}"
  git checkout -b "$EPIC_BRANCH" >/dev/null 2>&1
  echo "[epic-branch] ${EPIC_ORIGINAL_BRANCH} → ${EPIC_BRANCH}"
}

finalize_epic_branch() {
  [ -z "$EPIC_BRANCH" ] && return 0
  [ "$DRY_RUN" = true ] && return 0

  git checkout "$EPIC_ORIGINAL_BRANCH" >/dev/null 2>&1 || {
    echo "WARN: cannot return to $EPIC_ORIGINAL_BRANCH — ${EPIC_BRANCH} preserved" >&2
    return 0
  }
  if git merge --ff-only "$EPIC_BRANCH" >/dev/null 2>&1; then
    echo "[epic-branch] merged ${EPIC_BRANCH} → ${EPIC_ORIGINAL_BRANCH} (ff-only)"
    git push 2>/dev/null && echo "[epic-branch] pushed ${EPIC_ORIGINAL_BRANCH}" || echo "[epic-branch] push skipped or failed — local merge kept"
    git branch -d "$EPIC_BRANCH" >/dev/null 2>&1 || true
  else
    echo "WARN: ff-only merge failed — leave ${EPIC_BRANCH} for manual review" >&2
    git checkout "$EPIC_BRANCH" >/dev/null 2>&1 || true
  fi
}

setup_epic_branch

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
  print_epic_status_line
  echo ""
}

# ============================================================
# Epic status file — writes KEY=VALUE lines to $EPIC_STATUS_FILE.
# Matches the format used by run-task.sh so external monitors
# (epic.md, task.md) can read both files with the same parser.
# ============================================================
EPIC_STATUS_FILE="${LOG_DIR}/epic-status"

_quote_val() {
  # Escape a value for safe `source` in bash 3.2+/zsh.
  local v="$1"
  local repl="'\\''"
  local escaped="${v//\'/$repl}"
  printf "'%s'" "$escaped"
}

write_epic_status() {
  local tmp="${EPIC_STATUS_FILE}.tmp.$$"
  local pair key val

  if [ -f "$EPIC_STATUS_FILE" ]; then
    cp "$EPIC_STATUS_FILE" "$tmp"
  else
    : > "$tmp"
  fi

  for pair in "$@"; do
    key="${pair%%=*}"
    val="${pair#*=}"
    grep -v "^${key}=" "$tmp" > "${tmp}.new" 2>/dev/null || true
    mv "${tmp}.new" "$tmp"
    echo "${key}=$(_quote_val "$val")" >> "$tmp"
  done

  grep -v "^UPDATED_EPOCH=" "$tmp" > "${tmp}.new" 2>/dev/null || true
  mv "${tmp}.new" "$tmp"
  echo "UPDATED_EPOCH=$(date +%s)" >> "$tmp"

  mv -f "$tmp" "$EPIC_STATUS_FILE"
}

print_epic_status_line() {
  [ -f "$EPIC_STATUS_FILE" ] || return 0
  # shellcheck disable=SC1090
  ( source "$EPIC_STATUS_FILE"
    local now
    now=$(date +%s)
    local elapsed=$(( now - ${START_EPOCH:-$now} ))
    local mm=$((elapsed/60))
    local ss=$((elapsed%60))
    echo -e "  ${CYAN}🎯 ${EPIC_NAME:-?} | Stage ${STAGE:-?}/${STAGE_TOTAL:-?} | Tasks: ${TASK_TOTAL:-?} | ⏱ ${mm}m${ss}s${NC}"
  )
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

if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}════════════════════════════════════════${NC}"
  echo -e "${YELLOW}  [DRY-RUN] No claude -p calls will be made${NC}"
  echo -e "${YELLOW}════════════════════════════════════════${NC}"
fi

# ============================================================
# Phase 0: Epic Decomposition (skip if plan already exists)
# ============================================================
EPIC_PLAN=""
if [[ -n "${EPIC_NUM:-}" ]]; then
  EPIC_PLAN=$(find "$PROJECT_DIR/outputs/plans" -name "epic-${EPIC_NUM}*plan*.md" 2>/dev/null | sort | tail -1)
fi

# Dry-run: fall back to any epic plan file in outputs/plans if no EPIC_NUM match
if [ "$DRY_RUN" = true ] && [ -z "$EPIC_PLAN" ]; then
  EPIC_PLAN=$(find "$PROJECT_DIR/outputs/plans" -name "epic*plan*.md" 2>/dev/null | sort | tail -1)
  if [ -z "$EPIC_PLAN" ]; then
    echo -e "${RED}✗ [DRY-RUN] Requires a pre-existing epic plan in outputs/plans/epic*plan*.md${NC}"
    exit 1
  fi
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

# Arrays: SLICES[i] = description, SLICE_STAGE[i] = stage number,
# SLICE_FILES[i] = comma-separated target files (for overlap gate)
SLICES=()
SLICE_STAGE=()
SLICE_FILES=()
CURRENT_STAGE=1
STAGE_COUNT=1
LAST_SLICE_IDX=-1

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
  if echo "$line" | grep -qiE "^[[:space:]]*[-*|#0-9].*\b(Task|Slice)\s+[0-9]"; then
    SLICE_DESC=$(echo "$line" | sed -E '
      s/^[[:space:]]*[-*|]+[[:space:]]*//;
      s/\|[[:space:]]*$//;
      s/^[0-9]+\.[[:space:]]*//;
      s/^#+[[:space:]]*//;
      s/[[:space:]]+$//
    ')
    if [ -n "$SLICE_DESC" ]; then
      SLICES+=("$SLICE_DESC")
      SLICE_FILES+=("")
      LAST_SLICE_IDX=$(( ${#SLICES[@]} - 1 ))
      if $HAS_STAGES; then
        SLICE_STAGE+=("$CURRENT_STAGE")
      else
        # No explicit stages → each slice is its own sequential "stage"
        SLICE_STAGE+=("${#SLICES[@]}")
        STAGE_COUNT=${#SLICES[@]}
      fi
    fi
    continue
  fi

  # Detect "- **Files:** a.md, b.md" lines under the most recent slice
  if [ "$LAST_SLICE_IDX" -ge 0 ] \
     && [[ "$line" =~ ^[[:space:]]*-[[:space:]]*\*\*[Ff]iles:\*\*[[:space:]]*(.+)$ ]]; then
    SLICE_FILES[LAST_SLICE_IDX]="${BASH_REMATCH[1]}"
  fi
done < "$EPIC_PLAN"

if [ ${#SLICES[@]} -eq 0 ]; then
  echo -e "${YELLOW}! Could not auto-parse Slices from epic plan${NC}"
  echo "Run slices manually: ./scripts/run-task.sh \"Task N — description\""
  exit 0
fi

TOTAL=${#SLICES[@]}

# ============================================================
# Initialize epic status file (after slice parsing so we know TOTAL/STAGE_COUNT)
# ============================================================
write_epic_status \
  "EPIC_NAME=${EPIC}" \
  "STAGE=0" \
  "STAGE_TOTAL=${STAGE_COUNT}" \
  "TASK_TOTAL=${TOTAL}" \
  "COMPLETED_STAGES=0" \
  "START_EPOCH=$(date +%s)" \
  "PID=$$"

# Export so run-task.sh can pick up epic context for its own status file
export EPIC_NAME="${EPIC}"
export TASK_TOTAL="${TOTAL}"

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

# Overlap gate: detect target_files shared by 2+ slices in the same stage.
# Exits 1 (through caller) if conflicts found. Empty SLICE_FILES entries skipped.
check_slice_overlap() {
  local stage_num="$1"
  shift
  local indices=("$@")

  local tmpfile
  tmpfile=$(mktemp -t harvest-overlap.XXXXXX)
  local has_data=0

  for idx in "${indices[@]}"; do
    local files="${SLICE_FILES[$idx]:-}"
    [ -z "$files" ] && continue
    has_data=1
    # Strip markdown backticks/brackets, split on comma, trim
    echo "$files" \
      | sed 's/`//g; s/\[//g; s/\]//g' \
      | tr ',' '\n' \
      | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' \
      | sed '/^$/d' \
      | while IFS= read -r f; do
          echo "${idx}|${f}"
        done >> "$tmpfile"
  done

  if [ "$has_data" -eq 0 ]; then
    # No file lists parsed — rely on human discipline (backward compatible)
    rm -f "$tmpfile"
    return 0
  fi

  local duplicates
  duplicates=$(awk -F'|' '{print $2}' "$tmpfile" | sort | uniq -d)
  if [ -n "$duplicates" ]; then
    echo -e "${RED}[overlap-gate] BLOCK: Stage $stage_num has overlapping target files:${NC}" >&2
    while IFS= read -r dupfile; do
      local owners
      owners=$(awk -F'|' -v f="$dupfile" '$2 == f {print $1}' "$tmpfile" | tr '\n' ' ')
      echo -e "${RED}  - $dupfile (slices: $owners)${NC}" >&2
    done <<< "$duplicates"
    echo -e "${RED}  Edit the epic plan so each file is touched by only one slice per stage.${NC}" >&2
    rm -f "$tmpfile"
    return 1
  fi

  rm -f "$tmpfile"
  return 0
}

# Per-slice worktree helpers — opt-in via HARVEST_PARALLEL_WORKTREE=1.
# Each slice runs in .harvest-wt/stage-N/slice-I on its own branch.
# After the slice completes, changes are transferred back to the main
# working tree via `git diff | git apply` (the overlap gate guarantees
# that multiple slice patches will not collide).
WORKTREE_ENABLED=0
if [ "${HARVEST_PARALLEL_WORKTREE:-0}" = "1" ] \
   && [ "$DRY_RUN" != true ] \
   && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  WORKTREE_ENABLED=1
fi

setup_slice_worktree() {
  local stage_num="$1" idx="$2"
  [ "$WORKTREE_ENABLED" -ne 1 ] && return 0
  local wt_dir="$PROJECT_DIR/.harvest-wt/stage-${stage_num}/slice-${idx}"
  local wt_branch="harvest-wt/${RUN_ID}/s${stage_num}/${idx}"
  mkdir -p "$(dirname "$wt_dir")"
  if [ -d "$wt_dir" ]; then
    git worktree remove --force "$wt_dir" >/dev/null 2>&1 || true
  fi
  git worktree add --quiet "$wt_dir" -b "$wt_branch" HEAD >/dev/null 2>&1 \
    || { echo "[worktree] WARN: cannot create worktree for slice $idx — falling back to shared tree" >&2; return 1; }
  echo "$wt_dir"
}

finalize_slice_worktree() {
  local wt_dir="$1"
  [ "$WORKTREE_ENABLED" -ne 1 ] && return 0
  [ -z "$wt_dir" ] && return 0
  [ -d "$wt_dir" ] || return 0

  # Capture uncommitted changes as patch and apply to main worktree
  local patch
  patch=$(mktemp -t harvest-slice-patch.XXXXXX)
  ( cd "$wt_dir" && git add -A && git diff --cached ) > "$patch" 2>/dev/null
  if [ -s "$patch" ]; then
    ( cd "$PROJECT_DIR" && git apply --index "$patch" ) \
      || echo "[worktree] WARN: failed to apply slice patch from $wt_dir — inspect manually" >&2
  fi
  rm -f "$patch"

  # Remove worktree and delete its branch
  local wt_branch
  wt_branch=$( ( cd "$wt_dir" && git symbolic-ref --short HEAD 2>/dev/null ) || true)
  git worktree remove --force "$wt_dir" >/dev/null 2>&1 || true
  [ -n "$wt_branch" ] && git branch -D "$wt_branch" >/dev/null 2>&1 || true
}

# Commit all changes from a parallel stage in one consolidated commit
# Args: stage_number slice_indices...
# Multi-repo: commits to each git repo that has changes independently
commit_stage() {
  local stage_num="$1"
  shift
  local indices=("$@")

  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY-RUN] Skipping commit for Stage $stage_num${NC}"
    return 0
  fi

  echo -e "${BLUE}Committing Stage $stage_num changes...${NC}"

  # Build slice summaries for commit message
  local slice_summaries=""
  for idx in "${indices[@]}"; do
    local desc="${SLICES[$idx]}"
    local short_desc
    short_desc=$(echo "$desc" | sed -E 's/^(Slice|Task)\s+[0-9]+\s*[-—:]\s*//')
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
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY-RUN] Skipping deploy hook for Stage $stage_num${NC}"
    return 0
  fi
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

  # Overlap gate — refuse to launch if any two slices target the same file
  if ! check_slice_overlap "$stage_num" "${indices[@]}"; then
    return 1
  fi

  # Per-slice worktree bookkeeping (only populated when WORKTREE_ENABLED=1)
  declare -A SLICE_WT_DIR=()

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

      local dry_flag=""
      if [ "$DRY_RUN" = true ]; then
        dry_flag="--dry-run"
      fi

      local slice_cwd="$PROJECT_DIR"
      if [ "$WORKTREE_ENABLED" -eq 1 ]; then
        local wt
        wt=$(setup_slice_worktree "$stage_num" "$idx" 2>/dev/null || true)
        if [ -n "$wt" ] && [ -d "$wt" ]; then
          SLICE_WT_DIR[$idx]="$wt"
          slice_cwd="$wt"
          # Carry handoff file into the worktree so the slice can read it
          mkdir -p "$wt/handoff"
          [ -f "$PROJECT_DIR/handoff/task-slice-${idx}.md" ] \
            && cp "$PROJECT_DIR/handoff/task-slice-${idx}.md" "$wt/handoff/" 2>/dev/null || true
        fi
      fi

      ( cd "$slice_cwd" && \
        TASK_INDEX="$((idx+1))" TASK_TOTAL="$TOTAL" EPIC_NAME="$EPIC" \
          "$SCRIPT_DIR/run-task.sh" --task-id "slice-${idx}" --no-commit ${dry_flag:+$dry_flag} "$slice_desc" \
        ) > "${task_log_dir}/stdout.log" 2>&1 &

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

  # Merge worktree patches back to main working tree and clean up
  if [ "$WORKTREE_ENABLED" -eq 1 ]; then
    for idx in "${indices[@]}"; do
      local wt_dir="${SLICE_WT_DIR[$idx]:-}"
      [ -n "$wt_dir" ] && finalize_slice_worktree "$wt_dir"
      # Bring slice's handoff file (if any) back to main tree
      if [ -n "$wt_dir" ] && [ -f "$wt_dir/handoff/task-slice-${idx}.md" ]; then
        cp "$wt_dir/handoff/task-slice-${idx}.md" "$PROJECT_DIR/handoff/" 2>/dev/null || true
      fi
    done
  fi

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

  write_epic_status "STAGE=${stage_num}"
  log_phase "STAGE $stage_num/$STAGE_COUNT ($stage_slice_count slice(s))"

  if ! $HAS_STAGES || [ "$stage_slice_count" -eq 1 ]; then
    # Sequential execution: single slice or no explicit stages
    local_idx="${stage_indices[0]}"
    SLICE="${SLICES[$local_idx]}"

    echo -e "${BLUE}Running: Slice $((local_idx+1)) — ${SLICE}${NC}"

    dry_flag=""
    if [ "$DRY_RUN" = true ]; then
      dry_flag="--dry-run"
    fi
    if TASK_INDEX="$((local_idx+1))" TASK_TOTAL="$TOTAL" EPIC_NAME="$EPIC" \
         "$SCRIPT_DIR/run-task.sh" --no-commit ${dry_flag:+$dry_flag} "$SLICE"; then
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
  write_epic_status "COMPLETED_STAGES=${COMPLETED_STAGES}"
done

write_epic_status "STAGE=done" "COMPLETED_STAGES=${COMPLETED_STAGES}"

# Auto-merge epic branch to original on successful completion
finalize_epic_branch

echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}  EPIC COMPLETE: $EPIC${NC}"
echo -e "${GREEN}  All $STAGE_COUNT stage(s), $TOTAL slice(s) finished${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
