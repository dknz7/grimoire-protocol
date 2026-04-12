# Worked Example: TickTick Integration

This is how the Grimoire Protocol creator runs their daily workflow skills with [TickTick](https://ticktick.com) as the task manager. Use this as a reference for wiring up your own setup.

## Why TickTick?

TickTick covers everything the daily skills need in one app: tasks, calendar, habits, focus timer, and a bills/subscriptions list. One MCP server gives you the full picture. It also has solid mobile apps so you can manage tasks on the go and they'll be there when your AI checks in tomorrow morning.

## The MCP Server

We use [karbassi/mcp-ticktick](https://github.com/karbassi/mcp-ticktick) — a Python MCP server that connects via OAuth + a v2 session token. It exposes 45 tools covering the full TickTick API.

### Installation

```bash
# Clone the MCP server
git clone https://github.com/karbassi/mcp-ticktick.git

# It uses uv for Python package management
# No pip install needed — uv handles it at runtime
```

### Authentication

TickTick requires three credentials:

1. **OAuth tokens** — `TICKTICK_ACCESS_TOKEN`, `TICKTICK_CLIENT_ID`, `TICKTICK_CLIENT_SECRET`
2. **v2 session token** — `TICKTICK_V2_SESSION_TOKEN` (needed for calendar, habits, focus timer)

To get OAuth tokens, you'll need to register an app at [developer.ticktick.com](https://developer.ticktick.com) and go through the OAuth flow. The MCP server's README walks through this.

The v2 session token comes from your browser — log into TickTick web, open DevTools, find the `t` cookie value. This token expires periodically and needs refreshing.

### MCP Registration

Add to your global MCP config (wherever your other MCP servers live):

```json
"ticktick": {
  "type": "stdio",
  "command": "uv",
  "args": [
    "run",
    "--directory",
    "/path/to/mcp-ticktick",
    "mcp-ticktick"
  ],
  "env": {
    "TICKTICK_ACCESS_TOKEN": "your-access-token",
    "TICKTICK_CLIENT_ID": "your-client-id",
    "TICKTICK_CLIENT_SECRET": "your-client-secret",
    "TICKTICK_V2_SESSION_TOKEN": "your-session-token"
  }
}
```

On Windows, use the full path with double backslashes for the `--directory` arg.

### Tool Count

TickTick MCP registers **45 tools**. These cover:

- **Tasks:** list, create, edit, complete, delete, move, subtasks
- **Projects:** list, create, edit, delete (these are TickTick's "lists")
- **Calendar:** list events for a date range
- **Habits:** list, check-in, edit, archive
- **Focus:** start/stop timer, save sessions, view stats
- **Tags:** create, edit, merge, rename
- **Filters:** create and manage saved views

## How the Skills Use It

Here's how each daily workflow skill maps to TickTick tools:

### `/today` (morning check-in)

```
Pre-Query (silent, before asking the user anything):
  - mcp__ticktick__list_tasks → tasks due today across all lists
  - mcp__ticktick__list_events → calendar events for today
  - mcp__ticktick__list_habits → habits due today

After user input:
  - mcp__ticktick__add_task → create tasks from what the user reports
    Route to the right list based on project:
    - Work items → "HCF" list (or whatever your work list is called)
    - Personal → "Personal" list
    - Project-specific → that project's list
```

### `/tonight` (nightly check-in)

```
Pre-Query:
  - mcp__ticktick__list_tasks → tasks due today (check completed vs open)

After user input:
  - mcp__ticktick__complete_task → mark tasks as done that user reports completed
```

### `/weekend` (weekend planner)

```
Pre-Query:
  - mcp__ticktick__list_tasks → tasks due Saturday + Sunday
  - mcp__ticktick__list_events → weekend calendar events
  - mcp__ticktick__list_habits → weekend habits
  - mcp__ticktick__list_tasks → Monday tasks (for prep awareness)
```

### `/recap` (weekly review)

```
Pre-Query:
  - mcp__ticktick__list_tasks status="completed" → what got done this week
  - mcp__ticktick__list_events → next week's calendar
  - mcp__ticktick__list_tasks → task backlog by project
```

### `/dump` (quick capture)

```
After user input:
  - mcp__ticktick__add_task → actionable items become tasks
  - mcp__ticktick__checkin_habit → health/exercise items log as habit check-ins
  Ideas and notes go to inbox/drops/ (no TickTick involved)
```

## TickTick Project Organisation

We organise TickTick lists (called "projects" in the API) by life domain:

| TickTick List | What Goes Here |
|---|---|
| Personal | General life tasks, errands, admin |
| Work | 9-5 job tasks |
| Project A | Side project tasks |
| Project B | Another side project |
| Bills | Recurring bills and subscriptions (due dates matter) |
| Shopping | Shared shopping list |

The `/today` skill routes new tasks to the right list based on what domain the user mentions. If unclear, it defaults to Personal.

## Tips

- **Bills list is gold.** Having a dedicated bills list means `/tonight` can warn you about upcoming payments in the next 3 days. Set due dates on every bill.
- **Habits for health tracking.** Food, exercise, water, sleep — log these as TickTick habits and `/today` will remind you what's due.
- **Don't over-organise lists.** 4-6 lists is plenty. The AI routes tasks by context, not by rigid categories.
- **Session token refresh.** The v2 session token expires. If calendar/habits suddenly stop working, grab a fresh token from your browser cookies.

## Adapting for Your Setup

If you want to make the skills TickTick-specific (instead of generic), edit each skill's SKILL.md in `.claude/skills/` and replace the generic "use your task manager" lines with explicit TickTick tool calls as shown above. The generic versions work fine — the AI figures out the mapping — but explicit calls are more reliable.
