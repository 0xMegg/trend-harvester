---
name: trend-harvest
description: |
  외부 트렌드 수집 → 분석 → 적용 파이프라인을 실행한다.
  다음 요청에 활성화:
  "트렌드 수확해", "harvest 돌려", "외부 신호 수집", "self-improve",
  "run harvest", "collect trends", "/harvest"
  다음에는 활성화하지 않음:
  "하네스 점수" (→ harness-report), "이거 평가해" (→ fitness-filter),
  "버그 수정", "코드 리뷰", "기능 구현"
version: 1.0.0
---

# Trend Harvest Skill

외부 트렌드를 수집하고, 5축 필터로 평가하고, double-gating으로 검증하여 하네스에 적용하는 전체 파이프라인.

## Trigger
- "/harvest" — 전체 파이프라인
- "/harvest scan" — Phase 1만 (수집)
- "/harvest add <URL/설명>" — 수동 입력 → Phase 2~4
- "/harvest judge" — Phase 3~3.5만 (측정+검증)
- "/harvest apply" — Phase 4만 (대기 중인 제안 적용)
- "/harvest status" — 현황 보고

## 6-Phase Pipeline

### Phase 0: Execution Guard
1. `harvest/.lock` 확인 — 이미 실행 중이면 중단
2. `harvest/reports/` 최신 보고서의 timestamp 확인 — cooldown 미경과 시 중단
3. lock 생성 (정상/비정상 종료 시 반드시 제거)

### Phase 1: Collection
`harvest/config.json`의 enabled sources에서 수집:

**web_fetch**: 각 target URL에 대해 WebFetch MCP로 내용 수집
```
WebFetch(url, "Extract trending repositories, tools, or techniques related to developer tooling and AI coding")
```

**web_search**: 각 query에 대해 WebSearch MCP로 검색
```
WebSearch(query)
```

**manual**: `/harvest add <input>` 으로 사용자가 직접 등록

**internal_feedback**: `outputs/evaluations/*.md`에서 "Lessons Learned" 섹션 추출

수집 결과 → `harvest/raw/YYYY-MM-DD-HHMMSS.jsonl`에 저장
중복 체크: `harvest/.seen.json` 대조 (URL + title hash)

### Phase 2: Analysis
수집된 각 아이템에 대해 `fitness-filter` 스킬 호출:
1. 프로젝트 컨텍스트 로드 (CLAUDE.md, rules/, gotchas.md)
2. 5축 점수 산출
3. score >= 6 → `harvest/analyzed/`에 저장
4. score < 6 → `harvest/rejected/`에 저장 + 사유 기록

### Phase 3: Baseline Measurement
```bash
bash scripts/harness-report.sh quick
```
현재 점수를 `harvest/baseline.json`에 기록

### Phase 3.5: Autoresearch Judge (Double-Gating Gate 2)
score >= 6인 각 제안에 대해:
1. `git stash` (현재 작업 보존)
2. 제안을 임시 적용 (규칙 추가, 스킬 생성 등)
3. `bash scripts/harness-report.sh quick` 재실행
4. 비교:
   - new_score >= baseline_score → **keep** (통과)
   - new_score < baseline_score → **discard** (탈락)
5. `git checkout -- .` (임시 변경 제거)
6. `git stash pop` (작업 복원)
7. 결과를 proposal에 기록

### Phase 4: Apply Decision
`context/harvest-policy.md` 정책에 따라:

**Auto-apply** (조건 충족 시):
- 대상 파일에 변경 적용
- `chore: harvest — [description]` 커밋
- `harvest/applied/`에 기록

**Pending approval**:
- `harvest/applied/pending-*.json`에 저장
- 사용자에게 `/harvest status`로 확인 요청

### Phase 5: Report
1. `templates/harvest-report.md` 형식으로 보고서 생성
2. `harvest/reports/YYYY-MM-DD-HHMMSS.md`에 저장
3. `harvest/.seen.json` 업데이트
4. lock 해제
5. output provider에 따라 알림:
   - `log-only`: 보고서 파일만
   - `notion`: Notion DB에 기록
   - `obsidian`: vault에 마크다운 복사

## Context Required
파이프라인 실행 전 반드시 읽어야 하는 파일:
1. `harvest/config.json` — 소스, 임계값, 출력 설정
2. `context/harvest-policy.md` — 자동 적용 정책
3. `harvest/baseline.json` — 현재 baseline 점수
4. `harvest/.seen.json` — 중복 제거 인덱스
5. `.claude/rules/gotchas.md` — 기존 함정 (fitness-filter용)
6. `CLAUDE.md` — 프로젝트 아키텍처

## Gotchas
- Phase 3.5에서 `git reset --hard` 사용 금지 — `git checkout -- .` 사용
- lock 파일이 남아있으면 이전 실행이 비정상 종료된 것 → lock 삭제 후 재실행
- cooldown 내에 재실행 시도 시 사용자에게 알리고 중단
- auto-apply 후에도 harness-report가 하락하면 즉시 revert 커밋 생성
- 수집 소스 장애 시 해당 소스만 건너뛰고 나머지 계속 진행
- `.seen.json`이 없으면 빈 객체 `{}` 로 초기화
