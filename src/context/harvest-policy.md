# Harvest Policy

harvest pipeline이 수집한 트렌드를 프로젝트에 적용할 때의 정책.

## Auto-Apply (사람 승인 불필요)
다음 조건을 **모두** 충족하면 자동 적용:
- change_type: `rule` 또는 `scaffold-rule`
- fitness score >= 7
- risk = low
- harness-report 점수가 하락하지 않음 (Gate 2 통과)

자동 적용 대상:
- `.claude/rules/gotchas.md`에 Known Pitfall 추가
- 기존 rule 파일에 항목 추가 (api.md, frontend.md, testing.md, git.md)

## Requires Approval (사람 확인 필요)
- change_type: `new-skill` (새 스킬 디렉토리 생성)
- change_type: `hook` (.claude/hooks/ 또는 settings.json 변경)
- change_type: `config` (CLAUDE.md 또는 설정 파일 변경)
- risk: `medium`
- fitness score 6 (경계선)

승인 방식:
1. `harvest/applied/pending-*.json`에 제안 저장
2. `/harvest status`에서 pending 항목 표시
3. 사용자가 `/harvest apply` 또는 수동 확인 후 적용

## Blocked (절대 자동 적용 불가)
- change_type: `delete` (규칙, 스킬, 훅 삭제)
- risk: `high`
- harness-report 점수가 하락하는 변경
- 기존 동작을 변경하는 변경 (추가가 아닌 수정/삭제)

## Source Trust Levels
| 소스 | 신뢰도 | 비고 |
|------|--------|------|
| 내부 피드백 (evaluation.md) | 높음 | 프로젝트 자체 학습 |
| 수동 입력 (/harvest add) | 높음 | 사용자 판단 |
| WebFetch (GitHub trending) | 중간 | 인기 있지만 무검증 |
| WebSearch | 중간 | 검색 결과 품질 가변적 |

## Rollback
- Phase 3.5 sandbox: `git stash` → 임시 적용 → 측정 → `git checkout -- .` → `git stash pop`
- 적용 후 회귀: `revert: harvest — [description]` 커밋 생성
- `git reset --hard` 사용 금지 (settings.json deny list)
