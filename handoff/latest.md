# Handoff — 2026-04-25 (forge-feedback 5건 반영 진행)

## 현재 task
divebase forge-feedback (`outputs/reports/forge-feedback-2026-04-25.md`, divebase repo) 5건 forge 측 반영. 본 세션이 plan 작성 + Fix 1–5 구현 진행 중. plan: `~/.claude/plans/outputs-reports-forge-feedback-2026-04-wondrous-axolotl.md`.

- Fix 1 (HIGH): task.md inline `;` 명령 → `.claude/scripts/check-task-status.sh` wrapper 추출. settings.json + manifest [managed] 갱신. ✓
- Fix 2 (HIGH): setup.sh FILES_TO_REPLACE 확장 + upgrade-harness.sh post-copy `{{PROJECT_NAME}}` 치환 (managed .md/.sh). ✓
- Fix 3 (MEDIUM): manifest [deprecated] 섹션 + upgrade-harness.sh 삭제 분기 (옛 root rules 5개). ✓
- Fix 4 + 5 (LOW): templates/handoff.md 검증 체크리스트 + archive policy 통합. handoff/archive/ 디렉토리 신설. 옛 본문 → archive/session-2026-04-25.md. ✓
- 남은: docs/updates/ 노트, build-template.sh, commit (CLAUDE.md companion-doc 규칙 준수).

## 다음 task 후보
1. divebase 에 새 forge sync (이번 fix 들 반영) → task.md placeholder 치환 + monitoring prompt 폭주 회복 검증.
2. 다른 다운스트림 (honbabseoul, kody) 에 동일 sync — 옛 root rules 자동 정리 동작 확인.

## Open Issues
- forge-deploy hook 이 src/ 변경 없는 commit 에도 target repo 에 `.harness-version` timestamp-only commit 생성 (noise). 별도 검토.
- multi-repo workspace 의 develop-noop guard 확장.
- 병렬 spawn 자식 silent 0 종료 root cause (honbabseoul `/tmp/honbabseoul-run/1-20260425-133941/task-slice-3/` 로그 보존).

## 참조
- 옛 누적 본문: `handoff/archive/session-2026-04-25.md` (902줄, 본 세션 이전 마라톤 기록)
- 본 세션 plan: `~/.claude/plans/outputs-reports-forge-feedback-2026-04-wondrous-axolotl.md`
- 입력 피드백: `../../workouts/divebase/outputs/reports/forge-feedback-2026-04-25.md` (divebase repo 내)
