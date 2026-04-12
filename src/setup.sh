#!/bin/bash
# Claude Code Harness v4 Setup Script
#
# Usage:
#   cd /path/to/your-project
#   /path/to/claude-code-harness-template/setup.sh [--preset=nextjs|python|go] [project-name]

set -e

# Parse --preset flag
PRESET=""
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --preset=*) PRESET="${arg#--preset=}" ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done
set -- "${POSITIONAL[@]+"${POSITIONAL[@]}"}"

PROJECT_NAME="${1:-my-project}"
TEMPLATE_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$(pwd)"

echo "=== Claude Code Harness v4 Setup ==="
echo "Project: $PROJECT_NAME"
echo "Target:  $TARGET_DIR"
echo ""

# Warn if CLAUDE.md already exists
if [ -f "$TARGET_DIR/CLAUDE.md" ]; then
  echo "WARNING: CLAUDE.md already exists in $TARGET_DIR"
  read -p "Overwrite? (y/N): " confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Aborted."
    exit 1
  fi
fi

# Create directory structure
echo "[1/7] Creating directory structure..."
mkdir -p "$TARGET_DIR/.claude/hooks"
mkdir -p "$TARGET_DIR/.claude/rules"
mkdir -p "$TARGET_DIR/context"
mkdir -p "$TARGET_DIR/templates"
mkdir -p "$TARGET_DIR/outputs/plans"
mkdir -p "$TARGET_DIR/outputs/reviews"
mkdir -p "$TARGET_DIR/outputs/archive"
mkdir -p "$TARGET_DIR/handoff"
mkdir -p "$TARGET_DIR/skills/bug-fix/examples"
mkdir -p "$TARGET_DIR/skills/code-review/examples"
mkdir -p "$TARGET_DIR/scripts"
mkdir -p "$TARGET_DIR/docs"

# Copy core files
echo "[2/7] Copying core files..."
cp "$TEMPLATE_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
cp "$TEMPLATE_DIR/.claude/settings.json" "$TARGET_DIR/.claude/settings.json"

# Apply permission preset (adds runtime commands to settings.json allowDenyList)
if [ -n "$PRESET" ]; then
  case "$PRESET" in
    nextjs|node)
      PRESET_RULES='"Bash(npm *)", "Bash(npx *)", "Bash(node *)"'
      ;;
    python)
      PRESET_RULES='"Bash(pip *)", "Bash(pip3 *)", "Bash(python *)", "Bash(python3 *)"'
      ;;
    go)
      PRESET_RULES='"Bash(go *)"'
      ;;
    *)
      echo "WARNING: Unknown preset '$PRESET'. Supported: nextjs, python, go"
      PRESET_RULES=""
      ;;
  esac
  if [ -n "$PRESET_RULES" ]; then
    # Insert preset rules after the last existing allow entry in settings.json
    # Find the last "Bash(git" line and append after it
    sed -i '' '/Bash(git log/a\
      '"$PRESET_RULES"',' "$TARGET_DIR/.claude/settings.json" 2>/dev/null || \
    sed -i '/Bash(git log/a\
      '"$PRESET_RULES"',' "$TARGET_DIR/.claude/settings.json" 2>/dev/null || true
    echo "Applied preset: $PRESET ($PRESET_RULES)"
  fi
fi

# Copy hook scripts and set permissions
echo "[3/7] Setting up hooks..."
cp "$TEMPLATE_DIR/.claude/hooks/"*.sh "$TARGET_DIR/.claude/hooks/"
chmod +x "$TARGET_DIR/.claude/hooks/"*.sh

# Copy rules
echo "[4/7] Copying rules..."
cp "$TEMPLATE_DIR/.claude/rules/"*.md "$TARGET_DIR/.claude/rules/"

# Copy custom commands
echo "[5/7] Copying custom commands..."
mkdir -p "$TARGET_DIR/.claude/commands"
cp "$TEMPLATE_DIR/.claude/commands/"*.md "$TARGET_DIR/.claude/commands/"

