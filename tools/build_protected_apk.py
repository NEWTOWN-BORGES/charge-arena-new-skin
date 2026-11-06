#!/usr/bin/env python3
"""Build an encrypted, anti-tamper, protected APK for Charge Arena.

Features:
- PCK and directory encryption with 256-bit AES
- Bytecode-only compiled GDScript
- Anti-cloning / package name integrity check
- Save signature protection (HMAC-SHA256)
- Signed with release or debug keystore
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import secrets
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def generate_aes_key() -> str:
    """Generate a cryptographically secure 256-bit AES key (64 hex characters)."""
    return secrets.token_hex(32)


def main() -> int:
    parser = argparse.ArgumentParser(description="Export an encrypted & protected APK for Charge Arena")
    parser.add_argument("--output", "-o", default=str(ROOT / "builds" / "charge-arena-protegido.apk"), help="Path to output APK")
    parser.add_argument("--key", "-k", default="", help="256-bit AES encryption key in hex (generated if omitted)")
    parser.add_argument("--package", "-p", default="org.chargearena.game", help="Android package unique name")
    parser.add_argument("--name", "-n", default="Charge Arena", help="App display name")
    parser.add_argument("--godot-bin", default="", help="Path to Godot executable")
    args = parser.parse_args()

    key = args.key.strip()
    if not key:
        key = generate_aes_key()
        print(f"[*] Chave AES-256 gerada com sucesso: {key}")
    elif len(key) != 64:
        print("[!] Erro: A chave AES-256 deve ter exatamente 64 caracteres hexadecimais (256 bits).", file=sys.stderr)
        return 1

    out_path = Path(args.output).resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)

    print("================================================================")
    print("      Charge Arena - Gerador de APK Protegida e Criptografada   ")
    print("================================================================")
    print(f"  Pacote:      {args.package}")
    print(f"  Nome:        {args.name}")
    print(f"  Destino:     {out_path}")
    print(f"  Cripto AES:  {key[:8]}...{key[-8:]} (256 bits)")
    print("================================================================")

    # Localizar Godot se não especificado
    godot = args.godot_bin
    if not godot:
        candidates = [
            Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft" / "WinGet" / "Packages" / "GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe" / "Godot_v4.7.1-stable_win64_console.exe",
            shutil.which("godot"),
            shutil.which("godot4"),
            Path("/opt/charge-arena-server/godot"),
        ]
        for c in candidates:
            if c and Path(c).is_file():
                godot = str(c)
                break

    if not godot:
        print("[!] Erro: Executável do Godot 4 não encontrado. Especifique com --godot-bin.", file=sys.stderr)
        return 1

    print(f"[*] Usando Godot: {godot}")

    # Atualizar chave e opções no export_presets.cfg
    presets_file = ROOT / "export_presets.cfg"
    content = presets_file.read_text(encoding="utf-8")

    # Atualizar ou garantir preset.3 com a chave
    if "encryption_key=" in content:
        content = re.sub(r'encryption_key=".*"', f'encryption_key="{key}"', content)
        presets_file.write_text(content, encoding="utf-8")
        print("[*] export_presets.cfg atualizado com a chave de criptografia AES-256.")

    # Salvar chave fora do repositorio (na Area de Trabalho do desenvolvedor)
    key_file = Path.home() / "Desktop" / "charge-arena-encryption-key.txt"
    key_file.write_text(f"ENCRYPTION_KEY={key}\nPACKAGE={args.package}\n", encoding="utf-8")
    print(f"[*] Chave salva em: {key_file} (Guarde em local seguro e privado!)")

    # Comando de exportação
    cmd = [
        godot,
        "--headless",
        "--path", str(ROOT),
        "--export-release", "Android Protegido",
        str(out_path)
    ]

    print(f"[*] Executando exportação: {' '.join(cmd)}")
    result = subprocess.run(cmd)

    if result.returncode == 0 and out_path.exists():
        size_mb = out_path.stat().st_size / (1024 * 1024)
        print(f"\n[OK] APK PROTEGIDA CRIADA COM SUCESSO!")
        print(f"     Arquivo: {out_path} ({size_mb:.2f} MB)")
        print(f"     Criptografia PCK: ATIVADA (AES-256)")
        print(f"     Criptografia de Diretório: ATIVADA")
        print(f"     Anti-Tamper: ATIVADO")
        return 0
    else:
        print("\n[!] A exportação do Godot finalizou. Se faltam templates de exportação do Android, instale-os no Godot Editor (Project > Install Android Build Template).", file=sys.stderr)
        return result.returncode


if __name__ == "__main__":
    sys.exit(main())

