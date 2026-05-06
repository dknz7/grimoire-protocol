#!/bin/bash
#
# Grimoire Protocol — Vault Setup Script (macOS / Linux)
#
# Usage:
#   ./scaffold.sh /path/to/your/vault [/path/to/grimoire-binary]
#
# If no binary path is provided, the script will offer to build from source.

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║       GRIMOIRE PROTOCOL SETUP        ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"

# --- Arg parsing ---
VAULT_ROOT="${1:-}"
BINARY_PATH="${2:-}"

if [ -z "$VAULT_ROOT" ]; then
    echo -e "${YELLOW}Where is your Obsidian vault (or target folder)?${NC}"
    read -rp "> " VAULT_ROOT
fi

VAULT_ROOT="$(cd "$VAULT_ROOT" 2>/dev/null && pwd || echo "$VAULT_ROOT")"

if [ ! -d "$VAULT_ROOT" ]; then
    echo -e "${RED}Vault directory does not exist: $VAULT_ROOT${NC}"
    exit 1
fi

echo -e "${GREEN}Vault root:${NC} $VAULT_ROOT"
echo ""

# --- Binary ---
GRIMOIRE_DIR="$VAULT_ROOT/.grimoire"
mkdir -p "$GRIMOIRE_DIR"

if [ -n "$BINARY_PATH" ] && [ -f "$BINARY_PATH" ]; then
    echo -e "${GREEN}Copying grimoire binary...${NC}"
    cp "$BINARY_PATH" "$GRIMOIRE_DIR/grimoire"
    chmod +x "$GRIMOIRE_DIR/grimoire"
elif [ -f "$GRIMOIRE_DIR/grimoire" ]; then
    echo -e "${GREEN}Grimoire binary already exists at $GRIMOIRE_DIR/grimoire${NC}"
else
    echo -e "${YELLOW}No grimoire binary found.${NC}"
    echo "Options:"
    echo "  1) Build from source (requires Go 1.22+ and Node.js)"
    echo "  2) I'll place the binary manually later"
    read -rp "Choice [1/2]: " BUILD_CHOICE

    if [ "$BUILD_CHOICE" = "1" ]; then
        # Check prerequisites
        if ! command -v go &>/dev/null; then
            echo -e "${RED}Go not found. Install from https://go.dev/dl/${NC}"
            exit 1
        fi
        if ! command -v npm &>/dev/null; then
            echo -e "${RED}npm not found. Install Node.js from https://nodejs.org/${NC}"
            exit 1
        fi

        echo -e "${CYAN}Cloning sage-wiki engine...${NC}"
        TMPDIR=$(mktemp -d)
        git clone --depth 1 https://github.com/xoai/sage-wiki.git "$TMPDIR/sage-wiki"

        echo -e "${CYAN}Building web UI frontend...${NC}"
        cd "$TMPDIR/sage-wiki/web"
        npm install --silent
        npm run build --silent

        echo -e "${CYAN}Compiling grimoire binary...${NC}"
        cd "$TMPDIR/sage-wiki"
        go build -tags webui -o "$GRIMOIRE_DIR/grimoire" ./cmd/sage-wiki/
        chmod +x "$GRIMOIRE_DIR/grimoire"

        echo -e "${CYAN}Cleaning up build files...${NC}"
        rm -rf "$TMPDIR"
        cd "$VAULT_ROOT"

        echo -e "${GREEN}Binary built: $GRIMOIRE_DIR/grimoire${NC}"
    else
        echo -e "${YELLOW}Place your grimoire binary at: $GRIMOIRE_DIR/grimoire${NC}"
        echo "You can download pre-built binaries from GitHub Releases."
    fi
fi

echo ""

# --- Vault structure ---
echo -e "${CYAN}Creating vault structure...${NC}"

# Inbox
mkdir -p "$VAULT_ROOT/inbox/sessions"
mkdir -p "$VAULT_ROOT/inbox/tldr"
mkdir -p "$VAULT_ROOT/inbox/daily"
mkdir -p "$VAULT_ROOT/inbox/drops"
mkdir -p "$VAULT_ROOT/inbox/skills"   # populated by snapshot-skills.py before each compile

