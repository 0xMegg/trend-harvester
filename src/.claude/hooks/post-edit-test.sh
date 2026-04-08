#!/bin/bash
# Hook: Run targeted tests after file edits (PostToolUse)
#
# Maps edited source files to their test counterparts and runs only those.
# Skips gracefully if no matching test is found.
#
# Configuration (replace placeholders for your project):
#   SRC_DIR  — source code root (e.g., "lib", "src", "app")
#   TEST_DIR — test root (e.g., "test", "tests", "__tests__")
#   TEST_CMD — test runner command (e.g., "flutter test", "npx vitest run", "pytest")

INPUT="$1"

# ============================================================
# Project configuration — replace these placeholders
# ============================================================
SRC_DIR="{{SRC_DIR}}"
TEST_DIR="{{TEST_DIR}}"
TEST_CMD="{{TEST_CMD}}"

# ============================================================
# Skip if not configured
# ============================================================
if [[ "$SRC_DIR" == *"{{"* ]] || [[ "$TEST_CMD" == *"{{"* ]]; then
  # Placeholders not replaced yet — skip silently
  exit 0
fi

# ============================================================
# Extract edited file path from tool input
# ============================================================
EDITED_FILE=""
if echo "$INPUT" | grep -qE '"file_path"\s*:'; then
  EDITED_FILE=$(echo "$INPUT" | grep -oE '"file_path"\s*:\s*"[^"]+"' | head -1 | sed 's/.*"file_path"\s*:\s*"//;s/"//')
fi

# Fallback: try to extract any path that looks like a source file
if [ -z "$EDITED_FILE" ]; then
  EDITED_FILE=$(echo "$INPUT" | grep -oE "[a-zA-Z_/]+\.[a-zA-Z]+" | head -1)
fi

# Skip if we couldn't determine the edited file
if [ -z "$EDITED_FILE" ]; then
  exit 0
fi

# Skip if the edited file is not in the source directory
if ! echo "$EDITED_FILE" | grep -q "$SRC_DIR"; then
  exit 0
fi

# Skip if the edited file IS a test file
if echo "$EDITED_FILE" | grep -q "$TEST_DIR"; then
  exit 0
fi

# ============================================================
# Find matching test file
# ============================================================

# Strategy 1: Mirror path (lib/features/auth/data/repo.dart → test/features/auth/data/repo_test.dart)
RELATIVE_PATH=$(echo "$EDITED_FILE" | sed "s|.*${SRC_DIR}/||")
FILENAME=$(basename "$RELATIVE_PATH")
DIRNAME=$(dirname "$RELATIVE_PATH")
BASENAME="${FILENAME%.*}"
EXT="${FILENAME##*.}"

# Build candidate test paths
CANDIDATES=()

# Pattern: test/path/to/file_test.ext (Dart, Go)
CANDIDATES+=("${TEST_DIR}/${DIRNAME}/${BASENAME}_test.${EXT}")

# Pattern: test/path/to/file.test.ext (JS/TS)
CANDIDATES+=("${TEST_DIR}/${DIRNAME}/${BASENAME}.test.${EXT}")

# Pattern: test/path/to/file.spec.ext (JS/TS)
CANDIDATES+=("${TEST_DIR}/${DIRNAME}/${BASENAME}.spec.${EXT}")

# Pattern: __tests__/path/to/file.test.ext (React convention)
CANDIDATES+=("__tests__/${DIRNAME}/${BASENAME}.test.${EXT}")

# Strategy 2: Find any test in the same feature directory
FEATURE_DIR=""
if echo "$DIRNAME" | grep -qE "features/[^/]+"; then
  FEATURE_DIR=$(echo "$DIRNAME" | grep -oE "features/[^/]+")
fi

# ============================================================
# Try to run the matching test
# ============================================================
for candidate in "${CANDIDATES[@]}"; do
  if [ -f "$candidate" ]; then
    echo "Running targeted test: $candidate"
    $TEST_CMD "$candidate" 2>&1 | tail -5
    TEST_EXIT=$?
    if [ $TEST_EXIT -ne 0 ]; then
      echo "TARGETED TEST FAILED: $candidate (exit code: $TEST_EXIT)"
    else
      echo "Targeted test passed."
    fi
    exit 0
  fi
done

# Strategy 2: Run all tests in the feature directory
if [ -n "$FEATURE_DIR" ] && [ -d "${TEST_DIR}/${FEATURE_DIR}" ]; then
  echo "No exact test match. Running feature tests: ${TEST_DIR}/${FEATURE_DIR}/"
  $TEST_CMD "${TEST_DIR}/${FEATURE_DIR}/" 2>&1 | tail -5
  exit 0
fi

# No test found — warn but don't block
echo "No matching test found for: $EDITED_FILE (skipping)"
exit 0
