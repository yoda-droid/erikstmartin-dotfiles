# PowerShell profile
# Mirrors fish shell configuration for Windows parity

# ── PSReadLine ────────────────────────────────────────────────────────────
if (-not (Get-Module PSReadLine)) {
    Import-Module PSReadLine
}

# ── Cached init scripts (regenerate with: Remove-Item ~/.cache/pwsh-init/) ─
$_cacheDir = "$HOME\.cache\pwsh-init"
$_cacheMaxAge = [TimeSpan]::FromDays(7)
if (-not (Test-Path $_cacheDir)) { New-Item -ItemType Directory -Force -Path $_cacheDir | Out-Null }

function _load_cached {
    param([string]$Name, [scriptblock]$Generator)
    $cacheFile = Join-Path $script:_cacheDir "$Name.ps1"
    if (-not (Test-Path $cacheFile) -or
        ((Get-Date) - (Get-Item $cacheFile).LastWriteTime) -gt $script:_cacheMaxAge) {
        & $Generator | Set-Content -Path $cacheFile
    }
    . $cacheFile
}

# ── mise ──────────────────────────────────────────────────────────────────
# Uses shims mode for fast startup (~50ms vs ~2s for full activate).
# Shims resolve tool versions lazily. Trade-off: no auto hook-env on cd.
# Run `mise activate pwsh | Invoke-Expression` in a session if you need it.
if (Get-Command mise -ErrorAction SilentlyContinue) {
    _load_cached "mise" { mise activate pwsh --shims }
}

# ── Starship prompt ────────────────────────────────────────────────────────
if (Get-Command starship -ErrorAction SilentlyContinue) {
    _load_cached "starship" { & starship init powershell --print-full-init }
}

# ── Zoxide (smart cd) ─────────────────────────────────────────────────────
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    _load_cached "zoxide" { zoxide init --cmd z powershell }
}

# ── Direnv ─────────────────────────────────────────────────────────────────
if (Get-Command direnv -ErrorAction SilentlyContinue) {
    _load_cached "direnv" { direnv hook pwsh }
}

# ── Native completions (cached, in-process — no external spawn per tab) ───
# These generate pure-PowerShell scriptblocks once, then run in-process.
$_nativeCompletionTools = @(
    @{ Name = 'docker';    Cmd = 'docker';    Gen = { docker completion powershell } }
    @{ Name = 'kubectl';   Cmd = 'kubectl';   Gen = { kubectl completion powershell } }
    @{ Name = 'gh';        Cmd = 'gh';        Gen = { gh completion -s powershell } }
    @{ Name = 'mise';      Cmd = 'mise';      Gen = { mise completion powershell } }
    @{ Name = 'just';      Cmd = 'just';      Gen = { just --completions powershell } }
)
foreach ($tool in $_nativeCompletionTools) {
    if (Get-Command $tool.Cmd -ErrorAction SilentlyContinue) {
        _load_cached $tool.Name $tool.Gen
    }
}

# Carapace fallback for remaining commands (spawns process per tab press)
if (Get-Command carapace -ErrorAction SilentlyContinue) {
    $env:CARAPACE_MATCH = '1'
    $_carapace_completer = {
        param($wordToComplete, $commandAst, $cursorPosition)
        $elems = @()
        foreach ($el in $commandAst.CommandElements) {
            if ($el.Extent.StartOffset -gt $cursorPosition) { break }
            $t = $el.Extent.Text
            if ($el.Extent.EndOffset -gt $cursorPosition) {
                $t = $t.Substring(0, $t.Length - ($el.Extent.EndOffset - $cursorPosition))
            }
            $t = $t.Trim("'")
            if ($t.Length -eq 0) { $t = '""' }
            $elems += $t.Replace('`,', ',')
        }
        $cmd = ($elems[0] -replace '\.exe$', '')
        $args_list = if ($wordToComplete) { $elems } else { $elems + @('') }
        $result = carapace $cmd powershell @args_list 2>$null
        if ($result) {
            $result | ConvertFrom-Json | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_.CompletionText, $_.ListItemText, 'ParameterValue', $_.ToolTip)
            }
        }
    }
    # Only use carapace for tools without native completions
    $carapaceFallback = @(
        'cargo','cargo.exe','go','go.exe','npm','npm.exe',
        'az','az.exe','terraform','terraform.exe','helm','helm.exe'
    )
    Register-ArgumentCompleter -Native -CommandName $carapaceFallback -ScriptBlock $_carapace_completer
}

