# dotfiles Agent Guide

Guidance for AI coding agents working in this dotfiles repository.

## Repository Purpose

This repo manages a cross-platform Bash shell environment for macOS and Linux.
The installer provisions packages, symlinks tracked dotfiles, configures
machine-local Git settings, and creates local template files without
overwriting existing local config.

## Commands

Prefix shell commands with `rtk` when possible.

```bash
rtk bash -n install.sh test/dry-run.sh .bash_profile .bashrc .bash_aliases .bash_local.template .bash_functions.template
rtk test/dry-run.sh
rtk npx --yes cspell --no-progress --gitignore --dot "**/*"
HOMEBREW_NO_AUTO_UPDATE=1 rtk brew bundle check --file=Brewfile --verbose
```

If `rtk` cannot handle a command form, use the direct command only for that
case.

## Safety Rules

- Read `SECURITY.md` before changing installer, shell startup, Git config, or
  secrets handling.
- Never add real secrets, tokens, personal paths, host names, account names, or
  machine-specific credentials to tracked files.
- Keep machine-specific values in local files such as `~/.secrets`,
  `~/.bash_local`, `~/.bash_functions`, `~/.irbrc.local`, or
  `~/.gitconfig.local`.
- Do not use `curl | sh`, `wget | bash`, or dynamic "latest release" install
  logic.
- Prefer `brew`, `apt`, `dnf`, or mise-managed tools. Direct release downloads
  must be pinned and checksum-verified when upstream publishes checksums.
- If a direct-download artifact has no checksum, document the exception in
  `SECURITY.md`.
- `install.sh --dry-run` must not write files or mutate local state.

## Key Files

| File | Purpose |
| ---- | ------- |
| `install.sh` | Cross-platform installer, symlink setup, local template creation |
| `Brewfile` | macOS Homebrew formulae and casks |
| `.config/mise/config.toml` | mise-managed tool versions |
| `.bash_profile` | Login shell environment and PATH setup |
| `.bashrc` | Interactive shell startup |
| `.bash_aliases` | Shared aliases and shell functions |
| `.gitconfig` | Shared Git config only; local values belong in `~/.gitconfig.local` |
| `*.template` | Generic local-file templates; no personal or project-specific values |
| `cspell.json` | Repository spelling dictionary |
| `test/dry-run.sh` | Regression check for dry-run behavior |

## Editing Conventions

- Use `apply_patch` for manual edits.
- Keep tracked templates generic and reusable.
- When adding a tool, update all relevant places:
  - `Brewfile` for macOS
  - `install.sh` for Linux
  - `.config/mise/config.toml` if mise should manage it
  - `README.md` tool tables and usage sections
  - `CHANGELOG.md`
  - `SECURITY.md` if installer trust assumptions change
  - `cspell.json` if new tool names are valid vocabulary
- Keep README tools grouped by purpose.
- Keep shell scripts portable Bash and verify them with `bash -n`.

## Pre-Commit Checklist

Run the verification commands above before committing. `brew bundle check` may
report newly added formulae or casks until they are installed with:

```bash
HOMEBREW_NO_AUTO_UPDATE=1 rtk brew bundle install --file=Brewfile
```

After verification, check:

```bash
rtk git diff --check
rtk git status --short --branch
```
