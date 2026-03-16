# ~/.bashrc - Interactive shell configuration
# Cross-platform: macOS (arm64/x86_64) and Linux

[[ $- != *i* ]] && return

# Shell options
shopt -s histappend     # append to history, don't overwrite
shopt -s cdspell        # autocorrect minor cd typos
shopt -s dirspell       # autocorrect directory names in completion
shopt -s checkwinsize   # update LINES/COLUMNS after each command
shopt -s cmdhist        # save multi-line commands as one history entry
shopt -s globstar       # ** matches files and zero or more directories
shopt -s nocaseglob     # case-insensitive pathname expansion

# Brew prefix (HOMEBREW_PREFIX is set by brew shellenv in .bash_profile)
BREW_PREFIX="${HOMEBREW_PREFIX:-}"

# Starship prompt
command -v starship &>/dev/null && eval "$(starship init bash)"

# Completions (brew on macOS, /etc on Linux)
if [[ -n "${BREW_PREFIX:-}" && -r "$BREW_PREFIX/etc/profile.d/bash_completion.sh" ]]; then
  source "$BREW_PREFIX/etc/profile.d/bash_completion.sh"
elif [[ -r /usr/share/bash-completion/bash_completion ]]; then
  source /usr/share/bash-completion/bash_completion
elif [[ -r /etc/bash_completion ]]; then
  source /etc/bash_completion
fi
for f in "$HOME/.local/etc/bash_completion.d"/*; do [[ -f "$f" ]] && source "$f"; done

# Zoxide (z to jump, zi for interactive fzf picker)
command -v zoxide &>/dev/null && eval "$(zoxide init bash)"

# FZF (Ctrl-T: find files, Alt-C: cd into directory)
if [[ -n "${BREW_PREFIX:-}" ]]; then
  source "$BREW_PREFIX/opt/fzf/shell/completion.bash" 2>/dev/null
  [[ -f "$BREW_PREFIX/opt/fzf/shell/key-bindings.bash" ]] && source "$BREW_PREFIX/opt/fzf/shell/key-bindings.bash"
elif [[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.bash
  [[ -f /usr/share/doc/fzf/examples/completion.bash ]] && source /usr/share/doc/fzf/examples/completion.bash
elif [[ -f "$HOME/.fzf.bash" ]]; then
  source "$HOME/.fzf.bash"
fi

# bash-preexec (required by atuin)
[[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh

# Atuin (Ctrl-R: history search, Up: shell history)
if command -v atuin &>/dev/null; then
  export ATUIN_HOST="${ATUIN_HOST:-https://api.atuin.sh}"
  export ATUIN_NOBIND="true"
  eval "$(atuin init bash)"
  bind -x '"\C-r": __atuin_history'
  bind -x '"\e[A": __atuin_history --shell-up-key-binding'
  bind -x '"\eOA": __atuin_history --shell-up-key-binding'
fi

# AWS completion
if [[ -n "${BREW_PREFIX:-}" && -x "$BREW_PREFIX/bin/aws_completer" ]]; then
  complete -C "$BREW_PREFIX/bin/aws_completer" aws
elif command -v aws_completer &>/dev/null; then
  complete -C "$(command -v aws_completer)" aws
fi

# Mise (tool version manager — ruby, node, python, starship, atuin, zoxide)
eval "$(mise activate bash)"

# Machine/project-specific config (not in dotfiles repo)
[[ -f ~/.bash_local ]] && source ~/.bash_local

# Machine-specific functions (not in dotfiles repo)
[[ -f ~/.bash_functions ]] && source ~/.bash_functions

# Aliases
[[ -f ~/.bash_aliases ]] && source ~/.bash_aliases
