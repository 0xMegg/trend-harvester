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
# Colors — defined before any function that references them so
# check_harness_version() below does not hit `unbound variable`
# under `set -u`. Do not move below function definitions.
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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
# PHASE_MODE: which phases to run. "all" runs the full Plan→Develop→Review
# pipeline (default, backward-compatible). "plan" / "develop" / "review" run
# a single phase so each invocation fits inside Claude Code's 10-minute Bash
# tool timeout — divebase Task 52.1 was killed mid-run because the monolithic
# call exceeded that limit. Single-phase callers reuse $STATUS_FILE for state.
PHASE_MODE="all"
RESUME_MODE=false

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
    --phase)
      PHASE_MODE="${2:-all}"
      shift 2
      ;;
    --phase=*)
      PHASE_MODE="${1#--phase=}"
      shift
      ;;
    --resume)
      RESUME_MODE=true
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

case "$PHASE_MODE" in
  all|plan|develop|review) ;;
  *)
    echo "Error: --phase must be one of: all, plan, develop, review (got: $PHASE_MODE)" >&2
    exit 1
    ;;
esac

if ! [[ "$MAX_ITER" =~ ^[0-9]+$ ]] || [ "$MAX_ITER" -lt 1 ]; then
  echo "Error: --max-iter must be a positive integer (got: $MAX_ITER)"
  exit 1
fi

TASK="$*"

# In --resume mode the task description is recovered from $STATUS_FILE below,
# so empty $TASK is allowed here. Other modes still require it up-front.
if [ -z "$TASK" ] && [ "$RESUME_MODE" != true ]; then
  echo "Usage: $0 [--task-id <id>] [--no-commit] [--dry-run] [--max-iter N] [--phase plan|develop|review|all] [--resume] <task description>"
  echo "Example: $0 Task 1 — Fix empty form submission bug in signup"
  echo "Example: $0 --task-id slice-1 Task 1 — Signup form"
  echo "Example: $0 --max-iter 3 Task 1 — Login UI (iterate up to 3 times)"
  echo "Example: $0 --dry-run Task 1 — Smoke test (no tokens spent)"
  echo "Example: $0 --phase plan Task 52.1 — split run (avoids 10-min Bash tool timeout)"
  echo "Example: $0 --resume Task 52.1 — pick up where the previous run left off"
  exit 1
fi

mkdir -p "$LOG_DIR"

# ============================================================
# Harness version check — auto-applies pending updates before task starts.
# Skipped when launched by run-epic.sh (EPIC_NAME is set) to avoid a
# duplicate check. Set HARVEST_SKIP_UPDATE_CHECK=1 to opt out (warn only).
# ============================================================

# Read FORGE_COMMIT from a .harness-version content passed on stdin.
# Strips optional surrounding single or double quotes (build-template.sh
# writes bare, but be defensive).
_extract_forge_commit() {
  grep '^FORGE_COMMIT=' | head -1 | cut -d= -f2- | sed -e 's/^["'"'"']//' -e 's/["'"'"']$//'
}

# Parse template's docs/updates/INDEX.md, emit one line per update that
# lies above (= newer than) the local FORGE_COMMIT in the table.
# Format of emitted lines: "  [SEVERITY] TITLE (HASH)"
#
# INDEX.md table row format:
#   | 2026-04-23 | [hash](./hash.md) | P0 | fix | title | no |
_summarize_pending_updates() {
  local index_content="$1"
  local local_commit="$2"
  local in_table=0
  local line hash severity title
  # Read line by line
  while IFS= read -r line; do
    # Table header separator line: |---|---|...
    if [[ "$line" =~ ^\|[[:space:]]*-+ ]]; then
      in_table=1
      continue
    fi
    # Non-table line ends current table
    if [ "$in_table" = 1 ] && [[ "$line" != \|* ]]; then
      in_table=0
      continue
    fi
    [ "$in_table" = 1 ] || continue
    # Parse row: extract hash from [hash](./hash.md), then fields 3 and 5 (severity, title)
    hash=$(echo "$line" | sed -n 's/.*\[\([a-f0-9]\{7,\}\)\](.*/\1/p')
    [ -z "$hash" ] && continue
    # If we reached local commit, stop (all updates above are pending)
    if [ "$hash" = "$local_commit" ]; then
      break
    fi
    # Split pipe fields, extract severity (col 3) and title (col 5)
    severity=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$4); print $4}')
    title=$(echo "$line" | awk -F'|' '{gsub(/^ +| +$/,"",$6); print $6}')
    echo "  [${severity}] ${title} (${hash})"
  done <<< "$index_content"
}

