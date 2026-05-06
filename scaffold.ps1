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

# --- Copy skills (with {{VAULT_ROOT}} substitution) ---
Write-Host "Copying skills (filling in vault path)..." -ForegroundColor Cyan
$SkillsSrc = Join-Path $ScriptDir "skills"
$SkillsDst = Join-Path $VaultPath ".claude\skills"

if (Test-Path $SkillsSrc) {
    $count = 0
    Get-ChildItem -Path $SkillsSrc -Directory | ForEach-Object {
        $srcSkill = Join-Path $_.FullName "SKILL.md"
        $dst = Join-Path $SkillsDst $_.Name
        $dstSkill = Join-Path $dst "SKILL.md"
        New-Item -ItemType Directory -Path $dst -Force | Out-Null

        # Read source, substitute {{VAULT_ROOT}} with the actual vault path,
        # write out as UTF-8 (no BOM) to keep markdown clean.
        $content = (Get-Content $srcSkill -Raw).Replace('{{VAULT_ROOT}}', $VaultPath)
        [System.IO.File]::WriteAllText($dstSkill, $content)
        $count++
    }
    Write-Host "$count skills copied (vault path filled in)." -ForegroundColor Green
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

# --- MCP config (smart detection) ---
Write-Host ""
Write-Host "Detecting MCP configuration..." -ForegroundColor Cyan
Write-Host "  The grimoire engine registers 15 MCP tools (13 auto-approved)."
Write-Host ""

# Scan known locations for files containing mcpServers
$mcpCandidates = @()
$ClaudeHome = Join-Path $env:USERPROFILE ".claude"

$mcpLocations = @(
    (Join-Path $env:USERPROFILE ".claude.json"),
    (Join-Path $ClaudeHome "settings.json"),
    (Join-Path $ClaudeHome ".mcp.json"),
    (Join-Path $VaultPath ".mcp.json")
)

# Also check Claude desktop app locations
$appDataClaude = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"
if (Test-Path $appDataClaude) { $mcpLocations += $appDataClaude }

foreach ($loc in $mcpLocations) {
    if (Test-Path $loc) {
        $content = Get-Content $loc -Raw -ErrorAction SilentlyContinue
        if ($content -match "mcpServers") {
            $mcpCandidates += [PSCustomObject]@{ Path = $loc; Label = "$loc (has mcpServers)" }
        } else {
            $mcpCandidates += [PSCustomObject]@{ Path = $loc; Label = "$loc (exists, no mcpServers yet)" }
        }
    }
}

$mcpSnippet = @"

  "grimoire": {
    "type": "stdio",
    "command": "$BinaryEscaped",
    "args": ["serve", "--project", "$VaultEscaped"],
    "env": {}
  }
"@

if ($mcpCandidates.Count -gt 0) {
    Write-Host "Found these config files on your system:" -ForegroundColor Yellow
    Write-Host ""
    for ($i = 0; $i -lt $mcpCandidates.Count; $i++) {
        Write-Host "  $($i+1)) $($mcpCandidates[$i].Label)"
    }
    Write-Host "  $($mcpCandidates.Count + 1)) Enter a custom path"
    Write-Host "  $($mcpCandidates.Count + 2)) Skip — I'll do it manually"
    Write-Host ""
    $mcpChoice = Read-Host "Which file should grimoire be added to?"

    $choiceInt = 0
    if ([int]::TryParse($mcpChoice, [ref]$choiceInt) -and $choiceInt -le $mcpCandidates.Count -and $choiceInt -ge 1) {
        $mcpTarget = $mcpCandidates[$choiceInt - 1].Path
        Write-Host ""
        Write-Host "Add this to the mcpServers section in: $mcpTarget" -ForegroundColor Yellow
        Write-Host ""
        Write-Host $mcpSnippet
        Write-Host ""
        Write-Host "If the file already has mcpServers, add the grimoire entry inside it." -ForegroundColor Yellow
        Write-Host "If it doesn't have mcpServers yet, add:  `"mcpServers`": { <the above> }" -ForegroundColor Yellow
    } elseif ($choiceInt -eq ($mcpCandidates.Count + 1)) {
        $mcpTarget = Read-Host "Path to your config file"
        Write-Host ""
        Write-Host "Add this to the mcpServers section in: $mcpTarget" -ForegroundColor Yellow
        Write-Host ""
        Write-Host $mcpSnippet
        Write-Host ""
    } else {
        Write-Host "Skipped. You'll need to add the MCP config manually." -ForegroundColor Yellow
    }
} else {
    Write-Host "No existing MCP config files found." -ForegroundColor Yellow
    Write-Host "  Common locations:"
    Write-Host "    Windows:       %USERPROFILE%\.claude.json or %USERPROFILE%\.claude\settings.json"
    Write-Host "    macOS/Linux:   ~/.claude.json or ~/.claude/settings.json"
    Write-Host "    Project-level: <vault>/.mcp.json"
    Write-Host ""
    Write-Host "  Check which file your other MCP servers (if any) are configured in,"
    Write-Host "  then add this to its mcpServers section:"
    Write-Host ""
    Write-Host $mcpSnippet
}

Write-Host ""

# --- Hooks config (smart detection) ---
Write-Host "Hooks configuration..." -ForegroundColor Cyan
Write-Host "  Hooks use absolute paths so they work from any Claude Code session."
Write-Host ""

$SessionStartCmd = "$PythonPath $($VaultPath)\scripts\grimoire\session-start.py"
$SessionEndCmd = "$PythonPath $($VaultPath)\scripts\grimoire\session-end.py"
$PreCompactCmd = "$PythonPath $($VaultPath)\scripts\grimoire\pre-compact.py"

# Scan for settings files that could hold hooks
$hooksCandidates = @()
$hooksLocations = @(
    (Join-Path $env:USERPROFILE ".claude.json"),
    (Join-Path $ClaudeHome "settings.json"),
    (Join-Path $ClaudeHome "settings.local.json"),
    (Join-Path $VaultPath ".claude\settings.local.json")
)

foreach ($loc in $hooksLocations) {
    if (Test-Path $loc) { $hooksCandidates += $loc }
}

Write-Host "Hooks need to be added to your Claude Code settings." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Check which file holds your existing hooks or permissions,"
Write-Host "  then merge in the grimoire hooks. Found these candidates:"
Write-Host ""
if ($hooksCandidates.Count -gt 0) {
    foreach ($c in $hooksCandidates) { Write-Host "    - $c" }
} else {
    Write-Host "    (no settings files found)"
}
Write-Host ""
Write-Host "  IMPORTANT (Windows): Claude Code runs hooks through bash, NOT PowerShell." -ForegroundColor Red
Write-Host "  Use forward slashes in hook commands: /c/Users/... NOT C:\Users\..." -ForegroundColor Red
Write-Host "  Quote paths with spaces." -ForegroundColor Red
Write-Host ""

# Convert Windows paths to bash-compatible paths for display
$BashVault = ($VaultPath -replace '\\', '/') -replace '^([A-Za-z]):', '/$1'
$BashVault = $BashVault.Substring(0,2).ToLower() + $BashVault.Substring(2)
$BashPython = ($PythonPath -replace '\\', '/') -replace '^([A-Za-z]):', '/$1'
$BashPython = $BashPython.Substring(0,2).ToLower() + $BashPython.Substring(2)

Write-Host "  Hook commands (bash-compatible paths for Windows):"
Write-Host ""
Write-Host "    SessionStart: $BashPython `"$BashVault/scripts/grimoire/session-start.py`""
Write-Host "    SessionEnd:   $BashPython `"$BashVault/scripts/grimoire/session-end.py`""
Write-Host "    PreCompact:   $BashPython `"$BashVault/scripts/grimoire/pre-compact.py`""
Write-Host ""
Write-Host "  See config/settings-hooks.json.template for the full JSON structure."
Write-Host ""

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
