# Projects Workspace

This is the root workspace for all projects.

## Multi-Project Coordination

This workspace uses Claude Code Teams for cross-project coordination via the **Orchestra** system. Orchestra has two modes:

### Live Mode (Persistent Agents)

Spawn project agents that stay alive and receive work in real time:

```
/orchestra spawn my-app my-api    # spawn specific projects
/orchestra spawn                  # spawn all registered projects
```

Then assign work via natural language:
```
Tell my-app to fix the login bug
Send my-api: "Add support for pagination"
```

Under the hood, this uses `SendMessage` to wake the agent, which does the work and reports back.

| Command | Description |
|---------|-------------|
| `/orchestra spawn [project...]` | Spawn persistent project agents |
| `/orchestra shutdown` | Send shutdown requests to all live agents |
| `/orchestra who` | Show registered team members |

### Manual Mode (Polling)

Lightweight coordination via inbox JSON files. Works across sessions — inbox files survive after agents die.

| Command | Description |
|---------|-------------|
| `/orchestra` | Show active tasks and inbox messages |
| `/orchestra status` | Show all task statuses across projects |
| `/orchestra inbox` | Show unread messages for current project |
| `/orchestra done <id>` | Mark a task completed and notify team lead |
| `/orchestra refresh-dashboard` | Regenerate the visual dashboard |

### Team Files

- **Team config**: `~/.claude/teams/orchestra/config.json`
- **Project registry**: `~/.claude/teams/orchestra/projects.json`
- **Tasks**: `~/.claude/tasks/orchestra/*.json` (one file per task)
- **Inboxes**: `~/.claude/teams/orchestra/inboxes/{project-name}.json`
- **Team lead inbox**: `~/.claude/teams/orchestra/inboxes/team-lead.json`

### Workflow

**Live Mode**: Run `/orchestra spawn` to create persistent agents. Assign work by messaging them directly or through the team lead. Agents report back via `SendMessage` and also write to inbox files for persistence. Run `/orchestra shutdown` when done.

**Manual Mode**: On session start, check your inbox for assigned tasks. When completing work, update the task file and write a completion message to the team lead inbox. Use `/orchestra` to see current tasks and messages.

Both modes are interoperable — live agents write to the same inbox files that manual mode reads, so you can seamlessly switch between them.
