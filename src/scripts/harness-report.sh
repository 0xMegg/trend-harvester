#!/bin/bash
# harness-report.sh — Measure harness quality score
#
# Usage:
#   ./scripts/harness-report.sh                      # Full report
#   ./scripts/harness-report.sh quick                # Quick mode (skip tests)
#   ./scripts/harness-report.sh quick --target src/  # Measure a subtree
#
# Outputs a JSON score to stdout and optionally updates harvest/baseline.json
#
# Scoring (max 100, redesigned 2026-04-11 to defeat saturation):
#   Rules         : 0-20  (file count + content depth in lines)
#   Skills        : 0-15  (skill count + examples + Gotchas section depth)
#   Hooks         : 0-15  (file count + executable + HARD exit enforcement)
#   Guidance      : 0-10  (context/ + docs/ file count + content depth)  [NEW]
#   Scripts       : 0-10  (file count + HARD exit/pipefail enforcement)  [NEW]
#   Templates     : 0-10  (file count + filled ratio)
#   Evaluations   : 0-10  (completed evaluation records)
#   Test/Lint     : 0-10  (lint + test pass, skip in quick mode)
#
# Rationale: the old scheme saturated at rules 15/20, skills 20/20, hooks 15/15,
# templates 15/15 for the current src/ template, defeating Gate 2 discrimination.
# Depth-based metrics + new Guidance/Scripts categories restore movement.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Parse arguments: [quick|full] [--target <path>]
MODE="full"
TARGET_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    quick|full) MODE="$1"; shift ;;
    --target) TARGET_DIR="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# TARGET_DIR: the harness root to measure
