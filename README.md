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

# Install hook scripts (optional but recommended)
mkdir -p ~/.claude/hooks/orchestra
cp hooks/*.sh ~/.claude/hooks/orchestra/
chmod +x ~/.claude/hooks/orchestra/*.sh

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

## Hooks

Orchestra includes optional [Claude Code hooks](https://code.claude.com/docs/en/hooks) that automate common coordination tasks. The installer copies hook scripts to `~/.claude/hooks/orchestra/`. To enable them, merge the hook configurations from `templates/hooks.json` into your `~/.claude/settings.json`.

### Available Hooks

| Hook | Event | What It Does |
|------|-------|-------------|
| `orchestra-inbox-context.sh` | `SessionStart` | Auto-reads your inbox on session start and injects unread messages and active tasks as context |
| `orchestra-task-gate.sh` | `TaskCompleted` | Validates tests pass before allowing a task to be marked as completed |
| `orchestra-memory-inject.sh` | `SubagentStart` | Auto-injects project memory files as context when subagents spawn |
| `orchestra-memory-save.sh` | `Stop` | Reminds agents to save learnings to memory after substantive work sessions |
| `orchestra-idle-tracker.sh` | `TeammateIdle` | Writes status to inbox when agents go idle and notifies the team lead |
| `orchestra-precompact.sh` | `PreCompact` | Preserves Orchestra state (inbox, tasks, memory, team identity) through context compaction |

### Enabling Hooks

After installing, add the hook configurations to your `~/.claude/settings.json`. You can enable all hooks or pick the ones you want:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/orchestra/orchestra-inbox-context.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/orchestra/orchestra-task-gate.sh",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

See `templates/hooks.json` for the full configuration with all 6 hooks.

### Hook Details

**SessionStart — Inbox Context** reads your Orchestra inbox when a session starts or resumes. If you have unread messages, they appear as context so Claude immediately knows about pending tasks and messages. Also surfaces any active tasks assigned to your project.

**TaskCompleted — Quality Gate** runs before a task can be marked as completed. For JavaScript projects, it checks that `npm test` passes. For Ruby/Rails projects, it checks `bin/rails test` or `rspec`. Warns about uncommitted git changes. Only applies to Orchestra team tasks.

**SubagentStart — Memory Injection** automatically loads the project's Claude Code memory files (`~/.claude/projects/.../memory/MEMORY.md` and linked files) as context when any subagent spawns. Agents get knowledge from previous sessions without needing it in their prompt template.

**Stop — Memory Save** checks whether Claude completed substantive work (implemented, fixed, refactored, etc.) and hasn't mentioned saving to memory. If so, it blocks the stop and reminds the agent to save learnings. Won't trigger on short responses or repeat itself.

**TeammateIdle — Activity Tracking** writes a status message to the teammate's inbox and notifies the team lead when an Orchestra agent goes idle. This gives cross-session visibility into agent activity via the inbox files.

**PreCompact — Context Preservation** runs before context compaction and outputs a summary of Orchestra state: unread inbox messages, active tasks, project memory highlights, and team identity. This ensures agents don't lose their coordination context when the conversation window is compressed.

## Team Files

| Path | Purpose |
|------|---------|
| `~/.claude/teams/orchestra/config.json` | Team config (members list) |
| `~/.claude/teams/orchestra/projects.json` | Project registry |
| `~/.claude/teams/orchestra/settings.json` | Storage settings |
| `~/.claude/teams/orchestra/inboxes/*.json` | Per-project message inboxes |
| `~/.claude/tasks/orchestra/*.json` | Task files (one per task) |
| `~/.claude/hooks/orchestra/*.sh` | Hook scripts (optional) |

## Dashboard

Orchestra includes a static HTML dashboard that visualizes tasks, messages, and team members. Run `/orchestra refresh-dashboard` to update it with current data, then open the HTML file in a browser.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with Teams support
- Claude Code skills enabled (the `~/.claude/skills/` directory)
- `jq` for hook scripts (most systems have it; install via `brew install jq` or `apt install jq`)

## License

MIT
