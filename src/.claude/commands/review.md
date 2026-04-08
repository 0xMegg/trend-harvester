Follow the Reviewer role defined in templates/role-reviewer.md exactly.

## Language
터미널에 출력하는 모든 메시지는 한국어로 작성해.
단, 코드 파일, review report (outputs/reviews/), handoff/latest.md 등 파일에 기록하는 내용은 영어 유지.

## Task
$ARGUMENTS

## Critical Rule
You MUST review exactly the task specified above. Do NOT substitute, reorder, or skip to a different task. Find the matching Developer Handoff for this specific task.

## Workflow
1. Read handoff/latest.md → find the Developer Handoff section for this task
2. Inspect code changes using the checklist in templates/role-reviewer.md
3. Run lint/analyze and tests
4. Write review in outputs/reviews/task-N-review.md
5. Update handoff/latest.md with Reviewer Handoff section
6. Commit (LAST step — after all files are written):
   - APPROVE → stage all changed files (code + review + handoff) → commit + push
   - REQUEST_CHANGES → do NOT commit, return to Developer
7. Log (APPROVE only): append one line to $HOME/.claude/logs/YYYY-MM-DD.md
   - Format: `- [HH:MM] **{project}** Task N — short summary`
   - Project name: extract from current working directory name
   - Create the file if it doesn't exist yet
