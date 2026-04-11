# Proposal B Dry-Run — commit-time evaluation enforcement

**Date**: 2026-04-11
**Status**: ✋ **REJECT** (deferred from Run 20260411-040351)
**Decision basis**: 30-commit historical replay, 97% escape rate

## Proposal Summary

From `harvest/reports/20260411-040351.md`:

> Proposal B: **commit-time evaluation enforcement** (7/10, medium risk, REVIEW).
> Idea: a `pre-commit` hook that blocks any commit which does not also add or
> modify a file under `outputs/evaluations/`. Escape hatch: commit messages
> containing `[no-eval]` bypass the gate, so emergency / pure-meta commits
> remain possible.

The intent is to harden Principle 3 (Self-Improvement Loop) by making lessons-learned capture mechanically required rather than aspirational.

## Dry-Run Method

1. Walked the entire current `git log` (30 commits, from `fc1591e` to `95f4bc6`).
2. For each commit, checked whether it touched `outputs/evaluations/*` or `src/outputs/evaluations/*`.
3. Cross-classified each commit as **CODE** (touched `src/.claude/`, `src/scripts/`, `scripts/`, or `src/context/`) or **META** (only handoff/README/config/baseline/gitignore changes).
4. Computed the would-be escape rate.

The dry-run is hypothetical: the hook does not exist yet, so `[no-eval]` was never actually used. The question is **how many commits in real history would have needed the escape**.

## Raw Counts

| Category | With eval | Need escape | Total |
|---|---|---|---|
| **CODE** (real source change) | 1 | 19 | 20 |
| **META** (handoff/docs/config) | 0 | 10 | 10 |
| **All** | 1 | 29 | **30** |

- Overall escape rate: **96.7%** (29 / 30)
- CODE-only escape rate: **95.0%** (19 / 20)
- The single `WITH_EVAL` commit (`d8e9936 chore: harvest — 2차 E2E 테스트`) created the only file currently in `outputs/evaluations/` — and it was the *outcome* of an E2E test, not a side effect of a normal change.

## Per-Category Breakdown of CODE Commits (20)

| Sub-type | Count | Hook would have ... |
|---|---|---|
| `harvest` apply commits (item 1–5, deny `--no-verify`, 8영역 재설계, mcp-check 재시도) | 8 | blocked them — but the harvest report itself **is** the evaluation (`harvest/reports/*.md`) |
| Pure fix commits (`fix:` against scripts) | 4 | blocked them — eval would have repeated what the commit message already says |
| Feature additions (`feat:` audit-coherence, verify-parallel-worktree) | 2 | blocked them — these are tools whose own dogfood output is the evaluation |
| Refactor / large rewrite (run-task argparse, etc.) | 3 | blocked them — fits the hook's intent but only marginally |
| Trivial config fixes (settings.json deny entries, set -e fix) | 3 | blocked them — eval would be noise |

Of the 20 CODE commits, the number that *would have meaningfully benefitted* from a forced eval is roughly **3–5** (the refactors and the genuinely new features). The remaining 15–17 would have used `[no-eval]`.

## Analysis

**The escape becomes the default.** Once 95%+ of commits use `[no-eval]`, the tag stops being an escape hatch and becomes a habitual prefix. Mechanically the hook still runs, but it teaches the user to add `[no-eval]` reflexively, which destroys the signal value of the few commits that would have legitimately written an evaluation. The hook's only realized effect is friction, not learning.

**The current workflow already captures evaluation, just not at commit-level.** Three layers already exist:

1. `handoff/latest.md` — every session writes a "What Changed / Current State / What's Next" block. This is project-level lessons-learned, refreshed every session.
2. `harvest/applied/*.json` — every harvest application records `fitness`, `policy_verdict`, `applied_changes`, and `gate2_verdict`. This is item-level lessons-learned.
3. `harvest/reports/*.md` — every harvest run produces a report with `Discussion`, `Sycophancy incident`, `Postscript`. This is run-level lessons-learned.

The historical record is already **richer** than the proposed eval files would have been. Proposal B would create a fourth layer that duplicates the others without adding new signal.

**The one layer missing is task-level evaluation** for non-harvest work (regular fix/feat commits outside the harvest pipeline). But that should be a `/develop` or `/review` workflow rule, not a commit hook — eval is a *workflow output*, not a *commit invariant*.

**Counter-design — what the rejected proposal points to.** The legitimate kernel of Proposal B is that evaluations should be produced **somewhere** for non-harvest CODE changes. The right place is:

- After a `/develop` or `/review` task completes, generate `outputs/evaluations/{date}-{task-id}.md` from the task spec + diff + test outcome.
- Hook target = task script, not git pre-commit.
- Escape hatch unnecessary because the task script knows whether the work is "real".

This is closer to Item 2 from the previous batch (post-edit-size-check pattern) and fits the existing `run-task.sh` / `run-epic.sh` flow.

## Recommendation

**Reject Proposal B as designed** (commit-time enforcement with `[no-eval]` escape). 96.7% escape rate means the gate is theatre.

**Instead** — close the harvest todo for Proposal B with this report, and route the underlying intent into Item 1 (outputs/evaluations workflow specification) as a `/develop` or `/review` post-completion hook target. That conversation should decide:

1. Which task types must produce an evaluation (`fix` only? `feat` only? both?)
2. What template the evaluation file follows (existing `templates/evaluation.md` is the natural anchor)
3. Where the trigger lives (`run-task.sh` finalize step? `/review` skill?)

## Verification

Reproduce this analysis:

```bash
git log --pretty=format:'%h|%s' | while IFS='|' read -r sha subj; do
  files=$(git show --name-only --format= "$sha")
  has_code=0; has_eval=0
  echo "$files" | grep -qE '^(src/\.claude/|src/scripts/.+\.sh|scripts/.+\.sh|src/context/)' && has_code=1
  echo "$files" | grep -qE '(^|/)outputs/evaluations/' && has_eval=1
  cat=META; [ "$has_code" = "1" ] && cat=CODE
  estatus=NEED_ESCAPE; [ "$has_eval" = "1" ] && estatus=WITH_EVAL
  printf "%-4s %-12s %s  %s\n" "$cat" "$estatus" "$sha" "$subj"
done | awk '{c[$1"_"$2]++} END {for (k in c) print k, c[k]}'
```

Expected output (snapshot at `95f4bc6`):
```
META_NEED_ESCAPE 10
CODE_WITH_EVAL 1
CODE_NEED_ESCAPE 19
```
