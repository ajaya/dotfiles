# ~/.bashrc - Interactive shell configuration
# Cross-platform: macOS (arm64/x86_64) and Linux

# --- Non-interactive setup (PATH for brew + mise shims) ---
# Ensures tools are available in non-login shells (e.g., ssh host 'command')
if [[ -z "${HOMEBREW_PREFIX:-}" && -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
# Linux: system-wide defaults, as the distribution's own ~/.bashrc loads them
# (Debian/Ubuntu bash reads /etc/bash.bashrc itself).
if [[ $OSTYPE == linux* && -f /etc/bashrc ]]; then
  source /etc/bashrc
fi

# Host environment: a provisioned host may keep its tool environment in
# ~/.bash.eba (PATH, mise, prompt, completion). Load it first, in every bash;
# each step below skips what it already set up.
[[ -f ~/.bash.eba ]] && source ~/.bash.eba

# Non-interactive shell — mise shims only, then exit
if [[ $- != *i* ]]; then
  if command -v mise &>/dev/null && \
     [[ ":$PATH:" != *":${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims:"* ]]; then
    eval "$(mise activate bash --shims)"
  fi
  return
fi

# Shell options
shopt -s histappend     # append to history, don't overwrite
shopt -s cdspell        # autocorrect minor cd typos
shopt -s dirspell       # autocorrect directory names in completion
shopt -s checkwinsize   # update LINES/COLUMNS after each command
shopt -s cmdhist        # save multi-line commands as one history entry
shopt -s globstar       # ** matches files and zero or more directories
shopt -s nocaseglob     # case-insensitive pathname expansion

# History (set here, after the host environment, so these values win)
export HISTCONTROL=ignoreboth:erasedups
export HISTSIZE=100000
export HISTFILESIZE=200000

# Brew prefix (HOMEBREW_PREFIX is set by brew shellenv in .bash_profile)
BREW_PREFIX="${HOMEBREW_PREFIX:-}"

# Mise (tool version manager — ruby, node, python, starship, atuin, zoxide)
# Activated early: adds mise-managed tools to PATH before they are initialised below.
# Each tool below is initialised once: skipped when its hook already exists.
if command -v mise &>/dev/null && ! declare -F _mise_hook >/dev/null; then
  eval "$(mise activate bash)"
fi

# Direnv (auto-load .envrc per directory)
if command -v direnv &>/dev/null && ! declare -F _direnv_hook >/dev/null; then
  eval "$(direnv hook bash)"
fi

# Starship prompt
if command -v starship &>/dev/null && ! declare -F starship_precmd >/dev/null; then
  eval "$(starship init bash)"
fi

# Completions (brew on macOS, /etc on Linux), unless already loaded
if [[ -z "${BASH_COMPLETION_VERSINFO:-}" ]]; then
  if [[ -n "${BREW_PREFIX:-}" && -r "$BREW_PREFIX/etc/profile.d/bash_completion.sh" ]]; then
    source "$BREW_PREFIX/etc/profile.d/bash_completion.sh"
  elif [[ -r /usr/share/bash-completion/bash_completion ]]; then
    source /usr/share/bash-completion/bash_completion
  elif [[ -r /etc/bash_completion ]]; then
    source /etc/bash_completion
  fi
fi
# Generated completions (install.sh), skipping commands that already have one
for f in "$HOME/.local/etc/bash_completion.d"/*.bash; do
  [[ -f "$f" ]] || continue
  _cmd="$(basename "$f" .bash)"
  complete -p "$_cmd" &>/dev/null || source "$f"
done
unset f _cmd

# Zoxide (z to jump, zi for interactive fzf picker)
if command -v zoxide &>/dev/null && ! declare -F __zoxide_hook >/dev/null; then
  eval "$(zoxide init bash)"
fi

# FZF (Ctrl-T: find files, Alt-C: cd into directory)
if declare -F __fzf_select__ >/dev/null; then
  :
elif [[ -n "${BREW_PREFIX:-}" ]]; then
  source "$BREW_PREFIX/opt/fzf/shell/completion.bash" 2>/dev/null
  [[ -f "$BREW_PREFIX/opt/fzf/shell/key-bindings.bash" ]] && source "$BREW_PREFIX/opt/fzf/shell/key-bindings.bash"
elif [[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.bash
  [[ -f /usr/share/doc/fzf/examples/completion.bash ]] && source /usr/share/doc/fzf/examples/completion.bash
elif [[ -f /usr/share/fzf/shell/key-bindings.bash ]]; then
  # Fedora / EL (EPEL) fzf package; completion ships in bash-completion's dir
  source /usr/share/fzf/shell/key-bindings.bash
elif [[ -f "$HOME/.fzf.bash" ]]; then
  source "$HOME/.fzf.bash"
fi

# bash-preexec (required by atuin)
[[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh

# Atuin (Ctrl-R: history search, Up: shell history)
if command -v atuin &>/dev/null && ! declare -F __atuin_history >/dev/null; then
  export ATUIN_NOBIND="true"
  eval "$(atuin init bash)"
  bind -x '"\C-r": __atuin_history'
  bind -x '"\e[A": __atuin_history --shell-up-key-binding'
  bind -x '"\eOA": __atuin_history --shell-up-key-binding'
fi

# AWS completion
if complete -p aws &>/dev/null; then
  :
elif [[ -n "${BREW_PREFIX:-}" && -x "$BREW_PREFIX/bin/aws_completer" ]]; then
  complete -C "$BREW_PREFIX/bin/aws_completer" aws
elif command -v aws_completer &>/dev/null; then
  complete -C "$(command -v aws_completer)" aws
fi

# Machine/project-specific config (not in dotfiles repo)
[[ -f ~/.bash_local ]] && source ~/.bash_local

# Machine-specific functions (not in dotfiles repo)
[[ -f ~/.bash_functions ]] && source ~/.bash_functions

# Aliases
[[ -f ~/.bash_aliases ]] && source ~/.bash_aliases

# Source optional local shell helpers (code() wrapper, etc.)
[ -f "$HOME/.config/local_kit/shell/code-profile.sh" ] && . "$HOME/.config/local_kit/shell/code-profile.sh"
