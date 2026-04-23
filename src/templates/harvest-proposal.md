# Harvest Proposal

## Source
- Origin: [web_fetch / web_search / manual / internal_feedback]
- URL: [source URL or "N/A"]
- Discovered: [YYYY-MM-DD HH:MM]

## Concreteness Check
- Target file: [exact path. Project-specific pitfalls → `.claude/rules/local/gotchas-<project>.md`. Cross-project harness-wide rule → `.claude/rules/base/gotchas.md` (requires template repo PR).]
- Trigger: [specific condition, e.g., "3+ identical errors in output"]
- Action: [exact behavior, e.g., "exit 1 in pre-commit hook"]
- Pass/Fail: [pass / fail:abstract-proposal]

## Fitness Score
- **Total: [N]/10** (threshold: 6)
- Automation (0-2): [N] — [rationale]
- Friction (0-2): [N] — [rationale]
- HARD conversion (0-2): [N] — [rationale]
- Token efficiency (0-2): [N] — [rationale]
- Measurability (0-2): [N] — [rationale]

## Proposal
- Change type: [rule / scaffold-rule / new-skill / hook / config]
- Target file: [path]
- Risk: [low / medium / high]
- Description: [what this proposal does]

## Content
```
[actual content to be applied — rule text, skill YAML, hook script, etc.]
```

## Autoresearch Verdict
- Baseline score: [N]/100
- After-apply score: [N]/100
- Delta: [+/-N]
- Verdict: [keep / discard]
- Reason: [rationale for keeping or discarding]
