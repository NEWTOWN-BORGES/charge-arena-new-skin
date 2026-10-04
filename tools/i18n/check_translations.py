#!/usr/bin/env python3
"""Checks localization/*.csv: five filled columns, the pt column equal to the key, and the
same %d/%s placeholders, in the same order, in every language. Exit 1 on any problem."""
import csv, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LANGS = ["pt", "en", "fr", "es", "it"]
SPEC = re.compile(r"%(?:\d+\$)?[-+ 0#]*\d*(?:\.\d+)?[sdif%]")
problems = 0
for path in sorted((ROOT / "localization").glob("*.csv")):
    with path.open(encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader)
        if header != ["keys", *LANGS]:
            print(f"{path.name}: header must be keys,{','.join(LANGS)}"); problems += 1; continue
        for n, row in enumerate(reader, start=2):
            key = row[0]
            if len(row) != 6 or any(not cell.strip() for cell in row):
                print(f"{path.name}:{n}: empty or missing column for '{key[:40]}'"); problems += 1; continue
            if row[1] != key:
                print(f"{path.name}:{n}: pt column differs from the key"); problems += 1
            wanted = SPEC.findall(key)
            for lang, cell in zip(LANGS[1:], row[2:]):
                if SPEC.findall(cell) != wanted:
                    print(f"{path.name}:{n}: {lang} placeholders {SPEC.findall(cell)} != {wanted}"); problems += 1
print("TRANSLATIONS_OK" if problems == 0 else f"TRANSLATIONS_PROBLEMS={problems}")
sys.exit(1 if problems else 0)
