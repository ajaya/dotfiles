# ~/.bash_profile - Login shell configuration
# Environment variables and PATH only. Interactive config is in .bashrc.
# Cross-platform: macOS (arm64/x86_64) and Linux
#
# File Inventory:
#   .bash_profile      Login env (brew, PATH, secrets, history)
#   .bashrc            Interactive (shell opts, prompt, completions, tools)
#   .bash_aliases      Aliases and helper functions
#   .bash_local        Machine/project-specific config (not in repo)
#   .bash_functions    Machine-specific functions (not in repo)
#   .bash-preexec.sh   Third-party lib (required by atuin)
#   .secrets           Credentials and API tokens (chmod 600)
#   .local/share/zoxide  Zoxide directory database (auto-managed)
#
# Load Order:
#   .bash_profile
#     -> brew shellenv (macOS) / linuxbrew (Linux, if installed)
#     -> .secrets
#     -> .bashrc
#          -> shell options (cdspell, globstar, etc.)
#          -> starship (prompt)
#          -> bash-completion
#          -> zoxide (z: jump, zi: interactive fzf picker)
#          -> fzf (Ctrl-T: find files, Alt-C: cd into dir)
#          -> bash-preexec
#          -> atuin (Ctrl-R: history search, Up: shell history)
#          -> aws completion
#          -> rv
#          -> .bash_local (machine/project-specific)
#          -> .bash_functions (machine-specific functions)
#          -> .bash_aliases

# Suppress macOS bash deprecation warning
[[ "$(uname -s)" == "Darwin" ]] && export BASH_SILENCE_DEPRECATION_WARNING=1

# Homebrew (macOS arm64, macOS x86_64, or Linuxbrew)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Secrets
[[ -f "$HOME/.secrets" ]] && source "$HOME/.secrets"

# History
export HISTCONTROL=ignoreboth:erasedups
export HISTSIZE=100000
export HISTFILESIZE=200000

# GPG signing
export GPG_TTY=$(tty)

# PATH
export PATH="$HOME/.local/bin:/usr/local/sbin:$PATH"

# Interactive shell config
[[ -s "$HOME/.bashrc" ]] && source "$HOME/.bashrc"
