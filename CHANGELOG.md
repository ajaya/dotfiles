# Changelog

All notable changes to these dotfiles are documented here.

## Unreleased

### Command-line clients through mise on every platform

- gh 2.105.0, glab 1.131.0, jira-cli 1.7.0 (`github:ankitpokhrel/jira-cli`), confluence-cli 2.31.2 (`npm:confluence-cli`, pchuri) and AWS CLI 2.41.1 (`aws-cli`) are defined once, in `.config/mise/conf.d/dotfiles-clis.toml`, linked to `~/.config/mise/conf.d/`. aws-cli, jira-cli and glab use EBA's host tool lock versions; gh and confluence-cli their latest release.
- install.sh runs `mise install` for these five, user-level, on every machine (also with `--no-packages`). On a host-managed mise config (regular `config.toml` with `mise.lock`) the conf.d file is not linked and nothing is installed: that host's locked install would refuse tools its lock lacks, and its lock provides the clients.
- aube is pinned (`latest` → `2.10.1`): mise installs the npm backend's configured dependencies (node, aube) before confluence-cli and cannot resolve `latest` for them offline.
- `--no-packages` now means "no sudo and no system packages"; it still installs the clients (and mise into `~/.local/bin` when missing).
- Removed the Linux gh install (EPEL / GitHub repository) and the pinned glab release install.
- Removed gh, glab, awscli, jira-cli and confluence-cli (and the `pchuri/tap` tap) from the Brewfile. Existing Homebrew copies are left installed; mise's shims and activated paths come first on PATH, so the pinned versions win.

### Provisioned Linux hosts (AlmaLinux 10)

