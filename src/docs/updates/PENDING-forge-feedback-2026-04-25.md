---
hash: PENDING
date: 2026-04-25
severity: P0
type: fix
breaking: false
---

# [P0] fix: divebase forge-feedback 5건 반영 — monitoring prompt 폭주, placeholder 치환 누락, 옛 root rules 정리

## Summary

divebase 다운스트림 sync 세션에서 발견된 하네스 측 결함 5건 일괄 반영. 핵심: (1) `/task` monitoring 명령이 메인 세션에서 60초마다 권한 prompt 를 띄우는 P0 회귀를 wrapper script 추출로 해결, (2) `{{PROJECT_NAME}}` placeholder 가 task.md 등 일부 [managed] 파일에서 다운스트림에 치환되지 않은 채 흘러가던 문제를 upgrade-harness.sh post-copy 단계에서 자동 치환으로 해결, (3) base/local rules split 도입 (5fdf9ff) 후 다운스트림에 잔존하던 옛 root `.claude/rules/*.md` 5개를 manifest `[deprecated]` 섹션 + 자동 삭제 로직으로 정리.

## Commits

- `<PENDING>` divebase forge-feedback 5건 반영 (Fix 1–5 묶음)

## Changes

- `src/.claude/scripts/check-task-status.sh` (신규) — `/task` monitoring wrapper. 인라인 `;` 명령을 단순 prefix 로 추출.
- `src/.claude/commands/task.md:19` — 인라인 명령을 `bash .claude/scripts/check-task-status.sh {{PROJECT_NAME}}` 호출로 치환.
- `src/.claude/settings.json` — allow list 에 `Bash(bash .claude/scripts/check-task-status.sh:*)` 추가.
- `src/.harness-manifest`:
  - `[managed]` 에 `.claude/scripts/**` 추가
  - `[deprecated]` 신규 섹션 + 옛 root rules 5개 (`.claude/rules/{api,frontend,git,gotchas,testing}.md`) 등록
- `src/setup.sh:158-186` — `FILES_TO_REPLACE` 에 `.claude/commands/task.md` 명시적 추가 + `{{PROJECT_NAME}}` 자동 발견 보조 루프 (`.claude/commands/`, `.claude/scripts/` 재귀 grep).
- `src/scripts/upgrade-harness.sh`:
  - `[deprecated]` parser 분기 + `DEPRECATED` 배열
  - `resolve_project_name()` (env → CLAUDE.md `Name:` → basename) + `PROJECT_NAME_RESOLVED`
  - managed 분기 post-copy 치환 (managed `*.md`/`*.sh` 에 `{{PROJECT_NAME}}` 매칭 시 sed)
  - `[deprecated]` 별도 처리 루프 + 삭제 로직 (--apply 시 `rm -f`, 미존재 silent skip)
  - 리포트에 `Deprecated — delete` / `Deprecated — already gone` 카운트 추가
- `src/templates/handoff.md` — archive policy 통합 재작성 (50줄 한도, 모든 역할 동일, archive 디렉토리 명시) + merge 충돌 해결 가이드 + forge HEAD 검증 체크리스트 (Phase 2 auto-apply 같은 가정 기재 시 grep 결과 인용 의무).
- `src/handoff/archive/.gitkeep` (신규) — 다운스트림 handoff archive 디렉토리.

## Manifest classification

- `.claude/scripts/check-task-status.sh`, `.claude/commands/task.md`, `.claude/settings.json`, `setup.sh`, `scripts/upgrade-harness.sh`, `templates/handoff.md`, `.harness-manifest`, `handoff/archive/.gitkeep` — 각각 manifest 정책대로 (managed/seed) 전파.

## Why

피드백 문서: divebase repo `outputs/reports/forge-feedback-2026-04-25.md` (forge HEAD `7f96dd4` 적용 중 발견된 결함 5건).

- Fix 1: 메인 세션에서 7시간 prompt 폭주 (Claude Code 권한 시스템이 `;` 노드를 처리 못 함). spawn_task sub-session 만 가정한 inline 디자인이 메인 세션 운영을 깼음.
- Fix 2: divebase 의 `task.md` 에 `{{PROJECT_NAME}}` 가 그대로 남음. setup.sh `FILES_TO_REPLACE` 누락 + upgrade-harness.sh 가 `[managed]` 파일을 raw 복사하기만 한 게 원인.
- Fix 3: base/local split (5fdf9ff) 도입 후 옛 root rules 가 어떤 manifest 섹션에도 없어 upgrade walk 가 못 보고 다운스트림에 고아 잔존.
- Fix 4 + 5: forge 핸드오프가 검증 없이 "Phase 2 auto-apply 보유" 가정을 흘림 + handoff archive policy 가 templates/handoff.md 에 부분만 명시되어 merge 충돌 시 정보 손실 위험. (Issue 4 의 명칭 모호도 정리 — `check_harness_version()` 자동 apply 와 `run-harvest.sh` Phase 4 의 LLM 프롬프트 텍스트 둘이 혼동되었음.)

## Downstream impact

- 모든 다운스트림 (divebase, honbabseoul, kody, …): 다음 sync 시 `/task` monitoring prompt 폭주 회복. task.md 의 `{{PROJECT_NAME}}` 자동 치환. base/local split 이후 옛 root rules 보유한 프로젝트는 5개 자동 삭제.
- 로컬 커스텀 충돌: `.claude/rules/{api,frontend,git,gotchas,testing}.md` 를 다운스트림이 의도적으로 유지하던 경우 (드물 것으로 추정) 는 삭제됨 — base/local 정책상 base/* 와 local/* 로 옮겨야 정상.
- `templates/handoff.md` 갱신은 새 핸드오프 작성 시점부터 적용 (기존 latest.md 는 변경 안 함; archive 정리는 다운스트림 자율).

## Verification

다운스트림 적용 후:

1. `bash scripts/upgrade-harness.sh` (dry-run) → "Deprecated — delete: 5" 출력 (옛 root rules 미정리 프로젝트 한정), `Managed — overwrite` 에 `.claude/commands/task.md` 포함.
2. `bash scripts/upgrade-harness.sh --apply` 후 `grep -r '{{PROJECT_NAME}}' .claude/` → match 0.
3. `ls .claude/scripts/check-task-status.sh` 존재 + 실행 권한.
4. 메인 Claude Code 세션 (default permission mode) 에서 `/task <N>` 실행 → 60초 후 monitoring prompt 1회 후 자동 (settings.json 매칭 확인).
5. `ls .claude/rules/` 에 base/, local/ 만 (옛 root .md 5개 부재).

## Related

- 피드백 원본: divebase repo `outputs/reports/forge-feedback-2026-04-25.md`
- 본 변경 plan: `~/.claude/plans/outputs-reports-forge-feedback-2026-04-wondrous-axolotl.md`
- 이전 base/local split: [5fdf9ff](./5fdf9ff.md)
- Phase 2 auto-apply 명칭 정리: [4d02f86](./4d02f86.md) 의 `check_harness_version()` 이 정확한 위치.
