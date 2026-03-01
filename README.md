# dotfiles

Bash shell environment for macOS and Linux (arm64 and x86_64). One repo, one install script, every machine configured the same way.

Security policy: see `SECURITY.md`.

## Quick Start

```bash
git clone https://github.com/<your-username>/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
./install.sh            # install packages, symlink configs, set up templates
./install.sh --dry-run   # preview without changing anything
```

The install script will:

1. **Install packages** -- `brew bundle` on macOS; `apt`/`dnf` + verified binary installs on Linux
2. **Symlink dotfiles** -- 18 config files linked from the repo into `~`
3. **Configure git** -- credential helper and GPG program set per platform (in `~/.gitconfig.local`)
4. **Copy templates** -- `~/.secrets` and `~/.bash_local` created from templates (never overwritten)

## Tools

| Tool | What it does | Config |
|------|-------------|--------|
| [Bash](https://www.gnu.org/software/bash/) | Shell | `.bash_profile`, `.bashrc`, `.bash_aliases` |
| [Starship](https://starship.rs/) | Cross-shell prompt with git, ruby, battery, etc. | `.config/starship.toml` |
| [Atuin](https://atuin.sh/) | Searchable shell history synced across machines | `.config/atuin/config.toml` |
| [FZF](https://github.com/junegunn/fzf) | Fuzzy finder for files, directories, history | keybindings in `.bashrc` |
| [Zoxide](https://github.com/ajeetdsouza/zoxide) | Smarter `cd` -- learns your most-used directories | init in `.bashrc` |
| [Git](https://git-scm.com/) | Version control with delta diffs, GPG signing, 35+ aliases | `.gitconfig`, `.gitignore_global` |
| [Delta](https://github.com/dandavison/delta) | Syntax-highlighted git diffs and blame | section in `.gitconfig` |
| [gh](https://cli.github.com/) | GitHub CLI | `.config/gh/config.yml` |
| [glab](https://gitlab.com/gitlab-org/cli) | GitLab CLI | `.config/glab-cli/aliases.yml` |
| [Vim](https://www.vim.org/) | Text editor with vim-plug and 6 plugins | `.vimrc` |
| [Tmux](https://github.com/tmux/tmux) | Terminal multiplexer with tpm, powerkit, yank, fzf | `.tmux.conf` |
| [Ghostty](https://ghostty.org/) | GPU-accelerated terminal emulator (macOS) | `.config/ghostty/config` |
| [htop](https://htop.dev/) | Interactive process viewer | `.config/htop/htoprc` |
| [bat](https://github.com/sharkdp/bat) | `cat` with syntax highlighting and line numbers | aliased in `.bash_aliases` |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Fast recursive `grep` replacement | aliased in `.bash_aliases` |
| [eza](https://github.com/eza-community/eza) | Modern `ls` replacement with icons and git status | aliased in `.bash_aliases` |
| [jq](https://jqlang.github.io/jq/) | JSON processor for the command line | standalone |
| [tealdeer](https://github.com/tealdeer-rs/tealdeer) | Fast `tldr` client -- simplified man pages | aliased as `help` |
| [procs](https://github.com/dalance/procs) | Modern `ps` replacement with color and tree view | aliased in `.bash_aliases` |
| [fd](https://github.com/sharkdp/fd) | Fast file finder (`find` replacement) | `.config/fd/ignore` |
| [Smug](https://github.com/ivaaaan/smug) | Tmux session manager | layouts in `~/.config/smug/` |
| [rv](https://rv.dev/) | Ruby version manager | init in `.bashrc` |
| [GnuPG](https://gnupg.org/) | GPG signing for git commits | signing config in `.gitconfig` |

---

## Tool Configuration

### Bash

Shell loads in this order:

```text
.bash_profile                         # login shell entry point
  -> brew shellenv                    #   Homebrew paths (macOS/Linuxbrew)
  -> ~/.secrets                       #   API tokens, credentials (chmod 600)
  -> .bashrc                          #   interactive shell config
       -> shell options               #     cdspell, globstar, nocaseglob, ...
       -> starship                    #     prompt
       -> bash-completion             #     tab completion
       -> zoxide                      #     z: jump, zi: interactive picker
       -> fzf                         #     Ctrl-T: find files, Alt-C: cd dir
       -> bash-preexec + atuin        #     Ctrl-R: history search, Up: history
       -> aws completion              #     aws CLI tab completion
       -> rv                           #     Ruby version manager
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

**History** (`.bash_profile`):

| Setting | Value |
|---------|-------|
| `HISTCONTROL` | `ignoreboth:erasedups` -- skip duplicates and space-prefixed commands |
| `HISTSIZE` | 100,000 lines in memory |
| `HISTFILESIZE` | 200,000 lines on disk |

### Aliases and Functions

Defined in `.bash_aliases`. All aliases adapt to the current platform.

| Alias | Command | Notes |
|-------|---------|-------|
| `ls` | `eza` (or `ls -G`/`ls --color` fallback) | Uses eza if available |
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

**File compression** (requires jpegoptim, pngquant, oxipng, ghostscript, img2pdf -- installed via Brewfile):

| Function | Usage |
|----------|-------|
| `jpgsize` | `jpgsize photo.jpg 500` -- compress JPEG to target size (KB) |
| `jpgq` | `jpgq photo.jpg 80` -- compress JPEG to quality level (0-100) |
| `pngsmall` | `pngsmall photo.png [60-80]` -- lossy + lossless PNG compression |
| `pdfsmall` | `pdfsmall input.pdf [output.pdf] [screen\|ebook\|printer]` -- compress PDF |
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
| Sync | Every 10 minutes |
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

Configured in `.gitconfig` with delta as the pager.

**Delta** (diff pager):

| Setting | Value |
|---------|-------|
| Line numbers | On |
| Navigate | `n`/`N` to jump between hunks |
| Syntax theme | Dracula |
| Hyperlinks | On (clickable paths in Ghostty) |
| Side-by-side | Off by default (`git diff -s` for side-by-side) |

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

**Credentials:** Set per-platform by `install.sh` into `~/.gitconfig.local` -- osxkeychain on macOS, libsecret (or cache) on Linux.

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
| Font | IosevkaTerm Nerd Font, 12pt |
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
| `ls` | List files (eza) |
| `lsm` | Detailed list with icons, grouped directories first |
| `tree` | Tree view with icons |

### jq

JSON processor. Use it to parse and transform JSON from APIs and files.

| Command | Action |
|---------|--------|
| `curl ... \| jq .` | Pretty-print JSON |
| `jq '.key'` | Extract a key |
| `jq '.items[] \| .name'` | Extract nested values |

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

### Ruby (IRB)

Configured in `.irbrc`: 10,000 history entries, custom completion dialog colors, EBA project helpers (auto-loaded in Rails console).

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
├── .gitignore
│
├── .bash_profile                    # Login shell (brew, PATH, secrets, history)
├── .bashrc                          # Interactive shell (options, prompt, tools)
├── .bash_aliases                    # Aliases and functions
├── .bash-preexec.sh                 # Lib required by atuin
│
├── .gitconfig                       # Git (delta, GPG, 35+ aliases)
├── .gitignore_global                # Global gitignore
├── .vimrc                           # Vim (vim-plug, 6 plugins)
├── .tmux.conf                       # Tmux (tpm, powerkit)
├── .irbrc                           # Ruby IRB
│
├── .secrets.template                # Template -> ~/.secrets
├── .bash_local.template             # Template -> ~/.bash_local
├── .bash_functions.template         # Template -> ~/.bash_functions
│
├── .config/
│   ├── starship.toml                # Prompt theme
│   ├── atuin/config.toml            # History sync
│   ├── ghostty/config               # Terminal emulator
│   ├── fd/ignore                    # File finder ignores
│   ├── htop/htoprc                  # Process viewer
│   ├── gh/config.yml                # GitHub CLI
│   ├── glab-cli/aliases.yml         # GitLab CLI
│   └── git/ignore                   # Git ignore (XDG)
│
└── .ruby-lsp/                       # Ruby LSP (VS Code)
```

### Files not in repo (local to each machine)

| File | Purpose |
|------|---------|
| `~/.secrets` | Credentials and API tokens (chmod 600) |
| `~/.bash_local` | Machine/project-specific config |
| `~/.bash_functions` | Machine-specific functions (jlog, db helpers) |
| `~/.gitconfig.local` | Platform-specific git config (credential helper, GPG) |
| `~/.config/smug/*.yml` | Tmux session layouts |
| `~/.config/glab-cli/config.yml` | GitLab auth tokens |

## Machine-Specific Config

Everything project-specific goes in `~/.bash_local` (not in the repo). The template includes commented examples for:

- Project paths and environment variables
- Database config (Oracle, PostgreSQL)
- Bundler credentials
- Custom functions (e.g., Jira time logging)
- Machine-specific exports (`RESTIC_REPOSITORY`, `AWS_PROFILE`)

Credentials go in `~/.secrets` (chmod 600, sourced from `.bash_profile`).

```bash
vim ~/.bash_local       # machine/project config
vim ~/.secrets          # credentials and API tokens
```

## Cross-Platform Support

All dotfiles detect and adapt to the current platform.

| | macOS arm64 | macOS x86_64 | Linux arm64 | Linux x86_64 |
|---|---|---|---|---|
| Packages | Homebrew `/opt/homebrew` | Homebrew `/usr/local` | apt or dnf | apt or dnf |
| Git credentials | osxkeychain | osxkeychain | libsecret or cache | libsecret or cache |
| GPG | Auto-detected | Auto-detected | Auto-detected | Auto-detected |
| `ls` colors | `-G` | `-G` | `--color=auto` | `--color=auto` |
| Ports | `lsof` | `lsof` | `ss` | `ss` |
| File manager | `open .` | `open .` | `xdg-open .` | `xdg-open .` |
| FZF path | `/opt/homebrew/opt/fzf` | `/usr/local/opt/fzf` | `/usr/share/doc/fzf` | `/usr/share/doc/fzf` |

**Linux** (Ubuntu/Debian, Fedora/RHEL/AlmaLinux): `install.sh` installs base packages via apt/dnf. For tools not available in distro repos, it installs vetted release binaries when supported (delta, glab, smug, tealdeer, procs, Nerd Font) and otherwise prints a manual install hint.

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
./install.sh                       # apply machine-local git identity
gh auth login                      # GitHub CLI auth
glab auth login -h <your-host>     # GitLab CLI auth (if needed)
```
