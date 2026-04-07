# Just Global Justfile
set -gx JUST_GLOBAL_JUSTFILE "$HOME/.config/just/justfile"

if test (uname) = Darwin
    set -gx CC /opt/homebrew/opt/llvm/bin/clang
    set -gx CXX /opt/homebrew/opt/llvm/bin/clang++
    set -gx CLANGXX /opt/homebrew/opt/llvm/bin/clang++
else if test (uname) = Linux
    set -gx CC clang
    set -gx CXX clang++
    set -gx CLANGXX clang++
end

# Machine-local environment overrides — not tracked in dotfiles.
# Format: KEY=value or export KEY=value (one per line, no spaces around =)
if test -f ~/.env.local
    if type -q bass
        bass source ~/.env.local
    end
end

# Lazy GITHUB_TOKEN/GH_TOKEN — only calls git credential manager when first needed
function _ensure_gh_token
    if not set -q GH_TOKEN
        set -gx GH_TOKEN (printf "protocol=https\nhost=github.com\n\n" | git credential fill 2>/dev/null | string match -r '(?<=^password=).*')
        set -gx GITHUB_TOKEN $GH_TOKEN
    end
end

function gh --wraps gh
    _ensure_gh_token
    command gh $argv
end

function agency --wraps agency
    _ensure_gh_token
    command agency $argv
end