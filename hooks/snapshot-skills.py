"""
Grimoire Protocol — Skills snapshot.

Walks the user's global Claude Code skills directory (~/.claude/skills/*/SKILL.md),
extracts a summary, and writes a clean lightweight markdown file per skill into
inbox/skills/. The grimoire compiler then turns these into wiki articles describing
the AI assistant's capabilities.

Why a snapshot rather than scanning the skills dir as a source?
  - Many skills bundle .venv, .git, references/, scripts/ that bloat the scan
  - We only care about each skill's purpose, triggers and capabilities — not the
    full instruction body or implementation
  - This gives the wiki a clean "assistant capabilities" view that compounds as
    new skills are added

Setup:
  1. Copy this file to <vault>/scripts/grimoire/snapshot-skills.py
  2. Run it before /grimoire compile (manually or via scheduled routine)

Pure file I/O, no API calls, < 1 second execution.
"""

from __future__ import annotations

import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

# Vault root is two levels up from scripts/grimoire/
ROOT = Path(__file__).resolve().parent.parent.parent
INBOX_SKILLS = ROOT / "inbox" / "skills"

# User's global Claude Code skills directory (override via env var if needed)
SKILLS_SRC = Path(os.environ.get("GRIMOIRE_SKILLS_SRC") or os.path.expanduser("~/.claude/skills"))

# Cap the description length so giant frontmatter descriptions stay readable
MAX_DESC_CHARS = 600


def parse_frontmatter(text: str) -> tuple[dict[str, str], str]:
    """Parse YAML-ish frontmatter. Returns (fields, body). Tolerant — not a real YAML parser."""
    if not text.startswith("---"):
        return {}, text
    end = text.find("\n---", 3)
    if end == -1:
        return {}, text
    fm_text = text[3:end].strip()
    body = text[end + 4:].lstrip()

    fields: dict[str, str] = {}
    current_key: str | None = None
    for raw in fm_text.splitlines():
        if not raw.strip():
            continue
        if re.match(r"^\s+", raw) and current_key:
            # Continuation line for multiline values (rare in skill frontmatter)
            fields[current_key] = (fields.get(current_key, "") + " " + raw.strip()).strip()
            continue
        if ":" in raw:
            key, _, val = raw.partition(":")
            current_key = key.strip()
            fields[current_key] = val.strip().strip('"').strip("'")
    return fields, body


def extract_first_heading(body: str) -> str:
    """Return the first H1 or H2 heading text from the body, if any."""
    for line in body.splitlines():
        line = line.strip()
        if line.startswith("# "):
            return line[2:].strip()
        if line.startswith("## "):
            return line[3:].strip()
    return ""


def safe_filename(name: str) -> str:
    """Convert a skill name to a filesystem-safe slug."""
    slug = re.sub(r"[^a-z0-9-]+", "-", name.lower()).strip("-")
    return slug or "unnamed-skill"


def truncate(text: str, limit: int) -> str:
    if len(text) <= limit:
        return text
    return text[:limit].rsplit(" ", 1)[0] + "…"


def snapshot_skill(skill_md: Path) -> dict[str, str] | None:
    """Read a SKILL.md, extract metadata, return wiki-ready record."""
    try:
        text = skill_md.read_text(encoding="utf-8")
    except Exception:
        return None

    fm, body = parse_frontmatter(text)
    name = fm.get("name") or skill_md.parent.name
    description = truncate(fm.get("description", "").strip(), MAX_DESC_CHARS)
    heading = extract_first_heading(body)

    return {
        "name": name,
        "description": description,
        "heading": heading,
        "source_path": str(skill_md),
    }


def render_snapshot(record: dict[str, str], captured_at: str) -> str:
    """Render a wiki-ready markdown snapshot for a skill — rich frontmatter, minimal body."""
    name = record["name"]
    desc = record["description"].replace('"', '\\"')
    heading = record["heading"] or name
    body = record["description"] or "(no description in skill frontmatter)"

    return (
        "---\n"
        "type: skill\n"
        f"name: {name}\n"
        f"title: \"{heading}\"\n"
        f"description: \"{desc}\"\n"
        f"source_path: {record['source_path']}\n"
        f"captured_at: {captured_at}\n"
        "tags: [skill, capability, archie]\n"
        "status: evergreen\n"
        "---\n\n"
        f"# {heading}\n\n"
        f"{body}\n"
    )


def existing_matches(dst: Path, new_content: str) -> bool:
    """Check if file content matches new_content (ignoring captured_at line) — avoid churn."""
    if not dst.exists():
        return False
    try:
        existing = dst.read_text(encoding="utf-8")
    except Exception:
        return False
    strip_ts = lambda s: re.sub(r"^captured_at:.*\n", "", s, flags=re.MULTILINE)
    return strip_ts(existing) == strip_ts(new_content)


def main() -> None:
    if not SKILLS_SRC.is_dir():
        print(f"SKIP: skills source not found: {SKILLS_SRC}", file=sys.stderr)
        sys.exit(0)

    INBOX_SKILLS.mkdir(parents=True, exist_ok=True)

    captured_at = datetime.now(timezone.utc).astimezone().strftime("%Y-%m-%dT%H:%M:%S%z")

    written = 0
    unchanged = 0
    failed = 0

    # Scan top-level skill dirs only — depth 1. Plugin skills (skills/<plugin>/<skill>/SKILL.md)
    # are managed by their plugins; we only snapshot user-authored top-level skills.
    for skill_dir in sorted(SKILLS_SRC.iterdir()):
        if not skill_dir.is_dir():
            continue
        skill_md = skill_dir / "SKILL.md"
        if not skill_md.is_file():
            continue

        record = snapshot_skill(skill_md)
        if record is None:
            failed += 1
            continue

        content = render_snapshot(record, captured_at)
        dst = INBOX_SKILLS / f"{safe_filename(record['name'])}.md"

        if existing_matches(dst, content):
            unchanged += 1
            continue

        dst.write_text(content, encoding="utf-8")
        written += 1

    print(f"Skills snapshot: {written} written, {unchanged} unchanged, {failed} failed.")


if __name__ == "__main__":
    main()
