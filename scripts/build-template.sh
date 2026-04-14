#!/bin/bash
# build-template.sh — Build the harness template from src/ to the target repo
#
# Usage:
#   ./scripts/build-template.sh                    # Deploy to sibling repo
#   ./scripts/build-template.sh /path/to/target    # Deploy to custom path
#
# Copies src/ contents to the target harness template repo.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$PROJECT_DIR/src"
OUT_DIR="${1:-$PROJECT_DIR/../claude-code-harness-template}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ ! -d "$SRC_DIR" ]; then
  echo -e "${RED}✗ src/ directory not found at $SRC_DIR${NC}"
  exit 1
fi

echo -e "${CYAN}Building harness template...${NC}"
echo "  Source: $SRC_DIR"
echo "  Output: $OUT_DIR"

# Verify target exists
if [ ! -d "$OUT_DIR" ]; then
  echo -e "${RED}✗ Target directory not found: $OUT_DIR${NC}"
  echo "Create it first or specify a path: $0 /path/to/target"
  exit 1
fi

# Sync src/ to target (preserve .git in target!)
# Remove old template files but keep .git, harvest data, and outputs
rsync -av --delete \
  --exclude='.git' \
  --exclude='.git/' \
  --exclude='harvest/' \
  --exclude='outputs/' \
  --exclude='.DS_Store' \
  "$SRC_DIR/" "$OUT_DIR/"

# Write harness version stamp for staleness detection by run-epic/run-task
FORGE_HASH=$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
FORGE_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > "$OUT_DIR/.claude/.harness-version" << VEOF
HARNESS_VERSION=4.0.0
FORGE_COMMIT=$FORGE_HASH
BUILD_TIMESTAMP=$FORGE_TIMESTAMP
VEOF
echo "  Version stamp: .claude/.harness-version (forge $FORGE_HASH)"

# Ensure scripts are executable
find "$OUT_DIR/scripts" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
[ -f "$OUT_DIR/setup.sh" ] && chmod +x "$OUT_DIR/setup.sh"

# Count files
FILE_COUNT=$(find "$OUT_DIR" -type f -not -path '*/.git/*' | wc -l | tr -d ' ')

echo ""
echo -e "${GREEN}✓ Template deployed to: $OUT_DIR${NC}"
echo "  Files synced: $FILE_COUNT"
echo ""
echo -e "${YELLOW}Next: cd $OUT_DIR && git add -A && git commit -m 'chore: template update from harness-forge'${NC}"
