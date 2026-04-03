#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
DRY_RUN=false
BACKED_UP=0
LINKED=0
SKIPPED=0

# Detect platform
OS="$(uname -s)"    # Darwin or Linux
ARCH="$(uname -m)"  # arm64, aarch64, x86_64

# Detect Linux package manager
PKG_MGR=""
if [[ $OS == "Linux" ]]; then
  if command -v dnf &>/dev/null; then
    PKG_MGR="dnf"
  elif command -v apt-get &>/dev/null; then
    PKG_MGR="apt"
  fi
fi

# Files to symlink (relative to repo root)
HOME_FILES=(
  .bash_profile
  .bashrc
  .bash_aliases
  .bash-preexec.sh
  .gitconfig
  .gitignore_global
  .vimrc
  .tmux.conf
  .irbrc
)

CONFIG_FILES=(
  .config/starship.toml
  .config/atuin/config.toml
  .config/mise/config.toml
  .config/ghostty/config
  .config/fd/ignore
  .config/htop/htoprc
  .config/gh/config.yml
  .config/glab-cli/aliases.yml
  .config/git/ignore
)

usage() {
  echo "Usage: install.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --dry-run    Show what would be done without making changes"
  echo "  --help       Show this help message"
}

backup() {
  local target="$1"
  if [[ -e "$target" && ! -L "$target" ]]; then
    mkdir -p "$BACKUP_DIR"
    cp -a "$target" "$BACKUP_DIR/"
    BACKED_UP=$((BACKED_UP + 1))
  fi
}

link_file() {
  local src="$1" dest="$2"

  # Skip if already correctly linked
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    SKIPPED=$((SKIPPED + 1))
    return
  fi

  if $DRY_RUN; then
    echo "  [dry-run] $dest -> $src"
    LINKED=$((LINKED + 1))
    return
  fi

  # Backup existing file (not symlink)
  backup "$dest"

  # Create parent directory if needed
  mkdir -p "$(dirname "$dest")"

  # Remove existing symlink or file, then create new symlink
  rm -f "$dest"
  ln -s "$src" "$dest"
  LINKED=$((LINKED + 1))
}

# Configure git credential helper and GPG per platform
# Writes to ~/.gitconfig.local (included by .gitconfig) to avoid
# mutating the symlinked tracked .gitconfig with machine-specific values.
configure_platform() {
  echo "Configuring platform-specific settings ($OS/$ARCH)..."
  local git_local="$HOME/.gitconfig.local"

  if $DRY_RUN; then
    echo "  [dry-run] Would configure git credential.helper for $OS"
    echo "  [dry-run] Would configure gpg.program for $OS"
    return
  fi

  # Git credential helper
  case $OS in
    Darwin)
      git config --file "$git_local" credential.helper osxkeychain
      ;;
    Linux)
      if [[ -x /usr/lib/git-core/git-credential-libsecret ]] || \
         [[ -x /usr/libexec/git-core/git-credential-libsecret ]]; then
        git config --file "$git_local" credential.helper libsecret
      else
        git config --file "$git_local" credential.helper 'cache --timeout=3600'
        echo "  Note: install libsecret for persistent credential storage"
      fi
      ;;
  esac
  echo "  credential.helper = $(git config credential.helper)"

  # Default branch name
  git config --file "$git_local" init.defaultBranch master
  echo "  init.defaultBranch = $(git config --file "$git_local" init.defaultBranch)"

  # GPG program
  local gpg_path
  gpg_path="$(command -v gpg 2>/dev/null || true)"
  if [[ -n "$gpg_path" ]]; then
    git config --file "$git_local" gpg.program "$gpg_path"
    echo "  gpg.program = $gpg_path"
  else
    echo "  GPG not found — signing disabled until installed"
  fi

  # Optional user identity from environment (avoids hardcoded identity in tracked config)
  if [[ -n "${DOTFILES_GIT_NAME:-}" ]]; then
    git config --file "$git_local" user.name "$DOTFILES_GIT_NAME"
    echo "  user.name = $DOTFILES_GIT_NAME"
  fi

  if [[ -n "${DOTFILES_GIT_EMAIL:-}" ]]; then
    git config --file "$git_local" user.email "$DOTFILES_GIT_EMAIL"
    echo "  user.email = $DOTFILES_GIT_EMAIL"
  fi

  if [[ -n "${DOTFILES_GIT_SIGNINGKEY:-}" ]]; then
    git config --file "$git_local" user.signingkey "$DOTFILES_GIT_SIGNINGKEY"
    echo "  user.signingkey = $DOTFILES_GIT_SIGNINGKEY"
  fi

  if [[ -z "$(git config user.name || true)" || -z "$(git config user.email || true)" ]]; then
    echo "  Note: set DOTFILES_GIT_NAME and DOTFILES_GIT_EMAIL before install.sh to configure git identity"
  fi
}

