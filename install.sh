#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
DRY_RUN=false
ASSUME_YES=false
INSTALL_PACKAGES=true
BACKED_UP=0
LINKED=0
SKIPPED=0
FAILED=()

# Non-interactive when asked (--yes) or when there is no terminal (ssh host
# cmd, Ansible, CI). Nothing below prompts; sudo then runs with -n so a
# password prompt fails fast instead of hanging.
[[ -t 0 && -t 1 ]] || ASSUME_YES=true

# Pinned Linux release artifacts. Keep these explicit so installer behavior is
# reproducible and reviewable; do not resolve "latest" at install time.
MISE_VERSION="2026.10.25"
SMUG_VERSION="0.3.17"
NERD_FONT_VERSION="v3.5.1"
# GitHub's published digest for IosevkaTerm.tar.xz at NERD_FONT_VERSION.
NERD_FONT_SHA256="054a4a369cdcc5d57e9bc91ea56dfefd66c71c253dcb0c0d7b72c0810373da26"
TEALDEER_VERSION="1.8.1"
PROCS_VERSION="0.14.11"
SOPS_VERSION="3.13.3"

# Tools installed under ~/.local/bin and mise's shims count as installed even
# when the caller's PATH (ssh host cmd, Ansible) does not list them yet.
for dir in "${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims" "$HOME/.local/bin"; do
  [[ -d "$dir" && ":$PATH:" != *":$dir:"* ]] && PATH="$dir:$PATH"
done
export PATH

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

# Command-line clients from .config/mise/conf.d/dotfiles-clis.toml, installed
# user-level through mise on every machine whose mise config is not
# host-managed (also with --no-packages).
# node and aube (global config) go first: mise requires the npm backend's
# configured dependencies to be installed before confluence-cli.
CLI_TOOLS=(node aube aws-cli github:ankitpokhrel/jira-cli glab gh npm:confluence-cli)

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
  .config/mise/conf.d/dotfiles-clis.toml
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
  echo "  --dry-run       Show what would be done without making changes"
  echo "  --yes, -y       Non-interactive: never prompt (implied without a TTY)"
  echo "  --no-packages   No sudo and no system packages: skip brew, apt/dnf,"
  echo "                  release downloads, fonts, the full mise install and"
  echo "                  npm installs. Still links dotfiles, writes local config"
  echo "                  and installs the command-line clients (gh, glab, jira,"
  echo "                  confluence, aws) user-level through mise, unless the"
  echo "                  host manages the global mise config"
  echo "  --help          Show this help message"
}

# sudo that never prompts in non-interactive runs.
run_sudo() {
  if $ASSUME_YES; then sudo -n "$@"; else sudo "$@"; fi
}

# Run an optional install step; record a failure instead of aborting, so the
# rest of the install still happens and the exit status reports it.
# The step runs in a subshell with errexit on (a function called from an
# `if` would run with errexit off and carry on past a failed checksum).
optional() {
  local name="$1" rc; shift
  set +e
  (set -e; "$@")
  rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    echo "  FAILED: $name (exit $rc)" >&2
    FAILED+=("$name")
  fi
}

backup() {
  local target="$1" rel
  if [[ -e "$target" && ! -L "$target" ]]; then
    rel="${target#"$HOME"/}"
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp -a "$target" "$BACKUP_DIR/$rel"
    BACKED_UP=$((BACKED_UP + 1))
  fi
}

