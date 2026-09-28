#!/usr/bin/env bash
# Publica APKs de teste sem o limite de 100 MB do Git.
#
# Uso: tools/publish_apk.sh <LEIA-ME.md> <mensagem> <apk>...
#
# Cada APK é dividida em partes de 90 MB (parts/<apk>.partNN) e enviada, com o LEIA-ME e o
# workflow .github/workflows/publish.yml, para o ramo "apk-teste" (um commit órfão, que
# substitui o anterior). O GitHub Actions junta as partes e publica cada APK inteira na
# Release "apk" (até 2 GB por ficheiro):
#   https://github.com/<dono>/<repo>/releases/download/apk/<nome>.apk
# As APKs com menos de 100 MB ficam também na raiz do ramo, como antes.
set -euo pipefail

readme="$(realpath "${1:?LEIA-ME.md}")"
message="${2:?mensagem do commit}"
shift 2
root="$(git rev-parse --show-toplevel)"
work="$(mktemp -d)"
trap 'rm -r "$work"' EXIT
mkdir -p "$work/parts"

blob() { git -C "$root" hash-object -w "$1"; }

top="$work/top.list"
printf "100644 blob %s\tLEIA-ME.md\n" "$(blob "$readme")" > "$top"
for apk in "$@"; do
	name="$(basename "$apk")"
	split -b 90m -d -a 2 "$apk" "$work/parts/$name.part"
	if [ "$(stat -c %s "$apk")" -lt 99000000 ]; then
		printf "100644 blob %s\t%s\n" "$(blob "$apk")" "$name" >> "$top"
	fi
done
: > "$work/parts.list"
for part in "$work"/parts/*; do
	printf "100644 blob %s\t%s\n" "$(blob "$part")" "$(basename "$part")" >> "$work/parts.list"
done
parts_tree=$(git -C "$root" mktree < "$work/parts.list")
workflow=$(printf "100644 blob %s\tpublish.yml\n" "$(blob "$root/tools/apk_release_workflow.yml")" | git -C "$root" mktree)
dot_github=$(printf "040000 tree %s\tworkflows\n" "$workflow" | git -C "$root" mktree)
printf "040000 tree %s\t.github\n040000 tree %s\tparts\n" "$dot_github" "$parts_tree" >> "$top"
tree=$(git -C "$root" mktree < "$top")
commit=$(printf "%s\n" "$message" | git -C "$root" commit-tree "$tree")

git -C "$root" fetch -q origin apk-teste || true
old=$(git -C "$root" rev-parse -q --verify origin/apk-teste || echo "")
for attempt in 1 2 3 4; do
	git -C "$root" push -q --force-with-lease="refs/heads/apk-teste:$old" origin "$commit:refs/heads/apk-teste" || true
	if git -C "$root" ls-remote origin apk-teste | grep -q "$commit"; then
		echo "Publicado: $commit (o GitHub Actions envia as APKs para a Release \"apk\")"
		exit 0
	fi
	sleep $((2 ** attempt))
done
echo "Falhou o envio para apk-teste" >&2
exit 1
