---
name: code-review
description: >
  Code review workflow. Activate on requests like:
  "review this code", "is this safe to merge?", "is this code safe?",
  "check this PR", "review the changes", "review this code",
  "is this safe to merge", "check this PR"
  Do NOT activate on:
  "write code for me", "implement this", "build a new feature", "fix this bug"
version: 3.0.0
---

# Code Review Skill

## Objective
Review code changes and provide actionable feedback organized by severity.

## Inputs
- The diff or files to review
- Context about what the change is supposed to do

## Process

### 1. Understand Intent
- Read the Task description or plan
- Understand what problem the change solves

### 2. Read the Diff
- Read all changed files in full
- Note the scope of changes

### 3. Check for Issues (in priority order)

#### Critical (must fix)
- Security: hardcoded secrets, auth bypass
- Data loss risk
- Missing error handling on external calls
- Broken functionality (wrong routes, broken API)
- {{CRITICAL_CHECK_1}}

#### Important (should fix)
- Architecture rule violations (see .claude/rules/base/ and .claude/rules/local/)
- Missing tests for new behavior
- Hardcoded values (config, URLs, colors)
- {{IMPORTANT_CHECK_1}}
- {{IMPORTANT_CHECK_2}}

#### Minor (nice to fix)
- Naming improvements
- Code organization
- Documentation gaps

### 4. Report Format
```
## Review Report

**Overall:** APPROVE / REQUEST_CHANGES / NEEDS_DISCUSSION

### Critical
- [file:line] description + suggested fix

### Important
- [file:line] description + suggested fix

### Minor
- [file:line] description

### Good
- What was done well (reinforce good patterns)
```

### 5. Verify
- Run lint/analyze and check the results
- Run tests and check the results
- Compare report findings against actual tool output

## Gotchas
- Do not mix style nitpicks with real issues
- Mark uncertain areas as "needs confirmation" — do not APPROVE/REJECT based on guesses
- The Reviewer must not modify code directly (report only)
- Record out-of-scope code quality issues as separate Tasks

## Project-Specific Checks
- [ ] {{PROJECT_CHECK_1}}
- [ ] {{PROJECT_CHECK_2}}
- [ ] {{PROJECT_CHECK_3}}

## Verdict Criteria
- Any Critical → REQUEST_CHANGES
- Only Important → defer to Developer's judgment
- Only Minor → APPROVE
