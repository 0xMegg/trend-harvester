# Handoff — 2026-04-11 PM-4 (Self-improvement batch: 5 carry-overs closed)

## What Changed (2026-04-11 PM-4)
PM-3 What's Next 이월 5건 + GitHub rename + 두 repo push까지 한 세션에서 모두 정리.

### 인프라 정리
- **GitHub repo rename** (`gh repo rename harness-forge --repo 0xMegg/trend-harvester`) → `https://github.com/0xMegg/harness-forge`. 로컬 origin URL 갱신.
- **두 repo 모두 origin push** 동기화 시작. 이후 모든 PM-4 작업 중 PR 단위로 분리 commit + push 유지.

### 5개 self-improvement 항목 (PR 단위 분리)

| # | 작업 | this repo commits | 결과 |
|---|---|---|---|
| 4 | fitness-filter counterexample | `f52746f` | `bad-output.md` 신규 (3 케이스: abstract-proposal, low-fitness 1/10, HARD=0). PM-2 sycophancy 인시던트 보정 anchor. 점수 영향 없음 (calibration only). |
| 3 | `audit-coherence.sh` 작성 | `ebc89bd` (tool) → `9d330f8` (set -e fix) → `0839362` (harvest-policy sync) | 14-check 정합성 감사기 (HARD core 8 + 6 principles). dogfood가 잡은 진짜 drift 2건 같은 PR에 묶어 fix: src/scripts/diagnose+mcp-check `set -u` → `set -euo pipefail`, src/context/harvest-policy.md "Two-Stage Decision" 섹션 누락 (P3 plan 권장 rationale "Why two stages" 한 단락 동시 처리). |
| 5 | `verify-parallel-worktree.sh` + run-epic fix | `94e05da` (tool) → `95f4bc6` (fix + .gitignore) | 9-check worktree 격리 smoke test (mktemp 격리 repo). verify가 잡은 진짜 drift 2건 같은 PR에 묶어 fix: `finalize_slice_worktree` leftover `.harvest-wt/stage-N/` 디렉토리 정리 (`rmdir` 2회), `.gitignore` + `src/.gitignore`에 `.harvest-wt/` 등록 (방어선). |
| 2 | Proposal B dry-run | `d6f38a3` | 30-commit historical replay → **96.7% escape rate** (CODE-only 95%). `outputs/proposals/proposal-b-eval-enforcement-dry-run.md` 보고서. **REJECT 권고** + underlying intent를 1번 항목으로 routing. |
| 1 | Evaluation Loop 워크플로 명시 | `c6ebd35` (policy+template) → `dcb78d9` (runtime) | working-rules.md 양쪽 sync, 4-anchor (Who/When/For-which/What). `templates/evaluation.md`에 auto-fill metadata + "What I would do differently" 추가. `run-task.sh write_evaluation_stub()` APPROVE 직후 자동 호출 — CODE 매치 시 stub 생성, META-only는 skip, idempotent. |

### Drift fix가 입증한 자가검증 가치
- audit-coherence.sh가 본 repo는 14/14 PASS인데 src/ target에서 2건 drift 잡음 (P2 set-e + P5 two-stage) → 즉시 수정. 이게 plan 파일이 권장한 "마개조 자가 검증" 효과의 첫 사례.
- verify-parallel-worktree.sh가 8/9 PASS로 1건 fail → run-epic.sh의 `.harvest-wt/stage-N/` leftover 디렉토리 누적 잠재 버그 발견. 매 epic 실행마다 누적될 수 있던 noise를 사전 차단.
- **두 도구 모두 작성된 첫 세션에서 진짜 drift를 catch했다는 점이 도구 가치 입증**.

### 정책 cross-reference 보존
- `working-rules.md` Evaluation Loop 섹션 끝에 "Why this is not a commit-time hook" 단락 추가, dry-run report 경로 박음. 미래 누군가 commit hook을 다시 제안하면 30-commit replay 데이터가 의사결정 history로 남음.
- `harvest-policy.md` "Two-Stage Decision" 섹션에 PM-2 sycophancy 인시던트 cross-reference (`feedback_scoring_integrity` 메모리). 두 단계가 advisory 아닌 의무인 이유 명시.

