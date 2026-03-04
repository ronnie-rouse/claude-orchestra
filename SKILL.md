# /orchestra — Multi-Project Coordination

A global skill for reading and interacting with the Orchestra team coordination system.

> **Note:** Before using Orchestra, edit `~/.claude/teams/orchestra/projects.json` to register your own projects. See [templates/projects.json](templates/projects.json) for the format.

## Usage

- `/orchestra` — Show active tasks and inbox messages for the current project
- `/orchestra status` — Show all task statuses across projects
- `/orchestra inbox` — Show unread messages for the current project
- `/orchestra done <task-id>` — Mark a task as completed and notify the team lead
- `/orchestra refresh-dashboard` — Regenerate the orchestra-dashboard.html with current data
- `/orchestra spawn [project...]` — Spawn persistent project agents (Live Mode)
- `/orchestra shutdown` — Send shutdown requests to all live agents
- `/orchestra who` — Show registered team members

## How It Works

Orchestra uses Claude Code's built-in team and task system for coordination between independent project sessions. Tasks are managed through the native TaskCreate/TaskUpdate/TaskList/TaskGet tools. Cross-session persistence is provided by inbox JSON files at `~/.claude/teams/orchestra/inboxes/`.

**Two modes of operation:**

- **Live Mode**: `/orchestra spawn` creates persistent sub-agents that stay alive and receive work via `SendMessage`. Agents go idle between tasks (zero tokens) and wake when messaged.
- **Manual Mode**: `/orchestra status`, `/orchestra inbox`, `/orchestra done` for lightweight polling via inbox JSON files. Works across sessions — inbox files survive after agents die.

**Team files:**
- Team config: `~/.claude/teams/orchestra/config.json`
- Project registry: `~/.claude/teams/orchestra/projects.json`
- Inboxes: `~/.claude/teams/orchestra/inboxes/` (one JSON file per project)

**Inbox message format:**
```json
[
  {
    "from": "team-lead",
    "text": "Task #1 assigned: Implement entropy UI redesign",
    "summary": "New task assignment",
    "timestamp": "2026-02-23T10:00:00Z",
    "read": false
  }
]
```

## Instructions

When the user invokes `/orchestra`, follow these steps:

### Determine the current project name

Derive the project name from the current working directory. For example, if the cwd is `~/Projects/my-app`, the project name is `my-app`. If the cwd is the parent workspace directory (e.g. `~/Projects`), the project name is `team-lead`.

### `/orchestra` (default — overview)

1. Read the project's inbox file: `~/.claude/teams/orchestra/inboxes/{project-name}.json`
2. Use the **TaskList** tool to get all current tasks.

**Then display a summary:**
   - **Inbox**: Count of unread messages, show the most recent 3
   - **Your Tasks**: Tasks where `owner` matches the project name, grouped by status
   - **All Tasks**: Brief summary of all tasks by status (pending/in_progress/completed)

### `/orchestra status`

1. Use the **TaskList** tool to get all current tasks.
2. For each task that needs more detail, use **TaskGet** to read full descriptions.
3. List and read all inbox files in `~/.claude/teams/orchestra/inboxes/`

**Then display:**
   - **Tasks Board**: All tasks grouped by status (Pending | In Progress | Completed)
   - **Project Activity**: For each project, show task count, unread messages, last activity timestamp

### `/orchestra inbox`

1. Read the project's inbox file: `~/.claude/teams/orchestra/inboxes/{project-name}.json`
2. Display all messages, newest first
3. Mark all messages as `"read": true` by editing the inbox file

### `/orchestra done <task-id>`

1. Use **TaskGet** to read the task by ID.
2. Use **TaskUpdate** to set the task status to `"completed"`.
3. Write a completion message to the team-lead inbox (`~/.claude/teams/orchestra/inboxes/team-lead.json`):
   ```json
   {
     "from": "{project-name}",
     "text": "Task #{task-id} completed: {subject}",
     "summary": "Task completed",
     "timestamp": "{current ISO timestamp}",
     "read": false
   }
   ```
4. Confirm to the user that the task was marked done and the team lead was notified.

### `/orchestra refresh-dashboard`

