# dotfiles

Bash shell environment for macOS and Linux (arm64 and x86_64). One repo, one install script, every machine configured the same way.

Security policy: see `SECURITY.md`.

## Quick Start

```bash
git clone https://github.com/<your-username>/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
./install.sh                      # install packages, symlink configs, set up templates
./install.sh --dry-run            # preview without changing anything
./install.sh --yes --no-packages  # non-interactive; no sudo, no system packages
```

| Option | Effect |
|--------|--------|
| `--dry-run` | Print what would change; write nothing |
| `--yes`, `-y` | Never prompt. Implied when stdin/stdout is not a terminal (`ssh host cmd`, Ansible, CI); `sudo` then runs as `sudo -n` and fails instead of asking for a password |
| `--no-packages` | No `sudo` and no system packages: skip brew, apt/dnf, release downloads (Ghostty included), the full `mise install` and npm installs. Still does the user-level steps: links dotfiles, configures Git, copies templates, installs the [command-line clients](#command-line-clients) through mise (unless the host manages the global mise config), the Linux [fonts](#fonts) and the [VS Code](#vs-code) settings and extensions |

The install script will:

1. **Install packages** -- `brew bundle` on macOS; `apt`/`dnf`, pinned release installs, and selected npm CLI tools on Linux
2. **Symlink dotfiles** -- 18 config files linked from the repo into `~` (an existing regular file is first copied to `~/.dotfiles-backup-<timestamp>/`, keeping its path)
3. **Configure git** -- credential helper, GPG program, signing and pager set per machine (in `~/.gitconfig.local`)
4. **Copy templates** -- `~/.secrets`, `~/.bash_local`, `~/.bash_functions`, and `~/.irbrc.local` created from templates (never overwritten)

The script is idempotent: a second run links nothing, backs up nothing, leaves
`~/.gitconfig.local` and generated completions untouched, and exits 0. It exits
non-zero when a step fails (an optional tool install failing is reported in the
summary after everything else has run).

### Command-line clients

gh, glab, jira (`ankitpokhrel/jira-cli`), confluence (`pchuri/confluence-cli`)
and aws (AWS CLI v2) come from `.config/mise/conf.d/dotfiles-clis.toml`, linked
to `~/.config/mise/conf.d/`, with pinned versions on every platform. The
installer runs `mise install` for exactly these tools, user-level and without
`sudo`, also with `--no-packages`; mise's shims and activated paths put them
ahead of any Homebrew or distro copy. Versions: aws-cli 2.41.1, jira-cli 1.7.0
and glab 1.131.0 as EBA's host tool lock pins them; gh 2.105.0 and
confluence-cli 2.31.2 (latest when pinned).

On a host whose provisioning owns the global mise config (a regular
`~/.config/mise/config.toml` with `mise.lock` beside it), the file is **not**
linked and nothing is installed: that host's locked `mise install` reads every
`conf.d/*.toml` and would refuse tools its lock does not pin, so the host's own
lock provides the clients. There `--no-packages` is links and local config only.

### VS Code

When `code` is on PATH (also with `--no-packages`), the installer merges
`vscode/settings.json` into the user settings file (macOS
`~/Library/Application Support/Code/User/settings.json`, Linux
`~/.config/Code/User/settings.json`) and installs the extensions in
`vscode/extensions.txt` that are missing.

- **Merge, never replace.** Only the tracked keys are written, plus
  `terminal.external.osxExec` (`Ghostty.app`) or `terminal.external.linuxExec`
  (`ghostty`) and `git.enableCommitSigning` (true only when GPG has a secret
  key, as for Git). Every other key and every comment stays; a key whose value
  already matches is not touched, so a rerun writes nothing. The file may be
  JSONC (comments, trailing commas).
- **Keys other provisioning owns** are never written: `rubyLsp.rubyVersionManager`,
  `hadolint.hadolintPath`, `ansible.python.interpreterPath`,
  `settingsSync.ignoredSettings` (EBA's Ansible merges them on its machines).
- **Not tracked on purpose:** machine paths, Ruby formatter settings (Ruby LSP
  formats Ruby), personal connections, Copilot/chat/MCP keys, `yaml.schemas`,
  and `claudeCode.allowDangerouslySkipPermissions` (add it yourself).
- Family-baseline extensions are not listed: EBA's repositories recommend them.

### Fonts

macOS: the Brewfile casks (Iosevka, Iosevka Term, JetBrains Mono Nerd Fonts).
Linux (also with `--no-packages`, no `sudo`): Iosevka Nerd Font (VS Code) and
IosevkaTerm Nerd Font (Ghostty), Nerd Fonts v3.5.1, in
`~/.local/share/fonts/<name>NerdFont/` with their four base styles (Regular,
Bold, Italic, Bold Italic; the archives' other weights would take ~1 GB), then
`fc-cache`. Archives are checked against GitHub's published SHA-256 digests,
downloaded into `~/.cache/dotfiles` and removed after unpacking; a `.sha256`
marker makes reruns download nothing.

### Ghostty

macOS: the Brewfile cask. Linux (package path only, not `--no-packages`):
Ghostty has no official Linux package, Flathub app or EPEL package, so the
installer puts the pinned AppImage from
[pkgforge-dev/ghostty-appimage](https://github.com/pkgforge-dev/ghostty-appimage)
(1.4.0, checked against GitHub's SHA-256 digest; its CI verifies upstream's
minisign on the source) in `~/.local/opt/ghostty`, links `~/.local/bin/ghostty`
and adds a desktop entry. It is skipped when a `ghostty` package is installed.
`.config/ghostty/config` turns on `ssh-terminfo` and `ssh-env`, so Ghostty
installs its terminfo on hosts it SSHes to.

### Provisioned hosts

On a host whose provisioning already set up the shell (for example a managed
Linux workstation), run it as the host's user with:

```bash
cd /path/to/dotfiles && ./install.sh --yes --no-packages
```

- **Host environment.** `.bashrc` sources `~/.bash.eba` when it exists, before
  anything else and in every bash (interactive or not), so the host's PATH, mise,
  prompt, completion and helpers still load. Each tool `.bashrc` initialises
  afterwards (mise, direnv, starship, bash-completion, zoxide, fzf, atuin, aws
  and generated completions) is skipped when that file already set it up.
  On Linux `.bashrc` also loads `/etc/bashrc`, as the distribution's own does.
- **Host-managed mise.** When `~/.config/mise/config.toml` is a regular file with
  a `mise.lock` beside it, the provisioning owns the global mise config: the
  installer links neither dotfiles' mise config nor its `conf.d` file and runs
  no `mise install` (no command-line clients, no npm CLIs).
- **Tools already present stay.** Without `--no-packages`, every package and
  pinned tool is skipped when its command is already on PATH (the installer adds
  `~/.local/bin` and mise's shims to PATH first), so a host-installed version is
  never replaced. dnf/apt packages missing from every enabled repository are
  skipped with a note (on EL10: `mysql` comes from `mysql8.4`; `eza` and
  `tealdeer` have no package; fzf, fd, bat, ripgrep and git-delta need EPEL).
- **Git.** An existing `~/.git-credentials` keeps working: on Linux the `store`
  helper comes first. Commits and tags are signed only when a GPG secret key
  exists. `core.pager` is `hunk pager`, else `delta`, else Git's default.

## Branches

| Branch | Use it on | Contents |
|--------|-----------|----------|
| `master` | Any machine | The shared base |
| `dotfiles-eba` | EBA workstations (EBA's Ansible installs from it) | `master` plus EBA-specific behaviour, such as the check that its pins match EBA's (`test/eba-versions.sh`) |

Changes flow one way, `master` → `dotfiles-eba`, by merge; never merge
`dotfiles-eba` into `master`. Make a change that helps every machine on
`master`, then sync:

```bash
git switch master && git pull --ff-only
git switch dotfiles-eba && git pull --ff-only
git merge master && git push
```

## Tools

### Shell Experience

| Tool | What it does | Config |
|------|-------------|--------|
| [Bash](https://www.gnu.org/software/bash/) | Shell | `.bash_profile`, `.bashrc`, `.bash_aliases` |
| [Starship](https://starship.rs/) | Cross-shell prompt with git, ruby, battery, etc. | `.config/starship.toml` |
| [Atuin](https://atuin.sh/) | Searchable shell history synced across machines | `.config/atuin/config.toml` |
| [FZF](https://github.com/junegunn/fzf) | Fuzzy finder for files, directories, history | keybindings in `.bashrc` |
| [Zoxide](https://github.com/ajeetdsouza/zoxide) | Smarter `cd` -- learns your most-used directories | init in `.bashrc` |
| [Tmux](https://github.com/tmux/tmux) | Terminal multiplexer with tpm, sessionx, powerkit, yank, fzf | `.tmux.conf` |
| [Ghostty](https://ghostty.org/) | GPU-accelerated terminal emulator (macOS) | `.config/ghostty/config` |

### Git And Code Review

| Tool | What it does | Config |
|------|-------------|--------|
| [Git](https://git-scm.com/) | Version control with Hunk diffs, GPG signing, 35+ aliases | `.gitconfig`, `.gitignore_global` |
| [Hunk](https://github.com/modem-dev/hunk) | Review-first terminal diff viewer | `.gitconfig` pager |
| [lazygit](https://github.com/jesseduffield/lazygit) | Terminal UI for Git workflows | mise / Homebrew |
| [gh](https://cli.github.com/) | GitHub CLI | `.config/gh/config.yml` |
| [glab](https://gitlab.com/gitlab-org/cli) | GitLab CLI | `.config/glab-cli/aliases.yml` |
| [Git Credential Manager](https://github.com/git-ecosystem/git-credential-manager) | HTTPS credential helper (macOS cask) | `~/.gitconfig.local` |
| [GnuPG](https://gnupg.org/) | GPG signing for git commits | signing config in `.gitconfig` |

### Editing And Text Navigation

| Tool | What it does | Config |
|------|-------------|--------|
| [Vim](https://www.vim.org/) | Text editor with vim-plug and 6 plugins | `.vimrc` |
| [bat](https://github.com/sharkdp/bat) | `cat` with syntax highlighting and line numbers | aliased in `.bash_aliases` |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Fast recursive `grep` replacement | aliased in `.bash_aliases` |
| [fd](https://github.com/sharkdp/fd) | Fast file finder (`find` replacement) | `.config/fd/ignore` |
| [tealdeer](https://github.com/tealdeer-rs/tealdeer) | Fast `tldr` client -- simplified man pages | aliased as `help` |

### Files And Data

| Tool | What it does | Config |
|------|-------------|--------|
| [eza](https://github.com/eza-community/eza) | Modern `ls` replacement with icons and git status | aliased in `.bash_aliases` |
| [jq](https://jqlang.github.io/jq/) | JSON processor for the command line | standalone |
| [yq](https://github.com/mikefarah/yq) | YAML, XML, TOML, and JSON processor | standalone |
| [MySQL client](https://dev.mysql.com/doc/refman/en/mysql.html) | MySQL command-line client libraries and tools | PATH in `.bash_profile` |
| [PostgreSQL client](https://www.postgresql.org/docs/current/app-psql.html) | `psql` and libpq client tools | PATH in `.bash_profile` |
| [SOPS](https://getsops.io/) | Editor for encrypted files | standalone |

### System And Containers

| Tool | What it does | Config |
|------|-------------|--------|
| [htop](https://htop.dev/) | Interactive process viewer | `.config/htop/htoprc` |
| [procs](https://github.com/dalance/procs) | Modern `ps` replacement with color and tree view | aliased in `.bash_aliases` |
| [dtop](https://dtop.dev/) | Terminal dashboard for Docker container monitoring | standalone |
| [lazydocker](https://github.com/jesseduffield/lazydocker) | Terminal UI for Docker containers | mise / Homebrew |
| [Smug](https://github.com/ivaaaan/smug) | Tmux session manager | layouts in `~/.config/smug/` |
| [rsync](https://rsync.samba.org/) | File sync (newer than the macOS copy) | standalone |
| [watch](https://gitlab.com/procps-ng/procps) | Re-run a command on an interval | standalone |

### App Development

macOS prerequisites for Rails apps whose services run in Docker. Project
runtimes and tool pins (Ruby, Node, Python, Terraform, SOPS, age, ...) come
from each repository's `mise.toml`.

| Tool | What it does | Config |
|------|-------------|--------|
| [Colima](https://github.com/abiosoft/colima) | Docker engine VM for macOS | `colima start --cpu 4 --memory 8` |
| [Docker CLI](https://docs.docker.com/engine/reference/commandline/cli/) + Compose | Container CLI for app services | Docker context `colima` |
| [AWS CLI](https://aws.amazon.com/cli/) | AWS command line | completion in `.bashrc`; `AWS_PROFILE` in `~/.bash_local` |
| [jira-cli](https://github.com/ankitpokhrel/jira-cli) | Jira from the terminal (`jira`) | token in `~/.secrets` |
| [Oracle Instant Client](https://www.oracle.com/database/technologies/instant-client.html) | `ruby-oci8` libraries and `sqlplus` | `OCI_DIR` in `~/.bash_local` |
| [uv](https://docs.astral.sh/uv/) | Python package and tool runner | standalone |

Homebrew's Compose is a Docker CLI plugin. For `docker compose` to find it,
add `$(brew --prefix)/lib/docker/cli-plugins` to `~/.docker/config.json`
(that file also holds registry logins, so it is not tracked here). On Apple
silicon:

```json
"cliPluginsExtraDirs": ["/opt/homebrew/lib/docker/cli-plugins"]
```

### Personal Tools

`go`, `bun`, `iperf3`, `jpeg-xl`, `lima`, `mole`, `nmap`, `ollama`,
and `openapi-generator`: installed from the Brewfile's "Personal tools"
section; none needs dotfiles config. `confluence-cli` is one of the
[command-line clients](#command-line-clients).

### Runtimes And Tool Versions

| Tool | What it does | Config |
|------|-------------|--------|
| [mise](https://mise.jdx.dev/) | Tool version manager for Ruby, Node, Python, and shell tools | `.config/mise/config.toml`, activate in `.bashrc` |

Global npm CLIs are mise tools (`npm:` backend) so they survive Node upgrades:
`bw` (`@bitwarden/cli`), `gws` (`@googleworkspace/cli`), `pinchtab`, `pi`
(`@earendil-works/pi-coding-agent`) and `tmux-ide`. mise installs them with
npm and skips install scripts unless the tool opts in with `npm_args`
(`gws`, `pinchtab`, `tmux-ide`).

### AI And Automation

| Tool | What it does | Config |
|------|-------------|--------|
| [Claude Code](https://www.anthropic.com/claude-code) | Claude coding agent in the terminal | standalone |
| [Codex CLI](https://github.com/openai/codex) | OpenAI coding agent in the terminal | standalone |
| [rtk](https://www.rtk-ai.app/) | CLI proxy for compact command output in AI-assisted workflows | standalone |
| [GitHub Copilot CLI](https://docs.github.com/en/copilot/concepts/agents/about-copilot-cli) | Copilot coding agent in the terminal | standalone |

---

## Tool Configuration

### Bash

Shell loads in this order:

```text
.bash_profile                         # login shell entry point
  -> brew shellenv                    #   Homebrew paths (macOS/Linuxbrew)
  -> ~/.secrets                       #   API tokens, credentials (chmod 600)
  -> .bashrc                          #   interactive shell config
       -> /etc/bashrc (Linux)         #     distribution defaults
       -> ~/.bash.eba (when present)  #     provisioned host environment
       -> shell options, history      #     cdspell, globstar, nocaseglob, ...
       -> starship                    #     prompt
       -> bash-completion             #     tab completion
       -> zoxide                      #     z: jump, zi: interactive picker
       -> fzf                         #     Ctrl-T: find files, Alt-C: cd dir
       -> bash-preexec + atuin        #     Ctrl-R: history search, Up: history
       -> aws completion              #     aws CLI tab completion
       -> mise                          #     tool version manager (ruby, node, python, etc.)
       -> ~/.bash_local               #     machine/project config
       -> ~/.bash_functions           #     machine-specific functions
       -> .bash_aliases               #     aliases, functions, compression
```

**Shell options** (`.bashrc`):

| Option | Effect |
|--------|--------|
| `histappend` | Append to history file instead of overwriting |
| `cdspell` | Autocorrect minor typos in `cd` arguments |
| `dirspell` | Autocorrect directory names during tab completion |
| `globstar` | `**` matches files and directories recursively |
| `nocaseglob` | Case-insensitive pathname expansion |
| `cmdhist` | Save multi-line commands as one history entry |

**History** (`.bashrc`, after the host environment so these values win):

| Setting | Value |
|---------|-------|
| `HISTCONTROL` | `ignoreboth:erasedups` -- skip duplicates and space-prefixed commands |
| `HISTSIZE` | 100,000 lines in memory |
| `HISTFILESIZE` | 200,000 lines on disk |

### Aliases and Functions

Defined in `.bash_aliases`. All aliases adapt to the current platform.

| Alias | Command | Notes |
|-------|---------|-------|
| `ls` | `eza` (or `ls -G`/`ls --color` fallback) | Translates `-p` to `--classify` for eza |
| `lsm` | `eza -lah --icons --group-directories-first` | Detailed listing with icons |
| `tree` | `eza --tree --icons` | Tree view (eza) |
| `cat` | `bat --paging=never` | Syntax-highlighted cat (bat) |
| `catp` | `bat` | bat with pager |
| `grep` | `rg` | ripgrep (if available) |
| `ps` | `procs` | Modern ps (if available) |
| `up` | `cd ..` | |
| `cls` | `clear; lsm` | Clear screen and list |
| `update` | `brew upgrade` / `apt upgrade` / `dnf upgrade` | Platform-aware |
| `myip` | `curl icanhazip.com` | Public IP address |
| `plz` | Re-run last command with `sudo` | |
| `space` | `df -h` | Disk free space |
| `used` | `du -ch -d 1` | Directory sizes |
| `restart` | `source ~/.bash_profile` | Reload shell config |
| `ports` | `lsof` (mac) / `ss -tlnp` (linux) | Listening ports |
| `reveal` | `open .` (mac) / `xdg-open .` (linux) | Open file manager |
| `download` | `wget -r -p --no-parent ...` | Mirror a web page |

| Function | Usage |
|----------|-------|
| `weather` | `weather London` -- terminal weather forecast |
| `incognito` | `incognito start/stop` -- disable/enable history |
| `pman` | `pman grep` -- render man page as PDF |
| `help` | `help curl` -- simplified man page (tealdeer) |
| `aliases` | `aliases` -- list all aliases and functions with descriptions |

**File compression** (requires jpegoptim, pngquant, oxipng, ghostscript, img2pdf -- installed via Brewfile):

| Function | Usage |
|----------|-------|
| `jpgsize` | `jpgsize photo.jpg 500` -- compress JPEG to target size (KB) |
| `jpgq` | `jpgq photo.jpg 80` -- compress JPEG to quality level (0-100) |
| `pngsmall` | `pngsmall photo.png [60-80]` -- lossy + lossless PNG compression |
| `pdfsmall` | `pdfsmall input.pdf [output.pdf] [screen\|ebook\|printer]` -- compress PDF |
| `pdfunlock` | `pdfunlock file.pdf` -- remove password protection from PDFs |
| `imgs2pdf` | `imgs2pdf output.pdf *.jpg` -- combine images into a single PDF |

### Starship

Cross-shell prompt. Configured in `.config/starship.toml`.

Displays: username, hostname, directory (truncated to 5 levels), git branch/state, ruby version, python version, command duration (>10s), battery (warning at 10%), clock, sudo indicator, error indicator.

Disabled modules: `package`, `nodejs`.

### Atuin

Shell history search and sync. Configured in `.config/atuin/config.toml`.

| Setting | Value |
|---------|-------|
| Search mode | Fuzzy |
| Style | Compact |
| Sync | Every 10 minutes; server from `ATUIN_SYNC_ADDRESS` in `~/.bash_local` (default `https://api.atuin.sh`) |
| Secrets filter | On (hides commands with tokens/passwords) |
| Enter accept | On (Enter runs selected command) |

Keybindings (set in `.bashrc`):

| Key | Action |
|-----|--------|
| `Ctrl-R` | Search history (replaces default) |
| `Up arrow` | Browse history with context |

### FZF

Fuzzy finder. Keybindings loaded in `.bashrc`.

| Key | Action |
|-----|--------|
| `Ctrl-T` | Find and insert a file path |
| `Alt-C` | Find and cd into a directory |

### Zoxide

Smarter `cd` that learns your most-used directories. Initialized in `.bashrc`.

| Command | Action |
|---------|--------|
| `z foo` | Jump to the most-used directory matching "foo" |
| `zi foo` | Interactive picker with FZF |

### Git

Configured in `.gitconfig` with Hunk as the pager.

**Hunk** (diff pager):

| Command | Action |
|---------|--------|
| `git diff` | Review working tree changes in Hunk |
| `git show` | Review commit changes in Hunk |
| `hunk diff` | Review current repo changes, including untracked files |

**Diff and merge:**

| Tool | Usage |
|------|-------|
| VS Code | `git difftool` / `git mergetool` open VS Code |
| zdiff3 | Conflicts show base + ours + theirs |
| rerere | Remembers conflict resolutions for reuse |

**Signing:** Commits and tags are GPG-signed by default. `git ci` auto-detects GPG and falls back to unsigned with a warning.

**Key settings:**

| Setting | Value |
|---------|-------|
| `push.autoSetupRemote` | Auto-create remote tracking branch on first push |
| `pull.ff` | `only` -- refuse non-fast-forward pulls |
| `fetch.prune` | Auto-remove stale remote branches |
| `rebase.autoSquash` | Auto-squash `fixup!` commits |
| `rebase.autoStash` | Stash before rebase, apply after |
| `branch.sort` | Most recent branches first |
| `transfer.fsckObjects` | Verify object integrity |

**Credentials:** Set per-platform by `install.sh` into `~/.gitconfig.local`.
On Linux an existing `~/.git-credentials` keeps working (`store` first). Git
Credential Manager is preferred when installed, with osxkeychain on macOS
and libsecret/cache on Linux as fallbacks.

**Signing and pager:** `install.sh` sets `commit.gpgsign`/`tag.gpgsign` to
`true` only when GPG has a secret key (rerun it after adding one), and
`core.pager` to `hunk pager`, else `delta`, else Git's default. Set `DOTFILES_GITHUB_USERNAME` before
install to write a GitHub-specific username into local config.

**Aliases** (35+):

```text
# Shortcuts
git a               Interactive staging (add -p)
git b               Branch
git co              Checkout
git cp              Cherry-pick
git d               Diff
git s               Status (short)
git p               Push

# Commits
git ci              Smart commit (GPG auto-detect, fallback to unsigned)
git cns             Commit without signing
git amend           Amend last commit, keep message
git wip             Stage all + commit "WIP"
git unwip           Undo WIP commit
git fixup SHA       Create fixup commit for SHA

# History
git l               One-line graph log
git lg              Graph log (no merges)
git hist            Detailed graph with dates and authors
git last            Last commit with file stats
git today           Your commits today
git standup         Your commits since yesterday
git contributors    Contributor stats

# Diff
git staged          Staged changes
git unstaged        Unstaged changes

# Branches
git branches        All branches (local + remote)
git remotes         List remotes
git fresh           Fetch all + prune + status
git cleanup         Delete merged branches (keeps main/master/develop)

# Rebase
git up              Pull with rebase + autostash
git pwl             Push --force-with-lease
git r               Interactive rebase

# Worktrees
git wta             Add worktree
git wtl             List worktrees
git wtr             Remove worktree
git wtp             Prune worktrees

# Utilities
git root            Print repo root path
git whoami          Configured name and email
git aliases         List all aliases
git ignore LANG     Generate .gitignore from gitignore.io
git undo            Undo last commit (keep changes)
git nuke            Reset to remote HEAD (dangerous!)
```

Full list: `git aliases`

### GitHub CLI (gh)

Configured in `.config/gh/config.yml`. Uses HTTPS protocol. `co` alias runs `pr checkout`.

Auth managed by `gh auth login` (stored in system keychain).

### GitLab CLI (glab)

Aliases in `.config/glab-cli/aliases.yml`:

| Alias | Command |
|-------|---------|
| `glab ci` | View pipeline status |
| `glab co` | Checkout a merge request |

Auth managed by `glab auth login` (stored in `~/.config/glab-cli/config.yml`, not in dotfiles).

### lazygit

Terminal UI for common Git workflows.

| Command | Action |
|---------|--------|
| `lazygit` | Open the Git TUI for the current repository |

### Vim

Configured in `.vimrc` for casual editing -- search, replace, log viewing. Uses [vim-plug](https://github.com/junegunn/vim-plug) for plugin management (auto-installed on first run).

**Settings:**

| Setting | Value |
|---------|-------|
| Line numbers | On |
| Cursor line | Highlighted |
| Mouse | All modes (`mouse=a`) |
| Clipboard | System clipboard (yank/paste shared with OS) |
| Tab width | 2 spaces (expandtab) |
| Search | Incremental, highlighted, case-smart |
| `gdefault` | `:s` replaces all occurrences by default |
| Scroll offset | 5 lines above/below cursor |

**Search and replace:**

| Key / Command | Action |
|---------------|--------|
| `/pattern` | Search forward |
| `?pattern` | Search backward |
| `n` / `N` | Next / previous match |
| `*` | Search word under cursor |
| Visual select + `*` | Search for selected text |
| `Esc` | Clear search highlights |
| `:%s/old/new/` | Replace all in file (no `/g` needed) |
| `:%s/old/new/c` | Replace all with confirmation |
| `:5,20s/old/new/` | Replace in lines 5--20 |

**Copy/paste:** `clipboard=unnamed` connects vim to the system clipboard. With `mouse=a`, use Option+drag in Ghostty for terminal text selection, or drag + `y` for vim yank to clipboard.

**Plugins** (6, managed by vim-plug):

| Plugin | Purpose | Key commands |
|--------|---------|-------------|
| [AnsiEsc](https://github.com/powerman/vim-plugin-AnsiEsc) | Render ANSI colors (auto on `*.log`) | `:AnsiEsc` toggle |
| [vim-surround](https://github.com/tpope/vim-surround) | Change/add/delete surroundings | `cs"'` `ds"` `ysiw"` `S"` |
| [vim-repeat](https://github.com/tpope/vim-repeat) | Dot-repeat for surround and others | `.` repeats plugin commands |
| [vim-commentary](https://github.com/tpope/vim-commentary) | Toggle comments | `gcc` line, `gc` selection, `gcap` paragraph |
| [vim-visual-star-search](https://github.com/nelstrom/vim-visual-star-search) | Search for visual selection | Select text, press `*` |
| [emmet-vim](https://github.com/mattn/emmet-vim) | HTML/CSS shorthand expansion | `Ctrl-y ,` expand |

**Filetype detection:** `.bash*` and `.env*` -> shell. `*.properties` -> Java properties.

Update plugins: `:PlugUpdate`

### Tmux

Configured in `.tmux.conf`. Uses [TPM](https://github.com/tmux-plugins/tpm) for plugins.

| Plugin | Purpose |
|--------|---------|
| tmux-sensible | Sensible defaults |
| tmux-pain-control | Intuitive pane navigation and resizing |
| tmux-mode-indicator | Shows current mode in status bar |
| tmux-power-zoom | Toggle pane zoom |
| tmux-yank | Copy to system clipboard |
| tmux-fzf | FZF integration for sessions, windows, panes |
| tmux-sessionx | Session manager (`prefix + O`) |
| tmux-powerkit | Status bar: datetime, battery, CPU, memory, git, hostname |

Mouse enabled. Catppuccin Mocha theme. Status bar shows date, time, and mode.

First-time setup:

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# Inside tmux: prefix + I to install plugins
```

### Ghostty

Terminal emulator (macOS). Configured in `.config/ghostty/config`.

| Setting | Value |
|---------|-------|
| Theme | Tokyo Night |
| Font | Iosevka Term Nerd Font, 12pt |
| Background | 98% opacity with blur |
| Cursor | Bar, no blink |
| Copy on select | On (auto-copies to clipboard) |
| Window state | Restored on restart |
| Shell integration | Bash |

### htop

Process viewer. Configured in `.config/htop/htoprc`.

| Setting | Value |
|---------|-------|
| Color scheme | Black Night |
| Sort | CPU% descending |
| Kernel/userland threads | Hidden |
| CPU detail | Broken into usr/sys/nice/irq |
| CPU frequency | Shown |
| Layout | Two columns: CPU/battery (left), memory/disk/network (right) |
| Screens | Main (processes), I/O (disk rates) |

### bat

`cat` replacement with syntax highlighting and line numbers. Aliased as `cat` in `.bash_aliases`.

| Command | Action |
|---------|--------|
| `cat file.rb` | Syntax-highlighted output (no pager) |
| `catp file.rb` | Same but with pager for long files |
| `bat --list-themes` | Preview available color themes |

### ripgrep (rg)

Fast recursive grep. Aliased as `grep` in `.bash_aliases`.

| Command | Action |
|---------|--------|
| `grep pattern` | Recursive search in current directory |
| `rg -i pattern` | Case-insensitive search |
| `rg pattern -t ruby` | Search only Ruby files |
| `rg pattern -g '*.yml'` | Search only YAML files |
| `rg -l pattern` | List matching files only |

### eza

Modern `ls` replacement with icons and git status. Aliased as `ls` in `.bash_aliases`.

| Command | Action |
|---------|--------|
| `ls` | List files (eza). `-p` auto-translates to `--classify` |
| `ls -apl` | Works as expected -- `-p` is stripped and `--classify` added |
| `lsm` | Detailed list with icons, grouped directories first |
| `tree` | Tree view with icons |

### jq

JSON processor. Use it to parse and transform JSON from APIs and files.

| Command | Action |
|---------|--------|
| `curl ... \| jq .` | Pretty-print JSON |
| `jq '.key'` | Extract a key |
| `jq '.items[] \| .name'` | Extract nested values |

### yq

YAML, XML, TOML, and JSON processor. Use it for config files and structured CLI output.

| Command | Action |
|---------|--------|
| `yq '.key' file.yml` | Read a YAML key |
| `yq -o=json file.yml` | Convert YAML to JSON |
| `yq -i '.key = "value"' file.yml` | Edit a YAML file in place |

### tealdeer (tldr)

Simplified man pages with practical examples. Aliased as `help` in `.bash_aliases`.

| Command | Action |
|---------|--------|
| `help curl` | Show common curl examples |
| `tldr --update` | Update the local page cache |

### procs

Modern `ps` replacement. Aliased as `ps` in `.bash_aliases`.

| Command | Action |
|---------|--------|
| `ps` | List all processes (color, sortable) |
| `procs ruby` | Filter processes matching "ruby" |
| `procs --tree` | Process tree view |

### fd

Fast file finder. Ignore patterns in `.config/fd/ignore`:

- `.git`
- `Library/CloudStorage`, `Library/Mobile Documents`, `Library/Application Support/CloudDocs`

### dtop

Docker terminal dashboard installed by Homebrew.

| Command | Action |
|---------|--------|
| `dtop` | Monitor local Docker containers |

### lazydocker

Terminal UI for Docker containers and compose services.

| Command | Action |
|---------|--------|
| `lazydocker` | Open the Docker TUI |

### MySQL Client

macOS installs `mysql-client` with Homebrew as a keg-only formula. `.bash_profile`
adds the client bin directory to `PATH`. Linux installs the distro package:
`default-mysql-client` on apt systems and `mysql` on dnf systems.

| Command | Action |
|---------|--------|
| `mysql --version` | Verify the MySQL client is available |
| `mysql -h HOST -u USER -p` | Connect to a MySQL server |

### PostgreSQL Client

macOS installs `libpq` with Homebrew as a keg-only formula. `.bash_profile`
adds the client bin directory to `PATH`. Linux installs `postgresql-client` on
apt systems and `postgresql` on dnf systems.

| Command | Action |
|---------|--------|
| `psql --version` | Verify the PostgreSQL client is available |
| `psql "postgresql://USER@HOST/DB"` | Connect to a PostgreSQL server |

### SOPS

Editor for encrypted YAML, JSON, ENV, INI, and binary files.

| Command | Action |
|---------|--------|
| `sops --version` | Verify SOPS is available |
| `sops secrets.yml` | Edit an encrypted file |
| `sops -d secrets.yml` | Decrypt to stdout |

### rtk

CLI proxy for compact command output in AI-assisted workflows.

| Command | Action |
|---------|--------|
| `rtk <command>` | Run a command with compact, structured output |

### Claude Code

Claude coding agent for the terminal, installed as the `claude` command.

| Command | Action |
|---------|--------|
| `claude` | Start Claude Code |

### Codex CLI

OpenAI coding agent for the terminal, installed as the `codex` command.

| Command | Action |
|---------|--------|
| `codex` | Start Codex CLI |

### GitHub Copilot CLI

Copilot coding agent for the terminal, installed as the `copilot` command.

| Command | Action |
|---------|--------|
| `copilot` | Start or use GitHub Copilot CLI |

### Ruby (IRB)

Configured in `.irbrc`: 10,000 history entries and custom completion dialog colors. Machine/project helpers live in `~/.irbrc.local`, created from `.irbrc.local.template`.

### Global Gitignore

Two files:

| File | Applied via |
|------|-------------|
| `.gitignore_global` | `core.excludesfile` in `.gitconfig` |
| `.config/git/ignore` | Git XDG convention (automatic) |

Ignores: `.DS_Store`, macOS metadata (`._*`, `.Spotlight-V100`), editor files (`.swp`, `*~`, `.idea/`), env files (`.env`, `.env.local`), `*.log`, Claude Code settings.

---

## Repo Structure

```text
dotfiles/
├── install.sh                       # Package install + symlink + platform config
├── Brewfile                         # macOS Homebrew packages
├── README.md
├── CHANGELOG.md
├── .gitignore
│
├── .bash_profile                    # Login shell (brew, PATH, secrets, history)
├── .bashrc                          # Interactive shell (options, prompt, tools)
├── .bash_aliases                    # Aliases and functions
├── .bash-preexec.sh                 # Lib required by atuin
│
├── .gitconfig                       # Git (Hunk, GPG, 35+ aliases)
├── .gitignore_global                # Global gitignore
├── .vimrc                           # Vim (vim-plug, 6 plugins)
├── .tmux.conf                       # Tmux (tpm, sessionx, powerkit)
├── .irbrc                           # Ruby IRB
│
├── .secrets.template                # Template -> ~/.secrets
├── .bash_local.template             # Template -> ~/.bash_local
├── .bash_functions.template         # Template -> ~/.bash_functions
├── .irbrc.local.template            # Template -> ~/.irbrc.local
├── SECURITY.md                      # Security policy
├── LICENSE                          # MIT License
│
├── .config/
│   ├── starship.toml                # Prompt theme
│   ├── atuin/config.toml            # History sync
│   ├── mise/config.toml             # Tool versions (ruby, node, python, etc.)
│   ├── mise/conf.d/dotfiles-clis.toml  # gh, glab, jira, confluence, aws
│   ├── ghostty/config               # Terminal emulator
│   ├── fd/ignore                    # File finder ignores
│   ├── htop/htoprc                  # Process viewer
│   ├── gh/config.yml                # GitHub CLI
│   ├── glab-cli/aliases.yml         # GitLab CLI
│   └── git/ignore                   # Git ignore (XDG)
```

### Files not in repo (local to each machine)

| File | Purpose |
|------|---------|
| `~/.secrets` | Credentials and API tokens (chmod 600) |
| `~/.bash_local` | Machine/project-specific config |
| `~/.bash_functions` | Machine-specific functions (jlog, db helpers) |
| `~/.irbrc.local` | Machine/project-specific IRB helpers |
| `~/.gitconfig.local` | Platform-specific git config (credential helper, GPG) |
| `~/.config/smug/*.yml` | Tmux session layouts |
| `~/.config/glab-cli/config.yml` | GitLab auth tokens |

## Machine-Specific Config

Everything project-specific goes in `~/.bash_local` (not in the repo). The template includes commented examples for:

- Project paths and environment variables
- Database config (Oracle, PostgreSQL)
- Bundler credentials
- Machine-specific exports (`RESTIC_REPOSITORY`, `AWS_PROFILE`)

Machine-specific functions go in `~/.bash_functions` (e.g., Jira time logging, database helpers). See `.bash_functions.template`.

Credentials go in `~/.secrets` (chmod 600, sourced from `.bash_profile`).
Exported values in `~/.secrets` are inherited by child processes, so keep
session tokens short-lived and prefer one-shell exports for sensitive temporary
values.

```bash
vim ~/.bash_local       # machine/project config
vim ~/.secrets          # credentials and API tokens
```

## Cross-Platform Support

All dotfiles detect and adapt to the current platform.

| | macOS arm64 | macOS x86_64 | Linux arm64 | Linux x86_64 |
|---|---|---|---|---|
| Packages | Homebrew `/opt/homebrew` | Homebrew `/usr/local` | apt or dnf | apt or dnf |
| Git credentials | Git Credential Manager or osxkeychain | Git Credential Manager or osxkeychain | Git Credential Manager, libsecret, or cache | Git Credential Manager, libsecret, or cache |
| GPG | Auto-detected | Auto-detected | Auto-detected | Auto-detected |
| `ls` colors | `-G` | `-G` | `--color=auto` | `--color=auto` |
| Ports | `lsof` | `lsof` | `ss` | `ss` |
| File manager | `open .` | `open .` | `xdg-open .` | `xdg-open .` |
| FZF path | `/opt/homebrew/opt/fzf` | `/usr/local/opt/fzf` | `/usr/share/doc/fzf` or `/usr/share/fzf` | `/usr/share/doc/fzf` or `/usr/share/fzf` |

**Linux** (Ubuntu/Debian, Fedora/RHEL/AlmaLinux 9 and 10): `install.sh` installs the base packages apt/dnf offers (skipping ones already on PATH or in no enabled repository; it adds no repository), then installs mise which manages ruby, node, python, starship, atuin, zoxide, lazygit, and lazydocker. For other tools not in distro repos, it installs pinned release binaries, plus Hunk, Claude Code, and Codex CLI through npm after mise provisions Node. Checksums are verified when upstream publishes them; documented exceptions live in `SECURITY.md`.

Pinned direct-download tools are defined near the top of `install.sh`.

## Verification

Run these before committing installer or documentation changes:

```bash
rtk bash -n install.sh test/dry-run.sh test/idempotence.sh .bash_profile .bashrc .bash_aliases .bash_local.template .bash_functions.template
shellcheck install.sh test/*.sh
rtk test/dry-run.sh
rtk test/idempotence.sh
rtk npx --yes cspell --no-progress --gitignore --dot "**/*"
HOMEBREW_NO_AUTO_UPDATE=1 rtk brew bundle check --file=Brewfile --verbose
```

`brew bundle check` reports newly added formulae or casks until they are installed with `brew bundle install --file=Brewfile`.

## Adding New Dotfiles

1. Add the file to the repo
2. Add its path to `HOME_FILES` or `CONFIG_FILES` in `install.sh`
3. Run `./install.sh` -- idempotent (skips existing correct symlinks)

## Updating

Dotfiles are symlinked, so edits in `~` are reflected in the repo. Just commit and push.

```bash
cd ~/dev/dotfiles && git add -p && git commit && git push
```

On another machine: `cd ~/dev/dotfiles && git pull`

## Post-Install

```bash
vim ~/.bash_local                  # configure for this machine
vim ~/.secrets                     # add credentials
export DOTFILES_GIT_NAME="Your Name" DOTFILES_GIT_EMAIL="you@example.com"
export DOTFILES_GITHUB_USERNAME="your-github-username"
./install.sh                       # apply machine-local git identity
gh auth login                      # GitHub CLI auth
glab auth login -h <your-host>     # GitLab CLI auth (if needed)
```
