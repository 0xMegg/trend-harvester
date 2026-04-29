# Handoff — 2026-04-29 (round 5 — A4 OPERATING-MODE 흡수 + meta-backlog 정착)

## 현재 task
사용자 호소 ("포지만 만지작거리고 실무 진행 안돼") 의 근본 처방 = IMPL/META 트랙 박스화 (kody A4 reference). 본 round 5 는 그 reference 를 forge 측에 흡수 + 다운스트림 채택 가능한 template 화 + backlog 단일 위치 정착.

### 완료
- **A4 흡수**: `src/docs/operating-mode-template.md` (90줄, kody OPERATING-MODE 의 일반화 버전). prefix kody-specific 제거. IMPL/META 분리 + Error Budget + Carry-over 상한 5 + META 박스 2시간 절차 + 메트릭 + 모드 break 신호 + 프로젝트별 채우기 가이드 보존.
- **manifest 등록**: `src/.harness-manifest [managed]` docs 섹션에 `docs/operating-mode-template.md` 추가. 다운스트림 자동 sync 시 install.
- **meta-backlog 정착**: `outputs/meta-backlog.md` 신규. Operating Mode 박스화의 backlog 단일 위치. round 4 후속 12건 + round 3 carry-over 정리. 다음 META 박스 우선순위 명시 (P1 6건). Closed 섹션 (C1/C2/C3 = round 4 P0 + round 5).
- **handoff Meta Debt**: 본 섹션 (이전 Open Issues 의 정식 명칭화). 영속 backlog 는 meta-backlog.md.

### 남은
- `src/docs/updates/round-5-operating-mode.md` 임시 update doc + INDEX row
- `bash scripts/build-template.sh` 통과 확인
- round 5 commit (A4 흡수 + manifest + backlog + handoff + update doc)
- commit hash 확정 후 doc rename + chore commit
- 사용자 push (post-push-deploy hook 자동 발동)

## 직전 round 4 (참조)
- `cee3b30` round 4 P0 — upgrade-harness scoped substitution + 4 wrapper manifest 등록
- `4e0ec80` doc rename to cee3b30
- `321ea2c` chore: 2026-04-29 forge session reports
- 모두 origin push 완료 + template repo 자동 propagated (4b02b4e, FORGE_COMMIT=321ea2c)

## 다음 task 후보
1. **IMPL 트랙 복귀**: honbabseoul Slice 1 review / divebase Task 52.1 review / kody 신규 task. 자동 sync 가 round 4 P0 fix + round 5 template 까지 흡수.
2. **다음 META 박스 (Operating Mode 첫 정식 운영)**: `outputs/meta-backlog.md` 의 P1 6건 (kody G1/G2/G3 + honbab #2/#3 + check-harness-regression manifest 검증) 우선 처리. 2시간 박스 절차 (10m+30m+30m+30m+15m+5m) 따라.
3. **A1/A2/A3 흡수 평가**: 다음 META 박스 또는 그 다음. 5축 score + gstack 패턴 동일.

## Meta Debt
영속 backlog: `outputs/meta-backlog.md` (open 13건, P1 6건 / P2 5건 / P3 4건 + closed 3건).
- carry-over 상한 5 초과 (13). 다음 META 박스에서 결단 강제 — close / scope-out / escalate / keep.
- P1 6건 묶음 처리 시 한 round 안에 정리 가능. P1-3 (declare -A) 만 별도 분기 가능 (`/epics` 부활 정책과 묶임).
- P3 4건은 메트릭 / 진단 신호 (carry-over 추적, 미해결 root cause).

## 참조
- 본 round 보고서: `outputs/reports/session-report-2026-04-29.md`, `outputs/reports/p0-sync-fix-result-2026-04-29.md`
- 직전 update doc: `src/docs/updates/cee3b30.md` (round 4 P0), `src/docs/updates/e2ee114.md` (round 3)
- 본 round 산출: `src/docs/operating-mode-template.md`, `outputs/meta-backlog.md`, `src/docs/updates/round-5-operating-mode.md` (commit 후 hash rename)
- 다운스트림 sync 프롬프트 (이전 세션 작성): conversation 안 honbab / divebase 용
