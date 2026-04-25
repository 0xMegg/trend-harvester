# Session Handoff

> Archive policy (all roles): before overwriting, move the prior body to
> `handoff/archive/session-YYYY-MM-DD.md` (or append a dated section if a
> file for today already exists). Then write the new state below.
> Hard cap: 50 lines. Sections are: current task + next 2 tasks + Open Issues.
>
> Merge conflict: prefer HEAD (the new latest); move the displaced side
> into `handoff/archive/` instead of merging both into latest.md. Compose
> a fresh latest only if HEAD is unintentionally empty.
>
> Verification rule: if you state "X code is present in forge" or any
> claim about another repo's state, paste the exact `grep` command and
> its result alongside the claim — drift between handoff and code is
> what made the divebase 2026-04-25 sync misjudge Phase 2 auto-apply.

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
