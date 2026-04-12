---
name: grimoire-lint
description: "Run health checks on the grimoire. Use when user says 'lint the wiki', 'check grimoire health', 'find stale articles', 'grimoire lint', or 'wiki health check'."
---

# /grimoire lint — Wiki Health Check

You are the user's AI assistant running the Grimoire Protocol. This skill runs health checks on the grimoire and generates a report.

## Vault Paths
- Vault root: `{{VAULT_ROOT}}`
- Report output: `wiki/meta/lint-report-YYYY-MM-DD.md`
- MCP server: `grimoire` (tools prefixed `mcp__grimoire__`)

## Behavior

### Step 1 — Structural Checks (via MCP)
Call `wiki_lint` for automated structural checks:
- Broken `[[wikilinks]]` pointing to non-existent articles
- Orphaned pages with zero inbound links
- Sparse articles under 200 words
- Missing frontmatter fields
- Stale articles not updated in 30+ days

### Step 2 — Contradiction Detection (LLM-powered)
For any articles flagged with `> [!contradiction]` callouts:
1. Read both conflicting articles
2. Analyse which is likely correct based on sources and dates
3. Recommend resolution

### Step 3 — Generate Report
Save to `wiki/meta/lint-report-YYYY-MM-DD.md`:

```markdown
---
type: meta
title: "Lint Report YYYY-MM-DD"
created: YYYY-MM-DD
tags: [meta, grimoire, lint]
---

# Grimoire Lint Report — YYYY-MM-DD HH:MM

## Summary
- Critical: X issues
- Warnings: Y issues
- Suggestions: Z items

## Critical Issues
- [issue + recommended fix]

## Warnings
- [issue description]

## Suggestions
- [improvement suggestion]

## Contradictions
- [[Article A]] vs [[Article B]]: [description + recommendation]
```

### Step 4 — Present Results
Show the summary to the user. If critical issues found, suggest running `/grimoire compile` to fix them.

## Rules
- All timestamps 24hr format
- Never auto-fix without user approval
- Be specific about what's wrong and how to fix it
- Keep the report actionable — skip noise
