#
# Grimoire Protocol — Vault Setup Script (Windows PowerShell)
#
# Usage:
#   .\scaffold.ps1 -VaultPath "C:\path\to\vault" [-BinaryPath "C:\path\to\grimoire.exe"]
#
# If no binary path is provided, the script will offer to build from source.

param(
    [Parameter(Mandatory=$true)]
    [string]$VaultPath,

    [string]$BinaryPath
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "  +==============================================+" -ForegroundColor Cyan
Write-Host "  |         GRIMOIRE PROTOCOL SETUP              |" -ForegroundColor Cyan
Write-Host "  +==============================================+" -ForegroundColor Cyan
Write-Host ""

# --- Validate vault ---
if (-not (Test-Path $VaultPath -PathType Container)) {
    Write-Host "Vault directory does not exist: $VaultPath" -ForegroundColor Red
    exit 1
}

$VaultPath = (Resolve-Path $VaultPath).Path
Write-Host "Vault root: $VaultPath" -ForegroundColor Green
Write-Host ""

# --- Binary ---
$GrimoireDir = Join-Path $VaultPath ".grimoire"
New-Item -ItemType Directory -Path $GrimoireDir -Force | Out-Null
$BinaryDest = Join-Path $GrimoireDir "grimoire.exe"

if ($BinaryPath -and (Test-Path $BinaryPath)) {
    Write-Host "Copying grimoire binary..." -ForegroundColor Green
    Copy-Item $BinaryPath $BinaryDest -Force
} elseif (Test-Path $BinaryDest) {
    Write-Host "Grimoire binary already exists at $BinaryDest" -ForegroundColor Green
} else {
    Write-Host "No grimoire binary found." -ForegroundColor Yellow
    Write-Host "Options:"
    Write-Host "  1) Build from source (requires Go 1.22+ and Node.js)"
    Write-Host "  2) I'll place the binary manually later"
    $choice = Read-Host "Choice [1/2]"

    if ($choice -eq "1") {
        # Check prerequisites
        try { $null = Get-Command go -ErrorAction Stop } catch {
            Write-Host "Go not found. Install from https://go.dev/dl/" -ForegroundColor Red
            exit 1
        }
        try { $null = Get-Command npm -ErrorAction Stop } catch {
            Write-Host "npm not found. Install Node.js from https://nodejs.org/" -ForegroundColor Red
            exit 1
        }

        $TmpDir = Join-Path $env:TEMP "grimoire-build-$(Get-Random)"
        New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null

        Write-Host "Cloning sage-wiki engine..." -ForegroundColor Cyan
        git clone --depth 1 https://github.com/xoai/sage-wiki.git "$TmpDir\sage-wiki"

        Write-Host "Building web UI frontend..." -ForegroundColor Cyan
        Push-Location "$TmpDir\sage-wiki\web"
        npm install --silent
        npm run build --silent
        Pop-Location

        Write-Host "Compiling grimoire binary..." -ForegroundColor Cyan
        Push-Location "$TmpDir\sage-wiki"
        go build -tags webui -o $BinaryDest ./cmd/sage-wiki/
        Pop-Location

        Write-Host "Cleaning up build files..." -ForegroundColor Cyan
        Remove-Item -Recurse -Force $TmpDir

        Write-Host "Binary built: $BinaryDest" -ForegroundColor Green
    } else {
        Write-Host "Place your grimoire.exe at: $BinaryDest" -ForegroundColor Yellow
        Write-Host "You can download pre-built binaries from GitHub Releases."
    }
}

Write-Host ""

# --- Vault structure ---
Write-Host "Creating vault structure..." -ForegroundColor Cyan

$dirs = @(
    "inbox\sessions", "inbox\tldr", "inbox\daily", "inbox\drops",
    "wiki\concepts", "wiki\entities", "wiki\sources", "wiki\connections", "wiki\questions", "wiki\meta",
    ".sage",
    "scripts\grimoire"
)

foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Path (Join-Path $VaultPath $dir) -Force | Out-Null
}

Write-Host "Directories created." -ForegroundColor Green

# --- Wiki seed files ---
Write-Host "Seeding wiki files..." -ForegroundColor Cyan

$Today = Get-Date -Format "yyyy-MM-dd"

$seedFiles = @{
    "wiki\hot.md" = @"
---
type: meta
title: Hot Cache
updated: $Today
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
"@
    "wiki\index.md" = @"
---
type: meta
title: Grimoire Index
updated: $Today
tags: [meta, grimoire]
status: evergreen
---

# Grimoire — Master Index

| Article | Type | Domain | Updated |
|---------|------|--------|---------|

*Run ``/grimoire compile`` to populate.*
"@
    "wiki\log.md" = @"
---
type: meta
title: Grimoire Log
updated: $Today
tags: [meta, grimoire]
status: evergreen
---

# Grimoire — Operation Log

*Newest entries at top. Timestamps in 24hr format.*
"@
    "wiki\overview.md" = @"
---
type: meta
title: Grimoire Overview
updated: $Today
tags: [meta, grimoire]
status: evergreen
---

# Grimoire — Executive Summary

*Auto-generated after first compile. Summarises the entire knowledge base.*
"@
}

