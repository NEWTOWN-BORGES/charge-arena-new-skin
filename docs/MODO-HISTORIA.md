# Modo História: a Taça Aurora

A campanha deixa de ser "nível 1 → nível 2 → boss" e passa a ser um torneio de **1.024 pilotos**
em que as vitórias do jogador criam uma história. Nenhuma regra, arena ou boss foi redesenhado:
cada ronda da Taça é o nível da campanha dessa ronda, com o mesmo mapa, o mesmo boss com a sua
skin e o seu kit, o mesmo ritmo e a mesma música.

A base veio do Modo História feito no repositório `charge-arena` (3.1.0) e foi adaptada ao
elenco e ao visual novos.

## Estrutura

```
PARTIDA → CONSEQUÊNCIA → O MUNDO REAGE → JORNAL → A CHAVE MUDA → PRÓXIMO ADVERSÁRIO
```

- **Admissão** contra o **Bit**, a porta da Taça. Depois vêm dez rondas: 1.024 → 512 → … → 2 →
  campeão. Cada ronda tem um boss, pela ordem da campanha:
  - 1.ª a 3.ª eliminatória: Salvo, Bigorna, Batida;
  - 4.ª e 5.ª eliminatória: Rosca, Broto;
  - 16 avos e oitavos: Gancho, Faísca;
  - quartos de final e meias-finais: Órbita, Eclipse;
  - final: Hélio.

  O Magnus (tetracampeão) cai do outro lado da chave.
- **O resto da chave** joga-se à volta do jogador a partir de uma semente guardada: os mesmos
  pilotos e os mesmos resultados de cada vez que o jogo abre (`scripts/tournament.gd`).
- **Figuras com histórias próprias:** Vértice, Lira, Nina Vento, Kael Brasa, Oto Fio e Mara
  Lume. Os outros ~1.000 pilotos são gerados com nome, região, cor, símbolo e classificação.
- **Fios que só se juntam no fim:** o Kael Brasa desiste e aparece no camarote do Hélio; o Bit
  perdeu uma final há doze anos que ninguém explicou e volta à bancada; na véspera da final,
  ambos falam.

## Ecrãs

- **Lobby** (`scripts/lobby.gd`): o modo principal é o **MODO HISTÓRIA**.
  - O cartão mostra a ronda, o adversário e o aviso **NOVA EDIÇÃO** quando há jornal por ler.
  - **JOGAR** vai direto ao ecrã VS da próxima partida: quem só quer jogar faz
    entrar → lutar → avançar.
  - A tecla **HISTÓRIA** abre o hub.
  - As arenas já vencidas ficam em **ARENAS**, para jogo livre.
- **Hub da Taça** (`story_hub.gd`): a ronda atual, a escada 1.024 → campeão, a próxima partida,
  a Banca da Rosa, Meu Percurso, Árvore da Arena, Piloto, Poderes, Arenas e Opções.
- **Banca da Rosa** (`story_kiosk.gd`): o quiosque é um lugar em 3D, com a Rosa (cadela-robô) e
  a capa do dia. A fala muda com a campanha: de "Primeira vez na Taça?" até "Esta capa vai para
  a parede da banca".
- **AURORA EM CAMPO** (`story_paper.gd` + `story_press.gd`):
  - 12 edições escritas à mão, com manchete, fotografia, notícias secundárias, número e dia;
  - arquivo de edições;
  - tipografia de imprensa (Playfair Display e Lora, OFL).
- **Fotografias** (`news_scene.gd`): cenas encenadas com os modelos reais dos robôs em 10
  cenários:
  - arena, doca espacial, ponte de nave, hangar e corredor;
  - sala de imprensa, balneário, praça, camarote e observatório.

  Categorias: VICTORY, DEFEAT, INTERVIEW, CELEBRATION, RIVALRY, ARENA_EVENT, BOSS_ENTRANCE,
  TOURNAMENT, CROWD e FINAL. Uma imagem final colocada em `res://art/press/<chave>.png` toma o
  lugar da cena encenada; nada é gerado por cima de um asset oficial.
- **VS** (`story_versus.gd`): uma apresentação desportiva com a ronda, os dois pilotos, uma linha
  sobre o adversário e a frase dele. Pode-se saltar.
- **Pós-partida** (`story_after.gd`): vitória ou derrota, o resultado e a chave a encolher. Depois
  de uma vitória há nova edição; LER AGORA leva ao jornal.
- **Meu Percurso** (`story_route.gd`): só a história do jogador. Mostra a admissão e cada ronda,
  com o adversário, o resultado, a arena e a manchete do dia. Termina na ronda atual e num "?".
- **Árvore da Arena** (`story_bracket.gd`):
  - **Visão global:** 1.024 → 512 → … → campeão.
  - **A tua zona:** quem está perto do jogador, com os eliminados riscados.
  - **Sem spoilers:** mostra "possíveis adversários" e os resultados de cada ronda só depois de
    ela acontecer.

## Derrotas

Perder uma ronda não a elimina: a partida pode repetir-se. O jornal não imprime nada; a Rosa
comenta e o hub lembra a tentativa ("TENTAR DE NOVO").

## Save

`user://taca_v5.cfg` guarda:

- a semente, a admissão, as rondas ganhas e o percurso;
- os resultados da chave;
- os acontecimentos, as tentativas perdidas e as edições lidas.

Ao abrir o jogo nada é regenerado de forma diferente.

## Nomes

Os bosses mantêm os papéis e passam a ter os nomes do elenco novo:

| Nome antigo | Nome novo |
|---|---|
| Faroleiro | Salvo |
| Astrónomo | Órbita |
| Jardineiro | Broto |
| Mineiro | Bigorna |
| Sentinela | Eclipse |
| Relojoeiro | Rosca |
| Caça-Trovões | Faísca |
| Alquimista | Batida |
| Corsário | Gancho |
| Arconte Solar | Hélio |
| Aurel | Magnus |
| Aurora (a porteira) | Bit (o porteiro) |

As personalidades públicas (epíteto, linha e frase) foram reescritas a partir do design de cada
robô.

## Testes

- `tests/test_taca.gd`: a chave, as rondas, os bosses, a semente e as edições.
- `tests/test_story_hub.gd`: o fluxo completo.
  - lobby → VS → arena → resultado → jornal;
  - derrota → nova tentativa → vitória;
  - gravação, percurso e árvore.
- `tests/capture_story.gd`: folha com os ecrãs.
