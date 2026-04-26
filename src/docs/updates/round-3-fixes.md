---
hash: <commit-hash-pending>
date: 2026-04-26
severity: P0
type: fix
breaking: false
---

# [P0] fix: forge round 3 — scope-leak grep regression + phase split + resume + regression gate + decision protocol

## Summary
honbabseoul Epic 3 와 divebase Task 52.1 의 마지막 두 에러를 보면 단계 폭증의 직접 원인은 Plan 품질이 아니라 **Review 진입 직전의 인프라 레벨 크래시 + 사용자 의사결정 cascade** 였다. 본 round 는 (1) honbab 의 `run-task.sh:828` scope-leak grep 회귀를 픽스하고, (2) divebase 의 Bash 도구 10분 시한을 우회할 phase 별 entrypoint 와 `--resume` 을 도입하며, (3) 매 round 가 새 회귀를 양산하지 않도록 build-template.sh 직전에 `check-harness-regression.sh` 를 fail-closed 게이트로 추가하고, (4) cascade 가 발생했을 때 사용자 의사결정 부담을 일관 처리할 Confusion Protocol (gstack `garrytan/gstack` 흡수) 을 도입한다. (1)~(3) 이 cascade 발생률을 줄이고, (4) 가 발생 시 처방.

## Commits
- `<hash-pending>` fix: forge round 3 — scope-leak grep regression + phase split + resume + regression gate

## Changes
- `src/scripts/run-task.sh` — `set -euo pipefail` + grep no-match 트랩 픽스 3곳: `_scope_task_num` 추출 (line 828, honbab Epic 3 직접 원인), `dry_run_write_artifacts` 의 task_num 추출 (동일 패턴), `log_task_entry` 의 START_EPOCH grep. Slice 패턴 (`Slice N(.M)`) 인식 추가 + `|| true` graceful fallback. 신규 `--phase plan|develop|review|all` 옵션 + `--resume` + 그에 맞춘 main flow 분기 (review-only / develop-only 가지 분리).
- `src/scripts/run-epic.sh` — verdict cross-check 의 grep no-match 트랩 픽스 (line 898 + 917). `Task N` / `Slice N(.M)` 통합 패턴.
- `src/scripts/run-plan.sh` (신규, [managed]) — `run-task.sh --phase plan` thin wrapper.
- `src/scripts/run-develop.sh` (신규, [managed]) — `run-task.sh --phase develop` thin wrapper.
- `src/scripts/run-review.sh` (신규, [managed]) — `run-task.sh --phase review` thin wrapper.
- `src/scripts/check-harness-regression.sh` (신규, [managed]) — `bash -n` + 선택적 `shellcheck` + dry-run smoke (Task/Slice 양쪽 패턴, 케이스별 격리된 임시 git repo) 회귀 가드.
- `scripts/build-template.sh` (forge-only) — src/ 검증 직후 `check-harness-regression.sh` 자동 호출. 실패 시 build 거부. `SKIP_REGRESSION_CHECK=1` 비상 우회.
- `src/templates/role-developer.md` — `Slice Sizing — Beat the 10-Minute Tool Timeout` 섹션 추가 + `--resume` 가이드.
- `src/.claude/rules/base/decision-protocol.md` (신규, [managed]) — high-stakes ambiguity 가드 (4 시나리오 + STOP / 2–3 options / Ask, scope 제한). gstack `garrytan/gstack` 의 Confusion Protocol 흡수 (5축 합계 30/50, low cost). `outputs/proposals/gstack-fitness-evaluation-2026-04-26.md` 의 28.5 후보.
- `src/context/working-rules.md` — Communication 섹션에 decision-protocol cross-reference 한 줄 추가.

## Manifest classification
- `src/scripts/run-task.sh`, `src/scripts/run-epic.sh`, `src/scripts/run-plan.sh`, `src/scripts/run-develop.sh`, `src/scripts/run-review.sh`, `src/scripts/check-harness-regression.sh`, `src/templates/role-developer.md`, `src/.claude/rules/base/decision-protocol.md`, `src/context/working-rules.md` → 모두 `[managed]` (자동 덮어써짐)
- `scripts/build-template.sh` → forge-only, 다운스트림 무관