foreach ($file in $seedFiles.GetEnumerator()) {
    $path = Join-Path $VaultPath $file.Key
    if (-not (Test-Path $path)) {
        $file.Value | Out-File -FilePath $path -Encoding utf8
    }
}

# Sub-indexes
foreach ($cat in @("concepts", "entities", "sources", "connections", "questions")) {
    $idx = Join-Path $VaultPath "wiki\$cat\_index.md"
    if (-not (Test-Path $idx)) {
        $title = (Get-Culture).TextInfo.ToTitleCase($cat)
        @"
---
type: meta
title: "$title Index"
updated: $Today
tags: [meta, grimoire, $cat]
status: evergreen
---

# $title

| Article | Summary | Sources | Updated |
|---------|---------|---------|---------|

*Populated by ``/grimoire compile``.*
"@ | Out-File -FilePath $idx -Encoding utf8
    }
}

Write-Host "Wiki seeded." -ForegroundColor Green

# --- Copy skills ---
Write-Host "Copying skills..." -ForegroundColor Cyan
$SkillsSrc = Join-Path $ScriptDir "skills"
$SkillsDst = Join-Path $VaultPath ".claude\skills"

if (Test-Path $SkillsSrc) {
    $count = 0
    Get-ChildItem -Path $SkillsSrc -Directory | ForEach-Object {
        $dst = Join-Path $SkillsDst $_.Name
        New-Item -ItemType Directory -Path $dst -Force | Out-Null
        Copy-Item (Join-Path $_.FullName "SKILL.md") (Join-Path $dst "SKILL.md") -Force
        $count++
    }
    Write-Host "$count skills copied." -ForegroundColor Green
} else {
    Write-Host "No skills directory found — skipping." -ForegroundColor Yellow
}

# --- Copy hooks ---
Write-Host "Copying hook scripts..." -ForegroundColor Cyan
$HooksSrc = Join-Path $ScriptDir "hooks"
$HooksDst = Join-Path $VaultPath "scripts\grimoire"

if (Test-Path $HooksSrc) {
    Copy-Item "$HooksSrc\*.py" $HooksDst -Force
    Write-Host "Hooks copied to $HooksDst" -ForegroundColor Green
} else {
    Write-Host "No hooks directory found — skipping." -ForegroundColor Yellow
}

# --- Config files ---
Write-Host "Setting up configuration..." -ForegroundColor Cyan

# Engine config (always in vault root)
$configPath = Join-Path $VaultPath "config.yaml"
if (-not (Test-Path $configPath)) {
    Copy-Item (Join-Path $ScriptDir "config\config.yaml.template") $configPath
    Write-Host "config.yaml created — customise your source folders and timezone." -ForegroundColor Green
} else {
    Write-Host "config.yaml already exists — skipping." -ForegroundColor Yellow
}

# Detect Python path
$PythonPath = "python3"
try {
    $PythonPath = (Get-Command python3 -ErrorAction Stop).Source
} catch {
    try {
        $PythonPath = (Get-Command python -ErrorAction Stop).Source
    } catch {
        Write-Host "Python not found in PATH. You'll need to set the Python path manually in the hooks config." -ForegroundColor Yellow
    }
}

# Escaped paths for JSON
$BinaryEscaped = $BinaryDest -replace '\\', '\\\\'
$VaultEscaped = $VaultPath -replace '\\', '\\\\'
$PythonEscaped = $PythonPath -replace '\\', '\\\\'

$SessionStartCmd = "$PythonPath $($VaultPath)\scripts\grimoire\session-start.py"
$SessionEndCmd = "$PythonPath $($VaultPath)\scripts\grimoire\session-end.py"
$PreCompactCmd = "$PythonPath $($VaultPath)\scripts\grimoire\pre-compact.py"

$SessionStartEscaped = "$PythonEscaped $($VaultEscaped)\\scripts\\grimoire\\session-start.py"
$SessionEndEscaped = "$PythonEscaped $($VaultEscaped)\\scripts\\grimoire\\session-end.py"
$PreCompactEscaped = "$PythonEscaped $($VaultEscaped)\\scripts\\grimoire\\pre-compact.py"

# --- MCP config (global by default) ---
Write-Host ""
Write-Host "MCP server config — where should we install it?" -ForegroundColor Yellow
Write-Host "  The grimoire engine registers 15 MCP tools (13 auto-approved)."
Write-Host ""
Write-Host "  1) ~/.claude/.mcp.json (global — available in all projects, recommended)"
Write-Host "  2) Custom location"
$mcpChoice = Read-Host "Choice [1/2]"

