---
hash: <commit-hash-pending>
date: 2026-04-29
severity: P2
type: feat
breaking: false
---

# [P2] feat: forge round 5 — Operating Mode template 흡수 + meta-backlog 정착

## Summary
사용자 호소 "포지만 만지작거리고 실무 진행 안돼" 의 근본 처방으로 kody-workspace 의 OPERATING-MODE.md (gstack 평가의 A4 후보) 를 forge 측에 일반화 흡수. IMPL/META 트랙 박스화 + Error Budget + Carry-over 상한 5 패턴을 다운스트림이 채택 가능한 reference template 으로 제공. 동시에 `outputs/meta-backlog.md` 단일 backlog 위치를 정착해 round 4 후속 12건 + round 3 carry-over 를 영속 store 에 옮김.

## Commits
- `<hash-pending>` feat: forge round 5 — operating mode template + meta backlog

## Changes
- `src/docs/operating-mode-template.md` (신규, [managed]) — 90줄. kody OPERATING-MODE 의 일반화 버전. Two-Track 운용 / Error Budget / Carry-Over 정책 / META 박스 2시간 절차 / 메트릭 / 모드 break 신호 / 프로젝트별 채우기 가이드. kody-specific (K-series, /epics 부활 P0-1, 진단 보고서 경로) 모두 placeholder 또는 일반 표현으로 대체.
- `src/.harness-manifest` — [managed] docs 섹션에 `docs/operating-mode-template.md` 등록.
- `outputs/meta-backlog.md` (신규, forge-only) — Operating Mode 의 backlog 단일 위치. round 4 후속 (kody G1/G2/G3 + honbab #2~#5 + A1/A2/A3) + round 3 carry-over 4건 정리. 결단 4종 (open/close/scope-out/escalate/keep) + 메트릭 1줄 형식 명시.
- `handoff/latest.md` — Open Issues 섹션을 ## Meta Debt 로 정식 명칭화. meta-backlog.md 포인터.

## Manifest classification
- `src/docs/operating-mode-template.md` → [managed] (다운스트림 자동 sync 시 install)
- `outputs/meta-backlog.md` → forge-only (다운스트림 무관)
- `src/.harness-manifest`, `handoff/latest.md` → 기존 분류 유지

## Why
- 사용자가 본 forge 세션 막판에 호소: "포지만 계속 만지작거리고 실무 진행 안돼". round 3 → round 4 후속 cascade 가 정확히 그 패턴의 자기 증거. round 4 P0 close 후 backlog 12건 누적.
- 근본 처방 = IMPL 트랙 (다운스트림 실무) 와 META 트랙 (forge 개선) 을 시간 박스로 분리 + carry-over 상한 강제.
- kody-workspace 가 같은 통증으로 자기 docs/OPERATING-MODE.md 를 만들어 운영 중. 그 패턴을 일반화해서 모든 다운스트림이 채택할 수 있는 reference 로 제공.
- 본 round 까지 forge 의 backlog 가 5곳 분산 (handoff Open Issues / round-N update docs / outputs/proposals/ / outputs/reports/ / 사용자 conversation 메모리). meta-backlog.md 가 단일 진실 source.
- 본 round 의 다음 단계가 Operating Mode 첫 정식 운영 — 다음 META 박스에서 P1 6건 처리.

## Downstream impact
- 영향 받는 프로젝트 유형: 모든 다운스트림 (kody / honbab / divebase / 신규).
- 적용 후 동작 차이:
  - 다운스트림이 자동 sync 시 `docs/operating-mode-template.md` 를 받음. 채택 결정은 다운스트림 사용자 영역 — 본인 `docs/OPERATING-MODE.md` 로 복사 + placeholder 채우기 (META 박스 시각, task series 명, /epics 정책, carry-over 상한, timer 임계).
  - kody 는 이미 자기 OPERATING-MODE.md 를 가지고 있음 — template 와 본인 인스턴스 비교 후 차이만 흡수 (forge 일반화 버전이 더 추상화돼 있음).
  - honbab / divebase / 신규 프로젝트는 template 을 처음 받아 채택 가능.
- 로컬 충돌 가능성: template 은 [managed] 라 forge 가 갱신 시 다운스트림의 template 파일 본체는 자동 갱신. 단 다운스트림이 채택해서 만든 자기 `docs/OPERATING-MODE.md` 는 [seed] 영역도 아님 (template 과 별개 파일) — 사용자가 직접 관리.

## Verification
- `bash -n` on all `src/scripts/*.sh` — pass (회귀 가드 통과)
- `shellcheck -S warning` — clean
- `bash src/scripts/check-harness-regression.sh` — Task / Slice 양쪽 smoke pass
- `bash scripts/build-template.sh` — 회귀 가드 자동 호출 통과 → rsync → version stamp 갱신 (forge `<hash-pending>`)
- `wc -l src/docs/operating-mode-template.md` → 90 (docs/ 영역, size guard 무관)
- manifest 등록 확인: `grep operating-mode src/.harness-manifest` → [managed] docs 섹션 단일 매칭

## Next round (다음 META 박스 input — 첫 정식 운영)
`outputs/meta-backlog.md` 의 P1 6건 일괄 처리:
- P1-1 / P1-2 / P1-3 — kody G1/G2/G3 (forge gap fix 묶음)
- P1-4 — upgrade-harness self cp 안전성 (atomic temp+mv)
- P1-5 — round 4 P0 effectiveness 검증 (다운스트림 1회 sync 후)
- P1-6 — check-harness-regression 의 manifest coverage 검증 추가 (round 5 자기 진단 처방)

P2 5건 / P3 4건은 박스 잔여 시간 또는 별도 META 박스.
