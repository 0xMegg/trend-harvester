# Claude Code Harness Template v5

Claude Code & Cowork 마스터 가이드(583p) 기반 재사용 가능 작업 환경 템플릿.

v5는 가이드북 전 장을 대조 분석하여 누락된 영역을 보강한 버전이다.
외부 통합 정책, 토큰/컨텍스트 관리, Skill 정밀 설계, Plugin 배포 구조,
평가 루프, 권한 정책 문서를 추가하고, 병렬 Stage의 git 통합 커밋 문제를 해결했다.

## 새 프로젝트 시작하기

### 준비물
- 이 템플릿 레포
- 프로젝트 기획안 (자유 형식 OK, `docs/project-plan.md` 양식 제공)
- Claude Code CLI (`claude`)

### Step 1: 프로젝트 생성 + 하네스 복사

```bash
mkdir my-new-app && cd my-new-app
git init

# 하네스 복사 (프로젝트 이름을 인자로)
/path/to/claude-code-harness-template/setup.sh my-new-app
```

### Step 2: 기획안 넣기

```bash
# 방법 A: 양식 복사 후 직접 채우기
cp /path/to/claude-code-harness-template/docs/project-plan.md docs/project-plan.md

# 방법 B: 기존 기획서가 있으면 그냥 docs/에 넣기
cp ~/my-plan.pdf docs/
cp ~/my-plan.md docs/
```

### Step 3: 초기화 세션 (Claude가 하네스 설정을 채움)

```bash
claude "docs/에 있는 기획안을 읽고, PlaceholderGuide.md를 참고해서
하네스의 모든 {{PLACEHOLDER}}를 채워줘.
대상: CLAUDE.md, context/about-me.md, context/access-policy.md,
context/mcp-policy.md, templates/role-*.md
그리고 .claude/rules/와 .claude/hooks/post-edit-check.sh도
이 프로젝트에 맞게 수정해줘."
```

> 이 세션이 끝나면 하네스가 프로젝트에 맞게 완성됩니다.

### Step 4: 개발 시작

#### 방법 A: 자동 실행 (권장)

한 커맨드로 Plan → Develop → Review를 각각 새 세션에서 순차 실행:

```bash
# 단일 태스크
./scripts/run-task.sh "Task 1 — 회원가입 폼 빈값 제출 버그 수정"

# Epic (분해 + 각 Slice 자동 실행)
./scripts/run-epic.sh "Epic 1 — 다이브 로그 입력 화면 전체 구현"
```

- 순차 실행: Reviewer가 직접 커밋+푸시
- 병렬 Stage: 각 Slice는 `--no-commit`으로 실행, Stage 완료 후 통합 커밋 (모든 Slice가 git에 반영됨)
- REQUEST_CHANGES → 해당 Slice에서 멈추고 리뷰 내용 출력
- 로그: `/tmp/프로젝트명-run/{plan,develop,review}.log`

#### 방법 B: 수동 실행 (세밀한 제어)

각 단계를 별도 세션에서 수동으로:
```
/plan Task 1 — 회원가입 폼 빈값 제출 버그 수정
/develop Task 1 — 회원가입 폼 빈값 제출 버그 수정
/review Task 1 — 회원가입 폼 빈값 제출 버그 수정
```

**REQUEST_CHANGES가 나오면:**
```
/develop Task 1 — REQUEST_CHANGES 수정사항 반영
/review Task 1 — 재검사
```

### 전체 흐름

```
기획안 작성 + setup.sh 실행
  ↓
초기화 세션: 기획안 읽고 하네스 설정 완성
  ↓
자동: ./scripts/run-epic.sh "Epic N — 기능"  (Epic 분해 + Stage별 통합 커밋)
수동: /plan → /develop → /review             (세밀한 제어가 필요할 때)
  ↓
평가: templates/evaluation.md로 Task별 5대 지표 기록
  ↓
(handoff/latest.md + decision-log.md가 자동 업데이트되어 세션 간 상태 유지)
```

