# ~/.bash_profile - Login shell configuration
# Environment variables and PATH only. Interactive config is in .bashrc.
# Cross-platform: macOS and Linux
#
# File Inventory:
#   .bash_profile      Login env (brew, PATH, secrets)
#   .bashrc            Interactive (shell opts, prompt, completions, tools)
#   .bash_aliases      Aliases and helper functions
#   .bash_local        Machine/project-specific config (not in repo)
#   .bash_functions    Machine-specific functions (not in repo)
#   .bash-preexec.sh   Third-party lib (required by atuin)
#   .secrets           Credentials and API tokens (chmod 600)
#
# Load Order:
#   .bash_profile
#     -> brew shellenv (macOS)
#     -> .secrets
#     -> .bashrc
#          -> brew shellenv (non-login shells, if not already set)
#          -> /etc/bashrc (Linux)
#          -> ~/.bash.eba (host environment, when present)
#          -> mise shims (non-interactive only)
#          -> [non-interactive stops here]
#          -> shell options (cdspell, globstar, etc.), history
#          -> mise activate (interactive — full hooks)
#          -> direnv
#          (each tool initialises once: skipped when ~/.bash.eba already did)
#          -> starship (prompt)
#          -> bash-completion
#          -> zoxide (z: jump, zi: interactive fzf picker)
#          -> fzf (Ctrl-T: find files, Alt-C: cd into dir)
#          -> bash-preexec
#          -> atuin (Ctrl-R: history search, Up: shell history)
#          -> aws completion
#          -> .bash_local (machine/project-specific)
#          -> .bash_functions (machine-specific functions)
#          -> .bash_aliases

# Suppress macOS bash deprecation warning
[[ "$(uname -s)" == "Darwin" ]] && export BASH_SILENCE_DEPRECATION_WARNING=1

# Homebrew (macOS)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Secrets
[[ -f "$HOME/.secrets" ]] && source "$HOME/.secrets"

# Locale: Ruby tools expect UTF-8 (LANG only; LC_* settings still win)
export LANG="${LANG:-en_US.UTF-8}"

# GPG signing (only with a terminal: tty prints "not a tty" otherwise)
if [[ -t 0 ]]; then
  GPG_TTY="$(tty)"
  export GPG_TTY
fi

# PATH
export PATH="$HOME/.local/bin:/usr/local/sbin:$PATH"

# Interactive shell config
[[ -s "$HOME/.bashrc" ]] && source "$HOME/.bashrc"

# Homebrew keg-only database clients
if command -v brew &>/dev/null; then
  [[ -d "$(brew --prefix mysql-client 2>/dev/null)/bin" ]] && export PATH="$(brew --prefix mysql-client)/bin:$PATH"
  [[ -d "$(brew --prefix libpq 2>/dev/null)/bin" ]] && export PATH="$(brew --prefix libpq)/bin:$PATH"
fi
