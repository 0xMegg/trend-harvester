# Project Contract

## Project
- Name: Harness Forge
- Type: Harness Self-Improvement System
- Stack: Bash, Markdown, Claude Code Skills

## What It Does
A self-improvement pipeline that collects external trends → applies 5-axis filtering → validates with real measurements → automatically/manually applies changes to harness templates.
The output (improved harness templates) is stored in a separate repository.

## Build & Test Commands
- Build template: `bash scripts/build-template.sh`
- Harness report: `bash scripts/harness-report.sh`
- Run harvest: `bash scripts/run-harvest.sh`
- Lint: `shellcheck scripts/*.sh`

## Key Directories
- `src/` — Harness template source (contains {{placeholders}}, edit target)
- `harvest/` — Pipeline data (collection/analysis/apply history)
- `scripts/` — Pipeline execution scripts
- `outputs/` — Work artifacts (plans, reviews, evaluations)

## Output Target
- Built templates are deployed to `../claude-code-harness-template/`
- `scripts/build-template.sh` copies src/ → target repo

## Architecture
- 7-Element Harness: Permissions, Validation, Execution Mode, State, Decision Trace, External Integration, Self-Improvement Loop
- 6-Phase Pipeline: Guard → Collect → Analyze → Measure → Judge → Apply → Report
- Double-Gating: SOFT (5-axis filter) + HARD (harness-report measurement)

## Folder Boundaries
- Do NOT modify: `harvest/.seen.json`, `harvest/.lock`
- Template modifications must be made in `src/` → reflected via build

## Work Protocol
1. Read the relevant code before modifying
2. Keep changes feature-local first
3. Run lint/analyze after every change
4. Make the smallest change that completes the task
5. Update `handoff/latest.md` with what changed and what's next
6. After modifying src/, run `bash scripts/build-template.sh`

## Restrictions
- Never commit secrets, API keys, or .env files
- Never run `rm -rf` on project directories
- Never force push to main/master
- Never use `git reset --hard` — use `git checkout -- .` for rollback
- Never modify target repo directly — always edit src/ and rebuild

## Self-Improvement (Harvest Module)
- `harvest/config.json` — Collection sources, thresholds, schedule settings
- `context/harvest-policy.md` — Auto-apply vs manual approval policy
- `/harvest` — Run full pipeline
- `/harvest scan` — Collection only
- `/harvest validate <description>` — Manual input validation (Phase 2-5)
- `/harvest add <description>` — Alias for /harvest validate
- `/harvest judge` — Baseline measurement + autoresearch
- `/harvest status` — Check current status

## References
- `context/harvest-policy.md` — Auto-apply policy
- `context/working-rules.md` — Workflow rules + self-improvement loop
- `docs/harvest-guide.md` — Pipeline guide
- `handoff/latest.md` — Current state
- `templates/evaluation.md` — Task evaluation (6 metrics)
