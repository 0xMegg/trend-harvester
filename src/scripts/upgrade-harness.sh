#!/bin/bash
# upgrade-harness.sh — Manifest-based harness update from the template repo.
#
# Replaces the old rsync --update auto-sync that confused mtime comparison
# with "project-owned file protection" — see .harness-manifest for the
# declarative ownership policy consumed here.
#
# Behavior (per template file, classified via .harness-manifest):
#   managed → copy to project, overwriting any existing version
#   seed    → copy to project only if destination does not exist
#   ignore  → skip
#   (unclassified → report as a coverage gap; nothing copied)
#
# Usage:
#   scripts/upgrade-harness.sh             # dry-run (default — nothing changes)
#   scripts/upgrade-harness.sh --apply     # perform the update
#   scripts/upgrade-harness.sh --help      # show this comment block
#
# Reads TEMPLATE_REPO from .claude/.harness-origin. Exits 1 on config errors.

set -eo pipefail

# ---------- Colors ----------
if [ -t 2 ]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  CYAN=$'\033[0;36m'
  BOLD=$'\033[1m'
  NC=$'\033[0m'
else
  RED="" GREEN="" YELLOW="" CYAN="" BOLD="" NC=""
fi

# ---------- Arg parsing ----------
APPLY=false
case "${1:-}" in
  ""|--dry-run) APPLY=false ;;
  --apply)      APPLY=true ;;
  -h|--help)
    sed -n 's/^# \{0,1\}//p' "$0" | sed '/^!/,$d'
    exit 0
    ;;
  *)
    echo "${RED}ERROR: unknown argument: ${1}${NC}" >&2
    echo "Usage: $0 [--dry-run|--apply]" >&2
    exit 1
    ;;
esac

# ---------- Locate project + template ----------
# TEMPLATE_REPO resolution order:
#   1. pre-set env var (one-off propagation, broken .harness-origin bypass)
#   2. .claude/.harness-origin in the project (seed-owned; each project
#      customizes its path)
PROJECT_DIR="$(pwd)"
ORIGIN_FILE="$PROJECT_DIR/.claude/.harness-origin"

if [ -z "${TEMPLATE_REPO:-}" ]; then
  if [ ! -f "$ORIGIN_FILE" ]; then
    echo "${RED}ERROR: .claude/.harness-origin not found and TEMPLATE_REPO env var not set${NC}" >&2
    echo "  Either:  (a) run setup.sh from the template, or" >&2
    echo "           (b) invoke with:  TEMPLATE_REPO=/path/to/template bash $0" >&2
    exit 1
  fi
  # shellcheck source=/dev/null
  source "$ORIGIN_FILE"
fi

if [ -z "${TEMPLATE_REPO:-}" ]; then
  echo "${RED}ERROR: TEMPLATE_REPO unresolved (not in env and not in $ORIGIN_FILE)${NC}" >&2
  exit 1
fi

