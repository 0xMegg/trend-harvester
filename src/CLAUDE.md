# Project Contract

## Project
- Name: {{PROJECT_NAME}}
- Type: {{PROJECT_TYPE}}
- Stack: {{TECH_STACK}}

## Build & Test Commands
- Install: `{{INSTALL_CMD}}`
- Dev/Run: `{{DEV_CMD}}`
- Build: `{{BUILD_CMD}}`
- Test all: `{{TEST_CMD}}`
- Test single: `{{TEST_SINGLE_CMD}}`
- Lint/Analyze: `{{LINT_CMD}}`
- Format: `{{FORMAT_CMD}}`

<!-- Multi-Repo (uncomment if workspace has multiple git repos)
## Multi-Repo Structure
This workspace coordinates multiple independent repositories:
- `{{REPO_1}}/` — {{REPO_1_DESCRIPTION}}
- `{{REPO_2}}/` — {{REPO_2_DESCRIPTION}}

### {{REPO_1}} Commands
- Install: `cd {{REPO_1}} && {{REPO_1_INSTALL}}`
- Dev/Run: `cd {{REPO_1}} && {{REPO_1_DEV}}`
- Test: `cd {{REPO_1}} && {{REPO_1_TEST}}`
- Lint: `cd {{REPO_1}} && {{REPO_1_LINT}}`

### {{REPO_2}} Commands
- Install: `cd {{REPO_2}} && {{REPO_2_INSTALL}}`
- Dev/Run: `cd {{REPO_2}} && {{REPO_2_DEV}}`
- Lint: `cd {{REPO_2}} && {{REPO_2_LINT}}`

## Multi-Repo Discipline
- Preserve repository boundaries — each slice targets one repo unless explicitly cross-repo
- Do not assume a change in one repo requires a change in another
- Keep integration contracts explicit between repos
-->

## Folder Boundaries
- Source code: `{{SRC_DIR}}`
- Tests: `{{TEST_DIR}}`
- Do NOT modify: `.env`, `{{BUILD_OUTPUT}}/`, `{{LOCK_FILE}}`, `{{PROTECTED_FILES}}`

## Architecture
- {{ARCHITECTURE_PATTERN}}
- State management: {{STATE_MANAGEMENT}}
- Routing: {{ROUTING}}
- Data access: {{DATA_ACCESS_PATTERN}}

## Coding Conventions
- Language: {{LANGUAGE}}
- Naming: {{NAMING_CONVENTION}}
- File naming: {{FILE_NAMING}}
- Imports: {{IMPORT_STYLE}}
- Error handling: {{ERROR_HANDLING}}

## Work Protocol
1. Read the relevant code before modifying
2. Keep changes feature-local first
3. Run lint/analyze after every change
4. Run tests if they exist for the changed area
5. Make the smallest change that completes the task
6. Update `handoff/latest.md` with what changed and what's next

## Restrictions
- Never commit secrets, API keys, or .env files
- Never run `rm -rf` on project directories
- Never force push to main/master
- Never add dependencies without stating the reason
- Never do repo-wide refactor without explicit request

## References
- `context/` — project background, working rules, decision log
- `context/access-policy.md` — AI tool access policy (allowed / approval / blocked)
- `context/mcp-policy.md` — MCP & external integration policy
- `handoff/latest.md` — current state and task queue (read at every session start)
- `docs/plugin-guide.md` — plugin structure, security checklist, deployment strategy
- `docs/epic-guide.md` — epic decomposition, parallel stage execution, failure recovery
- `templates/evaluation.md` — task evaluation metrics (fill after each task)
- `{{SCHEMA_FILE}}` — data schema (source of truth), if applicable

## Self-Improvement (Optional — activate by setting harvest/config.json enabled: true)
- `harvest/config.json` — harvest pipeline configuration
- `context/harvest-policy.md` — auto-apply vs manual approval policy
- `/harvest` — run full pipeline
- `/harvest scan` — collection only
- `/harvest validate <description>` — manual input validation (Phase 2-5)
- `/harvest add <description>` — alias for /harvest validate
- `/harvest judge` — baseline measurement + autoresearch
- `/harvest status` — check current status

## 3-Role Workflow
- `/plan` — Planner: read-only, writes plans to `outputs/plans/`
- `/develop` — Developer: implements + verifies, does NOT commit
- `/review` — Reviewer: reviews, commits + pushes on APPROVE
- Tasks modifying 3+ files → Planner must produce a plan first

## Rules (auto-applied)
- `.claude/rules/base/*.md` — harness-owned rules (api, frontend, testing, git, gotchas). Upgraded automatically by `upgrade-harness.sh`.
- `.claude/rules/local/*.md` — project-specific rules (upgrade-safe; never overwritten). Add project learnings here (e.g., `gotchas-<project>.md`).
Claude reads both directories on every session.
