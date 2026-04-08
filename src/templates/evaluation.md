# Task Evaluation

## Task
[Task N] — [Task name]

## 5 Metrics

### 1. Success Rate (성공률)
- 완료 기준 통과: YES / NO / PARTIAL
- REQUEST_CHANGES 횟수: [N]

### 2. Human Edit Count (사람 수정량)
- Reviewer가 직접 고친 곳: [N]개소
- 주요 수정 내용: [설명]

### 3. Time (시간)
- 요청 → 승인 가능 상태: [시간]
- Plan → Develop → Review 각 단계: [시간]

### 4. Token Cost (토큰/비용)
- 총 토큰: [N]
- 세션 수: [N]
- 도구 호출 횟수: [N]

### 5. Failure Type (실패 유형)
해당하는 항목에 체크:
- [ ] 근거 부족 (필요한 정보를 충분히 읽지 않음)
- [ ] 형식 오류 (출력 형식이 기대와 다름)
- [ ] 테스트 실패 (기능적 오류)
- [ ] 범위 초과 (계획에 없는 파일 수정)
- [ ] 검증 누락 (수동 확인 빠짐)
- [ ] 기타: [설명]

## Lessons Learned
- [이번 작업에서 배운 점 — gotchas.md나 rules에 반영할 것이 있으면 여기 기록]