## Why
- **honbabseoul Epic 3 silent crash** — `set -euo pipefail` 활성 환경에서 `grep -oE "[Tt]ask[[:space:]]+[0-9]+"` 가 매치 못 찾으면 exit 1 → command substitution 실패 → 스크립트 abort. Slice 호출 (`TASK="Slice 1: ..."`) 에서 매번 매치 실패 → Plan ✓ Develop ✓ 6 verify gate 전부 통과한 직후, scope-leak detector 가 PHASE 3/3 REVIEW 진입 전에 죽음. **Round 2 (`8a8f0d5`) 에서 추가한 scope-leak detector 가 만든 회귀.**
- **divebase Task 52.1 SIGTERM** — Claude Code Bash 도구의 600000ms (10분) 하드 타임아웃이 monolithic run-task.sh 를 SIGTERM. Plan ~4분 + Develop ~14분 = 18분 → Review launch 전 강제 종료. `run_in_background:true` 라도 도구 lifetime 상한은 동일.
- 두 에러 모두 사용자가 매번 patch/resume/manual 의사결정 → 의도된 3단계가 10+ 단계로 폭증.
- 본 round 까지 회귀 가드가 없어서 매 round 의 신규 게이트가 다음 round 의 버그가 되는 cascade (Round 2 의 4개 게이트 도입 → Round 3 의 honbab silent crash). `build-template.sh` 가 회귀 가드를 자동 호출하도록 묶어 같은 부류 회귀 사전 차단.
- **Confusion Protocol (28.5)**: cascade 가 발생했을 때 사용자가 매번 patch / resume / manual 3택을 명시 없이 떠안는 패턴이 단계 폭증의 후반부 원인. gstack 의 Confusion Protocol 4 시나리오 (architecture choice / pattern contradiction / destructive op with unclear scope / missing context) + STOP/2–3 options/Ask 패턴이 정확히 그 처방. 비용 낮고 (`base/*.md` 1개 신규 38줄 + working-rules cross-ref 1줄), routine 코딩에는 적용 안 한다는 scope 제한이 명시돼 over-trigger 위험 작음. 평가 보고서: `outputs/proposals/gstack-fitness-evaluation-2026-04-26.md` (5축 합계 30/50).

## Downstream impact
- 영향 받는 프로젝트 유형: **Epic 모드를 쓰는 모든 다운스트림** (honbabseoul, divebase, kody, …). Slice 이름이 "Slice N: ..." 형식이면 그동안 Review 진입이 silently 막히던 회귀가 풀림. 평소처럼 `bash scripts/upgrade-harness.sh --apply` 후 동작 확인.
- 적용 후 기대 동작 차이:
  - Epic Slice 호출이 PHASE 3/3 REVIEW 까지 정상 진입 (이전엔 develop-iter1 종료 직후 silent exit 1)
  - 긴 task 는 `bash scripts/run-plan.sh "$TASK"` → `bash scripts/run-develop.sh "$TASK"` → `bash scripts/run-review.sh "$TASK"` 분할 호출로 각각 10분 안에 종료
  - 크래시 시 `bash scripts/run-task.sh --resume "$TASK"` 로 status 파일의 마지막 ROLE 보고 다음 phase 부터 재개 (TASK 인자 비워도 STATUS_FILE 의 TASK_NAME 에서 복원)
- 로컬 커스텀 충돌 가능성:
  - `--phase` / `--resume` 인자는 신규 — 기존 `bash scripts/run-task.sh "$TASK"` 호출은 그대로 동작 (PHASE_MODE=all default).
  - run-task.sh 가 다운스트림에서 forked 된 경우엔 `--phase` 분기 + scope-leak grep 의 `[Ss]lice` 인식이 함께 들어가야 함. fork 안 했으면 무관.
  - `check-harness-regression.sh` 는 forge 측 build 시점에만 호출되므로 다운스트림 동작에 영향 없음.

## Verification
- `bash -n` on src/scripts/*.sh — pass
- `shellcheck -S warning` on modified + new scripts — clean
- `bash src/scripts/check-harness-regression.sh` (Task/Slice 양쪽 dry-run smoke, 케이스별 격리 임시 repo) — pass
- `bash src/scripts/run-task.sh --dry-run --phase plan "Task 1 — phase test"` — `PLAN PHASE COMPLETE — exit early` 정상 출력 + exit 0
- `bash scripts/build-template.sh` — 회귀 가드 자동 호출 통과 → rsync → version stamp 갱신 (forge `<hash-pending>`)

## Next round (보류)
- Plan 품질 강화 (Planner output schema + spec 1:1 enumeration + plan-fix 자가 검증) — `8a8f0d5.md` 의 Slice 4 spec drift 사례가 retry loop 안에서 발생하는데, 본 round 에서 retry 진입 자체가 막히던 회귀를 풀고 난 뒤에야 측정 의미가 생김.
- Round 2 의 prompt-level 게이트 4개 (empirical-first / scope-leak / verdict cross-check / spec invariant) 의 lint/script 자동화.
- Epic mode 의 stage commit fail-closed cascade isolation (1개 slice 실패가 전체 epic abort 하지 않도록).
- harvest pipeline 의 단계 구조 진단 (본 round 진단 외).
