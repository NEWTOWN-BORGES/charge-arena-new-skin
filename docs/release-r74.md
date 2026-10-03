# Charge Arena 3.44.0 r74 — entrega

2026-10-03 · Repositório NEWTOWN-BORGES/charge-arena-new-skin · branch `codex/3.44-arena-heroica`.

Correção do hangar no PC: botão EQUIPAR acessível após redimensionar e tutorial inicial adiado enquanto o hangar está aberto. Câmara com Vista geral, Vista próxima e 3.ª pessoa, alternância por C, reposição por Home, zoom pela roda do rato e rotação arrastando o botão direito. Rosca e Batida recuperam os desenhos anteriores melhorados; Eclipse recupera o corpo anterior mantendo a cabeça melhorada.

## Artefactos de entrega

Os binários estão na pasta de entrega local `outputs`, fora do código versionado. Caminhos relativos à pasta de trabalho da entrega:

1. **APK LAB** — `outputs/charge-arena-3.44.0-r74-lab.apk`

   154 268 323 bytes (147,12 MiB). SHA256:
   `48d129d1f6b1cd8530080fb44af2660286592e71f6d749d53b7bbbd0966bb701`

2. **APK ALFA** — `outputs/charge-arena-3.44.0-r74-alfa.apk`

   124 994 052 bytes (119,20 MiB). SHA256:
   `f15f229a33ff58007065edb1fe1aae7d006adc18c408ba09de93ea01d17fa948`

3. **Instalador Windows EXE** — `outputs/Charge-Arena-3.44.0-PC-Corrigido-Setup.exe`

   89 952 040 bytes (85,78 MiB). SHA256:
   `dbfafab7f12f746060c0391d641073f90511b3c104d8512c1251599021a3370b`

4. **ZIP portátil Windows (opcional)** — `outputs/charge-arena-3.44.0-pc-corrigido.zip`

   105 812 441 bytes (100,91 MiB). SHA256:
   `02e01e2550b1cae91053eead61257742ef921a904176f878f06e0cb057555a88`

## Verificação

- Android LAB/ALFA: código de versão 74, assinaturas v2/v3 verificadas, mesmo certificado entre variantes. O recurso importado dos robôs é idêntico nos dois APKs e coincide com o cache final do repositório.
- Layout PC: 36 verificações, 0 falhas, incluindo clique real por GUI no EQUIPAR em diferentes tamanhos de janela.
- Tutorial/hangar: 13 verificações, 0 falhas, incluindo clique real no EQUIPAR após o temporizador inicial.
- Câmara PC: 0 falhas; alternância de vistas, terceira pessoa, roda, rato, teclas, persistência e seguimento do piloto PvP verificados.
- Modelos recuperados: teste geométrico no Blender aprovado (`RESTORED_ROBOTS_SMOKE_OK`). GLB final: 4.117.088 bytes.
- PC: exportação Godot 4.7.1 e inicialização do EXE nativo e do PCK com `--headless --quit-after 120` terminaram com código 0. As 11 comparações de fonte/staging conferem.
- Instalador NSIS 3.12: compilação e instalação real com `/TEST /S` numa pasta `work` terminaram com código 0; EXE, PCK, instruções e licenças instalados conferem por SHA256. O modo de teste não cria atalhos nem entradas de desinstalação pessoais.

Não foi feita instalação Android num telemóvel físico. O ambiente emite aviso de certificados; o EXE registou 4 objetos e 2 recursos ainda ativos no encerramento, apesar do código de saída 0.

Evidências da entrega: `outputs/R74-ANDROID-RELEASE.json`, `outputs/R74-VERIFICACAO-LAB.log`, `outputs/R74-VERIFICACAO-ALFA.log`, `outputs/PC-r74-export.log`, `outputs/PC-r74-native-runtime.log`, `outputs/PC-r74-native-stderr.log`, `outputs/PC-r74-pack-smoke.log`, `outputs/PC-r74-installer-build.log`, `outputs/PC-r74-installer-test.log` e `outputs/PC-r74-source-staging.json`.

Resultados GUI/modelos: `work/pc-layout-final.log`, `work/pc-hangar-tutorial-fix.log`, `work/pc-camera-fix.log` e `work/restored-robots-smoke.log`.

## Usar no PC

No PC, C alterna as três vistas; Home repõe a Vista geral. A roda aproxima/afasta; arrastar com botão direito ou do meio ajusta a câmara. Q/E rodam a vista e +/- ajustam o zoom. A/D ou setas movem; clique esquerdo ou Espaço dispara; 1/2/3 ativam habilidades; Esc fecha o painel ou pausa conforme o ecrã.

O instalador inclui o jogo e o PCK separado. Na versão portátil, extraia todo o ZIP e mantenha `ChargeArena.pck` junto de `ChargeArena.exe`. O PC é LAB, com acesso de teste desbloqueado (`open_test`).

