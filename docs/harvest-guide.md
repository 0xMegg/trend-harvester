# Harvest Guide — Self-Improvement Pipeline

## 개요

harvest 모듈은 하네스의 7번째 요소로, 외부 트렌드를 수집하고 프로젝트에 적용하는 자기 개선 파이프라인이다.

**핵심 원리**: "외부 세계가 빠르게 변하므로 시스템도 진화해야 한다. 단, 맹목적이지 않게 — 프로젝트 철학 필터를 통과한 것만 유지한다."

## 7-Element Harness Model

| # | 요소 | 역할 |
|---|------|------|
| 1 | Permissions | settings.json + access-policy.md |
| 2 | Validation | hooks (block, check, lint, test) |
| 3 | Execution Mode | 3-Role workflow (plan/develop/review) |
| 4 | State Maintenance | handoff/ + context/ |
| 5 | Decision Trace | decision-log.md + evaluation.md |
| 6 | External Integration | mcp-policy.md + plugin-guide.md |
| 7 | **Self-Improvement Loop** | **harvest pipeline** |

## 파이프라인 흐름

```
Phase 0: Guard (lock + cooldown)
    ↓
Phase 1: Collect (WebFetch, WebSearch, manual, internal feedback)
    ↓
Phase 2: Analyze (5-axis fitness filter, threshold >= 6)
    ↓
Phase 3: Measure (harness-report baseline)
    ↓
Phase 3.5: Judge (temp apply → re-measure → keep/discard)
    ↓
Phase 4: Apply (auto or pending approval per harvest-policy.md)
    ↓
Phase 5: Report (harvest/reports/)
```

## 5축 Fitness Filter

각 축 0~2점, 총 10점 만점. 임계값 6점 (3축 이상 의미 있게 충족).

| 축 | 질문 | 2점 | 1점 | 0점 |
|----|------|-----|-----|-----|
| Automation | 수동 단계를 줄이는가? | 완전 제거 | 부분 축소 | 영향 없음 |
| Friction | 기존 함정을 방지하는가? | 직접 방지 | 간접 관련 | 무관 |
| HARD conversion | exit code로 강제 가능? | 직접 강제 | 경고만 | 불가 |
| Token efficiency | 토큰을 줄이는가? | 측정 가능한 절감 | 간접 개선 | 영향 없음 |
| Measurability | 단일 지표로 추적? | 직접 추적 | 간접 추적 | 불가 |

## Double-Gating

두 가지 관문을 모두 통과해야 적용:

1. **Gate 1 (SOFT)**: 5축 점수 >= 6 — "이 프로젝트에 적합한가?"
2. **Gate 2 (HARD)**: harness-report 실측 — "실제로 개선되는가?"

이 조합이 막는 두 가지 실패:
- Gate 1만: 그럴듯해 보이지만 실제로 해로운 변경
- Gate 2만: 해롭지 않지만 프로젝트와 무관한 변경

## 사용법

### 전체 파이프라인
```
/harvest
```

### 수동 입력
```
/harvest add "pre-commit에서 TODO 3개 이상이면 차단"
/harvest add https://github.com/trending/shell
```

### 현황 확인
```
/harvest status
```

### 부분 실행
```
/harvest scan      # 수집만
/harvest judge     # 측정+검증만
/harvest apply     # 대기 중인 제안 적용
```

## 자동 적용 정책 요약

| 조건 | 동작 |
|------|------|
| rule/scaffold-rule + score >= 7 + risk low + harness 유지 | 자동 적용 |
| new-skill, hook, config 변경 | 승인 필요 |
| 삭제, risk high, harness 하락 | 차단 |

상세: `context/harvest-policy.md`

## 프로젝트 적용 가이드

### 1. 활성화
`harvest/config.json`에서 `"enabled": true` 설정.

### 2. 소스 커스터마이즈
```json
"web_fetch": {
  "targets": [
    {"name": "GitHub Trending Swift", "url": "https://github.com/trending/swift"}
  ]
},
"web_search": {
  "queries": ["iOS development best practices 2026"]
}
```

### 3. 축 가중치 조정 (선택)
프로젝트 특성에 따라 가중치 변경:
- 웹 프로젝트: friction 가중치 ↑
- 모바일 앱: hard_conversion 가중치 ↑
- 자동화 프로젝트: automation 가중치 ↑

### 4. 출력 설정
```json
"output": {
  "provider": "obsidian",
  "obsidian": {
    "vault_path": "/path/to/vault",
    "folder": "harvest-reports"
  }
}
```

## 디렉토리 구조

```
harvest/
├── config.json       # 설정 (git-tracked)
├── baseline.json     # 현재 harness 점수 (git-tracked)
├── .seen.json        # 중복 제거 인덱스 (gitignored)
├── .lock             # 동시 실행 방지 (gitignored)
├── raw/              # 수집 원본 (gitignored)
├── analyzed/         # 분석 결과 (gitignored)
├── rejected/         # 탈락 제안 (gitignored)
├── applied/          # 적용 이력 (git-tracked)
└── reports/          # 실행 보고서 (git-tracked)
```
