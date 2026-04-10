#!/bin/bash
# run-harvest.sh — Trend-harvester 6-Phase pipeline orchestrator
#
# Usage:
#   ./scripts/run-harvest.sh                              # Full pipeline (Phase 0-5)
#   ./scripts/run-harvest.sh scan                         # Phase 1 only (collection)
#   ./scripts/run-harvest.sh judge                        # Phase 3-3.5 only (measurement + autoresearch)
#   ./scripts/run-harvest.sh status                       # Show current status
#   ./scripts/run-harvest.sh validate "description"       # Manual input → Phase 1-M+2 → STOP for review
#   ./scripts/run-harvest.sh validate --file path.json    # Manual input from file → Phase 1-M+2 → STOP
#   ./scripts/run-harvest.sh validate --auto "description" # Manual input → Phase 1-M through 5 (no pause)
#
# This script orchestrates the pipeline structure.
# LLM-powered phases (analysis, scoring) are delegated to Claude Code skills
# via `claude -p` invocations.

set -euo pipefail

# ============================================================
# Configuration
# ============================================================
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
CLAUDE_TOOLS="--allowedTools Write,Read,Edit,Bash,WebFetch,WebSearch,Glob,Grep"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HARVEST_DIR="$PROJECT_DIR/harvest"
CONFIG_FILE="$HARVEST_DIR/config.json"
LOCK_FILE="$HARVEST_DIR/.lock"
SEEN_FILE="$HARVEST_DIR/.seen.json"
BASELINE_FILE="$HARVEST_DIR/baseline.json"
MODE="${1:-full}"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
VALIDATE_INPUT=""
VALIDATE_FILE=""
MANUAL_ID=""
VALIDATE_AUTO=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ "$MODE" = "validate" ]; then
  shift
  # Check for --auto flag
  if [ "${1:-}" = "--auto" ]; then
    VALIDATE_AUTO=true
    shift
  fi
  if [ "${1:-}" = "--file" ]; then
    VALIDATE_FILE="${2:-}"
    if [ -z "$VALIDATE_FILE" ] || [ ! -f "$VALIDATE_FILE" ]; then
      echo -e "${RED}✗ File not found: ${VALIDATE_FILE:-<empty>}${NC}"
      exit 1
    fi
    VALIDATE_INPUT="$(cat "$VALIDATE_FILE")"
  elif [ "${1:-}" = "-" ]; then
    VALIDATE_INPUT="$(cat)"
  else
    VALIDATE_INPUT="$*"
  fi
  if [ -z "$VALIDATE_INPUT" ]; then
    echo -e "${RED}✗ Usage: run-harvest.sh validate [--auto] \"description\" | --file path.json | -${NC}"
    exit 1
  fi
fi

log_phase() {
  echo ""
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo -e "${CYAN}  $1${NC}"
  echo -e "${CYAN}════════════════════════════════════════${NC}"
  echo ""
}

# ============================================================
# Preflight checks
# ============================================================
if [ ! -f "$CONFIG_FILE" ]; then
  echo -e "${RED}✗ harvest/config.json not found${NC}"
  echo "Initialize with: cp src/harvest/config.json harvest/config.json"
  exit 1
fi

# Check if enabled
ENABLED=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['enabled'])" 2>/dev/null || echo "false")
if [ "$ENABLED" != "True" ] && [ "$ENABLED" != "true" ]; then
  echo -e "${YELLOW}Harvest pipeline is disabled in config.json${NC}"
  exit 0
fi

