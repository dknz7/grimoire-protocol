---
name: grimoire-dream
description: "The nightly Dream Sequence — the grimoire tidies and synthesises while you sleep. Reconciles the processed registry, drains the capture firehose, runs a light lint, refreshes the hot cache. Triggers: 'dream sequence', 'run the dream', 'grimoire dream', '/grimoire dream', nightly scheduled run."
---

# /grimoire dream — The Dream Sequence

You are the user's AI assistant running the Grimoire Protocol. This is the nightly ritual: the grimoire ingests what's new, synthesises it, tidies itself, and wakes up smarter. It trusts the authoritative registry (`wiki/processed.md`), never the engine's manifest counter.

## Vault Paths
- Vault root: `{{VAULT_ROOT}}`
- Registry: `scripts/grimoire/registry.py` (reconcile / pending / mark)
- MCP server: `grimoire` (tools prefixed `mcp__grimoire__`)

## Ritual

### Step 1 — Reconcile the registry
```bash
python3 {{VAULT_ROOT}}/scripts/grimoire/registry.py reconcile
```
This rebuilds `wiki/processed.md` from on-disk summaries and prints the honest pending count. If `0 pending`, skip to Step 4 (still refresh hot.md so the date is current), then exit.

### Step 2 — Drain the firehose
Get the pending list (`registry.py pending`). For each pending source, run the `grimoire-compile` pipeline (Steps 2–7): summarise → `wiki_write_summary` → `registry.py mark` → extract concepts → write articles → ontology → connections. Prioritise newest first. If the list is long (>20), do as many as fit your context budget and leave the rest for tomorrow — do NOT skip Step 3 or 4.

### Step 3 — Light lint
Call `wiki_lint` for structural checks (broken links, orphans, sparse articles). Surface only CRITICAL findings in the log. Do NOT auto-fix. The deep weekly lint (`/grimoire lint`) handles contradiction analysis and the full report.

### Step 4 — Refresh structural files
1. Update `wiki/index.md` with any new/updated articles.
2. Prepend a Dream Sequence entry at the TOP of `wiki/log.md`: `## [YYYY-MM-DD HH:MM] dream | <one-line summary>` listing reconciled/processed/articles/lint findings.
3. Regenerate `wiki/hot.md` from scratch (~500 tokens, 24hr timestamps).

### Step 5 — Commit
Call `wiki_commit`: `dream: nightly YYYY-MM-DD — processed N, created A, hot refreshed`.

## Verification before exit
- [ ] `wiki/processed.md` updated date is today
- [ ] `wiki/hot.md` overwritten (frontmatter date is today)
- [ ] `wiki/log.md` has a new `dream` entry at top
- [ ] `wiki_commit` returned success

## Rules
- Trust `registry.py`, never `wiki_compile_diff`.
- NEVER call `wiki_compile` or `wiki_capture` (dummy API key → fail).
- All timestamps 24hr, your configured timezone.
- Surgical: do not mass-compile reference dirs autonomously — firehose only.
