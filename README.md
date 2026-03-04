# Orchestra

Multi-project coordination for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Spawn persistent agents across your projects, assign work via natural language, and track progress through a shared task board and inbox system.

Orchestra is a Claude Code **skill** — a `SKILL.md` file that teaches Claude how to coordinate work across multiple independent projects in your workspace.

## How It Works

Orchestra runs in two modes:

**Live Mode** — Spawn persistent agents that stay alive and receive work in real time. Each agent bootstraps its project (reads `CLAUDE.md`, checks git status, loads project memory from previous sessions) and waits for tasks. You talk to the team lead; it delegates to agents via `SendMessage`.

**Manual Mode** — Lightweight polling via JSON inbox files. Works across sessions since inbox files persist after agents die. Check your inbox, mark tasks done, and the team lead picks up the results next session.

Both modes are interoperable — live agents write to the same inbox files that manual mode reads.

## Install

### Quick (script)

```bash
git clone https://github.com/ronnie-rouse/claude-orchestra.git
cd claude-orchestra
chmod +x install.sh
./install.sh
```

### Manual

```bash
# Copy the skill
mkdir -p ~/.claude/skills/orchestra
cp SKILL.md ~/.claude/skills/orchestra/SKILL.md

# Create team directories
mkdir -p ~/.claude/teams/orchestra/inboxes
mkdir -p ~/.claude/tasks/orchestra

# Copy template configs
cp templates/config.json ~/.claude/teams/orchestra/config.json
cp templates/projects.json ~/.claude/teams/orchestra/projects.json
cp templates/settings.json ~/.claude/teams/orchestra/settings.json

# Initialize team-lead inbox
echo '[]' > ~/.claude/teams/orchestra/inboxes/team-lead.json

# Copy dashboard to parent directory (optional)
cp orchestra-dashboard.html ../orchestra-dashboard.html
```

## Configure

Edit `~/.claude/teams/orchestra/projects.json` to register your projects:

```json
{
  "projects": [
    { "name": "my-app", "path": "/path/to/my-app", "description": "Main web application" },
    { "name": "my-api", "path": "/path/to/my-api", "description": "Backend API service" }
  ]
}
```

Each project needs:
- **name** — identifier used for agent naming and inbox routing
- **path** — absolute path to the project directory
- **description** — brief description (agents see this on bootstrap)

Optionally, copy `templates/CLAUDE.md` into your workspace root to document the Orchestra commands for every session.

## Usage

Open a Claude Code session in your parent workspace directory and use these commands:

### Live Mode

```
/orchestra spawn                  # spawn all registered projects
/orchestra spawn my-app my-api    # spawn specific projects
```

Then assign work via natural language:

```
Tell my-app to fix the login bug
Send my-api: "Add pagination to the users endpoint"
```

Agents acknowledge tasks, do the work, run tests, and report back.

```
/orchestra shutdown               # gracefully stop all agents
/orchestra who                    # list registered team members
```

### Manual Mode

```
/orchestra                        # overview: tasks + recent inbox messages
/orchestra status                 # full task board across all projects
/orchestra inbox                  # read messages for current project
/orchestra done 3                 # mark task #3 completed
/orchestra refresh-dashboard      # regenerate the HTML dashboard
```

## Team Files

| Path | Purpose |
|------|---------|
| `~/.claude/teams/orchestra/config.json` | Team config (members list) |
| `~/.claude/teams/orchestra/projects.json` | Project registry |
| `~/.claude/teams/orchestra/settings.json` | Storage settings |
| `~/.claude/teams/orchestra/inboxes/*.json` | Per-project message inboxes |
| `~/.claude/tasks/orchestra/*.json` | Task files (one per task) |

## Dashboard

Orchestra includes a static HTML dashboard that visualizes tasks, messages, and team members. Run `/orchestra refresh-dashboard` to update it with current data, then open the HTML file in a browser.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with Teams support
- Claude Code skills enabled (the `~/.claude/skills/` directory)

## License

MIT
