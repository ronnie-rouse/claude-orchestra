# Orchestra

Multi-project coordination for [Claude Code](https://code.claude.com). Spawn persistent agents across your projects, assign work via natural language, and track progress through a shared task board and inbox system.

Orchestra is a Claude Code **skill** — a `SKILL.md` file that teaches Claude how to coordinate work across multiple independent projects in your workspace.

## How It Works

Orchestra runs in two modes:

**Live Mode** — Spawn persistent agents that stay alive and receive work in real time. Each agent bootstraps its project (reads `CLAUDE.md`, checks git status, loads project memory from previous sessions) and waits for tasks. You talk to the team lead; it delegates to agents via `SendMessage`.

**Manual Mode** — Lightweight polling via JSON inbox files. Works across sessions since inbox files persist after agents die. Check your inbox, mark tasks done, and the team lead picks up the results next session.

Both modes are interoperable — live agents write to the same inbox files that manual mode reads.

**Task management** uses Claude Code's native TaskCreate/TaskUpdate/TaskList/TaskGet tools. Orchestra adds cross-session persistence via inbox files and a visual HTML dashboard.

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
| `orchestra-refresh-dashboard.sh` | `SessionStart`, `PostToolUse` | Auto-refreshes the dashboard HTML when the session starts and after every task change (TaskCreate/TaskUpdate) |
| `orchestra-task-gate.sh` | `TaskCompleted` | Validates tests pass before allowing a task to be marked as completed |
| `orchestra-memory-inject.sh` | `SubagentStart` | Auto-injects project memory files as context when subagents spawn |
| `orchestra-memory-save.sh` | `Stop` | Reminds agents to save learnings to memory after substantive work sessions |
| `orchestra-idle-tracker.sh` | `TeammateIdle` | Writes status to inbox when agents go idle and notifies the team lead |
| `orchestra-precompact.sh` | `PreCompact` | Preserves Orchestra state (inbox, tasks, memory, team identity) through context compaction |
| `orchestra-spawn-cleanup.sh` | (called by `/orchestra spawn`) | Removes stale members from config.json and consolidates numbered inbox variants before agent creation |

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
          },
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/orchestra/orchestra-refresh-dashboard.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "TaskUpdate|TaskCreate",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/orchestra/orchestra-refresh-dashboard.sh",
            "timeout": 10,
            "async": true
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

See `templates/hooks.json` for the full configuration with all 8 hooks.

### Hook Details

**SessionStart — Inbox Context** reads your Orchestra inbox when a session starts or resumes. If you have unread messages, they appear as context so Claude immediately knows about pending tasks and messages. Also surfaces any active tasks assigned to your project.

**SessionStart + PostToolUse — Dashboard Refresh** automatically regenerates the dashboard HTML when a session starts and after every task mutation (TaskCreate, TaskUpdate). The PostToolUse hook runs asynchronously to avoid slowing down task operations. The dashboard path is read from `~/.claude/teams/orchestra/settings.json` (`dashboardPath` key).

**TaskCompleted — Quality Gate** runs before a task can be marked as completed. For JavaScript projects, it checks that `npm test` passes. For Ruby/Rails projects, it checks `bin/rails test` or `rspec`. Warns about uncommitted git changes. Only applies to Orchestra team tasks.

**SubagentStart — Memory Injection** automatically loads the project's Claude Code memory files (`~/.claude/projects/.../memory/MEMORY.md` and linked files) as context when any subagent spawns. Agents get knowledge from previous sessions without needing it in their prompt template.

**Stop — Memory Save** checks whether Claude completed substantive work (implemented, fixed, refactored, etc.) and hasn't mentioned saving to memory. If so, it blocks the stop and reminds the agent to save learnings. Won't trigger on short responses or repeat itself.

**TeammateIdle — Activity Tracking** writes a status message to the teammate's inbox and notifies the team lead when an Orchestra agent goes idle. This gives cross-session visibility into agent activity via the inbox files.

**PreCompact — Context Preservation** runs before context compaction and outputs a summary of Orchestra state: unread inbox messages, active tasks, project memory highlights, and team identity. This ensures agents don't lose their coordination context when the conversation window is compressed.

**Spawn Cleanup** (not a hook event — called directly by `/orchestra spawn`) removes stale members from config.json and consolidates numbered inbox variants into canonical files. This prevents agent name collisions and inbox fragmentation across sessions.

## Team Files

| Path | Purpose |
|------|---------|
| `~/.claude/teams/orchestra/config.json` | Team config (members list) |
| `~/.claude/teams/orchestra/projects.json` | Project registry |
| `~/.claude/teams/orchestra/settings.json` | Storage and dashboard settings |
| `~/.claude/teams/orchestra/inboxes/*.json` | Per-project message inboxes |
| `~/.claude/tasks/orchestra/*.json` | Task files (managed by native task tools) |
| `~/.claude/hooks/orchestra/*.sh` | Hook scripts (optional) |

## Dashboard

Orchestra includes a static HTML dashboard that visualizes tasks, messages, and team members.

If the `orchestra-refresh-dashboard.sh` hook is enabled, the dashboard auto-refreshes on every task change and session start. Otherwise, run `/orchestra refresh-dashboard` to update it manually, then open the HTML file in a browser.

The dashboard path is stored in `~/.claude/teams/orchestra/settings.json` under the `dashboardPath` key. The installer sets this automatically.

## Architecture

Orchestra bridges the gap between Claude Code's native agent teams (designed for single-session, single-project parallel work) and multi-session, multi-project coordination.

**What Orchestra adds on top of Claude Code:**
- **Project registry** — maps project names to paths for automated agent bootstrapping
- **Cross-session persistence** — inbox JSON files survive after agents die, enabling manual mode
- **Visual dashboard** — HTML overview of tasks and messages across all projects
- **Quality hooks** — pre-built scripts for test gates, memory management, context preservation
- **Spawn automation** — one command to bootstrap agents across all registered projects

**What Orchestra delegates to Claude Code:**
- **Task management** — uses native TaskCreate/TaskUpdate/TaskList/TaskGet tools
- **Agent communication** — uses native SendMessage for real-time messaging
- **Team membership** — uses native config.json for member tracking
- **Agent lifecycle** — uses native Task tool for spawning, idle/shutdown for lifecycle

## Requirements

- [Claude Code](https://code.claude.com) with Teams support (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)
- Claude Code skills enabled (the `~/.claude/skills/` directory)
- `jq` for hook scripts (most systems have it; install via `brew install jq` or `apt install jq`)

## License

MIT
