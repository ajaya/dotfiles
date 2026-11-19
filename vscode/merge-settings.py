#!/usr/bin/env python3
"""Merge dotfiles' VS Code user settings into a user settings.json (JSONC).

Usage:
  merge-settings.py TARGET TRACKED [KEY=JSON ...] [--dry-run]

TARGET   the user's settings.json (created when missing)
TRACKED  vscode/settings.json: the personal keys dotfiles owns
KEY=JSON extra keys for this machine (platform terminal, commit signing)

Only the tracked and extra keys are written. Every other key, comment and
blank line in TARGET stays as it is, including keys another tool (EBA's
Ansible) merges there; those are refused as tracked keys. A key whose value
already matches is left untouched, so a second run writes nothing. Prints
"changed: KEY" per key written, or "unchanged".
"""

import json
import os
import re
import sys
import tempfile

# Keys other provisioning owns on its machines; dotfiles never writes them.
PROTECTED = {
    "rubyLsp.rubyVersionManager",
    "hadolint.hadolintPath",
    "ansible.python.interpreterPath",
    "settingsSync.ignoredSettings",
}


def strip_jsonc(text):
    """Return JSON text: comments removed, trailing commas dropped."""
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                in_str = False
            i += 1
        elif c == '"':
            in_str = True
            out.append(c)
            i += 1
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            i = n if end < 0 else end + 2
        else:
            out.append(c)
            i += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


def loads(text):
    return json.loads(strip_jsonc(text)) if text.strip() else {}


def skip_space(text, i):
    """Skip whitespace and comments from i; return the next index."""
    n = len(text)
    while i < n:
        if text[i].isspace():
            i += 1
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            i = n if end < 0 else end + 2
        else:
            break
    return i


def scan_string(text, i):
    """i at an opening quote; return the index after the closing quote."""
    i += 1
    while text[i] != '"':
        i += 2 if text[i] == "\\" else 1
    return i + 1


def scan_value(text, i):
    """Return the end index of the JSON value starting at i."""
    if text[i] == '"':
        return scan_string(text, i)
    if text[i] in "{[":
        depth = 0
        while True:
            if text[i] == '"':
                i = scan_string(text, i)
                continue
            if text.startswith("//", i) or text.startswith("/*", i):
                i = skip_space(text, i)
                continue
            if text[i] in "{[":
                depth += 1
            elif text[i] in "}]":
                depth -= 1
                if depth == 0:
                    return i + 1
            i += 1
    m = re.compile(r"[^\s,}\]/]+").match(text, i)
    return m.end()


def top_level(text):
    """Map each top-level key to its value span; return (spans, closing brace)."""
    spans = {}
    i = skip_space(text, 0)
    if i >= len(text) or text[i] != "{":
        raise ValueError("settings file is not a JSON object")
    i = skip_space(text, i + 1)
    while text[i] != "}":
        end = scan_string(text, i)
        key = json.loads(text[i:end])
        i = skip_space(text, end)
        assert text[i] == ":"
        start = skip_space(text, i + 1)
        stop = scan_value(text, start)
        spans[key] = (start, stop)
        i = skip_space(text, stop)
        if text[i] == ",":
            i = skip_space(text, i + 1)
    return spans, i


def render(value, indent="  "):
    return json.dumps(value, indent=2, ensure_ascii=False).replace("\n", "\n" + indent)


def merge(text, wanted):
    """Return (new text, changed keys)."""
    if not text.strip():
        text = "{\n}\n"
    spans, close = top_level(text)
    current = loads(text)
    changed = []
    edits = []  # (start, stop, replacement)
    additions = []
    for key, value in wanted.items():
        if key in spans:
            if current.get(key) != value:
                start, stop = spans[key]
                edits.append((start, stop, render(value)))
                changed.append(key)
        else:
            additions.append(f'  {json.dumps(key)}: {render(value)}')
            changed.append(key)
    if additions:
        # Put a comma after the last existing value when it lacks one.
        last = max((stop for _, stop in spans.values()), default=None)
        block = ",\n".join(additions)
        if last is None:
            edits.append((close, close, block + "\n"))
        else:
            after = skip_space(text, last)
            sep = "" if text[after] == "," else ","
            # Insert right after the last value (or its comma), before the brace.
            pos = after + 1 if sep == "" else last
            edits.append((pos, pos, sep + "\n" + block))
    for start, stop, repl in sorted(edits, reverse=True):
        text = text[:start] + repl + text[stop:]
    loads(text)  # the result must still parse
    return text, changed


def main(argv):
    dry_run = "--dry-run" in argv
    args = [a for a in argv if a != "--dry-run"]
    if len(args) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    target, tracked = args[0], args[1]
    with open(tracked, encoding="utf-8") as f:
        wanted = loads(f.read())
    for pair in args[2:]:
        key, _, raw = pair.partition("=")
        wanted[key] = json.loads(raw)
    clash = PROTECTED & wanted.keys()
    if clash:
        print(f"refusing to write host-owned keys: {', '.join(sorted(clash))}", file=sys.stderr)
        return 1

    text = ""
    if os.path.exists(target):
        with open(target, encoding="utf-8") as f:
            text = f.read()
    new, changed = merge(text, wanted)
    if not changed:
        print("unchanged")
        return 0
    for key in changed:
        print(f"{'would change' if dry_run else 'changed'}: {key}")
    if dry_run:
        return 0
    os.makedirs(os.path.dirname(os.path.abspath(target)), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(os.path.abspath(target)), prefix=".settings.")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(new if new.endswith("\n") else new + "\n")
    if os.path.exists(target):
        os.chmod(tmp, os.stat(target).st_mode & 0o777)
    # Replace the file a link points to, not the link.
    os.replace(tmp, os.path.realpath(target))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