# ── fzf ───────────────────────────────────────────────────────────────────
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    # Catppuccin Mocha colour theme
    $env:FZF_DEFAULT_OPTS = @"
--color=bg+:#313244,bg:#11111b,spinner:#f5e0dc,hl:#f38ba8
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
--color=selected-bg:#45475a
--color=border:#6c7086,label:#cdd6f4
--border=rounded --border-label='' --preview-window=border-rounded:right:60%:wrap
--height=80%
--prompt='> ' --marker='-' --pointer='@' --separator='-' --scrollbar='|' --layout=reverse
"@

    if (Get-Command fd -ErrorAction SilentlyContinue) {
        $env:FZF_DEFAULT_COMMAND = 'fd --hidden --strip-cwd-prefix --exclude .git'
        $env:FZF_ALT_C_COMMAND = 'fd --type d --hidden --strip-cwd-prefix --exclude .git'
        $env:FZF_CTRL_T_COMMAND = $env:FZF_DEFAULT_COMMAND
    }

    # PSFzf: lazy-load on first Ctrl+T or Ctrl+R to avoid ~1s import at startup
    if (Get-Module -ListAvailable -Name PSFzf) {
        $__psfzf_lazy = {
            Import-Module PSFzf
            Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
        }
        Set-PSReadLineKeyHandler -Key 'Ctrl+t' -ScriptBlock { & $__psfzf_lazy; [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt() }
        Set-PSReadLineKeyHandler -Key 'Ctrl+r' -ScriptBlock { & $__psfzf_lazy; [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt() }
    }
}

# ── Environment ───────────────────────────────────────────────────────────
$env:JUST_GLOBAL_JUSTFILE = "$HOME\.config\just\justfile"

# ── Aliases ───────────────────────────────────────────────────────────────
# eza (modern ls replacement)
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function l { eza --color=always --git --icons=always --group-directories-first @args }
    function ll { eza --color=always --git --icons=always --group-directories-first --long --header --time-style=relative @args }
    function la { eza --color=always --git --icons=always --group-directories-first --long --all --header --time-style=relative @args }
    function tree { eza --tree --icons=always @args }
    function lt { eza --tree --level=2 --icons=always @args }
}

# Editors
Set-Alias -Name vim -Value nvim
Set-Alias -Name vi -Value nvim
Set-Alias -Name v -Value nvim
Set-Alias -Name n -Value nvim

# Git
Set-Alias -Name g -Value git

# Docker
Set-Alias -Name d -Value docker

# Kubernetes
Set-Alias -Name k -Value kubectl

# Yazi
if (Get-Command yazi -ErrorAction SilentlyContinue) {
    Set-Alias -Name y -Value yazi
}

# Clear
Set-Alias -Name cl -Value Clear-Host

# ── Functions ─────────────────────────────────────────────────────────────
# Smart just: local justfile or global
function j {
    if (Test-Path justfile) {
        just @args
    } else {
        just --global-justfile @args
    }
}

# Just global shortcut
function jg { just --global-justfile @args }

# Create directory and cd into it
function mkcd {
    param([string]$Path)
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    Set-Location $Path
}

# AI assistant wrapper
function ai {
    $assistant = if ($env:AI_ASSISTANT) { $env:AI_ASSISTANT } else { "opencode" }
    & $assistant @args
}
