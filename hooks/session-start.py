"""
Grimoire Protocol — SessionStart hook.

Injects the hot cache into every new conversation so your AI assistant
has compiled knowledge context from the start. Reads wiki/hot.md only.

Hard cap: 3,000 characters to avoid eating your context window.

Pure file I/O, no API calls, <1 second execution.

Setup:
  1. Copy this file to <vault>/scripts/grimoire/session-start.py
  2. Wire it in .claude/settings.local.json (see config/settings-hooks.json.template)
"""

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

# Vault root is two levels up from scripts/grimoire/
ROOT = Path(__file__).resolve().parent.parent.parent
HOT_CACHE = ROOT / "wiki" / "hot.md"

MAX_CONTEXT_CHARS = 3_000


def build_context() -> str:
    parts = []

    now = datetime.now(timezone.utc).astimezone()
    parts.append(f"## Today\n{now.strftime('%A, %Y-%m-%d %H:%M')}")

    if HOT_CACHE.exists():
        content = HOT_CACHE.read_text(encoding="utf-8").strip()
        if content:
            parts.append(f"## Grimoire Hot Cache\n\n{content}")
        else:
            parts.append("## Grimoire Hot Cache\n\n(empty — run `/grimoire compile` to populate)")
    else:
        parts.append("## Grimoire Hot Cache\n\n(not found — run `/grimoire compile` to create)")

    context = "\n\n---\n\n".join(parts)

    if len(context) > MAX_CONTEXT_CHARS:
        context = context[:MAX_CONTEXT_CHARS] + "\n\n...(truncated)"

    return context


def main():
    context = build_context()

    output = {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": context,
        }
    }

    print(json.dumps(output))


if __name__ == "__main__":
    main()
