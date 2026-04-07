# Windows dotfiles installer
# Requires: Developer Mode enabled (for file symlinks) or run as Administrator
#
# Enable script execution if needed:
#   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

$dotfiles = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

# ── Helpers ────────────────────────────────────────────────────────────────

function Test-DeveloperMode {
    try {
        $key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
        return (Get-ItemProperty -Path $key -Name AllowDevelopmentWithoutDevLicense -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense -eq 1
    } catch {
        return $false
    }
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Create a symlink, safely removing any existing target first
# Junctions for directories (no elevation needed), SymbolicLink for files (needs Developer Mode or admin)
function Link-Config {
    param(
        [string]$Target,
        [string]$Source    # relative to $dotfiles
    )
    $sourcePath = Join-Path $dotfiles $Source
    if (-not (Test-Path $sourcePath)) {
        Write-Warning "Source not found, skipping: $sourcePath"
        return
    }
    $sourcePath = (Resolve-Path $sourcePath).Path

    $parent = Split-Path -Parent $Target
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    # Safely remove existing target (avoid Remove-Item -Recurse on junctions — PS 5.1 follows them)
    if (Test-Path $Target) {
        $item = Get-Item $Target -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            # Junction or symlink — delete the link itself, not what it points to
            $item.Delete()
        } else {
            Remove-Item -Force -Recurse $Target
        }
    }

    $isDir = Test-Path $sourcePath -PathType Container
    if ($isDir) {
        New-Item -Path $Target -ItemType Junction -Value $sourcePath | Out-Null
    } else {
        New-Item -Path $Target -ItemType SymbolicLink -Value $sourcePath -ErrorAction Stop | Out-Null
    }
    Write-Host "  Linked: $Target -> $sourcePath"
}

# ── Pre-flight checks ─────────────────────────────────────────────────────

if (-not ((Test-DeveloperMode) -or (Test-IsAdmin))) {
    Write-Host "File symlinks require Developer Mode or Admin privileges. Elevating..."
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    exit $LASTEXITCODE
}

# ── Scoop ──────────────────────────────────────────────────────────────────
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Scoop..."
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
}

scoop bucket add nerd-fonts 2>&1 | Out-Null
scoop bucket add extras 2>&1 | Out-Null
scoop install innounp git gcc zig make msys2 JetBrainsMono-NF

# Tools also available via mise, but needed early for bootstrapping
scoop install neovim

# Optional yazi preview dependencies
scoop install ffmpeg 7zip poppler resvg imagemagick ghostscript

# ── Symlinks ───────────────────────────────────────────────────────────────
Write-Host "`nCreating config symlinks..."

# Neovim
Link-Config "$HOME\AppData\Local\nvim" "nvim\.config\nvim"

# Git
Link-Config "$HOME\.gitconfig" "git\.gitconfig"
Link-Config "$HOME\.gitignore" "git\.gitignore"

# Delta
Link-Config "$HOME\.config\delta" "delta\.config\delta"

# Mise
Link-Config "$HOME\.config\mise" "mise\.config\mise"

# Starship
Link-Config "$HOME\.config\starship.toml" "starship\.config\starship.toml"

# WezTerm
Link-Config "$HOME\.config\wezterm" "wezterm\.config\wezterm"

# Lazygit
Link-Config "$HOME\AppData\Roaming\lazygit" "lazygit\.config\lazygit"

# Lazydocker
Link-Config "$HOME\AppData\Roaming\lazydocker" "lazydocker\.config\lazydocker"

# K9s
Link-Config "$HOME\AppData\Roaming\k9s" "k9s\.config\k9s"

# Bat
Link-Config "$HOME\AppData\Roaming\bat" "bat\.config\bat"

# Yazi
Link-Config "$HOME\AppData\Roaming\yazi\config" "yazi\.config\yazi"

# Carapace
Link-Config "$HOME\AppData\Roaming\carapace" "carapace\.config\carapace"

# Just (global justfile)
Link-Config "$HOME\.config\just" "just\.config\just"

# Glow
Link-Config "$HOME\.config\glow" "glow\.config\glow"

# GitHub CLI
Link-Config "$HOME\AppData\Roaming\GitHub CLI" "gh\.config\gh"

# gh-dash
Link-Config "$HOME\.config\gh-dash" "gh-dash\.config\gh-dash"

# OpenCode
Link-Config "$HOME\.config\opencode" "opencode\.config\opencode"

# Copilot
Link-Config "$HOME\.copilot" "copilot\.copilot"

# Superpowers / agent skills
Link-Config "$HOME\.agents" "skills\global\.agents"

# PowerShell profile — use $PROFILE path to handle OneDrive redirection
$profileDir = Split-Path -Parent $PROFILE.CurrentUserAllHosts
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
}
Link-Config $PROFILE.CurrentUserCurrentHost "powershell\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"

# ── Git config ─────────────────────────────────────────────────────────────
# Windows-specific git settings go in .gitconfig-local (included by .gitconfig)
# so we don't pollute the shared dotfile
$gitconfigLocal = Join-Path $HOME ".gitconfig-local"
if (-not (Test-Path $gitconfigLocal)) {
    @"
[core]
    sshCommand = C:/Windows/System32/OpenSSH/ssh.exe
    autocrlf = true
"@ | Set-Content -Path $gitconfigLocal -Encoding UTF8
    Write-Host "  Created: $gitconfigLocal (Windows SSH config)"
} else {
    Write-Host "  Skipped: $gitconfigLocal already exists"
}

# ── Mise tools ─────────────────────────────────────────────────────────────
Write-Host "`nInstalling mise..."
if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
    scoop install mise 2>&1 | Out-Null
}

# Ensure MSYS2 build tools (make, rm, echo) are on PATH for native gem extensions
$msys2Usr = Join-Path (scoop prefix msys2) "usr\bin"
if (Test-Path $msys2Usr) {
    if ($env:PATH -notlike "*$msys2Usr*") {
        $env:PATH = "$msys2Usr;$env:PATH"
    }
    # Ensure MSYS2 make is installed (needed for Ruby native extensions)
    $msys2Make = Join-Path $msys2Usr "make.exe"
    if (-not (Test-Path $msys2Make)) {
        $msys2Bash = Join-Path (scoop prefix msys2) "usr\bin\bash.exe"
        & $msys2Bash -lc "pacman-key --init && pacman-key --populate msys2 && pacman --noconfirm -Sy make" 2>&1 | Out-Null
    }
}

Write-Host "Installing mise tools (this may take a while)..."
mise install

# Windows pipx-based tools: install via pip (pipx aqua package is linux/mac only)
Write-Host "Installing pip tools (Windows alternatives for pipx)..."
$pythonPath = (mise which python)
& $pythonPath -m pip install --user --quiet yamllint sqlfluff gersemi gdtoolkit posting code-review-graph

# Language provider support for Neovim
& $pythonPath -m pip install --user pynvim
mise exec -- gem install neovim

# ── GitHub CLI extensions ──────────────────────────────────────────────────
if (Get-Command gh -ErrorAction SilentlyContinue) {
    Write-Host "Installing gh extensions..."
    gh extension install dlvhdr/gh-dash 2>&1 | Out-Null
}

# ── PSFzf module (fzf integration for PowerShell) ─────────────────────────
Write-Host "Installing PSFzf module..."
Install-Module -Name PSFzf -Scope CurrentUser -Force -SkipPublisherCheck -ErrorAction SilentlyContinue

Write-Host "`nDone! Restart your terminal for changes to take effect."