# A global mise config that is a regular file with a mise.lock beside it is
# owned by the host's provisioning (dotfiles never writes a lock there).
# Leave it alone: no link, no `mise install` from dotfiles' tool list.
mise_config_managed() {
  local cfg="$HOME/.config/mise/config.toml"
  [[ -f "$cfg" && ! -L "$cfg" && -f "$HOME/.config/mise/mise.lock" ]]
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

# Set a key in ~/.gitconfig.local only when its values differ (reruns leave
# the file untouched). Several values set a multi-valued key in that order;
# no value removes the key.
git_local_set() {
  local file="$1" key="$2"; shift 2
  local want have value
  want="$(printf '%s\n' "$@")"
  have="$(git config --file "$file" --get-all "$key" 2>/dev/null || true)"
  [[ $# -eq 0 ]] && want=""
  [[ "$have" == "$want" ]] && return 0
  git config --file "$file" --unset-all "$key" >/dev/null 2>&1 || true
  for value in "$@"; do
    git config --file "$file" --add "$key" "$value"
  done
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

  # Git credential helper. An existing ~/.git-credentials (written by the
  # host's provisioning or by the user) stays in use: `store` goes first.
  # The leading empty value drops helpers inherited from system config.
  local helpers=("")
  if [[ $OS == "Linux" && -f "$HOME/.git-credentials" ]]; then
    helpers+=(store)
  fi

  local gcm_path
  gcm_path="$(command -v git-credential-manager 2>/dev/null || true)"
  if [[ -z "$gcm_path" && -x /usr/local/share/gcm-core/git-credential-manager ]]; then
    gcm_path="/usr/local/share/gcm-core/git-credential-manager"
  fi

  if [[ -n "$gcm_path" ]]; then
    helpers+=("$gcm_path")
  else
    case $OS in
      Darwin)
        helpers+=(osxkeychain)
        ;;
      Linux)
        if [[ -x /usr/lib/git-core/git-credential-libsecret ]] || \
           [[ -x /usr/libexec/git-core/git-credential-libsecret ]]; then
          helpers+=(libsecret)
        elif [[ ! -f "$HOME/.git-credentials" ]]; then
          helpers+=('cache --timeout=3600')
          echo "  Note: install libsecret for persistent credential storage"
        fi
        ;;
    esac
  fi
  git_local_set "$git_local" credential.helper "${helpers[@]}"
  echo "  credential.helper = $(printf '%s\n' "${helpers[@]}" | grep . | paste -sd ',' -)"

  if [[ -n "${DOTFILES_GITHUB_USERNAME:-}" ]]; then
    git_local_set "$git_local" credential.https://github.com.username "$DOTFILES_GITHUB_USERNAME"
    echo "  credential.https://github.com.username = $DOTFILES_GITHUB_USERNAME"
  fi

  # Default branch name
  git_local_set "$git_local" init.defaultBranch master
  echo "  init.defaultBranch = $(git config --file "$git_local" init.defaultBranch)"

  # GPG program and signing: sign commits and tags only when a secret key
  # exists, so a plain `git commit` works on a host without one.
  local gpg_path signing=false
  gpg_path="$(command -v gpg 2>/dev/null || true)"
  if [[ -n "$gpg_path" ]]; then
    git_local_set "$git_local" gpg.program "$gpg_path"
    echo "  gpg.program = $gpg_path"
    if [[ -n "${DOTFILES_GIT_SIGNINGKEY:-}" ]] || \
       [[ -n "$("$gpg_path" --batch --list-secret-keys 2>/dev/null)" ]]; then
      signing=true
    fi
  else
    git_local_set "$git_local" gpg.program
  fi
  git_local_set "$git_local" commit.gpgsign "$signing"
  git_local_set "$git_local" tag.gpgsign "$signing"
  if $signing; then
    echo "  commit.gpgsign = true (GPG secret key found)"
  else
    echo "  commit.gpgsign = false (no GPG secret key; rerun install.sh after adding one)"
  fi

  # Pager: Hunk when installed, else delta, else Git's default.
  if installed hunk; then
    git_local_set "$git_local" core.pager "hunk pager"
  elif installed delta; then
    git_local_set "$git_local" core.pager delta
  else
    git_local_set "$git_local" core.pager
  fi
  echo "  core.pager = $(git config --file "$git_local" core.pager || echo "(git default)")"

  # Optional user identity from environment (avoids hardcoded identity in tracked config)
  if [[ -n "${DOTFILES_GIT_NAME:-}" ]]; then
    git_local_set "$git_local" user.name "$DOTFILES_GIT_NAME"
    echo "  user.name = $DOTFILES_GIT_NAME"
  fi

  if [[ -n "${DOTFILES_GIT_EMAIL:-}" ]]; then
    git_local_set "$git_local" user.email "$DOTFILES_GIT_EMAIL"
    echo "  user.email = $DOTFILES_GIT_EMAIL"
  fi

  if [[ -n "${DOTFILES_GIT_SIGNINGKEY:-}" ]]; then
    git_local_set "$git_local" user.signingkey "$DOTFILES_GIT_SIGNINGKEY"
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

sha256_file() {
  local file="$1"
  if command -v sha256sum &>/dev/null; then
    sha256sum "$file" | awk '{print $1}'
  else
    shasum -a 256 "$file" | awk '{print $1}'
  fi
}

verify_sha256() {
  local file="$1" expected="$2" actual
  actual="$(sha256_file "$file")"
  if [[ "$actual" != "$expected" ]]; then
    echo "  Checksum mismatch for $(basename "$file")" >&2
    echo "    expected: $expected" >&2
    echo "    actual:   $actual" >&2
    return 1
  fi
}

download_verified() {
  local url="$1" dest="$2" checksum_url="$3" checksum_name="$4"
  local checksum_file expected

  curl -fsSL "$url" -o "$dest"
  checksum_file="$(mktemp /tmp/dotfiles-checksums-XXXX)"
  curl -fsSL "$checksum_url" -o "$checksum_file"
  expected="$(awk -v name="$checksum_name" '$2 == name || $2 == "./" name { print $1; exit }' "$checksum_file")"
  rm -f "$checksum_file"

  if [[ -z "$expected" ]]; then
    echo "  No checksum entry found for $checksum_name" >&2
    return 1
  fi

  verify_sha256 "$dest" "$expected"
}

# Base packages: "package[|alternative...]:command". A package is skipped when
# its command is already on PATH (for example a mise-managed tmux or yq from
# the host's provisioning, which must keep its version), when it is already
# installed, or when no enabled repository offers it (EL10 drops some names;
# EPEL may be absent). The first available alternative wins.
APT_PACKAGES=(
  bash:bash bash-completion:- git:git git-lfs:git-lfs gnupg:gpg vim:vim htop:htop
  tmux:tmux wget:wget fzf:fzf fd-find:fd curl:curl bat:bat ripgrep:rg jq:jq yq:yq
  default-mysql-client:mysql postgresql-client:psql git-delta:delta
)
DNF_PACKAGES=(
  bash:bash bash-completion:- git:git git-lfs:git-lfs gnupg2:gpg vim-enhanced:vim
  htop:htop tmux:tmux wget:wget fzf:fzf fd-find:fd curl:curl bat:bat ripgrep:rg
  jq:jq yq:yq "mysql|mysql8.4:mysql" postgresql:psql git-delta:delta
)

pkg_installed() {
  case $PKG_MGR in
    apt) dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed" ;;
    dnf) rpm -q --whatprovides "$1" &>/dev/null ;;
  esac
}