### Current State (2026-04-11 PM-4)
- Baseline: **53/100** (변동 없음 — 모든 변경이 docs/test/calibration/runtime이라 채점 메트릭 영향 없음)
- this repo: origin/main과 동기화 (clean working tree)
- target repo: origin/main과 동기화 (clean working tree)
- GitHub remote URL: **`0xMegg/harness-forge.git`** (rename 완료)
- 새 도구 (총 2개): `scripts/audit-coherence.sh`, `scripts/verify-parallel-worktree.sh` (양쪽 src/scripts/에도 sync)
- 새 자동화: `run-task.sh APPROVE` → `write_evaluation_stub` → `outputs/evaluations/{date}-task-{N}-{slug}.md` stub
- 옛 memory 디렉토리 백업 보존 중 (`-...-trend-harvester/`) — PM-3 결정 그대로

## What's Next (2026-04-11 PM-4)
- [ ] (선택) 옛 memory 백업 디렉토리 `-...-trend-harvester/` 수동 삭제 — PM-4까지 새 경로 안정화 확인됨
- [ ] (운영) `write_evaluation_stub` dogfood — 다음 코드 변경 task 실행 시 stub이 정확히 만들어지는지 + Reviewer가 fill 가능한지 실측. 결과 따라 sed 패턴 또는 template field 보정
- [ ] (선택, P4) audit plan 권장 외부 source 다양성 복원 — RSS 2~3개 (Simon Willison, Latent Space) 추가. trend-harvester 관성 유지 차원
- [ ] (관찰) audit-coherence.sh 주기 실행 정책 — `/harvest` 풀 파이프라인 직전에 자동 실행하는 게 자연스러움. 다음 harvest 배치 때 수동 확인 후 자동화 결정
- [ ] (이전부터) harness-report 6+영역 가중치 재설계 (rules 5/20, hooks 11/15 등 여전히 헤드룸 47점 — PM-3 P1 항목, 우선순위 낮음)

---

# Handoff — 2026-04-11 PM-3 (Rename: trend-harvester → harness-forge)

## What Changed (2026-04-11 PM-3)
- **프로젝트 우산 rename**: `trend-harvester` → `harness-forge` (this repo `7d8a79b`).
  - 로컬 경로: `~/Dev/13.claude/templates/trend-harvester/` → `~/Dev/13.claude/templates/harness-forge/`
  - Memory 경로: `~/.claude/projects/-Users-mero-Dev-13-claude-templates-trend-harvester/` → `-...-harness-forge/` (`feedback_*` 3건 보존)
  - `CLAUDE.md` Project Name 갱신, `src/.claude/settings.local.json` 절대경로 갱신
  - `trend-harvest` skill은 별도 모듈로 그대로 유지 (umbrella 이름만 변경)
- **새 세션 검증 (PM-3 verification)**:
  - `bash scripts/harness-report.sh quick --target src/` → **53/100 회귀 없음** (rules 5, skills 12, hooks 11, guidance 7, scripts 10, templates 8, evaluations 0, test_lint skip)
  - `bash scripts/run-harvest.sh status` → 정상 (baseline 53, applied 9, seen 32) — `settings.local.json` 절대경로 권한 정상 작동
  - `git remote -v` → origin 보존 (URL은 옛 `trend-harvester.git` 그대로 — GitHub repo rename은 미수행)
  - `git log --oneline -5` → rename 커밋 + PM-2 hotfix 4개 보존
  - MEMORY.md 자동 로드 + feedback 3건 보존 확인

### Current State (2026-04-11 PM-3)
- Baseline: **53/100** (PM-2 값 그대로, rename은 측정에 영향 없음)
- this repo: origin/main 대비 5 commits ahead (PM-2의 4 + rename `7d8a79b`)
- target repo: origin/main 대비 2 commits ahead (PM-2 sync 그대로)
- GitHub remote URL: 옛 이름 (`0xMegg/trend-harvester.git`) — 로컬-원격 이름 불일치 상태
- 옛 memory 디렉토리 백업 보존 중 (`-...-trend-harvester/`)

