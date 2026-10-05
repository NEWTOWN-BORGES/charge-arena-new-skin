# Charge Arena · Google Play

Tudo o que a Play Console pede para a primeira publicação. A chave de assinatura **não** está
aqui nem no repositório: guarda-a tu (ver "Chave de upload").

## Dados da app

| Campo | Valor |
|---|---|
| Nome da app | Charge Arena |
| Pacote (definitivo, não muda mais) | `com.newtownborges.chargearena` |
| Versão | 1.0.0 (versionCode 1; sobe 1 em cada envio) |
| Categoria | Jogos · Ação (ou Arcada) |
| Gratuita | Sim |
| Anúncios | Não |
| Compras na app | Não |
| Android mínimo | 7.0 (API 24) · alvo: API 36 |
| Ficheiro a enviar | `charge-arena-1.0.0.aab` (arm64 + 32 bits num só ficheiro) |

## Descrição curta (máx. 80 caracteres)

Robôs, muralhas de tijolos e golos: parte a muralha rival e marca primeiro!

## Descrição completa

Charge Arena é um jogo de arena para dois: cada lado tem uma muralha de tijolos a proteger a sua baliza. Dispara, faz ricochete nas paredes, parte a muralha do adversário e mete a bola na baliza dele antes que ele o faça na tua.

⚡ **24 robôs para desbloquear** — BIT, BROTO, BATIDA, ROSCA, GANCHO, FAÍSCA, ÓRBITA, BIGORNA, SALVO, ECLIPSE, HÉLIO e MAGNUS, cada um com a sua ultimate, o seu tijolo e uma versão DIFÍCIL com néon.

📖 **Modo história com duas temporadas** — o estudante BIT entra na Taça Charge Arena para pagar a universidade. Conversas com vozes robóticas, cartões VS, 11 rivais e uma segunda temporada cheia de reviravoltas.

🛠️ **Loja de poderes** — troca os tijolos que partes por 24 habilidades: explosões, lasers, escudos, ímanes, morteiros… e escolhe as duas que levas para o combate.

🌍 **Mundos cheios de vida** — ilha no céu, vale com montanhas, base submarina, estação orbital, telhado da cidade e cinco mundos de néon para a noite.

🎮 **Controlos simples** — toca no joystick para disparar, arrasta para mover e apontar. Câmara de cima ou em 3.ª pessoa.

👥 **PvP local** — desafia um amigo no mesmo Wi-Fi.

Sem anúncios. Sem contas. Joga offline.

## Imagens (pasta `store/`)

- Ícone 512×512: `icon_512.png`
- Imagem de destaque 1024×500: `feature_graphic_1024x500.png`
- Capturas 1080×1920 (telemóvel): `screenshots/1_lobby.png` … `6_poderes.png`

## Política de privacidade

`politica-de-privacidade.html` tem de estar num endereço público. Como o repositório vai ficar
privado, publica-a num sítio gratuito, por exemplo Google Sites (cola o texto), e mete esse
endereço na Play Console. Antes, substitui `[O TEU E-MAIL DE CONTACTO]` pelo teu e-mail.

## Respostas aos formulários da Play Console

**Segurança dos dados:** a app recolhe dados anónimos: "Falhas e diagnóstico" (relatórios de
erro, ligados por omissão e desligáveis) e "Atividade na app" (estatísticas de jogo, só se o
jogador as ligar), mais o identificador aleatório criado no telemóvel. Nada é partilhado com
terceiros. Dados cifrados em trânsito: sim (HTTPS, PostHog UE). Pedido de eliminação: por
e-mail, com o identificador mostrado em Opções › Jogo › Privacidade.

**Classificação de conteúdo (questionário IARC):** categoria Jogo; violência: robôs a disparar
contra tijolos e uns contra os outros, sem sangue nem pessoas (violência de fantasia ligeira);
sem linguagem imprópria, sem conteúdo sexual, sem jogo a dinheiro, sem interação entre
utilizadores pela internet (o PvP é local), sem partilha de localização, sem compras.
Resultado esperado: PEGI 7 / Todos 10+ (confirma o que o questionário atribuir).

**Público-alvo:** 13 anos ou mais é o mais simples (menores de 13 obriga ao programa "Designed
for Families", com regras extra).

**Acesso à app:** todas as funcionalidades sem restrições (sem login).

**Anúncios:** Não.

## Teste fechado (contas pessoais novas)

Antes de poder publicar para todos, a Google exige um teste fechado com pelo menos 12
testadores durante 14 dias seguidos. Cria a faixa "Teste fechado", sobe o `.aab`, adiciona os
e-mails dos testadores (conta Google de cada um) e partilha-lhes o link de adesão.

## Chave de upload

- Ficheiro: `charge-arena-upload.jks` (PKCS12), alias `chargearena`.
- A palavra-passe foi-te entregue à parte, junto com a chave.
- Na Play Console, ativa a **Assinatura de apps do Google Play** (vem ligada por omissão): a
  Google guarda a chave final da app e esta passa a ser só a chave de upload. Se a perderes,
  pedes à Google para registar uma nova (demora uns dias), mas guarda-a bem na mesma.
- Guarda-a em dois sítios (ex.: gestor de palavras-passe + pen/Drive pessoal). **Nunca** a
  metas no repositório.

## Gerar uma nova versão

```
STORE_KEYSTORE=/caminho/charge-arena-upload.jks STORE_ALIAS=chargearena STORE_PASS='…' \
VERSION_CODE=2 BUNDLETOOL=/caminho/bundletool-all.jar \
tools/build_aab.sh charge-arena-1.0.1.aab 1.0.1
```
