# Operating Mode — Template

> 다운스트림 프로젝트가 자기 컨텍스트에 맞게 채택하는 운용 모드 reference.
> 사용법: 본 파일을 `docs/OPERATING-MODE.md` 로 복사 + `<project>` placeholder 와
> 박스 시간 / 금지 영역 / carry-over 상한 등을 프로젝트 사정에 맞게 조정.
> 출처: gstack ETHOS / kody-workspace 운용 진단 (forge round 5 흡수).

핵심 통증 패턴: **task 실행 → 새 에러 → 즉시 fix 시도 → 메타 ceremony 폭주 → 실무 진척 0**. 매일 반복되면 본 모드로 박스화한다.

---

## Two-Track 운용

| Track | When | What | Output |
|-------|------|------|--------|
| **IMPL** (실무) | 평일 매일 | `/task` 실행 — 본 개발 task | 코드, handoff |
| **META** (하네스/방식 개선) | 주 1회 정해진 박스 (권장: 2시간) | postmortem 결단, forge feedback, harness sync, carry-over zero-out | `outputs/postmortems/`, forge feedback, changelog |

**원칙**: IMPL track 안에서는 `scripts/`, `templates/`, `.claude/` 같은 하네스 영역을 **수정하지 않는다**. 발견된 결함은 work-around 로 우회하고 META 박스로 deferred.

---

## Error Budget — IMPL 안에서 에러를 만났을 때

1. **work-around 가능?** → 우회로 task 진행. handoff `## Meta Debt` 섹션에 1줄 기록.
2. **work-around 불가?** → task scope-out 또는 carry-over 로 미루기. handoff 에 기록.
3. **critical (실무 자체가 막힘)?** → IMPL 중단, 즉시 META 로 전환. **단 1시간 안에 fix 못 하면 work-around 로 후퇴**. 1시간 timer 가 ceremony 무한 루프를 방지.

**금지**: "이번에만 잠깐 hook/script 한 줄 고치고 돌아오자" — 매번 2~3시간이 된다.

---

## Carry-Over 정책

- **상한 5건**. 6번째 발생 시 그 주 META 박스에서 결단 강제.
- 결단 4종: `close` (해결됨) / `scope-out` (안 함, 이유 기록) / `escalate` (forge 또는 외부 시스템) / `keep` (다음 IMPL 1순위, 단 ≤1건만 keep 허용)
- `handoff/latest.md` 의 Carry Over 표에 `Decision` 칼럼 추가 (각 항목에 결단 기록).
- 매 META 박스 종료 시 carry-over count 를 changelog 에 1줄 기록.

---

## META 박스 절차 (2시간 안에)

1. **(10m)** handoff carry-over + `outputs/postmortems/*` 훑기
2. **(30m)** postmortem 1~3건 — 초안 생성 후 본문 채움
3. **(30m)** carry-over 결단 — 4종 중 하나 부착, handoff 갱신
4. **(30m)** forge feedback — 새 P0/P1/P2 항목 발견됐으면 `outputs/upstream/forge-feedback-*.md` 갱신
5. **(15m)** harness sync 검토 — `git log` 확인, 필요 시 `bash scripts/upgrade-harness.sh --apply`
6. **(5m)** changelog 1줄 append (자동 + 수기 보강)

박스 초과 시 다음 META 로 deferred. 이번에 다 못 끝낸 게 다음 주 우선순위.

---

## 메트릭 (changelog 에 매 박스 1줄)

META 박스 메트릭:
- wall-clock (목표: ≤ 120m)
- 처리한 carry-over 수
- 발견한 P0/P1 신규 건수
- 다음 IMPL day 시작 carry-over count (목표: ≤ 5)

IMPL day 메트릭:
- 메타에 쓴 분 / 실무에 쓴 분 (목표: 메타 ≤ 30m)
- 우회한 결함 수 (work-around 활성 신호)
- task 종료 시 Meta Debt 추가 항목 수

---

## 모드 break 신호

- META 박스가 2주 연속 2시간을 못 끝낸다 → 박스 확장 필요 또는 결함 polynomial 증가
- IMPL day 에 메타 작업 1시간 초과가 2주 연속 → Error Budget 1시간 timer 위반, 모드 재설계
- Carry-over 가 매주 6+ 건 발생 → 운용 컨텍스트 자체 변경 필요

위 신호 보이면 다음 META 박스에서 plan 재조정.

---

## 프로젝트별 채우기 (다운스트림 채택 시)

본 template 을 `docs/OPERATING-MODE.md` 로 복사한 뒤 다음 항목을 자기 컨텍스트로 갱신:

- META 박스 요일 / 시각 (예: "금 14:00–16:00")
- IMPL 작업의 task naming 시리즈 (예: K-series, T1/T2/T3)
- `/epics` 사용 정책 — 현재 자기 프로젝트에서 부활/유지/deprecate 중 어느 상태인가
- carry-over 상한 (5 가 default, 컨텍스트 다르면 조정)
- 1시간 timer 임계 (default 60m, 작업 톤에 따라 30~90m)

원본 reference: gstack(ETHOS) / kody-workspace `docs/OPERATING-MODE.md` (자체 진단 결과 도입).