check_harness_version() {
  if [ -n "${EPIC_NAME:-}" ]; then return 0; fi  # epic already checked
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
  # Compare forge commits on both sides (fixes pre-Phase-2 bug of
  # comparing local forge hash to template repo's own hash).
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

  # Out of date — list pending updates + auto-apply
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

  # Opt-out for debugging / offline inspection
  if [ "${HARVEST_SKIP_UPDATE_CHECK:-0}" = "1" ]; then
    echo -e "${YELLOW}    HARVEST_SKIP_UPDATE_CHECK=1 — apply skipped; run scripts/upgrade-harness.sh --apply manually${NC}" >&2
    return 0
  fi

  # Auto-apply
  echo -e "${CYAN}  Auto-applying harness updates...${NC}" >&2
  if bash "$PROJECT_DIR/scripts/upgrade-harness.sh" --apply >&2; then
    echo -e "${GREEN}  ✓ Harness updated to forge ${template_forge_commit}${NC}" >&2
  else
    echo -e "${RED}  ✗ upgrade-harness.sh --apply failed — aborting task${NC}" >&2
    echo -e "${RED}    Fix the reported issue or set HARVEST_SKIP_UPDATE_CHECK=1 to proceed with stale harness${NC}" >&2
    return 1
  fi
}
check_harness_version

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

log_task_entry() {
  # Append a structured log line to ~/Dev/13.claude/logs/YYYY-MM-DD.md
  # Called on EVERY task completion — success or failure.
  [ "$DRY_RUN" = true ] && return 0

  local log_home="${TASK_LOG_HOME:-$HOME/Dev/13.claude/logs}"
  mkdir -p "$log_home"

  local now_hhmm
  now_hhmm=$(date +%H:%M)
  local now_hour
  now_hour=$(date +%H | sed 's/^0//')

  # 오전 9시 경계 규칙: 00:00~08:59 → 전날 파일에 기록
  local log_date
  if [ "$now_hour" -lt 9 ]; then
    log_date=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)
  else
    log_date=$(date +%Y-%m-%d)
  fi

  local log_file="${log_home}/${log_date}.md"
  local proj="${PROJECT_NAME}"
  local verdict="${VERDICT:-UNKNOWN}"
  local task_desc="${TASK:-untitled}"

  # 소요 시간 계산 (from STATUS_FILE's START_EPOCH)
  local elapsed_str="0:00"
  if [ -f "$STATUS_FILE" ]; then
    local _start_epoch
    _start_epoch=$(grep '^START_EPOCH=' "$STATUS_FILE" 2>/dev/null | tail -1 | sed "s/^START_EPOCH=//; s/^'//; s/'$//" || true)
    if [ -n "$_start_epoch" ]; then
      local _now_epoch
      _now_epoch=$(date +%s)
      local _el=$(( _now_epoch - _start_epoch ))
      local _mm=$(( _el / 60 ))
      local _ss=$(( _el % 60 ))
      elapsed_str=$(printf '%d:%02d' "$_mm" "$_ss")
    fi
  fi

  # 로그 라인 작성
  printf -- '- [%s] **%s** %s — %s (%s)\n' \
    "$now_hhmm" "$proj" "$task_desc" "$verdict" "$elapsed_str" \
    >> "$log_file"

  echo "[log] entry appended: $log_file"
}

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

