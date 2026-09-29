#!/usr/bin/env bash
# Exporta um APK de teste a partir do commit atual, sem mexer na pasta do projeto.
#
# Uso: tools/export_apk.sh <saida.apk> [pacote] [nome da app] [versão] [features]
#   pacote     por omissão org.chargearena.teste (instala-se ao lado das outras versões)
#   nome       por omissão "Charge Arena Teste"
#   versão     por omissão o hash curto do commit
#   features   por omissão nenhuma; "open_test" faz a versão LAB (tudo desbloqueado)
#   ícone      por omissão "bit"; usa art/icon/<ícone>_icon.png, _foreground e _background
#   arq        por omissão "arm64" (arm64-v8a); "arm32" faz o APK para telemóveis com Android
#              de 32 bits (armeabi-v7a), como os Android Go (ex.: Redmi A3); "all" leva os dois
#              (a versão para a loja: tools/build_aab.sh)
#
# Versão da loja: com STORE_KEYSTORE, STORE_ALIAS e STORE_PASS no ambiente assina com a chave
# de upload em vez da de depuração; VERSION_CODE define o número de versão (tem de subir a
# cada envio para a Google Play).
#
# Usa o preset "Android" só com arm64-v8a (os telemóveis atuais) e assina com a chave de
# depuração do Godot: serve para testes, não para distribuir. Precisa de
# `tools/setup_env.sh --android`.
set -euo pipefail

out="$(realpath -m "${1:?caminho do APK}")"
package="${2:-org.chargearena.teste}"
label="${3:-Charge Arena Teste}"
root="$(git rev-parse --show-toplevel)"
version="${4:-$(git -C "$root" rev-parse --short HEAD)}"
features="${5:-}"
icon="${6:-bit}"
arch="${7:-arm64}"
keystore="${HOME}/.local/share/godot/keystores/debug.keystore"

work="$(mktemp -d)"
trap 'rm -r "$work"' EXIT
git -C "$root" archive HEAD | tar -x -C "$work"
python3 - "$work/export_presets.cfg" "$out" "$package" "$label" "$version" "$features" "$icon" "$arch" <<'EOF'
import re, sys
path, out, package, label, version, features, icon, arch = sys.argv[1:]
text = open(path).read()
head, rest = text.split("[preset.1]", 1)
def put(key, value):
    global head
    head, count = re.subn(rf'^{re.escape(key)}=.*$', f'{key}={value}', head, count=1, flags=re.M)
    assert count == 1, key
put("export_path", f'"{out}"')
put("custom_features", f'"{features}"')
put("package/unique_name", f'"{package}"')
put("package/name", f'"{label}"')
put("version/name", f'"{version}"')
put("architectures/x86_64", "false")
put("architectures/arm64-v8a", "false" if arch == "arm32" else "true")
put("architectures/armeabi-v7a", "true" if arch in ("arm32", "all") else "false")
import os
if os.environ.get("VERSION_CODE"):
    put("version/code", os.environ["VERSION_CODE"])
put("launcher_icons/main_192x192", f'"res://art/icon/{icon}_icon.png"')
put("launcher_icons/adaptive_foreground_432x432", f'"res://art/icon/{icon}_foreground.png"')
put("launcher_icons/adaptive_background_432x432", f'"res://art/icon/{icon}_background.png"')
# The themed (monochrome) icon of Android 13+: without it the template points at a file it
# left out, and aapt2 refuses the APK when the App Bundle is built.
put("launcher_icons/adaptive_monochrome_432x432", f'"res://art/icon/{icon}_monochrome.png"')
open(path, "w").write(head + "[preset.1]" + rest)
EOF
mkdir -p "$(dirname "$out")"
(cd "$work" && godot --headless --import >/dev/null 2>&1 || true)
(cd "$work" && GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${STORE_KEYSTORE:-$keystore}" \
	GODOT_ANDROID_KEYSTORE_RELEASE_USER="${STORE_ALIAS:-androiddebugkey}" \
	GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${STORE_PASS:-android}" \
	godot --headless --export-release "Android" "$out" 2>&1 | grep -E 'ERROR|DONE.*export' || true)
apksigner verify "$out"
ls -lh "$out"
