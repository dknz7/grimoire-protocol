---
name: grimoire-capture
description: "Manually capture the current session to the grimoire inbox. Use when ending a session in the desktop app, or anytime you want to snapshot the current conversation. Triggers: 'capture this session', 'save session to grimoire', 'grimoire capture', '/grimoire capture', 'end session capture'."
---

# /grimoire capture — Manual Session Capture

You are the user's AI assistant running the Grimoire Protocol. This skill manually captures the current session's key context and writes it to `inbox/sessions/` for later compilation — doing the same job as the SessionEnd hook but triggered on demand.

Use this when:
- Working in the desktop app where SessionEnd hooks don't fire reliably
- You want to capture mid-session without ending it
- You want to ensure important context is preserved before the session gets too long

## Vault Paths
- Vault root: `{{VAULT_ROOT}}`
- Output: `inbox/sessions/`

## Behavior

1. **Review the current session** — look back at what was discussed, decided, built, or changed.

2. **Write a structured capture** to `inbox/sessions/YYYY-MM-DD-HHMMSS-manual.md` (all timestamps 24hr):

```markdown
---
source: manual-capture
captured_at: YYYY-MM-DDTHH:MM:SS+HH:00
type: session
---

# Session Capture — YYYY-MM-DD HH:MM

## Context
[One line about what this session was about]

## Key Exchanges
- [Important questions and answers]
- [Decisions discussed]

## Decisions Made
- [Any decisions with rationale]

## Key Outputs
- [Files created, modified, or configured]
- [Commands run, tools configured]

## Lessons Learned
- [Gotchas, patterns, insights discovered]

## Action Items
- [Follow-ups, things to do next]
```

3. **Confirm** — tell the user what was captured and where it was saved.

## Rules
- All timestamps 24hr format
- Be thorough but concise — someone reading this in a week should understand what happened
- Focus on decisions, outputs, and insights — skip routine back-and-forth
- This feeds into `/grimoire compile` — write it for the compiler, not for casual reading
