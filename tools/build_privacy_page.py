#!/usr/bin/env python3
"""Builds hosting/public/privacy/index.html: the privacy policy in pt, en, fr, es and it.

The texts live here so the five languages stay side by side when one changes. The page
picks the reader's language from the browser and offers the other four. Fill in
CONTROLLER and CONTACT before publishing (tools refuse to deploy while they are blank).
"""
from html import escape
from pathlib import Path

UPDATED = "2026-10-04"
CONTROLLER = "{{RESPONSAVEL}}"
CONTACT = "{{EMAIL}}"
POLICY_VERSION = 1

LANGS = {
"pt": {
"name": "Português", "title": "Política de privacidade · Charge Arena",
"updated": "Última atualização", "version": "Versão da política",
"sections": [
("Quem somos", [
 f"Charge Arena é um jogo para Android. Responsável pelo tratamento: {CONTROLLER}. Contacto: {CONTACT}.",
]),
("Resumo", [
 "Não há contas, publicidade nem compras dentro do jogo.",
 "O progresso (skins, poderes, níveis, opções) fica guardado só no teu telemóvel.",
 "As estatísticas de jogo só são enviadas se aceitares, e podes mudar de ideias a qualquer momento em Opções › Privacidade.",
]),
("Estatísticas de jogo (só com o teu consentimento)", [
 "Servem para perceber como o jogo é jogado e torná-lo melhor: que modos se jogam, onde os jogadores desistem, que níveis são difíceis demais.",
 "O que é enviado: um identificador aleatório criado no telemóvel (não está ligado ao teu nome, e-mail, conta Google nem ao identificador de publicidade); eventos de jogo (início e fim de partidas, modo, mapa, personagem, poderes usados, resultados, progresso nas histórias, tutorial, idioma, opções); dados técnicos (modelo e sistema do telemóvel, versão do jogo, desempenho em FPS).",
 "Quem recebe: PostHog, na região da União Europeia (Frankfurt, Alemanha), como subcontratante. O jogo apaga o endereço IP de cada evento antes de o enviar, por isso o endereço IP não é guardado nem usado para localizar o jogador. A região vem apenas da definição de idioma e região do telemóvel.",
 "Base legal: o teu consentimento (art. 6.º, n.º 1, alínea a) do RGPD). Os dados são apagados ao fim de 24 meses.",
]),
("Relatórios de erros", [
 "Quando o jogo encontra um erro, pode enviar um relatório técnico (a mensagem do erro, o ecrã em que estava, a versão e o modelo do telemóvel) com o mesmo identificador aleatório, para que o erro seja corrigido.",
 "Base legal: interesse legítimo em manter o jogo a funcionar (art. 6.º, n.º 1, alínea f) do RGPD). Podes desligar estes relatórios em Opções › Privacidade.",
]),
("PvP online", [
 "Para jogar online, o teu telemóvel liga-se ao servidor do jogo, alojado na União Europeia. O servidor recebe o teu endereço IP e as tuas ações na partida apenas enquanto ela decorre. Não há conversas entre jogadores e o servidor não guarda endereços IP.",
 "No PvP em rede local, os dois telemóveis ligam-se diretamente um ao outro, sem passar pelo servidor.",
]),
("Crianças", [
 "O jogo é adequado a todas as idades. Abaixo dos 16 anos (ou da idade definida no teu país), as estatísticas só devem ser ativadas com autorização de quem tem a responsabilidade parental. O jogo funciona por inteiro sem elas.",
]),
("Os teus direitos", [
 "Podes retirar o consentimento a qualquer momento em Opções › Privacidade; a partir daí nada mais é enviado.",
 "Podes pedir acesso aos dados ou que sejam apagados, escrevendo para o contacto acima com o identificador mostrado em Opções › Privacidade.",
 "Tens o direito de apresentar queixa à autoridade de proteção de dados do teu país (em Portugal, a CNPD).",
]),
("Alterações", [
 "Se esta política mudar de forma relevante, o jogo volta a pedir-te a escolha antes de enviar o que quer que seja.",
]),
]},
"en": {
"name": "English", "title": "Privacy policy · Charge Arena",
"updated": "Last updated", "version": "Policy version",
"sections": [
("Who we are", [
 f"Charge Arena is an Android game. Data controller: {CONTROLLER}. Contact: {CONTACT}.",
]),
("Summary", [
 "There are no accounts, no ads and no in-app purchases.",
 "Your progress (skins, powers, levels, settings) is stored only on your phone.",
 "Gameplay statistics are sent only if you agree, and you can change your mind at any time in Options › Privacy.",
]),
("Gameplay statistics (only with your consent)", [
 "They help us understand how the game is played and make it better: which modes are played, where players give up, which levels are too hard.",
 "What is sent: a random identifier created on the phone (not linked to your name, email, Google account or advertising ID); gameplay events (match start and end, mode, map, character, powers used, results, story progress, tutorial, language, settings); technical data (phone model and system, game version, performance in FPS).",
 "Who receives it: PostHog, in its European Union region (Frankfurt, Germany), as a processor. The game blanks the IP address on every event before sending it, so the IP address is neither stored nor used to locate you. The region comes only from the phone's language and region setting.",
 "Legal basis: your consent (GDPR art. 6(1)(a)). The data is deleted after 24 months.",
]),
("Error reports", [
 "When the game hits an error, it may send a technical report (the error message, the screen it was on, the game version and phone model) with the same random identifier, so the error can be fixed.",
 "Legal basis: legitimate interest in keeping the game working (GDPR art. 6(1)(f)). You can turn these reports off in Options › Privacy.",
]),
("Online PvP", [
 "To play online, your phone connects to the game's server, hosted in the European Union. The server receives your IP address and your actions in the match only while it is being played. There is no chat between players, and the server does not store IP addresses.",
 "In local-network PvP the two phones connect directly to each other, without the server.",
]),
("Children", [
 "The game is suitable for all ages. Under 16 (or the age set in your country), statistics should only be turned on with the permission of a parent or guardian. The game works fully without them.",
]),
("Your rights", [
 "You can withdraw consent at any time in Options › Privacy; from then on nothing more is sent.",
 "You can ask for access to your data or for it to be deleted by writing to the contact above with the identifier shown in Options › Privacy.",
 "You have the right to complain to the data protection authority of your country.",
]),
("Changes", [
 "If this policy changes in a meaningful way, the game asks for your choice again before sending anything.",
]),
]},
"fr": {
"name": "Français", "title": "Politique de confidentialité · Charge Arena",
"updated": "Dernière mise à jour", "version": "Version de la politique",
"sections": [
("Qui sommes-nous", [
 f"Charge Arena est un jeu pour Android. Responsable du traitement : {CONTROLLER}. Contact : {CONTACT}.",
]),
("En bref", [
 "Il n'y a ni compte, ni publicité, ni achat intégré.",
 "Ta progression (skins, pouvoirs, niveaux, options) est enregistrée uniquement sur ton téléphone.",
 "Les statistiques de jeu ne sont envoyées que si tu l'acceptes, et tu peux changer d'avis à tout moment dans Options › Confidentialité.",
]),
("Statistiques de jeu (uniquement avec ton consentement)", [
 "Elles servent à comprendre comment le jeu est joué et à l'améliorer : quels modes sont joués, où les joueurs abandonnent, quels niveaux sont trop difficiles.",
 "Ce qui est envoyé : un identifiant aléatoire créé sur le téléphone (sans lien avec ton nom, ton e-mail, ton compte Google ou l'identifiant publicitaire) ; des événements de jeu (début et fin des parties, mode, carte, personnage, pouvoirs utilisés, résultats, progression des histoires, tutoriel, langue, options) ; des données techniques (modèle et système du téléphone, version du jeu, performances en FPS).",
 "Qui les reçoit : PostHog, dans sa région de l'Union européenne (Francfort, Allemagne), en tant que sous-traitant. Le jeu efface l'adresse IP de chaque événement avant l'envoi : elle n'est ni conservée ni utilisée pour te localiser. La région provient uniquement du réglage de langue et de région du téléphone.",
 "Base légale : ton consentement (art. 6, paragraphe 1, point a) du RGPD). Les données sont supprimées au bout de 24 mois.",
]),
("Rapports d'erreurs", [
 "Lorsque le jeu rencontre une erreur, il peut envoyer un rapport technique (le message d'erreur, l'écran affiché, la version du jeu et le modèle du téléphone) avec le même identifiant aléatoire, afin que l'erreur soit corrigée.",
 "Base légale : l'intérêt légitime à garder le jeu en état de marche (art. 6, paragraphe 1, point f) du RGPD). Tu peux désactiver ces rapports dans Options › Confidentialité.",
]),
("PvP en ligne", [
 "Pour jouer en ligne, ton téléphone se connecte au serveur du jeu, hébergé dans l'Union européenne. Le serveur reçoit ton adresse IP et tes actions pendant la partie uniquement. Il n'y a pas de discussion entre joueurs et le serveur ne conserve pas les adresses IP.",
 "En PvP sur réseau local, les deux téléphones se connectent directement l'un à l'autre, sans passer par le serveur.",
]),
("Enfants", [
 "Le jeu convient à tous les âges. En dessous de 16 ans (ou de l'âge fixé dans ton pays), les statistiques ne doivent être activées qu'avec l'accord d'un parent ou tuteur. Le jeu fonctionne entièrement sans elles.",
]),
("Tes droits", [
 "Tu peux retirer ton consentement à tout moment dans Options › Confidentialité ; plus rien n'est envoyé ensuite.",
 "Tu peux demander l'accès à tes données ou leur suppression en écrivant au contact ci-dessus, avec l'identifiant affiché dans Options › Confidentialité.",
 "Tu as le droit d'introduire une réclamation auprès de l'autorité de protection des données de ton pays (en France, la CNIL).",
]),
("Modifications", [
 "Si cette politique change de façon importante, le jeu te redemande ton choix avant d'envoyer quoi que ce soit.",
]),
]},
"es": {
"name": "Español", "title": "Política de privacidad · Charge Arena",
"updated": "Última actualización", "version": "Versión de la política",
"sections": [
("Quiénes somos", [
 f"Charge Arena es un juego para Android. Responsable del tratamiento: {CONTROLLER}. Contacto: {CONTACT}.",
]),
("Resumen", [
 "No hay cuentas, publicidad ni compras dentro del juego.",
 "Tu progreso (skins, poderes, niveles, opciones) se guarda solo en tu teléfono.",
 "Las estadísticas de juego solo se envían si aceptas, y puedes cambiar de opinión en cualquier momento en Opciones › Privacidad.",
]),
("Estadísticas de juego (solo con tu consentimiento)", [
 "Sirven para entender cómo se juega y mejorar el juego: qué modos se juegan, dónde abandonan los jugadores, qué niveles son demasiado difíciles.",
 "Qué se envía: un identificador aleatorio creado en el teléfono (sin relación con tu nombre, correo, cuenta de Google ni identificador de publicidad); eventos de juego (inicio y fin de partidas, modo, mapa, personaje, poderes usados, resultados, progreso en las historias, tutorial, idioma, opciones); datos técnicos (modelo y sistema del teléfono, versión del juego, rendimiento en FPS).",
 "Quién los recibe: PostHog, en su región de la Unión Europea (Fráncfort, Alemania), como encargado del tratamiento. El juego borra la dirección IP de cada evento antes de enviarlo, así que no se guarda ni se usa para localizarte. La región procede solo del ajuste de idioma y región del teléfono.",
 "Base jurídica: tu consentimiento (art. 6.1.a del RGPD). Los datos se eliminan a los 24 meses.",
]),
("Informes de errores", [
 "Cuando el juego encuentra un error, puede enviar un informe técnico (el mensaje del error, la pantalla en la que estaba, la versión del juego y el modelo del teléfono) con el mismo identificador aleatorio, para poder corregirlo.",
 "Base jurídica: interés legítimo en mantener el juego funcionando (art. 6.1.f del RGPD). Puedes desactivar estos informes en Opciones › Privacidad.",
]),
("PvP en línea", [
 "Para jugar en línea, tu teléfono se conecta al servidor del juego, alojado en la Unión Europea. El servidor recibe tu dirección IP y tus acciones solo mientras dura la partida. No hay chat entre jugadores y el servidor no guarda direcciones IP.",
 "En el PvP en red local, los dos teléfonos se conectan directamente entre sí, sin pasar por el servidor.",
]),
("Menores", [
 "El juego es apto para todas las edades. Por debajo de los 16 años (o la edad que fije tu país), las estadísticas solo deben activarse con permiso de quien tenga la patria potestad. El juego funciona por completo sin ellas.",
]),
("Tus derechos", [
 "Puedes retirar el consentimiento en cualquier momento en Opciones › Privacidad; desde entonces no se envía nada más.",
 "Puedes pedir acceso a tus datos o su eliminación escribiendo al contacto indicado arriba con el identificador que aparece en Opciones › Privacidad.",
 "Tienes derecho a presentar una reclamación ante la autoridad de protección de datos de tu país (en España, la AEPD).",
]),
("Cambios", [
 "Si esta política cambia de forma relevante, el juego vuelve a pedirte tu elección antes de enviar nada.",
]),
]},
"it": {
"name": "Italiano", "title": "Informativa sulla privacy · Charge Arena",
"updated": "Ultimo aggiornamento", "version": "Versione dell'informativa",
"sections": [
("Chi siamo", [
 f"Charge Arena è un gioco per Android. Titolare del trattamento: {CONTROLLER}. Contatto: {CONTACT}.",
]),
("In breve", [
 "Non ci sono account, pubblicità né acquisti in-app.",
 "I tuoi progressi (skin, poteri, livelli, opzioni) restano salvati solo sul tuo telefono.",
 "Le statistiche di gioco vengono inviate solo se accetti, e puoi cambiare idea in qualsiasi momento in Opzioni › Privacy.",
]),
("Statistiche di gioco (solo con il tuo consenso)", [
 "Servono a capire come si gioca e a migliorare il gioco: quali modalità vengono giocate, dove i giocatori si arrendono, quali livelli sono troppo difficili.",
 "Cosa viene inviato: un identificativo casuale creato sul telefono (non collegato a nome, e-mail, account Google o ID pubblicitario); eventi di gioco (inizio e fine delle partite, modalità, mappa, personaggio, poteri usati, risultati, progressi nelle storie, tutorial, lingua, opzioni); dati tecnici (modello e sistema del telefono, versione del gioco, prestazioni in FPS).",
 "Chi li riceve: PostHog, nella sua regione dell'Unione europea (Francoforte, Germania), come responsabile del trattamento. Il gioco cancella l'indirizzo IP da ogni evento prima di inviarlo, quindi non viene conservato né usato per localizzarti. La regione deriva solo dall'impostazione di lingua e regione del telefono.",
 "Base giuridica: il tuo consenso (art. 6, par. 1, lett. a) del GDPR). I dati vengono cancellati dopo 24 mesi.",
]),
("Segnalazioni di errori", [
 "Quando il gioco incontra un errore, può inviare una segnalazione tecnica (il messaggio di errore, la schermata in cui si trovava, la versione del gioco e il modello del telefono) con lo stesso identificativo casuale, per poterlo correggere.",
 "Base giuridica: legittimo interesse a mantenere il gioco funzionante (art. 6, par. 1, lett. f) del GDPR). Puoi disattivare queste segnalazioni in Opzioni › Privacy.",
]),
("PvP online", [
 "Per giocare online, il telefono si collega al server del gioco, ospitato nell'Unione europea. Il server riceve il tuo indirizzo IP e le tue azioni solo durante la partita. Non c'è chat tra giocatori e il server non conserva gli indirizzi IP.",
 "Nel PvP in rete locale i due telefoni si collegano direttamente tra loro, senza passare dal server.",
]),
("Minori", [
 "Il gioco è adatto a tutte le età. Sotto i 16 anni (o l'età stabilita nel tuo paese), le statistiche vanno attivate solo con il permesso di chi esercita la responsabilità genitoriale. Il gioco funziona completamente anche senza.",
]),
("I tuoi diritti", [
 "Puoi revocare il consenso in qualsiasi momento in Opzioni › Privacy; da quel momento non viene inviato più nulla.",
 "Puoi chiedere l'accesso ai tuoi dati o la loro cancellazione scrivendo al contatto indicato sopra, con l'identificativo mostrato in Opzioni › Privacy.",
 "Hai il diritto di presentare reclamo all'autorità di protezione dei dati del tuo paese (in Italia, il Garante per la protezione dei dati personali).",
]),
("Modifiche", [
 "Se questa informativa cambia in modo rilevante, il gioco ti chiede di nuovo la tua scelta prima di inviare qualsiasi cosa.",
]),
]},
}

