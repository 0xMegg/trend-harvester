# Claude Code Harness Template v5

A reusable work environment template based on the Claude Code & Cowork Master Guide (583p).

v5 is a version that cross-analyzed every chapter of the guidebook and reinforced missing areas.
It adds external integration policy, token/context management, Skill precision design, Plugin deployment structure,
evaluation loop, and permission policy documentation, and resolves the integrated commit issue for parallel Stages.

## Getting Started with a New Project

### Prerequisites
- This template repo
- A project plan (any format OK, `docs/project-plan.md` template provided)
- Claude Code CLI (`claude`)

### Step 1: Create Project + Copy Harness

```bash
mkdir my-new-app && cd my-new-app
git init

# Copy the harness (pass the project name as an argument)
/path/to/claude-code-harness-template/setup.sh my-new-app
```

### Step 2: Add Your Project Plan

```bash
# Option A: Copy the template and fill it out manually
cp /path/to/claude-code-harness-template/docs/project-plan.md docs/project-plan.md

# Option B: If you already have a plan, just put it in docs/
cp ~/my-plan.pdf docs/
cp ~/my-plan.md docs/
```

### Step 3: Initialization Session (Claude fills in the harness settings)

```bash
claude "Read the project plan in docs/, refer to PlaceholderGuide.md,
and fill in all {{PLACEHOLDER}}s in the harness.
Targets: CLAUDE.md, context/about-me.md, context/access-policy.md,
context/mcp-policy.md, templates/role-*.md
Also modify .claude/rules/ and .claude/hooks/post-edit-check.sh
to fit this project."
```

> Once this session is complete, the harness will be fully configured for your project.

### Step 4: Start Development

#### Option A: Automated Execution (Recommended)

Run Plan, Develop, and Review sequentially in separate sessions with a single command:

```bash
# Single task
./scripts/run-task.sh "Task 1 — Fix empty submission bug in signup form"

# Epic (decomposition + auto-execution of each Slice)
./scripts/run-epic.sh "Epic 1 — Implement entire dive log entry screen"
```

- Sequential execution: Reviewer commits + pushes directly
- Parallel Stage: Each Slice runs with `--no-commit`, then an integrated commit is made after Stage completion (all Slices reflected in git)
- REQUEST_CHANGES: Stops at that Slice and outputs review feedback
- Logs: `/tmp/project-name-run/{plan,develop,review}.log`

#### Option B: Manual Execution (Fine-grained control)

Run each step manually in separate sessions:
```
/plan Task 1 — Fix empty submission bug in signup form
/develop Task 1 — Fix empty submission bug in signup form
/review Task 1 — Fix empty submission bug in signup form
```

**When REQUEST_CHANGES is returned:**
```
/develop Task 1 — Apply REQUEST_CHANGES fixes
/review Task 1 — Re-inspect
```

### Overall Flow

```
Write project plan + run setup.sh
  |
Initialization session: Read plan and complete harness setup
  |
Auto: ./scripts/run-epic.sh "Epic N — feature"  (Epic decomposition + integrated commit per Stage)
Manual: /plan -> /develop -> /review             (when fine-grained control is needed)
  |
Evaluation: Record 5 key metrics per Task using templates/evaluation.md
  |
(handoff/latest.md + decision-log.md auto-update to maintain state across sessions)
```

---

## Upgrading an Existing Project (harness already installed)

When the template repo has new changes and you want to pull them into an
existing project without clobbering project-owned files:

```bash
cd /path/to/existing-project
bash scripts/upgrade-harness.sh             # dry-run (default — nothing changes)
bash scripts/upgrade-harness.sh --apply     # perform the update
```

The tool consumes `.harness-manifest` from the template repo (pointed to
by `.claude/.harness-origin`) and classifies each template file:

- **managed**: harness owns it — overwritten with template version
- **seed**: seeded once — skipped if the project already has it (custom
  CLAUDE.md, .gitignore, per-project skill workflows, etc. are safe)
- **ignore**: project-local state — never touched

Override template path for one-off runs (e.g. broken `.harness-origin`):

```bash
TEMPLATE_REPO=/abs/path/to/template bash /abs/path/to/template/scripts/upgrade-harness.sh
```

Dry-run always runs first. Review the overwrite list; nothing changes
until `--apply`. One project at a time — never batch-upgrade.

---

## Applying to an Existing Project

