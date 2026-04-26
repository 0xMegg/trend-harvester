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
# Colors — defined before any function that references them so
# check_harness_version() and preflight_git_remote() below do
# not hit `unbound variable` under `set -u`. Do not move below
# function definitions.
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Bash 3.2+ required (macOS default). Reject older versions early.
if (( BASH_VERSINFO[0] < 3 )) || { (( BASH_VERSINFO[0] == 3 )) && (( BASH_VERSINFO[1] < 2 )); }; then
  echo "ERROR: run-epic.sh requires bash 3.2+. Current: $BASH_VERSION" >&2
  exit 1
fi

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
FORCE_RERUN=false
while [ $# -gt 0 ]; do
  case "${1:-}" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --force)
      FORCE_RERUN=true
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
# Harness version check — warning-only (no auto-sync).
# Compares local .harness-version stamp to template repo's stamp and
# auto-applies pending updates before the epic starts (Phase 2).
# Opt out with HARVEST_SKIP_UPDATE_CHECK=1 (warn only, no apply).
# ============================================================

_extract_forge_commit() {
  grep '^FORGE_COMMIT=' | head -1 | cut -d= -f2- | sed -e 's/^["'"'"']//' -e 's/["'"'"']$//'
}

_summarize_pending_updates() {
  local index_content="$1"
  local local_commit="$2"
  local in_table=0
  local line hash severity title
  while IFS= read -r line; do
    if [[ "$line" =~ ^\|[[:space:]]*-+ ]]; then
      in_table=1
      continue
    fi
    if [ "$in_table" = 1 ] && [[ "$line" != \|* ]]; then
      in_table=0
      continue
    fi
    [ "$in_table" = 1 ] || continue
    hash=$(echo "$line" | sed -n 's/.*\[\([a-f0-9]\{7,\}\)\](.*/\1/p')
    [ -z "$hash" ] && continue
    if [ "$hash" = "$local_commit" ]; then
      break
    fi
    severity=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$4); print $4}')
    title=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$6); print $6}')
    echo "  [${severity}] ${title} (${hash})"
  done <<< "$index_content"
}

