# Guia de Proteção, Criptografia e Prevenção de Mods / Clonagem

Este documento descreve as camadas de blindagem implementadas no **Charge Arena** para impedir:
1. **Roubo de código-fonte** e engenharia reversa de scripts GDScript / cenas.
2. **Criação de mods piratas** e modificação de mecânicas ou custos na loja.
3. **Clonagem de APK** e distribuição não autorizada sob outro nome de pacote.
4. **Adulteração de saves locais** (`user://*.cfg`) via editores hexadecimais ou gerenciadores de arquivos.

---

## As 5 Camadas de Segurança Implementadas

### 1. Criptografia AES-256 do PCK e Diretório de Arquivos
- **O que faz:** Todos os recursos (`.gd`, `.tscn`, texturas, áudios) dentro do arquivo `.pck` são cifrados com criptografia simétrica **AES-256**.
- **Criptografia de Diretório (`encrypt_directory=true`):** A tabela de nomes de arquivos também é criptografada. Descompiladores populares como `GDRE Tools`, `gdsdecomp` ou `Unpck` não conseguem nem listar quais arquivos existem dentro do jogo. Sem a chave de 256 bits, a extração resulta em dados ilegíveis.
- **Bytecode Compilado:** Scripts são convertidos em bytecode compilado do Godot antes da criptografia, eliminando comentários e código em texto claro.

### 2. Assinatura Criptográfica de Saves (Anti-Cheat / Anti-Save Mod)
- **Local:** `systems/security/SecurityGuard.gd`
- **O que faz:** Cada vez que o jogo salva o progresso do jogador (`skins.cfg`, `powers.cfg`, `marathon.cfg`), é gerada uma assinatura SHA-256 com sal secreto interno (`SECRET_SALT`).
- **Resultado:** Se um jogador ou modder tentar usar um editor de texto ou aplicativo de mod para colocar `bricks = 999999` ou desbloquear todas as skins no arquivo de save, a assinatura digital é invalidada. Ao iniciar, o jogo detecta a adulteração e descarta os dados manipulados.

### 3. Verificação de Integridade de Pacote (Anti-Clonagem)
- **O que faz:** Valida em tempo de execução se o identificador do aplicativo corresponde aos domínios oficiais registrados (`org.chargearena.game`, `org.chargearena.teste`, `org.chargearena.playtest`, etc.).
- **Resultado:** Se um clonador decompilar o manifesto do Android, alterar o `package_name` para redistribuir em outra loja ou monetizar com anúncios próprios, a camada de segurança detecta a discrepância e bloqueia a inicialização.

### 4. Proteção contra Depuração e Hooking em Produção
- **O que faz:** Em builds destinadas a lojas (Galaxy Store, Google Play), a inicialização com depuradores ativos ou flags de debug (`OS.is_debug_build()`) é rejeitada.
- **Resultado:** Dificulta a injeção de hooks via Frida, Xposed ou depuração remota em tempo real.

### 5. Assinatura Digital Android V2/V3 (Proteção de Binário)
- O APK final é assinado digitalmente com assinatura completa de esquema V2 e V3.
- Qualquer alteração em um único byte do APK (ex: tentar alterar imagens, assets ou bytecode) invalida a assinatura criptográfica do Android, impedindo a instalação ou atualização do APK pelo sistema operacional.

---

## Como Gerar o APK Protegido e Criptografado

### Opção 1: Usando o Script Automatizado (Recomendado)

No terminal, execute:
```bash
py tools/build_protected_apk.py
```

O script automaticamente:
1. Gera uma chave AES-256 segura de 64 caracteres hexadecimais (ou usa a chave informada via `--key`).
2. Configura o preset `Android Protegido` no arquivo `export_presets.cfg`.
3. Salva a chave gerada em `builds/encryption_key.txt`.
4. Executa a exportação release do Godot com PCK e diretório criptografados.

#### Parâmetros Opcionais:
- `--output builds/meu-jogo.apk`: Caminho de saída do APK.
- `--key <CHAVE_64_HEX>`: Usar uma chave específica de 256 bits.
- `--package org.chargearena.game`: Nome do pacote Android.

---

### Opção 2: Exportação Direta via Godot Editor

1. Abra o projeto no **Godot Editor**.
2. Vá em **Projeto > Exportar...**.
3. Selecione o preset **Android Protegido**.
4. Em **Criptografia**, observe que:
   - `Criptografar PCK`: Marcado (Ligado)
   - `Criptografar Diretório`: Marcado (Ligado)
   - `Chave de Criptografia`: Preenchida com a chave de 256 bits (64 hex).
5. Clique em **Exportar Projeto** e salve o APK.

---

## Cuidados Importantes
> [!IMPORTANT]
> **Guarde a sua chave AES-256 (`builds/encryption_key.txt`) em local seguro!**
> Sem esta chave, você não conseguirá depurar eventuais erros em relatórios de crash de versões já distribuídas aos jogadores. Nunca compartilhe a chave de criptografia nem a envie para repositórios públicos.

