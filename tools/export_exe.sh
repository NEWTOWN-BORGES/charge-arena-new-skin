#!/usr/bin/env bash
# Exporta o jogo para Windows (x86_64) num único .exe, a partir do commit atual, sem mexer na
# pasta do projeto.
#
# Uso: tools/export_exe.sh <saida.exe> [features]
#   features   por omissão "open_test" (a versão LAB, tudo desbloqueado); "" faz a ALFA
#
# O .pck vai dentro do .exe. Não é assinado: o Windows avisa ("O Windows protegeu o PC") e
# corre com "Mais informações" › "Executar mesmo assim".
set -euo pipefail

out="$(realpath -m "${1:?caminho do .exe}")"
features="${2-open_test}"
root="$(git rev-parse --show-toplevel)"

work="$(mktemp -d)"
trap 'rm -r "$work"' EXIT
git -C "$root" archive HEAD | tar -x -C "$work"
index=$(grep -c '^\[preset\.[0-9]*\]$' "$work/export_presets.cfg")
cat >> "$work/export_presets.cfg" <<EOF

[preset.$index]

name="Windows"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features="$features"
export_filter="all_resources"
include_filter=""
exclude_filter="audio/music_*,tests/*,tools/*,docs/*,previews/*,.qa/*,*.log,preview*.png,README.md,hosting/*,server/*"
export_path="$out"

[preset.$index.options]

binary_format/embed_pck=true
binary_format/architecture="x86_64"
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
codesign/enable=false
application/modify_resources=false
EOF
mkdir -p "$(dirname "$out")"
(cd "$work" && godot --headless --editor --import) || (cd "$work" && godot --headless --editor --import)
(cd "$work" && godot --headless --export-release "Windows" "$out")
ls -lh "$out"