pkg_available() {
  case $PKG_MGR in
    apt) [[ -n "$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ && $2 != "(none)" { print $2 }')" ]] ;;
    dnf) [[ -n "$(dnf -q repoquery --available --latest-limit 1 "$1" 2>/dev/null)" ]] ;;
  esac
}

# Prints the packages to install, one per line; skip notes go to stderr.
missing_packages() {
  local entry names cmd name chosen
  for entry in "$@"; do
    names="${entry%%:*}" cmd="${entry##*:}" chosen=""
    if [[ "$cmd" != "-" ]] && installed "$cmd"; then continue; fi
    for name in ${names//|/ }; do
      if pkg_installed "$name"; then chosen="-"; break; fi
    done
    [[ "$chosen" == "-" ]] && continue
    for name in ${names//|/ }; do
      if pkg_available "$name"; then chosen="$name"; break; fi
    done
    if [[ -n "$chosen" ]]; then
      echo "$chosen"
    else
      echo "  Skipping ${names//|/ or } — not in any enabled repository" >&2
    fi
  done
}

install_base_packages() {
  echo "Installing base packages ($PKG_MGR)..."
  local packages=()
  [[ $PKG_MGR == "apt" ]] && run_sudo apt-get update -qq
  if [[ $PKG_MGR == "apt" ]]; then
    mapfile -t packages < <(missing_packages "${APT_PACKAGES[@]}")
  else
    mapfile -t packages < <(missing_packages "${DNF_PACKAGES[@]}")
  fi

  if [[ ${#packages[@]} -eq 0 ]]; then
    echo "  All base packages present"
  elif [[ $PKG_MGR == "apt" ]]; then
    echo "  Installing: ${packages[*]}"
    run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${packages[@]}"
  else
    echo "  Installing: ${packages[*]}"
    run_sudo dnf install -y -q "${packages[@]}"
  fi

  # fd and bat use other names on Debian/Ubuntu
  if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    echo "  Symlinked fdfind -> fd"
  fi
  if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    echo "  Symlinked batcat -> bat"
  fi
}

install_mise() {
  if installed mise; then return; fi
  echo "  Installing mise..."

  local arch_suffix
  case $ARCH in
    x86_64)        arch_suffix="x64" ;;
    aarch64|arm64) arch_suffix="arm64" ;;
    *) echo "  Unsupported arch for mise: $ARCH"; return 0 ;;
  esac

  local artifact="mise-v${MISE_VERSION}-linux-${arch_suffix}"
  local tmp
  tmp=$(mktemp -d /tmp/mise-XXXX)
  download_verified \
    "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/${artifact}" \
    "$tmp/mise" \
    "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/SHASUMS256.txt" \
    "$artifact"
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$tmp/mise" "$HOME/.local/bin/mise"
  rm -rf "$tmp"
}

install_smug() {
  if installed smug; then return; fi
  echo "  Installing smug..."

  local arch_suffix
  case $ARCH in
    x86_64)        arch_suffix="x86_64" ;;
    aarch64|arm64) arch_suffix="arm64" ;;
    *) echo "  Unsupported arch for smug: $ARCH"; return 0 ;;
  esac

  local tmp
  tmp=$(mktemp -d /tmp/smug-XXXX)
  local artifact="smug_${SMUG_VERSION}_Linux_${arch_suffix}.tar.gz"
  download_verified \
    "https://github.com/ivaaaan/smug/releases/download/v${SMUG_VERSION}/${artifact}" \
    "$tmp/smug.tar.gz" \
    "https://github.com/ivaaaan/smug/releases/download/v${SMUG_VERSION}/checksums.txt" \
    "$artifact"
  tar -xzf "$tmp/smug.tar.gz" -C "$tmp"
  run_sudo install -m 755 "$tmp/smug" /usr/local/bin/smug
  rm -rf "$tmp"
}

