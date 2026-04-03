# ~/.bash_aliases - Shell aliases and helper functions
# Cross-platform: macOS and Linux
#
# Sections:
#   1. Core          sudo, ls/eza, cat/bat, grep/rg, ps/procs, navigation
#   2. System        update, disk, network, processes
#   3. Utilities     weather, incognito, man pages, download, aliases
#   4. Compression   JPEG, PNG, PDF compression and conversion (macOS)

# Platform detection (cached — avoids repeated subshell forks)
_OS="$(uname -s)"

# ── 1. Core ──────────────────────────────────────────────────────────

# Preserve alias expansion through sudo
alias sudo="sudo "                   # expand aliases through sudo

# ls/eza — use eza if available, fallback to ls
unalias ls 2>/dev/null                                    # clear system ls alias (colorls.sh)
if command -v eza &>/dev/null; then
  # shellcheck disable=SC2032  # function intentionally shadows ls
  ls() {                                                  # ls replacement (eza)
    local args=()
    for arg in "$@"; do
      if [[ "$arg" == -* && "$arg" != --* && "$arg" == *p* ]]; then
        local stripped="${arg//p/}"
        [[ -n "$stripped" && "$stripped" != "-" ]] && args+=("$stripped")
        args+=(--classify)
      else
        args+=("$arg")
      fi
    done
    command eza "${args[@]}"
  }
  alias lsm="eza -lah --icons --group-directories-first" # detailed listing
  alias tree="eza --tree --icons"                       # tree view
elif [[ "$_OS" == "Darwin" ]]; then
  alias ls="ls -G"
  alias lsm="ls -hlAFG"
else
  alias ls="ls --color=auto"
  alias lsm="ls -hlAF --color=auto"
fi

# cat/bat — use bat if available
if command -v bat &>/dev/null; then
  alias cat="bat --paging=never"                        # cat with syntax highlighting
  alias catp="bat"                                      # cat with paging
fi

# grep/ripgrep — use rg if available
if command -v rg &>/dev/null; then
  alias grep="rg"                                       # search with ripgrep
fi

# ps/procs — use procs if available
if command -v procs &>/dev/null; then
  alias ps="procs"                                      # process viewer
fi

# Navigation
alias up="cd .."                   # go up one directory
alias g="z"                        # zoxide jump (short alias)
alias cls="clear;lsm"             # clear screen + detailed listing

# ── 2. System ────────────────────────────────────────────────────────

# Package updates — auto-detects package manager
if command -v brew &>/dev/null; then
  alias update="brew update && brew upgrade"            # update system packages
elif command -v apt &>/dev/null; then
  alias update="sudo apt update && sudo apt upgrade -y"
elif command -v dnf &>/dev/null; then
  alias update="sudo dnf upgrade -y"
fi

alias myip="curl icanhazip.com"    # public IP address
alias plz="fc -l -1 | cut -d' ' -f2- | xargs sudo"  # re-run last command with sudo
alias space="df -h"                # disk free space
alias used="du -ch -d 1"          # directory sizes (1 level deep)
alias restart="source ~/.bash_profile"  # reload shell config

# Listening ports — macOS: lsof, Linux: ss
if [[ "$_OS" == "Darwin" ]]; then
  alias ports="lsof -i -P -n | grep LISTEN"            # show listening ports
else
  alias ports="ss -tlnp"
fi

# Open current directory in file manager
if [[ "$_OS" == "Darwin" ]]; then
  alias reveal="open ."                                 # open dir in file manager
elif command -v xdg-open &>/dev/null; then
  alias reveal="xdg-open ."
fi

# ── 3. Utilities ─────────────────────────────────────────────────────

# weather <city> — terminal weather forecast
weather() { curl wttr.in/"$1"; }

# incognito start|stop — disable/enable shell history
incognito() {
  case $1 in
    start) set +o history ;;
    stop)  set -o history ;;
    *)     echo "Usage: incognito start|stop" ;;
  esac
}

# pman <command> — render man page as PDF and open it
pman() {
  local ps
  ps=$(mktemp -t manpageXXXX).ps
  man -t "$@" > "$ps"
  if [[ "$_OS" == "Darwin" ]]; then
    open "$ps"
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$ps"
  fi
}

# tldr — simplified man pages (tealdeer)
command -v tldr &>/dev/null && alias help="tldr"       # simplified man pages

# download <url> — mirror all linked content from a web page
command -v wget &>/dev/null && alias download="wget --random-wait -r -p --no-parent -e robots=off -U mozilla" # mirror web page

