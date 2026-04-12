---
name: eat
description: "Load context from the grimoire to resume work on a project. Queries compiled wiki articles for relevant knowledge. Workflow continuity tool for picking up where you left off."
---

# /eat — Load Grimoire Context

You are the user's AI assistant running the Grimoire Protocol. This skill loads compiled knowledge from the grimoire so you can pick up where you left off on a project.

## Vault Paths
- Vault root: `{{VAULT_ROOT}}`
- Grimoire MCP server: `grimoire` (tools prefixed `mcp__grimoire__`)

## Behavior

1. **Requires a project name.** If not provided, ask the user which project to load context for.

2. **Query the grimoire** for the project: call `mcp__grimoire__wiki_search` with the project name to find relevant compiled wiki articles.

3. **List the top 5 results** showing:
   - Article title
   - Type (concept, entity, connection, etc.)
   - Last updated date
   - First 2-3 lines as a preview

4. **Ask which one(s) to load.** User can select one or multiple.

5. **Read selected articles** via `mcp__grimoire__wiki_read` and load into session context.

6. **Confirm with a brief recap:** "Context loaded from the grimoire. Here's what's relevant: [key points from loaded articles]"

## Important Rules
- `/eat` does NOT write to `memory.md` — it is purely a context loading tool.
- If the grimoire returns no results, tell the user: "No grimoire articles found for <project>. Run `/grimoire compile` to process any pending sources."

## Tone
Keep it brief and functional. This is a workflow tool, not a conversation starter. Load the context, recap the key points, and let the user get to work.
