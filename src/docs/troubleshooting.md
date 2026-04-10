# Troubleshooting

하네스 실행 중 발생하는 대표 실패 5가지와 복구 절차. 진단은 `bash scripts/diagnose.sh`가 자동화한다.

## 빠른 진단
```bash
bash scripts/diagnose.sh
```
- exit 0: 이상 없음
- exit 1: 발견된 이슈를 stderr로 나열하고 복구 명령 제안
- 세부 검사 항목은 이 문서의 각 시나리오와 1:1 매칭

---

## 1. run-task.sh 중간 실패

**증상**: 3-Role 스크립트가 Plan → Develop → Review 중 멈추거나 배경 작업이 종료된 것처럼 보임.

**진단**:
```bash
f=/tmp/${PROJECT_NAME}-run/task-status
[ -f "$f" ] && cat "$f"
ls -lt /tmp/${PROJECT_NAME}-run/ 2>/dev/null | head -5
```
- `ROLE`, `ITER`, `VERDICT` 필드 확인
- 최근 수정 시각이 10분 이상 지난 로그는 stale

**복구**:
1. stale이면: 해당 phase부터 수동 재실행 (`run-task.sh --resume` 또는 역할만 반복)
2. `outputs/plans/task-N-plan.md`가 남아있으면 그대로 활용
3. 부분 수정이 남아 있으면 `git status`로 확인 후 결정

## 2. Reviewer가 REQUEST_CHANGES 반복

**증상**: `--max-iter`가 소진되었는데 Reviewer가 같은 지적을 반복. Developer가 매 iteration마다 동일 파일을 수정.

**진단**:
```bash
ls -lt outputs/reviews/ | head -5
grep -l 'REQUEST_CHANGES' outputs/reviews/task-*-review.md
```
- 동일 task ID에 review 파일이 2개 이상이면 loop 발생

**복구**:
1. 중단: Planner가 해당 task를 2~3개의 작은 slice로 재분할
2. 새 task ID로 다시 시작, `handoff/latest.md`에 loop 원인 메모
3. `gotchas.md`에 재발 방지 규칙 추가 고려

## 3. 병렬 slice 충돌

**증상**: parallel stage가 완료 후 일부 파일이 빈 커밋이거나 내용이 뒤섞여 있음. `git status`에 예상치 못한 파일이 존재.

**진단**:
```bash
git worktree list
git stash list
ls outputs/plans/ | grep epic-
```
- worktree 잔여가 있거나 stash가 비정상적으로 많으면 충돌 흔적

**복구**:
1. 잔여 worktree 정리: `git worktree list`로 확인 후 `git worktree remove <path>`
2. 고아 worktree: `git worktree prune`
3. stash 확인: 필요한 것 `git stash pop`, 불필요 `git stash drop`
4. Stage를 재분할해 재실행 (slice target_files가 실제로 겹치지 않는지 재검토)

## 4. Hook 실패

**증상**: 파일 저장이나 `git commit`이 차단됨. `[BLOCK]` 또는 `[WARN]` 메시지 출력.

**진단**:
```bash
ls .claude/hooks/
.claude/hooks/block-dangerous.sh "test" 2>&1 || true
bash -n .claude/hooks/post-edit-lint.sh
```
- 어느 훅이 차단했는지 stderr 확인

**복구**:
1. `block-dangerous.sh` false positive: `.claude/settings.json`의 `permissions.allow`에 구체 패턴 추가
2. `post-edit-lint.sh` 실패: 실제 lint 오류이므로 먼저 lint 수정
3. `post-edit-size-check.sh` 경고: `HARVEST_ALLOW_OVERSIZE=1`로 한시 우회하고 이후 파일 분할 계획 수립
4. 새로 추가한 훅이 예상 밖으로 동작: `chmod -x <hook>`로 임시 비활성화 후 원인 분석

## 5. Harvest 파이프라인 lock 잔존

**증상**: `/harvest` 또는 `/harvest validate` 실행 시 "already running" 메시지. 실제로 실행 중인 파이프라인은 없음.

**진단**:
```bash
cat harvest/.lock 2>/dev/null
ls -l harvest/.lock 2>/dev/null
ps -ef | grep -E 'run-harvest|harvest' | grep -v grep
```
- `.lock` 타임스탬프가 최근 아니고 프로세스도 없으면 stale

**복구**:
1. 실행 중 프로세스 없음 확인 후: `rm harvest/.lock`
2. 재실행
3. 재발 시 `scripts/run-harvest.sh` abnormal exit 경로에 lock 삭제 누락 여부 확인

---

## 공통 원칙
- 복구 전에 항상 `git status`로 현재 상태 확인
- 파괴적 명령(`git reset --hard`, `rm -rf`)은 `.claude/settings.json` deny로 차단 — 대신 `git checkout -- .`, `git stash` 사용
- 동일 실패가 3회 반복되면 중단하고 `handoff/latest.md`에 원인·증거 기록 후 사람 판단