---

## 기존 프로젝트에 적용하기

```bash
cd /path/to/existing-project
/path/to/claude-code-harness-template/setup.sh my-existing-app

# 초기화 세션에서 기존 코드 분석도 요청
claude "이 프로젝트의 코드를 분석하고, PlaceholderGuide.md를 참고해서
하네스의 모든 {{PLACEHOLDER}}를 채워줘.
대상: CLAUDE.md, context/about-me.md, context/access-policy.md,
context/mcp-policy.md, templates/role-*.md
그리고 .claude/rules/와 .claude/hooks/post-edit-check.sh도
이 프로젝트에 맞게 수정해줘.
추가로 프로젝트의 좋은 점, 개선할 점, 바로 고쳐야 할 점을 분석해서
handoff/latest.md에 Task Queue로 정리해줘."
```

---

## 세션 종류 요약

| 세션 | 언제 쓰는지 | 커맨드 |
|------|-----------|--------|
| **초기화** | 프로젝트 시작할 때 1번 | `"기획안 읽고 placeholder 채워줘"` |
| **Epic 분해** | 큰 기능 시작할 때 | `/plan Epic N — [기능 설명]` |
| **Planner** | Task/Slice마다 첫 번째 | `/plan Task N — [설명]` |
| **Developer** | Task마다 두 번째 | `/develop Task N — [설명]` |
| **Reviewer** | Task마다 세 번째 | `/review Task N — [설명]` |
| **일반** | 간단한 질문/수정 | 역할 지정 없이 자유롭게 |

---

## 구조

```
project/
├── CLAUDE.md                              # 프로젝트 계약서 (AI 진입점, ~70줄)
├── .claude/
│   ├── settings.json                      # 권한/안전 설정
│   ├── hooks/
│   │   ├── block-dangerous.sh             # PreToolUse: 위험 명령 차단
│   │   ├── post-edit-check.sh             # PostToolUse: BLOCK/WARN 심각도 분리
│   │   ├── post-edit-lint.sh              # PostToolUse: 자동 lint (프로젝트 자동 감지)
│   │   └── post-edit-test.sh              # PostToolUse: 변경 영역 타겟 테스트 자동 실행
│   ├── commands/
│   │   ├── plan.md                        # /plan: Planner 역할 진입
│   │   ├── develop.md                     # /develop: Developer 역할 진입
│   │   └── review.md                      # /review: Reviewer 역할 진입
│   └── rules/
│       ├── api.md                         # API/DB 규칙
│       ├── frontend.md                    # UI 규칙
│       ├── testing.md                     # 테스트 규칙
│       ├── git.md                         # 커밋/브랜치 규칙
│       └── gotchas.md                     # 프로젝트 고유 함정 (CLAUDE.md에서 분리)
├── context/
│   ├── about-me.md                        # 프로젝트 배경
│   ├── working-rules.md                   # 작업 원칙 + 3-Role + 토큰 관리 + 평가 루프
│   ├── decision-log.md                    # 결정 기록 (재논의 방지)
│   ├── access-policy.md                   # AI 도구 접근 정책 (허용/승인/차단 + 4층 강제)
│   └── mcp-policy.md                      # MCP & 외부 통합 정책 (평가 체크리스트 + allowlist)
├── templates/
│   ├── role-planner.md                    # Planner 역할
│   ├── role-developer.md                  # Developer 역할
│   ├── role-reviewer.md                   # Reviewer 역할
│   ├── epic-plan.md                       # Epic → Slice 분해 형식
│   ├── plan.md                            # 작업 계획 형식 (per slice/task)
│   ├── verify.md                          # 검증 계획 (완료 기준 + 제약 조건 + Confidence)
│   ├── evaluation.md                      # Task 평가 루프 (5대 지표)
│   ├── handoff.md                         # 세션 인수인계 형식
│   └── bug-fix.md                         # 버그 수정 형식
├── skills/
│   ├── SKILL-TEST-CHECKLIST.md            # Skill 테스트 (trigger/negative/format/gotcha/boundary)
│   ├── bug-fix/
│   │   ├── SKILL.md                       # 버그 수정 워크플로 (trigger/negative 표현 포함)
│   │   └── examples/good-output.md        # 좋은 버그 수정 예시 (프로젝트별 교체)
│   └── code-review/
│       ├── SKILL.md                       # 코드 리뷰 워크플로 (trigger/negative 표현 포함)
│       └── examples/good-output.md        # 좋은 리뷰 예시 (프로젝트별 교체)
├── handoff/
│   └── latest.md                          # 현재 상태 (세션 간 연결고리)
├── outputs/
│   ├── plans/                             # Planner 산출물
│   ├── reviews/                           # Reviewer 산출물
│   └── archive/                           # 해결된 과거 문서
├── scripts/
│   ├── run-task.sh                        # 단일 Task 자동 실행 (--no-commit 지원)
│   └── run-epic.sh                        # Epic 분해 + Stage 통합 커밋
├── docs/
│   ├── project-plan.md                    # 프로젝트 기획안 양식
│   ├── plugin-guide.md                    # Plugin 구조, 보안 체크리스트, 배포 전략
│   └── epic-guide.md                      # Epic 분해 기준, 병렬 실행, 실패 복구
├── PlaceholderGuide.md                    # 초기화 세션용: placeholder 채우기 가이드
├── setup.sh                               # 새 프로젝트 초기화 스크립트
└── README.md
```

