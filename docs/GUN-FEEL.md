# Gun feel e feedback de combate

Passe de sensação do disparo: fazer com que TOQUE → KRAK → FSHH → THOCK (→ CRACK) funcione
sozinho, sem mexer no balanceamento, no PvP nem nas ultimates.

## 1. Auditoria: o fluxo do tiro

```
INPUT            hud (toque, stick, botão TIRO) / teclado / auto-disparo
  ↓              main.local_command()  →  {move, fire, tap, power}
FIRE REQUEST     arena_rules.step(): cooldown <= 0 e fire  →  shoot()
  ↓              cadência FIRE_INTERVAL 0,42 s (0,21 s com Sobrecarga)
PROJECTILE SPAWN spawn_ball(): bola a 0,64 à frente do piloto, 15,5 u/s
  ↓              evento "shot"
PROJECTILE TRAVEL advance_ball(): varrimento contínuo, até 8 sub-passos por tick
  ↓
COLLISION        parede / pilão / acelerador → evento "bounce" | "boost" | "spent"
  ↓              tijolo → damage_brick(); piloto → "player_hit"; espelho → "mirror"
DAMAGE           evento "brick_hit" (vida > 0) com heading, soaked (escudo), bite
  ↓
DESTRUCTION      evento "brick" (vida 0); "defense_open" quando cai o último
  ↓
GOAL             bola atravessa a baliza aberta → evento "goal", fase "goal"
```

**Determinístico (autoridade do anfitrião, não se toca):** `arena_rules.gd` inteiro, ou seja
cadência, velocidade, ricochete, colisões, dano, vidas dos tijolos, abertura da baliza e golo.
O cliente PvP recebe os mesmos eventos com cada estado.

**Apresentação (livre para afinar):**
- `main.play_events()` lê `rules.events` e distribui para som, háptica e câmara;
- `indie_arena_view.gd` trata o recuo da arma, o clarão, o projétil e o rasto, as faíscas e os
  pedaços, os tijolos a saltar e o abanão da câmara;
- `fx.gd` são as partículas GPU;
- `game_hud.gd` trata o botão e os avisos.

Tudo isto corre igual no anfitrião e no cliente, a partir dos eventos.

**Latência:** o toque fica guardado até ao tick de física seguinte (≤ 16,7 ms a 60 Hz). O evento
"shot" é tratado nesse mesmo tick: o som toca e o recuo arranca. O projétil aparece no frame de
desenho seguinte. Não há animação de antecipação a atrasar a bala.

**Estado antes deste passe:**
- **Tiro:** recuo só na arma, sem corpo; clarão = uma esfera a encolher mais 2-4 lascas; um
  único ficheiro de som por skin, com 3 variantes e sem variação de tom.
- **Impacto:** faíscas radiais iguais para tudo; o material só mudava o som (pilão = "metal").
- **Tijolos:** encolhem com a vida, mas não há estado "prestes a cair".
- **Destruição:** pedaços mais fumo, sem pausa nem direção.
- **Câmara:** um só abanão aleatório (`shake(power)`), sem direção nem hierarquia.
- **Vibração:** existe, mas só em alguns eventos; o tiro próprio não tinha categoria.
- **Botão TIRO:** encolhe a 93 % e volta, sem indicação da cadência.

## 2. O que muda (só apresentação)

Nada em `arena_rules.gd` mudou: cadência, velocidade, ricochete, dano, vidas e golo são os
mesmos, e o PvP continua a decidir tudo no anfitrião. O cliente apresenta os mesmos eventos.

O evento **"shot" é o `weapon_fired`**. Em `main.play_events()` todas as camadas respondem-lhe no
mesmo tick de física: som, recuo, clarão, câmara, botão e vibração. O gameplay dispara; o
feedback escuta.

### 3. Sistemas alterados

