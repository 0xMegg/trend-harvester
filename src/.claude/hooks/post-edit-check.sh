#!/bin/bash
# Hook: Automatic checks after file edits (PostToolUse)
#
# Severity levels:
#   BLOCK (exit 2) — Critical violations that must be fixed before continuing
#   WARN  (exit 0) — Advisory warnings, logged but non-blocking
#
# Project-specific blocked patterns can be added to BLOCKED_PATTERNS array below.

INPUT="$1"
BLOCKED=false

# ============================================================
# BLOCK: .env file modifications (secrets must not be in code)
# ============================================================
if echo "$INPUT" | grep -qE '\.env'; then
  echo "BLOCKED: .env file was modified. Secrets must not be committed."
  BLOCKED=true
fi

# ============================================================
# BLOCK: Hardcoded secret patterns
# ============================================================
SECRET_PATTERNS=(
  "sk-[a-zA-Z0-9]{20,}"
  "AKIA[A-Z0-9]{16}"
  "ghp_[a-zA-Z0-9]{36}"
  "password\s*=\s*['\"][^'\"]+['\"]"
  "api_key\s*=\s*['\"][^'\"]+['\"]"
  "secret\s*=\s*['\"][^'\"]+['\"]"
)

for pattern in "${SECRET_PATTERNS[@]}"; do
  if echo "$INPUT" | grep -qiE "$pattern"; then
    echo "BLOCKED: Possible hardcoded secret detected. Remove before continuing."
    BLOCKED=true
    break
  fi
done

# ============================================================
# BLOCK: Project-specific forbidden patterns
# Replace or extend these for your project.
# Examples:
#   "Navigator\.push"         — must use GoRouter
#   "Supabase\.instance"      — must use Repository pattern (in UI layer)
#   "document\.cookie"        — direct cookie manipulation forbidden
# ============================================================
BLOCKED_PATTERNS=(
  # {{BLOCKED_PATTERN_1}}
  # {{BLOCKED_PATTERN_2}}
  # {{BLOCKED_PATTERN_3}}
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  # Skip empty/commented patterns
  [[ -z "$pattern" || "$pattern" == \#* ]] && continue
  if echo "$INPUT" | grep -qE "$pattern"; then
    echo "BLOCKED: Forbidden pattern detected: $pattern"
    BLOCKED=true
  fi
done

# ============================================================
# Exit: BLOCK if any critical violation found
# ============================================================
if [ "$BLOCKED" = true ]; then
  echo "Fix the above violations before continuing."
  exit 2
fi

# ============================================================
# WARN: Advisory patterns (non-blocking)
# Add project-specific warnings here.
# ============================================================
WARN_PATTERNS=(
  # {{WARN_PATTERN_1}}
  # {{WARN_PATTERN_2}}
)

for pattern in "${WARN_PATTERNS[@]}"; do
  [[ -z "$pattern" || "$pattern" == \#* ]] && continue
  if echo "$INPUT" | grep -qE "$pattern"; then
    echo "WARNING: Pattern detected (review recommended): $pattern"
  fi
done

exit 0