## What's Next (2026-04-11 PM-3)
- [ ] (결정 필요) GitHub repo도 `trend-harvester` → `harness-forge`로 rename할지 — 결정 후 origin URL 갱신
- [ ] (안정화 후) 옛 memory 백업 디렉토리 `-...-trend-harvester/` 수동 삭제
- [ ] (필요 시) 두 repo 모두 origin push (this repo 5 ahead, target repo 2 ahead)
- [ ] (이월) PM-2의 outputs/evaluations 워크플로 명시 / Proposal B 재검토 / audit-coherence.sh / counterexample / 병렬 검증

---

# Handoff — 2026-04-11 PM-2 (Hotfix: harness-report fallback 제거)

## What Changed (2026-04-11 PM-2)
- **harness-report.sh evaluations fallback 결함 수정** (this repo `c804a71`, target sync `8e94671`).
  - 기존 코드는 `TARGET_DIR/outputs/evaluations`가 없으면 `PROJECT_DIR/outputs/evaluations`로 fallback. src/ 측정 시 harness-forge 자체의 `outputs/evaluations/20260410-harvest-e2e.md` 1건이 끼어들어 +2점 인플레이션 발생.
  - 수정: fallback 루프 삭제, TARGET_DIR만 측정. `scripts/harness-report.sh` + `src/scripts/harness-report.sh` 동시 동기화. shellcheck 통과.
- **양쪽 측정 결과 일치 확인**: `bash scripts/harness-report.sh quick --target src/` 와 `--target ../claude-code-harness-template/` 모두 **53/100** (둘 다 evaluations 0/10).
- **Run 20260411-040351 기록 정정** (같은 커밋에 묶음):
  - `harvest/baseline.json`: 55 → 53, evaluations 2/"1 records" → 0/"0 records"
  - `harvest/applied/20260411-040351-no-verify-deny-applied.json`: gate2 baseline_score / post_apply_score 53, note에 정정 사실 기록
  - `harvest/reports/20260411-040351.md`: Measurement / Harness Impact 섹션 정정 + Postscript 추가
- **거짓 정보 폐기**: 이전 handoff의 "Phase 3의 53은 transient anomaly" 서술은 사실의 반대였음. 실제로는 Phase 3의 53이 production 실측, sandbox 55가 fallback 인공물. 정정 완료.

### Current State (2026-04-11 PM-2)
- Baseline: **53/100** (quick mode, target=src/ — target repo도 동일)
- Headroom: ~47점
- src/.claude/settings.json deny: 13 entries (직전 PM 배치의 4 패턴 적용분 그대로 유지)
- this repo: origin/main 대비 4 commits ahead (baebe9d → 97d9eba → ccefcb9 → c804a71)
- target repo: origin/main 대비 2 commits ahead (8687b02 → 8e94671)

## What's Next (2026-04-11 PM-2)
- [ ] (검토) `outputs/evaluations/`가 빈 상태로 production 운영되는 상황 — 사용자가 실제로 어떻게 evaluation 파일을 만들 워크플로인지 명시 필요. Proposal B "commit-time eval 강제"가 재후보가 될 수 있음
- [ ] 보류된 Proposal B (commit-time eval 강제) 실전 친화도 추가 검토 후 재투입 여부 판단 — `[no-eval]` 이스케이프 dry-run
- [ ] 보류된 Proposal C (retry-counter) 재설계 시에만 재투입
- [ ] (이전부터) `scripts/audit-coherence.sh` 작성
- [ ] (이전부터) fitness-filter examples에 counterexample 추가
- [ ] (이전부터) 병렬 안정성 실전 검증 (`HARVEST_PARALLEL_WORKTREE=1`)
- [ ] (필요 시) 두 repo 모두 origin push

---