1. Use the **TaskList** tool and **TaskGet** for each task to collect all task data.
2. Read all inbox files from `~/.claude/teams/orchestra/inboxes/`
3. Read the team config from `~/.claude/teams/orchestra/config.json`
4. Read the dashboard template (the `orchestra-dashboard.html` file — configure its path in your workspace)
5. Replace the `ORCHESTRA_DATA` JavaScript object in the HTML with current data:
   - `tasks`: array of all task objects
   - `inboxes`: object mapping project name to array of messages
   - `members`: array from config.json `members` field
   - `generatedAt`: current ISO timestamp
6. Write the updated HTML back to the dashboard file
7. Tell the user: "Dashboard refreshed. Open orchestra-dashboard.html in a browser."

**Note:** If the `orchestra-refresh-dashboard.sh` hook is enabled, the dashboard auto-refreshes on every task change and session start. Manual refresh is only needed if hooks are not installed.

### `/orchestra spawn [project...]`

Spawns persistent project agents that join the "orchestra" team and stay alive to receive work.

1. Read the project registry: `~/.claude/teams/orchestra/projects.json`
2. If specific project names are given (e.g., `/orchestra spawn fizzy prism`), filter the list to only those projects. If no names given, spawn all projects in the registry.
3. **Run pre-spawn cleanup:** Execute `~/.claude/hooks/orchestra/orchestra-spawn-cleanup.sh` with the project names as arguments (or `all` if spawning all). This removes stale members from config.json and consolidates numbered inbox variants. Example:
   ```
   Bash: ~/.claude/hooks/orchestra/orchestra-spawn-cleanup.sh fizzy prism
   ```
   If the cleanup script doesn't exist, perform the cleanup manually:
   - Read `~/.claude/teams/orchestra/config.json` and remove ALL members whose `name` matches any project being spawned (including suffixed variants like `fizzy-2`, `fizzy-3`). Write the cleaned config back.
   - For each project, check for numbered inbox variants (e.g., `my-project-2.json`). If found, merge into the canonical file and delete variants.
4. **Derive memoryPath for each project:** Take the project's `path` from the registry, replace all `/` and `_` characters with `-`, then prepend `~/.claude/projects/` and append `/memory/`. This follows the Claude Code auto-memory directory convention. Example: `/path/to/my-app` becomes `~/.claude/projects/-path-to-my-app/memory/`. Pass `{memoryPath}` into the agent prompt template.
5. For each project, use the **Task tool** with these parameters:
   - `team_name`: `"orchestra"`
   - `name`: `"{project-name}"` (e.g., `"fizzy"` — must match the project name exactly)
   - `subagent_type`: `"general-purpose"`
   - `run_in_background`: `false`
   - `description`: `"Spawn {project-name} agent"`
   - `prompt`: Use the agent prompt template below, substituting `{name}`, `{path}`, `{description}`, and `{memoryPath}` from the project registry entry and step 4.

6. **Spawn agents in parallel** — make all Task calls in a single message for speed.
7. Wait for each agent to complete its bootstrap. They will send a "Ready" message via SendMessage.
8. **Verify names:** After spawn, read `config.json` and confirm each new agent's `name` matches the project name exactly (no suffix). If a suffix was added, warn the user that messaging may not route correctly.
9. Report to the user which agents are alive and ready.

**Agent prompt template:**