install_nerd_font() {
  local font_dir="$HOME/.local/share/fonts"
  if [[ -d "$font_dir" ]] && ls "$font_dir"/IosevkaTerm*.ttf &>/dev/null; then
    return
  fi
  echo "  Installing IosevkaTerm Nerd Font..."

  local tmp
  tmp=$(mktemp -d /tmp/nerd-font-XXXX)
  # Pinned archive, checked against GitHub's published asset digest.
  curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/IosevkaTerm.tar.xz" \
    -o "$tmp/IosevkaTerm.tar.xz"
  verify_sha256 "$tmp/IosevkaTerm.tar.xz" "$NERD_FONT_SHA256" || { rm -rf "$tmp"; return 1; }
  mkdir -p "$font_dir"
  tar -xJf "$tmp/IosevkaTerm.tar.xz" -C "$font_dir"
  rm -rf "$tmp"

  if command -v fc-cache &>/dev/null; then
    fc-cache -f "$font_dir"
  fi
}

install_eza() {
  if installed eza; then return; fi

  if [[ $PKG_MGR == "apt" ]]; then
    echo "  Installing eza..."
    # eza has an official apt repo
    run_sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
      | run_sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
      | run_sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
    run_sudo apt-get update -qq
    run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq eza
  elif [[ $PKG_MGR == "dnf" ]]; then
    # Fedora and some EPEL releases carry eza; EL10/EPEL 10 does not.
    if pkg_available eza; then
      echo "  Installing eza..."
      run_sudo dnf install -y -q eza
    else
      echo "  Skipping eza — not in any enabled repository (ls stays the default)"
    fi
  fi
}