# ======================================================================
# Linux package installation
# ======================================================================

installed() { command -v "$1" &>/dev/null; }

# Fetch latest release version from GitHub API (strips leading 'v')
# Usage: version=$(github_latest_version "owner/repo") or with keep_v=true to keep 'v' prefix
github_latest_version() {
  local repo="$1" strip_v="${2:-true}"
  local version
  version=$(curl -sL "https://api.github.com/repos/${repo}/releases/latest" \
    | grep '"tag_name"' | head -1 | cut -d'"' -f4)
  if [[ -z "$version" ]]; then
    return 1
  fi
  if [[ "$strip_v" == "true" ]]; then
    echo "${version#v}"
  else
    echo "$version"
  fi
}

install_apt_packages() {
  echo "Installing base packages (apt)..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq \
    bash bash-completion git git-lfs gnupg vim htop tmux wget fzf \
    fd-find curl bat ripgrep jq

  # fd is installed as fdfind on Debian/Ubuntu — symlink to fd
  if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    echo "  Symlinked fdfind -> fd"
  fi

  # bat is installed as batcat on Debian/Ubuntu — symlink to bat
  if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    echo "  Symlinked batcat -> bat"
  fi

  # git-delta (available in Ubuntu 24.04+, Debian 13+)
  if ! installed delta; then
    if apt-cache show git-delta &>/dev/null 2>&1; then
      sudo apt-get install -y -qq git-delta
    else
      echo "  Installing delta from GitHub release..."
      install_delta_from_release "deb"
    fi
  fi
}

install_dnf_packages() {
  echo "Installing base packages (dnf)..."
  sudo dnf install -y -q \
    bash bash-completion git git-lfs gnupg2 vim-enhanced htop tmux wget fzf \
    fd-find curl bat ripgrep jq

  # git-delta
  if ! installed delta; then
    if dnf info git-delta &>/dev/null 2>&1; then
      sudo dnf install -y -q git-delta
    else
      echo "  Installing delta from GitHub release..."
      install_delta_from_release "rpm"
    fi
  fi
}

install_delta_from_release() {
  local pkg_type="$1"
  local version
  if ! version=$(github_latest_version "dandavison/delta" false); then
    echo "  Could not determine delta version — skipping"
    return
  fi

  local arch_suffix
  case $ARCH in
    x86_64)  arch_suffix="amd64" ;;
    aarch64|arm64) arch_suffix="arm64" ;;
    *) echo "  Unsupported arch for delta: $ARCH"; return ;;
  esac

  local url="https://github.com/dandavison/delta/releases/download/${version}"
  if [[ $pkg_type == "deb" ]]; then
    local tmp
    tmp=$(mktemp /tmp/delta-XXXX.deb)
    curl -sL "${url}/git-delta_${version}_${arch_suffix}.deb" -o "$tmp"
    sudo dpkg -i "$tmp"
    rm -f "$tmp"
  elif [[ $pkg_type == "rpm" ]]; then
    local tmp
    tmp=$(mktemp /tmp/delta-XXXX.rpm)
    curl -sL "${url}/git-delta-${version}-1.${ARCH}.rpm" -o "$tmp"
    sudo rpm -i "$tmp"
    rm -f "$tmp"
  fi
}