# ============================================================
# Status mode (no lock needed)
# ============================================================
if [ "$MODE" = "status" ]; then
  echo -e "${CYAN}Harvest Status${NC}"
  echo ""

  # Baseline
  if [ -f "$BASELINE_FILE" ]; then
    score=$(python3 -c "import json; print(json.load(open('$BASELINE_FILE'))['score'])" 2>/dev/null || echo "?")
    ts=$(python3 -c "import json; print(json.load(open('$BASELINE_FILE'))['timestamp'])" 2>/dev/null || echo "?")
    echo -e "  Baseline: ${GREEN}${score}/100${NC} (${ts})"
  else
    echo -e "  Baseline: ${YELLOW}not measured yet${NC}"
  fi

  # Last run
  latest_report=$(find "$HARVEST_DIR/reports" -name '*.md' -type f 2>/dev/null | sort | tail -1)
  if [ -n "$latest_report" ]; then
    echo "  Last report: $(basename "$latest_report")"
  else
    echo -e "  Last report: ${YELLOW}none${NC}"
  fi

  # Pending
  pending_count=$(find "$HARVEST_DIR/applied" -name 'pending-*.json' -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$pending_count" -gt 0 ]; then
    echo -e "  Pending approval: ${YELLOW}${pending_count}${NC}"
  else
    echo "  Pending approval: 0"
  fi

  # Applied count
  applied_count=$(find "$HARVEST_DIR/applied" -name '*.json' -not -name 'pending-*' -type f 2>/dev/null | wc -l | tr -d ' ')
  echo "  Applied total: $applied_count"

  # Seen count
  if [ -f "$SEEN_FILE" ]; then
    seen_count=$(python3 -c "import json; print(len(json.load(open('$SEEN_FILE'))))" 2>/dev/null || echo "?")
    echo "  Seen items: $seen_count"
  fi

  exit 0
fi

# ============================================================
# Phase 0: Execution Guard
# ============================================================
log_phase "PHASE 0: EXECUTION GUARD"

# Lock check
if [ -f "$LOCK_FILE" ]; then
  lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
  if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
    echo -e "${RED}✗ Another harvest is running (PID: $lock_pid)${NC}"
    exit 1
  else
    echo -e "${YELLOW}! Stale lock found, removing${NC}"
    rm -f "$LOCK_FILE"
  fi
fi

# Cooldown check — skip for manual validate mode
if [ "$MODE" != "validate" ]; then
  COOLDOWN_MIN=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('cooldown_minutes', 60))" 2>/dev/null || echo 60)
  latest_report=$(find "$HARVEST_DIR/reports" -name '*.md' -type f 2>/dev/null | sort | tail -1)
  if [ -n "$latest_report" ]; then
    # Check if file was modified within cooldown period
    file_age_min=$(( ($(date +%s) - $(stat -f %m "$latest_report" 2>/dev/null || stat -c %Y "$latest_report" 2>/dev/null || echo 0)) / 60 ))
    if [ "$file_age_min" -lt "$COOLDOWN_MIN" ]; then
      echo -e "${YELLOW}Cooldown active: last run ${file_age_min}min ago (cooldown: ${COOLDOWN_MIN}min)${NC}"
      echo "Use './scripts/run-harvest.sh status' to check current state"
      exit 0
    fi
  fi
fi

# Acquire lock
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT INT TERM

echo -e "${GREEN}✓ Guard passed, lock acquired (PID: $$)${NC}"

# ============================================================
# Phase 1-M: Manual Input Ingestion (validate mode only)
# ============================================================
if [ "$MODE" = "validate" ]; then
  log_phase "PHASE 1-M: MANUAL INPUT INGESTION"

  mkdir -p "$HARVEST_DIR/raw"

  # Initialize seen file if missing
  if [ ! -f "$SEEN_FILE" ]; then
    echo "{}" > "$SEEN_FILE"
  fi

  # Generate slug from input (first 30 chars, lowercase, alphanumeric+hyphens)
  SLUG=$(echo "$VALIDATE_INPUT" | head -c 60 | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | head -c 30)
  MANUAL_ID="manual-${RUN_ID}-${SLUG}"
  RAW_FILE="$HARVEST_DIR/raw/${MANUAL_ID}.json"

  # Create raw entry via Claude
  echo "Ingesting manual input..."
  "$CLAUDE_BIN" $CLAUDE_TOOLS -p "Create a harvest raw entry from the following manual input.

Input: ${VALIDATE_INPUT}

Write a JSON file to harvest/raw/${MANUAL_ID}.json with this structure:
{
  \"id\": \"${MANUAL_ID}\",
  \"source\": \"manual\",
  \"source_type\": \"manual\",
  \"title\": \"<extract or generate a concise title from the input>\",
  \"description\": \"<the full input, cleaned up>\",
  \"url\": null,
  \"collected_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
  \"trust_level\": \"high\",
  \"status\": \"raw\"
}
If the input contains a URL, extract it into the url field.
Only write the JSON file, nothing else." \
    --output-format text \
    > "$HARVEST_DIR/raw/${MANUAL_ID}-ingest.log" 2>&1 || true

  if [ -f "$RAW_FILE" ]; then
    echo -e "${GREEN}✓ Manual input saved: ${MANUAL_ID}${NC}"
    item_count=1
  else
    echo -e "${RED}✗ Failed to create raw entry (check harvest/raw/${MANUAL_ID}-ingest.log)${NC}"
    exit 1
  fi
fi

