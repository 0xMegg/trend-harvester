#!/bin/bash
# check-harness-regression.sh — pre-build regression gate for src/scripts/.
#
# Catches the failure modes that have repeatedly slipped through recent
# self-improvement rounds:
#   - bash syntax errors (Round 1: bash3 array compat)
#   - `set -euo pipefail` traps from grep no-match (Round 2: scope-leak
#     detector aborted before PHASE 3/3 REVIEW when TASK="Slice 1: ...")
#   - dry-run smoke regressions (Round 2: task_num extraction in
#     dry_run_write_artifacts shared the same broken grep pattern)
#
# Run before `build-template.sh` so a regression never reaches downstream
# projects via the upgrade-harness flow.
#
# Usage:  bash src/scripts/check-harness-regression.sh
# Exit:   0 = all checks passed
#         2 = bash syntax error
#         3 = shellcheck warning (only when HARNESS_STRICT_SHELLCHECK=1)
#         4 = smoke test failed

set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$SRC_DIR/scripts"

cyan='\033[0;36m'; green='\033[0;32m'; yellow='\033[0;33m'; red='\033[0;31m'; nc='\033[0m'

echo -e "${cyan}[regression] bash -n on src/scripts/*.sh${nc}"
_synerr=0
for f in "$SCRIPTS_DIR"/*.sh; do
  if ! bash -n "$f" 2>&1; then
    echo -e "  ${red}✗ syntax error: $f${nc}" >&2
    _synerr=1
  fi
done
[ "$_synerr" -ne 0 ] && exit 2
echo -e "  ${green}✓ syntax OK${nc}"

if command -v shellcheck >/dev/null 2>&1; then
  echo -e "${cyan}[regression] shellcheck on src/scripts/*.sh${nc}"
  # -S warning suppresses style/info noise; the goal is to catch real bugs.
  if ! shellcheck -S warning "$SCRIPTS_DIR"/*.sh; then
    if [ "${HARNESS_STRICT_SHELLCHECK:-0}" = "1" ]; then
      echo -e "  ${red}✗ shellcheck warnings (HARNESS_STRICT_SHELLCHECK=1)${nc}" >&2
      exit 3
    fi
    echo -e "  ${yellow}⚠ shellcheck warnings detected — non-fatal (set HARNESS_STRICT_SHELLCHECK=1 to fail)${nc}"
  else
    echo -e "  ${green}✓ shellcheck clean${nc}"
  fi
else
  echo -e "${cyan}[regression] shellcheck not installed — skipped${nc}"
fi

echo -e "${cyan}[regression] smoke test — Task / Slice naming patterns${nc}"

# Each case gets its own TMPDIR so the dry-run DRYRUN-NOTES.md append in case
# A does not show up as a working-tree change in case B (which would then
# tickle run-task.sh's DEVELOP_NOOP detector — false positive).
SMOKE_ROOT=$(mktemp -d -t harness-regression.XXXXXX)
# shellcheck disable=SC2064
trap "rm -rf '$SMOKE_ROOT'" EXIT

# Two task descriptions — both must complete dry-run without aborting.
# The "Slice 1 ..." form is the exact regression that killed honbabseoul Epic 3.
_smoke_idx=0
for TASK_DESC in "Task 9999 — smoke test" "Slice 1 — smoke test"; do
  _smoke_idx=$((_smoke_idx + 1))
  _case="$SMOKE_ROOT/case-${_smoke_idx}"
  mkdir -p "$_case/scripts" "$_case/outputs/plans" "$_case/outputs/reviews" \
           "$_case/handoff" "$_case/.claude" "$_case/templates"

  cp "$SCRIPTS_DIR"/*.sh "$_case/scripts/"
  if [ -f "$SRC_DIR/templates/evaluation.md" ]; then
    cp "$SRC_DIR/templates/evaluation.md" "$_case/templates/evaluation.md"
  fi
  echo "# Smoke test handoff" > "$_case/handoff/latest.md"

  (
    cd "$_case"
    git init -q
    git -c user.email="smoke@regression" -c user.name="smoke" commit -q --allow-empty -m "init"
  )

  _logfile="$SMOKE_ROOT/case-${_smoke_idx}.log"
  if ! (
    cd "$_case"
    PROJECT_NAME="harness-smoke-${_smoke_idx}" \
      HARVEST_ALLOW_MAIN=1 \
      HARVEST_SKIP_UPDATE_CHECK=1 \
      bash scripts/run-task.sh --dry-run "$TASK_DESC"
  ) > "$_logfile" 2>&1; then
    echo -e "  ${red}✗ smoke FAILED for: $TASK_DESC${nc}" >&2
    echo -e "  ${red}  log tail:${nc}" >&2
    tail -40 "$_logfile" >&2
    exit 4
  fi
done
echo -e "  ${green}✓ smoke OK (Task / Slice both pass)${nc}"

echo -e "${green}[regression] all checks passed${nc}"
