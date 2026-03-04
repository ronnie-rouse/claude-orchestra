#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Orchestra Installer ==="
echo ""
echo "This will install the Orchestra skill and team configuration."
echo ""

# 1. Install SKILL.md
SKILL_DIR="$HOME/.claude/skills/orchestra"
mkdir -p "$SKILL_DIR"
cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"
echo "[OK] Installed SKILL.md -> $SKILL_DIR/SKILL.md"

# 2. Create team directories
TEAM_DIR="$HOME/.claude/teams/orchestra"
TASK_DIR="$HOME/.claude/tasks/orchestra"
INBOX_DIR="$TEAM_DIR/inboxes"
mkdir -p "$TEAM_DIR" "$TASK_DIR" "$INBOX_DIR"
echo "[OK] Created directories:"
echo "     $TEAM_DIR"
echo "     $TASK_DIR"
echo "     $INBOX_DIR"

# 3. Copy template configs (don't overwrite existing)
if [ ! -f "$TEAM_DIR/config.json" ]; then
  cp "$SCRIPT_DIR/templates/config.json" "$TEAM_DIR/config.json"
  echo "[OK] Installed config.json"
else
  echo "[--] config.json already exists, skipping"
fi

if [ ! -f "$TEAM_DIR/projects.json" ]; then
  cp "$SCRIPT_DIR/templates/projects.json" "$TEAM_DIR/projects.json"
  echo "[OK] Installed projects.json (edit this with your projects!)"
else
  echo "[--] projects.json already exists, skipping"
fi

if [ ! -f "$TEAM_DIR/settings.json" ]; then
  cp "$SCRIPT_DIR/templates/settings.json" "$TEAM_DIR/settings.json"
  echo "[OK] Installed settings.json"
else
  echo "[--] settings.json already exists, skipping"
fi

# 4. Install hook scripts
HOOKS_DIR="$HOME/.claude/hooks/orchestra"
mkdir -p "$HOOKS_DIR"
for hook_script in "$SCRIPT_DIR/hooks/"*.sh; do
  [ -f "$hook_script" ] || continue
  cp "$hook_script" "$HOOKS_DIR/"
  chmod +x "$HOOKS_DIR/$(basename "$hook_script")"
done
echo "[OK] Installed hook scripts -> $HOOKS_DIR/"
echo ""
echo "     To enable hooks, merge templates/hooks.json into your"
echo "     ~/.claude/settings.json (see README for details)."
echo ""

# 5. Initialize team-lead inbox
if [ ! -f "$INBOX_DIR/team-lead.json" ]; then
  echo "[]" > "$INBOX_DIR/team-lead.json"
  echo "[OK] Initialized team-lead inbox"
else
  echo "[--] team-lead.json already exists, skipping"
fi

# 6. Dashboard
echo ""
read -rp "Where should the dashboard HTML be copied? [$DEFAULT_DIR/orchestra-dashboard.html]: " DASH_PATH
DASH_PATH="${DASH_PATH:-$DEFAULT_DIR/orchestra-dashboard.html}"
DASH_DIR="$(dirname "$DASH_PATH")"

if [ -d "$DASH_DIR" ]; then
  cp "$SCRIPT_DIR/orchestra-dashboard.html" "$DASH_PATH"
  echo "[OK] Dashboard installed -> $DASH_PATH"

  # Save dashboard path to settings.json for the auto-refresh hook
  if [ -f "$TEAM_DIR/settings.json" ]; then
    jq --arg path "$DASH_PATH" '. + {dashboardPath: $path}' "$TEAM_DIR/settings.json" > "$TEAM_DIR/settings.json.tmp" \
      && mv "$TEAM_DIR/settings.json.tmp" "$TEAM_DIR/settings.json"
    echo "[OK] Saved dashboard path to settings.json"
  fi
else
  echo "[!!] Directory $DASH_DIR does not exist. Skipping dashboard copy."
  echo "     You can manually copy orchestra-dashboard.html later."
fi

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit $TEAM_DIR/projects.json with your actual projects"
echo "  2. Copy templates/CLAUDE.md into your workspace root (e.g. $DEFAULT_DIR/CLAUDE.md)"
echo "  3. Open a Claude Code session in your workspace and run: /orchestra"
echo ""
