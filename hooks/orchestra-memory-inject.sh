#!/usr/bin/env bash
# orchestra-memory-inject.sh
#
# SubagentStart hook for Orchestra.
# When a subagent is spawned, automatically injects the project's Claude Code
# memory files as additional context. This gives agents knowledge from previous
# sessions without requiring it in the prompt template.
#
# Configuration:
#   Event: SubagentStart
#   Matcher: (none — fires for all subagents)
#
# Input (stdin): JSON with agent_id, agent_type, cwd
# Output (stdout): JSON with additionalContext containing memory content

set -euo pipefail

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd')

# Derive the Claude Code memory directory path
# Convention: replace / and _ with - in the absolute path
SANITIZED=$(echo "$CWD" | sed 's/[/_]/-/g')
MEMORY_DIR="$HOME/.claude/projects/${SANITIZED}/memory"
MEMORY_FILE="$MEMORY_DIR/MEMORY.md"

if [ ! -f "$MEMORY_FILE" ]; then
  exit 0
fi

# Read the main MEMORY.md
MEMORY_CONTENT=$(cat "$MEMORY_FILE")

if [ -z "$MEMORY_CONTENT" ]; then
  exit 0
fi

# Also read any linked files referenced in MEMORY.md
# Look for markdown links like [name](filename.md)
LINKED_CONTENT=""
while IFS= read -r linked_file; do
  LINKED_PATH="$MEMORY_DIR/$linked_file"
  if [ -f "$LINKED_PATH" ]; then
    FILE_CONTENT=$(cat "$LINKED_PATH")
    LINKED_CONTENT="${LINKED_CONTENT}

--- ${linked_file} ---
${FILE_CONTENT}"
  fi
done < <(grep -oP '\[.*?\]\((\K[^)]+\.md)' "$MEMORY_FILE" 2>/dev/null || true)

CONTEXT="[Orchestra] Project memory from previous sessions:

${MEMORY_CONTENT}${LINKED_CONTENT}"

jq -n --arg ctx "$CONTEXT" '{
  hookSpecificOutput: {
    hookEventName: "SubagentStart",
    additionalContext: $ctx
  }
}'
