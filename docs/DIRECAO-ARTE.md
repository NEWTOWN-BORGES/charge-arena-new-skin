# Direção de arte nova

Este repositório refaz todo o visual do Charge Arena sobre o mesmo código e a mesma lógica de
jogo (regras, IA, poderes, campanha, Taça, PvP). O trabalho está dividido em fases:

| Fase | Conteúdo | Estado |
|---|---|---|
| 1 | Elenco de robôs: modelos, rostos, nomes, retratos | feito |
| 2 | Arenas, muralhas, balizas e cenário | por fazer |
| 3 | Disparos, poderes, partículas e explosões | por fazer |
| 4 | Luz, atmosfera e interface | por fazer |
| 5 | Banda sonora | por fazer |

## Estilo

Robôs *chibi* de cabeça-ecrã: uma cabeça grande em forma de televisor com o rosto desenhado num
ecrã escuro, corpo pequeno em placas, articulações escuras e pés mecânicos. As placas usam
sombreado *toon* suave, um brilho de contorno frio e uma linha de tinta à volta. Cada robô tem
uma cor principal forte, uma cor de acento e luzes da sua cor. As peças na cor da equipa (faixas
nos ombros, no cinto e no braço) mostram de que lado está cada um.

## Elenco

Os ultimates, os níveis dos bosses e as regras não mudaram. Mudaram o nome, o modelo, as cores e
a descrição.

| # | Nome | Antes | Ultimate | Assinatura |
|---|---|---|---|---|
| 0 | BIT | Piloto Aurora | — | antena, olhos em cápsula e sorriso, canhão de braço |
| 1 | SALVO | Faroleiro | volley | pega de transporte, casulo de mísseis, cano duplo |
| 2 | ÓRBITA | Astrónomo | meteors | parabólica, anel planetário a girar, luneta |
| 3 | BROTO | Jardineiro | bloom | rebento, vaso às costas, rodas, semeador |
| 4 | BIGORNA | Mineiro | plating | cabeça larga, ombreiras em bloco, faixas de perigo, broca |
| 5 | ECLIPSE | Sentinela | singularity | chifres, halo de eclipse a girar, lança de anel |
| 6 | ROSCA | Relojoeiro | sentries | olho de lupa, caixa de ferramentas, rebitadora |
| 7 | FAÍSCA | Caça-Trovões | thunder | para-raios, bobina, visor de varrimento |
| 8 | BATIDA | Alquimista | surge | crista de néon, colunas nos ombros, megafone |
| 9 | GANCHO | Corsário | plunder | capuz, capa, olho único, bacamarte |
| 10 | HÉLIO | Arconte Solar | sun_ray | coroa de raios a girar, cetro solar |
| 11 | MAGNUS | Aurel | b_forge | louros a girar, capa de campeão, manopla imperial |

Os 50 pilotos de estrada (skins 100-149) combinam 5 cabeças, 10 topos e 5 famílias de chassis,
todos diferentes entre si. Os saves com os nomes antigos continuam a funcionar
(`cup_tree_data.gd`, `LEGACY_NAMES`).

## Como funciona

- `tools/blender/robot_kit.py` modela 50 peças em Blender e escreve `art/robots/kit.glb`. Cada
  peça tem uma malha por papel de cor: `shell`, `trim`, `dark`, `metal`, `glow`, `team` e
  `screen`.
- `art/robots/roster.json` diz que peças e que cores tem cada robô. As cores vazias seguem a cor
  da equipa.
- `scripts/robots.gd` monta o robô no Godot: junta as peças por papel em cada grupo que se mexe
  (corpo, pernas, arma, crista giratória), cria o contorno e liga o ecrã do rosto.
- `shaders/robot_face.gdshader` desenha os olhos (12 estilos), o piscar e as expressões: calmo,
  contente e atordoado (quando o robô está paralisado).
- `shaders/robot_paint.gdshader` é a pintura; `robot_paint_low.gdshader` é a versão do perfil
  Leve, que também esconde o contorno.
- `tools/render_portraits.gd` renderiza os retratos do HUD a partir dos modelos reais
  (`art/robots/portraits/`).

## Comandos

```sh
tools/setup_env.sh --android                      # Godot, Blender e ferramentas Android
python3 tools/blender/robot_kit.py                # reescreve o kit
godot --headless --import                         # reimporta
godot -s tools/render_portraits.gd                # retratos (precisa de GPU)
godot -s tests/capture_cast.gd -- elenco.png      # folha do elenco no jogo
tools/export_apk.sh teste.apk                     # APK de teste (arm64)
```
