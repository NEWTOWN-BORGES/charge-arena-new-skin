#!/usr/bin/env bash
# Packs the online PvP server: the few scripts it runs, a minimal project file and the
# installer. Nothing secret goes in: it is the same game code the APK already carries.
#   tools/build_server_bundle.sh            -> builds/server/charge-arena-server.tar.gz
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/builds/server"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/charge-arena-server"
mkdir -p "$APP/scripts/network" "$APP/scripts/gameplay" "$APP/scripts/progression" "$OUT"
cp "$ROOT/scripts/network/online.gd" "$ROOT/scripts/network/online_server.gd" "$ROOT/scripts/network/server_main.gd" "$APP/scripts/network/"
cp "$ROOT/scripts/gameplay/arena_rules.gd" "$ROOT/scripts/gameplay/powers.gd" "$APP/scripts/gameplay/"
cp "$ROOT/scripts/progression/skins.gd" "$APP/scripts/progression/"
cp "$ROOT/server/install.sh" "$APP/install.sh"
cat > "$APP/project.godot" <<'EOF'
; Charge Arena online PvP server: only the rules, no graphics or sound.
config_version=5

[application]
config/name="Charge Arena Server"

[physics]
common/physics_ticks_per_second=60
common/physics_jitter_fix=0.0
EOF
PROTOCOL="$(grep -m1 '^const PROTOCOL' "$ROOT/scripts/network/online.gd" | grep -o '[0-9]\+')"
echo "$PROTOCOL" > "$APP/PROTOCOL"
tar -czf "$OUT/charge-arena-server.tar.gz" -C "$STAGE" charge-arena-server
echo "$OUT/charge-arena-server.tar.gz (protocol $PROTOCOL)"