# ============================================================
# Phase 1: Collection (scan mode starts here)
# ============================================================
if [ "$MODE" = "full" ] || [ "$MODE" = "scan" ]; then
  log_phase "PHASE 1: COLLECTION"

  RAW_FILE="$HARVEST_DIR/raw/${RUN_ID}.jsonl"
  mkdir -p "$HARVEST_DIR/raw"

  # Initialize seen file if missing
  if [ ! -f "$SEEN_FILE" ]; then
    echo "{}" > "$SEEN_FILE"
  fi

  # Delegate collection to Claude with the trend-harvest skill
  echo "Collecting from configured sources..."
  "$CLAUDE_BIN" $CLAUDE_TOOLS -p "Read harvest/config.json and collect trends from all enabled sources. For each item, output a JSON line to harvest/raw/${RUN_ID}.jsonl with fields: {title, url, description, source_type}. Check harvest/.seen.json for duplicates (by URL hash). Skip duplicates." \
    --output-format text \
    > "$HARVEST_DIR/raw/${RUN_ID}-collect.log" 2>&1 || true

  if [ -f "$RAW_FILE" ]; then
    item_count=$(wc -l < "$RAW_FILE" | tr -d ' ')
    echo -e "${GREEN}✓ Collected $item_count new items${NC}"
  else
    echo -e "${YELLOW}! No items collected (check harvest/raw/${RUN_ID}-collect.log)${NC}"
    item_count=0
  fi

  if [ "$MODE" = "scan" ]; then
    echo -e "\n${GREEN}Scan complete. Run './scripts/run-harvest.sh' for full pipeline.${NC}"
    exit 0
  fi
fi