- `install.sh --yes` / `-y`: never prompt; implied when stdin or stdout is not a terminal. Non-interactive runs use `sudo -n`, export `MISE_YES=1` and skip the post-install reminders.
- `install.sh --no-packages`: skip every install (brew, apt/dnf, release downloads, fonts, `mise install`, npm) and `sudo`; only link dotfiles, configure Git and copy templates.
- The installer is idempotent: a second run links nothing, backs up nothing, rewrites neither `~/.gitconfig.local` (values are set only when they differ) nor unchanged completion files, and exits 0. It exits non-zero when a step fails; optional tool installs run with errexit on in a subshell (a failed checksum stops that step) and are listed in the summary.
- Backups keep each file's path under `~/.dotfiles-backup-<timestamp>/` (`.config/fd/ignore` and `.config/git/ignore` no longer collide).
- `.bashrc` loads `/etc/bashrc` on Linux and then `~/.bash.eba` when present (before the non-interactive exit), and initialises mise, direnv, starship, bash-completion, zoxide, fzf, atuin, aws completion and generated completions only when not already set up. History settings moved from `.bash_profile` to `.bashrc` so they apply after the host environment.
- A host-managed global mise config (regular `~/.config/mise/config.toml` with `mise.lock` beside it) is left alone: no link, no `mise install`, no npm CLI installs.
- The installer puts `~/.local/bin` and mise's shims on PATH first, so tools the host installed through mise count as present and keep their version.
- dnf/apt base packages are installed only when their command is missing, the package is not installed and an enabled repository offers it; others are skipped with a note. EL10 uses `mysql8.4` for the MySQL client; `gh` comes from EPEL when available (GitHub's repository is added only otherwise); `eza` installs when a repository has it instead of being skipped on every RHEL-like host.
- `glab` installs from the pinned, checksum-verified release only (no distro package that lags the pin).
- The IosevkaTerm Nerd Font archive is verified against GitHub's published SHA-256 digest (checksum exception removed from `SECURITY.md`).
- Fedora/EL fzf key bindings (`/usr/share/fzf/shell`) load in `.bashrc`.
- `alias g=z` is defined only when no `g` function (bashmarks) exists.
- `GPG_TTY` is set only with a terminal.
- `test/idempotence.sh`: a second `--yes --no-packages` run changes nothing.

### Git

- On Linux, an existing `~/.git-credentials` keeps working: `credential.helper` is `store` first.
- `commit.gpgsign` and `tag.gpgsign` move from `.gitconfig` to `~/.gitconfig.local`: `true` only when GPG has a secret key (or `DOTFILES_GIT_SIGNINGKEY` is set). Rerun `install.sh` after adding a key; existing machines must rerun it once to keep signing.
- `core.pager` moves from `.gitconfig` to `~/.gitconfig.local`: `hunk pager` when Hunk is installed, else `delta`, else Git's default. Rerun `install.sh` once to keep the Hunk pager.

### Versions aligned with EBA

EBA app (`.ruby-version`, `mise.toml`) for the global runtimes; EBA's host tool lock (eba-apps-automation `host_software`, `group_vars/all`) for host tools.

| Tool | Where | From | To |
|------|-------|------|----|
| node | `.config/mise/config.toml` | `26` | `26.13.1` |
| python | `.config/mise/config.toml` | `3.14.8` | `3.14.10` |
| ruby | `.config/mise/config.toml` | `4.0.9` | `4.0.10` |
| starship | `.config/mise/config.toml` | `latest` | `1.27.0` |
| direnv | `.config/mise/config.toml` | `latest` | `2.38.2` |
| lazydocker | `.config/mise/config.toml` | `latest` | `0.25.2` |
| mise (Linux release) | `install.sh` | `2026.5.10` | `2026.10.25` |
| glab (Linux release) | `install.sh` | `1.97.0` | `1.131.0` |
| sops (Linux release) | `install.sh` | `3.13.1` | `3.13.3` |
| Nerd Fonts (IosevkaTerm) | `install.sh` | `v3.4.0` | `v3.5.1` |

### Earlier unreleased changes

### Added

- Add app development prerequisites to the Brewfile: Colima, Docker, Docker Compose, AWS CLI, jira-cli, Oracle Instant Client (basic and sqlplus), uv and the Git Credential Manager cask; plus rsync, watch, the JetBrains Mono Nerd Font and a "Personal tools" section.
- Manage the global npm CLIs (`bw`, `gws`, `pinchtab`, `pi`, `tmux-ide`) as mise `npm:` tools so they survive Node upgrades; mise installs them with npm.
- Export a UTF-8 `LANG` default in `.bash_profile`.

- Add Homebrew packages for `dtop`, `rtk`, `mysql-client`, `libpq`, `lazydocker`, `lazygit`, `sops`, GitHub Copilot CLI, Claude Code, Codex CLI, and Hunk from `modem-dev/tap`.
- Add Linux install support for MySQL client packages: `default-mysql-client` on apt systems and `mysql` on dnf systems.
- Add PostgreSQL client packages: `libpq` on Homebrew, `postgresql-client` on apt systems, and `postgresql` on dnf systems.
- Add Claude Code, Codex CLI, and Hunk to Linux npm global installs after mise provisions Node.
- Add `lazydocker` and `lazygit` to Homebrew; Linux continues to install them through mise.
- Add pinned, checksum-verified Linux install for SOPS.
- Add `.irbrc.local.template` for machine/project-specific IRB helpers.
- Add `test/dry-run.sh` to verify installer dry-run mode does not mutate `HOME`.
- Add `cspell.json` with dotfile, tool, and config vocabulary.

### Changed

- Install mise from Homebrew on macOS and activate it by name in `.bashrc` (no hard-coded `~/.local/bin/mise`).
- Set the Atuin sync server with `ATUIN_SYNC_ADDRESS` in `~/.bash_local`; drop the tracked `sync_address` and the unused `ATUIN_HOST` export.
- Global mise Python is 3.14.8.
- Ghostty: font size 11, Catppuccin Latte kept as a commented alternative, and `ssh-env` alongside `ssh-terminfo` so SSH sessions fall back to `xterm-256color` where the Ghostty terminfo cannot be installed.
- Atuin `history_filter` drops commands with GitLab tokens, bearer headers, `--password` or `--totp` arguments.
- htop config rewritten by htop 3.5.3 (sticky follow, memory tree sort, no Systemd meter on macOS).

- Set Git's default pager to `hunk pager`.
- Move project-specific IRB setup out of shared `.irbrc` and into `~/.irbrc.local`.
- Move machine-specific GitHub credential username and credential helper setup out of tracked `.gitconfig` and into `~/.gitconfig.local`.
- Prefer Git Credential Manager in local Git config when installed, with platform helpers as fallbacks.
- Harden Linux release installs by pinning versions and verifying checksums where upstream publishes them.
- Document checksum exceptions for tools whose upstream releases do not publish checksum files.
- Document npm-managed CLI installs in the security policy.
- Update README package, Git, IRB, platform, and security notes.

### Removed

- Remove `curl | sh` mise installation from the Linux installer.
- Remove dynamic "latest release" resolution from Linux release installs.
- Remove long-lived exported token examples from `.secrets.template`.
