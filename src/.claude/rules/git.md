# Git Rules

## Commits:
- Message format: `type: Task N — short summary` (feat, fix, refactor, test, docs, chore)
  - Example: `fix: Task 3 — add error handling`
  - Example: `refactor: Task 5 — extract inline logic`
- One commit per Task (logical unit)
- Never commit secrets, .env files, or build outputs
- Lint/analyze must pass before committing
- Only the Reviewer commits (after APPROVE)

## Multi-Repo:
- If no `.git/` in workspace root, commit+push individually in each sub-repo
- Commit message: `type: Task N [repo-name] — short summary`
- Push each repo independently
- Record commit hashes from all repos in handoff
- Do not run `git` commands from workspace root

## Branches:
- 모든 task 작업은 `task/{id}` 브랜치에서 실행 — `run-task.sh`가 자동 생성·체크아웃 (base는 `main`)
- Epic 실행은 `epic/{timestamp}` 브랜치에서 실행 — `run-epic.sh`가 자동 생성, parallel slice들은 epic 브랜치 상속
- **Protected branches**: `main`, `master`, `dev` — 모두 직접 커밋 금지 (`.claude/hooks/pre-commit-branch-check.sh`가 차단). task/epic 브랜치를 통해서만 변경이 들어옴
- **Workflow**:
  1. `run-task.sh`가 `task/{id}` 브랜치 생성 → Developer 작업 → Reviewer APPROVE
  2. APPROVE 시 `finalize_task_branch`가 task 브랜치를 **origin에 push만** 수행 (auto-merge X)
  3. 사용자 또는 Reviewer가 task 브랜치를 **수동으로 `dev`에 merge** (`git checkout dev && git merge --no-ff task/{id} && git push`) 또는 PR 생성 (`gh pr create --base dev --head task/{id}`)
  4. 누적된 dev는 별도 release 시점에 main으로 promote
- 긴급 우회: `HARVEST_ALLOW_MAIN=1` 환경변수 (인프라 정비 등 예외 상황 — main/master/dev 모두 적용)
- 멀티 레포 모드: 각 sub-repo에서 동일 규칙 적용 (scripts가 각 repo별로 branch 생성)

## Pull Requests (recommended):
- PR base는 `dev`, head는 `task/{id}`
- PR title은 commit message convention 따름
- 본문에 변경 내용 + 근거 명시
- 머지 전 self-review (diff 직접 확인)
- 자동 PR 생성은 의도적으로 안 함 — 사용자가 GitHub UI 또는 `gh pr create`로 직접 생성. push 시점에 finalize_task_branch가 명령 예시를 출력함
