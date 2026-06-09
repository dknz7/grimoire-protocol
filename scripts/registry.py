#!/usr/bin/env python3
"""
Grimoire Processed Registry — the authoritative ledger of compiled sources.

A source is "processed" iff a summary file exists for it on disk
(wiki/summaries/<name>.md), NOT when the engine manifest flag says so. The
manifest flag is unreliable on Windows: the engine walks disk with backslash
paths (filepath.Rel) but stores/looks-up forward-slash keys, so MarkCompiled
silently misses and sources stay "pending" forever. This registry bypasses
that entirely by trusting disk truth.

Subcommands:
  reconcile  Rebuild wiki/processed.md from on-disk summaries. Prints pending count.
  pending    List firehose sources with no summary yet (one per line).
  mark SRC SUMMARY   Append a processed source to wiki/processed.md (idempotent).

Forward-slash paths only. Python 3.12+ stdlib. No pip deps.
"""
from __future__ import annotations

import sys
from datetime import datetime, timezone
from pathlib import Path

# Vault root = two levels up from scripts/grimoire/
VAULT = Path(__file__).resolve().parent.parent.parent

# The capture firehose — the daily knowledge stream the nightly tracks.
# Reference dirs (projects/research/resources/templates/work) are on-demand
# compile targets, NOT nightly-tracked. inbox/skills is excluded (auto-generated
# snapshots, captured in [[Archie Skills Catalogue]]).
WATCH_DIRS = [
    "inbox/sessions",
    "inbox/tldr",
    "inbox/daily",
    "inbox/drops",
]
SUMMARIES_DIR = "wiki/summaries"
PROCESSED_FILE = "wiki/processed.md"

def _norm(value: str) -> str:
    """Forward-slash, no leading slash."""
    return str(value).replace("\\", "/").lstrip("/")


def compute_pending() -> list[str]:
    """Firehose sources on disk that have no summary yet."""
    done = set(summary_sources().keys())
    return [s for s in iter_sources() if s not in done]


def iter_sources():
    """Yield vault-relative forward-slash paths for every firehose markdown file."""
    for d in WATCH_DIRS:
        base = VAULT / d
        if not base.exists():
            continue
        for f in sorted(base.rglob("*.md")):
            if f.name.startswith(".") or f.name == "_index.md":
                continue
            yield d + "/" + f.relative_to(base).as_posix()


def _read_frontmatter_source(summary: Path) -> str | None:
    """Return the `source:` value from a summary's YAML frontmatter, if present."""
    try:
        text = summary.read_text(encoding="utf-8")
    except OSError:
        return None
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None
    for line in text[3:end].splitlines():
        line = line.strip()
        if line.startswith("source:"):
            val = line.split(":", 1)[1].strip().strip('"').strip("'")
            return _norm(val)
    return None


def summary_sources() -> dict[str, str]:
    """Map {source_path: summary_path} for every summary that credits a real source."""
    out: dict[str, str] = {}
    sdir = VAULT / SUMMARIES_DIR
    if not sdir.exists():
        return out
    # Basename->source for the fallback, but drop basenames shared by >1 source
    # so a summary without frontmatter can never be credited to an arbitrary file.
    seen: dict[str, str] = {}
    ambiguous: set[str] = set()
    for s in iter_sources():
        b = Path(s).name
        if b in seen:
            ambiguous.add(b)
        else:
            seen[b] = s
    by_basename = {b: s for b, s in seen.items() if b not in ambiguous}
    for sm in sorted(sdir.glob("*.md")):
        if sm.name == "_index.md":
            continue
        src = _read_frontmatter_source(sm)
        if not src or not (VAULT / src).exists():
            src = by_basename.get(sm.name)  # fallback: unambiguous basename match
        if src:
            out[src] = SUMMARIES_DIR + "/" + sm.name
    return out


def _today() -> str:
    return datetime.now(timezone.utc).astimezone().strftime("%Y-%m-%d")


def _render(processed: dict[str, str]) -> str:
    lines = [
        "---",
        "type: meta",
        "title: Processed Registry",
        f"updated: {_today()}",
        "tags: [meta, grimoire]",
        "status: evergreen",
        "---",
        "",
        "# Grimoire — Processed Registry",
        "",
        "Authoritative ledger of compiled sources. The Dream Sequence trusts THIS,",
        "not the engine's manifest counter. A source is processed iff a summary",
        "exists for it on disk. Forward-slash paths only (Windows-safe).",
        "",
        "Pending = firehose sources on disk (`inbox/{sessions,tldr,daily,drops}`)",
        "minus this list. Reference dirs and `inbox/skills` are not tracked here.",
        "",
        "| Source | Summary |",
        "|--------|---------|",
    ]
    for src in sorted(processed):
        lines.append(f"| {src} | {processed[src]} |")
    lines.append("")
    return "\n".join(lines)


def load_processed() -> dict[str, str]:
    """Parse wiki/processed.md back into {source: summary}."""
    pf = VAULT / PROCESSED_FILE
    out: dict[str, str] = {}
    if not pf.exists():
        return out
    for line in pf.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        parts = [p.strip() for p in line.strip("|").split("|")]
        if len(parts) < 2:
            continue
        src, summary = parts[0], parts[1]
        if src in ("", "Source") or set(src) <= {"-"}:  # skip header / separator
            continue
        out[_norm(src)] = _norm(summary)
    return out


def cmd_reconcile() -> int:
    """Rebuild processed.md from on-disk summaries. Returns pending count."""
    processed = summary_sources()
    (VAULT / PROCESSED_FILE).write_text(_render(processed), encoding="utf-8")
    pending = compute_pending()
    print(f"Reconciled: {len(processed)} processed, {len(pending)} pending.")
    return len(pending)


def cmd_pending() -> int:
    pending = compute_pending()
    for p in pending:
        print(p)
    return len(pending)


def cmd_mark(source: str, summary: str) -> None:
    """Add one processed source to processed.md (idempotent, path-normalised)."""
    source = _norm(source)
    summary = _norm(summary)
    processed = load_processed()
    if not processed:
        processed = summary_sources()
    processed[source] = summary
    (VAULT / PROCESSED_FILE).write_text(_render(processed), encoding="utf-8")
    print(f"Marked processed: {source}")


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    cmd = argv[0]
    if cmd == "reconcile":
        cmd_reconcile()
        return 0
    if cmd == "pending":
        cmd_pending()
        return 0
    if cmd == "mark":
        if len(argv) < 3:
            print("usage: registry.py mark <source> <summary>")
            return 2
        cmd_mark(argv[1], argv[2])
        return 0
    print(f"unknown subcommand: {cmd}")
    print(__doc__)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
