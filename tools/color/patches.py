"""Valores de teste para comparar as cores do Godot com as do Blender (luz linear, por canal).

    python3 tools/color/patches.py        # escreve tools/color/patches.json

17 níveis por canal (0 e uma escala geométrica de 0,003 a 3), 4913 quadrados em grelha de 70.
"""
import json
from pathlib import Path

LEVELS = [0.0] + [0.003 * (1000.0 ** (i / 15.0)) for i in range(16)]
COLUMNS = 70

if __name__ == "__main__":
    patches = [[r, g, b] for r in LEVELS for g in LEVELS for b in LEVELS]
    out = Path(__file__).with_name("patches.json")
    out.write_text(json.dumps({"columns": COLUMNS, "cell": 8, "levels": LEVELS, "patches": patches}))
    print("PATCHES", len(patches), out)