# Handoff — 2026-04-11 (Harvest Batch: --no-verify deny)

## What Changed (2026-04-11 PM)
- `/harvest` 풀 파이프라인 1회 실행 (Run ID: `20260411-040351`).
- 외부 14건 수집 → Phase 2 0/14 통과 → 사용자 push에 따라 재심 → 3건 후보 추출 (A 7/10 RECOMMEND, B 7/10 REVIEW, C 6/10 REVIEW) → A만 적용.
- **적용 항목**: `src/.claude/settings.json` permissions.deny에 `git commit --no-verify` / `-n` 4개 패턴 추가 (커밋 `baebe9d`).
  - 봉쇄 갭: 기존 PreToolUse/PostToolUse 훅 체인 6종이 `--no-verify` 플래그 1개로 전부 우회 가능했음.
- **Baseline 측정**: Phase 3 production 측정값은 **53/100** (정확). sandbox에서 본 55는 `harness-report.sh` evaluations fallback 결함으로 인한 인공물(`outputs/evaluations/20260410-harvest-e2e.md` 1 record가 PROJECT_DIR fallback으로 카운트됨)이었음 — PM-2 hotfix `c804a71`에서 fallback 제거하고 모든 기록 정정 완료.
- **Sycophancy 인시던트**: token_efficiency 채점에 대한 사용자 challenge에 즉시 점수를 올렸다가 반려당함. `feedback_scoring_integrity.md` 메모리 추가 (점수 challenge 시 원래 근거 설명이 우선, 압력에 의한 재채점 금지).

### Current State (2026-04-11 PM)
- Baseline: **53/100** (quick mode, target=src/) — PM-2 hotfix 후 정확한 production 값
- src/.claude/settings.json: deny 엔트리 9 → 13
- 변경 없음: rules/skills/hooks/scripts/templates/guidance/test_lint
- Headroom: ~47점
- 미적용 후보 보류: B (commit-time eval 강제, REVIEW), C (retry-counter hook, REVIEW)

## What's Next (2026-04-11 PM)
- [ ] 보류된 Proposal B (commit-time eval 강제) 실전 친화도 추가 검토 후 재투입 여부 판단 — `[no-eval]` 이스케이프가 남발될지 dry-run으로 확인 필요
- [ ] 보류된 Proposal C (retry-counter) 현 형태로는 false-positive 우려, 재설계 시에만 재투입
- [ ] (이전부터) `../claude-code-harness-template/`의 기존 미커밋 변경 정리 → `build-template.sh` 실행
- [ ] (이전부터) `scripts/audit-coherence.sh` 작성
- [ ] (이전부터) fitness-filter examples에 counterexample 추가
- [ ] (이전부터) 병렬 안정성 실전 검증 (`HARVEST_PARALLEL_WORKTREE=1`)

---

# Handoff — 2026-04-11 (Philosophy Audit + P1: harness-report 재설계)

## What Changed (2026-04-11)
- `hugh-kim.space/trend-harvester-analysis.html` 원본 철학과 현재 구현의 정합성 감사 수행. 감사 결과 → `/Users/mero/.claude/plans/immutable-weaving-parasol.md`
- **판정: 마개조 아님.** 철학 HARD 코어 8개(5축·6단계·double-gating·autoresearch·HARD BLOCK·dedup·rollback·change_type) 모두 유지. 이탈 5건은 모두 "더 보수적 쪽"으로 원본보다 안전 강화. 유일한 실질 이슈는 harness-report 점수 체계 포화 1건.
- **P1 실행 완료**: `harness-report.sh` 8영역 100점 재설계로 Gate 2 판별력 복원.
  - 기존 6영역(포화) → 신규 8영역: Rules 20 / Skills 15 / Hooks 15 / **Guidance 10 (NEW)** / **Scripts 10 (NEW)** / Templates 10 / Evaluations 10 / Test-Lint 10
  - 깊이 메트릭 도입: Rules는 파일 수 + 유효 라인 수 tier (200/400/600/800/1200), Guidance는 `context/` + `docs/` 통합 측정
  - HARD enforcement 메트릭: Hooks는 `exit 1/2`/`return 1` 카운트, Scripts는 `exit 1/2` 또는 `set -euo pipefail` 카운트 — 원본 철학 Axis 3("HARD conversion")과 정렬
  - baseline.json: **65/100 → 53/100** (기존엔 rules/hooks/templates 포화로 허수, 재설계 후 실측값)
  - Gate 2 판별력 실측: HARD 훅 1개 추가 시 +1, 300줄 규칙 1개 추가 시 +6 확인
  - shellcheck 통과
  - `scripts/harness-report.sh` + `src/scripts/harness-report.sh` 동시 동기화 완료
  - README.md `Harness Score` 섹션 + `Hardening Highlights` 테이블 갱신