PAGE = """<!doctype html>
<html lang="pt">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Charge Arena · Privacy</title>
<style>
:root {{ --bg: #f6f7fb; --card: #ffffff; --ink: #172033; --muted: #5a6478; --accent: #1f6fe5; --line: #dfe3ec; }}
@media (prefers-color-scheme: dark) {{ :root {{ --bg: #0b1020; --card: #141b2e; --ink: #e9edf6; --muted: #9aa6bd; --accent: #6ea8ff; --line: #26304a; }} }}
* {{ box-sizing: border-box; }}
body {{ margin: 0; background: var(--bg); color: var(--ink); font: 16px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }}
main {{ max-width: 760px; margin: 0 auto; padding: 24px 16px 64px; }}
nav {{ display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 24px; }}
nav a {{ display: inline-block; border: 1px solid var(--line); background: var(--card); color: var(--ink); border-radius: 999px; padding: 6px 14px; font-size: 14px; text-decoration: none; }}
nav a[aria-current="true"] {{ background: var(--accent); border-color: var(--accent); color: #fff; }}
article {{ background: var(--card); border: 1px solid var(--line); border-radius: 16px; padding: 24px; }}
h1 {{ font-size: 24px; line-height: 1.25; margin: 0 0 4px; }}
h2 {{ font-size: 18px; margin: 28px 0 8px; }}
p {{ margin: 0 0 10px; }}
.meta {{ color: var(--muted); font-size: 14px; margin-bottom: 8px; }}
article[hidden] {{ display: none; }}
</style>
</head>
<body>
<main>
<nav aria-label="Language">{buttons}</nav>
{articles}
</main>
<script>
(function () {{
  var langs = {codes};
  function show(code) {{
    langs.forEach(function (l) {{
      document.getElementById('lang-' + l).hidden = l !== code;
      document.querySelector('[data-lang="' + l + '"]').setAttribute('aria-current', l === code);
    }});
    document.documentElement.lang = code;
    document.title = document.querySelector('#lang-' + code + ' h1').textContent;
  }}
  window.addEventListener('hashchange', function () {{
    var code = location.hash.slice(1);
    if (langs.indexOf(code) >= 0) show(code);
  }});
  var wanted = (location.hash || '').slice(1);
  if (langs.indexOf(wanted) < 0) {{
    var nav = (navigator.languages || [navigator.language || 'en']).map(function (x) {{ return x.slice(0, 2).toLowerCase(); }});
    wanted = nav.filter(function (x) {{ return langs.indexOf(x) >= 0; }})[0] || 'en';
  }}
  show(wanted);
}})();
</script>
</body>
</html>
"""


def build() -> str:
    buttons = "".join(f'<a href="#{c}" data-lang="{c}" aria-current="false">{escape(d["name"])}</a>' for c, d in LANGS.items())
    articles = []
    for code, data in LANGS.items():
        body = [f'<article id="lang-{code}" lang="{code}"{" hidden" if code != "pt" else ""}>',
                f'<h1>{escape(data["title"])}</h1>',
                f'<p class="meta">{escape(data["updated"])}: {UPDATED} · {escape(data["version"])}: {POLICY_VERSION}</p>']
        for heading, paragraphs in data["sections"]:
            body.append(f"<h2>{escape(heading)}</h2>")
            body.extend(f"<p>{escape(p)}</p>" for p in paragraphs)
        body.append("</article>")
        articles.append("\n".join(body))
    return PAGE.format(buttons=buttons, articles="\n".join(articles), codes=list(LANGS))


if __name__ == "__main__":
    out = Path(__file__).resolve().parents[1] / "hosting" / "public" / "privacy" / "index.html"
    out.write_text(build(), encoding="utf-8")
    print(out)
