#!/usr/bin/env bash
# Inicia o servidor dedicado PvP do Charge Arena no Linux / macOS / WSL
set -euo pipefail

PORT="${1:-27941}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==================================================="
echo "    Charge Arena - Servidor Dedicado Online PvP"
echo "==================================================="
echo "Porta UDP: $PORT"
echo "Diretório: $ROOT"

GODOT_BIN=""
if command -v godot >/dev/null 2>&1; then
    GODOT_BIN="godot"
elif command -v godot4 >/dev/null 2>&1; then
    GODOT_BIN="godot4"
elif [ -x "/opt/charge-arena-server/godot" ]; then
    GODOT_BIN="/opt/charge-arena-server/godot"
fi

if [ -z "$GODOT_BIN" ]; then
    echo "[ERRO] Binário do Godot 4 não encontrado no PATH nem em /opt/charge-arena-server/godot." >&2
    exit 1
fi

echo "A arrancar servidor headless na porta UDP $PORT..."
exec "$GODOT_BIN" --headless --path "$ROOT" --script res://scripts/network/server_main.gd -- --port="$PORT"

