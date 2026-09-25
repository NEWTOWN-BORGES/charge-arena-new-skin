# Direção de arte nova

Este repositório refaz todo o visual do Charge Arena sobre o mesmo código e a mesma lógica de
jogo (regras, IA, poderes, campanha, Taça, PvP). O trabalho está dividido em fases:

| Fase | Conteúdo | Estado |
|---|---|---|
| 1 | Elenco de robôs: modelos, rostos, nomes, retratos | feito |
| 2 | Arenas, muralhas, balizas e cenário | feito |
| 3 | Disparos, poderes, partículas e explosões | feito |
| 4 | Luz, atmosfera e interface | interface feita; luz por ambiente a seguir |
| 5 | Banda sonora | por fazer |

## Estilo

Robôs *chibi* de cabeça-ecrã: uma cabeça grande em forma de televisor com o rosto desenhado num
ecrã escuro, cantos e painéis laterais na cor de acento, corpo em placas, punhos e pés grandes de
brinquedo. As placas usam sombreado *toon* suave, um brilho de contorno frio, uma linha de tinta
à volta e pintura gasta nas arestas vivas (calculada no shader a partir da curvatura). Cada robô
tem dois tons fortes, luzes da sua cor, uma silhueta própria no topo da cabeça (antena, folhas,
chifres, orelhas de gato, capuz, espigões...) e um tipo de corpo e de pernas (normais, pesadas,
de pássaro, rodas, lagartas ou propulsor). As peças na cor da equipa (faixas
nos ombros, no cinto e no braço) mostram de que lado está cada um.

## Elenco

Os ultimates, os níveis dos bosses e as regras não mudaram. Mudaram o nome, o modelo, as cores e
a descrição.

| # | Nome | Antes | Ultimate | Assinatura |
|---|---|---|---|---|
| 0 | BIT | Piloto Aurora | — | creme e cor da equipa, antena, sorriso, canhão de braço |
| 1 | SALVO | Faroleiro | volley | azul-marinho e laranja, cabeça larga com pega, lança-mísseis, cano duplo |
| 2 | ÓRBITA | Astrónomo | meteors | roxo, parabólica, anel planetário, asas, flutua num propulsor |
| 3 | BROTO | Jardineiro | bloom | verde, folhas como orelhas, corpo redondo, rodas, semeador |
| 4 | BIGORNA | Mineiro | plating | amarelo e preto, cabeça-visor, pirilampo, lagartas de tanque, broca |
| 5 | ECLIPSE | Sentinela | singularity | preto e vermelho, chifres, espigões, pernas de pássaro, garra, halo |
| 6 | ROSCA | Relojoeiro | sentries | cobre, óculos de soldador, olho de lupa, garra, rodas |
| 7 | FAÍSCA | Caça-Trovões | thunder | branco e azul, espigões de raio, pernas de pássaro, bobina |
| 8 | BATIDA | Alquimista | surge | rosa, orelhas de gato, auscultadores gigantes, megafone |
| 9 | GANCHO | Corsário | plunder | capuz, capa rasgada, olho único, bacamarte com gancho |
| 10 | HÉLIO | Arconte Solar | sun_ray | marfim e ouro, coroa de raios, asas, núcleo solar, cetro |
| 11 | MAGNUS | Aurel | b_forge | azul-real e ouro, louros, capa de campeão, maior que todos |

Os 50 pilotos de estrada (skins 100-149) combinam 5 cabeças, 10 topos e 5 famílias de chassis,
todos diferentes entre si. Os saves com os nomes antigos continuam a funcionar
(`cup_tree_data.gd`, `LEGACY_NAMES`).

## Arenas

Cada mapa pertence a um de seis ambientes (`scripts/arena_theme.gd`): Arena Aurora, Cidade Alta,
Fábrica Orbital, Canyon Vermelho, Base Gelada e Floresta Mecânica. O ambiente pinta o chão de
hexágonos (`shaders/court.gdshader`), o céu de fim de tarde com estrelas e feixes de holofote
(`shaders/backdrop.gdshader`), a muralha exterior de blocos blindados em dois tons com uma faixa
de néon da equipa, as bancadas com público, as torres de luz e as bandeiras
(`scripts/arena_dressing.gd`), os aceleradores e as barreiras. Os pilotos de estrada (`posto_*`)
percorrem os ambientes por ordem.

Os tijolos são caixotes blindados do kit (`brick_crate`) nas cores do robô que os defende, com a
tampa na cor da equipa e o topo do robô em miniatura. Os do BIT e dos pilotos de estrada são
baterias na cor da equipa. Os obstáculos são pilões hexagonais com faixas de perigo e uma tampa em
estrela que gira; as balizas têm postes do kit.

## Interface

- **Lobby** (`scripts/lobby.gd`): perfil do piloto e progresso da campanha no topo, carteira de
  tijolos e opções à direita; na coluna da esquerda Hangar, Poderes, História e PvP; ao centro o
  teu piloto em 3D, virado para ti, com a câmara a balançar devagar e a arena do nível com o boss
  ao fundo (desliza ou usa as setas para mudar de nível); em baixo a doca com a
  dificuldade da IA, o cartão do modo (com o boss do nível) e o botão JOGAR. Tocar no cartão abre
  a folha dos modos: Campanha, Jogo Rápido, Modo História e PvP.
- **Kit** (`scripts/ui_kit.gd`): paleta índigo noturna, um só amarelo-sol para a ação principal,
  menta para opções escolhidas e as cores das equipas para tudo o que pertence a um lado. Teclas
  "de brinquedo" com lábio que afunda ao carregar. Tipos de letra livres (OFL, `art/fonts/`):
  Lilita One nos títulos e teclas, Rubik no texto.
- **HUD de jogo**: cartões com a borda na cor da equipa, barras de muralha com brilho,
  marcador, contagem num mostrador, faixa de GOLO / VITÓRIA com a cor do momento, aviso de baliza
  desprotegida a vermelho e notificação de desbloqueio com a etiqueta NOVO!.
- **Desempenho**: as formas do HUD saem todas de um atlas gerado no arranque e o texto é desenhado
  no fim, agrupado por tipo de letra e tamanho; os símbolos dos poderes são pintados uma vez numa
  folha. O HUD passou de ~150 para ~30 draw calls por frame.

## Como funciona

- `tools/blender/robot_kit.py` modela 68 peças em Blender e escreve `art/robots/kit.glb`. Cada
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