### Current State (2026-04-11)
- Baseline: **53/100** (quick mode, target=src/)
  - rules 5/20 (5 files, 106 lines) — rules 내용 얇음, 확장 여지 +15
  - skills 12/15 (3 skills, 3 ex, 3 gotchas)
  - hooks 11/15 (6 files, 3 with HARD exit) — 강화 여지 +4
  - guidance 7/10 (16 files, 923 lines)
  - scripts 10/10 (6 files, 5 HARD, 4 pipefail) — 사실상 포화 (작은 카테고리)
  - templates 8/10 (11 files, 8 filled)
  - evaluations 0/10 — `src/outputs/evaluations/` 없음
  - test_lint 0/10 (quick 모드 skip)
- Headroom: ~47점 — 향후 harvest 적용물이 움직일 공간 확보됨
- `src/scripts/harness-report.sh` 업데이트됐으나 `../claude-code-harness-template/`로의 sync는 미실행 (타겟 리포에 기존 미커밋 M/D 다수 존재 → 사용자가 타겟 정리 후 `bash scripts/build-template.sh` 직접 실행 권장)

## What's Next (2026-04-11)
- [ ] `../claude-code-harness-template/`의 기존 미커밋 변경 정리 → `build-template.sh` 실행 → target repo에서 업데이트 커밋
- [ ] [감사 P2] `scripts/audit-coherence.sh` 작성 — 원본 철학 6원칙/HARD 코어 8항목을 bash 체크리스트로 (plan 파일의 D섹션 참조)
- [ ] [감사 P3] `context/harvest-policy.md`에 "왜 2단계 판단 의무"인가 rationale 한 줄 추가
- [ ] [감사 P4 선택] 외부 소스 다양성 복원 원하면 RSS 2~3개 추가
- [ ] fitness-filter examples에 counterexample 추가 (이전 handoff 미완료)
- [ ] 병렬 안정성 실전 검증: `HARVEST_PARALLEL_WORKTREE=1`로 Epic dry-run

---

# Handoff — 2026-04-10 (Harvest Batch: 영상 분석 + user 3)

## What Changed
- 영상 분석 RTF + 사용자 추가 3건을 기반으로 5개 항목을 harvest 파이프라인에 순차 투입.
- SDK 최적화 항목은 user 결정으로 **이번 배치에서 제외** → 5항목으로 축소.
- 파이프라인 규칙대로 각 항목마다 1차 판단(5축 채점) → 2차 사용자 승인을 거침.
- Item 1(MCP 예시)은 사용자 거절, 나머지 4개는 적용.
- 세션 시작 시 워킹트리에 남아 있던 미커밋 작업(run-task/run-epic dry-run/argparse refactor, commands/epic·task, harvest-policy)은 Item 5 적용 전에 별도 정리 커밋으로 분리.

