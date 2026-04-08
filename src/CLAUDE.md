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
- `harvest/config.json` — trend-harvester pipeline 설정
- `context/harvest-policy.md` — 자동 적용 vs 수동 승인 정책
- `/harvest` — 전체 파이프라인 실행
- `/harvest scan` — 수집만
- `/harvest add <URL/설명>` — 수동 입력
- `/harvest judge` — baseline 측정 + autoresearch
- `/harvest status` — 현황 확인

## 3-Role Workflow
- `/plan` — Planner: read-only, writes plans to `outputs/plans/`
- `/develop` — Developer: implements + verifies, does NOT commit
- `/review` — Reviewer: reviews, commits + pushes on APPROVE
- Tasks modifying 3+ files → Planner must produce a plan first

## Rules (auto-applied)
- `.claude/rules/api.md` — API/DB rules
- `.claude/rules/frontend.md` — UI rules
- `.claude/rules/testing.md` — testing rules
- `.claude/rules/git.md` — commit and branch rules
- `.claude/rules/gotchas.md` — project-specific pitfalls
