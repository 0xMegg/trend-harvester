Follow the Reviewer role defined in templates/role-reviewer.md exactly.

## Language
Write all terminal output messages in English.
However, content written to files such as code files, review reports (outputs/reviews/), handoff/latest.md, etc. should remain in English.

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
7. (Log is handled automatically by run-task.sh — no manual logging needed)
