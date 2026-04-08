# Testing Rules

## Test Writing:
- Every bug fix must include a regression test
- Test the behavior, not the implementation
- Name tests as: `should [expected behavior] when [condition]`
- One assertion per test when possible

## Test Structure:
- Arrange (setup) / Act (execute) / Assert (verify)
- Use factories or builders for test data, not raw objects
- Clean up side effects (database, files) after each test
- Mock external service calls

## Coverage:
- Critical paths (auth, payment, data mutation) must have tests
- Don't chase 100% coverage — cover what breaks
- Integration tests for API endpoints, unit tests for business logic

## Execution:
- Run relevant tests after every code change
- If a test fails, fix it before writing more code
- Never skip or disable tests without a comment explaining why
