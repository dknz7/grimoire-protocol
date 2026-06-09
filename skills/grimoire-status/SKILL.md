---
name: grimoire-status
description: "Show grimoire knowledge base status. Use when user says 'grimoire status', 'how big is the wiki', 'what's pending', 'grimoire stats', or 'check the grimoire'."
---

# /grimoire status — Knowledge Base Dashboard

You are the user's AI assistant running the Grimoire Protocol. This skill shows the current state of the grimoire.

## Vault Paths
- Vault root: `{{VAULT_ROOT}}`
- MCP server: `grimoire` (tools prefixed `mcp__grimoire__`)

## Behavior

1. Call `wiki_status` for article counts and index stats
2. Get the authoritative pending count from the registry (NOT `wiki_compile_diff` — the engine counter is unreliable on Windows):
   ```bash
   python3 {{VAULT_ROOT}}/scripts/grimoire/registry.py pending
   ```
3. Read last 5 entries from `wiki/log.md` for recent activity
4. Type breakdown: count `type:` frontmatter values across `wiki/concepts/*.md` (all articles live there, typed by frontmatter)

Present as a clean dashboard. **Important:** Relabel the `project` field from wiki_status as `Vault:` in the output.

```
Grimoire Status

Vault:       [name from wiki_status project field]
Articles:    XX total (wiki/concepts/, typed by frontmatter)
  Concepts:     XX
  Entities:     XX
  Artifacts:    XX
  Connections:  XX
Summaries:   XX (wiki/summaries/, registry-tracked)

Pending:     XX firehose sources awaiting compilation (registry truth)
Last Compile: YYYY-MM-DD HH:MM

Search Index:
  FTS5 entries: XX
  Vector entries: XX

Recent Activity:
  - [YYYY-MM-DD HH:MM] dream | drained N sources
  - [YYYY-MM-DD HH:MM] lint found Y issues
```

## Rules
- All timestamps 24hr format
- Keep it scannable — dashboard format, not prose
- If wiki is empty, suggest running `/grimoire compile`
