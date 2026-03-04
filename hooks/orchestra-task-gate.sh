#!/usr/bin/env bash
# orchestra-task-gate.sh
#
# TaskCompleted hook for Orchestra.
# Validates that basic quality checks pass before allowing a task to be
# marked as completed. Checks for uncommitted changes and optionally runs
# the project's test suite.
#
# Configuration:
#   Event: TaskCompleted
#   Matcher: (none — fires on every task completion)
#
# Input (stdin): JSON with task_id, task_subject, teammate_name, team_name, cwd
# Output: exit 0 to allow, exit 2 with stderr message to block

set -euo pipefail

INPUT=$(cat)
TEAM=$(echo "$INPUT" | jq -r '.team_name // ""')

# Only apply to Orchestra team tasks
if [ "$TEAM" != "orchestra" ]; then
  exit 0
fi

TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd')

# Check for uncommitted changes in git repos
if [ -d "$CWD/.git" ]; then
  DIRTY=$(cd "$CWD" && git status --porcelain 2>/dev/null | head -5)
  if [ -n "$DIRTY" ]; then
    echo "Warning: uncommitted changes detected in $CWD while completing: $TASK_SUBJECT" >&2
    # This is a warning, not a blocker — don't exit 2
  fi
fi

# Run tests if a known test runner config exists
if [ -f "$CWD/package.json" ]; then
  # Check if a test script is defined
  HAS_TEST=$(cd "$CWD" && jq -r '.scripts.test // ""' package.json 2>/dev/null)
  if [ -n "$HAS_TEST" ] && [ "$HAS_TEST" != "null" ] && [ "$HAS_TEST" != 'echo "Error: no test specified" && exit 1' ]; then
    if ! (cd "$CWD" && npm test --silent 2>&1); then
      echo "Tests failing in $CWD. Fix tests before completing: $TASK_SUBJECT" >&2
      exit 2
    fi
  fi
elif [ -f "$CWD/Gemfile" ]; then
  # Rails/Ruby project — check if tests exist
  if [ -d "$CWD/test" ] || [ -d "$CWD/spec" ]; then
    if [ -f "$CWD/bin/rails" ]; then
      if ! (cd "$CWD" && bin/rails test --silent 2>&1); then
        echo "Tests failing in $CWD. Fix tests before completing: $TASK_SUBJECT" >&2
        exit 2
      fi
    elif command -v rspec &>/dev/null && [ -d "$CWD/spec" ]; then
      if ! (cd "$CWD" && rspec --format progress 2>&1); then
        echo "Tests failing in $CWD. Fix tests before completing: $TASK_SUBJECT" >&2
        exit 2
      fi
    fi
  fi
fi

exit 0
