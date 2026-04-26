# Decision Protocol — High-Stakes Ambiguity Guard

When the next action is ambiguous AND the cost of guessing wrong is high,
stop and surface the choice instead of picking silently.

## When to apply
1. Two plausible architectures or data models
2. A request that contradicts existing patterns or rules
3. A destructive / hard-to-reverse operation with unclear scope
   (e.g. `rm -rf`, `git reset --hard`, force-push, schema migration, mass rename)
4. Missing context that would change the approach significantly

## What to do
- STOP. Do not guess.
- Name the ambiguity in one sentence.
- Present 2–3 options with explicit tradeoffs (blast radius, reversibility, cost).
- Ask the user to choose. Wait for the answer.

## When NOT to apply
- Routine coding, obvious bug fixes, read-only investigation.
- Small additive changes inside the requested scope.
- Cases where the user already specified the approach.

## Harness-specific triggers
Common ambiguities in this codebase that belong to the protocol:
- Mid-pipeline crash recovery — typical options: `--resume`, full re-run,
  manual recovery commit. Pick one in a session, not on every retry.
- Stale config / drift detected during upgrade — auto-heal vs preserve
  vs abort.
- Plan deviation discovered mid-Develop — revise plan in same session
  vs finish slice and flag vs split into follow-up Task.

## Enforcement
Reviewer should REQUEST_CHANGES if a destructive or architecturally
significant action landed in a slice without a Decision Protocol entry
in the handoff or chat log.

Cross-reference: `context/working-rules.md` "Communication" section.