install_tealdeer() {
  if installed tldr; then return; fi
  echo "  Installing tealdeer (tldr)..."

  if [[ $PKG_MGR == "apt" ]]; then
    # tealdeer available in Ubuntu 22.04+
    if pkg_available tealdeer; then
      run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq tealdeer
    else
      install_tealdeer_from_release
    fi
  elif [[ $PKG_MGR == "dnf" ]]; then
    if pkg_available tealdeer; then
      run_sudo dnf install -y -q tealdeer
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
    *) echo "  Unsupported arch for tealdeer: $ARCH"; return 0 ;;
  esac

  local artifact="tealdeer-linux-${arch_suffix}-musl"
  mkdir -p "$HOME/.local/bin"
  download_verified \
    "https://github.com/tealdeer-rs/tealdeer/releases/download/v${TEALDEER_VERSION}/${artifact}" \
    "$HOME/.local/bin/tldr" \
    "https://github.com/tealdeer-rs/tealdeer/releases/download/v${TEALDEER_VERSION}/${artifact}.sha256" \
    "$artifact"
  chmod +x "$HOME/.local/bin/tldr"
}

install_procs() {
  if installed procs; then return; fi
  echo "  Installing procs..."

  local arch_suffix
  case $ARCH in
    x86_64)        arch_suffix="x86_64" ;;
    aarch64|arm64) arch_suffix="aarch64" ;;
    *) echo "  Unsupported arch for procs: $ARCH"; return 0 ;;
  esac

  local tmp
  tmp=$(mktemp -d /tmp/procs-XXXX)
  # procs does not publish release checksums. Keep the version pinned and
  # install over HTTPS; this exception is documented in SECURITY.md.
  curl -fsSL "https://github.com/dalance/procs/releases/download/v${PROCS_VERSION}/procs-v${PROCS_VERSION}-${arch_suffix}-linux.zip" \
    -o "$tmp/procs.zip"
  unzip -qo "$tmp/procs.zip" -d "$tmp"
  run_sudo install -m 755 "$tmp/procs" /usr/local/bin/procs
  rm -rf "$tmp"
}

install_sops() {
  if installed sops; then return; fi
  echo "  Installing sops..."

  local arch_suffix
  case $ARCH in
    x86_64)        arch_suffix="amd64" ;;
    aarch64|arm64) arch_suffix="arm64" ;;
    *) echo "  Unsupported arch for sops: $ARCH"; return 0 ;;
  esac

  local artifact="sops-v${SOPS_VERSION}.linux.${arch_suffix}"
  local tmp
  tmp=$(mktemp -d /tmp/sops-XXXX)
  download_verified \
    "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/${artifact}" \
    "$tmp/sops" \
    "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.checksums.txt" \
    "$artifact"
  run_sudo install -m 755 "$tmp/sops" /usr/local/bin/sops
  rm -rf "$tmp"
}

