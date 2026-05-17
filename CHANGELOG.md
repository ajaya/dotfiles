# Changelog

All notable changes to these dotfiles are documented here.

## Unreleased

### Added

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
