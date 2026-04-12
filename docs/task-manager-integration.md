# Task Manager Integration

## Why You Need This

The daily workflow skills (`/today`, `/tonight`, `/weekend`, `/recap`, `/dump`) are designed to pull live data from a task manager — tasks due today, calendar events, habits, deadlines. Without one connected, the skills still work but they'll rely on what you tell them rather than pulling your schedule automatically.

The grimoire itself (compile, query, status, lint) does **not** need a task manager. It's purely a knowledge base. The task manager integration is only for the daily workflow layer.

## How It Works

The skills use generic language like "pull tasks due today from your task manager" rather than calling specific tools. This means you can wire up any task manager that has an MCP server — the skills adapt to whatever tools are available.

When a skill says "use your task manager MCP tools", it means:
- Read tasks due today / this week
- Read calendar events
- Read habits
- Create new tasks
- Complete tasks
- Check upcoming deadlines and bills

Your AI assistant will map these operations to whatever MCP tools your task manager provides.

## Compatible Task Managers

Any task manager with MCP server support will work. Here are some known options:

| Task Manager | MCP Server | Notes |
|---|---|---|
| **TickTick** | [karbassi/mcp-ticktick](https://github.com/karbassi/mcp-ticktick) | Full featured — tasks, calendar, habits, focus timer. See [our worked example](examples/ticktick-setup.md). |
| **Todoist** | [abhiz123/todoist-mcp-server](https://github.com/abhiz123/todoist-mcp-server) | Tasks, projects, labels. No calendar integration. |
| **Linear** | [linear/linear-mcp](https://github.com/linear/linear-mcp) | Issue tracking focused. Good for dev-heavy workflows. |
| **Google Tasks** | Community MCP servers available | Basic task lists via Google API. |
| **Apple Reminders** | Community MCP servers available | macOS only. |

Don't see yours? If it has an API, someone's probably built an MCP server for it. Check the [MCP server registry](https://github.com/modelcontextprotocol/servers).

## Adapting the Skills

The daily workflow skills are written to be task-manager-agnostic. If your MCP server uses different tool names, you have two options:

### Option 1: Let the AI figure it out (recommended)

Most AI assistants will see your MCP tools and map "pull tasks due today" to the right tool call automatically. If your task manager MCP is registered and the tools are available, the skills should just work without modification.

### Option 2: Edit the skills to be explicit

If you want more control, edit the skill files in `.claude/skills/` to reference your specific MCP tools:

```markdown
# Before (generic):
Use your task manager MCP tools to pull tasks due today.

# After (TickTick-specific):
Call `mcp__ticktick__list_tasks` with status "active" to get today's tasks.
Call `mcp__ticktick__list_events` for today's calendar.
Call `mcp__ticktick__list_habits` for today's habits.
```

See the [TickTick worked example](examples/ticktick-setup.md) for exactly how we did this.

## What Each Skill Needs

| Skill | What it reads | What it writes |
|---|---|---|
| `/today` | Tasks due today, calendar events, habits | Creates tasks from user input |
| `/tonight` | Tasks completed today, tasks still open | Completes tasks user reports as done |
| `/weekend` | Saturday + Sunday tasks/events, Monday deadlines | Nothing (read-only) |
| `/recap` | Week's completed tasks, next week's calendar, task backlog | Nothing (read-only) |
| `/dump` | Nothing | Creates tasks, logs habits |

## No Task Manager? No Problem

The skills degrade gracefully. Without a task manager:
- `/today` asks you what's on your plate instead of pulling it automatically
- `/tonight` asks what got done instead of checking completion status
- `/weekend` and `/recap` work from your verbal input
- `/dump` saves ideas to `inbox/drops/` but can't create tasks

The grimoire capture pipeline works regardless — your check-in outputs still land in `inbox/daily/` and get compiled into wiki articles.