_sanitize_val() {
  # Enforce the status-file contract: each value must be single-line.
  # Collapse newlines/CR to spaces and truncate overlong strings.
  # Without this, a multiline value breaks `grep -v "^KEY="` rewrite
  # (removes only the first line, rest becomes raw script that
  # `source $STATUS_FILE` later tries to execute → syntax error).
  # The full original $TASK stays in-process; the status file is
  # a display/monitor artifact, not a source of truth for prompts.
  local v="$1"
  local max_len="${2:-120}"
  v="${v//$'\n'/ }"
  v="${v//$'\r'/ }"
  while [[ "$v" == *"  "* ]]; do v="${v//  / }"; done
  # Trim leading/trailing spaces
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  if [ "${#v}" -gt "$max_len" ]; then
    v="${v:0:$((max_len-14))}... (truncated)"
  fi
  printf '%s' "$v"
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
    val=$(_sanitize_val "$val")
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
  # Extract task/slice number from $TASK description for file naming; fallback
  # to "dryrun". Recognises both "Task N" and "Slice N(.M)" forms so Epic-mode
  # callers (which pass slice descriptions) do not get coerced into "dryrun".
  # `|| true` absorbs grep no-match so `set -euo pipefail` does not abort here.
  local task_num
  task_num=$(printf '%s' "$TASK" \
    | grep -oE "([Tt]ask|[Ss]lice)[[:space:]]+[0-9]+(\.[0-9]+)?" \
    | grep -oE "[0-9]+(\.[0-9]+)?" \
    | head -1 || true)
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
# Resume — recover $TASK and pick the next PHASE_MODE from $STATUS_FILE
# so a crash mid-pipeline does not force the user to re-run earlier phases.
# Avoids the divebase Task 52.1 fallout where Plan + Develop succeeded but
# the 10-min Bash timeout killed the script before Review could launch.
# ============================================================
if [ "$RESUME_MODE" = true ]; then
  if [ ! -f "$STATUS_FILE" ]; then
    echo -e "${RED}Error: --resume requires $STATUS_FILE (no prior run found)${NC}" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  ( source "$STATUS_FILE"; printf 'TASK=%s\nROLE=%s\nVERDICT=%s\n' \
      "${TASK_NAME:-}" "${ROLE:-}" "${VERDICT:-}" ) > "${STATUS_FILE}.resume.$$"
  _resume_task=$(grep '^TASK=' "${STATUS_FILE}.resume.$$" | sed 's/^TASK=//')
  _resume_role=$(grep '^ROLE=' "${STATUS_FILE}.resume.$$" | sed 's/^ROLE=//')
  _resume_verdict=$(grep '^VERDICT=' "${STATUS_FILE}.resume.$$" | sed 's/^VERDICT=//')
  rm -f "${STATUS_FILE}.resume.$$"

  [ -z "$TASK" ] && TASK="$_resume_task"
  if [ -z "$TASK" ]; then
    echo -e "${RED}Error: --resume cannot recover TASK from status file${NC}" >&2
    exit 1
  fi

  case "$_resume_role" in
    plan)        PHASE_MODE="develop" ;;
    develop)     PHASE_MODE="review"  ;;
    review|done)
      # Already past review — re-run review only. APPROVE just finalises again
      # (idempotent push), other verdicts let the user retry the review pass.
      PHASE_MODE="review"
      ;;
    failed)
      echo -e "${RED}Error: previous run failed (VERDICT=${_resume_verdict:-?}). Inspect ${LOG_DIR}/ and resolve manually before --resume.${NC}" >&2
      exit 1
      ;;
    *)
      echo -e "${YELLOW}WARN: unknown ROLE='${_resume_role}' in status file — running full pipeline${NC}" >&2
      PHASE_MODE="all"
      ;;
  esac
  echo -e "${CYAN}[resume] last role=${_resume_role:-?} verdict=${_resume_verdict:-?} → PHASE_MODE=${PHASE_MODE} TASK=${TASK}${NC}"
  unset _resume_task _resume_role _resume_verdict
fi