install_hunk() {
  if installed hunk; then return; fi
  if ! command -v mise &>/dev/null; then
    echo "  Skipping hunk — mise unavailable"
    return
  fi

  echo "  Installing hunk..."
  mise exec -- npm install -g hunkdiff
  mise reshim node >/dev/null 2>&1 || true
}

install_ai_cli_tools() {
  if ! command -v mise &>/dev/null; then
    echo "  Skipping AI CLI tools — mise unavailable"
    return
  fi

  local packages=()
  installed claude || packages+=("@anthropic-ai/claude-code")
  installed codex || packages+=("@openai/codex")

  if [[ ${#packages[@]} -eq 0 ]]; then
    return
  fi

  echo "  Installing AI CLI tools..."
  mise exec -- npm install -g "${packages[@]}"
  mise reshim node >/dev/null 2>&1 || true
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

  # Base packages from distro repos (a failure here is fatal)
  install_base_packages

  # Tools that need special installation. Each skips a tool already on PATH,
  # so tools the host provisions (for example through mise) keep their version.
  echo ""
  echo "Installing CLI tools..."
  optional mise install_mise
  optional smug install_smug
  optional eza install_eza
  optional tealdeer install_tealdeer
  optional procs install_procs
  optional sops install_sops
  optional nerd-font install_nerd_font

  echo ""
  echo "Package installation complete."
}

# ======================================================================
# Main
# ======================================================================

# Parse arguments
for arg in "$@"; do
  case $arg in
    --dry-run)     DRY_RUN=true ;;
    --yes|-y)      ASSUME_YES=true ;;
    --no-packages) INSTALL_PACKAGES=false ;;
    --help|-h)     usage; exit 0 ;;
    *)             echo "Unknown option: $arg" >&2; usage >&2; exit 1 ;;
  esac
done

if $ASSUME_YES; then
  export MISE_YES=1 HOMEBREW_NO_ENV_HINTS=1 NONINTERACTIVE=1
fi

MISE_MANAGED=false
mise_config_managed && MISE_MANAGED=true

echo "Dotfiles installer"
echo "  Source:   $DOTFILES"
echo "  Target:   $HOME"
echo "  Platform: $OS/$ARCH"
$DRY_RUN && echo "  Mode:     DRY RUN"
$ASSUME_YES && echo "  Prompts:  none (non-interactive)"
$INSTALL_PACKAGES || echo "  Packages: skipped (--no-packages)"
$MISE_MANAGED && echo "  mise:     global config is host-managed (config.toml + mise.lock); left as is"
echo ""

# Install packages (macOS: brew bundle, Linux: apt/dnf + special installs)
if $DRY_RUN; then
  if $INSTALL_PACKAGES; then
    echo "  [dry-run] Would install packages ($([[ $OS == Darwin ]] && echo "brew bundle" || echo "${PKG_MGR:-none}"))"
    echo ""
  fi
