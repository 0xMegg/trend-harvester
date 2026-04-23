# Example: Trend Harvest Good Output

## Request
"/harvest"

## Result

```
═══════════════════════════════════
  HARVEST PIPELINE — 2026-04-08
═══════════════════════════════════

Phase 0: Guard ✓ (cooldown passed, lock acquired)

Phase 1: Collection
  web_fetch: 12 items from GitHub Trending
  web_search: 8 items from 3 queries
  internal_feedback: 2 items from evaluations
  Total: 22 collected, 15 new (7 duplicates filtered)

Phase 2: Analysis
  Scored: 15 items
  High (>=7): 3
  Medium (6): 4
  Below threshold: 8

Phase 3: Baseline
  Current harness score: 43/100

Phase 3.5: Autoresearch Judge
  Testing 7 proposals...
  ✓ "Add shellcheck pre-commit hook" — baseline 43 → 48 (+5) → KEEP
  ✓ "Add gotcha: Flutter pubspec version conflict" — baseline 43 → 44 (+1) → KEEP
  ✗ "Replace all rules with AI-generated rules" — baseline 43 → 38 (-5) → DISCARD
  ✓ "Add evaluation template auto-reminder" — baseline 43 → 43 (0) → KEEP
  ... (4 more tested)

Phase 4: Apply
  Auto-applied: 2
    .claude/rules/local/gotchas-<project>.md → "Flutter pubspec version conflict" pitfall added (project-specific)
    .claude/rules/base/testing.md → "shellcheck for bash scripts" rule added (harness-wide, requires template PR)
  Pending approval: 1
    .claude/hooks/pre-commit-shellcheck.sh → hook change (requires approval)
  Rejected: 4

Phase 5: Report
  Report: harvest/reports/2026-04-08-124530.md
  Harness: 43 → 45 (+2)
  Lock released ✓

═══════════════════════════════════
  HARVEST COMPLETE — 2 applied, 1 pending
═══════════════════════════════════
```
