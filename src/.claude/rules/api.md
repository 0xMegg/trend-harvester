# API & Data Rules

## API / External Calls:
- Always validate request input at the boundary
- Return consistent error response format
- Use proper HTTP status codes (don't default everything to 500)
- Never expose internal error stack traces in responses
- Log errors with context (request ID, user ID, endpoint)

## Database Queries:
- Use parameterized queries — never string concatenation for SQL
- Always include WHERE clauses in UPDATE/DELETE statements
- Add indexes for frequently queried columns
- Use transactions for multi-step mutations

## Data Access Pattern:
- Access data through the designated pattern (repository, service, etc.)
- Never call the database directly from UI/presentation layer
- Wrap all external calls in try/catch with meaningful error messages
- Separate user-facing error messages from debug logs

## Authentication & Security:
- Never log tokens, passwords, or session IDs
- Validate auth on every protected endpoint
- Check authorization (permissions) separately from authentication (identity)
