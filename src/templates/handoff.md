# Session Handoff

> Overwrite model: each role overwrites with current state only.
> Planner archives previous handoff to `outputs/archive/` before overwrite. Developer/Reviewer overwrite without archiving.
> Keep under 50 lines.

## Current State
- Task: [Task N — name]
- Phase: [Plan / Develop / Review / Done]
- Date: [date]

## Last Action
- [1-3 lines: key result from the most recent role]
- Verdict: [APPROVE / REQUEST_CHANGES / ITERATE / N/A] <!-- Reviewer only -->
- Commit: [hash / "none"] <!-- Reviewer only -->

## Files Changed
- `[repo/file path]` — [reason]

## Verification Status
- Lint: PASS / FAIL
- Test: PASS / FAIL / N/A
- Live: PASS / FAIL / N/A / SKIPPED

## Issues Found <!-- Reviewer only -->
- Critical: [list or "none"]
- Important: [list or "none"]

## Next Step
- [1-2 lines: what the next role should do]

## Carry Over
- [Issues deferred to next Task, or "none"]

## Plan & Review Locations
- Plan: outputs/plans/task-N-plan.md
- Verify: outputs/plans/task-N-verify.md
- Review: outputs/reviews/task-N-review.md