# ============================================================
# Set up task branch before any work (standalone mode only)
# ============================================================
setup_task_branch

# ============================================================
# Initialize status file (inherits EPIC_NAME/TASK_INDEX/TASK_TOTAL from env
# when launched by run-epic.sh; otherwise runs in standalone task mode).
# Resume preserves the original START_EPOCH so elapsed-time stays cumulative.
# ============================================================
if [ "$RESUME_MODE" = true ] && [ -f "$STATUS_FILE" ]; then
  write_status \
    "TASK_NAME=${TASK}" \
    "ROLE=resuming" \
    "VERDICT="
else
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
fi

echo -e "${CYAN}[phase-mode] ${PHASE_MODE}${NC}"

# ============================================================
# Phase 1: Plan (skipped unless PHASE_MODE = all|plan)
# ============================================================
if [ "$PHASE_MODE" = "all" ] || [ "$PHASE_MODE" = "plan" ]; then
  write_status "ROLE=plan" "ITER=1"
  log_phase "PHASE 1/3: PLAN"

  if ! run_claude "plan" "/plan $TASK"; then
    log_fail "Plan phase failed. Check ${LOG_DIR}/plan.log"
    write_status "ROLE=failed" "VERDICT=PLAN_FAILED"
    log_task_entry
    exit 1
  fi

  log_success "Plan phase complete"
fi

# Plan-only mode terminates here. The next call (typically
# `run-task.sh --phase develop "$TASK"`) picks up from the produced plan file.
if [ "$PHASE_MODE" = "plan" ]; then
  write_status "ROLE=plan" "VERDICT=PLAN_DONE"
  log_task_entry
  echo ""
  echo -e "${GREEN}════════════════════════════════════════${NC}"
  echo -e "${GREEN}  PLAN PHASE COMPLETE — exit early (--phase=plan)${NC}"
  echo -e "${GREEN}  Next: $0 --phase develop \"$TASK\"${NC}"
  echo -e "${GREEN}════════════════════════════════════════${NC}"
  exit 0
fi

# ============================================================
# Phase 2-3: Develop → Review (with iteration loop)
# In --phase=review mode, the Develop block is skipped and the loop runs once.
# ============================================================
ITER=1
VERDICT=""
EFFECTIVE_MAX_ITER="$MAX_ITER"
case "$PHASE_MODE" in
  review|develop) EFFECTIVE_MAX_ITER=1 ;;
esac