### 적용 결과
| Item | 주제 | 결과 | 커밋 |
|------|------|------|------|
| 1 | MCP 실전 설정 예시 (1차) | 거절 (fitness 6/10, user 거절) | — |
| 2 | Context 예산·세션 분할 체크리스트 + `post-edit-size-check.sh` | 적용 (9/10) | `e47eb67` |
| 3 | Troubleshooting 가이드 + `scripts/diagnose.sh` | 적용 (9/10) | `a0a8e31` |
| 5 | 브랜치 격리 (run-task/run-epic + pre-commit-branch-check 훅 + git.md 재작성) | 적용 (9/10, PENDING 승인) | `3ebd5bf` |
| 4 | 병렬 overlap gate (상시) + worktree 격리 (opt-in) | 적용 (9/10, PENDING 승인) | `2539e38` |
| 1* | MCP 실전 설정 (재시도): `.mcp.json.example` + `mcp-check.sh` + mcp-policy 부록 | 적용 (9/10, schema 교정 후 재투입) | `96761ef` |

### 추가 커밋
- `3fce0fb` — 세션 전 미커밋 작업 정리 (dry-run + argparse refactor, commands 문구, harvest-policy)
- `bb79220` — README 1차 갱신 (Hardening Highlights)
- `faf54ed` (soft-reset됨) — Item 5 초기 혼합 커밋. 세션 전 미커밋 작업이 섞여 있어 2개로 분리 후 폐기.

## Current State
- Baseline: 65/100 (모든 항목 Gate 2 pass — harness-report 점수 체계상 `rules` 5/5, `hooks` 6/6 등 이미 포화 상태라 항목 추가로 점수 변동 없음. 이 문제는 handoff/latest 이전 판에서 이미 지적됨.)
- `src/.claude/rules/gotchas.md` — 7개 규칙 (변경 없음)
- `src/.claude/hooks/` — 6개 (기존 4개 + `post-edit-size-check.sh`, `pre-commit-branch-check.sh`)
- `src/docs/` — 기존 4개 + `troubleshooting.md` 신규
- `src/scripts/` — 기존 + `diagnose.sh`, `mcp-check.sh` 신규
- `src/.mcp.json.example` — 신규 스캐폴드 (filesystem, github)
- `src/context/mcp-policy.md` — New MCP Pre-Connection Checklist 부록 추가
- `.gitignore` — `.mcp.json` 제외 추가
- `harvest/applied/` — Item 1(재시도)/2/3/4/5의 applied JSON 기록
- `harvest/raw/` — 6개 raw entry (1차 MCP rejected 포함)
- Template 전파: `bash scripts/build-template.sh` → `../claude-code-harness-template/`

## What's Next
- [ ] `../claude-code-harness-template/`에서 template 업데이트 커밋 (build-template.sh는 sync만 하고 커밋은 target repo에서 별도 수행)
- [ ] 병렬 안정성 실전 검증: `HARVEST_PARALLEL_WORKTREE=1`로 Epic dry-run 실행해 worktree 경로 자체 테스트
- [ ] `scripts/audit-coherence.sh` 작성 (이전 handoff의 미완료 항목)
- [ ] fitness-filter examples에 counterexample 추가 (이전 handoff의 미완료 항목)
- [ ] harness-report 점수 체계 개선 — 규칙/스킬/훅 포화 상태에서도 개선이 반영되도록 가중치 재설계
- [x] Item 1(MCP 예시) 재투입 — `mcp-check.sh` 검증기 + `.mcp.json.example` 로 9/10 달성 (`96761ef`)
- [ ] SDK 최적화는 프로젝트별 별도 처리 (이번 배치 분리됨)

## Notes
- 이번 배치는 `harvest-policy.md` L45-47에 따라 subprocess (`claude -p`) 없이 Claude 대화 내 직접 수행.
- Item 4, 5는 "modifies existing behavior"라 auto-apply 차단 대상 → PENDING 경로 + 사용자 명시 승인 후 적용.
- pre-commit-branch-check 훅은 Claude PreToolUse Bash 레이어에서 동작 — shell에서 직접 실행한 `git commit`은 차단하지 않음. 필요 시 `.git/hooks/pre-commit`로 확장 가능.
- worktree 격리는 opt-in이라 기본 동작에 영향 없음. 활성화 시 `.harvest-wt/` 디렉토리가 잠시 생성됐다가 정리됨.
