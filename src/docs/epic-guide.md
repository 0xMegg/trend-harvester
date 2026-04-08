# Epic Guide (v5)

Epic을 만들고 실행하는 기준 문서.
언제 Epic을 쓰는지, 어떻게 분해하는지, v5에서 달라진 점은 무엇인지를 다룬다.

---

## Epic이란

Epic은 단일 Task로 끝나지 않는 기능 단위의 작업이다.
여러 파일을 걸쳐 수정하고, 여러 관심사(데이터/로직/UI)가 얽혀 있으며,
완료까지 복수의 Plan → Develop → Review 사이클이 필요한 작업이 Epic이 된다.

## 언제 Epic을 쓰는가

| 상황 | 선택 |
|------|------|
| 수정 파일 1~2개, 단일 관심사 | Task 하나로 충분 |
| 수정 파일 3~5개, 하나의 기능 | Task 하나지만 Planner가 plan 먼저 |
| 수정 파일 6~9개, 단일 관심사 | **Epic Lite** (Stage 없이 단일 Task) |
| 수정 파일 6~9개, 복수 관심사 | **Epic으로 분해** |
| 수정 파일 10개 이상 | **Epic으로 분해** (Stage 필수) |
| DB 스키마 + API + UI가 함께 바뀜 | **Epic으로 분해** |
| "이거 하나만 하면 돼"인데 설명이 3줄 넘어감 | Epic일 가능성 높음 |

판단이 애매하면 Epic으로 시작한다. Slice가 1개뿐인 Epic은 자동으로 단일 Task처럼 동작한다.

### Epic Lite
Opus 4.6은 2시간 이상 일관된 빌드를 유지할 수 있다.
10파일 미만 + 단일 관심사인 경우 Stage 분해 없이 단일 Task로 처리하면 된다.

**Epic Lite 조건:**
- 수정 파일 6~9개
- 관심사가 1개 (데이터+로직+UI가 하나의 기능에 속함)
- 외부 의존성 변경 없음

**Epic Lite가 아닌 경우 (Full Epic 필요):**
- 파일 10개 이상
- 관심사 2개 이상 (예: 인증 + 결제가 동시에 바뀜)
- DB 마이그레이션 + API + UI가 독립적으로 실패할 수 있음

이 판단은 Planner가 수행한다. Epic Lite로 시작했다가 중간에 범위가 커지면 Full Epic으로 전환.

## Epic 분해 원칙

### 1. 층(Layer) 순서로 자르기

가장 안전한 분해 방향은 아래에서 위로:

```
Stage 1: 데이터 층 (스키마, 마이그레이션, 모델)
Stage 2: 로직 층 (서비스, 리포지토리, API)
Stage 3: UI 층 (컴포넌트, 라우트, 화면)
Stage 4: 통합 테스트 + 마무리
```

이 순서가 강한 이유는, 위 층이 아래 층에 의존하기 때문이다.
데이터 없이 API를 짤 수 없고, API 없이 UI를 짤 수 없다.

### 2. 같은 Stage 안에서는 파일이 겹치면 안 된다

이것이 병렬 실행의 유일하고 절대적인 규칙이다.

```
Stage 2 (병렬 가능):
  Slice A: src/api/auth.ts, src/services/auth.ts
  Slice B: src/api/profile.ts, src/services/profile.ts
  → 파일이 겹치지 않으므로 병렬 OK
```

```
Stage 2 (병렬 불가):
  Slice A: src/api/auth.ts, src/utils/validation.ts
  Slice B: src/api/profile.ts, src/utils/validation.ts
  → validation.ts가 겹치므로 같은 Stage에 넣으면 안 됨
```

겹치는 파일이 있으면 두 가지 중 하나를 선택한다:
- 공통 파일을 별도 Slice로 빼서 먼저 실행 (Stage 분리)
- 두 Slice를 다른 Stage에 순차 배치

### 3. Slice 크기 기준