# Wiki
for dir in concepts entities sources connections questions meta; do
    mkdir -p "$VAULT_ROOT/wiki/$dir"
done

# Engine storage
mkdir -p "$VAULT_ROOT/.sage"

# Hook scripts
mkdir -p "$VAULT_ROOT/scripts/grimoire"

echo -e "${GREEN}Directories created.${NC}"

# --- Wiki seed files ---
echo -e "${CYAN}Seeding wiki files...${NC}"

TODAY=$(date +%Y-%m-%d)

if [ ! -f "$VAULT_ROOT/wiki/hot.md" ]; then
cat > "$VAULT_ROOT/wiki/hot.md" << HOTEOF
---
type: meta
title: Hot Cache
updated: $TODAY
tags: [meta, grimoire]
status: evergreen
---

# Grimoire — Recent Context

Navigation: [[index]] | [[log]] | [[overview]]

## Last Compiled
(no compiles yet)

## Active Threads
(empty — will populate after first compile)

## Key Recent Facts
(empty — will populate after first compile)
HOTEOF
fi

if [ ! -f "$VAULT_ROOT/wiki/index.md" ]; then
cat > "$VAULT_ROOT/wiki/index.md" << IDXEOF
---
type: meta
title: Grimoire Index
updated: $TODAY
tags: [meta, grimoire]
status: evergreen
---

# Grimoire — Master Index

| Article | Type | Domain | Updated |
|---------|------|--------|---------|

