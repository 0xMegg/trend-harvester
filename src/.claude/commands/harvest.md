Run the harvest self-improvement pipeline.

## Task
$ARGUMENTS

## Workflow

1. Read `harvest/config.json` — verify module is active
2. Read `context/harvest-policy.md` — understand auto-apply rules
3. Read `harvest/baseline.json` — current harness score (if exists)

## Modes

### `/harvest` — Full pipeline (Phase 0-5)
Execute all 6 phases: guard → collect → analyze → measure → judge → apply → report.
Delegates to `bash scripts/run-harvest.sh` for orchestration, or runs phases interactively.

### `/harvest scan` — Collection only (Phase 1)
Collect from enabled sources in config. Save to `harvest/raw/`. No analysis or application.

### `/harvest add <URL or description>` — Manual input
1. Create a raw item from the user input
2. Run fitness-filter skill (5-axis scoring)
3. If score >= 6: proceed to Phase 3.5 (autoresearch judge)
4. If score >= 7 + policy allows: auto-apply
5. Otherwise: save as pending

### `/harvest judge` — Measurement + autoresearch (Phase 3-3.5)
Run harness-report baseline, then test pending analyzed proposals with double-gating.

### `/harvest apply` — Apply pending proposals (Phase 4)
Review and apply proposals in `harvest/applied/pending-*.json`.
Show each pending proposal and ask for approval before applying.

### `/harvest status` — Current state
Show: baseline score, last run, pending count, applied count, seen count.
Quick view: `bash scripts/run-harvest.sh status`

## Rules
- Never use `git reset --hard` — use `git checkout -- .` for rollback
- Always check `context/harvest-policy.md` before auto-applying
- Auto-apply commits use prefix: `chore: harvest —`
- Lock file (`harvest/.lock`) must be cleaned up on exit