| 기준 | 권장 |
|------|------|
| 수정 파일 수 | ~5개 이하 |
| 예상 구현 시간 | 1 세션 안에 끝날 분량 |
| 테스트 | 독립적으로 검증 가능 |
| 리뷰 | 한 눈에 diff를 읽을 수 있는 분량 |

Slice가 너무 크면 Review가 형식적이 된다.
Slice가 너무 작으면 세션 전환 비용이 이득을 넘어선다.

### 4. 의존성은 명시적으로

각 Slice의 `Depends on:` 필드를 반드시 채운다.
"이전 Stage 전체"보다 "Slice 2의 auth.ts"처럼 구체적으로 적을수록
실패 시 영향 범위를 빨리 파악할 수 있다.

---

## v5에서 달라진 점

### 병렬 Stage 통합 커밋

v4에서는 병렬 Slice마다 Reviewer가 `git commit + push`를 시도했다.
첫 번째 Slice가 push하면 나머지는 remote가 앞서 있어서 실패했다.

v5에서는:
- 병렬 Slice는 `--no-commit`으로 실행 → Reviewer가 git을 건드리지 않음
- Stage의 모든 Slice가 완료되면 `commit_stage()`가 통합 커밋
- 커밋 메시지: `feat: Stage N — slice1 요약 + slice2 요약 + ...`
- 순차 실행(단일 Slice)은 기존과 동일하게 Reviewer가 직접 커밋

```
Stage 1 (병렬):
  Slice A → Plan → Develop → Review (no commit) ✓
  Slice B → Plan → Develop → Review (no commit) ✓
  → commit_stage(): git add -A → commit → push ✓ (모든 Slice 반영)
```

### 검증 계획이 더 구체적

각 Slice의 verify.md에 다음이 추가되었다:
- **Completion Criteria**: 모델과 사람이 같은 끝점을 보게 만드는 좌표
- **Constraints**: "테스트를 수정하지 말 것" 같은 수정 금지 규칙
- **Confidence level**: HIGH / MEDIUM / LOW

Epic plan 단계에서 각 Slice의 완료 기준을 선명하게 적어야 한다.
"Done when: 동작함"이 아니라 "Done when: 빈 폼 제출 시 에러 메시지 표시 + 테스트 통과"처럼.

### 평가 루프

각 Slice(Task) 완료 후 `templates/evaluation.md`로 5대 지표를 기록한다:
성공률, 사람 수정량, 시간, 토큰/비용, 실패 유형.

Epic 단위에서는 Slice별 평가를 모아 반복되는 실패 패턴을 분석한다.
같은 유형의 실패가 2회 이상 나오면 `rules/gotchas.md`나 Skill의 Gotchas에 반영한다.

### 정책 문서 참조

Epic plan 작성 시 다음을 확인한다:
- `context/access-policy.md` — 이 Epic에 사람 승인이 필요한 작업이 있는가?
- `context/mcp-policy.md` — 외부 서비스 연결이 필요한가? allowlist에 있는가?

---

## Multi-Repo Workspaces

워크스페이스 루트에 `.git/`이 없고, 하위 디렉토리(e.g., `backend/`, `frontend/`)가 각각 독립된 git repo인 경우.

### commit_stage() 동작
- 워크스페이스 루트가 git repo인지 먼저 확인
- git repo가 아니면 직계 하위 디렉토리에서 `.git/`을 가진 repo를 탐색
- 변경이 있는 각 repo에서 독립적으로 commit + push
- 커밋 메시지에 `[repo-name]` 접두사 추가: `feat: Stage 1 [backend] — auth API`

### Planner 주의사항
- Slice의 Files 필드에 repo 이름을 접두사로 표기: `backend/src/api/auth.ts`
- 각 Slice에 `**Repo:**` 필드로 대상 repo 명시
- 같은 Stage 내 파일 겹침 규칙은 전체 워크스페이스 기준 (repo별이 아님)
- 서로 다른 repo만 수정하는 Slice는 병렬 실행에 안전
- 크로스리포 의존성(e.g., API 변경 → UI 반영)은 별도 Stage로 분리

