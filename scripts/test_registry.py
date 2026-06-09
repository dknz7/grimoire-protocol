"""Stdlib test harness for registry.py. Run: python test_registry.py"""
import importlib.util
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent


def load_registry(vault: Path):
    """Import registry.py with VAULT patched to a temp dir."""
    spec = importlib.util.spec_from_file_location("registry", HERE / "registry.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.VAULT = vault
    return mod


def make_vault(tmp: Path):
    """Scaffold a minimal vault: firehose dirs, a summaries dir, a processed file slot."""
    for d in ["inbox/sessions", "inbox/tldr", "inbox/daily", "inbox/drops",
              "inbox/skills", "wiki/summaries"]:
        (tmp / d).mkdir(parents=True, exist_ok=True)
    return tmp


def write(p: Path, text: str):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")


def test_pending_counts_only_firehose():
    with tempfile.TemporaryDirectory() as t:
        vault = make_vault(Path(t))
        write(vault / "inbox/sessions/a.md", "x")
        write(vault / "inbox/tldr/b.md", "x")
        write(vault / "inbox/skills/snap.md", "x")          # excluded
        write(vault / "projects/foo/context.md", "x")        # excluded (reference dir)
        r = load_registry(vault)
        pending = r.compute_pending()
        assert set(pending) == {"inbox/sessions/a.md", "inbox/tldr/b.md"}, pending
        print("PASS test_pending_counts_only_firehose")


def test_summary_credits_source():
    with tempfile.TemporaryDirectory() as t:
        vault = make_vault(Path(t))
        write(vault / "inbox/daily/2026-04-24-today.md", "content")
        write(vault / "wiki/summaries/2026-04-24-today.md",
              "---\nsource: inbox/daily/2026-04-24-today.md\n---\nsummary")
        r = load_registry(vault)
        processed = r.summary_sources()
        assert processed == {"inbox/daily/2026-04-24-today.md":
                             "wiki/summaries/2026-04-24-today.md"}, processed
        assert r.compute_pending() == [], r.compute_pending()
        print("PASS test_summary_credits_source")


def test_orphan_credited_by_basename_fallback():
    with tempfile.TemporaryDirectory() as t:
        vault = make_vault(Path(t))
        write(vault / "inbox/sessions/sess1.md", "content")
        # summary with NO source frontmatter — must fall back to basename match
        write(vault / "wiki/summaries/sess1.md", "no frontmatter summary")
        r = load_registry(vault)
        assert r.summary_sources() == {"inbox/sessions/sess1.md":
                                       "wiki/summaries/sess1.md"}
        print("PASS test_orphan_credited_by_basename_fallback")


def test_reconcile_writes_processed_file():
    with tempfile.TemporaryDirectory() as t:
        vault = make_vault(Path(t))
        write(vault / "inbox/daily/done.md", "content")
        write(vault / "wiki/summaries/done.md",
              "---\nsource: inbox/daily/done.md\n---\ns")
        write(vault / "inbox/tldr/todo.md", "content")
        r = load_registry(vault)
        pending_count = r.cmd_reconcile()
        text = (vault / "wiki/processed.md").read_text(encoding="utf-8")
        assert "inbox/daily/done.md" in text, text
        assert "wiki/summaries/done.md" in text, text
        assert pending_count == 1, pending_count           # todo.md still pending
        print("PASS test_reconcile_writes_processed_file")


def test_mark_is_idempotent():
    with tempfile.TemporaryDirectory() as t:
        vault = make_vault(Path(t))
        write(vault / "inbox/sessions/x.md", "content")
        r = load_registry(vault)
        r.cmd_reconcile()
        r.cmd_mark("inbox/sessions/x.md", "wiki/summaries/x.md")
        r.cmd_mark("inbox\\sessions\\x.md", "wiki\\summaries\\x.md")  # backslash dupe
        text = (vault / "wiki/processed.md").read_text(encoding="utf-8")
        assert text.count("inbox/sessions/x.md") == 1, text
        print("PASS test_mark_is_idempotent")


def test_ambiguous_basename_fallback_is_skipped():
    with tempfile.TemporaryDirectory() as t:
        vault = make_vault(Path(t))
        write(vault / "inbox/sessions/notes.md", "content")
        write(vault / "inbox/drops/notes.md", "content")          # same basename
        write(vault / "wiki/summaries/notes.md", "no frontmatter")  # ambiguous
        r = load_registry(vault)
        # Neither source may be credited via the ambiguous fallback.
        assert r.summary_sources() == {}, r.summary_sources()
        print("PASS test_ambiguous_basename_fallback_is_skipped")


def test_load_processed_skips_header_and_separator():
    with tempfile.TemporaryDirectory() as t:
        vault = make_vault(Path(t))
        write(vault / "wiki/processed.md",
              "# x\n\n| Source | Summary |\n|--------|---------|\n"
              "| inbox/sessions/a.md | wiki/summaries/a.md |\n")
        r = load_registry(vault)
        got = r.load_processed()
        assert got == {"inbox/sessions/a.md": "wiki/summaries/a.md"}, got
        print("PASS test_load_processed_skips_header_and_separator")


if __name__ == "__main__":
    test_pending_counts_only_firehose()
    test_summary_credits_source()
    test_orphan_credited_by_basename_fallback()
    test_reconcile_writes_processed_file()
    test_mark_is_idempotent()
    test_ambiguous_basename_fallback_is_skipped()
    test_load_processed_skips_header_and_separator()
    print("\nAll registry tests passed.")