| Momento | Antes | Depois |
|---|---|---|
| **Tiro: som** | um ficheiro por skin (3 variantes) | quatro camadas por tiro: KRAK de ataque (~1 ms), WHUMP grave com oitava, a energia da skin com os agudos domados e a cauda da sala; tom ±2,5 % e nível ±0,8 dB a cada disparo |
| **Tiro: recuo** | só a arma, curva simples | a arma salta num frame, segura 50 ms, volta em 150 ms com um pequeno passo além e assenta; o corpo recua ~4 cm e inclina |
| **Tiro: clarão** | esfera a encolher e 2-4 lascas em nós | núcleo branco (2-4 frames), brilho na cor da skin um pouco à frente, um traço na linha de tiro e faíscas num cone estreito, tudo em partículas GPU |
| **Tiro: luz** | até 8 luzes de impacto | uma lâmpada de 50 ms só no Refinado de computador; no telemóvel as partículas fazem esse papel |
| **Impacto** | faíscas radiais iguais | linguagem por material: tijolo = THOCK (clarão, pó, lascas para trás); pilão metálico = TANG (faíscas a raspar no sentido do ressalto); escudo = BWOM (onda e brilho); parede = toque seco; ricochete = TZZIP curto |
| **Tijolo atingido** | salto fixo | o salto cresce com o desgaste; com uma vida, o tijolo solta faíscas de vez em quando ("mais um tiro e cai") |
| **Tijolo destruído** | pedaços e fumo | THOCK e, 28 ms depois, CRACK; clarão, pedaços atirados no sentido do tiro, anel de pó, fumo, hit-stop visual de 28 ms e abanão pequeno com direção |
| **Último tijolo** | anel e som | hit-stop de 55 ms, depois onda de energia na baliza, faíscas, anel e som grave: "agora posso marcar" |
| **Golo** | 5 rajadas e um abanão forte | hit-stop de 90 ms, efeitos em câmara lenta (45 %) durante 0,55 s, o abanão mais forte do jogo virado para a baliza, onda, estrela, faíscas, brasas, luz, explosão sob o sino e a vibração mais forte |
| **Câmara** | um abanão aleatório | abanões por camadas (intensidade, duração, frequência, decaimento) com direção; 7 níveis de hierarquia |
| **Vibração** | alguns eventos | por categoria: tiro (só no disparo manual, nunca contínua), destruição, poder, ultimate, último tijolo, golo |
| **Botão TIRO** | 93 % e volta | 94 % logo ao toque → 103 % → 100 % em 160 ms; anel de recarga e pulso quando fica pronto |
| **Ultimates** | ducking de −4,5 dB | ducking afinável (−7 dB, 180 ms); sons e efeitos de cada ultimate intocados |

### 4. Parâmetros (`scripts/game_feel.gd`, painel LAB)

- **Recuo:** `fire_recoil_strength`, `fire_recoil_peak`, `fire_return_duration`, `fire_body_kick`.
- **Clarão e rasto:** `muzzle_flash_duration`, `muzzle_flash_size`, `muzzle_spark_amount`,
  `trail_length`.
- **Impacto e destruição:** `impact_flash_size`, `impact_particle_amount`,
  `destruction_particle_amount`.
- **Hit-stop:** `hitstop_destroy`, `hitstop_last_brick`, `hitstop_goal`.
- **Câmara:** `camera_fire_strength`, `camera_impact_strength`, `camera_destroy_strength`,
  `camera_power_strength`, `camera_ultimate_strength`, `camera_last_brick_strength`,
  `camera_goal_strength`.
- **Vibração:** `haptic_fire_ms` e `_strength`, `haptic_destroy_*`, `haptic_power_*`,
  `haptic_goal_*`.
- **Som:** `audio_pitch_variation`, `audio_volume_variation`, `ultimate_duck_db`,
  `ultimate_duck_seconds`.

Na versão LAB: **Opções → AFINAR SENSAÇÃO (LAB)**. Cada deslizador muda já o próximo tiro;
GUARDAR grava em `user://game_feel.cfg` e REPOR volta aos valores de origem.

### 5. Opções para o jogador

- **Impacto da câmara:** Desligado / Suave / Completo (já existia; passa a controlar os abanões
  novos).
- **Vibração:** ligada ou desligada (já existia).
- **Intensidade dos efeitos:** Completa ou Reduzida (nova). Reduzida corta 40 % das partículas e
  todas as luzes, mantendo a hierarquia. Não há flashes intermitentes em nenhum perfil.

### 6. Perfis gráficos

