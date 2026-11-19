#!/usr/bin/env bash
# dotfiles-eba only: the versions this branch pins match EBA's sources of truth.
#
# Reads EBA's pins from origin/master of two local checkouts (run
# `git fetch` in them first, or pass --fetch):
#   EBA app             .ruby-version, mise.toml [tools]
#   eba-apps-automation ansible/roles/host_software/defaults/main.yml
#                       (host_software_versions, the Nerd Font URL) and
#                       ansible/group_vars/all/main.yml (python, mise_version)
# and compares them with this branch's pins:
#   .config/mise/config.toml, .config/mise/conf.d/dotfiles-clis.toml and the
#   MISE_VERSION, SOPS_VERSION and NERD_FONT_VERSION pins in install.sh.
# A tool is checked against every EBA source that defines it; tools EBA does
# not define are not checked. Exits 1 listing each mismatch; skips (exit 0)
# when a checkout is absent.
#
# Overrides: DOTFILES_EBA_DIR (default /opt/apps/dev/eba),
# DOTFILES_EBA_AUTOMATION_DIR (default /opt/apps/dev/eba-apps-automation),
# DOTFILES_EBA_REF (default origin/master).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
eba_dir="${DOTFILES_EBA_DIR:-/opt/apps/dev/eba}"
automation_dir="${DOTFILES_EBA_AUTOMATION_DIR:-/opt/apps/dev/eba-apps-automation}"
ref="${DOTFILES_EBA_REF:-origin/master}"

for arg in "$@"; do
  case $arg in
    --fetch) fetch=true ;;
    *) echo "Usage: test/eba-versions.sh [--fetch]" >&2; exit 2 ;;
  esac
done

for dir in "$eba_dir" "$automation_dir"; do
  if ! git -C "$dir" rev-parse --verify --quiet "$ref" >/dev/null 2>&1; then
    echo "skipped: no git checkout with $ref at $dir (set DOTFILES_EBA_DIR / DOTFILES_EBA_AUTOMATION_DIR)"
    exit 0
  fi
  if [[ "${fetch:-false}" == true ]]; then
    git -C "$dir" fetch --quiet origin
  fi
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git -C "$eba_dir" show "$ref:.ruby-version" > "$tmp/ruby-version"
git -C "$eba_dir" show "$ref:mise.toml" > "$tmp/app-mise.toml"
git -C "$automation_dir" show "$ref:ansible/roles/host_software/defaults/main.yml" > "$tmp/host.yml"
git -C "$automation_dir" show "$ref:ansible/group_vars/all/main.yml" > "$tmp/group_vars.yml"

python3 -I - "$repo_root" "$tmp" "$ref" <<'PY'
import re, sys, tomllib
from pathlib import Path

repo, tmp, ref = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]

# Clients the EBA lock is expected to pin; skipped with a note until it does.
expected_in_host = ["gh", "npm:confluence-cli"]

def tools(path):
    out = {}
    for name, spec in tomllib.loads(path.read_text()).get("tools", {}).items():
        out[name] = spec["version"] if isinstance(spec, dict) else spec
    return out

# This branch's pins
ours = tools(repo / ".config/mise/config.toml")
ours.update(tools(repo / ".config/mise/conf.d/dotfiles-clis.toml"))
install = (repo / "install.sh").read_text()
for key, tool in [("MISE_VERSION", "mise"), ("SOPS_VERSION", "sops"), ("NERD_FONT_VERSION", "nerd-fonts")]:
    m = re.search(rf'^{key}="v?([^"]+)"', install, re.M)
    if m:
        ours[f"{tool} (install.sh)"] = m.group(1)

# EBA app
app = tools(tmp / "app-mise.toml")
app["ruby"] = (tmp / "ruby-version").read_text().strip()

# EBA host tool lock (YAML with Jinja: read the plain key: "value" lines)
group_vars = (tmp / "group_vars.yml").read_text()
def gv(key):
    m = re.search(rf'^{key}:\s*"?([^"\s]+)"?', group_vars, re.M)
    return m.group(1) if m else None
host = {}
block = re.search(r"^host_software_versions:\n((?:[ \t]+.*\n)+)", (tmp / "host.yml").read_text(), re.M)
for line in block.group(1).splitlines():
    m = re.match(r'\s+"?([^":]+(?::[^":]+)?)"?:\s*"([^"]+)"', line)
    if m:
        name, version = m.groups()
        if "ansible_mise_python_version" in version:
            version = gv("ansible_mise_python_version")
        host[name] = version
font = re.search(r"nerd-fonts/releases/download/v([0-9.]+)/", (tmp / "host.yml").read_text())
host["mise (install.sh)"] = gv("mise_version")
if font:
    host["nerd-fonts (install.sh)"] = font.group(1)
host["sops (install.sh)"] = host.get("sops")
app["sops (install.sh)"] = app.get("sops")

sources = [("EBA app (.ruby-version, mise.toml)", app), ("EBA host tool lock (host_software)", host)]
mismatches, checked, notes = [], 0, []
for tool, version in sorted(ours.items()):
    for label, eba in sources:
        want = eba.get(tool)
        if want is None:
            continue
        checked += 1
        if str(version) != str(want):
            mismatches.append(f"  {tool}: dotfiles-eba {version}, {label} {want}")
for tool in expected_in_host:
    if tool not in host:
        notes.append(f"  {tool}: not in the EBA host tool lock on {ref} yet; skipped")

for note in notes:
    print(note)
if mismatches:
    print(f"{len(mismatches)} version mismatch(es) with EBA ({ref}):", file=sys.stderr)
    print("\n".join(mismatches), file=sys.stderr)
    sys.exit(1)
print(f"versions match EBA ({ref}): {checked} pin comparisons")
PY