# ============================================================
# Phase 2: Analysis
# ============================================================
if [ "$MODE" = "full" ] || [ "$MODE" = "validate" ]; then
  log_phase "PHASE 2: ANALYSIS"

  mkdir -p "$HARVEST_DIR/analyzed" "$HARVEST_DIR/rejected"

  if [ "${item_count:-0}" -gt 0 ]; then
    if [ "$MODE" = "validate" ]; then
      echo "Analyzing manual input with fitness-filter..."
      "$CLAUDE_BIN" $CLAUDE_TOOLS -p "Read harvest/raw/${MANUAL_ID}.json. Apply the fitness-filter skill (5-axis scoring). This is a manual input with trust_level: high. If score >= 6: save to harvest/analyzed/${MANUAL_ID}-passed.json. If score < 6: save to harvest/rejected/${MANUAL_ID}.json with reasons. Read CLAUDE.md, .claude/rules/gotchas.md, and harvest/config.json for context." \
        --output-format text \
        > "$HARVEST_DIR/analyzed/${MANUAL_ID}-analysis.log" 2>&1 || true
    else
      echo "Analyzing collected items with fitness-filter..."
      "$CLAUDE_BIN" $CLAUDE_TOOLS -p "Read harvest/raw/${RUN_ID}.jsonl. For each item, apply the fitness-filter skill (5-axis scoring). Items scoring >= 6: save to harvest/analyzed/${RUN_ID}-passed.json. Items scoring < 6: save to harvest/rejected/${RUN_ID}-rejected.json with reasons. Read CLAUDE.md, .claude/rules/gotchas.md, and harvest/config.json for context." \
        --output-format text \
        > "$HARVEST_DIR/analyzed/${RUN_ID}-analysis.log" 2>&1 || true
    fi
    echo -e "${GREEN}✓ Analysis complete${NC}"
  else
    echo -e "${YELLOW}No items to analyze${NC}"
  fi

  # ── Human Review Gate (validate mode only, unless --auto) ──
  if [ "$MODE" = "validate" ] && [ "$VALIDATE_AUTO" = false ]; then
    echo ""
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${CYAN}  PHASE 2 REVIEW CHECKPOINT${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo ""

    # Show analyzed result
    PASSED_FILE="$HARVEST_DIR/analyzed/${MANUAL_ID}-passed.json"
    REJECTED_FILE="$HARVEST_DIR/rejected/${MANUAL_ID}.json"

    if [ -f "$PASSED_FILE" ]; then
      echo -e "${GREEN}✓ Proposal PASSED fitness filter${NC}"
      echo ""
      python3 -c "
import json, sys
data = json.load(open('$PASSED_FILE'))
items = data if isinstance(data, list) else [data]
for item in items:
    print(f\"  Title:       {item.get('title', 'N/A')}\")
    f = item.get('fitness', {})
    print(f\"  Score:       {f.get('total', '?')}/10\")
    print(f\"  Automation:  {f.get('automation', '?')}  Friction: {f.get('friction', '?')}  HARD: {f.get('hard_conversion', '?')}  Token: {f.get('token_efficiency', '?')}  Measure: {f.get('measurability', '?')}\")
    print(f\"  Target:      {item.get('target_file', 'N/A')}\")
    print(f\"  Change type: {item.get('change_type', 'N/A')}\")
    print(f\"  Risk:        {item.get('risk', 'N/A')}\")
    print()
" 2>/dev/null || echo "  (Run 'cat $PASSED_FILE' to see full details)"
      echo ""
      echo -e "  Full details: ${PASSED_FILE}"
    elif [ -f "$REJECTED_FILE" ]; then
      echo -e "${RED}✗ Proposal REJECTED by fitness filter${NC}"
      echo ""
      python3 -c "
import json
data = json.load(open('$REJECTED_FILE'))
items = data if isinstance(data, list) else [data]
for item in items:
    print(f\"  Title:  {item.get('title', 'N/A')}\")
    print(f\"  Reason: {item.get('reason', item.get('rejection_reason', 'N/A'))}\")
" 2>/dev/null || echo "  (Run 'cat $REJECTED_FILE' to see details)"
    else
      echo -e "${YELLOW}! No analysis output found${NC}"
      echo "  Check: $HARVEST_DIR/analyzed/${MANUAL_ID}-analysis.log"
    fi

    echo ""
    echo -e "${YELLOW}Review the result above, then:${NC}"
    echo -e "  Continue → ${GREEN}./scripts/run-harvest.sh judge${NC}"
    echo -e "  Discard  → no action needed"
    echo ""
    exit 0
  fi
fi

# ============================================================
# Phase 3: Baseline Measurement
# ============================================================
if [ "$MODE" = "full" ] || [ "$MODE" = "judge" ] || [ "$MODE" = "validate" ]; then
  log_phase "PHASE 3: BASELINE MEASUREMENT"

  echo "Measuring current harness score..."
  MEASURE_CMD=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('measurement', {}).get('command', 'bash scripts/harness-report.sh quick'))" 2>/dev/null || echo "bash scripts/harness-report.sh quick")
  (cd "$PROJECT_DIR" && bash -c "$MEASURE_CMD") > /dev/null 2>&1
  baseline_score=$(python3 -c "import json; print(json.load(open('$BASELINE_FILE'))['score'])" 2>/dev/null || echo 0)
  echo -e "${GREEN}✓ Baseline: ${baseline_score}/100${NC}"
fi

# ============================================================
# Phase 3.5: Autoresearch Judge
# ============================================================
if [ "$MODE" = "full" ] || [ "$MODE" = "judge" ] || [ "$MODE" = "validate" ]; then
  log_phase "PHASE 3.5: AUTORESEARCH JUDGE"

  if [ "$MODE" = "validate" ]; then
    JUDGE_TARGET="harvest/analyzed/${MANUAL_ID}-passed.json"
  else
    JUDGE_TARGET="harvest/analyzed/"
  fi

  echo "Testing proposals with double-gating..."
  "$CLAUDE_BIN" $CLAUDE_TOOLS -p "Read ${JUDGE_TARGET} for proposals that passed Phase 2 (score >= 6). For each proposal:
1. Run 'git stash' to save current state
2. Apply the proposed change temporarily
3. Run 'bash scripts/harness-report.sh quick' and compare with harvest/baseline.json
4. If new score >= baseline: mark as KEEP
5. If new score < baseline: mark as DISCARD
6. Run 'git checkout -- .' to revert, then 'git stash pop' to restore
7. Update the proposal with the verdict
Write results to harvest/analyzed/ with verdicts." \
    --output-format text \
    > "$HARVEST_DIR/analyzed/${RUN_ID}-judge.log" 2>&1 || true
  echo -e "${GREEN}✓ Autoresearch judge complete${NC}"

  if [ "$MODE" = "judge" ]; then
    echo -e "\n${GREEN}Judge complete. Run './scripts/run-harvest.sh' for full pipeline.${NC}"
    exit 0
  fi
fi

# ============================================================
# Phase 4: Apply Decision
# ============================================================
if [ "$MODE" = "full" ] || [ "$MODE" = "validate" ]; then
  log_phase "PHASE 4: APPLY DECISION"

  mkdir -p "$HARVEST_DIR/applied"

  if [ "$MODE" = "validate" ]; then
    APPLY_SOURCE="harvest/analyzed/${MANUAL_ID}-passed.json"
    APPLY_LOG="${MANUAL_ID}"
  else
    APPLY_SOURCE="harvest/analyzed/"
    APPLY_LOG="${RUN_ID}"
  fi

  echo "Applying approved proposals per harvest-policy.md..."
  "$CLAUDE_BIN" $CLAUDE_TOOLS -p "Read context/harvest-policy.md and ${APPLY_SOURCE} for proposals marked as KEEP.
For each proposal:
- If it meets auto-apply criteria (rule/scaffold-rule, score >= 7, risk low): apply the change and record in harvest/applied/${APPLY_LOG}-applied.json
- Otherwise: save to harvest/applied/pending-${APPLY_LOG}.json for manual approval
After applying, update harvest/.seen.json with all processed items.
Do NOT use git reset --hard. For auto-applied changes, commit with message 'chore: harvest — [description]'." \
    --output-format text \
    > "$HARVEST_DIR/applied/${APPLY_LOG}-apply.log" 2>&1 || true
  echo -e "${GREEN}✓ Apply decisions made${NC}"
fi

# ============================================================
# Phase 5: Report
# ============================================================
if [ "$MODE" = "full" ] || [ "$MODE" = "validate" ]; then
  log_phase "PHASE 5: REPORT"

  mkdir -p "$HARVEST_DIR/reports"

  if [ "$MODE" = "validate" ]; then
    REPORT_ID="${MANUAL_ID}"
    REPORT_LABEL="MANUAL VALIDATION COMPLETE"
    FILE_GLOB="${MANUAL_ID}"
  else
    REPORT_ID="${RUN_ID}"
    REPORT_LABEL="HARVEST COMPLETE"
    FILE_GLOB="${RUN_ID}"
  fi

  REPORT_FILE="$HARVEST_DIR/reports/${REPORT_ID}.md"

  # Re-measure after applies
  echo "Final measurement..."
  MEASURE_CMD=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('measurement', {}).get('command', 'bash scripts/harness-report.sh quick'))" 2>/dev/null || echo "bash scripts/harness-report.sh quick")
  (cd "$PROJECT_DIR" && bash -c "$MEASURE_CMD") > /dev/null 2>&1
  final_score=$(python3 -c "import json; print(json.load(open('$BASELINE_FILE'))['score'])" 2>/dev/null || echo 0)

  echo "Generating report..."
  "$CLAUDE_BIN" $CLAUDE_TOOLS -p "Generate a harvest report using templates/harvest-report.md format.
Read harvest/raw/${FILE_GLOB}*, harvest/analyzed/${FILE_GLOB}*, harvest/applied/${FILE_GLOB}*, and harvest/rejected/${FILE_GLOB}*.
Baseline was ${baseline_score:-0}/100, final is ${final_score}/100, delta is $((${final_score:-0} - ${baseline_score:-0})).
Write the report to harvest/reports/${REPORT_ID}.md" \
    --output-format text \
    > "$HARVEST_DIR/reports/${REPORT_ID}-generate.log" 2>&1 || true

  # Output provider handling
  PROVIDER=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('output', {}).get('provider', 'log-only'))" 2>/dev/null || echo "log-only")

  if [ "$PROVIDER" = "obsidian" ]; then
    VAULT_PATH=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c['output']['obsidian']['vault_path'])" 2>/dev/null || echo "")
    FOLDER=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c['output']['obsidian'].get('folder', 'harvest-reports'))" 2>/dev/null || echo "harvest-reports")
    if [ -n "$VAULT_PATH" ] && [ -d "$VAULT_PATH" ]; then
      mkdir -p "$VAULT_PATH/$FOLDER"
      cp "$REPORT_FILE" "$VAULT_PATH/$FOLDER/" 2>/dev/null || true
      echo -e "${GREEN}✓ Report copied to Obsidian vault${NC}"
    fi
  fi

  echo ""
  echo -e "${GREEN}════════════════════════════════════════${NC}"
  echo -e "${GREEN}  ${REPORT_LABEL}${NC}"
  echo -e "${GREEN}  Score: ${baseline_score:-?} → ${final_score}/100 (Δ $((${final_score:-0} - ${baseline_score:-0})))${NC}"
  echo -e "${GREEN}  Report: harvest/reports/${REPORT_ID}.md${NC}"
  echo -e "${GREEN}════════════════════════════════════════${NC}"
fi
