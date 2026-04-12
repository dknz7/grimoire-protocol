"""
Grimoire Protocol — SessionEnd hook.

Captures conversation transcript and writes it directly to
inbox/sessions/ as a markdown file for later compilation.

NO background process spawning. NO API calls. Pure file I/O.
The compilation happens later via `/grimoire compile`.

Setup:
  1. Copy this file to <vault>/scripts/grimoire/session-end.py
  2. Wire it in .claude/settings.local.json (see config/settings-hooks.json.template)
"""

from __future__ import annotations

import json
import logging
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

# Recursion guard: if spawned by Agent SDK or similar, exit immediately.
if os.environ.get("CLAUDE_INVOKED_BY"):
    sys.exit(0)

# Vault root is two levels up from scripts/grimoire/
ROOT = Path(__file__).resolve().parent.parent.parent
INBOX_SESSIONS = ROOT / "inbox" / "sessions"
LOG_DIR = ROOT / "scripts" / "grimoire"

logging.basicConfig(
    filename=str(LOG_DIR / "grimoire-hooks.log"),
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [session-end] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

MAX_TURNS = 30
MAX_CONTEXT_CHARS = 15_000
MIN_TURNS_TO_FLUSH = 1


def extract_conversation_context(transcript_path: Path) -> tuple[str, int]:
    """Read JSONL transcript and extract last ~N turns as markdown."""
    turns: list[str] = []

    with open(transcript_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            msg = entry.get("message", {})
            if isinstance(msg, dict):
                role = msg.get("role", "")
                content = msg.get("content", "")
            else:
                role = entry.get("role", "")
                content = entry.get("content", "")

            if role not in ("user", "assistant"):
                continue

            if isinstance(content, list):
                text_parts = []
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "text":
                        text_parts.append(block.get("text", ""))
                    elif isinstance(block, str):
                        text_parts.append(block)
                content = "\n".join(text_parts)

            if isinstance(content, str) and content.strip():
                label = "User" if role == "user" else "Assistant"
                turns.append(f"**{label}:** {content.strip()}\n")

    recent = turns[-MAX_TURNS:]
    context = "\n".join(recent)

    if len(context) > MAX_CONTEXT_CHARS:
        context = context[-MAX_CONTEXT_CHARS:]
        boundary = context.find("\n**")
        if boundary > 0:
            context = context[boundary + 1:]

    return context, len(recent)


def main() -> None:
    try:
        raw_input = sys.stdin.read()
        try:
            hook_input: dict = json.loads(raw_input)
        except json.JSONDecodeError:
            fixed_input = re.sub(r'(?<!\\)\\(?!["\\])', r'\\\\', raw_input)
            hook_input = json.loads(fixed_input)
    except (json.JSONDecodeError, ValueError, EOFError) as e:
        logging.error("Failed to parse stdin: %s", e)
        return

    session_id = hook_input.get("session_id", "unknown")
    transcript_path_str = hook_input.get("transcript_path", "")

    logging.info("SessionEnd fired: session=%s", session_id)

    if not transcript_path_str or not isinstance(transcript_path_str, str):
        logging.info("SKIP: no transcript path")
        return

    transcript_path = Path(transcript_path_str)
    if not transcript_path.exists():
        logging.info("SKIP: transcript missing: %s", transcript_path_str)
        return

    try:
        context, turn_count = extract_conversation_context(transcript_path)
    except Exception as e:
        logging.error("Context extraction failed: %s", e)
        return

    if not context.strip():
        logging.info("SKIP: empty context")
        return

    if turn_count < MIN_TURNS_TO_FLUSH:
        logging.info("SKIP: only %d turns (min %d)", turn_count, MIN_TURNS_TO_FLUSH)
        return

    INBOX_SESSIONS.mkdir(parents=True, exist_ok=True)

    now = datetime.now(timezone.utc).astimezone()
    timestamp = now.strftime("%Y-%m-%d-%H%M%S")
    session_short = session_id[:8] if len(session_id) >= 8 else session_id
    filename = f"{timestamp}-{session_short}.md"
    output_path = INBOX_SESSIONS / filename

    frontmatter = (
        "---\n"
        "source: session-end\n"
        f"session_id: {session_id}\n"
        f"captured_at: {now.strftime('%Y-%m-%dT%H:%M:%S%z')}\n"
        f"turns: {turn_count}\n"
        "---\n\n"
    )

    output_path.write_text(frontmatter + context, encoding="utf-8")
    logging.info(
        "Wrote session capture: %s (%d turns, %d chars)",
        filename, turn_count, len(context),
    )


if __name__ == "__main__":
    main()
