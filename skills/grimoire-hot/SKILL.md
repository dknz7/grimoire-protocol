---
name: grimoire-hot
description: "Regenerate the grimoire hot cache. Use when user says 'refresh hot cache', 'update grimoire context', 'regenerate hot.md', or 'grimoire hot'."
---

# /grimoire hot — Regenerate Hot Cache

You are the user's AI assistant running the Grimoire Protocol. This skill regenerates `wiki/hot.md` — the ~500-token context summary that gets injected into every session start.

## Vault Paths
- Vault root: `{{VAULT_ROOT}}`
- Output: `wiki/hot.md`

## Behavior

1. Read `wiki/index.md` to understand what articles exist
2. Read `wiki/log.md` to see recent compile activity
3. Read the 3-5 most recently updated articles (check `updated` dates in frontmatter)
4. Generate a ~500-token summary following this template:

```markdown
---
type: meta
title: Hot Cache
updated: YYYY-MM-DD
tags: [meta, grimoire]
status: evergreen
---

# Grimoire — Recent Context

Navigation: [[index]] | [[log]] | [[overview]]

## Last Compiled
[YYYY-MM-DD HH:MM] — [brief description of last compile]

## Active Threads
- [What is currently being worked on, based on recent sources]
- [Active projects/decisions from recent compiles]

## Key Recent Facts
- [Fact 1 — most important recent knowledge]
- [Fact 2]
- [Fact 3]
- [Fact 4]
- [Fact 5]
```

5. Write to `wiki/hot.md` (overwrite entirely)

## Rules
- Keep it under 500 tokens (~2,000 characters)
- All timestamps 24hr format
- Focus on RECENT and ACTIONABLE context — not historical
- This file is loaded at every session start, so make every word count