```bash
cd /path/to/existing-project
/path/to/claude-code-harness-template/setup.sh my-existing-app

# In the initialization session, also request analysis of existing code
claude "Analyze the code in this project, refer to PlaceholderGuide.md,
and fill in all {{PLACEHOLDER}}s in the harness.
Targets: CLAUDE.md, context/about-me.md, context/access-policy.md,
context/mcp-policy.md, templates/role-*.md
Also modify .claude/rules/ and .claude/hooks/post-edit-check.sh
to fit this project.
Additionally, analyze the project's strengths, areas for improvement,
and issues that should be fixed immediately, and organize them as a
Task Queue in handoff/latest.md."
```

---

## Session Types Summary

| Session | When to Use | Command |
|---------|-------------|---------|
| **Initialization** | Once when starting a project | `"Read plan and fill in placeholders"` |
| **Epic Decomposition** | When starting a large feature | `/plan Epic N — [feature description]` |
| **Planner** | First for each Task/Slice | `/plan Task N — [description]` |
| **Developer** | Second for each Task | `/develop Task N — [description]` |
| **Reviewer** | Third for each Task | `/review Task N — [description]` |
| **General** | Simple questions/edits | Freely, without role assignment |

---

## Structure

```
project/
├── CLAUDE.md                              # Project contract (AI entry point, ~70 lines)
├── .claude/
│   ├── settings.json                      # Permission/safety settings
│   ├── hooks/
│   │   ├── block-dangerous.sh             # PreToolUse: Block dangerous commands
│   │   ├── post-edit-check.sh             # PostToolUse: BLOCK/WARN severity separation
│   │   ├── post-edit-lint.sh              # PostToolUse: Auto lint (project auto-detection)
│   │   └── post-edit-test.sh              # PostToolUse: Auto-run targeted tests for changed areas
│   ├── commands/
│   │   ├── plan.md                        # /plan: Enter Planner role
│   │   ├── develop.md                     # /develop: Enter Developer role
│   │   └── review.md                      # /review: Enter Reviewer role
│   └── rules/
│       ├── api.md                         # API/DB rules
│       ├── frontend.md                    # UI rules
│       ├── testing.md                     # Testing rules
│       ├── git.md                         # Commit/branch rules
│       └── gotchas.md                     # Project-specific pitfalls (separated from CLAUDE.md)
├── context/
│   ├── about-me.md                        # Project background
│   ├── working-rules.md                   # Working principles + 3-Role + token management + evaluation loop
│   ├── decision-log.md                    # Decision log (prevent re-discussion)
│   ├── access-policy.md                   # AI tool access policy (allowed/approval/blocked + 4-layer enforcement)
│   └── mcp-policy.md                      # MCP & external integration policy (evaluation checklist + allowlist)
├── templates/
│   ├── role-planner.md                    # Planner role
│   ├── role-developer.md                  # Developer role
│   ├── role-reviewer.md                   # Reviewer role
│   ├── epic-plan.md                       # Epic -> Slice decomposition format
│   ├── plan.md                            # Task plan format (per slice/task)
│   ├── verify.md                          # Verification plan (completion criteria + constraints + Confidence)
│   ├── evaluation.md                      # Task evaluation loop (5 key metrics)
│   ├── handoff.md                         # Session handoff format
│   └── bug-fix.md                         # Bug fix format
├── skills/
│   ├── SKILL-TEST-CHECKLIST.md            # Skill testing (trigger/negative/format/gotcha/boundary)
│   ├── bug-fix/
│   │   ├── SKILL.md                       # Bug fix workflow (with trigger/negative expressions)
│   │   └── examples/good-output.md        # Good bug fix example (replace per project)
│   └── code-review/
│       ├── SKILL.md                       # Code review workflow (with trigger/negative expressions)
│       └── examples/good-output.md        # Good review example (replace per project)
├── handoff/
│   └── latest.md                          # Current state (link between sessions)
├── outputs/
│   ├── plans/                             # Planner outputs
│   ├── reviews/                           # Reviewer outputs
│   └── archive/                           # Resolved past documents
├── scripts/
│   ├── run-task.sh                        # Single Task auto-execution (--no-commit support)
│   ├── run-epic.sh                        # Epic decomposition + Stage integrated commit
│   └── upgrade-harness.sh                 # Manifest-based template → project sync (dry-run default)
├── docs/
│   ├── project-plan.md                    # Project plan template
│   ├── plugin-guide.md                    # Plugin structure, security checklist, deployment strategy
│   └── epic-guide.md                      # Epic decomposition criteria, parallel execution, failure recovery
├── .harness-manifest                      # Per-file ownership policy (managed/seed/ignore)
├── PlaceholderGuide.md                    # For initialization session: placeholder filling guide
├── setup.sh                               # New project initialization script
└── README.md
```