```
You are the "{name}" project agent in the Orchestra coordination team.

== YOUR PROJECT ==
Directory: {path}
Description: {description}

== BOOTSTRAP (do these immediately) ==
1. Read {path}/CLAUDE.md (and any files it references like @AGENTS.md)
2. Check for project skills: use Glob to look for {path}/.claude/skills/*/SKILL.md
3. Run: cd {path} && git status
4. Read project memory: Read {memoryPath}/MEMORY.md if it exists. If MEMORY.md references other files (e.g., [infrastructure.md](infrastructure.md)), read those too. This gives you context from previous sessions. If the memory directory doesn't exist, skip this step.

== MEMORY ==
Your project memory directory is: {memoryPath}
- On bootstrap, you read MEMORY.md for prior session context (done above)
- During work, if you discover stable patterns, key decisions, or solutions to recurring problems, save them to your memory files using Write/Edit
- Follow the same conventions as Claude Code auto-memory:
  - Keep MEMORY.md concise (under 200 lines) as an index
  - Create separate topic files for detailed notes and link from MEMORY.md
  - Only save stable, verified patterns — not session-specific state
  - Update or remove memories that become outdated

== WORKING RULES ==
- Always use absolute paths or prefix Bash commands with: cd {path} &&
- Only modify files within {path} — never touch other projects
- Follow conventions from your project's CLAUDE.md
- Run tests after changes (check CLAUDE.md for the test command)
- Never commit unless the team lead explicitly asks

== COMMUNICATION ==
- Acknowledge tasks via SendMessage to "team-lead"
- Report results via SendMessage to "team-lead" with a summary
- Update task status via TaskUpdate when starting/completing work
- Also write a status line to your inbox file for cross-session persistence:
  ~/.claude/teams/orchestra/inboxes/{name}.json

== CROSS-PROJECT NEEDS ==
If you need something from another project, message "team-lead" — never modify other projects directly.

Bootstrap now, then send a "Ready" message to team-lead.
```

### `/orchestra shutdown`

Sends shutdown requests to all live project agents and cleans up stale members.

1. Read the team config: `~/.claude/teams/orchestra/config.json`
2. Parse the `members` array
3. For each member whose `name` is NOT `"team-lead"`, send a shutdown request:
   ```
   SendMessage(type="shutdown_request", recipient="{member-name}", content="Orchestra session ending. Before shutting down: if you discovered any important patterns, architectural decisions, debugging insights, or conventions during this session, save them to your project memory files. Then shut down gracefully.")
   ```
4. **Clean up config:** After shutdown requests are sent, remove all non-team-lead members from the `members` array in `config.json` and write it back. Dead agents from previous sessions should not persist in the config.
5. Report to the user which agents were sent shutdown requests and that the config was cleaned up.

### `/orchestra who`

Shows registered team members.

1. Read the team config: `~/.claude/teams/orchestra/config.json`
2. Parse the `members` array
3. Display a table/list of members with:
   - **Name**: the member's `name`
   - **Type**: the member's `agentType`
   - **Joined**: format the `joinedAt` timestamp to a readable date
4. Note to the user: "Members in config doesn't guarantee they're alive — they may have been shut down. Use `/orchestra spawn` to start agents."

## Important Notes

- **Tasks use native tools.** Use TaskCreate/TaskUpdate/TaskList/TaskGet for all task operations. Do not read or write task JSON files directly.
- **Inboxes use JSON files.** Inbox files are the cross-session persistence layer. When appending a message, read the current array, push the new message, and write the full array back.
- Manual mode commands (`/orchestra`, `status`, `inbox`, `done`, `refresh-dashboard`) use the native task tools plus Read/Edit/Write for inbox files.
- Live mode commands (`spawn`, `shutdown`, `who`) use Task, SendMessage, Bash (for cleanup script), and Read tools.
- If any file doesn't exist yet, report it gracefully (e.g., "No inbox found — the orchestra team may not be initialized yet. Run the installer.")
- Agents spawned with `/orchestra spawn` will appear in `config.json` members. They go idle between turns (zero cost) and wake on `SendMessage`.
- The `/orchestra` manual mode can always pick up where live agents left off — inbox files persist across sessions.
- **Agent naming is critical for SendMessage routing.** The agent's `name` in `config.json` MUST match the project name exactly (e.g., `"fizzy"`, not `"fizzy-2"`). The pre-spawn cleanup ensures this. When sending messages to agents, always use the canonical project name as the recipient.
- **One inbox per project.** Each project uses a single canonical inbox file (e.g., `my-project.json`). Never create numbered variants like `my-project-2.json`. The spawn cleanup script consolidates any stale numbered variants into the canonical file.
- **Dashboard auto-refresh.** If the `orchestra-refresh-dashboard.sh` hook is enabled (via PostToolUse and SessionStart hooks), the dashboard updates automatically on every task change. The `/orchestra refresh-dashboard` command is a manual fallback.
