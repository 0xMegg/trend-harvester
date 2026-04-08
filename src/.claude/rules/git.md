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
- 워크스페이스 루트에 `.git/`이 없으면 각 하위 repo에서 개별 commit+push
- 커밋 메시지: `type: Task N [repo-name] — short summary`
- 각 repo 독립적으로 push
- 핸드오프에 모든 repo의 커밋 해시 기록
- 워크스페이스 루트에서 `git` 명령을 실행하지 말 것

## Branches:
- Solo development: work directly on main — commit + push allowed
- Team collaboration: feature branch (`feat/short-description`) → PR → merge
- For large changes, use a branch even in solo mode

## Pull Requests (team mode):
- PR title follows commit message convention
- Include what changed and why in the description
- Self-review the diff before requesting review
