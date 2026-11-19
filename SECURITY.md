# Security Policy

This repository manages local shell/tooling configuration and an installer that modifies user environment state.

## Scope

Security review focus areas:

- `install.sh` package install and download/execute behavior
- handling of secrets and credentials (`~/.secrets`, `~/.bash_local`, git credentials)
- machine-local vs tracked configuration boundaries

## Installer Trust Model

`install.sh` should follow these rules:

- Never execute remote scripts via `curl | sh` or equivalent.
- Prefer OS package managers (`brew`, `apt`, `dnf`).
- Language package manager installs must use explicit package names and run after the toolchain is provisioned by mise.
- If downloading release artifacts directly, use pinned versions and verify checksums/signatures whenever available.
- If upstream does not publish checksums for a release artifact, keep the version pinned, use HTTPS, and document the exception in this file.
- `--dry-run` must not write files or mutate local state.
- Platform-specific mutable settings belong in machine-local files (`~/.gitconfig.local`), not tracked dotfiles.
- Never prompt: non-interactive runs (`--yes`, or no TTY) use `sudo -n`; `--no-packages` uses no `sudo` and installs no system packages (only the user-level command-line clients through mise).
- Do not replace a tool the host already provides (command on PATH) or link over a host-managed mise config (regular `config.toml` with `mise.lock` beside it).
- Do not add package repositories.
- The command-line clients (`.config/mise/conf.d/dotfiles-clis.toml`) are exact versions installed by mise, which verifies the published checksums (aqua registry, GitHub release digests); `confluence-cli` is an npm package installed with install scripts off.

Current checksum exceptions (the Iosevka and IosevkaTerm Nerd Font archives
are checked against GitHub's published asset digests):

- `procs` Linux zip from `dalance/procs`; upstream does not publish release checksums.

Third-party build (pinned, checksum-verified):

- Ghostty AppImage for Linux from `pkgforge-dev/ghostty-appimage`: not built by
  the Ghostty project (which publishes no Linux binaries). The version and
  GitHub's SHA-256 digest are pinned in `install.sh`; no signature or
  attestation is published; its CI verifies upstream's minisign on the source.

VS Code: `vscode/merge-settings.py` writes only the tracked keys into the user
settings file and refuses the keys other provisioning owns; extensions are
installed by id from the Marketplace through the `code` CLI.

Current npm-managed CLI installs:

- `hunkdiff`
- `@anthropic-ai/claude-code`
- `@openai/codex`

Global npm CLIs managed by mise (`.config/mise/config.toml`, exact versions):

- `@bitwarden/cli`, `@earendil-works/pi-coding-agent`: install scripts skipped.
- `@googleworkspace/cli`, `pinchtab`: install scripts allowed; they download
  the pinned release binary and verify its SHA-256 checksum.
- `tmux-ide`: install script allowed; it links the package's own workspace
  packages and restores executable bits.

## Secrets Handling

- Never store real secrets in this repo.
- Use local files only:
  - `~/.secrets` for credentials/tokens
  - `~/.bash_local` for machine/project-specific configuration
- Ensure `~/.secrets` permissions are restricted (`chmod 600 ~/.secrets`).
- Values exported from `~/.secrets` are inherited by child processes. Prefer short-lived shell-local exports for session tokens such as `BW_SESSION`, and avoid storing long-lived secrets there unless the tool requires environment-variable auth.

## Supported Security Baseline

- Git commits/tags are signed when GPG is configured.
- Git credential helper is configured per-platform in `~/.gitconfig.local`.
- Tracked config should avoid personal identifiers and machine-specific secrets.

## Reporting a Vulnerability

Please report suspected vulnerabilities privately to the repository maintainer.

Include:

- affected file(s)
- reproduction steps
- expected vs actual behavior
- risk/impact assessment

Do not open public issues for unpatched vulnerabilities containing exploit details or secrets.

## PR Security Checklist

For pull requests touching installer logic, shell startup, git config, or secrets handling:

- [ ] No remote script execution (`curl | sh`, `wget | bash`, etc.).
- [ ] New downloads are pinned and verified (checksum/signature), or explicitly justified.
- [ ] New language package manager installs use explicit package names and are documented.
- [ ] New direct-download exceptions are listed in this file.
- [ ] No remote release version is resolved dynamically at install time.
- [ ] `./install.sh --dry-run` performs no writes or state mutations.
- [ ] No secrets, tokens, or machine-local credentials are introduced into tracked files.
- [ ] Machine-specific values are kept in local files (`~/.secrets`, `~/.bash_local`, `~/.gitconfig.local`).
- [ ] README/docs are updated when installer behavior or security assumptions change.
