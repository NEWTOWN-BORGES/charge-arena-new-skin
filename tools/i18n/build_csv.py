#!/usr/bin/env python3
"""Writes localization/translations.csv from the batches in tools/i18n/rows_*.py.

The Portuguese text is the key (first column) and also the pt column, so the game shows
it unchanged in Portuguese and Godot translates it for the other four languages.
"""
import csv, importlib.util, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
rows, seen = [], {}
for path in sorted((ROOT / "tools" / "i18n").glob("rows_*.py")):
    spec = importlib.util.spec_from_file_location(path.stem, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    for row in module.ROWS:
        if row[0] in seen:
            if seen[row[0]] != row:
                sys.exit(f"{path.name}: '{row[0][:40]}' translated twice, differently")
            continue
        seen[row[0]] = row
        rows.append(row)
out = ROOT / "localization" / "translations.csv"
with out.open("w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["keys", "pt", "en", "fr", "es", "it"])
    for row in rows:
        w.writerow([row[0], *row])
print(f"{out} ({len(rows)} rows)")