### Reviewer 주의사항
- 각 repo에서 개별적으로 git status → add → commit → push
- 핸드오프에 각 repo의 커밋 해시 기록
- 워크스페이스 루트에서 `git` 명령을 실행하지 않는다

### Deploy Hook
- `scripts/deploy-hook.sh`가 존재하고 실행 가능하면, 각 Stage 커밋 후 자동 실행
- 인자: stage 번호 (`$1`)
- 실패해도 Epic은 계속 진행 (non-blocking)

### 단일 Repo 워크스페이스
- 기존과 완전히 동일하게 동작. 변경 없음.

---

## Epic Plan 작성법

### 시작 전 체크리스트

- [ ] `handoff/latest.md` 읽었는가? (현재 상태 파악)
- [ ] `context/decision-log.md` 확인했는가? (이전 결정 재논의 방지)
- [ ] `context/access-policy.md` 확인했는가? (사람 승인 필요 작업 확인)
- [ ] 관련 코드를 충분히 읽었는가?

### Epic Plan 구조

`templates/epic-plan.md`를 따르되, 핵심은 다음 4가지:

1. **Goal**: 이 기능이 완성되면 어떤 상태인가 (2-3문장)
2. **Stages & Slices**: 층 순서로 분해, 파일 겹침 없이
3. **Done when**: 각 Slice마다 구체적 완료 기준 (verify.md에 쓸 수 있을 정도로)
4. **Rollback Strategy**: 중간에 포기해야 할 때 어디까지 되돌리는가

### 좋은 Epic Plan의 특징

- Slice 설명만 읽어도 Developer가 무엇을 만들지 감이 잡힘
- 각 Slice의 Files 목록이 겹치지 않음 (같은 Stage 내)
- 완료 기준이 측정 가능함 (테스트, 화면 확인, lint 통과)
- Open Questions가 남아 있으면 해당 Slice를 뒤 Stage로 미룸

### 나쁜 Epic Plan의 신호

- "구현한다"만 적혀 있고 완료 기준이 없음
- 하나의 Slice가 10개 이상 파일을 건드림
- 같은 Stage 안 Slice들이 공통 파일을 수정함
- "나머지 전부"라는 Slice가 있음 (범위가 불명확)
- Open Questions가 있는데 첫 번째 Stage에 배치됨

---

## 실행 방법

### 자동 실행 (권장)

```bash
# Epic 분해 + Stage별 자동 실행
./scripts/run-epic.sh "Epic 1 — 사용자 인증 시스템"

# 기존 Epic plan이 있으면 자동 감지하여 재사용
./scripts/run-epic.sh 1
```

동작 순서:
1. `/plan Epic N` → epic plan 생성 (`outputs/plans/epic-N-plan.md`)
2. Stage & Slice 파싱
3. Stage별 실행:
   - 단일 Slice → 순차 (Reviewer가 커밋)
   - 복수 Slice → 병렬 (`--no-commit` + Stage 통합 커밋)
4. 모든 Stage 완료 → EPIC COMPLETE

### 수동 실행

```bash
# 1. Epic plan 만들기
/plan Epic 1 — 사용자 인증 시스템

# 2. 각 Slice를 순서대로 실행
/plan Task 1 — 회원가입 DB 스키마
/develop Task 1 — 회원가입 DB 스키마
/review Task 1 — 회원가입 DB 스키마

/plan Task 2 — 회원가입 API
/develop Task 2 — 회원가입 API
/review Task 2 — 회원가입 API
```

수동 실행은 세밀한 제어가 필요할 때 쓴다.
중간에 방향을 바꾸거나, 특정 Slice만 다시 하거나, 병렬이 아닌 순차로 하고 싶을 때.

### 실패 시 복구