# If --target is relative, resolve from PROJECT_DIR
if [ -n "$TARGET_DIR" ]; then
  if [[ "$TARGET_DIR" != /* ]]; then
    TARGET_DIR="$PROJECT_DIR/$TARGET_DIR"
  fi
else
  TARGET_DIR="$PROJECT_DIR"
fi

# Verify target exists
if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: target directory not found: $TARGET_DIR" >&2
  exit 1
fi

echo "Measuring: $TARGET_DIR" >&2

SCORE=0
BREAKDOWN="{}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# Helpers
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

# Count non-blank, non-pure-placeholder lines in a single file
count_effective_lines() {
  local file="$1"
  [ -f "$file" ] || { echo 0; return; }
  grep -cvE '^[[:space:]]*$|^[[:space:]]*\{\{[^}]*\}\}[[:space:]]*$' "$file" 2>/dev/null || echo 0
}

# Sum effective lines across a list of files
sum_effective_lines() {
  local total=0 n
  for f in "$@"; do
    [ -f "$f" ] || continue
    n=$(count_effective_lines "$f")
    total=$((total + n))
  done
  echo "$total"
}

# Count files that contain HARD enforcement (exit 1/2 or return 1)
count_hard_enforced() {
  local count=0
  for f in "$@"; do
    [ -f "$f" ] || continue
    if grep -qE '(^|[^a-zA-Z_])(exit[[:space:]]+[12]|return[[:space:]]+1)' "$f" 2>/dev/null; then
      count=$((count + 1))
    fi
  done
  echo "$count"
}

# Count shell scripts that use `set -euo pipefail` (hardening)
count_pipefail_hardened() {
  local count=0
  for f in "$@"; do
    [ -f "$f" ] || continue
    if grep -qE '^[[:space:]]*set[[:space:]]+-(euo|eo|eu)[[:space:]]+pipefail|^[[:space:]]*set[[:space:]]+-euo[[:space:]]+pipefail' "$f" 2>/dev/null; then
      count=$((count + 1))
    fi
  done
  echo "$count"
}

# Tiered scorer: returns $2 when value >= threshold[i], 0 otherwise
# Usage: tier value thr1 pts1 thr2 pts2 ...
tier() {
  local val="$1"; shift
  local result=0
  while [ $# -ge 2 ]; do
    if [ "$val" -ge "$1" ]; then
      result="$2"
    fi
    shift 2
  done
  echo "$result"
}

# ============================================================
# 1. Rules (0-20)
# ============================================================
echo -e "${CYAN}Checking rules...${NC}" >&2

rules_score=0
rule_count=0
rules_lines=0
# Score only base/ (harness-owned baseline). local/ is project-free area,
# not part of the harness baseline comparison.
rules_dir="$TARGET_DIR/.claude/rules/base"
if [ -d "$rules_dir" ]; then
  rule_count=$(find "$rules_dir" -name '*.md' -type f | wc -l | tr -d ' ')
  # Up to 10 files = 10 points (1 per file)
  file_points=$((rule_count > 10 ? 10 : rule_count))

  # Depth: total effective lines across all rules (tiered)
  rules_lines=0
  for f in "$rules_dir"/*.md; do
    [ -f "$f" ] || continue
    n=$(count_effective_lines "$f")
    rules_lines=$((rules_lines + n))
  done
  depth_points=$(tier "$rules_lines" 200 3 400 5 600 7 800 9 1200 10)

  rules_score=$((file_points + depth_points))
  rules_score=$((rules_score > 20 ? 20 : rules_score))
fi
add_score "rules" "$rules_score" 20 "${rule_count} files, ${rules_lines} lines"
echo -e "  Rules: ${rules_score}/20 (${rule_count} files, ${rules_lines} lines)" >&2

# Informational: count local/ files (not scored)
local_rules_dir="$TARGET_DIR/.claude/rules/local"
if [ -d "$local_rules_dir" ]; then
  local_count=$(find "$local_rules_dir" -name '*.md' -type f -not -name 'README.md' | wc -l | tr -d ' ')
  [ "$local_count" -gt 0 ] && echo -e "  Local rules: ${local_count} files (project-owned, not scored)" >&2
fi

# ============================================================
# 2. Skills (0-15)
# ============================================================
echo -e "${CYAN}Checking skills...${NC}" >&2

skills_score=0
skill_count=0
skill_with_examples=0
skill_with_gotchas=0
skills_dir="$TARGET_DIR/.claude/skills"
if [ -d "$skills_dir" ]; then
  for skill in "$skills_dir"/*/; do
    [ -d "$skill" ] || continue
    if [ -f "${skill}SKILL.md" ]; then
      skill_count=$((skill_count + 1))
      if [ -d "${skill}examples" ]; then
        skill_with_examples=$((skill_with_examples + 1))
      fi
      if grep -qiE '^##[[:space:]]+(Gotchas|Common Pitfalls|Context Required)' "${skill}SKILL.md" 2>/dev/null; then
        skill_with_gotchas=$((skill_with_gotchas + 1))
      fi
    fi
  done

  # base: 2 pt per skill, max 6
  base=$((skill_count * 2 > 6 ? 6 : skill_count * 2))
  # examples bonus: 1 pt per skill with examples, max 4
  ex_points=$((skill_with_examples > 4 ? 4 : skill_with_examples))
  # depth: 1 pt per skill with Gotchas/Context Required section, max 5
  depth_points=$((skill_with_gotchas > 5 ? 5 : skill_with_gotchas))

  skills_score=$((base + ex_points + depth_points))
  skills_score=$((skills_score > 15 ? 15 : skills_score))
fi
add_score "skills" "$skills_score" 15 "${skill_count} skills, ${skill_with_examples} with examples, ${skill_with_gotchas} with gotchas"
echo -e "  Skills: ${skills_score}/15 (${skill_count} skills, ${skill_with_examples} ex, ${skill_with_gotchas} gotchas)" >&2

# ============================================================
# 3. Hooks (0-15)
# ============================================================
echo -e "${CYAN}Checking hooks...${NC}" >&2

hooks_score=0
hook_count=0
executable_count=0
hook_hard=0
hooks_dir="$TARGET_DIR/.claude/hooks"
if [ -d "$hooks_dir" ]; then
  hook_count=$(find "$hooks_dir" -name '*.sh' -type f | wc -l | tr -d ' ')
  executable_count=$(find "$hooks_dir" -name '*.sh' -type f -perm +111 | wc -l | tr -d ' ')

  # file_points: 1 pt per hook, max 5
  file_points=$((hook_count > 5 ? 5 : hook_count))
  # exec_bonus: 3 if all executable
  exec_bonus=0
  if [ "$hook_count" -gt 0 ] && [ "$hook_count" -eq "$executable_count" ]; then
    exec_bonus=3
  fi
  # HARD enforcement: hooks with `exit 1`/`exit 2`/`return 1`, 1 pt each, max 7
  hook_files=()
  for f in "$hooks_dir"/*.sh; do [ -f "$f" ] && hook_files+=("$f"); done
  if [ ${#hook_files[@]} -gt 0 ]; then
    hook_hard=$(count_hard_enforced "${hook_files[@]}")
  fi
  hard_points=$((hook_hard > 7 ? 7 : hook_hard))

  hooks_score=$((file_points + exec_bonus + hard_points))
  hooks_score=$((hooks_score > 15 ? 15 : hooks_score))
fi
add_score "hooks" "$hooks_score" 15 "${hook_count} hooks, ${executable_count} exec, ${hook_hard} HARD"
echo -e "  Hooks: ${hooks_score}/15 (${hook_count} files, ${hook_hard} with HARD exit)" >&2

# ============================================================
# 4. Guidance (0-10) — context/ + docs/  [NEW]
# ============================================================
echo -e "${CYAN}Checking guidance (context + docs)...${NC}" >&2

guidance_score=0
guidance_files=0
guidance_lines=0
context_dir="$TARGET_DIR/context"
docs_dir="$TARGET_DIR/docs"

collect_guidance_lines() {
  local d="$1"
  [ -d "$d" ] || return
  while IFS= read -r f; do
    n=$(count_effective_lines "$f")
    guidance_lines=$((guidance_lines + n))
    guidance_files=$((guidance_files + 1))
  done < <(find "$d" -name '*.md' -type f 2>/dev/null)
}
collect_guidance_lines "$context_dir"
collect_guidance_lines "$docs_dir"

if [ "$guidance_files" -gt 0 ]; then
  # file_points: 1 pt per file, max 5
  file_points=$((guidance_files > 5 ? 5 : guidance_files))
  # depth: tiered by total lines
  depth_points=$(tier "$guidance_lines" 200 1 500 2 1000 3 1500 4 2500 5)
  guidance_score=$((file_points + depth_points))
  guidance_score=$((guidance_score > 10 ? 10 : guidance_score))
fi
add_score "guidance" "$guidance_score" 10 "${guidance_files} files, ${guidance_lines} lines"
echo -e "  Guidance: ${guidance_score}/10 (${guidance_files} files, ${guidance_lines} lines)" >&2

# ============================================================
# 5. Scripts (0-10)  [NEW]
# ============================================================
echo -e "${CYAN}Checking scripts...${NC}" >&2

scripts_score=0
script_count=0
script_hard=0
script_pipefail=0
scripts_dir="$TARGET_DIR/scripts"
if [ -d "$scripts_dir" ]; then
  script_count=$(find "$scripts_dir" -name '*.sh' -type f | wc -l | tr -d ' ')
  script_files=()
  for f in "$scripts_dir"/*.sh; do [ -f "$f" ] && script_files+=("$f"); done
  if [ ${#script_files[@]} -gt 0 ]; then
    script_hard=$(count_hard_enforced "${script_files[@]}")
    script_pipefail=$(count_pipefail_hardened "${script_files[@]}")
  fi

  # file_points: 1 pt per script, max 5
  file_points=$((script_count > 5 ? 5 : script_count))
  # HARD enforcement (exit 1/2 OR set -euo pipefail): up to 5
  hardened=$((script_hard > script_pipefail ? script_hard : script_pipefail))
  hard_points=$((hardened > 5 ? 5 : hardened))

  scripts_score=$((file_points + hard_points))
  scripts_score=$((scripts_score > 10 ? 10 : scripts_score))
fi
add_score "scripts" "$scripts_score" 10 "${script_count} scripts, ${script_hard} HARD, ${script_pipefail} pipefail"
echo -e "  Scripts: ${scripts_score}/10 (${script_count} files, ${script_hard} HARD, ${script_pipefail} pipefail)" >&2

# ============================================================
# 6. Templates (0-10)
# ============================================================
echo -e "${CYAN}Checking templates...${NC}" >&2

templates_score=0
template_count=0
filled_count=0
templates_dir="$TARGET_DIR/templates"
if [ -d "$templates_dir" ]; then
  template_count=$(find "$templates_dir" -name '*.md' -type f | wc -l | tr -d ' ')
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

  # file_points: 1 pt per template, max 5
  file_points=$((template_count > 5 ? 5 : template_count))
  # filled ratio: up to 5 points, tiered
  if [ "$template_count" -gt 0 ]; then
    # ratio_pct = filled * 100 / total
    ratio_pct=$((filled_count * 100 / template_count))
    fill_points=$(tier "$ratio_pct" 20 1 40 2 60 3 80 4 95 5)
  else
    fill_points=0
  fi

  templates_score=$((file_points + fill_points))
  templates_score=$((templates_score > 10 ? 10 : templates_score))
fi
add_score "templates" "$templates_score" 10 "${template_count} templates, ${filled_count} filled"
echo -e "  Templates: ${templates_score}/10 (${template_count} files, ${filled_count} filled)" >&2

# ============================================================
# 7. Evaluations (0-10)
# ============================================================
echo -e "${CYAN}Checking evaluations...${NC}" >&2

eval_score=0
eval_count=0
# Measure ONLY the target tree — never fall back to PROJECT_DIR (would conflate
# dev environment artifacts with production target measurement).
if [ -d "$TARGET_DIR/outputs/evaluations" ]; then
  eval_count=$(find "$TARGET_DIR/outputs/evaluations" -name '*.md' -type f | wc -l | tr -d ' ')
fi
# 2 pt per evaluation, max 10
eval_score=$((eval_count * 2 > 10 ? 10 : eval_count * 2))
add_score "evaluations" "$eval_score" 10 "${eval_count} records"
echo -e "  Evaluations: ${eval_score}/10 (${eval_count} files)" >&2

# ============================================================
# 8. Test/Lint (0-10) — skip in quick mode
# ============================================================
echo -e "${CYAN}Checking test/lint...${NC}" >&2

test_score=0
if [ "$MODE" = "quick" ]; then
  test_score=0
  add_score "test_lint" 0 10 "skipped (quick mode)"
  echo -e "  Test/Lint: ${YELLOW}skipped (quick mode)${NC}" >&2
else
  lint_pass=0
  test_pass=0

  if command -v shellcheck &>/dev/null; then
    sc_count=0
    sc_pass=0
    for f in "$TARGET_DIR/scripts/"*.sh; do
      [ -f "$f" ] || continue
      sc_count=$((sc_count + 1))
      if shellcheck -S warning "$f" &>/dev/null; then
        sc_pass=$((sc_pass + 1))
      fi
    done
    if [ "$sc_count" -gt 0 ]; then
      lint_pass=$((sc_pass * 5 / sc_count))
    fi
  else
    lint_pass=2
  fi

  if [ -f "$TARGET_DIR/package.json" ]; then
    if npm test --prefix "$TARGET_DIR" &>/dev/null 2>&1; then
      test_pass=5
    fi
  elif [ -f "$TARGET_DIR/pubspec.yaml" ]; then
    if (cd "$TARGET_DIR" && dart test) &>/dev/null 2>&1; then
      test_pass=5
    fi
  else
    test_pass=2
  fi

  test_score=$((lint_pass + test_pass))
  test_score=$((test_score > 10 ? 10 : test_score))
  add_score "test_lint" "$test_score" 10 "lint:${lint_pass}/5 test:${test_pass}/5"
  echo -e "  Test/Lint: ${test_score}/10" >&2
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
