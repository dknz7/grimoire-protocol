# Grimoire Protocol — Architecture

## What This Repo Is (And Isn't)

**Grimoire Protocol is the integration layer.** It contains the skills, hooks, config templates, and scaffold scripts that wire everything together. It does NOT contain the compilation engine.

**The engine is [sage-wiki](https://github.com/xoai/sage-wiki)** — a separate Go project that provides SQLite + FTS5 storage, hybrid search, MCP tools, and the web UI. Grimoire Protocol pulls sage-wiki at build time (via the scaffold scripts) and brands the binary as `grimoire`. We don't fork sage-wiki — we consume it.

**Why this separation?** sage-wiki handles storage and retrieval. Your Claude subscription handles all the LLM reasoning. Grimoire Protocol is the glue that connects them — the skills that orchestrate compilation, the hooks that capture sessions, and the config that ties it to your vault.

```
┌──────────────────────────────────────────────────────────────┐
│  THIS REPO (grimoire-protocol)                               │
│  Skills, hooks, config, scaffold scripts                     │
│                                                              │
│  ┌────────────────────┐    ┌──────────────────────────────┐  │
│  │  Your Claude Sub   │    │  sage-wiki engine (grimoire) │  │
│  │  (LLM reasoning)   │───>│  (SQLite, FTS5, MCP, Web UI) │  │
│  └────────────────────┘    └──────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

## The Three Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    YOUR OBSIDIAN VAULT                       │
│                                                             │
│  ┌──────────────┐     ┌──────────────┐     ┌────────────┐  │
│  │   CAPTURE     │     │   COMPILE    │     │   QUERY    │  │
│  │              │     │              │     │            │  │
│  │  Hooks write │────>│  Skills read │────>│  Hot cache │  │
│  │  to inbox/   │     │  inbox/ and  │     │  + FTS5    │  │
│  │              │     │  write wiki/ │     │  search    │  │
│  └──────────────┘     └──────────────┘     └────────────┘  │
│                                                             │
│  inbox/          ──>  wiki/           ──>  wiki/hot.md     │
│  (append-only)        (compiler-owned)     (session primer) │
└─────────────────────────────────────────────────────────────┘
```

## How It Works

### 1. Capture (Automatic)

Three hooks fire automatically during Claude Code sessions:

- **SessionStart** — reads `wiki/hot.md` (~500 tokens) and injects it as context. Every session starts with compiled knowledge.
- **SessionEnd** — extracts the last ~30 conversation turns and writes them to `inbox/sessions/` as a markdown file.
- **PreCompact** — same as SessionEnd but fires before auto-compaction. Safety net for long sessions where context would otherwise be lost to summarisation.

Daily workflow skills (`/today`, `/tonight`, `/recap`, `/weekend`, `/tldr`, `/dump`) also write to `inbox/` subdirectories.

### 2. Compile (Manual or Scheduled)

`/grimoire compile` processes pending sources through this pipeline:

1. **Diff** — check `inbox/` for new/changed files since last compile
2. **Summarise** — generate concise summaries of each source
3. **Extract** — identify concepts, entities, and connections across summaries
4. **Write** — create or update wiki articles with structured frontmatter
5. **Ontology** — register entities and typed relations in the graph
6. **Connections** — find cross-cutting insights linking 2+ concepts
7. **Update** — refresh index.md, log.md, hot.md, and sub-indexes

The compile skill calls sage-wiki's MCP write tools (`wiki_write_article`, `wiki_add_ontology`, etc.) while Claude Code's subscription LLM does all the reasoning. Zero API cost.

### 3. Query (On Demand)

`/grimoire query` follows a cascade protocol — read the minimum needed:

1. **Hot cache** (~500 tokens) — often enough for recent context
2. **FTS5 search** — keyword + semantic ranking via sage-wiki
3. **Read articles** — top 3-5 results, synthesise with citations
4. **Deep dive** — follow wikilinks, check ontology graph (only if asked)

## The Engine

sage-wiki (branded as `grimoire`) runs as an MCP server, providing:

- **SQLite + FTS5** — full-text search with BM25 ranking
- **Vector embeddings** — optional semantic search (requires local embedding model)
- **Ontology graph** — typed entities and relations (implements, extends, contradicts, etc.)
- **Manifest tracking** — SHA-256 hashes for incremental compilation
- **15 MCP tools** — read, write, search, lint, and graph operations
- **Web UI** — article browser, search, knowledge graph visualisation at localhost:3333

## File Ownership Rules

| Location | Owner | Rule |
|---|---|---|
| `inbox/` | Hooks + Skills | **Append-only.** Never edit or delete captures. |
| `wiki/` | Compile skill | **Compiler-owned.** Never write directly — only `/grimoire compile` does. |
| `wiki/hot.md` | Compile skill | Auto-regenerated each compile. Overwritten entirely. |
| `config.yaml` | User | Manual configuration. |
| `.sage/` | Engine | SQLite DB, auto-managed. Don't touch. |

## Frontmatter Schema

Every wiki article uses flat YAML frontmatter (Obsidian-compatible):

```yaml
---
type: concept|entity|source|connection|question
title: "Human-Readable Title"
aliases: []
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: [domain-tag, type-tag]
status: seed|developing|mature|evergreen
related: ["[[Other Article]]"]
sources: ["inbox/sessions/2026-04-11-120000.md"]
confidence: high|medium|low
domain: your-domain-here
---
```

## Parent Projects

Grimoire Protocol is a hybrid of three open-source projects:

- **[sage-wiki](https://github.com/xoai/sage-wiki)** — the Go engine (SQLite, FTS5, vectors, MCP server, web UI)
- **[claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian)** — UX patterns (hot cache, query cascade, frontmatter schema, lint)
- **[claude-memory-compiler](https://github.com/coleam00/claude-memory-compiler)** — hook architecture (SessionStart/End/PreCompact, recursion guards)
