#!/usr/bin/env bash
# orchestra-inbox-context.sh
#
# SessionStart hook for Orchestra.
# Reads the current project's Orchestra inbox and injects unread messages
# as additional context so Claude starts the session aware of pending
# tasks and messages.
#
# Configuration:
#   Event: SessionStart
#   Matcher: "startup|resume"
#
# Input (stdin): JSON with session info including "cwd"
# Output (stdout): JSON with additionalContext if unread messages exist

set -euo pipefail

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd')

# Derive project name from the last path component
PROJECT_NAME=$(basename "$CWD")

# If CWD is the parent workspace directory, this is the team lead
INBOX_FILE="$HOME/.claude/teams/orchestra/inboxes/${PROJECT_NAME}.json"

if [ ! -f "$INBOX_FILE" ]; then
  exit 0
fi

# Count unread messages
UNREAD_COUNT=$(jq '[.[] | select(.read == false)] | length' "$INBOX_FILE" 2>/dev/null || echo "0")

if [ "$UNREAD_COUNT" -eq 0 ]; then
  exit 0
fi

# Build context string with unread messages
UNREAD_MESSAGES=$(jq -r '[.[] | select(.read == false)] | .[] | "  From: \(.from) [\(.timestamp)]\n  \(.text)\n"' "$INBOX_FILE" 2>/dev/null)

CONTEXT="[Orchestra] You have ${UNREAD_COUNT} unread message(s) in your inbox (${INBOX_FILE}):

${UNREAD_MESSAGES}
Use /orchestra inbox to view all messages and mark them as read."

# Also check for assigned tasks
TASK_DIR="$HOME/.claude/tasks/orchestra"
if [ -d "$TASK_DIR" ]; then
  TASK_CONTEXT=""
  for task_file in "$TASK_DIR"/*.json; do
    [ -f "$task_file" ] || continue
    OWNER=$(jq -r '.owner // ""' "$task_file" 2>/dev/null)
    STATUS=$(jq -r '.status // ""' "$task_file" 2>/dev/null)
    if [ "$OWNER" = "$PROJECT_NAME" ] && [ "$STATUS" != "completed" ]; then
      TASK_ID=$(jq -r '.id // ""' "$task_file" 2>/dev/null)
      TASK_SUBJECT=$(jq -r '.subject // ""' "$task_file" 2>/dev/null)
      TASK_CONTEXT="${TASK_CONTEXT}  #${TASK_ID}: ${TASK_SUBJECT} [${STATUS}]\n"
    fi
  done

  if [ -n "$TASK_CONTEXT" ]; then
    CONTEXT="${CONTEXT}

[Orchestra] Your active tasks:
${TASK_CONTEXT}"
  fi
fi

jq -n --arg ctx "$CONTEXT" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
