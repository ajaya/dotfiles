#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_home="$(mktemp -d)"
before_manifest="$(mktemp)"
after_manifest="$(mktemp)"

cleanup() {
  rm -rf "$tmp_home"
  rm -f "$before_manifest" "$after_manifest"
}
trap cleanup EXIT

find "$tmp_home" -mindepth 1 -print | sort > "$before_manifest"
HOME="$tmp_home" "$repo_root/install.sh" --dry-run >/tmp/dotfiles-dry-run.log
find "$tmp_home" -mindepth 1 -print | sort > "$after_manifest"

if ! cmp -s "$before_manifest" "$after_manifest"; then
  echo "install.sh --dry-run mutated HOME:" >&2
  diff -u "$before_manifest" "$after_manifest" >&2 || true
  exit 1
fi

echo "dry-run did not mutate HOME"