### Document Role Separation

| Document | Purpose |
|----------|---------|
| `README.md` | Getting started guide, usage |
| `docs/project-plan.md` | Project plan template |
| `docs/plugin-guide.md` | Plugin promotion criteria, security, deployment strategy |
| `docs/epic-guide.md` | Epic decomposition principles, parallel Stage execution, v5 changes |
| `PlaceholderGuide.md` | Rules for filling placeholders in the initialization session |
| `context/access-policy.md` | Human-readable AI tool access policy |
| `context/mcp-policy.md` | MCP evaluation checklist, allowlist, connection principles |
| `templates/evaluation.md` | Record 5 key metrics after Task completion |
| `skills/SKILL-TEST-CHECKLIST.md` | Skill testing (trigger/negative + 5 types) |
| Everything else | Harness files automatically read and followed each session |

---

## File Connection Structure

```
CLAUDE.md (AI entry point)
  ├── context/about-me.md <- Project background
  ├── context/working-rules.md <- 3-Role + token management + evaluation loop
  ├── context/access-policy.md <- Allowed/approval/blocked policy (4-layer enforcement)
  ├── context/mcp-policy.md <- MCP evaluation + allowlist
  ├── handoff/latest.md <- Link between sessions
  │     ^ Planner writes -> Developer reads -> Reviewer writes
  ├── templates/role-*.md <- Behavioral rules for each role
  │     ├── role-planner.md -> outputs/plans/ (plan + verify)
  │     ├── role-developer.md -> handoff/latest.md (does not commit)
  │     └── role-reviewer.md -> outputs/reviews/ + git commit+push
  ├── templates/verify.md <- Completion criteria + constraints + Confidence level
  ├── templates/evaluation.md <- Record 5 key metrics per Task
  ├── docs/plugin-guide.md <- Skill->Plugin promotion, security
  ├── docs/epic-guide.md <- Epic decomposition criteria, parallel execution guide
  ├── skills/SKILL-TEST-CHECKLIST.md <- Skill quality verification
  ├── .claude/commands/ <- Slash commands (/plan, /develop, /review)
  ├── .claude/rules/ <- Auto-applied rules
  ├── .claude/hooks/ <- Automated safety checks
  └── .claude/settings.json <- Permissions + hook connections
```

### Parallel Epic Execution Flow

```
run-epic.sh "Epic N"
  |
/plan Epic N -> Generate epic plan (Stage & Slice structure)
  |
Stage 1 (parallel):
  Slice A: run-task.sh --no-commit -> Plan -> Develop -> Review (no git)
  Slice B: run-task.sh --no-commit -> Plan -> Develop -> Review (no git)
  -> commit_stage(): git add -A -> commit -> push (all Slices reflected together)
  |
Stage 2 (parallel):
  Slice C: run-task.sh --no-commit -> Plan -> Develop -> Review (no git)
  -> commit_stage(): Integrated commit
  |
EPIC COMPLETE
```

---

## Harness 6 Elements (Per Guidebook)

| # | Element | Implementation | Role |
|---|---------|---------------|------|
| 1 | **Permissions** | settings.json + access-policy.md | allow/deny/ask routing + human-readable policy |
| 2 | **Validation** | hooks/ (block-dangerous, check, lint, test) | Pre-block + post-verification |
| 3 | **Execution Mode** | commands/ + scripts/ | 3-Role separation + automated/parallel execution |
| 4 | **State Maintenance** | handoff/ + context/ | Link between sessions + background knowledge |
| 5 | **Decision Trace** | decision-log.md + evaluation.md | Decision rationale + quality tracking |
| 6 | **External Integration** | mcp-policy.md + plugin-guide.md | MCP policy + Plugin deployment |

---

## Guidebook Mapping