- **Todos:** mantêm TIRO → IMPACTO → DESTRUIÇÃO.
- **Leve:** 50 % das partículas e sem luzes.
- **Equilibrado:** 80 % das partículas.
- **Refinado:** efeitos completos, com uma lâmpada no tiro apenas no computador.

### 7. Assets

- Nenhum ficheiro novo: os sons são refeitos por `tools/master_combat_audio.py` a partir das
  gravações de cada skin.
- A energia acima de 5 kHz caiu entre 60 e 70 % nos tiros, contra a fadiga auditiva, com o
  mesmo ataque (~1 ms).

### 8. Desempenho

- O tiro deixou de criar nós: o clarão e as lascas passaram para os lotes GPU que já existiam.
- As draw calls por frame ficam iguais (141 no Refinado no benchmark).
- O ganho grande desta ronda vem da correção de FPS feita antes:
  - MSAA 4× em vez de 8×;
  - sem brilho (glow) e com no máximo uma luz de impacto no telemóvel;
  - ajuste automático que recupera os FPS em vez de ficar preso.

### 9. Ferramentas de teste

- `tests/capture_feel.gd`: película tiro → impacto → quebra → defesa aberta → golo, vista da
  câmara de jogo.
- `tests/benchmark_frame.gd -- 2 lights=N`: custo por perfil, com e sem luzes de impacto.

### 10. Por verificar no telemóvel

- **Tamanhos:** clarão e impacto; a câmara de jogo é pequena num telemóvel e o simulador de
  software não mostra bem o brilho aditivo.
- **Hit-stop:** confirmar que 28 / 55 / 90 ms não parecem soluços.
- **Vibração:** as durações variam muito entre telemóveis.
- **Som:** repetir 3 minutos de tiro e confirmar que não cansa.
- **Teste cego:** perguntar "Como sentiste o disparo?" e "Qual foi o momento mais satisfatório?".

## 11. Revisão 3.2.1: tijolos mais leves (desempenho no telemóvel)

Depois de testar num Galaxy S23 ainda havia quedas de FPS. A destruição de tijolos, o evento
mais frequente de uma partida, passou a um efeito simples:

- **Tijolo atingido:** um clarão curto.
- **Tijolo destruído:** um clarão e um anel no chão (duas partículas). Saem os pedaços, as
  faíscas, o fumo e os cartões transparentes, que eram uma draw call por tijolo.
- **Tijolos com uma vida:** deixam de soltar faíscas.
- **Rasto dos projéteis:** um brilho por frame no Leve e no Equilibrado (dois só no Refinado).
- **Luzes de impacto:** nenhuma no telemóvel. A primeira luz a tocar num material obrigava o
  renderizador GL a compilar essa variante a meio da partida.
- **Aquecimento de shaders:** durante a contagem de cada partida desenham-se amostras invisíveis
  dos materiais dos efeitos e de um projétil, para nada compilar a meio do jogo (adaptado do
  repositório 3.1).

## 12. Revisão 3.2.2: o HUD deixa de pesar

Capturas num Galaxy S23: 30 FPS no Refinado com alvo de 90 e, no Equilibrado, alvo de 30 com
quedas durante os poderes, sobretudo a metralhadora.

**A causa:** o HUD voltava a pintar o botão REPETIR 30 vezes por segundo, com caixas de estilo
novas de cada vez. Cada pintura é uma mudança de tema, e cada mudança de tema obriga todo o
ecrã a refazer o layout. Só isso custava ~35 ms por atualização no processador de teste, mais
do que o resto do frame junto.

**As correções:**

- **Botões:** `UiKit.key_styles()` constrói as caixas uma vez por tipo e `paint_key()` só pinta
  quando o tipo muda. No teste headless, o jogo passa de ~22 FPS para os 90 do limite, com e sem
  metralhadora (`tests/benchmark_powers.gd`).
- **Ajuste automático no Equilibrado e no Refinado:**
  - espera 3 s de quedas, e não um instante de poder, antes de baixar alguma coisa;
  - desce mais a resolução antes de tocar no limite de FPS (até 66 % no Equilibrado e 72 % no
    Refinado);
  - só desce para 30 FPS se o telemóvel nem chegar aos 36;
  - recupera mais cedo.
