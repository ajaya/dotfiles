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

Current checksum exceptions:

- IosevkaTerm Nerd Font archive from `ryanoasis/nerd-fonts`; upstream does not publish per-font checksums.
- `procs` Linux zip from `dalance/procs`; upstream does not publish release checksums.

Current npm-managed CLI installs:

- `hunkdiff`
- `@anthropic-ai/claude-code`
- `@openai/codex`

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
