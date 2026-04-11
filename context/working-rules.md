# Working Rules

## Work Principles
1. **Read before write** — understand existing code before changing it
2. **Feature-local first** — make changes inside the owning feature/module first; touch shared layers only when necessary
3. **Smallest change** — do only what completes the task, nothing more
4. **No scope creep** — if you notice unrelated cleanup or refactoring, log it as a separate task

## Session Protocol (3-Role Workflow)
Each session performs exactly one role. When given a role file (`templates/role-*.md`), follow only that role.

1. **Planner** (read-only): read handoff → analyze code → write `outputs/plans/task-N-plan.md` → update handoff
2. **Developer** (implement only): read handoff → follow plan → lint + test → update handoff (do NOT commit)
3. **Reviewer** (verify only): read handoff → inspect code → write `outputs/reviews/task-N-review.md` → commit + push on APPROVE → update handoff

If no role is specified (general session):
1. Start: read `handoff/latest.md` for current state
2. **Decide:** First determine whether the user's request is planning/discussion or execution
   - Planning/discussion: Epic decomposition, architecture decisions, direction discussion → **Do not modify code.** Operate in Planner mode
   - Execution: Explicit instructions like "implement", "create", "fix" → Operate in Developer mode
3. Execute: make changes, run lint/analyze (only for execution requests)
4. Verify: confirm tests pass
5. Handoff: update `handoff/latest.md`

## Default Mode Rule
In conversations without an explicit role, **planning mode (read-only)** is the default.
- Do not modify code or create files when discussing Epics, features, or architecture
- Only touch code when the user gives explicit execution instructions like "implement", "execute", "/develop"
- If ambiguous, ask "Should I just plan, or implement as well?"
- Planning artifacts (plan, epic-plan) may be saved to `outputs/plans/` — but not code files

## Session Management
- **Continue (`--continue`):** same task, same context — pick up where you left off
- **Resume (`--resume`):** browse past sessions and select one to continue
- **Fork (`--fork-session`):** branch off into a different direction from the current session
- **Worktree (`--worktree`):** parallel implementation on separate files — never edit the same file in two sessions
- When a session gets long, write a handoff and **start a new session** (context reset)
- After a direction change, prefer `--fork-session` over continuing in a polluted context

## Context Reset Rules
Reset (new session) is better than Compaction (summarization).
Compaction causes "context anxiety" — the model tends to rush to finish work prematurely.
- When the task boundary changes → write handoff → new session
- Within the same task, after 2+ hours → write handoff → new session
- When starting a new session: re-read handoff + plan + related files first
- `/compact` is a last resort, not a default strategy

## Communication
- If uncertain about scope, ask before implementing
- If 3+ different approaches fail, stop and discuss
- Flag security concerns immediately
- State assumptions explicitly

## Quality Gates (before declaring done)
- [ ] Lint/Analyze passes
- [ ] Related tests pass (if any)
- [ ] Changes are within the requested scope
- [ ] Handoff notes updated

## Token & Context Management

### Core Principle
Tokens are both a cost and an attention budget issue.
Focus over frugality — compose only what's needed.

### Context Composition (always vs on-demand)
| Always Resident | Open Only When Needed |
|----------------|----------------------|
| CLAUDE.md | Long reference docs, case studies |
| Short shared rules (rules/) | Detailed library references |
| Core commands, project structure | Outdated design docs |
| handoff/latest.md | outputs/archive/ |

### 5 Areas Where Token Cost Grows
1. Overly long CLAUDE.md and always-resident rule files
2. Vague prompts ("just figure it out")
3. Long session accumulation (break sessions at task boundaries)
4. Excessive tool output (full test logs, hundreds of search result lines)
5. Too many roles in a single session

### Model Usage Separation
- Strong model (Opus): design, paper comprehension, large structural decisions
- Balanced model (Sonnet): implementation, search, file inspection, simple fixes

### Session Separation Criteria
- Break sessions at task boundaries
- Default strategy: reset (new session) → handoff and plan must be solid (clean starting point)
- Opus 4.6 can maintain consistency in 2+ hour sessions — avoid unnecessary session splits
- When starting a new session: re-read handoff + plan + related files first

### MCP Resident Cost
- Tool descriptions and outputs consume context upfront
- Disable infrequently used MCPs
- For the same task, on-demand CLI calls can be lighter than heavy integrations

### CLAUDE.md Management
- Reflect repeated mistakes as rules
- Don't write out common sense that's already well-followed
- Rule files aren't longer-is-better manuals — they're short operational documents that reduce recurring failure points

## Evaluation Loop

Record an evaluation in the `templates/evaluation.md` format after each task that ships code. The loop has four anchors:

1. **Who writes it** — the **Reviewer** role. Same person who runs `commit + push` is the same person who writes the evaluation. Planner and Developer don't.
2. **When** — immediately after `APPROVE`, before the next task starts. `run-task.sh` auto-creates a stub at `outputs/evaluations/{date}-task-{N}-{slug}.md` so the Reviewer only fills in the qualitative fields.
3. **For which tasks** — only tasks with **CODE changes** (touching `src/.claude/`, `src/scripts/`, `scripts/`, or `src/context/`). META-only tasks (handoff, README, baseline, gitignore) are exempt — `handoff/latest.md` already covers them.
4. **What goes in it** — the 5 metrics (success rate, human edits, time, tokens, failure types) plus `Lessons Learned` and `What I would do differently`. Auto-filled metadata (files touched, diff size) is populated by the stub.

When recurring failure patterns appear across evaluations:
1. Add as a Known Pitfall in `.claude/rules/gotchas.md`
2. Add to the relevant Skill's Common Pitfalls
3. Add automatic detection via hooks if necessary

Continuously compare the 5 metrics across evaluations: success rate, human edit volume, time, tokens/cost, failure types.

**Why this is not a commit-time hook**: `outputs/proposals/proposal-b-eval-enforcement-dry-run.md` (2026-04-11) replayed 30 commits and found a 96.7% would-be `[no-eval]` escape rate. The escape becomes the default; the hook becomes theatre. Task-completion enforcement (run-task.sh) hits the actual decision boundary instead.

## Self-Improvement Loop (Harvest Module)
An extension of the evaluation loop. Collects external signals, scores them, applies them experimentally, and measures the results.

### Pipeline (6 Phases)
0. Execution guard (lockfile + cooldown)
1. Collect (WebFetch, WebSearch, manual input, internal feedback)
2. Analyze (5-axis fitness filter: automation, friction removal, HARD conversion, token efficiency, measurability)
3. Baseline measurement (harness-report.sh)
3.5 Double verification (temp apply → re-measure → keep/discard)
4. Apply decision (per harvest-policy.md: auto vs requires approval)
5. Report (harvest/reports/)

### Execution Methods
- Manual: `/harvest` command or `bash scripts/run-harvest.sh`
- Partial: `/harvest scan`, `/harvest add <URL>`, `/harvest judge`, `/harvest status`

### Core Principles
- **Double-Gating**: Both philosophy filter (SOFT) + real measurement (HARD) must pass before applying
- **Rollback guarantee**: Use `git stash`/`git checkout -- .` (`git reset --hard` is prohibited)
- **Incremental evolution**: Apply in small rule/skill units, not large changes at once
- **Measurement-based**: Automatically discard/revert if harness-report score drops
