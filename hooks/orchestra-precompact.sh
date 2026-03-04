#!/usr/bin/env bash
# orchestra-precompact.sh
#
# PreCompact hook for Orchestra.
# Before context compaction, captures critical Orchestra state and injects
# it as additional context so it survives the compaction. This ensures
# agents don't lose track of their inbox, active tasks, or team identity
# after auto-compaction.
#
# Configuration:
#   Event: PreCompact
#   Matcher: (none — fires on both manual and auto compaction)
#
# Input (stdin): JSON with trigger (manual|auto), cwd
# Output (stdout): text added as context for Claude to see

set -euo pipefail

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd')

# Derive project name from directory
PROJECT_NAME=$(basename "$CWD")

# Build a compact summary of Orchestra state to preserve through compaction
CONTEXT=""

# 1. Check for unread inbox messages
INBOX_FILE="$HOME/.claude/teams/orchestra/inboxes/${PROJECT_NAME}.json"
if [ -f "$INBOX_FILE" ]; then
  UNREAD_COUNT=$(jq '[.[] | select(.read == false)] | length' "$INBOX_FILE" 2>/dev/null || echo "0")
  TOTAL_COUNT=$(jq 'length' "$INBOX_FILE" 2>/dev/null || echo "0")
  if [ "$UNREAD_COUNT" -gt 0 ]; then
    RECENT=$(jq -r '[.[] | select(.read == false)] | last | "From \(.from): \(.text)"' "$INBOX_FILE" 2>/dev/null || echo "")
    CONTEXT="${CONTEXT}[Orchestra] Inbox: ${UNREAD_COUNT} unread of ${TOTAL_COUNT} total. Most recent: ${RECENT}
"
  fi
fi

# 2. Check for active tasks assigned to this project
TASK_DIR="$HOME/.claude/tasks/orchestra"
if [ -d "$TASK_DIR" ]; then
  ACTIVE_TASKS=""
  for task_file in "$TASK_DIR"/*.json; do
    [ -f "$task_file" ] || continue
    OWNER=$(jq -r '.owner // ""' "$task_file" 2>/dev/null)
    STATUS=$(jq -r '.status // ""' "$task_file" 2>/dev/null)
    if [ "$OWNER" = "$PROJECT_NAME" ] && [ "$STATUS" != "completed" ]; then
      TASK_ID=$(jq -r '.id // ""' "$task_file" 2>/dev/null)
      TASK_SUBJECT=$(jq -r '.subject // ""' "$task_file" 2>/dev/null)
      ACTIVE_TASKS="${ACTIVE_TASKS}  #${TASK_ID}: ${TASK_SUBJECT} [${STATUS}]
"
    fi
  done

  if [ -n "$ACTIVE_TASKS" ]; then
    CONTEXT="${CONTEXT}[Orchestra] Your active tasks:
${ACTIVE_TASKS}"
  fi
fi

# 3. Include memory summary if it exists
SANITIZED=$(echo "$CWD" | sed 's/[/_]/-/g')
MEMORY_FILE="$HOME/.claude/projects/${SANITIZED}/memory/MEMORY.md"
if [ -f "$MEMORY_FILE" ]; then
  # Only include first 50 lines to keep it compact
  MEMORY_SUMMARY=$(head -50 "$MEMORY_FILE")
  CONTEXT="${CONTEXT}[Orchestra] Project memory summary:
${MEMORY_SUMMARY}
"
fi

# 4. Team identity reminder
CONTEXT="${CONTEXT}[Orchestra] You are the \"${PROJECT_NAME}\" agent in the Orchestra team. Your project directory is ${CWD}. Use /orchestra to check your full inbox and task list."

if [ -n "$CONTEXT" ]; then
  echo "$CONTEXT"
fi

exit 0
