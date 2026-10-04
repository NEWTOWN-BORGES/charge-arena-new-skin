# Charge Arena: plano de implementação de analytics e localização

Fase 1, análise do projeto. Escrito antes de qualquer alteração ao jogo. Nenhum ficheiro do jogo foi modificado para produzir este documento.

- Base analisada: `claude/charge-arena-new-skin` @ `96b9819`. É igual a `main` (`5e140ba`) mais a numeração 3.45.0.
- Data: 4 de outubro de 2026.

---

## 0. Resumo

O Charge Arena **não tem**, à data, nenhum destes sistemas:

| Sistema | Estado |
|---|---|
| Analytics | Inexistente |
| Monitorização de erros | Inexistente |
| Identificador de jogador | Inexistente |
| Pedidos HTTP | Inexistentes |
| Plugins Android | Inexistentes (o export usa os modelos oficiais, sem Gradle) |
| Autoloads | Inexistentes |
| Localização | Inexistente: todo o texto está em português, escrito diretamente nos scripts |

A proposta assenta em cinco escolhas:

1. **Uma camada própria de analytics em GDScript.** Há um `AnalyticsManager` (autoload) e uma interface `AnalyticsProvider`. O primeiro fornecedor real é o **PostHog Cloud (região UE)**, através da sua API HTTP.
   - O PostHog não precisa de SDK nativo nem de Gradle.
   - Funciona igual no Android e no PC.
   - Calcula DAU/WAU/MAU, retenção D1/D7/D30, funis e painéis partilháveis.
   - A chave de projeto do PostHog serve só para enviar eventos (é pública por definição).
   - O Firebase/Crashlytics fica preparado como segundo fornecedor, mas exige Gradle e `google-services.json` (ver §8).
2. **Monitorização de erros em GDScript.** Usa a classe `Logger` do Godot 4.7, com `OS.add_logger`, e deteção de fecho anormal na sessão seguinte.
   - Erros de script e do motor ficam com contexto (cena, modo, mapa, personagem).
   - Crashes nativos com stack trace exigem um SDK nativo (Sentry ou Crashlytics). Fica documentado como ação futura, não escondido.
3. **ID anónimo (UUID v4)**, gerado localmente com `Crypto`. Não usa nenhum identificador do aparelho.
4. **Consentimento separado por finalidade**: estatísticas de jogo, relatórios de erros, publicidade e marketing. As duas últimas ficam sempre desligadas, porque não existem.
5. **Localização nativa do Godot** (CSV para `.translation`) em pt, en, fr, es e it. O texto passa a usar chaves `tr("CHAVE")`.

O volume de texto foi medido: cerca de **1 950 literais, 1 470 únicos e cerca de 10 800 palavras**. Uma parte não é texto visível (nomes de nós, metadados). Cerca de **3 700 palavras** pertencem à Taça Aurora, um modo que existe no código mas **não está acessível no lobby** (ver §1.6). A proposta é traduzir em duas ondas (§9).

---

## 1. Sistemas encontrados

### 1.1 Motor e projeto

