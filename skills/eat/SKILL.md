---
name: eat
description: "Load context to resume work on a project. Choose between importing a recent /tldr session export or searching the Grimoire wiki. Workflow continuity tool for picking up where you left off."
---

# /eat — Load Context (tldr or Grimoire)

You are the user's AI assistant running the Grimoire Protocol. This skill loads prior context into the current session so you can pick up where you left off — either from a recent `/tldr` export (short-term continuity) or from the Grimoire compiled wiki (long-term knowledge).

## Vault Paths
- Vault root: `{{VAULT_ROOT}}`
- tldr folder: `{{VAULT_ROOT}}/inbox/tldr`
- Grimoire MCP server: `grimoire` (tools prefixed `mcp__grimoire__`)

## Behavior

### Step 0 — Route

**If a project name was passed as an argument** (e.g. `!eat <project>`, `/eat <project>`): skip the question and go straight to Path B with that project.

**Otherwise**, ask the user:

> "Do you want to import a recent tldr or search the Grimoire? (A / B)"
>
> - **A** — Import one of the 3 most recent `/tldr` session exports (best for resuming a thread from the last few days)
> - **B** — Search the compiled Grimoire wiki by project (best for long-term knowledge)

Accept "A" / "tldr" / "1" for Path A, or "B" / "grimoire" / "2" for Path B.

---

### Path A — Import a recent /tldr

1. **List the 3 most recent files** from `{{VAULT_ROOT}}/inbox/tldr/`. Sort by modification time, newest first. Use `Glob` (`**/*.md` in the tldr path) or list the directory and order by mtime.

2. **Show each one** with:
   - **[N]** Filename
   - **Project:** parsed from the `project:` field in YAML frontmatter (fallback: "unknown")
   - **Date / Title:** parsed from the `YYYY-MM-DD-<short-title>.md` filename pattern
   - **Preview:** first 2-3 non-empty lines of the `## Summary` section

3. **Ask which one(s) to load.** Accept a number (1, 2, 3), a filename, "all" for all three, or "cancel" to abort.

4. **Read the selected file(s)** via the Read tool and load into session context.

5. **Confirm with a brief recap:**
   > "Loaded [filename(s)]. Here's what's relevant: [3-5 bullet key points from the Summary + Key Decisions sections]"

---

### Path B — Search the Grimoire

1. **Requires a project name.** If not provided, ask the user which project to load context for.

2. **Query the grimoire** via `mcp__grimoire__wiki_search` with the project name to find relevant compiled wiki articles.

3. **List the top 5 results** showing:
   - Article title
   - Type (concept, entity, connection, etc.)
   - Last updated date
   - First 2-3 lines as a preview

4. **Ask which one(s) to load.** User can select one or multiple.

5. **Read selected articles** via `mcp__grimoire__wiki_read` and load into session context.

6. **Confirm with a brief recap:**
   > "Context loaded from the grimoire. Here's what's relevant: [key points from loaded articles]"

---

## Important Rules
- `/eat` does NOT write to `memory.md` — purely a context loading tool, regardless of path.
- **Path A empty case:** if no tldr files exist in `inbox/tldr/`, tell the user: "No /tldr exports found in `inbox/tldr/`. Run `/tldr` at the end of a session to capture one." Then offer to fall back to Path B.
- **Path B empty case:** if the grimoire returns no results, tell the user: "No grimoire articles found for <project>. Run `/grimoire compile` to process any pending sources." Then offer to fall back to Path A.
- If triggered from Discord (`!eat` or `!eat <project>`), same behavior but output goes to the Discord channel the command came from.

## Tone
Keep it brief and functional. This is a workflow tool, not a conversation starter. Load the context, recap the key points, and let the user get to work.