| File | Guidebook Reference |
|------|-------------------|
| `CLAUDE.md` | 3.7 (7-day setup), 5.3 (operational principles) |
| `settings.json` | 3.14 (security), 5.10 (harness elements) |
| `access-policy.md` | 5.10 (Permission minimum documentation), Ch.11 (governance) |
| `mcp-policy.md` | 5.10 (external integration), Ch.6 (MCP design) |
| `hooks/` | Ch.2 (Hook concepts), 5.10 (automated intervention), 5.6 (tool output budget) |
| `commands/` | 6.1 (Skill triggers), operational principles (reduce repetition cost) |
| `verify.md` | 5.11 (verification layers), 5.10 ("define how to verify before starting") |
| `evaluation.md` | 5.11 (evaluation loop 5 metrics) |
| `rules/` | 5.4 (Rules separation), 5.5 (context engineering) |
| `working-rules.md` | 5.5 (token economics), 5.7 (session management) |
| `context/` | 3.17 (starter bundle), 5.2 (workspace design) |
| `templates/` | 3.9 (template roles), 4.3 (practical prompts) |
| `role-*.md` | 4.5 (role separation), 5.8 (agent team patterns) |
| `skills/` | 6.1-6.3 (Skill anatomy, trigger design, testing) |
| `SKILL-TEST-CHECKLIST.md` | 6.3 (Skill testing checklist) |
| `plugin-guide.md` | 6.4-6.5 (Plugin structure, deployment strategy, security) |
| `epic-guide.md` | 5.8 (agent teams), 5.10 (parallel execution), 4.5 (role separation) |
| `handoff/` | 5.7 (Handoff > session compression) |
| `outputs/` | 5.2 (output management) |
| `scripts/` | 5.8 (agent team file conflict prevention), practical operations |

---

## Version History

### v4 -> v5

| Improvement | v4 | v5 |
|-------------|----|----|
| External integration | No MCP-related structure | **mcp-policy.md** -- MCP evaluation checklist, allowlist, connection principles |
| Permission policy | settings.json only (machine-readable) | **access-policy.md** -- Allowed/approval/blocked policy + 4-layer enforcement structure |
| Verification plan | Basic checklist | **verify.md enhanced** -- Completion criteria, modification-prohibited constraints, Confidence level |
| Token management | Compact Rules only | **Token & Context Management** -- 5 cost tiers, model separation, session separation |
| Skills | Single description | **trigger/negative expressions** -- Explicit activation/deactivation, enhanced Gotchas |
| Skill testing | None | **SKILL-TEST-CHECKLIST.md** -- 5 types: invocation/false-trigger/format/failure/boundary |
| Plugin | No structure | **plugin-guide.md** -- Promotion criteria, structure, security checklist, deployment strategy |
| Evaluation loop | None | **evaluation.md** -- 5 key metrics (success rate, revision count, time, tokens, failure type) |
| Parallel git | Individual commit per Slice (conflicts) | **Stage integrated commit** -- --no-commit + commit_stage() |
| Harness model | 5 elements | **6 elements** -- External Integration added |

### v3 -> v4

| Improvement | v3 | v4 |
|-------------|----|----|
| Post-edit check | All WARNING (exit 0) | **BLOCK/WARN severity separation** -- Secrets and forbidden patterns block with exit 2 |
| Post-edit test | None (manual execution) | **post-edit-test.sh** -- Auto-run targeted tests for changed areas |
| CLAUDE.md | ~90 lines (Gotchas, Templates, etc. included) | **Slimmed to ~50 lines** -- Gotchas separated to rules/gotchas.md |
| Gotchas | Included in CLAUDE.md body | **Separated to rules/gotchas.md** -- Promoted to auto-applied rule |
| Forbidden patterns | Hardcoded in hooks or absent | **BLOCKED_PATTERNS array** -- Configurable per project |

### v2 -> v3

| Improvement | v2 | v3 |
|-------------|----|----|
| Role entry | Type long prompt each time | **`/plan`, `/develop`, `/review` slash commands** |
| Verification plan | Acceptance Criteria within plan.md | **Independent `templates/verify.md` + Planner writes it** |
| Post-edit lint | Manual execution | **PostToolUse hook auto-execution (project auto-detection)** |
| Session management | Not mentioned | **continue/resume/fork/worktree instructions in working-rules.md** |
| /compact directive | None | **Compact Rules with pre-defined preservation items** |
| Gotchas | None | **Project-specific pitfalls section in CLAUDE.md** |
| Skill structure | SKILL.md only | **examples/ folder added (provides sense of good results)** |

### v1 -> v2

| Improvement | v1 | v2 |
|-------------|----|----|
| Workflow | Single session | **3-Role (Planner -> Developer -> Reviewer)** |
| Commit permission | Not specified | **Only Reviewer commits after APPROVE** |
| settings.json | Read/Write only allowed | **git, lint, test Bash auto-permitted** |
| Output management | Single outputs/ folder | **outputs/plans/, reviews/, archive/ separation** |
| Branch rules | Fixed "no direct push to main" | **Solo/collaboration distinction** |
| File connections | Only partial references | **Full structure references** |
| Initialization | Fill placeholders manually | **Auto-fill in initialization session** |
