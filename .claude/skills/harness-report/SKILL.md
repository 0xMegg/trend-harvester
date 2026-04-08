---
name: harness-report
description: |
  하네스 품질 점수를 측정하고 보고한다.
  다음 요청에 활성화:
  "하네스 점수", "harness report", "하네스 상태", "품질 측정", "baseline 확인",
  "score check", "하네스 리포트"
  다음에는 활성화하지 않음:
  "트렌드 수집", "harvest", "코드 리뷰", "버그 수정"
version: 1.0.0
---

# Harness Report Skill

하네스의 현재 품질 점수를 측정한다.

## Trigger
- "하네스 점수 확인해", "harness report", "baseline 갱신", "품질 측정"

## Workflow

### 1. 측정 실행
```bash
bash scripts/harness-report.sh quick
```
또는 전체 측정:
```bash
bash scripts/harness-report.sh
```

### 2. 결과 해석
- **80+**: 건강한 하네스. 규칙/스킬/훅이 충실하고 평가 기록 있음
- **50-79**: 보통. 일부 영역 보강 필요
- **50 미만**: 초기 단계. 스킬, 평가 기록 등 보강 우선

### 3. 개선 제안
점수가 낮은 영역을 식별하고 구체적인 개선 액션을 제안:
- rules 낮음 → gotchas.md 보강, 프로젝트 특화 규칙 추가
- skills 낮음 → 반복 워크플로우를 스킬로 추출
- hooks 낮음 → post-edit 검증 추가
- evaluations 낮음 → 작업 후 evaluation.md 작성 습관화
- test_lint 낮음 → 린트/테스트 명령어 설정 확인

### 4. Baseline 갱신
측정 결과는 자동으로 `harvest/baseline.json`에 저장된다.

## Output Format
JSON 형식의 점수 + 영역별 breakdown.

## Gotchas
- quick 모드는 test/lint를 건너뛰므로 20점이 빠짐
- 템플릿 파일(src/)이 아닌 프로젝트 루트 기준으로 측정
- skills 디렉토리가 .claude/skills/에 있어야 인식됨
