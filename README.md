# Charge Arena

Jogo de arena 3D em Godot: disparos com ricochete, muralhas destrutíveis, poderes por piloto, campanha, PvP e batalhas 3 contra 3.

Este é o repositório **NEWTOWN-BORGES/charge-arena-new-skin**. A base desta revisão é `a820bad`, da branch `claude/charge-arena-new-skin`, usada na auditoria da versão 3.44.0 LAB; a versão atual é a **3.45.0** (código 74), que junta a atualização heroica 3.44.0 e as batalhas 3 contra 3 desta ramificação. O histórico do projeto antigo está em [docs/archive](docs/archive/README-3.44-original.md).

## Abrir e jogar

1. Instalar **Godot 4.7.1**, versão standard.
2. Importar `project.godot` e aguardar a importação dos recursos.
3. Premir **F5**. O projeto usa o renderizador **Compatibility**, incluindo no Android.

O menu permite escolher PvE/PvP, história, skins e opções. Os três modos de disparo continuam disponíveis: automático, botão separado e toque no joystick. A qualidade gráfica e o limite de FPS são independentes.

## Organização

| Pasta | Responsabilidade |
|---|---|
| `scripts/main.gd` | Sessão, entrada, pausa, rede e ligação dos sistemas |
| `scripts/gameplay` | Regras, colisões, IA e poderes |
| `scripts/presentation` | Arena 3D, robôs, materiais, animação e efeitos |
| `scripts/ui` | HUD, menu, loja, controlos e tutoriais |
| `scripts/story` | Taça, percurso, árvore e jornal |
| `scripts/progression` | Campanha, skins e progressão |
| `scripts/settings` | Preferências de jogo, vídeo e feedback |
| `scripts/audio` | Reprodução de música e efeitos sonoros |
| `art`, `audio`, `shaders`, `scenes` | Recursos usados pelo jogo |
| `tests/regression`, `tests/network` | Verificações de comportamento e PvP entre processos |
| `tests/captures`, `tests/benchmarks` | Capturas no motor e medições de desenvolvimento |
| `tools` | Exportação, produção de recursos e execução dos testes |
| `docs/archive` | Documentação e imagens históricas, fora da importação/exportação |

Os caminhos alterados estão registados em [resource-path-migration.json](docs/resource-path-migration.json). Os UIDs existentes foram preservados. A organização não muda os nomes nem os formatos dos ficheiros de progresso em `user://`.

## Verificar alterações

Com Python 3 e o executável Godot disponível:

```sh
godot --headless --editor --import
python tools/check_resources.py
python tools/run_tests.py --godot godot
python tools/run_tests.py --godot godot --network
```

No Windows, substituir `godot` pelo caminho ou nome do executável, por exemplo `Godot_v4.7.1-stable_win64_console.exe`.

O executor cria cópias em `.qa/` e saves separados em `ChargeArenaQA/`. Não usa o progresso do jogador. Os relatórios JSON e logs ficam em `.qa/`; recursos pesados são ligados localmente para evitar cópias desnecessárias. Os testes de rede executam dois processos locais por caso. Executar a suite de regressão e a de rede **sequencialmente**, com o jogo fechado, para não disputar a porta LAN.

Capturas e testes que leem MultiMesh precisam de um renderizador gráfico; `--headless` não verifica o aspeto final nem mede o desempenho de um telemóvel. Os antigos scripts de captura gravam por omissão em `user://`. `capture_refinement.gd` aceita um prefixo absoluto e `--portrait`, e exige um diretório de saves de QA.

## Android e saves

Os presets são Alfa, Teste e LAB. O LAB usa `org.chargearena.newskinlab`, correspondente aos APK 3.44.0 e 3.45.0; os outros identificadores existentes são preservados. Instalar uma atualização sobre uma app existente exige **o mesmo pacote e a mesma assinatura**. Não desinstalar a app para testar uma atualização se quiser preservar os saves.

O script `tools/export_apk.sh` exporta **o commit atual**, numa pasta temporária, usando o ambiente preparado por `tools/setup_env.sh --android`. Falhas de importação ou exportação interrompem o build. A publicação de uma release continua a ser um passo separado: alterar o código ou os presets não substitui um APK já instalado nem publicado.

As chaves de assinatura, caches, APKs e saves não pertencem ao repositório. Para uma distribuição nova, definir o `VERSION_CODE` apropriado e confirmar pacote, assinatura e versão no manifesto do APK.

Ver [a revisão técnica e visual](docs/MAINTENANCE-3.44.md) para alterações, validação e limites conhecidos.
