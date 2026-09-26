# Direção de arte nova

Este repositório refaz todo o visual do Charge Arena sobre o mesmo código e a mesma lógica de
jogo (regras, IA, poderes, campanha, Taça, PvP). O trabalho está dividido em fases:

| Fase | Conteúdo | Estado |
|---|---|---|
| 1 | Elenco de robôs: modelos, rostos, nomes, retratos | feito |
| 2 | Arenas, muralhas, balizas e cenário | feito |
| 3 | Disparos, poderes, partículas e explosões | feito |
| 4 | Luz, atmosfera e interface | feito: estilo estúdio no jogo todo |
| 5 | Banda sonora | por fazer |
| 6 | Robôs v2 (kit mecânico) | BIT feito; os outros 11 e os pilotos de estrada a seguir |

## Estilo estúdio (atual)

O jogo inteiro segue o render do BIT v2 feito no Blender: suave e polido, como uma sessão de
fotografia de estúdio.

- **Materiais** (`shaders/robot_paint.gdshader`): pintura lisa semi-mate com reflexos largos nos
  biséis, chassis grafite, juntas em metal polido, borracha mate e sensores com luz. Sem linha de
  tinta nem sujidade. O perfil Leve usa `robot_paint_low.gdshader`, com a mesma luz calculada a
  partir da normal.
- **Luz** (`scripts/arena_finish.gd`): uma cúpula cinzenta neutra dá a luz ambiente e os reflexos,
  uma luz principal quente vem de cima à esquerda e um enchimento frio e fraco vem de trás. O
  tonemapping é AgX, o mesmo do Blender.
- **Fundo** (`shaders/backdrop.gdshader`): um ciclorama claro com um gradiente suave e vinheta.
- **Arenas** (`scripts/arena_theme.gd`): chão de placas mate claras com juntas suaves e marcações
  pintadas, sem néon. As seis cores dos ambientes são tons pastel da mesma luz. O Leve ilumina por
  vértice.
- **Sombras**: um disco de contacto suave debaixo de cada piloto.
- **Interface** (`scripts/ui_kit.gd`): placas claras com sombra suave, texto em tinta escura e o
  amarelo só na ação principal. Os nomes da paleta mantêm o papel: `WHITE` é a cor do texto
  principal e `PANEL` a das placas.
- **História**: a banca da Rosa, as fotografias do jornal e os ecrãs do hub usam a mesma luz e a
  mesma paleta.

## Estilo anterior (robôs v1)

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

Os tijolos seguem o tema do robô que defende a muralha (`brick` em `art/robots/roster.json`,
peças `brick_*` do kit): baterias do BIT, caixas de munição do SALVO, observatórios da ÓRBITA,
canteiros do BROTO, bigornas da BIGORNA, monólitos do ECLIPSE, engrenagens do ROSCA, bobinas de
Tesla da FAÍSCA, colunas de som da BATIDA, arcas do GANCHO, obeliscos solares do HÉLIO e emblemas
do MAGNUS. Usam as cores do robô, mas a faixa da base, a tampa ou as luzes ficam sempre na cor da
equipa, para se ler de relance de quem é cada muralha. Os pilotos de estrada defendem baterias na
cor da equipa.
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