elif $INSTALL_PACKAGES; then
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
  if [[ $file == .config/mise/* ]] && $MISE_MANAGED; then
    echo "  Skipping ~/$file — host-managed (mise.lock beside it)"
    continue
  fi
  link_file "$DOTFILES/$file" "$HOME/$file"
done

# Install mise-managed tools (config.toml is now symlinked)
if ! $DRY_RUN && $INSTALL_PACKAGES && ! $MISE_MANAGED && installed mise; then
  echo ""
  echo "Installing mise-managed tools..."
  optional "mise install" mise install --yes
  if [[ $OS == "Linux" ]]; then
    optional hunk install_hunk
    optional "AI CLI tools" install_ai_cli_tools
  fi
fi

# Command-line clients (user-level, no sudo; also with --no-packages). A
# host-managed mise config provides them itself and is left alone.
echo ""
echo "Installing command-line clients (mise, user-level)..."
if $MISE_MANAGED; then
  echo "  Skipping — the host-managed mise config provides them"
elif $DRY_RUN; then
  echo "  [dry-run] Would run: mise install ${CLI_TOOLS[*]}"
else
  installed mise || optional mise install_mise
  if installed mise; then
    # From HOME, so only the global config (and its conf.d) decides versions.
    # shellcheck disable=SC2016  # expanded by the inner bash
    optional "command-line clients" bash -c 'cd "$HOME" && mise install --yes "$@"' _ "${CLI_TOOLS[@]}"
  else
    echo "  FAILED: command-line clients (mise unavailable)" >&2
    FAILED+=("command-line clients")
  fi
fi

# Platform-specific git configuration
echo ""
configure_platform

# Write a file only when its content changes (keeps reruns no-ops).
write_if_changed() {
  local dest="$1" content="$2"
  if [[ -f "$dest" && "$(cat "$dest")" == "$content" ]]; then return 0; fi
  printf '%s\n' "$content" > "$dest"
}

# Generate bash completions for installed tools. Tools whose completion the
# host's shell environment already loads are skipped again in .bashrc.
echo ""
echo "Generating bash completions..."
if $DRY_RUN; then
  echo "  [dry-run] Would write completion files under ~/.local/etc/bash_completion.d"
else
  mkdir -p "$HOME/.local/etc/bash_completion.d"
  # glab and gh write their config on any run; point them at a scratch dir.
  _comp_cfg="$(mktemp -d)"
  for tool in glab smug gh; do
    installed "$tool" || continue
    case $tool in
      smug) _comp=$(smug completion bash 2>/dev/null || true) ;;
      *)    _comp=$(GLAB_CONFIG_DIR="$_comp_cfg" GH_CONFIG_DIR="$_comp_cfg" "$tool" completion -s bash 2>/dev/null || true) ;;
    esac
    if [[ "$_comp" == *complete* ]]; then
      write_if_changed "$HOME/.local/etc/bash_completion.d/$tool.bash" "$_comp"
      echo "  $tool"
    fi
  done
  rm -rf "$_comp_cfg"
fi

# Copy templates for files that are NOT symlinked (machine-specific)
echo ""
echo "Setting up local config templates..."

copy_template() {
  local template="$1" dest="$2" mode="${3:-}"
  if [[ -f "$dest" ]]; then
    echo "  ~/${dest#"$HOME"/} already exists, skipping"
    return
  fi
  if $DRY_RUN; then
    echo "  [dry-run] Copy $(basename "$template") -> ~/${dest#"$HOME"/}"
    return
  fi
  cp "$template" "$dest"
  [[ -n "$mode" ]] && chmod "$mode" "$dest"
  echo "  Created ~/${dest#"$HOME"/} from template"
}

copy_template "$DOTFILES/.secrets.template" "$HOME/.secrets" 600
copy_template "$DOTFILES/.bash_local.template" "$HOME/.bash_local"
copy_template "$DOTFILES/.bash_functions.template" "$HOME/.bash_functions"
copy_template "$DOTFILES/.irbrc.local.template" "$HOME/.irbrc.local"

# Summary
echo ""
echo "Done!"
echo "  Linked:    $LINKED"
echo "  Skipped:   $SKIPPED (already correct)"
if [[ $BACKED_UP -gt 0 ]]; then
  echo "  Backed up: $BACKED_UP files -> $BACKUP_DIR"
fi
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "  Failed:    ${FAILED[*]}" >&2
fi
echo ""

if ! $ASSUME_YES; then
  echo "Next steps:"
  echo "  vim ~/.bash_local                  # configure for this machine"
  echo "  vim ~/.secrets                     # add your credentials"
  echo "  export DOTFILES_GIT_NAME='Your Name' DOTFILES_GIT_EMAIL='you@example.com'"
  echo "  ./install.sh                       # apply machine-local git identity"
  echo "  gh auth login                      # authenticate GitHub CLI"
fi

[[ ${#FAILED[@]} -eq 0 ]]
