#!/usr/bin/env bash
# orchestra-refresh-dashboard.sh
#
# Auto-refreshes the Orchestra dashboard HTML with current task, inbox,
# and member data. Can be used as a standalone script or as a hook.
#
# Hook configuration (recommended triggers):
#   Event: PostToolUse (matcher: "TaskUpdate|TaskCreate")
#   Event: SessionStart (matcher: "startup|resume")
#
# When run as a hook, reads JSON input from stdin (ignored — we read
# data directly from the filesystem).
#
# Requires: jq

set -euo pipefail

# Consume stdin if running as a hook (prevents broken pipe)
cat > /dev/null 2>/dev/null || true

TEAM_DIR="$HOME/.claude/teams/orchestra"
TASK_DIR="$HOME/.claude/tasks/orchestra"
INBOX_DIR="$TEAM_DIR/inboxes"
CONFIG="$TEAM_DIR/config.json"
SETTINGS="$TEAM_DIR/settings.json"

# Determine dashboard path from settings, argument, or fallback
DASHBOARD_PATH=""
if [ $# -gt 0 ]; then
  DASHBOARD_PATH="$1"
elif [ -f "$SETTINGS" ]; then
  DASHBOARD_PATH=$(jq -r '.dashboardPath // ""' "$SETTINGS" 2>/dev/null)
fi

# Fallback: look in common locations
if [ -z "$DASHBOARD_PATH" ] || [ ! -f "$DASHBOARD_PATH" ]; then
  for candidate in \
    "$HOME/Projects/orchestra-dashboard.html" \
    "$HOME/projects/orchestra-dashboard.html" \
    "$(dirname "$TEAM_DIR")/../orchestra-dashboard.html" \
  ; do
    if [ -f "$candidate" ]; then
      DASHBOARD_PATH="$candidate"
      break
    fi
  done
fi

if [ -z "$DASHBOARD_PATH" ] || [ ! -f "$DASHBOARD_PATH" ]; then
  # Dashboard not found — exit silently (don't block hooks)
  exit 0
fi

# --- Collect tasks ---
TASKS_JSON="[]"
if [ -d "$TASK_DIR" ]; then
  TASK_FILES=("$TASK_DIR"/*.json)
  if [ -f "${TASK_FILES[0]:-}" ]; then
    TASKS_JSON=$(jq -s '.' "$TASK_DIR"/*.json 2>/dev/null || echo "[]")
  fi
fi

# --- Collect inboxes ---
INBOXES_JSON="{}"
if [ -d "$INBOX_DIR" ]; then
  INBOXES_JSON="{"
  FIRST=true
  for inbox_file in "$INBOX_DIR"/*.json; do
    [ -f "$inbox_file" ] || continue
    INBOX_NAME=$(basename "$inbox_file" .json)
    INBOX_CONTENT=$(cat "$inbox_file" 2>/dev/null || echo "[]")
    if [ "$FIRST" = true ]; then
      FIRST=false
    else
      INBOXES_JSON="$INBOXES_JSON,"
    fi
    INBOXES_JSON="$INBOXES_JSON\"$INBOX_NAME\":$INBOX_CONTENT"
  done
  INBOXES_JSON="$INBOXES_JSON}"
fi

# --- Collect members ---
MEMBERS_JSON="[]"
if [ -f "$CONFIG" ]; then
  MEMBERS_JSON=$(jq '.members // []' "$CONFIG" 2>/dev/null || echo "[]")
fi

# --- Assemble ORCHESTRA_DATA ---
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ORCHESTRA_DATA=$(jq -n \
  --arg ts "$TIMESTAMP" \
  --argjson tasks "$TASKS_JSON" \
  --argjson inboxes "$INBOXES_JSON" \
  --argjson members "$MEMBERS_JSON" \
  '{
    generatedAt: $ts,
    tasks: $tasks,
    inboxes: $inboxes,
    members: $members
  }')

# --- Inject into dashboard HTML ---
# Replace everything between the ORCHESTRA DATA markers
# Compact JSON to single line to avoid awk newline issues

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

ORCHESTRA_DATA_COMPACT=$(echo "$ORCHESTRA_DATA" | jq -c '.')

awk -v data="$ORCHESTRA_DATA_COMPACT" '
  /^\/\/ ========== ORCHESTRA DATA/ {
    print $0
    print "const ORCHESTRA_DATA = " data ";"
    skip = 1
    next
  }
  /^\/\/ ========== END ORCHESTRA DATA/ {
    skip = 0
    print $0
    next
  }
  !skip { print $0 }
' "$DASHBOARD_PATH" > "$TMPFILE"

mv "$TMPFILE" "$DASHBOARD_PATH"

exit 0
