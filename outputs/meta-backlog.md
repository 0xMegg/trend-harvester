# Forge Meta Backlog

> Operating Mode 박스화의 backlog 단일 위치. handoff `## Meta Debt` 의 영속 store.
> 채택 정책: `src/docs/operating-mode-template.md` 참조. 다음 META 박스 input.

- 최초 작성: 2026-04-29 (round 5 close-out 시점)
- carry-over 상한: 5 (Operating Mode default)
- **현재 open count: 13** — 상한 초과. 다음 META 박스에서 결단 강제.
- 결단 4종: `open` (대기) / `close` (해결) / `scope-out` (안 함, 이유 기록) / `escalate` / `keep` (≤1건만)

---

## P1 — Gap fix / regression (다음 META 박스 우선)

| ID | 출처 | 요약 | 결단 |
|----|------|------|------|
| P1-1 | kody G1 | `templates/epic-plan.md` Pre-Start Checklist 누락 (forge 36c4273 에서 role-planner.md 만 처리, epic-plan 빠짐) | open |
| P1-2 | kody G2 | `run-task.sh` 의 `setup_task_branch` origin remote preflight 누락 (run-epic 에는 있음). origin 비면 finalize push silent drop | open |
| P1-3 | kody G3 | `run-epic.sh:1122-1123` 의 `declare -A` 잔존 (bash 3.2 비호환, `/epics` parallel 분기 진입 시 즉시 깨짐) | open |
| P1-4 | honbab #2 | `upgrade-harness.sh` self-update line-offset shift — apply 도중 cp loop 가 자기 자신 덮어쓰며 line ~243 syntax error. cp pass 끝나지만 trailing [deprecated] removal pass silent skip. round 4 P0 의 allowlist fix 가 substitution 만 막고 self cp 자체는 그대로 | open |
| P1-5 | honbab #3 | `{{PROJECT_NAME}}` sed substitution 이 docs/updates/*.md 본문 literal 까지 치환했던 옛 회귀. round 4 P0 의 allowlist 로 일단 차단됨. **검증 필요** — 다음 sync 1회 통과 확인 후 close | open (검증 대기) |
| P1-6 | session-report 자기 진단 | `check-harness-regression.sh` 가 manifest coverage 검증 미포함 → round 4 P0 #2 (manifest 누락) 를 사전 차단 못함. build 시점에 `[managed] 선언 vs manifest 등록` 일치 검증 추가 | open |

## P2 — 효율 / 안정성 / 신규 자산 평가

| ID | 출처 | 요약 | 결단 |
|----|------|------|------|
| P2-1 | honbab #4 | macOS APFS staging 잔재 (`.!<PID>!*` 0-byte) 정리 — `upgrade-harness.sh --apply` 끝부분에 `find ... -name '.!*!*' -size 0 -type f -delete` 추가 | open |
| P2-2 | honbab #5 | `run-task.sh --help` case 절 누락 — PHASE 1 PLAN 으로 진입 (SIGPIPE 로 abort 되지만 안전성 ↓). wrapper 3개 (run-plan/develop/review.sh) 에도 동일 적용 | open |
| P2-3 | kody A1 | `scripts/preflight.sh` (10-check 매트릭스) 흡수 평가 — 5축 score 산정 + prefix `HARVEST_*` 일반화 | open |
| P2-4 | kody A2 | `scripts/new-postmortem.sh` + `templates/postmortem.md` 흡수 평가 — 메타 30→5분 효과, python3 의존 | open |
| P2-5 | kody A3 | `docs/harness-changelog.md` + `upgrade-harness.sh` auto-append wiring 흡수 평가 — 5곳 분산 → 1곳 통합 | open |

## P3 — 메모 / 선택

| ID | 출처 | 요약 | 결단 |
|----|------|------|------|
| P3-1 | divebase 메모 | macOS Bash sandbox 가 `cp` dest write 를 0-byte temp redirect (67개 zombie 발견 사례). Claude Code sandbox 동작이라 forge 영역 밖 — 단 forge 의 `cp` 패턴이 sandbox 와 어떻게 충돌하는지 인지 (P2-1 과 묶음 가능) | open |
| P3-2 | round 3 carry-over | forge-deploy hook 이 src/ 변경 없는 commit 에도 target repo 에 `.harness-version` timestamp-only commit 생성 (noise) | open |
| P3-3 | round 3 carry-over | 병렬 spawn 자식 silent 0 종료 root cause 미규명 — `/tmp/honbabseoul-run/1-20260425-133941/task-slice-3/` 로그 보존 | open |
| P3-4 | round 3 carry-over | multi-repo workspace 의 develop-noop guard 확장 (현재 단일 repo 만 정확히 동작) | open |

---

## Closed (round 5 시점 처리됨)

| ID | 출처 | 결단 | 메모 |
|----|------|------|------|
| C1 | divebase Issue 1 | close (round 4 P0) | upgrade-harness self-substitution → allowlist 로 self skip + sed escape 추가 |
| C2 | divebase Issue 3 / honbab #1 | close (round 4 P0) | round 3 신규 4 파일 manifest 미등록 → src/.harness-manifest [managed] 등록 |
| C3 | kody A4 | close (round 5) | OPERATING-MODE.md → `src/docs/operating-mode-template.md` 일반화 reference 흡수 + meta-backlog.md 정착 |

---

## 다음 META 박스 권고 입력

본 backlog 의 P1 6건이 다음 META 박스 (2시간) 의 우선순위:
- **P1-1, P1-2, P1-3 묶음** = forge 본체 gap fix (kody G1/G2/G3). 한 round 6 commit.
- **P1-4** = upgrade-harness self cp 안전성 (atomic temp+mv 패턴). 별도 round 또는 P1-1~3 묶음 안에 포함.
- **P1-5** = round 4 P0 effectiveness 검증 (다운스트림 1회 sync 후 docs/updates/** literal 보존 재확인). META 박스 검증 단계 (15m harness sync) 에 자연 통합.
- **P1-6** = check-harness-regression 의 manifest coverage 검증 추가. round 5 의 자기 진단 처방.

P2 5건은 박스 잔여 시간에 1~2건 평가 (5축 fitness, gstack 패턴).

P3 4건은 META 박스 메트릭 / 진단 신호로 활용 (carry-over 추적용).

---

## 메트릭 (META 박스 종료 시 1줄 append)

```
YYYY-MM-DD | wall-clock <Nm> | closed <N> | open-after <N> | new-found-P0/P1 <N>
```

- 첫 박스 (이번 round 5 close-out 자체): wall-clock 1세션 (2일치 누적, 박스 없이 진행됨), closed 3 (C1/C2/C3), open-after 13, new-found-P0/P1 0.
