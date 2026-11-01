# ~/dev/dotfiles/Brewfile
# macOS: brew bundle --file=~/dev/dotfiles/Brewfile
# Linux: packages are handled by install.sh (apt/dnf + release binaries)
#
# Project toolchains (ruby, node, python, terraform, sops, ...) come from each
# repository's mise.toml, not from here. The global npm CLIs live in
# .config/mise/config.toml.

tap "modem-dev/tap"
tap "instantclienttap/instantclient"
tap "oven-sh/bun"
tap "pchuri/tap"

# Shell & prompt
brew "bash"
brew "bash-completion@2"
brew "fzf"
brew "mise"

# Git
brew "git"
brew "git-delta"
brew "git-lfs"
brew "gh"
brew "glab"
brew "gnupg"
brew "lazygit"
brew "modem-dev/tap/hunk"
cask "git-credential-manager"

# Directory environment
brew "direnv"

# Editors
brew "vim"

# Terminal tools
brew "bat"
brew "dtop"
brew "eza"
brew "fd"
brew "htop"
brew "jq"
brew "lazydocker"
brew "procs"
brew "ripgrep"
brew "rsync"
brew "rtk"
brew "smug"
brew "tealdeer"
brew "tmux"
brew "watch"
brew "wget"
brew "yq"

# App development: Docker via Colima, cloud and issue CLIs, database clients
brew "colima"
brew "docker"
brew "docker-compose"
brew "awscli"
brew "jira-cli"
brew "sops"
brew "libpq"
brew "mysql-client"
if Hardware::CPU.arm?
  brew "instantclienttap/instantclient/instantclient-arm64-basic"
  brew "instantclienttap/instantclient/instantclient-arm64-sqlplus"
else
  brew "instantclienttap/instantclient/instantclient-basic"
  brew "instantclienttap/instantclient/instantclient-sqlplus"
end
brew "uv"

# Personal tools
brew "go"
brew "oven-sh/bun/bun"
brew "iperf3"
brew "jpeg-xl"
brew "lima"
brew "mole"
brew "nmap"
brew "ollama"
brew "openapi-generator"
brew "pchuri/tap/confluence-cli"

# Image & PDF compression
brew "jpegoptim"
brew "pngquant"
brew "oxipng"
brew "ghostscript"
brew "img2pdf"
brew "qpdf"

# Fonts
cask "font-iosevka-term-nerd-font"
cask "font-jetbrains-mono-nerd-font"

# Terminal emulator (macOS only)
cask "ghostty"

# AI coding agents
cask "claude-code"
cask "codex"
cask "copilot-cli"