$ClaudeHome = Join-Path $env:USERPROFILE ".claude"
New-Item -ItemType Directory -Path $ClaudeHome -Force | Out-Null

if ($mcpChoice -eq "2") {
    $mcpTarget = Read-Host "Path to .mcp.json"
} else {
    $mcpTarget = Join-Path $ClaudeHome ".mcp.json"
}

if (Test-Path $mcpTarget) {
    Write-Host "$mcpTarget already exists." -ForegroundColor Yellow
    Write-Host "Add this to your existing mcpServers:"
    Write-Host ""
    Write-Host "  `"grimoire`": {"
    Write-Host "    `"command`": `"$BinaryEscaped`","
    Write-Host "    `"args`": [`"serve`", `"--project`", `"$VaultEscaped`"],"
    Write-Host "    `"env`": {}"
    Write-Host "  }"
    Write-Host ""
} else {
    @"
{
  "mcpServers": {
    "grimoire": {
      "command": "$BinaryEscaped",
      "args": ["serve", "--project", "$VaultEscaped"],
      "env": {}
    }
  }
}
"@ | Out-File -FilePath $mcpTarget -Encoding utf8
    Write-Host "MCP config written to $mcpTarget" -ForegroundColor Green
}

# --- Hooks config (global by default) ---
Write-Host ""
Write-Host "Hook config — where should we install it?" -ForegroundColor Yellow
Write-Host "  Hooks use absolute paths, so they work from any Claude Code session."
Write-Host ""
Write-Host "  1) ~/.claude/settings.local.json (global — recommended)"
Write-Host "  2) Custom location"
$hooksChoice = Read-Host "Choice [1/2]"

if ($hooksChoice -eq "2") {
    $hooksTarget = Read-Host "Path to settings file"
} else {
    $hooksTarget = Join-Path $ClaudeHome "settings.local.json"
}

if (Test-Path $hooksTarget) {
    Write-Host "$hooksTarget already exists." -ForegroundColor Yellow
    Write-Host "Merge these hooks and permissions into your existing config:"
    Write-Host ""
    Write-Host "  Hooks (use absolute paths):"
    Write-Host "    SessionStart: $SessionStartCmd"
    Write-Host "    SessionEnd:   $SessionEndCmd"
    Write-Host "    PreCompact:   $PreCompactCmd"
    Write-Host ""
    Write-Host "  See config/settings-hooks.json.template for the full JSON structure."
    Write-Host ""
} else {
    @"
{
  "permissions": {
    "allow": [
      "mcp__grimoire__wiki_status",
      "mcp__grimoire__wiki_search",
      "mcp__grimoire__wiki_read",
      "mcp__grimoire__wiki_list",
      "mcp__grimoire__wiki_write_summary",
      "mcp__grimoire__wiki_write_article",
      "mcp__grimoire__wiki_add_ontology",
      "mcp__grimoire__wiki_add_source",
      "mcp__grimoire__wiki_learn",
      "mcp__grimoire__wiki_commit",
      "mcp__grimoire__wiki_compile_diff",
      "mcp__grimoire__wiki_ontology_query",
      "mcp__grimoire__wiki_lint"
    ]
  },
  "hooks": {
    "SessionStart": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "$SessionStartEscaped",
        "timeout": 15
      }]
    }],
    "PreCompact": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "$PreCompactEscaped",
        "timeout": 10
      }]
    }],
    "SessionEnd": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "$SessionEndEscaped",
        "timeout": 10
      }]
    }]
  }
}
"@ | Out-File -FilePath $hooksTarget -Encoding utf8
    Write-Host "Hooks and permissions written to $hooksTarget" -ForegroundColor Green
}

# Obsidian CSS
$obsidianDir = Join-Path $VaultPath ".obsidian"
if (Test-Path $obsidianDir) {
    $snippetsDir = Join-Path $obsidianDir "snippets"
    New-Item -ItemType Directory -Path $snippetsDir -Force | Out-Null
    Copy-Item (Join-Path $ScriptDir "obsidian\snippets\grimoire-colors.css") $snippetsDir -Force
    Write-Host "Obsidian CSS snippet installed. Enable in Settings > Appearance > CSS Snippets." -ForegroundColor Green
}

Write-Host ""
Write-Host "  +==============================================+" -ForegroundColor Cyan
Write-Host "  |           SETUP COMPLETE!                    |" -ForegroundColor Green
Write-Host "  +==============================================+" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Customise config.yaml (source folders, timezone)"
Write-Host "  2. If you had existing config files, merge the grimoire entries shown above"
Write-Host "  3. Restart Claude Code"
Write-Host "  4. Run: /grimoire status"
Write-Host "  5. Drop a file in inbox/drops/ and run: /grimoire compile"
Write-Host ""
Write-Host "The grimoire awaits." -ForegroundColor Green
