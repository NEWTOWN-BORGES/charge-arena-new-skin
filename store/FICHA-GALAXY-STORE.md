# Charge Arena · Samsung Galaxy Store

Tudo o que o Galaxy Store Seller Portal pede para a primeira publicação. A chave de assinatura
**não** está aqui nem no repositório: guarda-a tu (ver "Chave de assinatura").

## Dados da app

| Campo | Valor |
|---|---|
| Nome da app | Charge Arena |
| Pacote (definitivo, não muda mais) | `org.chargearena.game` |
| Versão | 3.48.0 (versionCode 78; sobe 1 em cada envio) |
| Categoria | Games · Action (ou Arcade) |
| Gratuita | Sim |
| Anúncios | Não |
| Compras na app | Não |
| Android mínimo | 7.0 (API 24) · alvo: API 36 |
| Ficheiro a enviar | `charge-arena-galaxy-3.48.0.apk` (arm64 + 32 bits num só ficheiro, assinado com a tua chave) |
| Idiomas do jogo | Inglês, português, francês, espanhol, italiano |

A versão da loja tem o seu próprio pacote; instala-se ao lado das versões LAB e ALFA de teste.

## Título e descrições (inglês, idioma principal da ficha)

**Título:** Charge Arena

**Descrição curta:** Robots, brick walls and goals: smash the rival wall and score first!

**Descrição completa:**

Charge Arena is a two-sided arena game: each side has a brick wall guarding its goal. Shoot, bounce your shots off the walls, smash your opponent's wall and put the ball in their goal before they score in yours.

⚡ 24 robots to unlock: BIT, BROTO, BATIDA, ROSCA, GANCHO, FAÍSCA, ÓRBITA, BIGORNA, SALVO, ECLIPSE, HÉLIO and MAGNUS, each with its own ultimate, its own bricks and a HARD neon version.

📖 Story mode with two seasons: the student BIT enters the Charge Arena Cup to pay for university. Robot voices, VS cards, 11 rivals and a second season full of twists.

🛠️ Power shop: trade the bricks you break for 24 abilities (explosions, lasers, shields, magnets, mortars…) and pick the two you take into battle.

🧱 Workshop: paint jobs, shot colours and 10 brick styles for your wall, from safes and barrels to crystals and neon orbs.

🌍 Worlds full of life: a sky island, a mountain valley, an undersea base, an orbital station, a city rooftop and neon worlds for the night.

🎮 Simple controls: tap the joystick to shoot, drag to move and aim. Top-down camera or third person.

👥 Local PvP: challenge a friend on the same Wi-Fi.

No ads. No accounts. Play offline.

## Ficha em português (idioma extra)

**Descrição curta:** Robôs, muralhas de tijolos e golos: parte a muralha rival e marca primeiro!

**Descrição completa:**

Charge Arena é um jogo de arena para dois: cada lado tem uma muralha de tijolos a proteger a sua baliza. Dispara, faz ricochete nas paredes, parte a muralha do adversário e mete a bola na baliza dele antes que ele o faça na tua.

⚡ 24 robôs para desbloquear: BIT, BROTO, BATIDA, ROSCA, GANCHO, FAÍSCA, ÓRBITA, BIGORNA, SALVO, ECLIPSE, HÉLIO e MAGNUS, cada um com a sua ultimate, o seu tijolo e uma versão DIFÍCIL com néon.

📖 Modo história com duas temporadas: o estudante BIT entra na Taça Charge Arena para pagar a universidade. Vozes robóticas, cartões VS, 11 rivais e uma segunda temporada cheia de reviravoltas.

🛠️ Loja de poderes: troca os tijolos que partes por 24 habilidades (explosões, lasers, escudos, ímanes, morteiros…) e escolhe as duas que levas para o combate.

🧱 Oficina: pinturas, cor dos disparos e 10 estilos de tijolo para a tua muralha.

🌍 Mundos cheios de vida: ilha no céu, vale com montanhas, base submarina, estação orbital, telhado da cidade e mundos de néon para a noite.

🎮 Controlos simples: toca no joystick para disparar, arrasta para mover e apontar. Câmara de cima ou em 3.ª pessoa.

👥 PvP local: desafia um amigo no mesmo Wi-Fi.

Sem anúncios. Sem contas. Joga offline.

## Imagens (pasta `store/`)

- Ícone 512×512: `icon_512.png`
- Imagem de destaque 1024×500: `feature_graphic_1024x500.png` (opcional no Galaxy Store)
- Capturas 1080×1920 em inglês (telemóvel): `screenshots/*.png`, pela ordem dos números

## Política de privacidade

`politica-de-privacidade.html` (português e inglês) tem de estar num endereço público. Como o
repositório é privado, publica-a num sítio gratuito (por exemplo Google Sites: cola o texto) e
mete esse endereço no Seller Portal. E-mail de contacto: dev.nettuno@gmail.com.

A política descreve o que o jogo envia de facto: relatórios de erro anónimos (ligados por
omissão, desligáveis) e estatísticas de jogo anónimas (só se o jogador as ligar), para o
PostHog na UE, sem IP nem dados pessoais.

## Respostas aos formulários do Seller Portal

**Classificação etária:** o Galaxy Store usa o questionário IARC. Violência de fantasia ligeira
(robôs a disparar contra tijolos e uns contra os outros, sem sangue nem pessoas), sem
linguagem imprópria, sem conteúdo sexual, sem jogo a dinheiro, sem comunicação entre
utilizadores pela internet (o PvP é local), sem partilha de localização, sem compras.
Resultado esperado: PEGI 7 / 12+ (confirma o que o questionário atribuir).

**Recolha de dados:** sim, dados anónimos de diagnóstico (relatórios de erro) e, com
autorização, estatísticas de uso; nenhum dado pessoal; não partilhados com terceiros nem
usados para publicidade; enviados cifrados (HTTPS).

**Público-alvo:** 13 anos ou mais.

**Anúncios:** Não. **Compras:** Não. **Login:** Não.

**Países:** todos (o jogo está em 5 idiomas e funciona offline).

## Chave de assinatura

- Ficheiro: `charge-arena-galaxy.jks` (PKCS12), alias `chargearena`.
- A palavra-passe foi-te entregue à parte, junto com a chave.
- O Galaxy Store não guarda a chave por ti: **todas** as atualizações têm de ser assinadas com
  esta mesma chave. Se a perderes, não podes atualizar a app (terias de publicar outra).
- Guarda-a em dois sítios (ex.: gestor de palavras-passe + pen/Drive pessoal). **Nunca** a
  metas no repositório.

## Gerar uma nova versão

```
STORE_KEYSTORE=/caminho/charge-arena-galaxy.jks STORE_ALIAS=chargearena STORE_PASS='…' \
VERSION_CODE=78 tools/export_apk.sh charge-arena-galaxy-3.47.2.apk org.chargearena.game \
"Charge Arena" 3.47.2 store_galaxy bit all
```
