#!/usr/bin/env bash
# orchestra-memory-save.sh
#
# Stop hook for Orchestra.
# When Claude finishes responding, checks whether the session involved
# substantive work and reminds the agent to save learnings to project
# memory if it hasn't already. Uses a simple heuristic: if the last
# message doesn't mention "memory" or "MEMORY.md", and the session
# has been active (not just starting up), it blocks the stop and asks
# Claude to consider saving.
#
# Configuration:
#   Event: Stop
#   Matcher: (none — fires every time Claude stops)
#
# Input (stdin): JSON with stop_hook_active, last_assistant_message, cwd
# Output (stdout): JSON with decision "block" + reason to continue, or exit 0 to allow

set -euo pipefail

INPUT=$(cat)

# Don't create infinite loops — if we already triggered a stop hook, let it go
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active')
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd')
LAST_MESSAGE=$(echo "$INPUT" | jq -r '.last_assistant_message // ""')

# Derive memory directory to check if it exists
SANITIZED=$(echo "$CWD" | sed 's/[/_]/-/g')
MEMORY_DIR="$HOME/.claude/projects/${SANITIZED}/memory"

# If there's no memory directory, the project hasn't opted into memory
if [ ! -d "$MEMORY_DIR" ]; then
  exit 0
fi

# Check if the last message already mentions saving to memory
if echo "$LAST_MESSAGE" | grep -qiE 'memory|MEMORY\.md|saved.*learn|wrote.*memory'; then
  exit 0
fi

# Check if this was a substantive session by looking at message length
# Short responses (< 200 chars) are likely just acknowledgments or status updates
MSG_LENGTH=${#LAST_MESSAGE}
if [ "$MSG_LENGTH" -lt 200 ]; then
  exit 0
fi

# Check if the message mentions completing significant work
if echo "$LAST_MESSAGE" | grep -qiE 'implemented|fixed|refactored|redesigned|added|created|updated|resolved|migrated'; then
  jq -n '{
    decision: "block",
    reason: "Before finishing, consider whether you discovered any stable patterns, key decisions, debugging insights, or conventions during this session worth saving to your project memory files. If so, update your MEMORY.md. If nothing worth saving, you can stop."
  }'
  exit 0
fi

# No significant work detected, allow stop
exit 0