# Resolve relative path against project dir
case "$TEMPLATE_REPO" in
  /*) ;;  # absolute
  *)  TEMPLATE_REPO="$PROJECT_DIR/$TEMPLATE_REPO" ;;
esac

if [ ! -d "$TEMPLATE_REPO" ]; then
  echo "${RED}ERROR: TEMPLATE_REPO directory does not exist: $TEMPLATE_REPO${NC}" >&2
  echo "  Check TEMPLATE_REPO in $ORIGIN_FILE" >&2
  exit 1
fi
TEMPLATE_REPO="$(cd "$TEMPLATE_REPO" && pwd)"

MANIFEST="$TEMPLATE_REPO/.harness-manifest"
if [ ! -f "$MANIFEST" ]; then
  echo "${RED}ERROR: .harness-manifest not found at $MANIFEST${NC}" >&2
  echo "  Template repo is out of date — rebuild from forge src/ first." >&2
  exit 1
fi

# Refuse to upgrade into the template repo itself
if [ "$PROJECT_DIR" = "$TEMPLATE_REPO" ]; then
  echo "${RED}ERROR: refusing to upgrade the template repo into itself${NC}" >&2
  exit 1
fi

# ---------- Parse manifest ----------
MANAGED=()
SEED=()
IGNORE=()
DEPRECATED=()
section=""
while IFS= read -r line || [ -n "$line" ]; do
  # Trim trailing + leading whitespace (tabs and spaces)
  line="${line%"${line##*[! 	]}"}"
  line="${line#"${line%%[! 	]*}"}"
  [ -z "$line" ] && continue
  case "$line" in
    \#*) continue ;;
    \[managed\])    section="managed";    continue ;;
    \[seed\])       section="seed";       continue ;;
    \[ignore\])     section="ignore";     continue ;;
    \[deprecated\]) section="deprecated"; continue ;;
    \[*)            section="";           continue ;;
  esac
  case "$section" in
    managed)    MANAGED+=("$line") ;;
    seed)       SEED+=("$line")    ;;
    ignore)     IGNORE+=("$line")  ;;
    deprecated) DEPRECATED+=("$line") ;;
  esac
done < "$MANIFEST"

# ---------- Resolve PROJECT_NAME for placeholder substitution ----------
# Order: env var → CLAUDE.md "- Name:" line → directory basename.
# Used to substitute {{PROJECT_NAME}} in managed .md/.sh files post-copy
# (covers files that setup.sh's FILES_TO_REPLACE list missed at init time).
resolve_project_name() {
  if [ -n "${PROJECT_NAME:-}" ]; then
    echo "$PROJECT_NAME"
    return
  fi
  if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
    local n
    n="$(awk '/^- Name:/ { sub(/^- Name:[[:space:]]*/, ""); print; exit }' "$PROJECT_DIR/CLAUDE.md")"
    if [ -n "$n" ] && [ "$n" != "{{PROJECT_NAME}}" ]; then
      echo "$n"
      return
    fi
  fi
  basename "$PROJECT_DIR"
}
PROJECT_NAME_RESOLVED="$(resolve_project_name)"

