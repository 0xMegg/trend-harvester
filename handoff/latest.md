# Handoff — 2026-04-26 (forge round 3 — 회귀 픽스 + phase 분리 + 회귀 가드)

## 현재 task
forge round 3 — 사용자가 첨부한 honbabseoul Epic 3 / divebase Task 52.1 마지막 두 에러를 분석한 결과, "10+ 단계 폭증" 의 직접 원인은 Plan 품질이 아니라 **Review 진입 직전 인프라 레벨 크래시 + 사용자 의사결정 cascade** 였다. 본 round 는 그 두 크래시 모드를 닫고, 매 round 가 같은 부류 회귀를 양산하지 않도록 회귀 가드를 추가했다.

Plan 파일: `~/.claude/plans/async-wibbling-truffle.md` (한국어).

### 완료
- **P0 — scope-leak grep 회귀 픽스** (honbab Epic 3 직접 원인): `run-task.sh` 의 `_scope_task_num` (line 828), `dry_run_write_artifacts` task_num (line 614), `log_task_entry` START_EPOCH (line 430) + `run-epic.sh` 의 verdict cross-check task_num (line 898) / vc_marker tail (line 917). Slice 패턴 (`Slice N(.M)`) 인식 + `|| true` graceful fallback.
- **P1 — phase 분리** (divebase 10분 시한 우회): `run-task.sh --phase plan|develop|review|all` + `--resume` 옵션. main flow 를 review-only / develop-only 가지로 분기. thin wrapper `run-plan.sh` / `run-develop.sh` / `run-review.sh` 신설.
- **P1 — 회귀 가드** (cascade 차단): `src/scripts/check-harness-regression.sh` (`bash -n` + `shellcheck` + dry-run smoke 케이스별 격리). `scripts/build-template.sh` 가 build 전 자동 호출 + fail-closed.
- **P2 — Slice Sizing 안내**: `src/templates/role-developer.md` 에 10분 시한 안내 + `--resume` 가이드 섹션 추가.
- **P1 — Confusion Protocol (28.5 흡수)**: `src/.claude/rules/base/decision-protocol.md` 신규 (38줄, gstack 4 시나리오 + STOP/2–3 options/Ask, scope 제한). `src/context/working-rules.md` Communication 섹션에 cross-ref. cascade 발생률을 줄이는 회귀 픽스(P0)와 짝지어, 발생 시 의사결정 처방을 일관화. 평가 근거: `outputs/proposals/gstack-fitness-evaluation-2026-04-26.md`.
- **검증**: `bash -n`, `shellcheck -S warning`, regression smoke (Task / Slice 양쪽), `--phase plan` dry-run, `bash scripts/build-template.sh` 모두 통과.
- **빌드**: `../claude-code-harness-template/` 에 propagated (forge `7017f08` stamp — commit 후 재빌드로 갱신 예정).
- **문서**: `src/docs/updates/round-3-fixes.md` (임시 이름) + `src/docs/updates/INDEX.md` 행 추가. commit 후 hash 로 rename 예정 (관례: `8a8f0d5.md`, `24070b5.md` 와 동일 패턴).

### 남은
- **commit**: 사용자 의사 확인 후 진행. `pre-commit-updates-doc-check.sh` 가 src/ 변경 + updates/ staged 짝 강제 → 위 문서 staged 되면 통과.
- **doc rename + 재빌드**: commit hash 확정 후 `mv round-3-fixes.md <short-hash>.md`, INDEX.md 같은 hash 로 변경, `bash scripts/build-template.sh`, 별도 chore 커밋.
- **다운스트림 sync**: divebase / honbabseoul / kody 에 별도 세션에서 `bash scripts/upgrade-harness.sh --dry-run` 후 적용. honbab Epic 3 의 미완 Develop 결과물은 사용자가 별도로 commit/discard 결정.

## 다음 task 후보
1. **Round 4 — Plan 품질 강화 (보류)**: `templates/plan.md` 에 신규 3개 섹션 (Spec enumeration / Invariants / Implements vs spec) + `check-plan-schema.sh` + plan-fix 자가 검증 루프. 본 round 의 retry 진입 회귀가 풀린 후에야 효과 측정 의미.
2. **Round 2 prompt-level 게이트 자동화**: empirical-first / scope-leak detector / spec invariant 를 lint/script 로 이전.
3. **Epic mode stage commit cascade isolation**: 1개 slice 실패가 전체 epic abort 하지 않도록.
4. **harvest pipeline 단계 진단**: 본 round 진단 외.

## Open Issues
- forge-deploy hook 이 src/ 변경 없는 commit 에도 target repo 에 `.harness-version` timestamp-only commit 생성 (noise). 이전 round 부터 carry-over.
- 병렬 spawn 자식 silent 0 종료 root cause (honbabseoul `/tmp/honbabseoul-run/1-20260425-133941/task-slice-3/` 로그 보존). 이전 round 부터 carry-over.
- multi-repo workspace 의 develop-noop guard 확장. 이전 round 부터 carry-over.

## 참조
- 본 세션 plan: `~/.claude/plans/async-wibbling-truffle.md`
- 입력 에러: `~/Downloads/honbab.rtf`, `~/Downloads/divebase.rtf` (사용자 첨부)
- 옛 누적 본문: `handoff/archive/session-2026-04-25.md`
- 직전 round update doc: `src/docs/updates/8a8f0d5.md`, `src/docs/updates/24070b5.md`
