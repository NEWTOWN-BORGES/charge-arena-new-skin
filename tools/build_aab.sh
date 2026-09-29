#!/usr/bin/env bash
# Gera o Android App Bundle (.aab) para a Google Play, a partir do commit atual, sem Gradle.
#
# Uso: STORE_KEYSTORE=... STORE_ALIAS=... STORE_PASS=... VERSION_CODE=N \
#        BUNDLETOOL=bundletool.jar tools/build_aab.sh <saida.aab> <versão> [pacote] [nome]
#
# 1. tools/export_apk.sh exporta um APK com os dois processadores (arm64-v8a e armeabi-v7a),
#    assinado com a chave de upload;
# 2. o aapt2 converte os recursos do APK para o formato protobuf que o bundle usa;
# 3. os ficheiros são arrumados no módulo "base" (manifest/, dex/, res/, assets/, lib/, root/);
# 4. o bundletool monta o .aab e o jarsigner assina-o com a mesma chave de upload;
# 5. o bundletool valida o resultado gerando os APKs que a loja entregaria.
#
# A chave NUNCA vai para o repositório: guarda-a fora dele (o .gitignore recusa *.jks).
set -euo pipefail

out="$(realpath -m "${1:?caminho do .aab}")"
version="${2:?versão, ex.: 1.0.0}"
package="${3:-com.newtownborges.chargearena}"
label="${4:-Charge Arena}"
: "${STORE_KEYSTORE:?falta STORE_KEYSTORE}" "${STORE_ALIAS:?falta STORE_ALIAS}" "${STORE_PASS:?falta STORE_PASS}"
: "${VERSION_CODE:?falta VERSION_CODE}" "${BUNDLETOOL:?falta BUNDLETOOL (bundletool-all.jar)}"
root="$(git rev-parse --show-toplevel)"
work="$(mktemp -d)"
trap 'rm -r "$work"' EXIT

"$root/tools/export_apk.sh" "$work/app.apk" "$package" "$label" "$version" "" bit all

aapt2 convert --output-format proto -o "$work/proto.apk" "$work/app.apk"
mkdir -p "$work/unpacked" "$work/base/manifest" "$work/base/dex" "$work/base/root"
(cd "$work/unpacked" && unzip -q ../proto.apk)
cd "$work/unpacked"
mv AndroidManifest.xml ../base/manifest/
mv resources.pb ../base/
for dir in res assets lib; do
	[ -d "$dir" ] && mv "$dir" ../base/
done
mv ./*.dex ../base/dex/
# The old APK signature does not belong in the bundle; everything else rides along at root.
rm -rf META-INF
if [ -n "$(ls -A .)" ]; then
	mv ./* ../base/root/
fi
(cd ../base && zip -q -r -D ../base.zip .)
rm -f "$out"
java -jar "$BUNDLETOOL" build-bundle --modules="$work/base.zip" --output="$out"
jarsigner -sigalg SHA256withRSA -digestalg SHA-256 -keystore "$STORE_KEYSTORE" -storepass "$STORE_PASS" "$out" "$STORE_ALIAS" >/dev/null
jarsigner -verify "$out" | tail -1
java -jar "$BUNDLETOOL" validate --bundle="$out" | tail -3
java -jar "$BUNDLETOOL" build-apks --bundle="$out" --output="$work/check.apks" \
	--ks="$STORE_KEYSTORE" --ks-key-alias="$STORE_ALIAS" --ks-pass="pass:$STORE_PASS" >/dev/null
echo "AAB pronto: $out ($(du -h "$out" | cut -f1)); o bundletool gerou os APKs de teste sem erros."
