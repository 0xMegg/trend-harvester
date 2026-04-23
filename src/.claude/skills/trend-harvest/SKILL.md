---
name: trend-harvest
description: |
  Runs the external trend collection → analysis → application pipeline.
  Activate on these requests:
  "harvest trends", "run harvest", "collect external signals", "self-improve",
  "run harvest", "collect trends", "/harvest"
  Do NOT activate on:
  "harness score" (→ harness-report), "evaluate this" (→ fitness-filter),
  "fix bug", "code review", "implement feature"
version: 1.0.0
---

# Trend Harvest Skill

Full pipeline that collects external trends, evaluates them with a 5-axis filter, verifies through double-gating, and applies them to the harness.

## Trigger
- "/harvest" — full pipeline (external collection → Phase 0-5)
- "/harvest scan" — Phase 1 only (collection)
- "/harvest validate <description>" — manual input → Phase 1-M+2 → STOP for human review
- "/harvest validate --file <path>" — manual input from file → Phase 1-M+2 → STOP
- "/harvest validate --auto <description>" — manual input → Phase 1-M through 5 (no review pause)
- "/harvest add <description>" — alias for /harvest validate
- "/harvest judge" — Phase 3-3.5 only (measurement + verification)
- "/harvest apply" — Phase 4 only (apply pending proposals)
- "/harvest status" — status report

## Two Pipeline Paths

**External Collection** (`/harvest` or `/harvest scan`):
```
Phase 0 (lock + cooldown) → Phase 1 (WebFetch/WebSearch) → Phase 2 → Phase 3 → Phase 3.5 → Phase 4 → Phase 5
```

**Manual Validation** (`/harvest validate <input>`):
```
Phase 0 (lock only, no cooldown) → Phase 1-M (manual ingest) → Phase 2 → ■ HUMAN REVIEW → judge → Phase 3 → Phase 3.5 → Phase 4 → Phase 5
```

Manual inputs receive:
- `source_type: manual`, `trust_level: high` (per harvest-policy.md)
- No cooldown throttling (can validate ideas anytime)
- **Human review checkpoint** after Phase 2: shows fitness score and proposal details, then stops
- User runs `/harvest judge` to continue to measurement and apply
- Use `--auto` flag to skip the review checkpoint (for future automation)

## 6-Phase Pipeline

### Phase 0: Execution Guard
1. Check `harvest/.lock` — abort if already running
2. Check the latest report timestamp in `harvest/reports/` — abort if cooldown has not elapsed
3. Create lock (must be removed on both normal and abnormal exit)

### Phase 1: Collection
Collect from enabled sources in `harvest/config.json`:

**web_fetch**: Fetch content from each target URL via WebFetch MCP
```
WebFetch(url, "Extract trending repositories, tools, or techniques related to developer tooling and AI coding")
```

**web_search**: Search each query via WebSearch MCP
```
WebSearch(query)
```

**manual**: User registers directly via `/harvest validate <input>` (or `/harvest add`)

**internal_feedback**: Extract "Lessons Learned" sections from `outputs/evaluations/*.md`

Collection results → saved to `harvest/raw/YYYY-MM-DD-HHMMSS.jsonl`
Dedup check: cross-reference with `harvest/.seen.json` (URL + title hash)

### Phase 1-M: Manual Input Ingestion (validate mode only)
Accepts user-provided improvement idea and creates a raw entry:
1. Generate slug from input (first 30 chars, lowercase, alphanumeric+hyphens)
2. Create `harvest/raw/manual-{RUN_ID}-{slug}.json` with `source_type: manual`, `trust_level: high`
3. Skip cooldown (manual validation is not rate-limited)
4. Proceeds directly to Phase 2

### Phase 2: Analysis
For each collected item, invoke the `fitness-filter` skill:
1. Load project context (CLAUDE.md, rules/base/, rules/local/, gotchas.md)
2. Calculate 5-axis score
3. score >= 6 → save to `harvest/analyzed/`
4. score < 6 → save to `harvest/rejected/` + record reason

### Phase 3: Baseline Measurement
```bash
bash scripts/harness-report.sh quick
```
Record current score in `harvest/baseline.json`

### Phase 3.5: Autoresearch Judge (Double-Gating Gate 2)
For each proposal with score >= 6:
1. `git stash` (preserve current work)
2. Temporarily apply the proposal (add rule, create skill, etc.)
3. Re-run `bash scripts/harness-report.sh quick`
4. Compare:
   - new_score >= baseline_score → **keep** (passes)
   - new_score < baseline_score → **discard** (rejected)
5. `git checkout -- .` (remove temporary changes)
6. `git stash pop` (restore work)
7. Record result in the proposal

### Phase 4: Apply Decision
According to `context/harvest-policy.md` policy:

**Auto-apply** (when conditions are met):
- Apply changes to the target file
- Commit with `chore: harvest — [description]`
- Record in `harvest/applied/`

**Pending approval**:
- Save to `harvest/applied/pending-*.json`
- Prompt user to check via `/harvest status`

### Phase 5: Report
1. Generate report using `templates/harvest-report.md` format
2. Save to `harvest/reports/YYYY-MM-DD-HHMMSS.md`
3. Update `harvest/.seen.json`
4. Release lock
5. Notify based on output provider:
   - `log-only`: report file only
   - `notion`: record in Notion DB
   - `obsidian`: copy markdown to vault

## Context Required
Files that must be read before running the pipeline:
1. `harvest/config.json` — sources, thresholds, output settings
2. `context/harvest-policy.md` — auto-apply policy
3. `harvest/baseline.json` — current baseline score
4. `harvest/.seen.json` — dedup index
5. `.claude/rules/base/gotchas.md` + `.claude/rules/local/gotchas-*.md` — existing pitfalls (for fitness-filter)
6. `CLAUDE.md` — project architecture

## Gotchas
- Do NOT use `git reset --hard` in Phase 3.5 — use `git checkout -- .`
- If the lock file remains, the previous run terminated abnormally → delete lock and re-run
- If a re-run is attempted within cooldown, notify the user and abort
- If harness-report drops after auto-apply, immediately create a revert commit
- If a collection source fails, skip that source and continue with the rest
- If `.seen.json` does not exist, initialize with an empty object `{}`