### 문서 역할 구분

| 문서 | 용도 |
|------|------|
| `README.md` | 시작 가이드, 사용법 |
| `docs/project-plan.md` | 프로젝트 기획안 양식 |
| `docs/plugin-guide.md` | Plugin 승격 기준, 보안, 배포 전략 |
| `docs/epic-guide.md` | Epic 분해 원칙, 병렬 Stage 실행, v5 변경점 |
| `PlaceholderGuide.md` | 초기화 세션에서 placeholder 채우기 규칙 |
| `context/access-policy.md` | 사람이 읽는 AI 도구 접근 정책 |
| `context/mcp-policy.md` | MCP 평가 체크리스트, allowlist, 연결 원칙 |
| `templates/evaluation.md` | Task 완료 후 5대 지표 기록 |
| `skills/SKILL-TEST-CHECKLIST.md` | Skill 테스트 (trigger/negative 등 5종) |
| 나머지 전부 | 세션마다 자동으로 읽고 따르는 하네스 파일 |

---

## 파일 간 연결 구조

```
CLAUDE.md (AI 진입점)
  ├── context/about-me.md ← 프로젝트 배경
  ├── context/working-rules.md ← 3-Role + 토큰 관리 + 평가 루프
  ├── context/access-policy.md ← 허용/승인/차단 정책 (4층 강제)
  ├── context/mcp-policy.md ← MCP 평가 + allowlist
  ├── handoff/latest.md ← 세션 간 연결고리
  │     ↑ Planner 쓰기 → Developer 읽기 → Reviewer 쓰기
  ├── templates/role-*.md ← 각 역할의 행동 규칙
  │     ├── role-planner.md → outputs/plans/ (plan + verify)
  │     ├── role-developer.md → handoff/latest.md (커밋 안 함)
  │     └── role-reviewer.md → outputs/reviews/ + git commit+push
  ├── templates/verify.md ← 완료 기준 + 제약 조건 + Confidence level
  ├── templates/evaluation.md ← Task별 5대 지표 기록
  ├── docs/plugin-guide.md ← Skill→Plugin 승격, 보안
  ├── docs/epic-guide.md ← Epic 분해 기준, 병렬 실행 가이드
  ├── skills/SKILL-TEST-CHECKLIST.md ← Skill 품질 검증
  ├── .claude/commands/ ← 슬래시 커맨드 (/plan, /develop, /review)
  ├── .claude/rules/ ← 자동 적용 규칙
  ├── .claude/hooks/ ← 자동 안전 검사
  └── .claude/settings.json ← 권한 + hook 연결
```

