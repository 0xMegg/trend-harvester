# Example: Harness Report Good Output

## 요청
"하네스 점수 확인해"

## 결과
```
하네스 품질 점수: 67/100

영역별 현황:
- Rules:       13/20 (5 files, 내용 충실)
- Skills:      15/20 (3 skills, 2 with examples)
- Hooks:       15/15 (4 hooks, 모두 실행 가능) ✓ 만점
- Templates:   11/15 (11 templates, 4 filled)
- Evaluations:  4/10 (2 records)
- Test/Lint:    9/20 (lint pass, tests partial)

개선 우선순위:
1. Evaluations (+6): 작업 완료 후 evaluation.md 작성 2건 추가
2. Skills (+5): code-review 스킬에 examples/ 추가
3. Test/Lint (+11): 테스트 커버리지 확대

baseline 갱신 완료: harvest/baseline.json
```
