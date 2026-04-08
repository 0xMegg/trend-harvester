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
2. **판단:** 사용자의 요청이 기획/논의인지, 실행인지 먼저 구분
   - 기획/논의: Epic 분해, 아키텍처 결정, 방향 토론 → **코드를 수정하지 않는다.** Planner 모드로 동작
   - 실행: 명시적으로 "구현해", "만들어", "수정해" → Developer 모드로 동작
3. Execute: make changes, run lint/analyze (실행 요청일 때만)
4. Verify: confirm tests pass
5. Handoff: update `handoff/latest.md`

## Default Mode Rule
역할이 명시되지 않은 대화에서는 **기획 모드(read-only)**가 기본이다.
- Epic, 기능, 아키텍처를 논의할 때 코드를 수정하거나 파일을 생성하지 않는다
- 사용자가 "구현해", "실행해", "/develop" 등 명시적 실행 지시를 할 때만 코드를 건드린다
- 애매하면 "기획만 할까요, 구현까지 할까요?" 물어본다
- 기획 결과물(plan, epic-plan)은 `outputs/plans/`에 저장해도 된다 — 코드 파일은 안 됨

## Session Management
- **Continue (`--continue`):** same task, same context — pick up where you left off
- **Resume (`--resume`):** browse past sessions and select one to continue
- **Fork (`--fork-session`):** branch off into a different direction from the current session
- **Worktree (`--worktree`):** parallel implementation on separate files — never edit the same file in two sessions
- 세션이 길어지면 handoff를 작성한 뒤 **새 세션으로 시작** (context reset)
- After a direction change, prefer `--fork-session` over continuing in a polluted context

## Context Reset Rules
Compaction(요약)보다 Reset(새 세션)이 더 낫다.
Compaction은 "context anxiety"를 유발하여 모델이 작업을 조기 마무리하려는 경향을 만든다.
- 작업 경계가 바뀌면 → handoff 작성 → 새 세션
- 같은 task 내에서도 2시간 이상 → handoff 작성 → 새 세션
- 새 세션 시작 시: handoff + plan + 관련 파일을 다시 읽고 시작
- `/compact`는 정말 불가피할 때만 — 기본 전략이 아닌 예외

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

### 핵심 원칙
토큰은 비용이면서 집중력(attention budget) 문제다.
절약보다 집중 — 필요한 것만 조합한다.

### 컨텍스트 구성 (항상 vs 필요 시)
| 항상 상주 | 필요 시만 열기 |
|-----------|---------------|
| CLAUDE.md | 긴 참고 문서, 사례집 |
| 짧은 공통 규칙 (rules/) | 세부 라이브러리 레퍼런스 |
| 핵심 명령, 프로젝트 구조 | 오래된 설계 문서 |
| handoff/latest.md | outputs/archive/ |

### 토큰 비용이 커지는 5가지 구간
1. 너무 긴 CLAUDE.md와 상시 규칙 파일
2. 범위가 모호한 프롬프트 ("알아서 해 줘")
3. 긴 세션 누적 (작업 경계 바뀌면 세션도 끊기)
4. 과도한 도구 출력 (테스트 전체 로그, 검색 결과 수백 줄)
5. 한 세션에서 너무 많은 역할 동시 수행

### 모델 사용 분리
- 강한 모델 (Opus): 설계, 논문 이해, 큰 구조 판단
- 균형형 모델 (Sonnet): 구현, 검색, 파일 확인, 단순 수정

### 세션 분리 기준
- 작업 경계가 바뀌면 세션도 끊기
- 기본 전략: 리셋 (새 세션) → handoff와 plan이 더 단단해야 함 (깨끗한 출발점)
- Opus 4.6은 2시간+ 세션도 일관성 유지 가능 — 불필요한 세션 분리 금지
- 새 세션 시작 시: handoff + plan + 관련 파일을 다시 읽고 시작

### MCP 상주 비용
- 도구 설명과 출력이 컨텍스트를 미리 차지
- 자주 안 쓰는 MCP는 꺼두기
- 같은 작업이라도 무거운 통합보다 필요 시 CLI 호출이 가벼울 수 있음

### CLAUDE.md 관리
- 같은 실수가 반복되면 규칙에 반영
- 이미 잘 지키는 상식까지 길게 적지 않음
- 규칙 파일은 많을수록 좋은 설명서가 아니라, 계속 틀리는 지점을 줄여주는 짧은 운영 문서

## Evaluation Loop
매 Task 완료 후 `templates/evaluation.md` 형식으로 기록.
반복되는 실패 패턴이 발견되면:
1. `.claude/rules/gotchas.md`에 Known Pitfall로 추가
2. 해당 Skill의 Common Pitfalls에 추가
3. 필요 시 hook으로 자동 감지 추가

5가지 지표를 계속 비교:
- 성공률, 사람 수정량, 시간, 토큰/비용, 실패 유형

## Self-Improvement Loop (Harvest Module)
평가 루프의 확장판. 외부 신호를 수집하고, 점수화하고, 실험적으로 적용하고, 측정한다.

### 파이프라인 (6 Phase)
0. 실행 가드 (lockfile + cooldown)
1. 수집 (WebFetch, WebSearch, 수동 입력, 내부 피드백)
2. 분석 (5축 fitness filter: 자동화, 마찰제거, HARD전환, 토큰효율, 측정가능성)
3. 기준 측정 (harness-report.sh)
3.5 이중 검증 (임시 적용 → 재측정 → 유지/폐기)
4. 적용 판단 (harvest-policy.md 기준: auto vs 승인 필요)
5. 보고 (harvest/reports/)

### 실행 방법
- 수동: `/harvest` 커맨드 또는 `bash scripts/run-harvest.sh`
- 부분: `/harvest scan`, `/harvest add <URL>`, `/harvest judge`, `/harvest status`

### 핵심 원칙
- **Double-Gating**: 철학 필터(SOFT) + 실측 검증(HARD) 둘 다 통과해야 적용
- **롤백 보장**: `git stash`/`git checkout -- .` 사용 (`git reset --hard` 금지)
- **점진적 진화**: 한 번에 큰 변경 아닌, 작은 규칙/스킬 단위로 적용
- **측정 기반**: harness-report 점수가 하락하면 자동 폐기/revert
