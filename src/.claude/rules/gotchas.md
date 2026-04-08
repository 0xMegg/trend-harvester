# Project Gotchas

Project-specific pitfalls that cause repeated mistakes.
Add entries as you discover them — each bug fix or unexpected behavior is a candidate.

## Known Pitfalls
- Run existing tests before modifying code — if they already fail, fix or flag before starting your task
- When lint or tests fail, paste the full error output into your next fix attempt — never guess the cause from the test name alone
- Implement one function or feature at a time — verify it works before moving to the next. Large-scope changes produce jumbled, undebuggable output
- Reference real file paths and symbol names in task specs — never describe code by concept alone. Vague references produce hallucinated paths and wasted cycles
- If the same fix fails 3 times, stop — reassess the approach instead of retrying. Endless retry loops waste tokens and context