*Run \`/grimoire compile\` to populate.*
IDXEOF
fi

if [ ! -f "$VAULT_ROOT/wiki/log.md" ]; then
cat > "$VAULT_ROOT/wiki/log.md" << LOGEOF
---
type: meta
title: Grimoire Log
updated: $TODAY
tags: [meta, grimoire]
status: evergreen
---

# Grimoire — Operation Log

*Newest entries at top. Timestamps in 24hr format.*
LOGEOF
fi

if [ ! -f "$VAULT_ROOT/wiki/overview.md" ]; then
cat > "$VAULT_ROOT/wiki/overview.md" << OVREOF
---
type: meta
title: Grimoire Overview
updated: $TODAY
tags: [meta, grimoire]
status: evergreen
---

# Grimoire — Executive Summary

*Auto-generated after first compile. Summarises the entire knowledge base.*
OVREOF
fi

# Sub-indexes
for category in concepts entities sources connections questions; do
    idx="$VAULT_ROOT/wiki/$category/_index.md"
    if [ ! -f "$idx" ]; then
        TITLE="$(echo "$category" | sed 's/./\U&/')"
cat > "$idx" << SUBEOF
---
type: meta
title: "$TITLE Index"
updated: $TODAY
tags: [meta, grimoire, $category]
status: evergreen
---

# $TITLE

| Article | Summary | Sources | Updated |
|---------|---------|---------|---------|

*Populated by \`/grimoire compile\`.*
SUBEOF
    fi
done

echo -e "${GREEN}Wiki seeded.${NC}"

# --- Copy skills (with {{VAULT_ROOT}} substitution) ---
echo -e "${CYAN}Copying skills (filling in vault path)...${NC}"
SKILLS_SRC="$SCRIPT_DIR/skills"
SKILLS_DST="$VAULT_ROOT/.claude/skills"
mkdir -p "$SKILLS_DST"

if [ -d "$SKILLS_SRC" ]; then
    skill_count=0
    for skill_dir in "$SKILLS_SRC"/*/; do
        skill_name=$(basename "$skill_dir")
        mkdir -p "$SKILLS_DST/$skill_name"
        # Substitute {{VAULT_ROOT}} with the actual vault path. Use awk's literal
        # index/substr so any character (\, &, |, spaces) in the path passes through cleanly.
        awk -v old='{{VAULT_ROOT}}' -v new="$VAULT_ROOT" '{
            while ((i = index($0, old)) > 0) {
                $0 = substr($0, 1, i-1) new substr($0, i + length(old))
            }
            print
        }' "$skill_dir/SKILL.md" > "$SKILLS_DST/$skill_name/SKILL.md"
        skill_count=$((skill_count + 1))
    done
    echo -e "${GREEN}$skill_count skills copied (vault path filled in).${NC}"
else
    echo -e "${YELLOW}No skills directory found at $SKILLS_SRC — skipping.${NC}"
fi

# --- Copy hooks ---
echo -e "${CYAN}Copying hook scripts...${NC}"
HOOKS_SRC="$SCRIPT_DIR/hooks"
HOOKS_DST="$VAULT_ROOT/scripts/grimoire"

if [ -d "$HOOKS_SRC" ]; then
    cp "$HOOKS_SRC"/*.py "$HOOKS_DST/"
    echo -e "${GREEN}Hooks copied to $HOOKS_DST${NC}"
else
    echo -e "${YELLOW}No hooks directory found — skipping.${NC}"
fi

# --- Config files ---
echo -e "${CYAN}Setting up configuration...${NC}"

# Engine config (always in vault root)
if [ ! -f "$VAULT_ROOT/config.yaml" ]; then
    cp "$SCRIPT_DIR/config/config.yaml.template" "$VAULT_ROOT/config.yaml"
    echo -e "${GREEN}config.yaml created — customise your source folders and timezone.${NC}"
else
    echo -e "${YELLOW}config.yaml already exists — skipping.${NC}"
fi

# Detect Python path for hooks
PYTHON_PATH="python3"
if command -v python3 &>/dev/null; then
    PYTHON_PATH="$(command -v python3)"
elif command -v python &>/dev/null; then
    PYTHON_PATH="$(command -v python)"
fi

# --- MCP config (smart detection) ---
echo ""
echo -e "${CYAN}Detecting MCP configuration...${NC}"
echo "  The grimoire engine registers 15 MCP tools (13 auto-approved)."
echo ""

# Scan known locations for files containing mcpServers
MCP_CANDIDATES=()
MCP_CANDIDATE_LABELS=()

# Check common locations
for candidate in \
    "$HOME/.claude.json" \
    "$HOME/.claude/settings.json" \
    "$HOME/.claude/.mcp.json" \
    "$HOME/Library/Application Support/Claude/claude_desktop_config.json" \
    "$VAULT_ROOT/.mcp.json"; do
    if [ -f "$candidate" ] && grep -q "mcpServers" "$candidate" 2>/dev/null; then
        MCP_CANDIDATES+=("$candidate")
        MCP_CANDIDATE_LABELS+=("$candidate (has mcpServers)")
    fi
done

# Also check for files that exist but DON'T have mcpServers yet
for candidate in \
    "$HOME/.claude.json" \
    "$HOME/.claude/settings.json" \
    "$VAULT_ROOT/.mcp.json"; do
    if [ -f "$candidate" ] && ! grep -q "mcpServers" "$candidate" 2>/dev/null; then
        # Only add if not already in the list
        already=false
        for existing in "${MCP_CANDIDATES[@]}"; do
            [ "$existing" = "$candidate" ] && already=true
        done
        if ! $already; then
            MCP_CANDIDATES+=("$candidate")
            MCP_CANDIDATE_LABELS+=("$candidate (exists, no mcpServers yet)")
        fi
    fi
done

MCP_JSON_SNIPPET=$(cat <<SNIPPETEOF
"grimoire": {
  "type": "stdio",
  "command": "$GRIMOIRE_DIR/grimoire",
  "args": ["serve", "--project", "$VAULT_ROOT"],
  "env": {}
}
SNIPPETEOF
)

if [ ${#MCP_CANDIDATES[@]} -gt 0 ]; then
    echo -e "${YELLOW}Found these config files on your system:${NC}"
    echo ""
    for i in "${!MCP_CANDIDATES[@]}"; do
        echo "  $((i+1))) ${MCP_CANDIDATE_LABELS[$i]}"
    done
    echo "  $((${#MCP_CANDIDATES[@]}+1))) Enter a custom path"
    echo "  $((${#MCP_CANDIDATES[@]}+2))) Skip — I'll do it manually"
    echo ""
    read -rp "Which file should grimoire be added to? " MCP_CHOICE

    if [ "$MCP_CHOICE" -le "${#MCP_CANDIDATES[@]}" ] 2>/dev/null; then
        MCP_TARGET="${MCP_CANDIDATES[$((MCP_CHOICE-1))]}"
        echo ""
        echo -e "${YELLOW}Add this to the mcpServers section in: $MCP_TARGET${NC}"
        echo ""
        echo "$MCP_JSON_SNIPPET"
        echo ""
        echo -e "${YELLOW}If the file already has mcpServers, add the grimoire entry inside it.${NC}"
        echo -e "${YELLOW}If it doesn't have mcpServers yet, add: \"mcpServers\": { <the above> }${NC}"
    elif [ "$MCP_CHOICE" = "$((${#MCP_CANDIDATES[@]}+1))" ]; then
        read -rp "Path to your config file: " MCP_TARGET
        echo ""
        echo -e "${YELLOW}Add this to the mcpServers section in: $MCP_TARGET${NC}"
        echo ""
        echo "$MCP_JSON_SNIPPET"
        echo ""
    else
        echo -e "${YELLOW}Skipped. You'll need to add the MCP config manually.${NC}"
    fi
else
    echo -e "${YELLOW}No existing MCP config files found.${NC}"
    echo "  Common locations:"
    echo "    macOS/Linux:  ~/.claude.json or ~/.claude/settings.json"
    echo "    Windows:      %USERPROFILE%\\.claude.json"
    echo "    Project-level: <vault>/.mcp.json"
    echo ""
    echo "  Check which file your other MCP servers (if any) are configured in,"
    echo "  then add this to its mcpServers section:"
    echo ""
    echo "$MCP_JSON_SNIPPET"
fi

echo ""

# --- Hooks config (smart detection) ---
echo -e "${CYAN}Hooks configuration...${NC}"
echo "  Hooks use absolute paths so they work from any Claude Code session."
echo ""

SESSION_START_CMD="$PYTHON_PATH $VAULT_ROOT/scripts/grimoire/session-start.py"
SESSION_END_CMD="$PYTHON_PATH $VAULT_ROOT/scripts/grimoire/session-end.py"
PRE_COMPACT_CMD="$PYTHON_PATH $VAULT_ROOT/scripts/grimoire/pre-compact.py"

# Scan for settings files that could hold hooks
HOOKS_CANDIDATES=()
for candidate in \
    "$HOME/.claude.json" \
    "$HOME/.claude/settings.json" \
    "$HOME/.claude/settings.local.json" \
    "$VAULT_ROOT/.claude/settings.local.json"; do
    if [ -f "$candidate" ]; then
        HOOKS_CANDIDATES+=("$candidate")
    fi
done

echo -e "${YELLOW}Hooks need to be added to your Claude Code settings.${NC}"
echo ""
echo "  Check which file holds your existing hooks or permissions,"
echo "  then merge in the grimoire hooks. Common locations:"
echo ""
for candidate in "${HOOKS_CANDIDATES[@]}"; do
    echo "    - $candidate"
done
[ ${#HOOKS_CANDIDATES[@]} -eq 0 ] && echo "    (no settings files found)"
echo ""
echo "  Hook commands (use these exact strings with absolute paths):"
echo ""
echo "    SessionStart: $SESSION_START_CMD"
echo "    SessionEnd:   $SESSION_END_CMD"
echo "    PreCompact:   $PRE_COMPACT_CMD"
echo ""
echo "  See config/settings-hooks.json.template for the full JSON structure."
echo ""

# Obsidian CSS
if [ -d "$VAULT_ROOT/.obsidian" ]; then
    mkdir -p "$VAULT_ROOT/.obsidian/snippets"
    cp "$SCRIPT_DIR/obsidian/snippets/grimoire-colors.css" "$VAULT_ROOT/.obsidian/snippets/"
    echo -e "${GREEN}Obsidian CSS snippet installed. Enable it in Settings > Appearance > CSS Snippets.${NC}"
fi

echo ""
echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         ${GREEN}SETUP COMPLETE!${CYAN}              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
echo ""
echo "Next steps:"
echo "  1. Customise config.yaml (source folders, timezone)"
echo "  2. If you had existing config files, merge the grimoire entries shown above"
echo "  3. Restart Claude Code"
echo "  4. Run: /grimoire status"
echo "  5. Drop a file in inbox/drops/ and run: /grimoire compile"
echo ""
echo -e "${GREEN}The grimoire awaits.${NC}"