# Copy context, templates, skills, docs
echo "[6/7] Copying context, templates, skills, and docs..."
cp "$TEMPLATE_DIR/context/"*.md "$TARGET_DIR/context/"
# decision-log.md is included via context/*.md copy above
cp "$TEMPLATE_DIR/templates/"*.md "$TARGET_DIR/templates/"
cp "$TEMPLATE_DIR/skills/bug-fix/SKILL.md" "$TARGET_DIR/skills/bug-fix/SKILL.md"
cp "$TEMPLATE_DIR/skills/bug-fix/examples/good-output.md" "$TARGET_DIR/skills/bug-fix/examples/good-output.md"
cp "$TEMPLATE_DIR/skills/code-review/SKILL.md" "$TARGET_DIR/skills/code-review/SKILL.md"
cp "$TEMPLATE_DIR/skills/code-review/examples/good-output.md" "$TARGET_DIR/skills/code-review/examples/good-output.md"

# Copy automation scripts
echo "[6.5/7] Copying automation scripts..."
cp "$TEMPLATE_DIR/scripts/"*.sh "$TARGET_DIR/scripts/"
chmod +x "$TARGET_DIR/scripts/"*.sh

# Copy PlaceholderGuide (AI reads this during init session)
if [ -f "$TEMPLATE_DIR/PlaceholderGuide.md" ]; then
  cp "$TEMPLATE_DIR/PlaceholderGuide.md" "$TARGET_DIR/PlaceholderGuide.md"
fi

# Copy project plan template
if [ -f "$TEMPLATE_DIR/docs/project-plan.md" ]; then
  cp "$TEMPLATE_DIR/docs/project-plan.md" "$TARGET_DIR/docs/project-plan.md"
fi

# Replace project name in key files
echo "[7/7] Replacing project name..."
FILES_TO_REPLACE=(
  "$TARGET_DIR/CLAUDE.md"
  "$TARGET_DIR/context/about-me.md"
  "$TARGET_DIR/templates/role-planner.md"
  "$TARGET_DIR/templates/role-developer.md"
  "$TARGET_DIR/templates/role-reviewer.md"
  "$TARGET_DIR/scripts/run-task.sh"
  "$TARGET_DIR/scripts/run-epic.sh"
)

for file in "${FILES_TO_REPLACE[@]}"; do
  if [ -f "$file" ]; then
    sed -i '' "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$file" 2>/dev/null || \
    sed -i "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$file" 2>/dev/null || true
  fi
done

# Create initial handoff file
cat > "$TARGET_DIR/handoff/latest.md" << EOF
# Session Handoff

## Date
$(date +%Y-%m-%d)

## Current State
Project initialized with Claude Code harness v4 template.

## Task Queue
### Next Steps
1. Write project plan in docs/project-plan.md
2. Run init session: Claude reads project plan + PlaceholderGuide.md, fills all placeholders
3. Start Task 1 with Planner role

## Notes
- Harness template version: 4.0.0
- Workflow: Planner → Developer → Reviewer
EOF

# Create .gitignore if it doesn't exist
if [ ! -f "$TARGET_DIR/.gitignore" ]; then
  cat > "$TARGET_DIR/.gitignore" << 'EOF'
# Claude Code
.claude/settings.local.json

# Environment
.env
.env.local
.env.*.local

# Dependencies
node_modules/

# Build
dist/
build/
.next/
EOF
  echo "Created .gitignore"
fi

echo ""
echo "=== Setup Complete (v4.0.0) ==="
echo ""
echo "Next steps:"
echo "  1. Write your project plan in docs/project-plan.md"
echo "  2. Run init session:"
echo ""
echo "     claude \"Read the project plan in docs/ and fill all {{PLACEHOLDER}} values"
echo "     using PlaceholderGuide.md as reference."
echo "     Target files: CLAUDE.md, context/about-me.md, templates/role-*.md"
echo "     Also customize .claude/rules/, .claude/hooks/post-edit-check.sh,"
echo "     and .claude/hooks/post-edit-test.sh for this project.\""
echo ""
echo "  3. Start development (use slash commands):"
echo "     /plan Task 1 — [task description]"
echo "     /develop Task 1 — [task description]"
echo "     /review Task 1 — [task description]"
echo ""
echo "Files created:"
find "$TARGET_DIR" -not -path "*/node_modules/*" -not -path "*/.git/*" \
  \( -name "*.md" -o -name "*.json" -o -name "*.sh" \) | \
  sed "s|$TARGET_DIR/||" | sort | head -30
