---
hash: PENDING
date: 2026-04-25
severity: P0
type: fix
breaking: false
---

# [P0] fix: forge round 2 — empirical-first / scope-leak / verdict cross-check / spec invariant

## Summary
honbabseoul Epic 2 (2026-04-26) 회고에서 식별된 4개 결함을 의미·프로세스 층위에서 차단. round 1 (`bcb8cf9` — bash3 / develop-noop / install-before-import) 위에 쌓는다. 핵심 1건은 `commit_stage()` 의 review-file `FINAL_VERDICT` cross-check 로 stage commit 게이트를 review 의 진실의 원천에 묶는 것.

## Commits
- `<TIP>` fix: forge round 2 — 4 patches from honbabseoul Epic 2 retrospective

## Changes
- `src/templates/role-developer.md` — `Install Before Import` 직후 `Empirical-First Deviation` 섹션 추가. plan invariant (RLS / 보안 / defense-in-depth) 를 약화·제거할 때 Developer 가 사전에 경험적 재현 + 실제 출력 + 결론을 handoff 에 첨부하도록 강제. 추론만으로 정책 약화 금지.
- `src/scripts/run-task.sh` — Develop 직후 `log_success` 와 `# --- Review ---` 사이에 scope-leak detector (warn-only) 삽입. `DEVELOP_PRE_HEAD` 이후 변경된 파일을 `git diff` + `git status --porcelain` 로 모은 뒤 task plan 의 `## Scope` → `- Files to modify:` 와 비교, 차집합을 handoff 에 `## Unplanned changes` 섹션으로 append. plan 미존재·미해독 시 graceful skip. parser false positive 우려로 block 안 함.
- `src/scripts/run-epic.sh` — `commit_stage()` 진입 직후 verdict cross-check (fail-closed). stage 의 모든 slice 에 대해 `outputs/reviews/task-${num}-review.md` (3개 후보 경로) 를 grep, `<!-- FINAL_VERDICT: APPROVE -->` 마커 부재 또는 review file 부재 시 stage commit abort. 기존 `task-status` VERDICT 게이트와 별개의 defense-in-depth.
- `src/templates/role-planner.md` — `Pre-Start Checklist` 에 4번째 항목 `Spec invariant grep` 추가. spec 의 enumeration (예: "spec §5 — 6 fields") 을 plan `## Implements (vs spec)` 섹션에 그대로 옮기고 plan 출력과 1:1 매칭.

## Manifest classification
- `[managed]` `scripts/run-task.sh`
- `[managed]` `scripts/run-epic.sh`
- `[managed]` `templates/role-developer.md`
- `[managed]` `templates/role-planner.md`

## Why
honbabseoul Epic 2 (4 slices / 2 stages, against forge `7f96dd4`). Slice 1 (schema migration + RLS) 가 critical RC 였는데 runner 가 "all 4 APPROVED" 로 잘못 보고. cleanup 회고가 4개 root cause 식별:

1. **Empirical-first deviation 부재** — Developer 가 PostgreSQL RLS WITH CHECK 의미를 *추론만으로* 잘못 모델링하고 plan 의 `with check (status = 'pending')` 를 `(true)` 로 약화. Reviewer 가 ablation 테스트 (트리거 끄고 anon INSERT) 로 즉석 falsify 했지만, evidence 가 handoff 에 없었으면 그대로 ship 됐을 위험.
2. **Scope leak** — 8개 `scripts/db-*.sh` (debug/grants/trigger-test) + 2개 비계획 `db:verify`/`db:smoke` package 스크립트가 commit 에 섞임. plan 은 `db:push` / `db:reset` 만 승인. handoff 에 "may delete" 라고 적고서 실제로 `git rm` 안 함. Epic 1 `nextscaffold/` 408MB 누수와 같은 구조.
3. **Runner mis-report** — Slice 1 review 파일이 `<!-- FINAL_VERDICT: REQUEST_CHANGES -->` 인데 stage 통합 commit 이 통과. 사용자가 review 파일을 직접 읽어야만 RC 가 보였음.
4. **Spec drift** — Spec §5 의 6개 UGC 필드 중 `reason` 누락 → plan 의 16-column 목록도 누락 → Slice 4 의 submissions 레포가 `reason` 을 zod 로 받고 persist 안 함 (TODO). Reviewer verify 가 plan vs implementation 만 비교, plan vs spec 비교 단계 부재.