while [ "$ITER" -le "$EFFECTIVE_MAX_ITER" ]; do
  # --phase=review skips Develop entirely — the working tree is assumed to
  # carry the prior Develop output already.
  if [ "$PHASE_MODE" = "review" ]; then
    write_status "ROLE=review" "ITER=${ITER}"
    log_phase "PHASE 3/3: REVIEW (review-only mode)"
    REVIEW_LOG="${LOG_DIR}/review-iter${ITER}.log"
    if ! run_claude "review-iter${ITER}" "/review $TASK"; then
      log_fail "Review phase failed. Check ${REVIEW_LOG}"
      write_status "ROLE=failed" "VERDICT=REVIEW_FAILED"
      log_task_entry
      exit 1
    fi
  else
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

  # Snapshot working-tree + HEAD before Develop, so we can detect a silent
  # no-op (claude session that exited 0 without touching anything — the
  # Slice 4 "Developer phase never ran" failure mode observed in the wild).
  DEVELOP_PRE_STATE="$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null)|$(git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null)"
  DEVELOP_PRE_HEAD="$(git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null || echo "")"

  # Override log file for iteration tracking
  if ! run_claude "develop-iter${ITER}" "$DEVELOP_PROMPT"; then
    log_fail "Develop phase failed (iter ${ITER}). Check ${DEVELOP_LOG}"
    write_status "ROLE=failed" "VERDICT=DEVELOP_FAILED"
    log_task_entry
    exit 1
  fi

  # Detect develop-phase no-op: same working-tree porcelain + same HEAD.
  # Empty PRE_STATE (e.g. PROJECT_DIR not in a git repo) skips the check
  # so non-git workspaces are not falsely flagged.
  DEVELOP_POST_STATE="$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null)|$(git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null)"
  if [ -n "$DEVELOP_PRE_STATE" ] && [ "$DEVELOP_PRE_STATE" = "$DEVELOP_POST_STATE" ]; then
    log_fail "Develop phase exited cleanly but produced NO observable changes."
    log_fail "  Working tree + HEAD identical pre/post — likely a silent claude session failure."
    log_fail "  See ${DEVELOP_LOG}."
    write_status "ROLE=failed" "VERDICT=DEVELOP_NOOP"
    log_task_entry
    exit 1
  fi

  log_success "Develop phase complete (iter ${ITER})"

  # --- Scope-leak detector (warn-only) ---
  # Enumerate files Develop just touched (uncommitted + any committed since
  # DEVELOP_PRE_HEAD) and compare against the slice's plan Files list. Files
  # outside the plan get appended to the handoff under ## Unplanned changes
  # so the Reviewer (and the next Planner) can see them. This is a signal,
  # not a gate — the verdict cross-check in run-epic.sh blocks bad commits.
  if [ -n "$DEVELOP_PRE_HEAD" ] && [ "$ITER" -eq 1 ]; then
    _scope_changed=$( {
      _post_head=$(git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null || echo "")
      if [ -n "$_post_head" ] && [ "$DEVELOP_PRE_HEAD" != "$_post_head" ]; then
        git -C "$PROJECT_DIR" diff --name-only "$DEVELOP_PRE_HEAD" "$_post_head" 2>/dev/null
      fi
      git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | awk '{print $NF}'
    } | sort -u | sed '/^$/d' )
    # Extract task/slice number from $TASK. Earlier forms only matched "Task N",
    # which made Epic-mode callers (TASK="Slice 1: foo") fail under
    # `set -euo pipefail` because grep no-match exited 1 and aborted the
    # whole script before PHASE 3/3 REVIEW could run (honbabseoul Epic 3).
    # Recognise both forms and tolerate no-match via `|| true`.
    _scope_task_num=$(printf '%s' "$TASK" \
      | grep -oE "([Tt]ask|[Ss]lice)[[:space:]]+[0-9]+(\.[0-9]+)?" \
      | grep -oE "[0-9]+(\.[0-9]+)?" \
      | head -1 || true)
    _scope_plan_file="$PROJECT_DIR/outputs/plans/task-${_scope_task_num:-unknown}-plan.md"
    _scope_planned=""
    if [ -n "$_scope_task_num" ] && [ -f "$_scope_plan_file" ]; then
      # Extract files from "## Scope" → "- Files to modify:" line. Strip
      # surrounding brackets, split commas, trim whitespace. Falls through to
      # empty (skip) if the plan does not follow templates/plan.md format.
      _scope_planned=$(awk '/^- Files to modify:/{sub(/^- Files to modify:[[:space:]]*/,""); gsub(/[][]/,""); gsub(/,/,"\n"); print; exit}' "$_scope_plan_file" \
        | awk '{$1=$1; print}' | sed '/^$/d' | sort -u)
    fi
    if [ -n "$_scope_changed" ] && [ -n "$_scope_planned" ]; then
      _scope_unplanned=$(comm -23 <(printf '%s\n' "$_scope_changed") <(printf '%s\n' "$_scope_planned"))
      if [ -n "$_scope_unplanned" ]; then
        log_warn "Develop touched files outside plan Files list — see handoff ## Unplanned changes"
        {
          echo ""
          echo "## Unplanned changes (auto-detected $(date -u +%Y-%m-%dT%H:%M:%SZ))"
          echo ""
          echo "Plan file: outputs/plans/task-${_scope_task_num}-plan.md"
          echo "Files Develop touched but plan did not authorise:"
          echo ""
          printf '%s\n' "$_scope_unplanned" | sed 's/^/- /'
          echo ""
          echo "Developer: mark each as \`keep — <reason>\` or \`drop — <reason>\` before /review."
        } >> "${PROJECT_DIR}/${HANDOFF_FILE}" 2>/dev/null || true
      fi
    fi
    unset _scope_changed _scope_task_num _scope_plan_file _scope_planned _scope_unplanned _post_head
  fi

  # Develop-only mode terminates here so the next call (typically
  # `run-task.sh --phase review "$TASK"`) can run the review pass inside
  # a fresh 10-min Bash tool window.
  if [ "$PHASE_MODE" = "develop" ]; then
    write_status "ROLE=develop" "VERDICT=DEVELOP_DONE"
    log_task_entry
    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}  DEVELOP PHASE COMPLETE — exit early (--phase=develop)${NC}"
    echo -e "${GREEN}  Next: $0 --phase review \"$TASK\"${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    exit 0
  fi

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
    log_task_entry
    exit 1
  fi
  fi  # end: $PHASE_MODE branching (review-only vs develop+review)

  # Check verdict — search only the tail of the review log to avoid
  # false positives from earlier context (e.g. "fixed previous REQUEST_CHANGES").
  # Structured markers (<!-- FINAL_VERDICT: X -->) are checked first.
  VERDICT_TAIL=$(tail -40 "$REVIEW_LOG" 2>/dev/null || true)

  if echo "$VERDICT_TAIL" | grep -q '<!-- FINAL_VERDICT: APPROVE -->'; then
    log_success "Review verdict: APPROVE (iter ${ITER}) [marker]"
    VERDICT="APPROVE"
    break
  elif echo "$VERDICT_TAIL" | grep -q '<!-- FINAL_VERDICT: REQUEST_CHANGES -->'; then
    log_fail "Review verdict: REQUEST_CHANGES (iter ${ITER}) [marker]"
    write_status "ROLE=done" "VERDICT=REQUEST_CHANGES"
    log_task_entry
    echo ""
    echo "Review output: $REVIEW_LOG"
    echo ""
    echo "Next steps:"
    echo "  1. Read the review: cat $REVIEW_LOG"
    echo "  2. Fix: /develop $TASK — REQUEST_CHANGES fix"
    echo "  3. Re-review: /review $TASK"
    exit 1
  elif echo "$VERDICT_TAIL" | grep -q '<!-- FINAL_VERDICT: ITERATE -->'; then
    if [ "$ITER" -lt "$MAX_ITER" ]; then
      log_warn "Review verdict: ITERATE (iter ${ITER}/${MAX_ITER}) [marker] — refining..."
      write_status "VERDICT=ITERATE"
      ITER=$((ITER + 1))
      continue
    else
      log_warn "Review verdict: ITERATE but max iterations reached (${MAX_ITER})"
      log_warn "Accepting current state. Manual refinement may be needed."
      VERDICT="ITERATE_EXHAUSTED"
      break
    fi
  elif echo "$VERDICT_TAIL" | grep -qi "APPROVE"; then
    log_success "Review verdict: APPROVE (iter ${ITER})"
    VERDICT="APPROVE"
    break
  elif echo "$VERDICT_TAIL" | grep -qi "REQUEST_CHANGES\|request.changes"; then
    log_fail "Review verdict: REQUEST_CHANGES (iter ${ITER})"
    write_status "ROLE=done" "VERDICT=REQUEST_CHANGES"
    log_task_entry
    echo ""
    echo "Review output: $REVIEW_LOG"
    echo ""
    echo "Next steps:"
    echo "  1. Read the review: cat $REVIEW_LOG"
    echo "  2. Fix: /develop $TASK — REQUEST_CHANGES fix"
    echo "  3. Re-review: /review $TASK"
    exit 1
  elif echo "$VERDICT_TAIL" | grep -qi "ITERATE"; then
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
  else
    # No recognized verdict — treat as done
    log_warn "No clear verdict detected in review log"
    VERDICT="UNKNOWN"
    break
  fi
done

write_status "ROLE=done" "VERDICT=${VERDICT}"
log_task_entry

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
