---
name: code-review
description: >
  코드 리뷰 워크플로. 다음과 같은 요청에 활성화:
  "코드 리뷰해 줘", "이거 머지해도 될까?", "이 코드 안전해?",
  "PR 검토", "변경사항 확인해 줘", "review this code",
  "is this safe to merge", "check this PR"
  다음에는 활성화하지 않음:
  "코드 작성해 줘", "구현해 줘", "새 기능 만들어 줘", "버그 수정해 줘"
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
- Architecture rule violations (see .claude/rules/)
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
- 스타일 nitpick과 실제 이슈를 섞지 말 것
- 불확실한 부분은 "확인 필요"로 표시 — 추측으로 APPROVE/REJECT 하지 말 것
- Reviewer가 직접 코드를 수정하지 말 것 (보고만)
- 범위 밖 코드 품질 문제는 별도 Task로 기록

## Project-Specific Checks
- [ ] {{PROJECT_CHECK_1}}
- [ ] {{PROJECT_CHECK_2}}
- [ ] {{PROJECT_CHECK_3}}

## Verdict Criteria
- Any Critical → REQUEST_CHANGES
- Only Important → defer to Developer's judgment
- Only Minor → APPROVE