### 병렬 Epic 실행 흐름

```
run-epic.sh "Epic N"
  ↓
/plan Epic N → epic plan 생성 (Stage & Slice 구조)
  ↓
Stage 1 (병렬):
  Slice A: run-task.sh --no-commit → Plan → Develop → Review (git 안 함)
  Slice B: run-task.sh --no-commit → Plan → Develop → Review (git 안 함)
  → commit_stage(): git add -A → commit → push (모든 Slice 통합 반영)
  ↓
Stage 2 (병렬):
  Slice C: run-task.sh --no-commit → Plan → Develop → Review (git 안 함)
  → commit_stage(): 통합 커밋
  ↓
EPIC COMPLETE
```

---

## 하네스 6요소 (가이드북 기준)

| # | 요소 | 구현 | 역할 |
|---|------|------|------|
| 1 | **Permissions** | settings.json + access-policy.md | allow/deny/ask 라우팅 + 사람이 읽는 정책 |
| 2 | **Validation** | hooks/ (block-dangerous, check, lint, test) | 사전 차단 + 사후 검증 |
| 3 | **Execution Mode** | commands/ + scripts/ | 3-Role 분리 + 자동/병렬 실행 |
| 4 | **State Maintenance** | handoff/ + context/ | 세션 간 연결고리 + 배경 지식 |
| 5 | **Decision Trace** | decision-log.md + evaluation.md | 의사결정 근거 + 품질 추적 |
| 6 | **External Integration** | mcp-policy.md + plugin-guide.md | MCP 정책 + Plugin 배포 |

---

## 가이드북 매핑

| 파일 | 가이드북 근거 |
|------|-------------|
| `CLAUDE.md` | 3.7 (7일 세팅), 5.3 (운영 원칙) |
| `settings.json` | 3.14 (보안), 5.10 (하네스 요소) |
| `access-policy.md` | 5.10 (Permission 최소 문서), 11장 (거버넌스) |
| `mcp-policy.md` | 5.10 (외부 통합), 6장 (MCP 설계) |
| `hooks/` | 2장 (Hook 개념), 5.10 (자동 개입), 5.6 (도구 출력 예산) |
| `commands/` | 6.1 (Skill 트리거), 운영 원칙 (반복 비용 절감) |
| `verify.md` | 5.11 (검증 계층), 5.10 ("무엇으로 확인할지 먼저 정한다") |
| `evaluation.md` | 5.11 (평가 루프 5가지 지표) |
| `rules/` | 5.4 (Rules 분리), 5.5 (컨텍스트 엔지니어링) |
| `working-rules.md` | 5.5 (토큰 경제학), 5.7 (세션 관리) |
| `context/` | 3.17 (스타터 번들), 5.2 (작업공간 설계) |
| `templates/` | 3.9 (템플릿 역할), 4.3 (실전 프롬프트) |
| `role-*.md` | 4.5 (역할 분리), 5.8 (에이전트 팀 패턴) |
| `skills/` | 6.1-6.3 (Skill anatomy, trigger 설계, 테스트) |
| `SKILL-TEST-CHECKLIST.md` | 6.3 (Skill 테스트 체크리스트) |
| `plugin-guide.md` | 6.4-6.5 (Plugin 구조, 배포 전략, 보안) |
| `epic-guide.md` | 5.8 (에이전트 팀), 5.10 (병렬 실행), 4.5 (역할 분리) |
| `handoff/` | 5.7 (Handoff > 세션 압축) |
| `outputs/` | 5.2 (산출물 관리) |
| `scripts/` | 5.8 (에이전트 팀 파일 충돌 방지), 실전 운영 |

---

## 버전 히스토리

### v4 → v5

