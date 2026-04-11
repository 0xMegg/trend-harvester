# Harvest Policy

Policy for applying trends collected by the harvest pipeline to the project.

## Auto-Apply (No Human Approval Required)
Automatically applied when **all** of the following conditions are met:
- change_type: `rule` or `scaffold-rule`
- fitness score >= 7
- risk = low
- harness-report score does not decrease (Gate 2 passed)

Auto-apply targets:
- Adding Known Pitfalls to `.claude/rules/gotchas.md`
- Adding entries to existing rule files (api.md, frontend.md, testing.md, git.md)

## Requires Approval (Human Review Needed)
- change_type: `new-skill` (creating a new skill directory)
- change_type: `hook` (changes to .claude/hooks/ or settings.json)
- change_type: `config` (changes to CLAUDE.md or configuration files)
- risk: `medium`
- fitness score 6 (borderline)

Approval process:
1. Proposal saved to `harvest/applied/pending-*.json`
2. Pending items displayed in `/harvest status`
3. Applied after user runs `/harvest apply` or manually confirms

## Blocked (Never Auto-Applied)
- change_type: `delete` (deleting rules, skills, or hooks)
- risk: `high`
- Changes that cause harness-report score to decrease
- Changes that modify existing behavior (modifications/deletions, not additions)

## Source Trust Levels
| Source | Trust Level | Notes |
|------|--------|------|
| Internal feedback (evaluation.md) | High | Project's own learning |
| Manual input (/harvest validate) | High | User judgment |
| WebFetch (GitHub trending) | Medium | Popular but unverified |
| WebSearch | Medium | Variable search result quality |

## Human Review Gate
- **validate mode**: pauses after Phase 2 (fitness filter) for human review
  - Shows fitness score, proposal details, target file
  - User runs `/harvest judge` to continue to Phase 3-5
  - `--auto` flag skips the review (for future automation when criteria are established)
- **full mode**: no pause (external collection runs unattended through all phases)
- **Concreteness pre-filter**: proposals must specify target file, triggering condition, and exact action — abstract proposals are rejected before scoring

## Two-Stage Decision
- **Stage 1 (Claude)**: collection → concreteness gate → 5-axis scoring → Gate 2 measurement → draft application decision
- **Stage 2 (User + Claude)**: Claude presents the judgment summary → user reviews and finalizes approval / rejection / modification
- **All applications must pass Stage 2 before being executed** — including auto-apply candidates. The two-stage rule supersedes any "auto" classification above.

Why two stages: Stage 1 catches mechanical violations (fitness < 6, HARD-BLOCK categories, score regression). Stage 2 catches what scoring cannot see — whether the change actually fits this project right now. LLM scoring is a useful filter but not a sufficient decision-maker, so the human gate is mandatory rather than advisory. This rule originated from a sycophancy incident where score adjustments under user pressure invalidated the filter — see `feedback_scoring_integrity` memory.

## Rollback
- Phase 3.5 sandbox: `git stash` → temporary apply → measure → `git checkout -- .` → `git stash pop`
- Post-apply regression: create a `revert: harvest — [description]` commit
- `git reset --hard` is prohibited (settings.json deny list)