# aliases — list personal aliases and functions with descriptions
aliases() {
  awk '
    /^# ── [0-9]/ { printf "\n\033[1m%s\033[0m\n", $0 }
    /alias [a-zA-Z_]+[=]/ {
      line = $0; sub(/.*alias /, "", line)
      name = line; sub(/=.*/, "", name)
      if (name in seen) next; seen[name] = 1
      desc = ""
      if (line ~ /#/) { desc = line; sub(/.*#[[:space:]]*/, "", desc) }
      printf "  \033[36m%-14s\033[0m %s\n", name, desc
    }
    /^# [a-z].* — / { fdesc = $0; sub(/^# /, "", fdesc) }
    /^[a-zA-Z0-9_]+\(\)/ {
      fn = $0; sub(/\(\).*/, "", fn)
      printf "  \033[36m%-14s\033[0m %s\n", fn "()", fdesc
      fdesc = ""
    }
    !/^#/ && !/^[a-zA-Z0-9_]+\(\)/ && !/^[[:space:]]*$/ && !/alias / { fdesc = "" }
  ' ~/.bash_aliases
}

# ── 4. Compression ──────────────────────────────────────────────────
# Tools: jpegoptim, pngquant, oxipng, ghostscript, qpdf, img2pdf
# Install: brew bundle (see Brewfile)

# jpgsize <file> <max_kb> — compress JPEG to target file size
#   jpgsize photo.jpg 500        → compress to ≤ 500 KB
#   jpgsize photo.jpg 2048       → compress to ≤ 2 MB
jpgsize() {
  if [[ $# -lt 2 ]]; then
    echo "Usage: jpgsize <file> <max_size_kb>"; return 1
  fi
  jpegoptim --strip-all -S "${2}k" "$1"
}

# jpgq <file> <quality> — compress JPEG to quality level (0-100)
#   jpgq photo.jpg 80
jpgq() {
  if [[ $# -lt 2 ]]; then
    echo "Usage: jpgq <file> <quality 0-100>"; return 1
  fi
  jpegoptim --strip-all -m "$2" "$1"
}

# pngsmall <file> [quality] — compress PNG (lossy pngquant + lossless oxipng)
#   pngsmall image.png           → default quality 60-80
#   pngsmall image.png 40-60     → more aggressive
pngsmall() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: pngsmall <file> [quality_min-quality_max]"; return 1
  fi
  local quality="${2:-60-80}"
  pngquant --quality="$quality" --strip --skip-if-larger --force --ext .png "$1" \
    && oxipng -o 4 --strip safe "$1"
}

# pdfsmall <input> [output] [preset] — compress PDF with ghostscript
#   pdfsmall scan.pdf                         → ebook preset (150 dpi)
#   pdfsmall scan.pdf small.pdf screen        → screen preset (72 dpi, smallest)
#   Presets: screen (72dpi) | ebook (150dpi) | printer (300dpi) | prepress (300dpi+)
pdfsmall() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: pdfsmall <input.pdf> [output.pdf] [screen|ebook|printer]"; return 1
  fi
  local input="$1"
  local output="${2:-${input%.pdf}_compressed.pdf}"
  local preset="${3:-ebook}"
  gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/"$preset" \
     -dNOPAUSE -dQUIET -dBATCH \
     -sOutputFile="$output" "$input"
  echo "$(du -h "$input" | cut -f1) -> $(du -h "$output" | cut -f1): $output"
}

# pdfunlock <file.pdf> [...] — remove password protection from PDFs
#   pdfunlock file.pdf           → outputs file_unlocked.pdf
#   pdfunlock *.pdf              → batch unlock, prompts for password once if needed
pdfunlock() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: pdfunlock <file.pdf> [file2.pdf ...]"; return 1
  fi
  local pw=""
  for input in "$@"; do
    local output="${input%.pdf}_unlocked.pdf"
    if qpdf --decrypt --password="" "$input" "$output" 2>/dev/null \
       || qpdf --decrypt "$input" "$output" 2>/dev/null; then
      echo "Unlocked: $output"
    else
      [[ -z "$pw" ]] && { read -rsp "Password: " pw; echo; }
      if qpdf --decrypt --password="$pw" "$input" "$output"; then
        echo "Unlocked: $output"
      else
        echo "Failed:   $input"
      fi
    fi
  done
}

# imgs2pdf <output.pdf> <files...> — convert images to PDF without re-encoding
#   imgs2pdf combined.pdf *.jpg
#   imgs2pdf scan.pdf page1.png page2.png
imgs2pdf() {
  if [[ $# -lt 2 ]]; then
    echo "Usage: imgs2pdf <output.pdf> <files...>"; return 1
  fi
  local output="$1"; shift
  img2pdf "$@" -o "$output"
  echo "Created $output ($(du -h "$output" | cut -f1))"
}
