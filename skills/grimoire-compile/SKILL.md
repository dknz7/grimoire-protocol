---
name: grimoire-compile
description: "Compile pending sources into wiki articles. Use when user says 'compile the grimoire', 'process inbox', 'update the wiki', 'run grimoire compile', or 'compile pending sources'."
---

# /grimoire compile — Compilation Pipeline

You are the user's AI assistant running the Grimoire Protocol. This skill compiles raw sources from `inbox/` into structured wiki articles.

## Vault Paths
- Vault root: `{{VAULT_ROOT}}`
- Sources: `inbox/sessions/`, `inbox/tldr/`, `inbox/daily/`, `inbox/drops/`
- Also watches: `daily/`, `projects/`, `research/`, `resources/`, `templates/`, `work/`
- Output: `wiki/concepts/` (ALL articles live here, typed by frontmatter) + `wiki/summaries/` (engine-written per-source summaries)
- MCP server: `grimoire` (tools prefixed `mcp__grimoire__`)

## Pipeline

Execute these steps in order:

### Step 1 — Check for Pending Sources
Run:
```bash
python3 {{VAULT_ROOT}}/scripts/grimoire/registry.py pending
```
Each printed line is a firehose source (`inbox/{sessions,tldr,daily,drops}`) that has no summary yet. If the output is empty, report "Grimoire is current — nothing to compile." and stop. `wiki_compile_diff` may be called for drift visibility only — never act on its counter.

### Step 2 — Read Pending Sources
Read each pending source file. Group them by source folder for domain detection.

### Step 3 — Summarise (be concise)
For each source:
1. Generate a concise summary (3-5 sentences capturing key facts, decisions, and insights)
2. Call `wiki_write_summary` with the summary content and a list of concept names extracted from the source
3. Run `python3 {{VAULT_ROOT}}/scripts/grimoire/registry.py mark "<source-path>" "wiki/summaries/<source-basename>.md"` to mark the source processed in the registry
4. Identify the domain from content (customise domains in `config.yaml`)

### Step 4 — Extract Concepts (thorough)
Across all summaries from Step 3:
1. Identify unique concepts (ideas, frameworks, patterns, tools, techniques)
2. Identify entities (people, organisations, products, projects)
3. Identify potential connections between concepts
4. De-duplicate — check existing articles via `wiki_read` before creating new ones

### Step 5 — Write Articles
For each concept identified:
1. Check if article exists: call `wiki_read` with the concept name
2. If exists: merge new information into existing article, update the `updated` date and `sources` list
3. If new: write a fresh article

**ALL articles** (concepts, entities, artifacts, connections alike) go through `wiki_write_article` — it writes to `wiki/concepts/` and indexes in FTS5. The article's TYPE lives in its frontmatter, not its folder — frontmatter typing + the master index do the categorisation work.

**Frontmatter schema (required on every article):**
```yaml
---
type: concept|entity|artifact|connection
title: "Human-Readable Title"
aliases: []
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: [domain-tag, type-tag]
status: seed|developing|mature|evergreen
related: ["[[Other Article]]"]
sources: ["inbox/sessions/2026-04-11-120000-abc123.md"]
confidence: high|medium|low
domain: your-domain-here
---
```

**Wikilink convention:** `[[Article Title]]` format (Obsidian-native, no file paths).

### Step 6 — Build Ontology
For each entity and concept, call `wiki_add_ontology` to create:
- Entity entries (type: concept, technique, source, claim, artifact)
- Typed relations (implements, extends, optimizes, contradicts, cites, prerequisite_of, trades_off, derived_from)

### Step 7 — Write Connections (deep reasoning)
Look for non-obvious cross-cutting insights that link 2+ concepts from different domains.
Write connection articles via `wiki_write_article` with `type: connection` frontmatter (they live in `wiki/concepts/` like everything else).
Only create connections that are genuinely insightful — not just "X and Y were mentioned together".

**Contradiction handling:** If new information conflicts with existing article content:
```markdown
> [!contradiction] Conflicts with [[Other Article]]
> New source claims X, but existing article says Y.
> Needs resolution. Check dates and primary sources.
```

### Step 8 — Update Structural Files
1. **wiki/index.md** — Update the master table with all new/updated articles
2. **wiki/log.md** — Prepend a compile entry at the TOP (newest first):
   ```markdown
   ## [YYYY-MM-DD HH:MM] compile | [Brief description]
   - Sources processed: N
   - Articles created: [[Article 1]], [[Article 2]]
   - Articles updated: [[Article 3]]
   - Connections found: [[Connection 1]]
   ```
3. **wiki/hot.md** — Regenerate (~500 tokens):
   - Last Compiled: timestamp (24hr format)
   - Active Threads: what's currently being worked on
   - Key Recent Facts: most important 3-5 facts from this compile
4. **wiki/overview.md** — Update if the compile significantly changes the knowledge landscape

### Step 9 — Commit
Call `wiki_commit` with a descriptive message like: "compile: processed N sources, created X articles, updated Y"

## Important Rules
- All dates: YYYY-MM-DD format
- All timestamps: 24hr format (HH:MM:SS), never AM/PM
- Timezone: Configure in `config.yaml` (default: UTC)
- NEVER call `wiki_compile` or `wiki_capture` MCP tools — they will fail
- Keep articles focused: one concept per article, 100-300 lines max
- Use `[[wikilinks]]` for all cross-references
- Status progression: seed -> developing -> mature -> evergreen
