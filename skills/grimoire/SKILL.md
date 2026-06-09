---
name: grimoire
description: "Grimoire Protocol — compile, query, and manage the knowledge base. Use when user says 'grimoire', 'compile the grimoire', 'compile the wiki', 'query the grimoire', 'what does the grimoire know', 'grimoire status', 'check grimoire', 'lint the wiki', 'refresh hot cache', 'capture this session', 'save session', 'run the dream sequence', or runs /grimoire. Subcommands: compile, query, status, lint, hot, capture, dream."
---

# /grimoire — Knowledge Base Management

You are the user's AI assistant running the Grimoire Protocol. This skill manages the compiled knowledge base backed by SQLite + FTS5.

## Subcommands

Route based on the argument or natural language intent:

| Subcommand | Triggers | Action |
|---|---|---|
| `compile` | "compile", "process inbox", "update the wiki" | Run the compilation pipeline (see /grimoire-compile skill) |
| `query` | "query", "what does the grimoire know about", "search knowledge" | Query the wiki (see /grimoire-query skill) |
| `status` | "status", "how big is the wiki", "what's pending" | Show wiki stats (see /grimoire-status skill) |
| `lint` | "lint", "health check", "find stale articles" | Run health checks (see /grimoire-lint skill) |
| `hot` | "hot", "refresh cache", "update hot cache" | Regenerate hot.md (see /grimoire-hot skill) |
| `capture` | "capture", "save session", "end session" | Manually capture current session to inbox (see /grimoire-capture skill) |
| `dream` | "dream", "dream sequence", "run the dream" | Run the nightly Dream Sequence ritual (see /grimoire-dream skill) |

If no subcommand is given, show a brief help message listing available subcommands.

## MCP Tools Available

The grimoire MCP server provides these tools (prefixed `mcp__grimoire__` at runtime):
- `wiki_status` — Wiki stats
- `wiki_search` — Hybrid BM25 + vector search
- `wiki_read` — Read article content
- `wiki_list` — List all concepts
- `wiki_compile_diff` — Show pending sources
- `wiki_write_summary` — Write source summary
- `wiki_write_article` — Write concept article
- `wiki_add_source` — Register source in manifest
- `wiki_add_ontology` — Create entity/relation
- `wiki_learn` — Store learning entry
- `wiki_commit` — Git commit
- `wiki_ontology_query` — Graph traversal
- `wiki_lint` — Run lint checks

**NEVER call `wiki_compile` or `wiki_capture`** — they attempt LLM API calls with a dummy key and will fail. All compilation goes through the individual write tools orchestrated by our skills.

## Conventions
- Dates: YYYY-MM-DD (ISO 8601)
- Timestamps: 24hr format (HH:MM:SS), never AM/PM
- Timezone: Configure in `config.yaml` (default: UTC)
- Domains: Customise domains in `config.yaml`