| 개선 | v4 | v5 |
|------|----|----|
| 외부 통합 | MCP 관련 구조 없음 | **mcp-policy.md** — MCP 평가 체크리스트, allowlist, 연결 원칙 |
| 권한 정책 | settings.json만 (기계용) | **access-policy.md** — 허용/승인/차단 정책 + 4층 강제 구조 |
| 검증 계획 | 기본 체크리스트 | **verify.md 강화** — 완료 기준, 수정 금지 제약, Confidence level |
| 토큰 관리 | Compact Rules만 | **Token & Context Management** — 5가지 비용 구간, 모델 분리, 세션 분리 |
| Skills | 단일 description | **trigger/negative 표현** — 활성화/비활성화 명시, Gotchas 강화 |
| Skill 테스트 | 없음 | **SKILL-TEST-CHECKLIST.md** — 호출/오발동/형식/실패/경계 5종 |
| Plugin | 구조 없음 | **plugin-guide.md** — 승격 기준, 구조, 보안 체크리스트, 배포 전략 |
| 평가 루프 | 없음 | **evaluation.md** — 5대 지표 (성공률, 수정량, 시간, 토큰, 실패 유형) |
| 병렬 git | Slice별 개별 commit (충돌) | **Stage 통합 커밋** — --no-commit + commit_stage() |
| 하네스 모델 | 5요소 | **6요소** — External Integration 추가 |

### v3 → v4

| 개선 | v3 | v4 |
|------|----|----|
| 편집 후 검사 | 전부 WARNING (exit 0) | **BLOCK/WARN 심각도 분리** — 시크릿, 금지패턴은 exit 2로 블로킹 |
| 편집 후 테스트 | 없음 (수동 실행) | **post-edit-test.sh** — 변경 영역 대응 테스트 자동 실행 |
| CLAUDE.md | ~90줄 (Gotchas, Templates 등 포함) | **~50줄로 다이어트** — Gotchas → rules/gotchas.md 분리 |
| Gotchas | CLAUDE.md 본문에 포함 | **rules/gotchas.md로 분리** — auto-applied rule로 승격 |
| 금지 패턴 | 훅에 하드코딩 또는 없음 | **BLOCKED_PATTERNS 배열** — 프로젝트별 설정 가능 |

### v2 → v3

| 개선 | v2 | v3 |
|------|----|----|
| 역할 진입 | 매번 긴 프롬프트 입력 | **`/plan`, `/develop`, `/review` 슬래시 커맨드** |
| 검증 계획 | plan.md 내 Acceptance Criteria | **독립 `templates/verify.md` + Planner가 작성** |
| 편집 후 lint | 수동 실행 | **PostToolUse hook 자동 실행 (프로젝트 자동 감지)** |
| 세션 관리 | 언급 없음 | **working-rules.md에 continue/resume/fork/worktree 지침** |
| /compact 지침 | 없음 | **Compact Rules로 보존 항목 사전 정의** |
| Gotchas | 없음 | **CLAUDE.md에 프로젝트 고유 함정 섹션** |
| Skill 구조 | SKILL.md만 | **examples/ 폴더 추가 (좋은 결과 감각 제공)** |

### v1 → v2

| 개선 | v1 | v2 |
|------|----|----|
| 워크플로우 | 단일 세션 | **3-Role (Planner → Developer → Reviewer)** |
| 커밋 권한 | 명시 없음 | **Reviewer만 APPROVE 후 커밋+푸시** |
| settings.json | Read/Write만 허용 | **git, lint, test Bash 자동 허가** |
| 산출물 관리 | outputs/ 단일 폴더 | **outputs/plans/, reviews/, archive/ 분리** |
| 브랜치 규칙 | "main 직접 푸시 금지" 고정 | **Solo/협업 구분** |
| 파일 간 연결 | 일부만 참조 | **전체 구조 참조** |
| 초기화 | placeholder 직접 채움 | **초기화 세션에서 자동 채움** |
