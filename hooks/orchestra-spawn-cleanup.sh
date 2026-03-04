#!/usr/bin/env bash
# orchestra-spawn-cleanup.sh
#
# Pre-spawn cleanup for Orchestra agents.
# Removes stale members from config.json and consolidates numbered inbox
# variants into canonical files. Run this before spawning agents to prevent
# name collisions (e.g., "fizzy-2") and inbox fragmentation.
#
# Usage:
#   orchestra-spawn-cleanup.sh [project-name ...]
#   orchestra-spawn-cleanup.sh all
#
# If "all" is passed or no arguments given, cleans up all projects in the
# project registry. Otherwise, only cleans the named projects.
#
# Requires: jq

set -euo pipefail

TEAM_DIR="$HOME/.claude/teams/orchestra"
CONFIG="$TEAM_DIR/config.json"
PROJECTS_FILE="$TEAM_DIR/projects.json"
INBOX_DIR="$TEAM_DIR/inboxes"

# Validate dependencies
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed." >&2
  exit 1
fi

if [ ! -f "$CONFIG" ]; then
  echo "Error: $CONFIG not found. Is Orchestra installed?" >&2
  exit 1
fi

if [ ! -f "$PROJECTS_FILE" ]; then
  echo "Error: $PROJECTS_FILE not found." >&2
  exit 1
fi

# Determine which projects to clean up
if [ $# -eq 0 ] || [ "$1" = "all" ]; then
  # Get all project names from registry
  PROJECT_NAMES=$(jq -r '.projects[].name' "$PROJECTS_FILE")
else
  PROJECT_NAMES="$*"
fi

# --- Step 1: Remove stale members from config.json ---
# For each project, remove ALL members whose name starts with the project name
# (catches "fizzy", "fizzy-2", "fizzy-3", etc.)

FILTER='.'
for name in $PROJECT_NAMES; do
  # Build a jq filter that removes members matching this project name pattern
  FILTER="$FILTER | .members = [.members[] | select(.name | test(\"^${name}(-[0-9]+)?$\") | not)]"
done

# Apply the filter
jq "$FILTER" "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"

CLEANED_COUNT=0
for name in $PROJECT_NAMES; do
  CLEANED_COUNT=$((CLEANED_COUNT + 1))
done
echo "Cleaned stale members for $CLEANED_COUNT project(s) from config.json"

# --- Step 2: Consolidate numbered inbox variants ---
# For each project, merge any numbered variants (e.g., my-project-2.json)
# into the canonical inbox file (my-project.json) and delete the variants.

for name in $PROJECT_NAMES; do
  CANONICAL="$INBOX_DIR/${name}.json"

  # Ensure canonical inbox exists
  if [ ! -f "$CANONICAL" ]; then
    echo "[]" > "$CANONICAL"
  fi

  # Find numbered variants
  VARIANTS=()
  for variant in "$INBOX_DIR/${name}"-[0-9]*.json; do
    [ -f "$variant" ] || continue
    VARIANTS+=("$variant")
  done

  if [ ${#VARIANTS[@]} -gt 0 ]; then
    # Merge all variants into canonical
    for variant in "${VARIANTS[@]}"; do
      # Concatenate the arrays
      jq -s '.[0] + .[1]' "$CANONICAL" "$variant" > "${CANONICAL}.tmp" \
        && mv "${CANONICAL}.tmp" "$CANONICAL"
      rm "$variant"
    done
    echo "Consolidated ${#VARIANTS[@]} inbox variant(s) for $name"
  fi
done

echo "Spawn cleanup complete."
