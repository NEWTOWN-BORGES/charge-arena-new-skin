#!/usr/bin/env python3
"""Check literal Godot resource paths and duplicate script UIDs after folder moves."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
PATH = re.compile(r'''["'](res://[^"'\n]+)["']''')
SUFFIXES = {".gd", ".gdshader", ".tscn", ".tres", ".cfg", ".godot"}


def main() -> int:
    errors = []
    checked = 0
    files = [ROOT / "project.godot", ROOT / "export_presets.cfg"]
    for folder in ("scripts", "scenes", "shaders", "tests", "tools"):
        files.extend(p for p in (ROOT / folder).rglob("*") if p.suffix in SUFFIXES)
    for path in files:
        for line_number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
            if line.lstrip().startswith("#"):
                continue
            for match in PATH.finditer(line):
                relative = match.group(1)[6:]
                # Dynamic assets and temporary test fixtures have no static file to check.
                if any(token in relative for token in ("%", "*")) or relative.endswith((".tmp", "/")) or not Path(relative).suffix:
                    continue
                checked += 1
                if not (ROOT / relative).exists():
                    errors.append(f"{path.relative_to(ROOT)}:{line_number}: missing {relative}")
    seen = {}
    for folder in ("scripts", "tests"):
        for path in (ROOT / folder).rglob("*.uid"):
            uid = path.read_text(encoding="utf-8").strip()
            if uid in seen:
                errors.append(f"Duplicate UID: {path.relative_to(ROOT)} / {seen[uid]}")
            seen[uid] = str(path.relative_to(ROOT))
    print(f"RESOURCE_CHECK: {checked} paths, {len(seen)} script UIDs, {len(errors)} errors")
    for error in errors:
        print(error)
    return int(bool(errors))


if __name__ == "__main__":
    sys.exit(main())
