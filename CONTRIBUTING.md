# Contributing to Grimoire Protocol

First off — thanks for being interested. This project is early and actively evolving, so your input genuinely matters.

## Current State

Grimoire Protocol is a personal project that grew into something shareable. It's functional and in daily use, but there's plenty of room to improve. The architecture is documented in [`docs/architecture.md`](docs/architecture.md).

**Important context:** Grimoire Protocol is an integration layer, not a standalone engine. The compilation engine is [sage-wiki](https://github.com/xoai/sage-wiki) — a separate Go project. We don't fork or bundle sage-wiki; the scaffold scripts clone and build it at setup time.

## How to Help

### Report Bugs

[Open an issue](../../issues/new). Include:
- Your OS (Windows/macOS/Linux)
- How you installed (scaffold script vs manual)
- What you expected vs what happened
- Any error output from `scripts/grimoire/grimoire-hooks.log` if relevant

### Suggest Features

[Open an issue](../../issues/new) with the `enhancement` label. Describe:
- What problem it solves
- How you'd expect it to work
- Whether it affects the engine (sage-wiki) or the integration layer (this repo)

### Submit Changes

**Please file an issue before opening a PR.** This lets us discuss the approach before you invest time coding.

When you're ready:

1. Fork the repo
2. Create a branch (`git checkout -b fix/your-fix-name`)
3. Make your changes
4. Test with a real vault (clone → scaffold → compile → query)
5. Commit with a clear message
6. Open a PR referencing the issue

### What Lives Where

| Change Type | Where |
|---|---|
| Skill logic (prompts, steps, triggers) | `skills/*/SKILL.md` |
| Hook scripts (capture, injection) | `hooks/*.py` |
| Config templates | `config/*.template` |
| Setup automation | `scaffold.sh`, `scaffold.ps1` |
| Obsidian integration | `obsidian/` |
| Documentation | `docs/`, `README.md` |
| Engine bugs/features | Upstream at [xoai/sage-wiki](https://github.com/xoai/sage-wiki) |

### Skill Conventions

If you're modifying or adding skills:
- Use `{{VAULT_ROOT}}` for vault path references
- All dates: `YYYY-MM-DD` (ISO 8601)
- All timestamps: 24hr format, never AM/PM
- Keep frontmatter flat YAML (Obsidian-compatible)
- Use `[[wikilinks]]` for cross-references
- Include natural language triggers in the skill `description` field

## Dev Environment Setup

1. Clone the repo
2. Run `scaffold.sh` or `scaffold.ps1` against a test vault
3. Build the engine: clone sage-wiki, build with `go build -tags webui`
4. Open Claude Code in the test vault
5. Verify with `/grimoire status`

## Code of Conduct

Be decent. Be helpful. Don't be a jerk. If someone's stuck, help them out. If someone's wrong, be kind about it. We're all here to build something useful.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