install_gh() {
  if installed gh; then return; fi
  echo "  Installing gh (GitHub CLI)..."

  if [[ $PKG_MGR == "apt" ]]; then
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq gh
  elif [[ $PKG_MGR == "dnf" ]]; then
    sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo 2>/dev/null \
      || sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo 2>/dev/null
    sudo dnf install -y -q gh
  fi
}

install_glab() {
  if installed glab; then return; fi
  echo "  Installing glab (GitLab CLI)..."

  if [[ $PKG_MGR == "dnf" ]]; then
    sudo dnf install -y -q glab 2>/dev/null && return
  fi

  # Fallback: install from GitLab release binary
  local version
  version=$(curl -sL "https://gitlab.com/api/v4/projects/34675721/releases" \
    | grep -o '"tag_name":"v[^"]*"' | head -1 | cut -d'"' -f4 | tr -d 'v')
  if [[ -z "$version" ]]; then
    echo "  Could not determine glab version — skipping"
    return
  fi

  local arch_suffix
  case $ARCH in
    x86_64)        arch_suffix="amd64" ;;
    aarch64|arm64) arch_suffix="arm64" ;;
    *) echo "  Unsupported arch for glab: $ARCH"; return ;;
  esac

  local tmp
  tmp=$(mktemp -d /tmp/glab-XXXX)
  curl -sL "https://gitlab.com/gitlab-org/cli/-/releases/v${version}/downloads/glab_${version}_linux_${arch_suffix}.tar.gz" \
    -o "$tmp/glab.tar.gz"
  tar -xzf "$tmp/glab.tar.gz" -C "$tmp"
  sudo install -m 755 "$tmp/bin/glab" /usr/local/bin/glab
  rm -rf "$tmp"
}

install_mise() {
  if installed mise; then return; fi
  echo "  Installing mise..."
  curl -fsSL https://mise.jdx.dev/install.sh | bash
}

install_smug() {
  if installed smug; then return; fi
  echo "  Installing smug..."

  local version
  if ! version=$(github_latest_version "ivaaaan/smug"); then
    echo "  Could not determine smug version — skipping"
    return
  fi

  local arch_suffix
  case $ARCH in
    x86_64)        arch_suffix="x86_64" ;;
    aarch64|arm64) arch_suffix="arm64" ;;
    *) echo "  Unsupported arch for smug: $ARCH"; return ;;
  esac

  local tmp
  tmp=$(mktemp -d /tmp/smug-XXXX)
  curl -sL "https://github.com/ivaaaan/smug/releases/download/v${version}/smug_${version}_Linux_${arch_suffix}.tar.gz" \
    -o "$tmp/smug.tar.gz"
  tar -xzf "$tmp/smug.tar.gz" -C "$tmp"
  sudo install -m 755 "$tmp/smug" /usr/local/bin/smug
  rm -rf "$tmp"
}

install_nerd_font() {
  local font_dir="$HOME/.local/share/fonts"
  if [[ -d "$font_dir" ]] && ls "$font_dir"/IosevkaTerm*.ttf &>/dev/null; then
    return
  fi
  echo "  Installing IosevkaTerm Nerd Font..."

  local version
  if ! version=$(github_latest_version "ryanoasis/nerd-fonts" false); then
    echo "  Could not determine Nerd Fonts version — skipping"
    return
  fi

  local tmp
  tmp=$(mktemp -d /tmp/nerd-font-XXXX)
  curl -sL "https://github.com/ryanoasis/nerd-fonts/releases/download/${version}/IosevkaTerm.tar.xz" \
    -o "$tmp/IosevkaTerm.tar.xz"
  mkdir -p "$font_dir"
  tar -xJf "$tmp/IosevkaTerm.tar.xz" -C "$font_dir"
  rm -rf "$tmp"

  if command -v fc-cache &>/dev/null; then
    fc-cache -f "$font_dir"
  fi
}

