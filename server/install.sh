#!/usr/bin/env bash
# Installs (or updates) the Charge Arena online PvP server on a Linux machine with
# systemd: Ubuntu or Oracle Linux, ARM or Intel. Run it as root from the unpacked bundle:
#   sudo bash install.sh
# It keeps running after a reboot and restarts by itself if it ever stops.
set -euo pipefail
GODOT_VERSION="4.7.1"
PORT="${PORT:-27941}"
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="/opt/charge-arena-server"

if [ "$(id -u)" -ne 0 ]; then
	echo "Corre com sudo: sudo bash install.sh" >&2
	exit 1
fi

case "$(uname -m)" in
	aarch64|arm64) ARCH="arm64" ;;
	x86_64|amd64) ARCH="x86_64" ;;
	*) echo "Processador não suportado: $(uname -m)" >&2; exit 1 ;;
esac

echo "== Pacotes necessários"
if command -v apt-get >/dev/null; then
	apt-get update -q
	apt-get install -y -q unzip curl
elif command -v dnf >/dev/null; then
	dnf install -y -q unzip curl
fi

echo "== Godot $GODOT_VERSION ($ARCH)"
BIN="$DEST/godot"
if [ ! -x "$BIN" ] || ! "$BIN" --headless --version 2>/dev/null | grep -q "^$GODOT_VERSION"; then
	mkdir -p "$DEST"
	TMP="$(mktemp -d)"
	NAME="Godot_v${GODOT_VERSION}-stable_linux.${ARCH}"
	curl -fsSL -o "$TMP/godot.zip" "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/${NAME}.zip"
	unzip -q -o "$TMP/godot.zip" -d "$TMP"
	install -m 0755 "$TMP/$NAME" "$BIN"
	rm -rf "$TMP"
fi

echo "== Ficheiros do servidor"
id charge >/dev/null 2>&1 || useradd --system --home "$DEST" --shell /usr/sbin/nologin charge
mkdir -p "$DEST/app"
rm -rf "$DEST/app/scripts"
cp -r "$HERE/scripts" "$HERE/project.godot" "$HERE/PROTOCOL" "$DEST/app/"
chown -R charge:charge "$DEST"

echo "== Serviço (arranca sozinho)"
cat > /etc/systemd/system/charge-arena-server.service <<EOF
[Unit]
Description=Charge Arena online PvP server
After=network-online.target
Wants=network-online.target

[Service]
User=charge
WorkingDirectory=$DEST/app
Environment=HOME=$DEST
ExecStart=$BIN --headless --path $DEST/app --script res://scripts/network/server_main.gd -- --port=$PORT
Restart=always
RestartSec=3
NoNewPrivileges=true
ProtectSystem=full
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable charge-arena-server >/dev/null
systemctl restart charge-arena-server

echo "== Firewall da máquina: porta UDP $PORT"
if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
	ufw allow "$PORT/udp"
elif command -v firewall-cmd >/dev/null && firewall-cmd --state >/dev/null 2>&1; then
	firewall-cmd --permanent --add-port="$PORT/udp" && firewall-cmd --reload
elif command -v iptables >/dev/null; then
	# Oracle's Ubuntu images reject everything not listed; the rule goes before that.
	if ! iptables -C INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null; then
		iptables -I INPUT 5 -p udp --dport "$PORT" -j ACCEPT
	fi
	if command -v netfilter-persistent >/dev/null; then
		netfilter-persistent save >/dev/null
	fi
fi

sleep 3
if systemctl is-active --quiet charge-arena-server; then
	echo
	echo "PRONTO: o servidor está a correr na porta UDP $PORT (protocolo $(cat "$HERE/PROTOCOL"))."
	echo "Falta só abrir a mesma porta na consola da nuvem (ver o guia)."
else
	echo "O servidor não arrancou. Últimas linhas do registo:" >&2
	journalctl -u charge-arena-server -n 30 --no-pager >&2
	exit 1
fi
