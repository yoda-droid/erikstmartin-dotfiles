# mise — activate tool environments
# Sorts before aliases.fish so mise tools are on $PATH when conf.d scripts run.
# Use absolute path fallback so mise is found even before ~/.local/bin is on PATH
# (conf.d runs before config.fish which adds ~/.local/bin).
#
# We also call hook-env eagerly after activation so tool paths (e.g. starship)
# are in PATH immediately. Without this, mise only populates tool paths on the
# first fish_prompt call — after config.fish has already skipped any
# type-q checks for mise-managed tools.
if type -q mise
    mise activate fish | source
    mise hook-env fish -s 0 2>/dev/null | source
else if test -x $HOME/.local/bin/mise
    $HOME/.local/bin/mise activate fish | source
    $HOME/.local/bin/mise hook-env fish -s 0 2>/dev/null | source
end
