# Placeholder Guide (v4)

This document lists every `{{PLACEHOLDER}}` in the harness template and how to fill them.
Read the project plan in `docs/` first, then replace each placeholder with project-specific values.

---

## 1. CLAUDE.md — Project Contract

### Project Info

| Placeholder | Description | Examples |
|-------------|-------------|----------|
| `{{PROJECT_NAME}}` | Project name | `my-saas-app`, `divebase`, `portfolio-site` |
| `{{PROJECT_TYPE}}` | Project type | `Web App`, `Mobile App (Flutter)`, `API Server`, `CLI Tool` |
| `{{TECH_STACK}}` | Main technologies, comma-separated | `Next.js 15, React 19, TypeScript, Tailwind, Prisma, PostgreSQL` |

### Build & Test Commands (most important!)

These commands are used for automatic verification after every code change.

| Placeholder | Description | Examples |
|-------------|-------------|----------|
| `{{INSTALL_CMD}}` | Install dependencies | `npm install`, `flutter pub get`, `pip install -r requirements.txt` |
| `{{DEV_CMD}}` | Run dev server | `npm run dev`, `flutter run`, `python manage.py runserver` |
| `{{BUILD_CMD}}` | Production build | `npm run build`, `flutter build apk`, `go build` |
| `{{TEST_CMD}}` | Run all tests | `npm test`, `flutter test`, `pytest`, `go test ./...` |
| `{{TEST_SINGLE_CMD}}` | Run a single test file | `npx vitest run {{file}}`, `flutter test test/{{file}}`, `pytest {{file}}` |
| `{{LINT_CMD}}` | Lint / analyze | `npm run lint`, `dart analyze`, `flake8`, `golangci-lint run` |
| `{{FORMAT_CMD}}` | Code formatting | `npx prettier --write .`, `dart format lib/`, `black .`, `gofmt -w .` |

> If a command doesn't exist for this project, delete the entire line.

### Folder Boundaries

| Placeholder | Description | Examples |
|-------------|-------------|----------|
| `{{SRC_DIR}}` | Source code root | `src/`, `lib/`, `app/`, `cmd/` |
| `{{TEST_DIR}}` | Test root | `tests/`, `test/`, `__tests__/` |
| `{{BUILD_OUTPUT}}` | Build output (do not modify) | `dist`, `build`, `.next` |
| `{{LOCK_FILE}}` | Lock file (do not modify) | `package-lock.json`, `pubspec.lock`, `poetry.lock` |

### Architecture

| Placeholder | Description | Examples |
|-------------|-------------|----------|
| `{{ARCHITECTURE_PATTERN}}` | Code structure pattern | `Feature-First`, `MVC`, `Clean Architecture`, `Monolith` |
| `{{STATE_MANAGEMENT}}` | State management | `Riverpod`, `Redux`, `Zustand`, `Pinia`, `None (SSR)` |
| `{{ROUTING}}` | Routing approach | `GoRouter`, `Next.js App Router`, `React Router`, `file-based` |
| `{{DATA_ACCESS_PATTERN}}` | Data access pattern | `Repository pattern`, `Direct ORM`, `API client`, `Supabase SDK` |

### Coding Conventions

| Placeholder | Description | Examples |
|-------------|-------------|----------|
| `{{LANGUAGE}}` | Primary language | `TypeScript (strict)`, `Dart`, `Python 3.12`, `Go 1.22` |
| `{{NAMING_CONVENTION}}` | Naming rules | `camelCase for vars, PascalCase for classes` |
| `{{FILE_NAMING}}` | File naming rules | `snake_case`, `kebab-case`, `PascalCase` |
| `{{IMPORT_STYLE}}` | Import style | `absolute (@/components)`, `relative`, `package imports first` |
| `{{ERROR_HANDLING}}` | Error handling approach | `try/catch with typed errors`, `Result type`, `error wrapping` |

### Other

| Placeholder | Description | Examples |
|-------------|-------------|----------|
| `{{PROTECTED_FILES}}` | Files that must not be modified without asking | `CI/CD configs`, `supabase/migrations`, `android/, ios/` |
| `{{SCHEMA_FILE}}` | Data schema document (if any) | `SCHEMA.md`, `prisma/schema.prisma`, delete line if none |

---

## 2. .claude/hooks/ — Hook Configuration

### post-edit-check.sh (BLOCK/WARN patterns)

