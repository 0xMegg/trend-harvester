#!/bin/bash
# harness-report.sh — Measure harness quality score
#
# Usage:
#   ./scripts/harness-report.sh         # Full report
#   ./scripts/harness-report.sh quick   # Quick mode (skip tests)
#
# Outputs a JSON score to stdout and optionally updates harvest/baseline.json
#
# Scoring (max 100):
#   Rules coverage:     0-20  (rules files exist and have content)
#   Skills coverage:    0-20  (skills with SKILL.md + examples)
#   Hooks coverage:     0-15  (pre/post hooks present and executable)
#   Templates quality:  0-15  (templates filled, not just placeholders)
#   Evaluation records: 0-10  (completed evaluations exist)
#   Test/Lint pass:     0-20  (tests and lint pass, skip in quick mode)

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-full}"
SCORE=0
BREAKDOWN="{}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# Helper: add to score and breakdown
# ============================================================
add_score() {
  local category="$1"
  local points="$2"
  local max="$3"
  local detail="$4"

  SCORE=$((SCORE + points))
  BREAKDOWN=$(echo "$BREAKDOWN" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['$category'] = {'score': $points, 'max': $max, 'detail': '$detail'}
print(json.dumps(d))
" 2>/dev/null || echo "$BREAKDOWN")
}

# ============================================================
# 1. Rules Coverage (0-20)
# ============================================================
echo -e "${CYAN}Checking rules coverage...${NC}" >&2

rules_score=0
rules_dir="$PROJECT_DIR/.claude/rules"
if [ -d "$rules_dir" ]; then
  rule_count=$(find "$rules_dir" -name '*.md' -type f | wc -l | tr -d ' ')
  # 1 point per rule file, max 10
  file_points=$((rule_count > 10 ? 10 : rule_count))

  # Check if rules have actual content (not just placeholders)
  content_points=0
  for f in "$rules_dir"/*.md; do
    [ -f "$f" ] || continue
    # Count non-empty, non-placeholder lines
    real_lines=$(grep -cvE '^\s*$|^\s*#|{{.*}}' "$f" 2>/dev/null || echo 0)
    if [ "$real_lines" -gt 3 ]; then
      content_points=$((content_points + 2))
    fi
  done
  content_points=$((content_points > 10 ? 10 : content_points))

  rules_score=$((file_points + content_points))
  rules_score=$((rules_score > 20 ? 20 : rules_score))
fi
add_score "rules" "$rules_score" 20 "${rule_count:-0} files"
echo -e "  Rules: ${rules_score}/20" >&2

# ============================================================
# 2. Skills Coverage (0-20)
# ============================================================
echo -e "${CYAN}Checking skills coverage...${NC}" >&2

skills_score=0
skills_dir="$PROJECT_DIR/.claude/skills"
if [ -d "$skills_dir" ]; then
  skill_count=0
  skill_with_examples=0
  for skill in "$skills_dir"/*/; do
    [ -d "$skill" ] || continue
    if [ -f "${skill}SKILL.md" ]; then
      skill_count=$((skill_count + 1))
      # 5 points per skill with SKILL.md, max 15
      if [ -d "${skill}examples" ]; then
        skill_with_examples=$((skill_with_examples + 1))
      fi
    fi
  done

  base=$((skill_count * 5 > 15 ? 15 : skill_count * 5))
  example_bonus=$((skill_with_examples > 0 ? 5 : 0))
  skills_score=$((base + example_bonus))
  skills_score=$((skills_score > 20 ? 20 : skills_score))
fi
add_score "skills" "$skills_score" 20 "${skill_count:-0} skills, ${skill_with_examples:-0} with examples"
echo -e "  Skills: ${skills_score}/20" >&2

# ============================================================
# 3. Hooks Coverage (0-15)
# ============================================================
echo -e "${CYAN}Checking hooks coverage...${NC}" >&2

hooks_score=0
hooks_dir="$PROJECT_DIR/.claude/hooks"
if [ -d "$hooks_dir" ]; then
  hook_count=$(find "$hooks_dir" -name '*.sh' -type f | wc -l | tr -d ' ')
  executable_count=$(find "$hooks_dir" -name '*.sh' -type f -perm +111 | wc -l | tr -d ' ')

  # 3 points per hook, max 12
  hook_points=$((hook_count * 3 > 12 ? 12 : hook_count * 3))
  # 3 bonus if all hooks are executable
  exec_bonus=0
  if [ "$hook_count" -gt 0 ] && [ "$hook_count" -eq "$executable_count" ]; then
    exec_bonus=3
  fi

  hooks_score=$((hook_points + exec_bonus))
  hooks_score=$((hooks_score > 15 ? 15 : hooks_score))
fi
add_score "hooks" "$hooks_score" 15 "${hook_count:-0} hooks, ${executable_count:-0} executable"
echo -e "  Hooks: ${hooks_score}/15" >&2

# ============================================================
# 4. Templates Quality (0-15)
# ============================================================
echo -e "${CYAN}Checking templates quality...${NC}" >&2

templates_score=0
templates_dir="$PROJECT_DIR/templates"
if [ -d "$templates_dir" ]; then
  template_count=$(find "$templates_dir" -name '*.md' -type f | wc -l | tr -d ' ')
  filled_count=0
  for f in "$templates_dir"/*.md; do
    [ -f "$f" ] || continue
    placeholder_count=$(grep -c '{{.*}}' "$f" 2>/dev/null || true)
    placeholder_count=${placeholder_count:-0}
    placeholder_count=$(echo "$placeholder_count" | tr -d '[:space:]')
    total_lines=$(wc -l < "$f" | tr -d '[:space:]')
    if [ "$total_lines" -gt 5 ] && [ "$placeholder_count" -lt 3 ]; then
      filled_count=$((filled_count + 1))
    fi
  done

  # 3 points per template, max 9
  base=$((template_count * 2 > 9 ? 9 : template_count * 2))
  # Bonus for filled templates
  fill_bonus=$((filled_count * 2 > 6 ? 6 : filled_count * 2))

  templates_score=$((base + fill_bonus))
  templates_score=$((templates_score > 15 ? 15 : templates_score))
fi
add_score "templates" "$templates_score" 15 "${template_count:-0} templates, ${filled_count:-0} filled"
echo -e "  Templates: ${templates_score}/15" >&2

# ============================================================
# 5. Evaluation Records (0-10)
# ============================================================
echo -e "${CYAN}Checking evaluation records...${NC}" >&2

eval_score=0
eval_dir="$PROJECT_DIR/outputs/evaluations"
if [ -d "$eval_dir" ]; then
  eval_count=$(find "$eval_dir" -name '*.md' -type f | wc -l | tr -d ' ')
  # 2 points per evaluation, max 10
  eval_score=$((eval_count * 2 > 10 ? 10 : eval_count * 2))
fi
add_score "evaluations" "$eval_score" 10 "${eval_count:-0} records"
echo -e "  Evaluations: ${eval_score}/10" >&2

# ============================================================
# 6. Test/Lint Pass (0-20) — skip in quick mode
# ============================================================
echo -e "${CYAN}Checking test/lint pass...${NC}" >&2

test_score=0
if [ "$MODE" = "quick" ]; then
  test_score=0
  add_score "test_lint" 0 20 "skipped (quick mode)"
  echo -e "  Test/Lint: ${YELLOW}skipped (quick mode)${NC}" >&2
else
  lint_pass=0
  test_pass=0

  # Check if shellcheck is available and scripts pass
  if command -v shellcheck &>/dev/null; then
    script_count=0
    pass_count=0
    for f in "$PROJECT_DIR/scripts/"*.sh; do
      [ -f "$f" ] || continue
      script_count=$((script_count + 1))
      if shellcheck -S warning "$f" &>/dev/null; then
        pass_count=$((pass_count + 1))
      fi
    done
    if [ "$script_count" -gt 0 ]; then
      lint_pass=$((pass_count * 10 / script_count))
    fi
  else
    lint_pass=5  # Partial credit if shellcheck not installed
  fi

  # Check if project has tests and they pass
  if [ -f "$PROJECT_DIR/package.json" ]; then
    if npm test --prefix "$PROJECT_DIR" &>/dev/null 2>&1; then
      test_pass=10
    fi
  elif [ -f "$PROJECT_DIR/pubspec.yaml" ]; then
    if (cd "$PROJECT_DIR" && dart test) &>/dev/null 2>&1; then
      test_pass=10
    fi
  else
    test_pass=5  # No test framework detected, partial credit
  fi

  test_score=$((lint_pass + test_pass))
  test_score=$((test_score > 20 ? 20 : test_score))
  add_score "test_lint" "$test_score" 20 "lint:${lint_pass}/10 test:${test_pass}/10"
  echo -e "  Test/Lint: ${test_score}/20" >&2
fi

# ============================================================
# Output
# ============================================================
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "" >&2
if [ "$SCORE" -ge 80 ]; then
  echo -e "${GREEN}HARNESS SCORE: ${SCORE}/100${NC}" >&2
elif [ "$SCORE" -ge 50 ]; then
  echo -e "${YELLOW}HARNESS SCORE: ${SCORE}/100${NC}" >&2
else
  echo -e "${RED}HARNESS SCORE: ${SCORE}/100${NC}" >&2
fi

# JSON output to stdout
RESULT=$(python3 -c "
import json
breakdown = json.loads('$BREAKDOWN')
result = {
    'score': $SCORE,
    'max': 100,
    'mode': '$MODE',
    'timestamp': '$TIMESTAMP',
    'breakdown': breakdown
}
print(json.dumps(result, indent=2))
" 2>/dev/null || echo "{\"score\": $SCORE, \"max\": 100, \"mode\": \"$MODE\", \"timestamp\": \"$TIMESTAMP\"}")

echo "$RESULT"

# Update baseline if harvest/ exists
BASELINE_FILE="$PROJECT_DIR/harvest/baseline.json"
if [ -d "$PROJECT_DIR/harvest" ]; then
  echo "$RESULT" > "$BASELINE_FILE"
  echo -e "\n${GREEN}✓ Baseline updated: $BASELINE_FILE${NC}" >&2
fi
