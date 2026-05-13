---
# Grimoire Protocol — Nightly Compile Routine Template
#
# Copy this prompt into your scheduled-task runner (Claude Code desktop app
# "Routines", cron + claude-code-cli, or equivalent). Run nightly around 23:57.
#
# Replace {{VAULT_ROOT}} with your vault's absolute path before saving.
# The scaffold scripts substitute this for you if used.
#
# Architecture note:
#   The grimoire engine has a TWO-STAGE pipeline:
#     1. Registration — file added to manifest (cheap, no LLM)
#     2. Compilation — manifest entry → wiki article (LLM work, via MCP)
#   `wiki_compile_diff` ONLY reports REGISTERED-but-not-compiled sources.
#   Files on disk that have never been registered are invisible to it.
#   Step 0.5 below closes this gap by registering everything new before pre-check.
---

You are running the nightly Grimoire compile for the vault at `{{VAULT_ROOT}}`.

# Step 0 — Refresh the skills snapshot

Before anything else, run the skills snapshot script so any new or updated assistant skills land in `inbox/skills/`:

```bash
python "{{VAULT_ROOT}}/scripts/grimoire/snapshot-skills.py"
```

Walks `~/.claude/skills/*/SKILL.md` and writes lightweight summary files. Pure file I/O, < 1 second. Print its one-line output.

# Step 0.5 — Register unregistered sources

The grimoire engine has a two-stage pipeline: **registration** then **compilation**. `mcp__grimoire__wiki_compile_diff` only reports REGISTERED-but-not-compiled sources. Files on disk that have never been registered are invisible to it. So before the pre-check we must register everything new.

1. Run the engine's dry-run to enumerate files on disk that aren't in the manifest:
   ```bash
   "{{VAULT_ROOT}}/.grimoire/grimoire.exe" compile --project "{{VAULT_ROOT}}" --dry-run > /tmp/grimoire-pending.log 2>&1
   ```
   (On macOS/Linux drop the `.exe` and adjust the temp path.)

2. Parse `/tmp/grimoire-pending.log` for unregistered files. Lines look like:
   ```
     + inbox\skills\new-skill.md (article)
     + projects\foo\context.md (article)
   ```
   Capture every path after the `+` (strip surrounding whitespace and the trailing `(type)`).

3. **Filter out binary file extensions** that the engine config cannot block (this engine's ignore does not support `*.ext` globs). Skip any path ending in:
   `.psd .png .jpg .jpeg .gif .webp .ico .icns .mp3 .mp4 .wav .zip .tar .gz .xlsx .docx .pptx .pdf .gitignore .gitkeep`

   Also skip if the path contains `.git/` or `.git\` (defence in depth — config ignores nested .git but new clones may slip through).

4. **For each surviving path**, call `mcp__grimoire__wiki_add_source` with the path normalised to forward slashes:
   ```
   wiki_add_source(path="inbox/skills/new-skill.md")
   ```
   No LLM call — pure manifest insert. Fast.

5. Print one line: `Registered N new sources.` (N may be 0 on quiet nights.)

# Pre-check

1. Call `mcp__grimoire__wiki_compile_diff`.
2. If zero pending compilation **AND** Step 0.5 registered zero sources, exit silently. No output, no writes, no commit.

# Compile pipeline (when there is work to do)

Invoke the `grimoire-compile` skill via the Skill tool and execute every step (1–9). You MUST complete all of the following before exiting — do not stop after writing concept articles:

- **Steps 1–7** — Read pending sources, summarise (call `wiki_write_summary` per source), extract concepts, write articles via `wiki_write_article`, build ontology via `wiki_add_ontology`, write connections.

  **Pragmatic note on volume:** If the pending list is large (>50 sources), prioritise:
  - Skill snapshots (`inbox/skills/*`) — tiny; batch through them efficiently
  - Recent inbox content (`inbox/tldr/`, `inbox/daily/`, `inbox/sessions/` — last 7 days)
  - Anything else: do as many as fit in your context budget, leave the rest for the next nightly run. Do NOT skip Step 8 just because the pending list is long.

- **Step 8 — STRUCTURAL FILES (do not skip):**
  1. Update `wiki/index.md` — append all new/updated articles to the master table.
  2. Prepend a new entry at the TOP of `wiki/log.md` with format `## [YYYY-MM-DD HH:MM] compile | <description>` listing sources processed, articles created, articles updated, connections found.
  3. **Regenerate `wiki/hot.md` from scratch** (overwrite entirely, ~500 tokens) following the template in the `grimoire-hot` skill: `Last Compiled` timestamp (24hr), `Active Threads` (3-6 bullets), `Key Recent Facts` (3-5 bullets).
  4. Update `wiki/overview.md` only if this compile materially changes the knowledge landscape.
  5. Update relevant `wiki/<category>/_index.md` sub-indexes for any category where articles were added or modified.

- **Step 9** — Call `mcp__grimoire__wiki_commit` with a descriptive message: `compile: nightly YYYY-MM-DD — registered X, processed N sources, created Y articles, refreshed hot/index/log`.

# Verification before exit

Before considering the task complete, confirm:
- [ ] `wiki/hot.md` was overwritten (its `updated:` frontmatter date matches today)
- [ ] `wiki/log.md` has a new entry at the top dated today
- [ ] `wiki/index.md` reflects any new/updated articles
- [ ] `wiki_commit` was called and returned successfully

If ANY of these are missing, finish them before exiting. The whole point of the nightly run is to keep `hot.md` fresh.

# Output

If work was done, print one line: `Nightly compile YYYY-MM-DD: registered R, compiled C, articles created A, updated U, hot.md refreshed.`
If nothing was pending (no new files, no pending compilation), print nothing.

# Important engine quirks

- The engine's ignore patterns do NOT support `**/` recursive globs.
- Bare names in `ignore:` match TOP-LEVEL ONLY. Nested paths need explicit entries in BOTH slash forms (e.g. `"templates/prompt-templates/.git"` AND `"templates\\prompt-templates\\.git"`).
- File-extension globs like `"*.psd"` DO NOT WORK in the engine's ignore. Filter binaries at this prompt's Step 0.5.3 instead.
- The CLI `compile` command (and the MCP `wiki_compile` tool) try to call the Anthropic API directly with the dummy key in `config.yaml` — they will fail. NEVER call them. All LLM work flows through the MCP `wiki_write_summary` / `wiki_write_article` tools that the agent (you) drive.
