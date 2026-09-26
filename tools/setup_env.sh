#!/usr/bin/env bash
# Instala as ferramentas usadas neste projeto num Linux x86_64 (Ubuntu/Debian):
#   - Godot 4.7.1 (comando `godot`)
#   - Blender 5.0 como módulo Python (`pip install bpy`) para os modelos em tools/blender
#   - com --android: modelos de exportação Android do Godot, apksigner, zipalign e adb
#
# Uso: tools/setup_env.sh [--android]
# Cada passo é saltado quando já está feito, por isso pode correr-se sempre.
set -euo pipefail

GODOT_VERSION="4.7.1"
GODOT_TAG="${GODOT_VERSION}-stable"
GODOT_DIR="/opt/godot"
GODOT_BIN="${GODOT_DIR}/Godot_v${GODOT_TAG}_linux.x86_64"
RELEASES="https://github.com/godotengine/godot-builds/releases/download/${GODOT_TAG}"
TEMPLATES_DIR="${HOME}/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
SDK_DIR="/opt/android-sdk"
SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

if ! command -v godot >/dev/null || ! godot --version 2>/dev/null | grep -q "^${GODOT_VERSION}"; then
	echo "== Godot ${GODOT_VERSION}"
	$SUDO mkdir -p "$GODOT_DIR"
	tmp="$(mktemp -d)"
	curl -fsSL -o "$tmp/godot.zip" "${RELEASES}/Godot_v${GODOT_TAG}_linux.x86_64.zip"
	$SUDO unzip -oq "$tmp/godot.zip" -d "$GODOT_DIR"
	rm -r "$tmp"
	$SUDO ln -sf "$GODOT_BIN" /usr/local/bin/godot
fi
godot --version

if ! python3 -c "import bpy" 2>/dev/null; then
	echo "== Blender (bpy)"
	python3 -m pip install --quiet bpy
fi
python3 -c "import bpy; print('Blender', bpy.app.version_string)"

if [ "${1:-}" = "--android" ]; then
	echo "== Ferramentas Android"
	if ! command -v apksigner >/dev/null; then
		$SUDO apt-get install -y -q apksigner zipalign adb
	fi
	# O Godot só precisa de platform-tools/adb e build-tools/<versão>/apksigner no SDK.
	$SUDO mkdir -p "$SDK_DIR/platform-tools" "$SDK_DIR/build-tools/34.0.0"
	$SUDO ln -sf "$(command -v adb)" "$SDK_DIR/platform-tools/adb"
	$SUDO ln -sf "$(command -v apksigner)" "$SDK_DIR/build-tools/34.0.0/apksigner"
	$SUDO ln -sf "$(command -v zipalign)" "$SDK_DIR/build-tools/34.0.0/zipalign"
	if [ ! -f "$TEMPLATES_DIR/android_release.apk" ]; then
		echo "== Modelos de exportação Android (descarrega ~1,2 GB, guarda só os de Android)"
		mkdir -p "$TEMPLATES_DIR"
		tmp="$(mktemp -d)"
		curl -fsSL -o "$tmp/templates.tpz" "${RELEASES}/Godot_v${GODOT_TAG}_export_templates.tpz"
		unzip -ojq "$tmp/templates.tpz" 'templates/android*' 'templates/version.txt' -d "$TEMPLATES_DIR"
		rm -r "$tmp"
	fi
	# Abrir o projeto uma vez cria as definições do editor e a chave de depuração.
	settings="${HOME}/.config/godot/editor_settings-${GODOT_VERSION%.*}.tres"
	if [ ! -f "$settings" ]; then
		godot --headless --editor --quit >/dev/null 2>&1 || true
	fi
	sed -i "s|^export/android/android_sdk_path = .*|export/android/android_sdk_path = \"${SDK_DIR}\"|" "$settings"
	grep -q '^export/android/android_sdk_path' "$settings" || echo "export/android/android_sdk_path = \"${SDK_DIR}\"" >> "$settings"
	echo "Android pronto: tools/export_apk.sh"
fi