| Placeholder | Description | Examples |
|-------------|-------------|----------|
| `{{BLOCKED_PATTERN_1}}` | Forbidden code pattern (blocks edit) | `Navigator\.push` (must use GoRouter) |
| `{{BLOCKED_PATTERN_2}}` | Forbidden code pattern (blocks edit) | `Supabase\.instance` (must use Repository in UI layer) |
| `{{BLOCKED_PATTERN_3}}` | Forbidden code pattern (blocks edit) | `document\.cookie` (direct cookie manipulation) |
| `{{WARN_PATTERN_1}}` | Advisory pattern (logged, non-blocking) | `TODO:` (reminder to clean up) |
| `{{WARN_PATTERN_2}}` | Advisory pattern (logged, non-blocking) | `console\.log` (remove before commit) |

> Uncomment and fill patterns in the arrays inside post-edit-check.sh. BLOCK patterns cause exit 2 (edit is rejected). WARN patterns are logged but don't stop work.

### post-edit-test.sh (targeted test runner)

| Placeholder | Description | Examples |
|-------------|-------------|----------|
| `{{SRC_DIR}}` | Source code root (same as CLAUDE.md) | `lib`, `src`, `app` |
| `{{TEST_DIR}}` | Test root (same as CLAUDE.md) | `test`, `tests`, `__tests__` |
| `{{TEST_CMD}}` | Test runner command (same as CLAUDE.md) | `flutter test`, `npx vitest run`, `pytest` |

> These must match CLAUDE.md values. The hook maps edited source files to test counterparts automatically.

---

## 3. .claude/rules/base/gotchas.md — Project Pitfalls

| Placeholder | Description | Examples |
|-------------|-------------|----------|
| `{{GOTCHA_1}}` | Pitfall 1 | `build_runner must run before test`, `RLS hides rows silently` |
| `{{GOTCHA_2}}` | Pitfall 2 | `iOS simulator needs manual cert refresh after 7 days` |
| `{{GOTCHA_3}}` | Pitfall 3 | `Legacy code in lib/screens/ uses different patterns` |

> Add or remove lines as needed. These accumulate over time — each bug fix or unexpected behavior is a candidate. Moved from CLAUDE.md to rules/base/ so it's auto-applied without bloating the contract. Project-specific gotchas discovered mid-flight should go in `rules/local/gotchas-<project>.md` to survive harness upgrades.

---

## 4. context/about-me.md — Project Background

| Placeholder | Description | Examples |
|-------------|-------------|----------|
| `{{PROJECT_NAME}}` | Same as CLAUDE.md | — |
| `{{ONE_PARAGRAPH_DESCRIPTION}}` | 2-3 sentence project description | `Project management SaaS for small teams. Kanban, timeline, team chat.` |
| `{{FRONTEND}}` | Frontend tech + version | `Next.js 15, React 19, TypeScript 5.5, Tailwind CSS 4` |
| `{{BACKEND}}` | Backend tech + version | `Node.js 22, Express` or `None (serverless)` |
| `{{DATABASE}}` | Database | `PostgreSQL 16`, `Supabase`, `MongoDB Atlas` |
| `{{HOSTING}}` | Hosting/deployment | `Vercel`, `AWS EC2`, `undecided` |
| `{{SRC_DIR}}` | Source code path | `src/app/`, `lib/features/` |
| `{{TEST_DIR}}` | Test path | `tests/`, `test/` |
| `{{CONFIG_DIR}}` | Config path | `config/`, `project root` |
| `{{TARGET_USERS}}` | Target users | `Korean startup PMs`, `personal tool`, `general consumers (20-30s)` |
| `{{ANY_CONSTRAINTS_OR_HISTORY}}` | Things Claude can't know from code alone | `Legacy jQuery in pages/`, `Launching in June`, `Solo project` |

---

## 5. templates/role-*.md — Role Files

### role-planner.md

| Placeholder | Description |
|-------------|-------------|
| `{{PROJECT_NAME}}` | Auto-replaced by setup.sh |
| `{{SCHEMA_FILE}}` | Same as CLAUDE.md |

### role-developer.md

| Placeholder | Description |
|-------------|-------------|
| `{{PROJECT_NAME}}` | Auto-replaced by setup.sh |
| `{{LINT_CMD}}` | Same as CLAUDE.md Lint/Analyze command |
| `{{TEST_CMD}}` | Same as CLAUDE.md Test all command |

### role-reviewer.md

