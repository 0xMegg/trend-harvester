# Handoff — 2026-04-11 PM-2 (Hotfix: harness-report fallback 제거)

## What Changed (2026-04-11 PM-2)
- **harness-report.sh evaluations fallback 결함 수정** (this repo `c804a71`, target sync `8e94671`).
  - 기존 코드는 `TARGET_DIR/outputs/evaluations`가 없으면 `PROJECT_DIR/outputs/evaluations`로 fallback. src/ 측정 시 trend-harvester 자체의 `outputs/evaluations/20260410-harvest-e2e.md` 1건이 끼어들어 +2점 인플레이션 발생.
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
- 영상 분석 RTF + 사용자 추가 3건을 기반으로 5개 항목을 trend-harvester 파이프라인에 순차 투입.
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