| Item | Encontrado |
|---|---|
| Motor | **Godot 4.7.1** stable, `GL Compatibility` também no Android |
| Linguagem | GDScript apenas (sem C#) |
| Cena principal | `res://scenes/main.tscn`, com um único nó `Node3D` e `scripts/main.gd` |
| Autoloads | **Nenhum.** Não há GameManager nem SaveManager; `main.gd` (2 242 linhas) é o orquestrador |
| Padrão de módulos | `preload()` de scripts `RefCounted` como constantes (sem `class_name`) |
| Pastas | `scripts/{audio,gameplay,presentation,progression,settings,story,ui}`, `shaders/`, `art/`, `audio/`, `tests/{regression,captures,benchmarks,network}`, `tools/`, `docs/`. `docs`, `tests` e `tools` têm `.gdignore` |
| Testes | `tools/run_tests.py`. Espelha `scripts scenes shaders art audio tests .godot` num projeto descartável por teste e falha se a saída tiver `ERROR:` ou `SCRIPT ERROR:` |
| Export Android | `tools/export_apk.sh` (exporta o `HEAD` numa pasta temporária, importa e assina) e `export_presets.cfg` (presets Alfa, Teste e LAB, versão **3.45.0 / código 74**, `gradle_build=false`, permissões `INTERNET` e `VIBRATE`) |
| Variantes | LAB = feature `open_test` (tudo desbloqueado); ALFA = progressão normal. Pacotes publicados nos links: `org.chargearena.newskinlab` e `org.chargearena.newskinalfa` |
| Plugins e addons | Nenhum (`addons/` e `android/` não existem) |
| Firebase, analytics, HTTP | Nenhum (`grep` a `firebase`, `analytics`, `posthog`, `sentry`, `HTTPRequest`, `TranslationServer` e `tr(` não encontra nada) |

Verificado no motor desta máquina: `Logger`, `OS.add_logger`, `ScriptBacktrace`, `Crypto.generate_random_bytes`, `HTTPRequest` com threads e `TranslationDomain` estão todos disponíveis. **Não existe** `OS.get_installer_package_name`, por isso a loja de origem não pode ser lida sem código Android nativo (§8, Fase 34).

### 1.2 Orquestração: `scripts/main.gd`

| Função | Linha | Papel |
|---|---:|---|
| `_ready()` | 112 | Cria a arena, o HUD e a música; carrega todos os saves; liga todos os sinais do HUD |
| `start_pve(layout)` | 291 | Jogo rápido (mapa `torre`/`torre_<mundo>`), Coliseu contra a IA, 3 contra 3 e arena de teste |
| `start_pvp_ai()` | 317 | Coliseu (`pvp_map`) contra a IA |
| `start_squad(watch)` | 320 | 3 contra 3 (`esquadrao`): `watch=true` vê as 6 IA; `false` joga como líder azul |
| `start_level(i)` | 350 | Modo ARENAS (campanha livre), `Campaign.LEVELS[i]` |
| `start_story(step, hard, talk)` | 635 | Modo história: conversa e depois `begin_story` |
| `begin_training()` / `finish_training()` | 676 / 710 | Capítulo 3: partida de treino com a BATIDA (é o tutorial da partida) |
| `begin_story(step, hard)` | 724 | Partida contra o chefe da ronda |
| `finish_story()` | 770 | Resultado, desbloqueio de skin e conversa pós-partida |
| `finish_level()` | 825 | Fim de partida em campanha ou história (chamado quando `phase` passa a `finished`) |
| `start_cup()` / `finish_cup()` | 2139 / 2174 | Taça Aurora (inacessível, §1.6) |
| `host_game()` / `join_game(ip)` | 944 / 973 | PvP em rede local (ENet, porta 27940) |
| `peer_connected` / `joined_server` / `peer_disconnected` | 997–1019 | Ligação e desligação |
| `return_to_menu(msg)` | 873 | Saída de qualquer modo, incluindo **abandono** a meio de partida |
| `replay()` | 1023 | Revanche (nova partida) |
| `pause_pve` / `resume_pve` | 908 / 917 | Pausa |
| `_notification` | 926 | `APPLICATION_PAUSED` / `RESUMED` para `go_background(away)`; `WM_CLOSE_REQUEST`; voltar atrás |
| `go_background(away)` | 1905 | Segundo plano: pausa, guarda e desativa o processamento |
| `_physics_process` | 1719 | Passo das regras (`rules.step`), IA e rede; consome `rules.events` |
| `play_events()` | 1404 | Despacha cada evento das regras para som e efeitos (**ponto de agregação de combate**) |
| `_process` | 1958 | Deteta mudanças de `rules.phase` (`goal`, `finished`) e mede FPS a cada 0,5 s (`video.adapt`) |
| `bank_bricks()` | 1106 | **Economia:** tijolos partidos entram na carteira (`power_shop.add_bricks`) |
| `buy_power` / `equip_power` | 1124 / 1131 | **Loja:** comprar e equipar habilidade |
| `select_skin(i)` | 1097 | **Hangar:** vestir skin (personagem) |
| `preview_skin_music(i)` | 2232 | Pré-visualização de skin no Hangar (sinal `skin_previewed`) |
| `tutorial_done(kind, skipped)` | 1892 | Fim de tutorial (`lobby`, `match`, `shop`) |
| `change_*` | 1267–1394 | Definições (dificuldade, mira, sensibilidade, áudio, vídeo...) |

Variáveis de estado relevantes:
- `mode`: `menu`, `pve`, `host` ou `client`.
- `local_team`.
- `level_index`.
- `story_run`: `{step, hard, boss, training}`.
- `cup_active`.
- `backgrounded`.
- `rules.phase`: `countdown`, `play`, `goal` ou `finished`.
- `rules.winner`.
- `rules.scores`.

### 1.3 Regras e combate: `scripts/gameplay/arena_rules.gd` (3 192 linhas)

- **Autoridade da simulação.** `step(dt, commands)` produz `events: Array`, com cerca de 50 tipos, por exemplo:
  - disparo e trajetória: `shot`, `bounce`, `boost`, `spent`;
  - tijolos: `brick`, `brick_hit`;
  - pilotos: `player_hit`, `stun`;
  - golos: `goal`;
  - poderes: `power`, `power_ready`, `ultimate_charge`, `ultimate`.
- Estes eventos são a fonte natural das métricas de partida: **agregar localmente e enviar um resumo no fim** (Fase 38).
- **Vitória.** `WIN_SCORE = 2` golos. A baliza só abre quando a muralha inteira cai. Ganha quem chega primeiro a 2 golos.
- **"Morte".** Não há morte nem *respawn*. O piloto tem 5 vidas; a 0 fica **atordoado** 0,5 s (evento `stun`) e recupera. O equivalente honesto a *kill/death* é **derrubar o piloto rival / ser derrubado**.
- **Atribuição de dano.** Hoje os eventos `brick` e `player_hit` não dizem que poder causou o dano.
  - A bala tem `power` (1 explosão, 2 metralha, 3 leque, 4 certeiro, 5 e 7 fragmentação, 6 ricochete).
  - As ultimates passam por `ultimate_blow`.
  - Para responder "que poder causa mais dano/derrubes" é preciso juntar um campo **`src`** (e `by`, o piloto) aos eventos de dano. É só metadado: **não muda mecânica** (§5, risco R3).
- **3 contra 3** (`squad`): 6 pilotos (0 e 1 líderes, 2 a 5 alas); `caster` diz quem lançou o poder; `squad_command(i)` é a IA.

### 1.4 Personagens e skins: `scripts/progression/skins.gd`

- `CATALOG` tem 24 entradas: 12 robôs base (0 BIT … 11 MAGNUS), 11 skins difíceis (12–21, 23) e BIT DE ELITE (22).
- Cada robô traz a sua **ultimate**, por isso no Charge Arena **personagem = robô base**.
- **`character_id`** = robô base (`Skins.base_of(i)`, por exemplo `salvo`).
- **`skin_id`** = entrada do catálogo (por exemplo `salvo_blindado`).
- Os nomes visíveis vão ser traduzidos, por isso os IDs técnicos ficam numa tabela fixa no `EventSchema`.
- **Não há compras de skins:** ganham-se ao vencer chefes (`skins.defeat(i)`).
- Sinais do HUD: `skin_previewed`, `skin_selected`; o Hangar abre com `open_skins()`.
- Save: `user://skins.cfg` (`defeated`, `seen`, `story_won`, `selected`).

### 1.5 Poderes, ultimates e economia: `scripts/gameplay/powers.gd`

- 24 habilidades em `CATALOG`, com `id`, `name`, `short`, `kind`, `charge`, `wait`, `price` e `about` (texto). Há ainda 11 `ULTIMATES` de skin e 13 `BASIC_ULTIMATES`, num total de 48 IDs.
- A **moeda única** são os tijolos (`bricks`):
  - ganham-se a partir tijolos inimigos em qualquer modo (`main.bank_bricks()`, durante a partida);
  - gastam-se na loja de PODERES (`buy`).
- **Não há moeda paga, compras na app, nem anúncios.**
- Kit: 2 habilidades equipadas (`kit`) mais a ultimate da skin.
- Save: `user://powers.cfg` (`bricks`, `owned`, `kit`).

### 1.6 Campanha e histórias

| Modo no jogo | Código | Mapeamento para analytics |
|---|---|---|
| **Modo história NORMAL**: a aventura do BIT, Taça Charge Arena | `story_script.gd` `INTRO` (capítulos 1–2), treino com a BATIDA (capítulo 3, o tutorial da partida), `OPENING` (capítulo 4); depois 11 rondas `ORDER` (ROSCA … ECLIPSE). HÉLIO é o "professor" (avança mesmo perdendo) | **`story_1`**. Capítulo = `ch1_fine`, `ch2_call`, `ch3_training`, `ch4_opening`, `round_01` … `round_11`. Chefe = robô da ronda. Checkpoint = ronda vencida (`skins.story_won`) |
| **Modo história DIFÍCIL**: Temporada 2 | `ORDER_HARD` (MAGNUS … HÉLIO), `S2_INTRO`, abre depois de acabar o NORMAL | **`story_2`**, rondas `round_01` … `round_11` |
| **ARENAS**: campanha livre | `campaign.gd` `LEVELS` (11 arenas: `treino`, `farol`, … `coroa`, com chefes e "postos") | modo `campaign`, `map_id` = `level.map.id` |
| **Taça Aurora**: modo antigo | `cup.gd`, `tournament.gd`, `story_hub/kiosk/press/paper/bracket/route/after` | **Inacessível:** o lobby já não tem a entrada `story`. Instrumentação mínima (`cup_*`) porque o código existe; tradução na onda 2 |

- Save das histórias: `skins.story_won` (`n<skin>`, `h<skin>`, `p<skin>`, `treino`).
- Save da campanha: `user://campaign.cfg`.
- Save da Taça: `user://taca_v5.cfg`.
- Não há checkpoints *dentro* de uma partida: cada ronda é uma partida curta.
- **"Fases do chefe"** (Fase 16) não existem como mecânica. O equivalente mensurável é o **estado da partida**: placar, muralha restante e golo sofrido. Proponho `boss_phase_reached` com `phase` = `goal_conceded_1`, `goal_scored_1`, `wall_below_50` e `wall_down`, registado uma vez por tentativa.

### 1.7 Modos de partida

`game_mode` proposto:

| Valor | Origem |
|---|---|
| `quick` | `start_pve` (mapa `torre*`) |
| `pvp_ai` | `start_pvp_ai` (Coliseu) |
| `squad_play` | `start_squad(false)` |
| `squad_watch` | `start_squad(true)` |
| `campaign` | `start_level` |
| `story_1` | `begin_story` (`hard=false`) |
| `story_2` | `begin_story` (`hard=true`) |
| `story_training` | `begin_training` |
| `cup` | `start_cup` |
| `pvp_lan` | `host_game` / `join_game` (`role` = `host`/`client`) |
| `test_arena` | só no LAB |

**PvP:**
- Só existe em **rede local** (ENet por IP).
- **Não há matchmaking, servidor nem contas.**
- Os eventos `matchmaking_*` pedidos mapeiam-se para o fluxo real:
  - `matchmaking_start` quando se cria a sala ou se tenta entrar;
  - `matchmaking_success` quando o par se liga;
  - `matchmaking_cancel` quando se sai antes de ligar, há *timeout* ou a ligação falha.

### 1.8 Tutorial

`scripts/ui/tutorial_overlay.gd`:
- passos com `start(steps)`, `show_step()`, `advance()` e `close(skipped)`;
- sinal `finished(skipped)`.

`game_hud.gd` (`start_tutorial(kind)`, linha 4415) tem três tutoriais:

| Tutorial | Passos |
|---|---|
| `lobby` | 12 |
| `match` | 11 (corre sobre a partida de treino da história, ou sobre a primeira partida rápida) |
| `shop` | 8 |

As flags ficam em `user://game_settings.cfg`.

### 1.9 Definições, saves e idioma

- `game_settings.gd` (`user://game_settings.cfg`), `video_settings.gd` (`user://video_settings.cfg`), `music_player.gd` (`user://audio_settings.cfg`), `game_feel.gd` (`user://game_feel.cfg`).
- **Não há sistema de idioma.**
- O ecrã de opções (`game_hud.build_video_menu`, linha ~2479) tem três separadores: CONTROLOS, JOGO, IMAGEM E SOM.
- `save_preferences()` reescreve só as chaves conhecidas. Por isso, idioma, consentimento e ID ficam em **ficheiros novos**, para não mexer nos formatos existentes (reversível).

### 1.10 Desempenho e aparelho

- `video_settings.gd`: `low_end()` (32 bits ou menos de 3,5 GB) dá o **`device_tier`**; perfis `quality` 0–2.
- `adapt()` baixa o limite de FPS em tempo real.
- O FPS é medido a cada 0,5 s em `main._process`, a fonte do `performance_sample` agregado por partida.

### 1.11 Fontes

As fontes Rubik, LilitaOne, Lora, Lora Italic e Playfair cobrem **todos** os caracteres de fr, es e it (verificado com fontTools).

---

## 2. Arquitetura proposta

```
JOGO (main.gd, HUD, regras)
   │  Analytics.track(Events.MATCH_END, {...})        ← só constantes do EventSchema
   ▼
AnalyticsManager (autoload "Analytics")
   ├─ PrivacyManager       → pode enviar? (estatísticas / erros, separados)
   ├─ EventSchema          → nomes, parâmetros permitidos e tipos (validação)
   ├─ SessionTracker       → sessão, primeiro plano/segundo plano, duração real
   ├─ MatchTracker         → agrega rules.events numa partida (tiros, acertos, dano, derrubes, poderes)
   ├─ ErrorMonitor         → Logger do Godot + migalhas + fecho anormal
   ├─ EventQueue           → fila, lotes, retry com backoff, persistência offline limitada, deduplicação por uuid
   └─ AnalyticsProvider (interface)
         ├─ NullProvider        (testes, ou analytics desligado)
         ├─ DebugProvider       ([ANALYTICS] no console, builds de desenvolvimento)
         ├─ PostHogProvider     (HTTP /batch/ na UE) ← primeiro fornecedor real
         └─ FirebaseProvider    (stub documentado, precisa de plugin Android, §8)
```

- **Sem dependência dura do autoload.** O jogo chama uma fachada estática, `AnalyticsManager.track(...)` via `preload`, que reencaminha para a instância se existir. Se não existir, nada acontece. Assim os testes atuais (`-s`, sem autoload garantido) não partem.
- **Nunca bloqueia.** `track()` só valida e mete na fila em memória. O envio é um `HTTPRequest` com thread, a cada 30 s, a 20 eventos, ao ir para segundo plano ou ao sair.
- **Idempotência.** Cada evento leva `uuid` (o PostHog deduplica por uuid). `match_id` e `attempt_id` são gerados no início. `match_end`, `story_complete`, `boss_defeated` e `skin_unlock` têm guarda "uma vez por id", persistida quando o evento é de uma vez na vida.
- **Propriedades comuns a todos os eventos:**
  - `anonymous_player_id`, `session_id`;
  - `game_version`, `build_number`, `build_flavor` (`lab`/`alfa`/`store`);
  - `platform`, `os_version`, `device_model`, `device_tier`;
  - `game_language`, `system_locale`, `store`.

  O país vem do GeoIP do PostHog, do lado do servidor. O jogo não lê nem guarda o IP.

---

## 3. Ficheiros novos

| Ficheiro | Conteúdo |
|---|---|
| `systems/analytics/AnalyticsManager.gd` | Autoload: API `track`, `set_user_property`, `start_session`, `end_session`, `flush`, `set_collection_enabled`; fachada estática |
| `systems/analytics/AnalyticsProvider.gd` | Interface: `initialize()`, `track_event()`, `set_user_property()`, `start_session()`, `end_session()`, `flush()`, `set_collection_enabled()` |
| `systems/analytics/providers/NullProvider.gd`, `DebugProvider.gd`, `PostHogProvider.gd`, `FirebaseProvider.gd` | Implementações (a do Firebase fica documentada, sem dependência) |
| `systems/analytics/EventSchema.gd` | Constantes de eventos e parâmetros, tipos, limites, tabelas de IDs (personagens, skins, mapas, modos) e buckets |
| `systems/analytics/EventQueue.gd` | Fila, lotes, retry, *timeout*, limite (500 eventos ou 256 KB em disco), persistência `user://analytics_queue.json` |
| `systems/analytics/SessionTracker.gd` | `first_open`, `game_open`, sessões, primeiro e segundo plano |
| `systems/analytics/MatchTracker.gd` | Resumo de partida a partir de `rules.events`; zonas; buckets de HP |
| `systems/analytics/ErrorMonitor.gd` | `Logger` (thread-safe), migalhas, marcador de sessão ativa, `app_error`/`app_crash_suspected` |
| `systems/analytics/PrivacyManager.gd` | Consentimentos separados (estatísticas, erros, publicidade, marketing), persistência, versão da política |
| `systems/analytics/BuildInfo.gd` | Versão, build, variante e loja, a partir de `ProjectSettings` e *feature tags* |
| `systems/analytics/analytics_config.json` | `provider`, `host` UE, `api_key` pública, intervalos. Sem segredos |
| `systems/localization/Localization.gd` | Deteção de idioma, preferência (`user://locale.cfg`), `language_changed`, utilitários de formatação |
| `localization/translations.csv`, `story.csv`, `content.csv`, `press.csv` | `KEY,pt,en,fr,es,it` (UI; diálogos das histórias; poderes, skins, arenas e mapas; Taça Aurora) |
| `ui/privacy` (no HUD) | Ecrã de consentimento na primeira abertura e secção Privacidade nas Opções |
| `tools/i18n/extract_strings.py`, `tools/i18n/check_translations.py` | Inventário de literais e validação do CSV (chaves em falta, placeholders `%d`/`%s` coerentes, colunas vazias) |
| `tests/regression/test_analytics_*.gd`, `test_localization.gd` | Testes automáticos (§10) |
| `docs/analytics/ANALYTICS_EVENTS.md`, `ANALYTICS_SETUP.md`, `PUBLISHER_DASHBOARD.md`, `IMPLEMENTATION_REPORT.md`, `PRIVACY_POLICY_DRAFT.md` | Documentação pedida |

O caminho `res://systems/...` segue o pedido. O resto do projeto usa `scripts/...` e nomes em `snake_case`; os nomes em PascalCase pedidos mantêm-se só nesta pasta nova.

---

## 4. Ficheiros a modificar

As alterações são pequenas: chamadas de *tracking* e troca de literais por chaves. **Não há mudanças de mecânica, equilíbrio nem formatos de save existentes.**

| Ficheiro | Função atual | Alteração | Eventos |
|---|---|---|---|
| `project.godot` | Configuração | `[autoload] Analytics="*res://systems/analytics/AnalyticsManager.gd"`; `[internationalization] locale/translations`; `application/config/version` e `build_number` | — |
| `tools/export_apk.sh` | Export | Escreve versão, build e loja no `project.godot` temporário (como já faz com o preset) | — |
| `tools/run_tests.py` | Testes | Espelhar `systems/` e `localization/` (`.csv`, `.translation`, `.json`) | — |
| `scripts/main.gd` | Orquestração | Início e fim de cada modo, abandono em `return_to_menu`/`replay`, PvP, loja, skins, tutorial, segundo plano, idioma; `MatchTracker.consume(rules.events)` após `rules.step` | sessões, tutorial, story, boss, match, character, map, skin, economia, PvP, idioma |
| `scripts/gameplay/arena_rules.gd` | Simulação | **Só metadados**: `src` (poder/ultimate/tiro) e `by` (piloto) nos eventos `brick`, `brick_hit`, `player_hit` e `stun` | (alimenta `power_hit`, `ultimate_hit`, derrubes) |
| `scripts/ui/tutorial_overlay.gd` | Tutorial | Sinal `step_shown(index, total)`; textos por chave | `tutorial_step` |
| `scripts/ui/game_hud.gd` | Interface | Textos por chave; idioma e privacidade nas Opções; sinal `shop_item_viewed`; ecrã de consentimento | `shop_item_view`, `language_changed`, `privacy_*` |
| `scripts/ui/lobby.gd`, `ui_kit.gd`, `unlock_notice.gd`, `feel_panel.gd` | Interface | Textos por chave | — |
| `scripts/story/story_script.gd`, `story_talk.gd`, `story_versus.gd` | Histórias | Diálogos por chave (`tr` ao mostrar) | — |
| `scripts/gameplay/powers.gd`, `progression/skins.gd`, `progression/campaign.gd`, `presentation/arena_theme.gd`, `settings/game_settings.gd` | Catálogos | Funções de nome visível por chave (`display_name(id)`). **Os catálogos e os IDs não mudam** | — |
| Taça Aurora (`story_*`, `tournament.gd`, `news_scene.gd`, `cup.gd`) | Modo inacessível | Onda 2: textos por chave e `cup_*` mínimos | `cup_match_start` / `end` |

---

## 5. Riscos e mitigação

| # | Risco | Mitigação |
|---|---|---|
| R1 | Testes atuais (53) partirem porque o autoload não existe em `-s`, ou porque o texto passa a inglês (o *locale* desta máquina é `en`) | Fachada estática tolerante; testes forçam `pt`; suite completa antes de cada *commit* |
| R2 | O executor de testes falha com qualquer `ERROR:` | Sem rede nos testes; analytics em `NullProvider`; falhas HTTP registadas como *debug*, nunca `push_error` |
| R3 | Metadados `src`/`by` nos eventos aumentam os pacotes PvP | Campos curtos (inteiros); o limite de 80 eventos por pacote mantém-se; teste de rede |
| R4 | Dados do LAB (tudo desbloqueado) contaminarem as métricas para publishers | `build_flavor` em todos os eventos; LAB envia para projeto de desenvolvimento, ou não envia |
| R5 | RGPD/ePrivacy (Portugal/UE): o UUID persistente e o envio a terceiros exigem consentimento | Estatísticas **opt-in** no primeiro arranque; erros com aviso e opção de desligar; política de privacidade publicada (ação manual) |
| R6 | Fecho anormal ≠ crash no Android (o sistema mata apps em segundo plano) | Marcar sessão "limpa" ao ir para segundo plano; só conta como suspeita de crash o fim em primeiro plano |
| R7 | Crashes nativos sem stack trace | Documentado. SDK nativo (Sentry ou Crashlytics) como fase seguinte |
| R8 | Volume de eventos e bateria | Agregação por partida; lotes de 30 s; amostras de desempenho, uma por partida |
| R9 | Tradução grande (cerca de 7 000 palavras acessíveis × 4 idiomas) | Ondas; validação automática de placeholders e chaves; revisão por nativo recomendada antes da loja |
| R10 | Texto embutido em imagens | Só "TAÇA CHARGE ARENA" no fundo `estadio.png`, mantido como nome próprio |
| R11 | Mudança de idioma a quente | Os controlos usam *auto-translate* do Godot com chave no `text`; o texto desenhado no `_draw` chama `tr()` a cada desenho; o resto atualiza via `language_changed` |

---

## 6. Eventos

Lista mínima, cada um com a pergunta a que responde. A tabela completa fica em `ANALYTICS_EVENTS.md`.

| Grupo | Eventos | Pergunta |
|---|---|---|
| Sessão | `first_open`, `game_open`, `session_start`, `session_end` (duração em primeiro plano), `game_background`, `game_foreground`, `game_exit` | Quantos instalam e abrem? DAU/WAU/MAU, retenção, minutos por jogador |
| Tutorial | `tutorial_start`, `tutorial_step` (`step_id`, `step_number`, `elapsed_seconds`), `tutorial_complete`, `tutorial_skip`, `tutorial_abandon` | Onde se perde o jogador novo? |
| História | `story_start`, `story_continue`, `story_chapter_start`, `story_checkpoint`, `story_death` (partida perdida), `story_retry`, `story_boss_start`, `story_boss_defeated`, `story_chapter_complete`, `story_abandon`, `story_complete` | Funis da História 1 e 2 |
| Chefes | `boss_encounter_start`, `boss_phase_reached`, `boss_player_death`, `boss_retry`, `boss_defeated` | Tentativas, fase de derrota, tempo |
| Partida | `matchmaking_start` / `success` / `cancel` (PvP local), `match_start`, `match_end` (resumo), `match_abandon` | Partidas por jogador, adoção de PvP, abandono, duração |
| Personagem | `character_selected`, `character_changed`, `character_match_end` | Uso, vitórias, tempo, dano médio |
| Poderes | `power_equipped`, `power_used`, `power_hit` / `power_miss` / `power_kill` (no fim da partida, por poder, para limitar o volume) | Uso, acerto, dano, derrubes |
| Ultimates | `ultimate_ready`, `ultimate_used`, `ultimate_hit` / `ultimate_kill` (agregados por uso) | Eficiência das ultimates |
| Derrubes | `player_death` (só o piloto local; `cause`, `power_id`, `position_zone` de 3×3) | Onde e porquê caem |
| Mapas | `map_enter`, `map_complete`, `map_abandon` | Popularidade, abandono, duração |
| Skins | `skin_view` (Hangar), `skin_preview`, `skin_equip`, `skin_unlock` | Interesse contra uso. **Sem eventos de compra** (não há compras) |
| Economia | `currency_earned` (agregado por partida, fonte), `currency_spent`, `item_unlock`, `shop_open`, `shop_item_view` | Fontes e gastos de tijolos |
| Desempenho | `performance_sample` (uma por partida: FPS médio e mínimo em *buckets*, perfil, tier, tempo de carga) | Aparelhos fracos abandonam? |
| Erros | `app_error` (limitado por sessão), `app_crash_suspected` | Versão e aparelho com mais problemas |
| Idioma | `language_detected`, `language_changed` e a propriedade `game_language` | Interesse internacional |
| Privacidade | `privacy_consent_updated` (só quando permitido) | Taxa de aceitação |
| Aquisição | Propriedades `store` e `install_source` | Que loja traz melhores jogadores |

---

## 7. Volume esperado

| Situação | Eventos |
|---|---|
| Sessão típica de 15 min e 4 partidas | cerca de 25–40 |
| Por partida | cerca de 6–12: `match_start`, `match_end`, `character_match_end`, `map_*`, `performance_sample`, `power_used` × N, `ultimate_*` |

Nunca se envia posição, bala, HP a cada alteração, nem dados por frame.

---

## 8. Dependências e ações manuais

1. **Conta PostHog Cloud UE** (gratuita até 1 milhão de eventos/mês). Criar dois projetos, "Charge Arena (dev)" e "Charge Arena (prod)", e copiar a *Project API Key* (pública) e o *host* `https://eu.i.posthog.com`. Ativar "Discard client IP data".
   - Até haver chave, o jogo funciona em modo local: nada sai do aparelho.
2. **Política de privacidade** publicada num URL. É necessária para a Galaxy Store e para o ecrã de consentimento; o rascunho é feito por mim.
3. **Loja de origem.** Sem código Android nativo não se lê o instalador. Proposta: um APK por loja com a *feature tag* `store_galaxy`, `store_github`, etc. Quando não estiver definida fica `unknown`.
4. **Crashes nativos (opcional, fase seguinte).** Sentry (GDExtension oficial) ou Firebase Crashlytics, que precisa de Gradle e `google-services.json`.
5. **Firebase Analytics (opcional).** Mesmo requisito Gradle; o fornecedor fica preparado na interface.
6. **Revisão das traduções por falantes nativos** antes da publicação comercial (recomendado).

---

## 9. Localização

- **Formato.** CSV nativo (`KEY,pt,en,fr,es,it`), importado pelo Godot para `.translation` e registado em `internationalization/locale/translations`.
- **Ficheiros.** Divididos por domínio para manutenção: `translations.csv` (UI), `story.csv`, `content.csv`, `press.csv`. Todos usam as mesmas colunas.
- **Chaves.** Prefixo por domínio, por exemplo:
  - `MENU_PLAY`, `HUD_WALL`, `SETTINGS_LANGUAGE`, `TUTORIAL_LOBBY_01_TITLE`;
  - `STORY1_INTRO_003`, `POWER_BLAST_NAME`, `SKIN_SALVO_ABOUT`, `LEVEL_FAROL_CHALLENGE`.
- **Formatação.** Placeholders `%d`/`%s` na mesma ordem em todos os idiomas, validados por script. Sem plurais (o CSV não os suporta); quando é preciso, usam-se chaves separadas.
- **Deteção.** Na primeira abertura, `OS.get_locale_language()`: se for pt, en, fr, es ou it usa esse; senão `en`. A escolha manual em Opções › Jogo › Idioma (Português, English, Français, Español, Italiano) é guardada em `user://locale.cfg`.
- **Ondas.**
  1. Tudo o que é acessível: menus, HUD, opções, tutoriais, loja, hangar, poderes, skins, arenas, mapas, avisos, Modo história NORMAL e DIFÍCIL. São cerca de 1 050 literais.
  2. Taça Aurora (inacessível no lobby): cerca de 740 literais.
- **Não se traduzem** IDs, ficheiros, URLs nem nomes técnicos. Os nomes próprios dos robôs (BIT, SALVO…) mantêm-se; as variantes descritivas ("SALVO BLINDADO") traduzem-se.

---

## 10. Testes previstos

Automáticos, em `tests/regression`, sem rede:

1. Instalação nova: UUID criado, válido (v4) e persistente.
2. `first_open` só uma vez.
3. Sessão com duração correta através de segundo plano e primeiro plano.
4. Consentimento desligado: zero eventos de estatística na fila. Religado: volta a recolher.
5. Validação: evento desconhecido, tipo errado e tamanho excessivo são rejeitados.
6. Fila: limite, persistência offline, retry e deduplicação por `uuid`.
7. Partida simulada (regras sem gráficos): `match_start` e `match_end` uma vez cada, com agregados coerentes com `rules.events`.
8. História 1 e 2: funil de eventos por ronda, tentativa e vitória, sem duplicados.
9. Tutorial: passos e saltar.
10. Economia: `currency_earned` agregado e igual aos tijolos creditados.
11. Erros: `push_error` gera `app_error` com contexto.
12. Localização:
    - todas as chaves existem nas 5 colunas;
    - placeholders coerentes;
    - nenhuma chave visível em falta (o `tr` não devolve a própria chave).
13. Mudança de idioma a quente.

Manuais:
- Android (APK LAB e ALFA): primeiro arranque, consentimento, eventos a chegar ao PostHog dev, modo offline e reconexão.
- Medição de impacto nos FPS.

---

## 11. Decisões que preciso de ti antes de ligar o envio real

| # | Decisão | Recomendação |
|---|---|---|
| D1 | Fornecedor | **PostHog Cloud UE** já; Firebase/Crashlytics depois, se quiseres |
| D2 | Consentimento | Estatísticas **opt-in** (ecrã no primeiro arranque); relatórios de erros ligados com aviso e opção de desligar |
| D3 | Dados do LAB | Enviar para o projeto *dev*, nunca para o de produção |
| D4 | Loja de origem | Um APK por loja com etiqueta (`store_galaxy`…) |
| D5 | Taça Aurora | Traduzir na onda 2 (está fora do lobby) |

A arquitetura, os eventos, o ID, as sessões, a privacidade e a localização avançam já, em modo local. Só o envio real depende da chave do PostHog (D1).

---

## 12. Ordem de execução

Cada passo é implementado, testado e guardado no GitHub antes do seguinte:

1. Arquitetura central: Manager, Provider, Schema, Queue e BuildInfo, com testes.
2. ID anónimo e sessões.
3. Privacidade e consentimento (lógica; o ecrã vem com a localização).
4. PostHogProvider (modo local até haver chave) e ErrorMonitor.
5. Instrumentação: tutorial, História 1, História 2, chefes, partidas (incluindo metadados `src`/`by`), personagens, poderes, ultimates, mapas, skins, economia, PvP e desempenho.
6. Localização: infraestrutura, extração e chaves (onda 1), PT/EN/FR/ES/IT, seletor de idioma, ecrã de consentimento, eventos de idioma.
7. Testes completos, offline e Android (APK LAB), medição de desempenho.
8. Documentação (`ANALYTICS_EVENTS`, `ANALYTICS_SETUP`, `PUBLISHER_DASHBOARD`), relatório final e onda 2 de tradução.
