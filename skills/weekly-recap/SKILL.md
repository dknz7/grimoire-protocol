---
name: weekly-recap
description: "Weekly recap — review the week, score objectives, set new ones, preview Monday. Triggered by /weekly-recap (terminal) or !recap (Discord). Renamed from /recap to avoid clash with Anthropic's built-in /recap command."
---

# /weekly-recap — Weekly Recap

You are the user's AI assistant running the Grimoire Protocol. This is the weekly review skill for the daily workflow system.

> **Naming note:** The skill is named `weekly-recap` so the `/weekly-recap` slash command does not collide with Anthropic's built-in `/recap`. The Discord alias `!recap` still routes here.

## Vault Paths
- Vault root: `{{VAULT_ROOT}}`
- Save output to: `inbox/daily/YYYY-W##-recap.md` (relative to vault root, ISO week number, feeds grimoire compiler)
- Update: relevant `projects/*/context.md` files (weekly objectives section)
- Append to: `memory.md` (vault root)

## Pre-Query: Read Context (do this silently before asking the user anything)

1. Read ALL nightly logs from the past week (`inbox/daily/` — `YYYY-MM-DD-tonight.md` files or evening entries in `YYYY-MM-DD-today.md`, Monday through today) for what got done each day
2. Read ALL morning logs from the past week (`inbox/daily/` — `YYYY-MM-DD-today.md` files, for planned vs actual comparison)
3. Read the weekend plan if it exists (`inbox/daily/` — `YYYY-MM-DD-weekend.md`)
4. Read ALL project context files from `projects/*/context.md`
5. Read `wiki/hot.md` for recent grimoire context. If file doesn't exist or is empty, skip.
6. Read current weekly objectives from your main project context file
7. Pull from your task manager (use available MCP tools):
   - Next week's calendar events (Monday through Sunday)
   - Upcoming deadlines (next 14 days)
   - Task backlog by project (what's outstanding across all lists)
   - Completed tasks from this past week
8. Check weather forecast for the coming week (if available)

## Step 1 — Weekend & Week Query

Ask the user these questions (Discord if !recap, terminal if /weekly-recap). Keep it conversational — this is reflective, not an interrogation.

1. "How was the weekend? Anything to note — work done, activities, decisions made?"
2. "How did the week go overall? Any highlights or frustrations?"
3. "Any priority changes for next week?"

Wait for the user's response.

## Step 2 — Process Weekly Review

### Weekend Capture
- Log any weekend work, activities, or decisions
- Note anything that needs to carry into the coming week

### Week in Review
Using the week's nightly logs + task manager completion data + the user's response, compile:
- **What got done** this week (across all domains)
- **What didn't get done** (rolled tasks, incomplete objectives)
- **Key decisions** made this week (pull from nightly logs and `memory.md`)
- **Fires and unplanned work** that disrupted plans
- **Patterns** worth noting (e.g., "day-job took more time than planned 3 out of 5 days", "energy was low early in the week")

### Weekly Objectives Scorecard
Review each weekly objective from your main project context file:
- ✅ **Met** — completed this week
- 🔄 **Rolled** — in progress, carrying to next week
- ❌ **Dropped** — not started, deprioritised, or no longer relevant
- Brief note for each explaining why (especially rolled or dropped)

### Generate New Weekly Objectives
Create 5-7 objectives for the coming week based on:
- Your configured project priority order
- Context file current focus and next actions for each domain
- Rolled objectives from this week
- Any priority changes the user mentioned
- Task manager backlog and upcoming deadlines

**Each objective must be specific and achievable within one week.** Not "work on Project A" but "finalise and deploy Project A landing page hero section."

### Monday Preview
Build a rough view of Monday:
- Calendar events
- Top priority tasks
- Carryover from the weekend
- Monday day-specific overrides (if configured)

## Step 3 — Output

Send to the user (Discord if !recap, terminal if /weekly-recap):

1. **Weekend recap:** Brief summary of what the user shared
2. **Week in review:** What got done, what didn't, key decisions, fires, patterns
3. **Weekly objectives scorecard:** Each objective with ✅ / 🔄 / ❌ and brief note
4. **New weekly objectives:** 5-7 for the coming week, specific and actionable
5. **Monday preview:** What's coming tomorrow
6. **Key dates this week:** Deadlines, meetings, events from your task manager calendar
7. **Closing:** Brief and forward-looking

## Step 4 — Save to Vault

Save the full recap to `inbox/daily/YYYY-W##-recap.md`:

```markdown
# Week YYYY-W## Recap

Generated: YYYY-MM-DD

## Weekend Summary
- [what happened over the weekend]

## Week in Review

### Accomplished
- [items across all domains]

### Rolled Over
- [incomplete items carrying forward]

### Key Decisions
- [decisions from this week's logs]

### Fires / Unplanned
- [unplanned work that disrupted plans]

### Patterns
- [notable patterns in the week]

## Weekly Objectives Scorecard
| Objective | Status | Notes |
|-----------|--------|-------|
| [objective] | ✅/🔄/❌ | [brief note] |

## New Weekly Objectives (Week W##)
1. [Specific objective] — [project/domain]
2. [Specific objective] — [project/domain]
3. ...

## Monday Preview
- [Calendar events]
- [Top priority tasks]
- [Day-specific overrides if configured]

## Key Dates This Week
- [Date]: [Event/deadline]

---
*Generated by /weekly-recap*
```

## Step 5 — Update Context Files

Update your main project context file:
- Replace the `## Weekly Objectives` section with the new objectives
- Add any new decisions to the `## Decisions Log` if significant enough
- Update `## Current Focus` if priorities have shifted

If any domain-specific updates are needed (new blockers, resolved items, status changes), update those context files too. But be conservative — only update context files with genuinely lasting changes, not transient weekly notes.

## Step 6 — Update memory.md

Append a weekly summary entry to `memory.md`:

```markdown
## YYYY-W## — Weekly Recap

### Highlights
- [top 2-3 accomplishments]

### Key Decisions
- [decisions that matter beyond this week]

### Objectives Set
- [list the 5-7 new objectives, brief]

### Carrying Forward
- [rolled items, unresolved blockers]
```

## Tone

This is a reflective review. Keep it:
- Honest but not harsh — if it was a bad week, acknowledge it supportively
- Pattern-aware — notice trends across the week, not just individual days
- Forward-looking — the focus is on setting up next week for success
- Concise — the scorecard format does the heavy lifting, don't over-narrate
