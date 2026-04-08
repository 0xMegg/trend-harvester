# Frontend Rules

## Components:
- One component/widget per file
- Keep components under 200 lines; extract sub-components if larger
- Prefer stateless/functional components; use stateful only when necessary
- Props/parameters must be explicitly typed (no `any`, no `dynamic`)

## Styling:
- Follow the project's existing styling approach
- Don't mix styling approaches within the same component
- Use design tokens/variables for colors, spacing, typography
- No hardcoded color values — use theme tokens
- Responsive/adaptive design where applicable

## State Management:
- Local state for UI-only concerns
- Shared state for cross-component data
- Server/async state via the project's data fetching pattern
- Never duplicate server data in client state

## Navigation/Routing:
- Use only the project's designated routing solution
- Route additions/changes only when the task explicitly requires it
- No mixing of routing approaches (e.g., no Navigator.push if using GoRouter)

## Performance:
- Lazy load routes and heavy components
- Memoize expensive computations only when measured
- Don't premature optimize — measure first

## Accessibility:
- Semantic elements over generic containers
- Interactive elements must be keyboard accessible
- Sufficient color contrast
