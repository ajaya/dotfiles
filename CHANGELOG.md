# Changelog

All notable changes to these dotfiles are documented here.

## Unreleased

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
