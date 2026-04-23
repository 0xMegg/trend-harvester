---
name: fitness-filter
description: |
  Scores external trend items using a 5-axis fitness filter.
  Activate on these requests:
  "evaluate this trend", "fitness score", "fitness assessment", "5-axis analysis",
  "is this worth applying?", "trend evaluate"
  Do NOT activate on:
  "harness score", "code review", "fix bug", "collect trends"
version: 1.0.0
---

# Fitness Filter Skill

Evaluates external trends/ideas with a 5-axis fitness score from the project's perspective.

## Trigger
- "evaluate this trend [URL/description]"
- "fitness score for [item]"
- Automatically invoked during Phase 2 of the harvest pipeline

## Input
Trend item:
- title: title or summary
- url: source URL (optional)
- description: detailed description
- source_type: web_fetch / web_search / manual / internal_feedback

## Pre-Filter: Concreteness Gate

Before scoring, reject proposals that lack concrete specifics. A proposal MUST specify all three:
1. **Target file** — exact path. Project-specific pitfall: `.claude/rules/local/gotchas-<project>.md`. Harness-wide rule (needs template PR): `.claude/rules/base/gotchas.md`. Never just "a rule file".
2. **Triggering condition** — specific, observable event (e.g., "3+ consecutive identical error messages", not "when things go wrong")
3. **Action** — exact behavior (e.g., "exit 1 to block commit", not "warn the user")

If any of the three is missing or vague, reject immediately with reason `abstract-proposal`.
Do NOT invent specifics to pass the gate — if the input is vague, reject it.

**Reject** (abstract):
- "Add a rule about code quality" → no target file, no condition, no action
- "Improve error handling" → no specific trigger or file
- "Be more careful with tests" → aspirational, not enforceable

**Pass** (concrete):
- "Add to gotchas.md: if `git diff --cached` shows `*.env*` files, exit 1 in pre-commit hook"
- "Add rule to testing.md: run `npm test -- --bail` before committing; if exit code != 0, block"

## 5-Axis Scoring

Each axis 0-2 points, 10 points total. **Threshold: 6 points** (meaningfully satisfied on 3 or more axes)

### 1. Automation — 0-2
- 2: Completely eliminates a manual step (e.g., automates a verification that was done by hand every time via a hook)
- 1: Partially reduces a manual step (e.g., scripts part of a repetitive task)
- 0: No automation effect

### 2. Friction — 0-2
- 2: Directly prevents an existing pitfall in gotchas.md (e.g., automatically blocks a known mistake)
- 1: Reduces related friction but not a direct connection
- 0: Unrelated to existing friction

### 3. HARD Conversion — 0-2
- 2: Can be directly enforced via bash exit code (e.g., block with exit 1 in a hook)
- 1: Partially auto-verifiable (e.g., warns but does not block)
- 0: Purely subjective judgment, cannot be automated

### 4. Token Efficiency — 0-2
- 2: Measurable token savings (e.g., shorter prompts, removing unnecessary context)
- 1: Indirect improvement (e.g., clearer rules leading to fewer retries)
- 0: No token impact

### 5. Measurability — 0-2
- 2: Directly trackable with a single metric (e.g., test count, lint warning count, evaluation score)
- 1: Trackable via indirect metrics (e.g., session length, rework frequency)
- 0: No clear measurement metric

## Context Required
Files that must be read when calculating scores:
1. `.claude/rules/base/gotchas.md` + `.claude/rules/local/gotchas-*.md` — existing pitfalls (for evaluating the Friction axis)
2. `CLAUDE.md` — project architecture (for judging applicability)
3. `harvest/config.json` — per-axis weights
4. `context/harvest-policy.md` — whether auto-apply is possible

## Output Format
Output in `templates/harvest-proposal.md` format.

## Decision
- score >= 7 + risk low → auto-apply candidate
- score >= 6 → proceed to Phase 3.5 (autoresearch judge)
- score < 6 → record in harvest/rejected/ + reason

## Gotchas
- Do not score based on generalities without project context
- "Looks good" is different from "needed for this project"
- If HARD conversion is 0, it cannot be enforced as a rule, so effectiveness is low
- If a similar item already exists in gotchas.md, treat as a duplicate rather than giving Friction 2 points
- Do NOT invent specifics to pass the concreteness gate — if the input is vague, reject it as `abstract-proposal`
- See `examples/bad-output.md` for calibration counterexamples (abstract proposals, plausible-but-sub-threshold docs, HARD=0 behavior asks). Re-read these whenever you catch yourself scoring something 6+ "because it sounds reasonable"