check_harness_version() {
  local vfile="$PROJECT_DIR/.claude/.harness-version"
  local origin_file="$PROJECT_DIR/.claude/.harness-origin"

  # Auto-bootstrap: create missing files so first-time projects don't silently skip
  if [ ! -f "$vfile" ]; then
    echo -e "${YELLOW}⚠ .claude/.harness-version not found — creating bootstrap stamp${NC}" >&2
    mkdir -p "$(dirname "$vfile")"
    cat > "$vfile" << BVEOF
HARNESS_VERSION=4.0.0
FORGE_COMMIT=bootstrap
BUILD_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BVEOF
    echo -e "${GREEN}  ✓ Created .claude/.harness-version (bootstrap)${NC}" >&2
  fi

  # shellcheck disable=SC1090
  source "$vfile"
  echo -e "${CYAN}  Harness: v${HARNESS_VERSION:-?} (forge ${FORGE_COMMIT:-?}, built ${BUILD_TIMESTAMP:-?})${NC}" >&2

  # Auto-bootstrap: create .harness-origin with default template path
  if [ ! -f "$origin_file" ]; then
    echo -e "${YELLOW}⚠ .claude/.harness-origin not found — creating with default path${NC}" >&2
    mkdir -p "$(dirname "$origin_file")"
    cat > "$origin_file" << 'BOEOF'
# Harness template origin — used by scripts/upgrade-harness.sh.
# Edit TEMPLATE_REPO to match your local template repo path.
TEMPLATE_REPO=../claude-code-harness-template
BOEOF
    echo -e "${GREEN}  ✓ Created .claude/.harness-origin (edit TEMPLATE_REPO if needed)${NC}" >&2
  fi

  # shellcheck disable=SC1090
  source "$origin_file"
  local tmpl_repo="${TEMPLATE_REPO:-}"

  if [ -n "$tmpl_repo" ] && [[ "$tmpl_repo" != /* ]]; then
    tmpl_repo="$PROJECT_DIR/$tmpl_repo"
  fi

  if [ -z "$tmpl_repo" ] || [ ! -d "$tmpl_repo/.git" ]; then
    echo -e "${YELLOW}⚠ Template repo not found at: ${tmpl_repo:-<empty>} — version check skipped${NC}" >&2
    return 0
  fi

  if ! git -C "$tmpl_repo" fetch --quiet 2>/dev/null; then
    echo -e "${YELLOW}⚠ Could not fetch template repo updates (offline?) — version check skipped${NC}" >&2
    return 0
  fi

  local local_commit="${FORGE_COMMIT:-}"
  local template_forge_commit
  template_forge_commit=$(git -C "$tmpl_repo" show origin/main:.claude/.harness-version 2>/dev/null \
    | _extract_forge_commit)

  if [ -z "$template_forge_commit" ]; then
    echo -e "${YELLOW}⚠ Could not read template .harness-version — version check skipped${NC}" >&2
    return 0
  fi

  if [ "$local_commit" = "$template_forge_commit" ]; then
    echo -e "${GREEN}  ✓ Harness up-to-date (forge ${local_commit})${NC}" >&2
    return 0
  fi

  echo -e "${YELLOW}  ⚠ Harness out of date: forge ${local_commit} → ${template_forge_commit}${NC}" >&2

  local index_content pending
  index_content=$(git -C "$tmpl_repo" show "origin/main:docs/updates/INDEX.md" 2>/dev/null || echo "")
  if [ -n "$index_content" ]; then
    pending=$(_summarize_pending_updates "$index_content" "$local_commit")
    if [ -n "$pending" ]; then
      echo -e "${CYAN}  Pending updates:${NC}" >&2
      echo "$pending" >&2
    fi
  fi

  if [ "${HARVEST_SKIP_UPDATE_CHECK:-0}" = "1" ]; then
    echo -e "${YELLOW}    HARVEST_SKIP_UPDATE_CHECK=1 — apply skipped; run scripts/upgrade-harness.sh --apply manually${NC}" >&2
    return 0
  fi

  echo -e "${CYAN}  Auto-applying harness updates...${NC}" >&2
  if bash "$PROJECT_DIR/scripts/upgrade-harness.sh" --apply >&2; then
    echo -e "${GREEN}  ✓ Harness updated to forge ${template_forge_commit}${NC}" >&2
  else
    echo -e "${RED}  ✗ upgrade-harness.sh --apply failed — aborting epic${NC}" >&2
    echo -e "${RED}    Fix the reported issue or set HARVEST_SKIP_UPDATE_CHECK=1 to proceed with stale harness${NC}" >&2
    return 1
  fi
}
check_harness_version

# ============================================================
# Git repo discovery (multi-repo support) — must be defined
# before setup_epic_branch so the function can iterate repos.
# ============================================================
# If PROJECT_DIR is a git repo, returns PROJECT_DIR only.
# Otherwise, finds immediate child directories that are git repos.
discover_git_repos() {
  local root_is_git=false
  if [ -d "$PROJECT_DIR/.git" ] || git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    root_is_git=true
  fi

  # Always scan children for independent .git/ repos (hybrid mode support)
  local sub_repos=()
  for dir in "$PROJECT_DIR"/*/; do
    [ -d "$dir" ] || continue
    if [ -d "${dir}.git" ]; then
      if $root_is_git; then
        # Distinguish submodule from independent sub-repo
        local relpath
        relpath="${dir#"$PROJECT_DIR"/}"
        relpath="${relpath%/}"
        if git -C "$PROJECT_DIR" ls-files --error-unmatch "$relpath" >/dev/null 2>&1; then
          continue   # submodule — skip
        fi
      fi
      sub_repos+=("${dir%/}")
    fi
  done

  if $root_is_git; then
    echo "$PROJECT_DIR"
  fi
  if [ ${#sub_repos[@]} -gt 0 ]; then
    printf '%s\n' "${sub_repos[@]}"
  fi

  if ! $root_is_git && [ ${#sub_repos[@]} -eq 0 ]; then
    echo "WARNING: No git repos found under $PROJECT_DIR" >&2
    return 1
  fi
}

IS_MULTI_REPO=false
_repo_count=$(discover_git_repos 2>/dev/null | wc -l | tr -d ' ')
if [ "${_repo_count:-0}" -gt 1 ]; then
  IS_MULTI_REPO=true
elif ! [ -d "$PROJECT_DIR/.git" ] && ! git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  IS_MULTI_REPO=true
fi
unset _repo_count

# ============================================================
# Epic branch isolation — create epic/{RUN_ID} branch off main
# (skipped for dry-run, non-git, or HARVEST_ALLOW_MAIN=1)
# Multi-repo: creates epic branch in each sub-repo individually.
# ============================================================
EPIC_BRANCH=""
EPIC_ORIGINAL_BRANCH=""
EPIC_ORIGINAL_BRANCHES=()   # multi-repo: "repo_path|original_branch" entries
EPIC_KNOWN_REPOS=()         # repos known at setup_epic_branch time

# ============================================================
# Preflight: verify a git remote exists so end-of-run push operations
# don't silently fail and drop the epic's commits locally. Default:
# hard-exit if any repo has no remote. Escape hatch:
# `HARVEST_ALLOW_NO_REMOTE=1` for deliberately local-only runs.
# ============================================================
preflight_git_remote() {
  if [ "$DRY_RUN" = true ]; then return 0; fi
  if [ "${HARVEST_ALLOW_NO_REMOTE:-0}" = "1" ]; then return 0; fi

  local missing=()
  local repo_dir

  if $IS_MULTI_REPO; then
    while IFS= read -r repo_dir; do
      if ! (cd "$repo_dir" && git remote 2>/dev/null | grep -q .); then
        missing+=("$(basename "$repo_dir")")
      fi
    done < <(discover_git_repos)
  else
    if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      if ! git -C "$PROJECT_DIR" remote 2>/dev/null | grep -q .; then
        missing+=("$(basename "$PROJECT_DIR")")
      fi
    fi
  fi

  if [ ${#missing[@]} -gt 0 ]; then
    echo -e "${RED}✗ No git remote configured in: ${missing[*]}${NC}" >&2
    echo -e "${YELLOW}  Epic commits would stay local only — push operations silently drop them.${NC}" >&2
    echo -e "${YELLOW}  Add one:     cd <repo> && git remote add origin <URL>${NC}" >&2
    echo -e "${YELLOW}  Or bypass:   HARVEST_ALLOW_NO_REMOTE=1 bash scripts/run-epic.sh ...${NC}" >&2
    exit 1
  fi
}

setup_epic_branch() {
  if [ "$DRY_RUN" = true ]; then return 0; fi
  if [ "${HARVEST_ALLOW_MAIN:-0}" = "1" ]; then return 0; fi

  preflight_git_remote

  if $IS_MULTI_REPO; then
    # --- Multi-repo: create epic branch in each sub-repo ---

    # Warn about stale epic branches from previous runs
    while IFS= read -r repo_dir; do
      local stale
      stale=$(cd "$repo_dir" && git branch --list "epic/*" 2>/dev/null | tr -d ' ' || true)
      if [ -n "$stale" ]; then
        echo "WARN: stale epic branches in $(basename "$repo_dir"): $stale" >&2
        echo "  Clean up: cd $repo_dir && git branch -D $stale" >&2
      fi
    done < <(discover_git_repos)

    while IFS= read -r repo_dir; do
      cd "$repo_dir"
      local orig
      orig=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
      case "$orig" in
        main|master) ;;
        *) echo "[epic-branch] [$(basename "$repo_dir")] on $orig (non-main) — skipping"; continue ;;
      esac

      if [ -n "$(git status --porcelain)" ]; then
        echo "ERROR: working tree dirty in $(basename "$repo_dir") on $orig — commit/stash first or set HARVEST_ALLOW_MAIN=1" >&2
        cd "$PROJECT_DIR"
        exit 1
      fi

      git checkout -b "epic/${RUN_ID}" >/dev/null 2>&1
      EPIC_ORIGINAL_BRANCHES+=("${repo_dir}|${orig}")
      echo "[epic-branch] [$(basename "$repo_dir")] ${orig} → epic/${RUN_ID}"
    done < <(discover_git_repos)

    cd "$PROJECT_DIR"

    if [ ${#EPIC_ORIGINAL_BRANCHES[@]} -gt 0 ]; then
      EPIC_BRANCH="epic/${RUN_ID}"
    fi
  else
    # --- Single-repo: original logic ---
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

    # Warn about stale epic branches
    local stale
    stale=$(git branch --list "epic/*" 2>/dev/null | tr -d ' ' || true)
    if [ -n "$stale" ]; then
      echo "WARN: stale epic branches: $stale" >&2
      echo "  Clean up: git branch -D $stale" >&2
    fi

    EPIC_BRANCH="epic/${RUN_ID}"
    git checkout -b "$EPIC_BRANCH" >/dev/null 2>&1
    echo "[epic-branch] ${EPIC_ORIGINAL_BRANCH} → ${EPIC_BRANCH}"
  fi
}

finalize_epic_branch() {
  [ -z "$EPIC_BRANCH" ] && return 0
  [ "$DRY_RUN" = true ] && return 0

  if $IS_MULTI_REPO; then
    # --- Multi-repo: finalize each sub-repo ---
    for entry in "${EPIC_ORIGINAL_BRANCHES[@]}"; do
      local repo_dir="${entry%%|*}"
      local orig="${entry##*|}"
      cd "$repo_dir"

      git checkout "$orig" >/dev/null 2>&1 || {
        echo "WARN: [$(basename "$repo_dir")] cannot return to $orig — epic/${RUN_ID} preserved" >&2
        continue
      }
      if git merge --ff-only "epic/${RUN_ID}" >/dev/null 2>&1; then
        echo "[epic-branch] [$(basename "$repo_dir")] merged epic/${RUN_ID} → ${orig} (ff-only)"
        git push 2>/dev/null && echo "[epic-branch] [$(basename "$repo_dir")] pushed ${orig}" \
          || echo "[epic-branch] [$(basename "$repo_dir")] push skipped or failed — local merge kept"
        git branch -d "epic/${RUN_ID}" >/dev/null 2>&1 || true
      else
        echo "WARN: [$(basename "$repo_dir")] ff-only merge failed — leave epic/${RUN_ID} for manual review" >&2
        git checkout "epic/${RUN_ID}" >/dev/null 2>&1 || true
      fi
    done
    # Log repos created mid-epic (no epic branch to merge)
    while IFS= read -r repo_dir; do
      local is_known=false
      for kr in "${EPIC_KNOWN_REPOS[@]}"; do
        [ "$repo_dir" = "$kr" ] && is_known=true && break
      done
      if ! $is_known && [ -d "$repo_dir/.git" ]; then
        echo "[epic-branch] [$(basename "$repo_dir")] new repo — no epic branch, skipping finalize"
      fi
    done < <(discover_git_repos 2>/dev/null)
    cd "$PROJECT_DIR"
  else
    # --- Single-repo: original logic ---
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
  fi
}

setup_epic_branch

# Record repos known at setup time (used to detect mid-epic repo creation)
while IFS= read -r _kr; do
  EPIC_KNOWN_REPOS+=("$_kr")
done < <(discover_git_repos 2>/dev/null)

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

_sanitize_val() {
  # Enforce single-line status-file contract (see run-task.sh for rationale).
  local v="$1"
  local max_len="${2:-120}"
  v="${v//$'\n'/ }"
  v="${v//$'\r'/ }"
  while [[ "$v" == *"  "* ]]; do v="${v//  / }"; done
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  if [ "${#v}" -gt "$max_len" ]; then
    v="${v:0:$((max_len-14))}... (truncated)"
  fi
  printf '%s' "$v"
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
    val=$(_sanitize_val "$val")
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
  if echo "$line" | grep -qE "^#{3,4}[[:space:]]+(Task|Slice)[[:space:]]+[0-9]"; then
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
  exit 1
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
    # Parallel slices must declare Files for overlap detection
    echo -e "${RED}[overlap-gate] BLOCK: Stage $stage_num — parallel slices require Files declaration${NC}" >&2
    echo -e "${RED}  Add '- **Files:** file1, file2' to each slice in the epic plan.${NC}" >&2
    rm -f "$tmpfile"
    return 1
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

# classify_slice_repo — extract repo paths from a slice's Files list
# Args: slice_index
# Output: one repo path per line (deduplicated). Empty Files → all repos.
classify_slice_repo() {
  local idx="$1"
  local files="${SLICE_FILES[$idx]:-}"

  if [ -z "$files" ]; then
    discover_git_repos 2>/dev/null
    return
  fi

  local all_repos_file
  all_repos_file=$(mktemp -t harvest-repos.XXXXXX)
  discover_git_repos 2>/dev/null > "$all_repos_file"

  echo "$files" \
    | sed 's/`//g; s/\[//g; s/\]//g' \
    | tr ',' '\n' \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' \
    | sed '/^$/d' \
    | while IFS= read -r f; do
        local matched=false
        while IFS= read -r r; do
          local rname
          rname=$(basename "$r")
          if [[ "$f" == "${rname}/"* ]]; then
            echo "$r"
            matched=true
            break
          fi
        done < "$all_repos_file"
        if ! $matched && [ -d "$PROJECT_DIR/.git" ]; then
          echo "$PROJECT_DIR"
        fi
      done | sort -u

  rm -f "$all_repos_file"
}

# recover_dependencies — restore missing/stale deps after APPROVE'd slice skip
# Checks package.json → node_modules for each discovered repo.
recover_dependencies() {
  [ "$DRY_RUN" = true ] && return 0

  while IFS= read -r repo_dir; do
    if [ -f "$repo_dir/package.json" ]; then
      if [ ! -d "$repo_dir/node_modules" ]; then
        echo -e "${YELLOW}[dep-recover] $(basename "$repo_dir"): node_modules missing — running npm install${NC}"
        ( cd "$repo_dir" && npm install --no-audit --no-fund 2>&1 | tail -1 ) || \
          echo -e "${RED}[dep-recover] npm install failed in $(basename "$repo_dir")${NC}" >&2
      elif [ "$repo_dir/package.json" -nt "$repo_dir/node_modules/.package-lock.json" ] 2>/dev/null; then
        echo -e "${YELLOW}[dep-recover] $(basename "$repo_dir"): package.json newer — running npm install${NC}"
        ( cd "$repo_dir" && npm install --no-audit --no-fund 2>&1 | tail -1 ) || \
          echo -e "${RED}[dep-recover] npm install failed in $(basename "$repo_dir")${NC}" >&2
      fi
    fi
  done < <(discover_git_repos 2>/dev/null)
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
  git worktree remove --force "$wt_dir" >/dev/null 2>&1 || echo "WARNING: failed to remove worktree $wt_dir" >&2
  [ -n "$wt_branch" ] && { git branch -D "$wt_branch" >/dev/null 2>&1 || echo "WARNING: failed to delete branch $wt_branch" >&2; }

  # Tidy up empty parent directories left behind by setup_slice_worktree.
  # rmdir only succeeds when the directory is empty, so this is safe even if
  # other slices in the same stage are still running.
  rmdir "$(dirname "$wt_dir")" 2>/dev/null || true
  rmdir "$PROJECT_DIR/.harvest-wt" 2>/dev/null || true
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

  # Verdict cross-check (defense-in-depth) — grep every slice's review file
  # for the human-facing FINAL_VERDICT marker. The earlier task-status gate
  # checks VERDICT= but that field can drift from the review file (observed:
  # honbabseoul Epic 2 Slice 1, where REQUEST_CHANGES in the review went
  # unnoticed). Fail closed: if any review file is missing, unreadable, or
  # does not carry the APPROVE marker, abort the stage commit.
  local _vc_missing=()
  local _vc_not_approved=()
  for _vc_idx in "${indices[@]}"; do
    local _vc_desc="${SLICES[$_vc_idx]}"
    local _vc_num
    # Recognise both "Task N" and "Slice N(.M)" in one pass. Earlier the two
    # forms were two separate command substitutions and the first (Task) one
    # could exit 1 under `set -euo pipefail` when the slice description had
    # no "Task" prefix, aborting the whole script before reaching the Slice
    # fallback. Combined regex + `|| true` makes this trap-free.
    _vc_num=$(printf '%s' "$_vc_desc" \
      | grep -oE "([Tt]ask|[Ss]lice)[[:space:]]+[0-9]+(\.[0-9]+)?" \
      | grep -oE "[0-9]+(\.[0-9]+)?" \
      | head -1 || true)
    local _vc_review=""
    if [ -n "$_vc_num" ]; then
      for _vc_cand in \
        "$PROJECT_DIR/outputs/reviews/task-${_vc_num}-review.md" \
        "$PROJECT_DIR/outputs/reviews/task-slice-${_vc_num}-review.md" \
        "$PROJECT_DIR/outputs/reviews/slice-${_vc_num}-review.md"; do
        if [ -f "$_vc_cand" ]; then _vc_review="$_vc_cand"; break; fi
      done
    fi
    if [ -z "$_vc_review" ]; then
      _vc_missing+=("Slice $((_vc_idx+1)) (${_vc_desc}) — no review file found under outputs/reviews/")
      continue
    fi
    if ! grep -q '<!-- FINAL_VERDICT: APPROVE -->' "$_vc_review" 2>/dev/null; then
      local _vc_marker
      _vc_marker=$(grep -oE '<!-- FINAL_VERDICT: [A-Z_]+ -->' "$_vc_review" 2>/dev/null | tail -1 || true)
      _vc_marker="${_vc_marker:-<no marker>}"
      _vc_not_approved+=("$(basename "$_vc_review") — ${_vc_marker}")
    fi
  done
  if [ "${#_vc_missing[@]}" -gt 0 ] || [ "${#_vc_not_approved[@]}" -gt 0 ]; then
    echo -e "${RED}✗ Verdict cross-check failed for Stage $stage_num — refusing to commit${NC}" >&2
    for _vc_msg in "${_vc_missing[@]}";      do echo -e "  ${RED}missing:${NC}      $_vc_msg" >&2; done
    for _vc_msg in "${_vc_not_approved[@]}"; do echo -e "  ${RED}not APPROVE:${NC}  $_vc_msg" >&2; done
    echo -e "  ${YELLOW}Resolve every slice to FINAL_VERDICT: APPROVE before retrying.${NC}" >&2
    return 1
  fi
  unset _vc_missing _vc_not_approved _vc_idx _vc_desc _vc_num _vc_review _vc_cand _vc_marker _vc_msg

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

  # Re-discover repos (may include repos created mid-epic)
  local current_repos=()
  while IFS= read -r _cr; do
    current_repos+=("$_cr")
  done < <(discover_git_repos 2>/dev/null)

  # Log newly discovered repos
  for cr in "${current_repos[@]}"; do
    local is_known=false
    for kr in "${EPIC_KNOWN_REPOS[@]}"; do
      [ "$cr" = "$kr" ] && is_known=true && break
    done
    if ! $is_known; then
      echo -e "  ${YELLOW}[commit_stage] New repo detected: $(basename "$cr") (no epic branch)${NC}"
    fi
  done

  # Commit in each git repo that has changes
  for repo_dir in "${current_repos[@]}"; do
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
  done

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

  # Warn if parallel slices target the same repo (worktree recommended)
  if $IS_MULTI_REPO; then
    local repo_map_file
    repo_map_file=$(mktemp -t harvest-repo-map.XXXXXX)
    for idx in "${indices[@]}"; do
      while IFS= read -r repo_path; do
        echo "${repo_path}|${idx}" >> "$repo_map_file"
      done < <(classify_slice_repo "$idx")
    done
    local dup_repos
    dup_repos=$(awk -F'|' '{print $1}' "$repo_map_file" | sort | uniq -d)
    if [ -n "$dup_repos" ]; then
      while IFS= read -r dup_repo; do
        local slice_list
        slice_list=$(awk -F'|' -v r="$dup_repo" '$1 == r {print $2}' "$repo_map_file" | tr '\n' ' ')
        echo -e "${YELLOW}[parallel-warn] Same repo '$(basename "$dup_repo")' targeted by slices: ${slice_list}${NC}"
        echo -e "${YELLOW}  Consider HARVEST_PARALLEL_WORKTREE=1 for safe isolation${NC}"
      done <<< "$dup_repos"
    fi
    rm -f "$repo_map_file"
  fi

  # Per-slice worktree bookkeeping (only populated when WORKTREE_ENABLED=1)
  SLICE_WT_DIR=()

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

      # H2: Skip already-approved slices unless --force
      if [ "$FORCE_RERUN" = false ]; then
        local par_status="${task_log_dir}/task-status"
        if [ -f "$par_status" ]; then
          local pv=""
          pv=$(grep "^VERDICT=" "$par_status" 2>/dev/null | tail -1 | cut -d= -f2 | tr -d "'" || true)
          if [ "$pv" = "APPROVE" ]; then
            echo -e "  ${GREEN}Skip: Slice $((idx+1)) already APPROVE'd${NC}"
            recover_dependencies
            continue
          fi
        fi
      fi

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

    # H1: Health check — verify batch processes started (5s grace period)
    if [ ${#pids[@]} -gt 0 ]; then
      sleep 5
      for hc_idx in "${!pids[@]}"; do
        local hc_pid="${pids[$hc_idx]}"
        local hc_s_idx="${pid_to_idx[$hc_idx]}"
        local hc_log="${LOG_DIR}/task-slice-${hc_s_idx}/stdout.log"
        if ! kill -0 "$hc_pid" 2>/dev/null; then
          echo -e "  ${RED}WARNING: Slice $((hc_s_idx+1)) process died within 5s (PID $hc_pid)${NC}" >&2
        elif [ ! -f "$hc_log" ] || [ ! -s "$hc_log" ]; then
          echo -e "  ${YELLOW}WARNING: Slice $((hc_s_idx+1)) log empty after 5s — may be stuck${NC}" >&2
        fi
      done
    fi

    echo "  Waiting for batch to complete..."

    # D: Foreground progress monitor — polls task-status files every 10s inline
    #    (no background subshell, so output appears directly in the main stream)
    if [ ${#pids[@]} -gt 0 ] && [ "$DRY_RUN" = false ]; then
      local prev_states=""
      # Parallel-to-pids[] flag/code arrays. Indexed by p_idx (the same
      # index as pids[]), NOT by PID — keeps bash 3.2 compatibility, since
      # macOS ships bash 3.2 and `declare -A` is bash 4+ only.
      local _pid_done=()  # "1" once we have already reaped this slot
      local _pid_rc=()    # exit code captured at reap time (informational)

      while true; do
        # Check for newly finished PIDs (non-blocking via kill -0)
        local any_alive=false
        for p_idx in "${!pids[@]}"; do
          local pid="${pids[$p_idx]}"
          [ "${_pid_done[$p_idx]:-0}" = "1" ] && continue  # already reaped
          if ! kill -0 "$pid" 2>/dev/null; then
            # Process finished — reap immediately to collect exit code
            local wait_rc=0
            wait "$pid" || wait_rc=$?
            _pid_done[$p_idx]=1
            _pid_rc[$p_idx]=$wait_rc
            local s_idx="${pid_to_idx[$p_idx]}"
            if [ "$wait_rc" -eq 0 ]; then
              echo -e "  ${GREEN}✓ Slice $((s_idx+1)) complete${NC}"
            else
              echo -e "  ${RED}✗ Slice $((s_idx+1)) failed (exit $wait_rc)${NC}"
              all_ok=false
              failed_slices+=("$s_idx")
            fi
          else
            any_alive=true
          fi
        done

        # All done — exit the loop
        $any_alive || break

        # Read and display progress from task-status files
        local states=""
        for m_idx in "${pid_to_idx[@]}"; do
          local sf="${LOG_DIR}/task-slice-${m_idx}/task-status"
          if [ -f "$sf" ]; then
            local role="" iter="" verdict=""
            role=$(grep "^ROLE=" "$sf" 2>/dev/null | tail -1 | cut -d= -f2 | tr -d "'" || true)
            iter=$(grep "^ITER=" "$sf" 2>/dev/null | tail -1 | cut -d= -f2 | tr -d "'" || true)
            verdict=$(grep "^VERDICT=" "$sf" 2>/dev/null | tail -1 | cut -d= -f2 | tr -d "'" || true)
            states="${states}  S$((m_idx+1)):${role:-?}"
            [ -n "$iter" ] && [ "$iter" != "1" ] && states="${states}(i${iter})"
            [ -n "$verdict" ] && states="${states}→${verdict}"
          else
            states="${states}  S$((m_idx+1)):init"
          fi
        done
        if [ "$states" != "$prev_states" ]; then
          echo -e "  ${CYAN}[progress]${states}${NC}"
          prev_states="$states"
        fi

        sleep 10
      done
    elif [ "$DRY_RUN" = true ]; then
      # Dry-run: just wait for all PIDs sequentially
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
    fi

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

    # H2: Skip already-approved slices unless --force
    if [ "$FORCE_RERUN" = false ]; then
      seq_status="${LOG_DIR}/task-slice-${local_idx}/task-status"
      if [ -f "$seq_status" ]; then
        prev_verdict=$(grep "^VERDICT=" "$seq_status" 2>/dev/null | tail -1 | cut -d= -f2 | tr -d "'" || true)
        if [ "$prev_verdict" = "APPROVE" ]; then
          echo -e "  ${GREEN}Skip: Slice $((local_idx+1)) already APPROVE'd${NC}"
          recover_dependencies
          COMPLETED_STAGES=$((COMPLETED_STAGES+1))
          write_epic_status "COMPLETED_STAGES=${COMPLETED_STAGES}"
          continue
        fi
      fi
    fi

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
      # M6: Sync handoff after sequential stage completion
      merge_stage_handoffs "$stage_num" "$local_idx"
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
    recover_dependencies
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

# Enforce Terminal Audit Slice gate (if an audit report exists for this epic).
# An audit report that says "Verdict: ITERATE" or Blocker>0 must fail the
# whole epic — otherwise the wrapper marks success while real blockers remain
# (kody Epic 7: 14/14 APPROVE with audit Blocker=2 shipped as green).
if [ "$DRY_RUN" != true ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  ACCEPT_REPORT=$(find "$PROJECT_DIR/outputs/reviews" -type f \
    \( -name "*${RUN_ID}*audit*" -o -name "*${EPIC}*audit*" -o -name "*epic*audit*" \) \
    -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -1 || true)
  if [ -n "$ACCEPT_REPORT" ] && [ -f "$SCRIPT_DIR/acceptance-check.sh" ]; then
    echo ""
    echo -e "${CYAN}Terminal audit gate check: $ACCEPT_REPORT${NC}"
    if ! bash "$SCRIPT_DIR/acceptance-check.sh" "$ACCEPT_REPORT"; then
      echo -e "${RED}✗ Epic acceptance FAILED — audit report reports blockers${NC}" >&2
      echo -e "${RED}  See: $ACCEPT_REPORT${NC}" >&2
      echo -e "${RED}  Epic branch kept for review; not auto-merged.${NC}" >&2
      exit 1
    fi
  fi
fi

# Auto-merge epic branch to original on successful completion
finalize_epic_branch

echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}  EPIC COMPLETE: $EPIC${NC}"
echo -e "${GREEN}  All $STAGE_COUNT stage(s), $TOTAL slice(s) finished${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
