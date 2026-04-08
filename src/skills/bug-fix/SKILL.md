---
name: bug-fix
description: >
  버그 수정 워크플로. 다음과 같은 요청에 활성화:
  "버그 수정해 줘", "이거 왜 안 돼?", "에러 발생", "동작이 이상해",
  "regression 생겼어", "이전에 되던 게 안 됨", "fix this bug",
  "broken", "not working"
  다음에는 활성화하지 않음:
  "리팩토링해 줘", "새 기능 추가", "성능 개선", "코드 정리"
version: 3.0.0
---

# Bug Fix Skill

## Objective
Fix the bug with minimal blast radius and full verification.

## Inputs
- Bug description (what is broken)
- Reproduction steps (or enough info to find them)

## Process

### 1. Understand
- Read the bug report
- Identify the affected area (files, modules, endpoints)
- Read the relevant code

### 2. Reproduce
- Follow reproduction steps
- Record the exact error message or incorrect behavior

### 3. Diagnose
- Form a root cause hypothesis
- Trace the code path from trigger to symptom
- Check git blame for recent changes
- If hypothesis is wrong, form a new one (max 3 attempts, then escalate to human)

### 4. Plan
- Write a fix plan using `templates/bug-fix.md`
- Define scope: files to change vs. files to avoid
- Present the plan before implementing

### 5. Implement
- Make the smallest change that fixes the bug
- Do not refactor surrounding code
- If you find other bugs, note them in handoff (don't fix now)

### 6. Verify
- [ ] `{{LINT_CMD}}` passes with no warnings
- [ ] Related tests pass
- [ ] Regression test added
- [ ] Project architecture rules followed (see .claude/rules/)
- [ ] Manual reproduction no longer triggers the bug
- [ ] {{VERIFY_CHECK_1}}
- [ ] {{VERIFY_CHECK_2}}

### 7. Handoff
- Update handoff/latest.md
- Record what changed, why, and any remaining risk

## Gotchas
- Fixing the symptom instead of the root cause
- Changing too many files at once
- Forgetting to add a regression test
- Mixing scope — doing refactoring alongside the fix
- 불확실한 원인은 추측하지 말고 "확인 필요"로 표시
- 3회 이상 가설이 틀리면 사람에게 에스컬레이션
- 에러 메시지만 보고 원인을 단정하지 말 것 — 실제 코드 경로를 반드시 추적
- {{PITFALL_1}}
- {{PITFALL_2}}
