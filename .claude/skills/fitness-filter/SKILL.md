---
name: fitness-filter
description: |
  외부 트렌드 아이템을 5축 적합성 필터로 점수화한다.
  다음 요청에 활성화:
  "이 트렌드 평가해", "fitness score", "적합성 점수", "5축 분석",
  "이거 적용할만해?", "trend evaluate"
  다음에는 활성화하지 않음:
  "하네스 점수", "코드 리뷰", "버그 수정", "수집해"
version: 1.0.0
---

# Fitness Filter Skill

외부 트렌드/아이디어를 프로젝트 관점에서 5축 적합성 점수로 평가한다.

## Trigger
- "이 트렌드 평가해 [URL/설명]"
- "fitness score for [item]"
- harvest pipeline의 Phase 2에서 자동 호출

## Input
트렌드 아이템:
- title: 제목 또는 요약
- url: 출처 URL (선택)
- description: 상세 설명
- source_type: web_fetch / web_search / manual / internal_feedback

## 5-Axis Scoring

각 축 0~2점, 총 10점 만점. **임계값: 6점** (3축 이상 의미 있게 충족)

### 1. Automation (자동화) — 0~2
- 2: 수동 단계를 완전히 제거 (예: 매번 손으로 하던 검증을 hook으로 자동화)
- 1: 수동 단계를 부분적으로 줄임 (예: 반복 작업의 일부를 스크립트화)
- 0: 자동화 효과 없음

### 2. Friction (마찰 제거) — 0~2
- 2: gotchas.md의 기존 함정을 직접 방지 (예: 알려진 실수를 자동 차단)
- 1: 관련 있는 마찰을 줄이지만 직접 연결은 아님
- 0: 기존 마찰과 무관

### 3. HARD Conversion (강제 전환) — 0~2
- 2: bash exit code로 직접 강제 가능 (예: 훅에서 exit 1로 차단)
- 1: 부분적으로 자동 검증 가능 (예: 경고는 되지만 차단은 안 됨)
- 0: 순수 주관적 판단, 자동화 불가

### 4. Token Efficiency (토큰 효율) — 0~2
- 2: 측정 가능한 토큰 절감 (예: 프롬프트 단축, 불필요한 컨텍스트 제거)
- 1: 간접적 개선 (예: 더 명확한 규칙으로 재시도 감소)
- 0: 토큰 영향 없음

### 5. Measurability (측정가능성) — 0~2
- 2: 단일 지표로 직접 추적 가능 (예: 테스트 수, 린트 경고 수, evaluation 점수)
- 1: 간접 지표로 추적 (예: 세션 길이, 재작업 빈도)
- 0: 명확한 측정 지표 없음

## Context Required
점수 산출 시 반드시 읽어야 하는 파일:
1. `.claude/rules/gotchas.md` — 기존 함정 (Friction 축 평가용)
2. `CLAUDE.md` — 프로젝트 아키텍처 (적용 가능성 판단)
3. `harvest/config.json` — 축별 가중치
4. `context/harvest-policy.md` — 자동 적용 가능 여부

## Output Format
`templates/harvest-proposal.md` 형식으로 출력.

## Decision
- score >= 7 + risk low → auto-apply 후보
- score >= 6 → Phase 3.5 (autoresearch judge) 진행
- score < 6 → harvest/rejected/에 기록 + 사유

## Gotchas
- 프로젝트 컨텍스트 없이 일반론으로 점수를 매기지 말 것
- "좋아 보이는" 것과 "이 프로젝트에 필요한" 것은 다름
- HARD conversion이 0이면 규칙으로 강제할 수 없으므로 실효성 낮음
- 이미 gotchas.md에 유사한 항목이 있으면 Friction 2점이 아닌 중복 처리
