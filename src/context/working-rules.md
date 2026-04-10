# Working Rules

## Work Principles
1. **Read before write** — understand existing code before changing it
2. **Feature-local first** — make changes inside the owning feature/module first; touch shared layers only when necessary
3. **Smallest change** — do only what completes the task, nothing more
4. **No scope creep** — if you notice unrelated cleanup or refactoring, log it as a separate task

## Session Protocol (3-Role Workflow)
Each session performs exactly one role. When given a role file (`templates/role-*.md`), follow only that role.

1. **Planner** (read-only): read handoff → analyze code → write `outputs/plans/task-N-plan.md` → update handoff
2. **Developer** (implement only): read handoff → follow plan → lint + test → update handoff (do NOT commit)
3. **Reviewer** (verify only): read handoff → inspect code → write `outputs/reviews/task-N-review.md` → commit + push on APPROVE → update handoff

If no role is specified (general session):
1. Start: read `handoff/latest.md` for current state
2. **Determine intent:** First distinguish whether the user's request is planning/discussion or execution
   - Planning/discussion: Epic decomposition, architecture decisions, direction discussion → **Do not modify code.** Operate in Planner mode
   - Execution: Explicit instructions like "implement", "build", "fix" → Operate in Developer mode
3. Execute: make changes, run lint/analyze (only when execution is requested)
4. Verify: confirm tests pass
5. Handoff: update `handoff/latest.md`

## Default Mode Rule
In conversations where no role is specified, **planning mode (read-only)** is the default.
- Do not modify code or create files when discussing Epics, features, or architecture
- Only touch code when the user gives explicit execution instructions such as "implement", "execute", "/develop"
- If ambiguous, ask: "Should I just plan, or implement as well?"
- Planning outputs (plan, epic-plan) may be saved to `outputs/plans/` — but not code files

## Session Management
- **Continue (`--continue`):** same task, same context — pick up where you left off
- **Resume (`--resume`):** browse past sessions and select one to continue
- **Fork (`--fork-session`):** branch off into a different direction from the current session
- **Worktree (`--worktree`):** parallel implementation on separate files — never edit the same file in two sessions
- When a session gets long, write a handoff and **start a new session** (context reset)
- After a direction change, prefer `--fork-session` over continuing in a polluted context

## Context Reset Rules
Reset (new session) is better than compaction (summarization).
Compaction induces "context anxiety," causing the model to rush toward wrapping up work prematurely.
- When the task boundary changes → write handoff → new session
- Even within the same task, after 2+ hours → write handoff → new session
- When starting a new session: re-read the handoff + plan + related files before beginning
- `/compact` is only for truly unavoidable situations — an exception, not the default strategy

## Communication
- If uncertain about scope, ask before implementing
- If 3+ different approaches fail, stop and discuss
- Flag security concerns immediately
- State assumptions explicitly

## Quality Gates (before declaring done)
- [ ] Lint/Analyze passes
- [ ] Related tests pass (if any)
- [ ] Changes are within the requested scope
- [ ] Handoff notes updated

## Token & Context Management

### Core Principle
Tokens are both a cost and an attention budget issue.
Focus over frugality — compose only what is needed.

### Context Composition (Always vs On-Demand)
| Always Resident | Open Only When Needed |
|-----------|---------------|
| CLAUDE.md | Long reference docs, case studies |
| Short shared rules (rules/) | Detailed library references |
| Core commands, project structure | Outdated design docs |
| handoff/latest.md | outputs/archive/ |

### 5 Areas Where Token Cost Grows
1. Overly long CLAUDE.md and always-resident rule files
2. Vague prompts with unclear scope ("just figure it out")
3. Long session accumulation (break the session when the task boundary changes)
4. Excessive tool output (full test logs, hundreds of lines of search results)
5. Performing too many roles simultaneously in a single session

### Model Usage Separation
- Strong model (Opus): design, research comprehension, large structural decisions
- Balanced model (Sonnet): implementation, search, file inspection, simple modifications

### Session Separation Criteria
- When the task boundary changes, break the session too
- Default strategy: reset (new session) → handoff and plan must be more solid (clean starting point)
- Opus 4.6 can maintain consistency in 2+ hour sessions — do not split sessions unnecessarily
- When starting a new session: re-read the handoff + plan + related files before beginning

### MCP Residency Cost
- Tool descriptions and outputs pre-occupy context space
- Keep infrequently used MCPs disabled
- Even for the same task, on-demand CLI calls can be lighter than heavy always-on integrations

### CLAUDE.md Management
- When the same mistake recurs, reflect it in the rules
- Don't write lengthy entries for common sense that's already being followed
- Rule files are not better documentation the longer they get — they're short operational documents that reduce recurring mistakes

### 세션 분할 체크리스트
다음 중 하나라도 해당하면 즉시 handoff 갱신 → 새 세션 시작:
- [ ] 컨텍스트 70% 이상 사용
- [ ] 동일 오류가 3회 이상 반복됨
- [ ] 역할 전환이 필요함 (Planner → Developer 등)
- [ ] 2시간 이상 경과 (Opus 4.6는 예외지만 task 경계에서 분할 권장)
- [ ] CLAUDE.md · rules · context 중 다수를 재로드해야 함

전환 전 필수: `handoff/latest.md` 갱신 (What Changed / Current State / What's Next).

### 파일 크기 상한
`post-edit-size-check.sh` 훅이 편집 후 자동 경고 (경고 전용, block 아님):

| 파일 | 상한 | 이유 |
|------|------|------|
| `CLAUDE.md` | 200줄 | 항상 resident, token 비용 직접 |
| `.claude/rules/*.md` | 50줄 | 항상 resident, 짧은 운영 문서 |
| `context/*.md` | 150줄 | 자주 참조 (`decision-log.md` 제외) |

초과 시: (1) 분할, (2) 요약, (3) on-demand 이동 중 선택. 한시적 우회는 `HARVEST_ALLOW_OVERSIZE=1`.

## Evaluation Loop
Record in the `templates/evaluation.md` format after completing each Task.
When recurring failure patterns are discovered:
1. Add as a Known Pitfall in `.claude/rules/gotchas.md`
2. Add to the relevant Skill's Common Pitfalls
3. Add automatic detection via hooks if necessary

Continuously compare these 5 metrics:
- Success rate, human edit volume, time, tokens/cost, failure types
