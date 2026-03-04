#!/usr/bin/env bash
# orchestra-idle-tracker.sh
#
# TeammateIdle hook for Orchestra.
# When an Orchestra teammate goes idle, writes a status update to its
# inbox file for cross-session persistence. This allows manual mode to
# see when agents last went idle and track their activity.
#
# Configuration:
#   Event: TeammateIdle
#   Matcher: (none — fires for all teammates)
#
# Input (stdin): JSON with teammate_name, team_name, cwd
# Output: exit 0 to allow idle, exit 2 with stderr to block (keep working)

set -euo pipefail

INPUT=$(cat)
TEAM=$(echo "$INPUT" | jq -r '.team_name // ""')
NAME=$(echo "$INPUT" | jq -r '.teammate_name // ""')

# Only track Orchestra team members
if [ "$TEAM" != "orchestra" ]; then
  exit 0
fi

# Don't track the team lead
if [ "$NAME" = "team-lead" ]; then
  exit 0
fi

# Write idle status to the teammate's inbox
INBOX="$HOME/.claude/teams/orchestra/inboxes/${NAME}.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Create inbox if it doesn't exist
if [ ! -f "$INBOX" ]; then
  echo "[]" > "$INBOX"
fi

# Append idle status message
jq --arg ts "$TIMESTAMP" --arg name "$NAME" \
   '. += [{"from": "system", "text": "Agent went idle — standing by for tasks", "summary": "Agent idle", "timestamp": $ts, "read": true}]' \
   "$INBOX" > "${INBOX}.tmp" && mv "${INBOX}.tmp" "$INBOX"

# Also notify the team lead
LEAD_INBOX="$HOME/.claude/teams/orchestra/inboxes/team-lead.json"
if [ -f "$LEAD_INBOX" ]; then
  jq --arg ts "$TIMESTAMP" --arg name "$NAME" \
     '. += [{"from": $name, "text": "Agent went idle — standing by for tasks", "summary": "Agent idle", "timestamp": $ts, "read": false}]' \
     "$LEAD_INBOX" > "${LEAD_INBOX}.tmp" && mv "${LEAD_INBOX}.tmp" "$LEAD_INBOX"
fi

exit 0
