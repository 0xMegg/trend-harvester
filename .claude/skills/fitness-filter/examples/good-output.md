# Example: Fitness Filter Good Output

## 요청
"/harvest add 'pre-commit hook에서 TODO 주석이 3개 이상이면 커밋 차단'"

## 결과

### Fitness Score: 8/10

| 축 | 점수 | 근거 |
|----|------|------|
| Automation | 2 | 현재 post-edit-check.sh에서 TODO를 WARN으로만 처리. 이걸 pre-commit으로 올리면 커밋 전 자동 차단 |
| Friction | 2 | gotchas.md에 "TODO 쌓임" 관련 pitfall 없지만, evaluation에서 "TODO 방치" 패턴 2회 발견 |
| HARD conversion | 2 | `grep -c 'TODO' | [ $(cat) -gt 3 ] && exit 1` — bash exit code로 직접 강제 가능 |
| Token efficiency | 0 | 토큰 사용에 직접 영향 없음 |
| Measurability | 2 | `grep -rc 'TODO' src/` 로 TODO 수 추적 가능 |

### Proposal
- Change type: `hook`
- Target: `.claude/hooks/pre-commit-todo-check.sh`
- Risk: `low`
- Verdict: **승인 필요** (hook 변경은 auto-apply 대상 아님)