install_eza() {
  if installed eza; then return; fi

  # eza requires a newer glibc than RHEL 9 / AlmaLinux 9 / Rocky 9 ship
  if [[ -f /etc/os-release ]]; then
    local distro_id
    distro_id=$(. /etc/os-release && echo "${ID:-}")
    local distro_like
    distro_like=$(. /etc/os-release && echo "${ID_LIKE:-}")
    if [[ "$distro_id" =~ ^(rhel|almalinux|rocky|centos)$ ]] || \
       [[ "$distro_like" =~ rhel ]]; then
      echo "  Skipping eza — glibc too old on RHEL/AlmaLinux/Rocky"
      return
    fi
  fi

  echo "  Installing eza..."

  if [[ $PKG_MGR == "apt" ]]; then
    # eza has an official apt repo
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
      | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg 2>/dev/null
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
      | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq eza
  elif [[ $PKG_MGR == "dnf" ]]; then
    sudo dnf install -y -q eza 2>/dev/null && return
    echo "  eza not in dnf repos — install manually or via cargo"
  fi
}

install_tealdeer() {
  if installed tldr; then return; fi
  echo "  Installing tealdeer (tldr)..."

  if [[ $PKG_MGR == "apt" ]]; then
    # tealdeer available in Ubuntu 22.04+
    if apt-cache show tealdeer &>/dev/null 2>&1; then
      sudo apt-get install -y -qq tealdeer
    else
      install_tealdeer_from_release
    fi
  elif [[ $PKG_MGR == "dnf" ]]; then
    if dnf info tealdeer &>/dev/null 2>&1; then
      sudo dnf install -y -q tealdeer
    else
      install_tealdeer_from_release
    fi
  fi
}

install_tealdeer_from_release() {
  local arch_suffix
  case $ARCH in
    x86_64)        arch_suffix="x86_64" ;;
    aarch64|arm64) arch_suffix="aarch64" ;;
    *) echo "  Unsupported arch for tealdeer: $ARCH"; return ;;
  esac

  local url="https://github.com/tealdeer-rs/tealdeer/releases/latest/download/tealdeer-linux-${arch_suffix}-musl"
  mkdir -p "$HOME/.local/bin"
  curl -sL "$url" -o "$HOME/.local/bin/tldr"
  chmod +x "$HOME/.local/bin/tldr"
}

install_procs() {
  if installed procs; then return; fi
  echo "  Installing procs..."

  local version
  if ! version=$(github_latest_version "dalance/procs"); then
    echo "  Could not determine procs version — skipping"
    return
  fi

  local arch_suffix
  case $ARCH in
    x86_64)        arch_suffix="x86_64" ;;
    aarch64|arm64) arch_suffix="aarch64" ;;
    *) echo "  Unsupported arch for procs: $ARCH"; return ;;
  esac

  local tmp
  tmp=$(mktemp -d /tmp/procs-XXXX)
  curl -sL "https://github.com/dalance/procs/releases/download/v${version}/procs-v${version}-${arch_suffix}-linux.zip" \
    -o "$tmp/procs.zip"
  unzip -qo "$tmp/procs.zip" -d "$tmp"
  sudo install -m 755 "$tmp/procs" /usr/local/bin/procs
  rm -rf "$tmp"
}


install_linux_packages() {
  echo ""
  echo "Installing packages for Linux ($PKG_MGR)..."
  echo ""

  if [[ -z "$PKG_MGR" ]]; then
    echo "  No supported package manager found (need apt or dnf)"
    echo "  Skipping package installation"
    return
  fi

  # Base packages from distro repos
  if [[ $PKG_MGR == "apt" ]]; then
    install_apt_packages
  elif [[ $PKG_MGR == "dnf" ]]; then
    install_dnf_packages
  fi

  # Tools that need special installation
  echo ""
  echo "Installing CLI tools..."
  install_mise
  install_gh
  install_glab
  install_smug
  install_eza
  install_tealdeer
  install_procs
  install_nerd_font

  echo ""
  echo "Package installation complete."
}

# ======================================================================
# Main
# ======================================================================

# Parse arguments
for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    --help)    usage; exit 0 ;;
    *)         echo "Unknown option: $arg"; usage; exit 1 ;;
  esac
done