```
Stage 2에서 Slice B가 실패한 경우:

1. 로그 확인: /tmp/프로젝트명-run/task-slice-1/stdout.log
2. REQUEST_CHANGES이면:
   /develop "Slice B — REQUEST_CHANGES 수정"
   /review "Slice B — 재검사"
3. 수정 후 나머지 Stage 이어서:
   ./scripts/run-epic.sh 1  (이미 완료된 plan 재사용)
```

---

## Epic Plan 예시

```markdown
# Epic Plan

## Epic
Epic 1 — 회원가입 기능

## Goal
이메일/비밀번호로 회원가입하고, 가입 즉시 로그인되어 메인 화면으로 이동한다.

## Context
- User need: 현재 게스트 모드만 가능, 데이터 저장 불가
- Related docs: docs/project-plan.md의 Feature 1
- Dependencies: Supabase Auth 설정 완료

## Stages & Slices

### Stage 1
#### Slice 1: DB 스키마 + RLS
- **What:** users 테이블, profiles 테이블, RLS 정책
- **Files:** supabase/migrations/001_auth.sql
- **Depends on:** (none)
- **Done when:** 마이그레이션 성공 + RLS 테스트 통과

### Stage 2
#### Slice 2: Auth 서비스
- **What:** 회원가입 + 로그인 + 로그아웃 API
- **Files:** src/services/auth_service.dart, src/models/user.dart
- **Depends on:** Stage 1 (users 테이블)
- **Done when:** 유닛 테스트 통과 (가입/로그인/로그아웃)

#### Slice 3: Auth 상태 관리
- **What:** AuthProvider + 로그인 상태 감지
- **Files:** src/providers/auth_provider.dart
- **Depends on:** Stage 1 (users 테이블)
- **Done when:** Provider 테스트 통과

### Stage 3
#### Slice 4: 회원가입 화면
- **What:** 이메일/비밀번호 입력 폼 + 유효성 검사 + 에러 표시
- **Files:** src/screens/signup_screen.dart, src/widgets/auth_form.dart
- **Depends on:** Slice 2 (auth_service), Slice 3 (auth_provider)
- **Done when:** 빈 폼 제출 시 에러 + 정상 입력 시 가입 성공 + 메인으로 이동

## Epic Acceptance Criteria
- [ ] 이메일/비밀번호로 가입 가능
- [ ] 가입 후 자동 로그인 + 메인 이동
- [ ] 빈 값/중복 이메일 에러 처리
- [ ] lint + test 통과

## Open Questions
- 소셜 로그인은 이 Epic에 포함하지 않음 (별도 Epic)

## Rollback Strategy
- Stage 1만 완료된 경우: 마이그레이션만 남기고 나머지 revert
- Stage 2까지 완료된 경우: API는 유지, UI만 revert 가능
```

이 예시에서 Stage 2의 Slice 2와 Slice 3는 파일이 겹치지 않으므로 병렬 실행된다.
Stage 3의 Slice 4는 둘 다에 의존하므로 반드시 Stage 2 완료 후 실행된다.

### Multi-Repo 예시

Multi-repo 워크스페이스에서는 `**Repo:**` 필드와 파일 경로에 repo 접두사를 붙인다:

```markdown
### Stage 2
#### Slice 2: Auth API
- **What:** 회원가입 + 로그인 API
- **Repo:** backend
- **Files:** backend/src/services/auth.ts, backend/src/routes/auth.ts
- **Depends on:** Stage 1
- **Done when:** API 테스트 통과

#### Slice 3: Auth UI
- **What:** 로그인 화면
- **Repo:** frontend
- **Files:** frontend/src/pages/login.tsx, frontend/src/hooks/useAuth.ts
- **Depends on:** Stage 1
- **Done when:** 로그인 폼 표시 + API 연동
```

Slice 2와 3은 서로 다른 repo만 수정하므로 같은 Stage에서 병렬 실행 가능.
