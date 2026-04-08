# Verification Plan

## Task
[Task N] — [Task name]

## Completion Criteria
Coordinates so both model and human see the same finish line.
- [ ] [Functional completion criterion 1]
- [ ] [Functional completion criterion 2]

## Automated Checks
Run in order. Stop on first failure.
1. Lint/Analyze: `{{LINT_CMD}}`
2. Type check: `{{TYPECHECK_CMD}}` <!-- optional: remove if project has no type checker -->
3. Targeted test: `{{TEST_SINGLE_CMD}}` (changed area only)
4. Full test: `{{TEST_CMD}}`
5. Build: `{{BUILD_CMD}}`

## Live Verification (UI/API tasks)
Reviewer verifies against a running app to catch runtime bugs invisible in static review.
1. Start dev server: `{{DEV_CMD}}`
   <!-- Multi-repo: start the repo's own server, e.g., backend {{BACKEND_DEV_CMD}}, frontend {{FRONTEND_DEV_CMD}} -->
2. Happy path:
   - [ ] [Normal scenario — e.g., "valid email/password signup → redirects to main"]
3. Edge cases:
   - [ ] [Edge 1 — e.g., "empty form submit shows error"]
   - [ ] [Edge 2 — e.g., "duplicate email shows conflict"]
4. API endpoints (if applicable):
   - [ ] [curl/Postman: valid request returns expected response]
   - [ ] [Invalid input returns proper error]

For pure logic/refactoring tasks, mark this section "N/A — pure logic change".

## Quality Criteria (design/creative tasks)
Even if functional, subpar quality → ITERATE verdict.
Skip this section for non-design tasks.

1-10 scale, weighted:
- Design Quality (×3): visual hierarchy, spacing, typography consistency
- Originality (×3): avoids generic/template patterns, unique character
- Craft (×2): detail polish, transitions, responsiveness
- Functionality (×2): correctness, edge case handling

Weighted sum below 70/100 → ITERATE (must specify improvement targets)

## Constraints
- Do NOT modify tests to make them pass
- Do NOT touch protected files: [list]
- Task is not complete until live verification passes

## Rollback Point
- Revert target: [specific files or git revert strategy]
- Safe to keep: [files that survive rollback]

## Report
After verification, record:
- What changed:
- What passed:
- What failed:
- What needs human confirmation:
- Confidence level: HIGH / MEDIUM / LOW