echo "Dotfiles installer"
echo "  Source:   $DOTFILES"
echo "  Target:   $HOME"
echo "  Platform: $OS/$ARCH"
$DRY_RUN && echo "  Mode:     DRY RUN"
echo ""

# Install packages (macOS: brew bundle, Linux: apt/dnf + special installs)
if ! $DRY_RUN; then
  if [[ $OS == "Darwin" ]]; then
    if command -v brew &>/dev/null; then
      echo "Installing brew packages..."
      brew bundle --file="$DOTFILES/Brewfile"
      echo ""
    fi
  elif [[ $OS == "Linux" ]]; then
    install_linux_packages
  fi
fi

# Symlink home directory files
echo "Linking home files..."
for file in "${HOME_FILES[@]}"; do
  link_file "$DOTFILES/$file" "$HOME/$file"
done

# Symlink .config files
echo "Linking config files..."
for file in "${CONFIG_FILES[@]}"; do
  link_file "$DOTFILES/$file" "$HOME/$file"
done

# Install mise-managed tools (config.toml is now symlinked)
if ! $DRY_RUN && installed mise; then
  echo ""
  echo "Installing mise-managed tools..."
  mise install --yes
fi

# Platform-specific git configuration
echo ""
configure_platform

# Generate bash completions for installed tools
echo ""
if $DRY_RUN; then
  echo "Generating bash completions..."
  echo "  [dry-run] Would write completion files under ~/.local/etc/bash_completion.d"
else
  echo "Generating bash completions..."
  mkdir -p "$HOME/.local/etc/bash_completion.d"

  if installed glab; then
    _comp=$(glab completion -s bash 2>/dev/null) \
      && [[ "$_comp" == *complete* ]] \
      && printf '%s\n' "$_comp" > "$HOME/.local/etc/bash_completion.d/glab.bash" \
      && echo "  glab" || true
  fi

  if installed smug; then
    _comp=$(smug completion bash 2>/dev/null) \
      && [[ "$_comp" == *complete* ]] \
      && printf '%s\n' "$_comp" > "$HOME/.local/etc/bash_completion.d/smug.bash" \
      && echo "  smug" || true
  fi

  if installed gh; then
    _comp=$(gh completion -s bash 2>/dev/null) \
      && [[ "$_comp" == *complete* ]] \
      && printf '%s\n' "$_comp" > "$HOME/.local/etc/bash_completion.d/gh.bash" \
      && echo "  gh" || true
  fi
fi

# Copy templates for files that are NOT symlinked (machine-specific)
echo ""
echo "Setting up local config templates..."

copy_template() {
  local template="$1" dest="$2" mode="${3:-}"
  if [[ -f "$dest" ]]; then
    echo "  ~/${dest#$HOME/} already exists, skipping"
    return
  fi
  if $DRY_RUN; then
    echo "  [dry-run] Copy $(basename "$template") -> ~/${dest#$HOME/}"
    return
  fi
  cp "$template" "$dest"
  [[ -n "$mode" ]] && chmod "$mode" "$dest"
  echo "  Created ~/${dest#$HOME/} from template"
}

copy_template "$DOTFILES/.secrets.template" "$HOME/.secrets" 600
copy_template "$DOTFILES/.bash_local.template" "$HOME/.bash_local"
copy_template "$DOTFILES/.bash_functions.template" "$HOME/.bash_functions"

# Summary
echo ""
echo "Done!"
echo "  Linked:    $LINKED"
echo "  Skipped:   $SKIPPED (already correct)"
[[ $BACKED_UP -gt 0 ]] && echo "  Backed up: $BACKED_UP files -> $BACKUP_DIR"
echo ""

# Post-install reminders
echo "Next steps:"
echo "  vim ~/.bash_local                  # configure for this machine"
echo "  vim ~/.secrets                     # add your credentials"
echo "  export DOTFILES_GIT_NAME='Your Name' DOTFILES_GIT_EMAIL='you@example.com'"
echo "  ./install.sh                       # apply machine-local git identity"
echo "  gh auth login                      # authenticate GitHub CLI"
