#!/usr/bin/env bash
# A second `install.sh --yes --no-packages` run changes nothing in HOME (mise's
# own data and cache dirs aside: it refreshes its shims) and
# exits 0; existing regular files are backed up once, then replaced by links.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_home="$(mktemp -d)"
# mise installs the command-line clients into the throwaway HOME (a few
# hundred MB of downloads on the first run).
export MISE_DATA_DIR="$tmp_home/.local/share/mise" MISE_CACHE_DIR="$tmp_home/.cache/mise"
unset MISE_CONFIG_DIR MISE_GLOBAL_CONFIG_FILE MISE_ENV
marker="$(mktemp)"
log="$(mktemp)"

cleanup() {
  rm -rf "$tmp_home"
  rm -f "$marker" "$log"
}
trap cleanup EXIT

# A file the installer replaces, as a provisioned host would have it
printf '# pre-existing\n' > "$tmp_home/.bashrc"

HOME="$tmp_home" "$repo_root/install.sh" --yes --no-packages </dev/null >"$log" 2>&1 \
  || { cat "$log" >&2; echo "first run failed" >&2; exit 1; }

[[ -L "$tmp_home/.bashrc" ]] || { echo ".bashrc is not a link" >&2; exit 1; }
backup="$(find "$tmp_home" -maxdepth 1 -name '.dotfiles-backup-*' -print -quit)"
[[ -f "$backup/.bashrc" ]] || { echo "existing .bashrc was not backed up" >&2; exit 1; }

sleep 1
touch "$marker"
HOME="$tmp_home" "$repo_root/install.sh" --yes --no-packages </dev/null >"$log" 2>&1 \
  || { cat "$log" >&2; echo "second run failed" >&2; exit 1; }

changed="$(find "$tmp_home" \( -path "$tmp_home/.local/state" -o -path "$tmp_home/.gnupg" -o -path "$tmp_home/.cache" -o -path "$MISE_DATA_DIR" \) -prune \
  -o -newer "$marker" -print)"
if [[ -n "$changed" ]]; then
  echo "second run changed HOME:" >&2
  echo "$changed" >&2
  exit 1
fi
if [[ "$(find "$tmp_home" -maxdepth 1 -name '.dotfiles-backup-*' | wc -l | tr -d ' ')" != 1 ]]; then
  echo "second run made another backup" >&2
  exit 1
fi

echo "second run changed nothing"