원본 회고: honbabseoul `docs/forge-feedback/2026-04-26-epic2-cleanup-lessons.md` (208줄).

## Downstream impact

### 영향 받는 환경
- **모든 다운스트림** — 4건 모두 OS 무관. Patch 3 (verdict cross-check) 은 epic mode 사용 다운스트림에 가장 영향. Patch 1·4 는 다음 Developer/Planner 세션 prompt 에 즉시 반영.

### 적용 후 동작 차이
- `/develop`: plan 외 파일 수정하면 handoff 에 `## Unplanned changes` 섹션 자동 append. 이후 Reviewer/Planner 가 keep/drop 결정 명시 가능. **block 안 함** — 자동 게이트는 verdict cross-check 가 담당.
- `/epic` 의 stage commit: 모든 slice review 파일에 `FINAL_VERDICT: APPROVE` 마커가 있어야 통과. 한 slice 라도 REQUEST_CHANGES / 마커 부재 / 파일 부재면 stage commit abort. "all approved" 로 보고됐지만 실제로는 RC 였던 round 2 시나리오 차단.
- Developer 세션이 plan 의 invariant (RLS / 보안 / defense-in-depth) 를 약화하려 할 때 prompt 에 명시된 "Empirical-First Deviation" 룰에 의해 재현 가능한 evidence 첨부 강제.
- Planner 세션이 spec 의 enumeration 을 plan 에 그대로 옮기고 1:1 매칭 명시.

### 의도적 미해결
- Patch 2 의 plan 파서는 task mode `plan.md` 의 `- Files to modify:` 한 가지 형식만 인식. epic-plan 의 `- **Files:**` 슬라이스별 항목은 미지원 (epic mode 에서는 graceful skip). 차후 epic-plan 파싱 추가는 별도 patch.
- Patch 2 는 warn-only. block 으로의 승격은 false positive 데이터 (parser 실패율) 누적 후 결정.
- Patch 3 의 review file 경로 후보 3개 (`task-${n}-review.md`, `task-slice-${n}-review.md`, `slice-${n}-review.md`) 를 순서대로 시도. 다운스트림이 다른 이름 컨벤션을 쓰면 cross-check 가 항상 `missing` → fail-closed → 모든 stage commit 차단. 이런 다운스트림은 본 update 적용 시 review 파일 경로를 정렬해야 함.
- Patch 4 의 "Spec invariant grep" 은 prompt-level 룰. Reviewer-side 자동 검증은 후속 round 에서.

## Verification
다운스트림에서:
```bash
# 1) 자동 적용 (다음 /task 또는 /epic 진입 시 check_harness_version 이 호출)
# 또는 수동:
bash scripts/upgrade-harness.sh --apply

# 2) Patch 1 — Developer 룰 확인
grep -n "^## Empirical-First Deviation" templates/role-developer.md
#    → 1건

# 3) Patch 2 — scope-leak detector 확인 (warn-only)
grep -n "Unplanned changes (auto-detected" scripts/run-task.sh
#    → 1건

# 4) Patch 3 — verdict cross-check (commit_stage 진입 직후)
grep -n "Verdict cross-check" scripts/run-epic.sh
#    → 1건. 또한 grep '<!-- FINAL_VERDICT: APPROVE -->' scripts/run-epic.sh 도 1건

# 5) Patch 4 — Planner Pre-Start 항목
grep -n "Spec invariant grep" templates/role-planner.md
#    → 1건

# 6) bash 3.2 호환 회귀 없음
/bin/bash -n scripts/run-task.sh && /bin/bash -n scripts/run-epic.sh
```

## Related
- 원본 피드백: honbabseoul `docs/forge-feedback/2026-04-26-epic2-cleanup-lessons.md`
- 직전 update (round 1): `docs/updates/bcb8cf9.md` (bash3 + develop-noop + install-before-import)
- round 1 회고: honbabseoul `docs/forge-feedback/2026-04-25-bash3-noop-install.md`