| Placeholder | Description | Examples |
|-------------|-------------|----------|
| `{{PROJECT_NAME}}` | Auto-replaced by setup.sh | — |
| `{{LINT_CMD}}` | Same as CLAUDE.md | — |
| `{{TEST_CMD}}` | Same as CLAUDE.md | — |
| `{{ARCHITECTURE_CHECK_1}}` | Architecture check item 1 | `Repository pattern followed` |
| `{{ARCHITECTURE_CHECK_2}}` | Architecture check item 2 | `Routing solution is consistent` |
| `{{ARCHITECTURE_CHECK_3}}` | Architecture check item 3 | `Design system tokens used` |
| `{{SECURITY_CHECK}}` | Security check item | `No RLS bypass`, `XSS defense`, `CSRF token present` |

---

## 6. skills/ — Skill Placeholders

### skills/bug-fix/SKILL.md

| Placeholder | Description | Examples |
|-------------|-------------|----------|
| `{{LINT_CMD}}` | Same as CLAUDE.md | `dart analyze`, `npm run lint` |
| `{{VERIFY_CHECK_1}}` | Project-specific verification | `Repository pattern followed`, `No direct DB calls from UI` |
| `{{VERIFY_CHECK_2}}` | Project-specific verification | `GoRouter only (no Navigator.push)`, `Design tokens used` |
| `{{PITFALL_1}}` | Common project-specific mistake | `Defining Providers inline in page files`, `Calling API directly from UI` |
| `{{PITFALL_2}}` | Common project-specific mistake | `Forgetting RLS means no WHERE user_id needed`, `Missing try/catch on async calls` |

### skills/code-review/SKILL.md

| Placeholder | Description | Examples |
|-------------|-------------|----------|
| `{{CRITICAL_CHECK_1}}` | Project-specific critical issue | `RLS bypass`, `Missing auth check`, `SQL injection risk` |
| `{{IMPORTANT_CHECK_1}}` | Project-specific important issue | `Direct DB calls from UI (must use Repository)`, `Provider defined inline in page` |
| `{{IMPORTANT_CHECK_2}}` | Project-specific important issue | `Navigator.push used (should use GoRouter)`, `Hardcoded colors (use tokens)` |
| `{{PROJECT_CHECK_1}}` | Project-wide architecture check | `Feature-local first principle followed` |
| `{{PROJECT_CHECK_2}}` | Project-wide architecture check | `Data schema alignment (check schema doc)` |
| `{{PROJECT_CHECK_3}}` | Project-wide architecture check | `RLS isolation maintained` |

> These accumulate as you learn what breaks in your project. Fill during first review or after the first bug fix.

---

## 7. templates/verify.md — Verification Plan

Uses the same `{{LINT_CMD}}`, `{{TEST_CMD}}`, `{{TEST_SINGLE_CMD}}`, `{{BUILD_CMD}}` as CLAUDE.md.
No additional placeholders — the Planner fills in task-specific checks when writing each verification plan.

---

## 8. .claude/commands/blog.md — Blog Command

| Placeholder | Description | Examples |
|-------------|-------------|----------|
| `{{BLOG_LANGUAGE}}` | Blog post language | `Korean`, `English`, `Japanese` |

---

## Priority

### Must fill now
- `{{PROJECT_NAME}}`, `{{PROJECT_TYPE}}`
- `{{INSTALL_CMD}}`, `{{DEV_CMD}}`, `{{BUILD_CMD}}`, `{{TEST_CMD}}`, `{{LINT_CMD}}`
- `{{ONE_PARAGRAPH_DESCRIPTION}}`
- `{{LANGUAGE}}`, `{{TECH_STACK}}`

### Can fill later
- `{{TARGET_USERS}}`, `{{HOSTING}}`
- `{{ANY_CONSTRAINTS_OR_HISTORY}}`
- `{{TEST_SINGLE_CMD}}`, `{{FORMAT_CMD}}`
- `{{ARCHITECTURE_CHECK_*}}`, `{{SECURITY_CHECK}}` (can fill during first review)
- `{{BLOG_LANGUAGE}}` (defaults to Korean if unfilled)
- `{{GOTCHA_*}}` (accumulate during development — each bug fix adds candidates)
- `{{BLOCKED_PATTERN_*}}`, `{{WARN_PATTERN_*}}` (fill when you discover forbidden/advisory patterns)
- `{{VERIFY_CHECK_*}}`, `{{PITFALL_*}}`, `{{CRITICAL_CHECK_*}}`, `{{IMPORTANT_CHECK_*}}`, `{{PROJECT_CHECK_*}}` (fill during first review/bug fix)

> **Key principle:** Build/test commands must be accurate for Claude to auto-verify after code changes. If those are correct, the rest can be filled incrementally.
