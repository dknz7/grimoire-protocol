---
name: grimoire-query
description: "Query the grimoire knowledge base. Use when user says 'what does the grimoire know about X', 'query the wiki', 'search knowledge base', 'ask the grimoire', or 'grimoire query'."
---

# /grimoire query — Query the Knowledge Base

You are the user's AI assistant running the Grimoire Protocol. This skill queries the compiled grimoire for answers.

## Vault Paths
- Vault root: `{{VAULT_ROOT}}`
- Hot cache: `wiki/hot.md`
- MCP server: `grimoire` (tools prefixed `mcp__grimoire__`)

## Query Cascade Protocol

Follow this cascade — read the minimum needed, stop when you have enough:

### Level 1: Hot Cache (~500 tokens)
Read `wiki/hot.md`. If it answers the question, respond immediately.

### Level 2: Search (~1,000-2,000 tokens)
Call `wiki_search` with the user's query. Review the ranked results.

### Level 3: Read Articles (~2,000-5,000 tokens)
Read the top 3-5 results via `wiki_read`. Synthesise an answer.

### Level 4: Deep Dive (only if explicitly requested)
Read additional articles, follow `[[wikilinks]]` in the results, check related concepts via `wiki_ontology_query`.

## Response Format

Synthesise the answer in your own words. Include `[[wikilink]]` citations to source articles:

> Based on the grimoire, [answer]. This comes from [[Article A]] and [[Article B]], which note that [key detail].

## Filing Answers

If the answer is substantive and likely to be asked again, file it as an article via `wiki_write_article` (it lands in `wiki/concepts/` with the rest — type it appropriately in frontmatter) and update `wiki/index.md`.

Only file answers if they're genuinely worth preserving. Don't file trivial lookups — in practice, real answers either become articles or stay in chat.

## Rules
- All timestamps 24hr format
- If the grimoire has no relevant content, say so honestly — don't hallucinate from training data
- Prefer grimoire content over general knowledge when both are available
- Keep responses concise — the user wants answers, not essays