# ---------- Classification ----------
# Returns 0 if $1 matches pattern $2; handles `dir/**` as recursive prefix.
match_pattern() {
  local path="$1" pattern="$2" base
  case "$pattern" in
    */\*\*)
      base="${pattern%/\*\*}"
      case "$path" in
        "$base"|"$base"/*) return 0 ;;
      esac
      return 1
      ;;
  esac
  # shellcheck disable=SC2053
  [[ "$path" == $pattern ]]
}

classify() {
  local path="$1" p
  for p in ${MANAGED[@]+"${MANAGED[@]}"}; do
    match_pattern "$path" "$p" && { echo managed; return; }
  done
  for p in ${SEED[@]+"${SEED[@]}"}; do
    match_pattern "$path" "$p" && { echo seed; return; }
  done
  for p in ${IGNORE[@]+"${IGNORE[@]}"}; do
    match_pattern "$path" "$p" && { echo ignore; return; }
  done
  echo unknown
}

# ---------- Walk template ----------
ACT_MANAGED_NEW=()      # managed file, not present in project
ACT_MANAGED_OW=()       # managed file, differs from project copy
ACT_MANAGED_SAME=()     # managed file, identical
ACT_SEED_INSTALL=()     # seed file, project missing it
ACT_SEED_SKIP=()        # seed file, project already has it
ACT_IGNORE=()           # template file classified as ignore (rare)
ACT_UNKNOWN=()          # template file not matched by any section
ACT_DEPRECATED_DEL=()   # deprecated path present in project — will be deleted
ACT_DEPRECATED_GONE=()  # deprecated path already absent — silent skip

while IFS= read -r -d '' file; do
  rel="${file#"$TEMPLATE_REPO"/}"
  # Always skip git internals and OS artifacts at the template side
  case "$rel" in
    .git|.git/*) continue ;;
    *.DS_Store) continue ;;
  esac

  klass="$(classify "$rel")"
  dst="$PROJECT_DIR/$rel"

  case "$klass" in
    managed)
      if [ ! -e "$dst" ]; then
        ACT_MANAGED_NEW+=("$rel")
      elif cmp -s "$file" "$dst"; then
        ACT_MANAGED_SAME+=("$rel")
      else
        ACT_MANAGED_OW+=("$rel")
      fi
      if $APPLY; then
        mkdir -p "$(dirname "$dst")"
        cp -p "$file" "$dst"
        # Post-copy: substitute {{PROJECT_NAME}} in managed text files so
        # downstream projects do not ship raw placeholders (root cause of
        # the divebase task.md regression where the inline command pointed
        # at /tmp/{{PROJECT_NAME}}-run/).
        case "$rel" in
          *.md|*.sh)
            if grep -q '{{PROJECT_NAME}}' "$dst" 2>/dev/null; then
              sed -i '' "s/{{PROJECT_NAME}}/$PROJECT_NAME_RESOLVED/g" "$dst" 2>/dev/null || \
              sed -i "s/{{PROJECT_NAME}}/$PROJECT_NAME_RESOLVED/g" "$dst" 2>/dev/null || true
            fi
            ;;
        esac
      fi
      ;;
    seed)
      if [ -e "$dst" ]; then
        ACT_SEED_SKIP+=("$rel")
      else
        ACT_SEED_INSTALL+=("$rel")
        if $APPLY; then
          mkdir -p "$(dirname "$dst")"
          cp -p "$file" "$dst"
        fi
      fi
      ;;
    ignore)  ACT_IGNORE+=("$rel")  ;;
    unknown) ACT_UNKNOWN+=("$rel") ;;
  esac
done < <(find "$TEMPLATE_REPO" -type f -print0)

# ---------- Process [deprecated] removals ----------
# Iterates manifest [deprecated] entries against the project (no template
# walk — these are paths the harness no longer ships). Existing files are
# deleted on --apply; absent files are silent (re-running upgrade stays
# idempotent after a successful cleanup).
for dpath in ${DEPRECATED[@]+"${DEPRECATED[@]}"}; do
  if [ -e "$PROJECT_DIR/$dpath" ]; then
    ACT_DEPRECATED_DEL+=("$dpath")
    if $APPLY; then
      rm -f "$PROJECT_DIR/$dpath"
    fi
  else
    ACT_DEPRECATED_GONE+=("$dpath")
  fi
done

# Ensure managed scripts/hooks remain executable after copy
if $APPLY; then
  find "$PROJECT_DIR/scripts"        -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
  find "$PROJECT_DIR/.claude/hooks"  -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
  [ -f "$PROJECT_DIR/setup.sh" ] && chmod +x "$PROJECT_DIR/setup.sh"
fi

# ---------- Report ----------
mode_label="DRY-RUN"
$APPLY && mode_label="APPLY"

print_list() {
  local prefix="$1"; shift
  local f
  for f in "$@"; do
    echo "    $prefix  $f"
  done
}

echo
echo "${BOLD}=== Harness upgrade — mode: ${mode_label} ===${NC}"
echo "  Template: $TEMPLATE_REPO"
echo "  Project:  $PROJECT_DIR"
echo

echo "${CYAN}Managed — new install      : ${#ACT_MANAGED_NEW[@]}${NC}"
print_list "+" ${ACT_MANAGED_NEW[@]+"${ACT_MANAGED_NEW[@]}"}
echo "${CYAN}Managed — overwrite        : ${#ACT_MANAGED_OW[@]}${NC}"
print_list "M" ${ACT_MANAGED_OW[@]+"${ACT_MANAGED_OW[@]}"}
echo "${GREEN}Managed — unchanged        : ${#ACT_MANAGED_SAME[@]}${NC}"
echo
echo "${CYAN}Seed — install (missing)   : ${#ACT_SEED_INSTALL[@]}${NC}"
print_list "+" ${ACT_SEED_INSTALL[@]+"${ACT_SEED_INSTALL[@]}"}
echo "${GREEN}Seed — skip (exists)       : ${#ACT_SEED_SKIP[@]}${NC}"
echo
echo "${YELLOW}Deprecated — delete        : ${#ACT_DEPRECATED_DEL[@]}${NC}"
print_list "-" ${ACT_DEPRECATED_DEL[@]+"${ACT_DEPRECATED_DEL[@]}"}
echo "${GREEN}Deprecated — already gone  : ${#ACT_DEPRECATED_GONE[@]}${NC}"
echo

if [ ${#ACT_UNKNOWN[@]} -gt 0 ]; then
  echo "${YELLOW}Unclassified template files (coverage gap — update .harness-manifest):${NC}"
  print_list "?" "${ACT_UNKNOWN[@]}"
  echo
fi

if ! $APPLY; then
  echo "${YELLOW}DRY-RUN complete. Nothing was changed.${NC}"
  echo "${YELLOW}Review the lists above, then re-run with:  bash scripts/upgrade-harness.sh --apply${NC}"
else
  echo "${GREEN}✓ Upgrade applied.${NC}"
fi
