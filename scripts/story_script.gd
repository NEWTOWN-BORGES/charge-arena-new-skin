extends RefCounted
## The story of the Modo história (NORMAL): BIT, a university robot who spent his tuition on
## a speeding fine, enters the Taça Charge Arena to win the prize money. Each boss has lines
## before the match and after it (won or lost); the speaker is a skin index, AGENTE (the
## traffic officer) or NARRADOR (a caption with no portrait).

const NARRADOR = -1
const AGENTE = -2
const BIT = 0
const SALVO = 1
const ORBITA = 2
const BROTO = 3
const BIGORNA = 4
const ECLIPSE = 5
const ROSCA = 6
const FAISCA = 7
const BATIDA = 8
const GANCHO = 9
const HELIO = 10
const MAGNUS = 11
const BIT_ELITE = 22

# The opponents in the order the tournament puts them in front of BIT.
const ORDER = [ROSCA, SALVO, BIGORNA, BATIDA, BROTO, GANCHO, ORBITA, FAISCA, MAGNUS, HELIO, ECLIPSE]
# HÉLIO's match moves the story on whatever the result: he wins it easily with his ultimate,
# then teaches BIT the RAIO DE ELITE. From there BIT wears BIT DE ELITE.
const TEACHER = HELIO
const FINAL = ECLIPSE

const PROLOGUE = [
	[NARRADOR, "Cidade de Voltara, fim de tarde. O BIT, estudante de engenharia na Universidade de Voltara, vai atrasado para casa…"],
	[NARRADOR, "…e a conduzir um bocadinho depressa demais."],
	[AGENTE, "Alto! Robô modelo BIT: 92 km/h numa zona de 50. A multa é de 800 créditos, a pagar já."],
	[BIT, "800?! Mas… esse é o dinheiro das propinas da universidade!"],
	[AGENTE, "Regras são regras. Conduza com cuidado."],
	[NARRADOR, "O BIT pagou a multa. E ficou sem nada para pagar a universidade."],
	[BIT, "Tenho de ligar à BATIDA. Ela sabe sempre o que fazer."],
	[BATIDA, "BIT?! Multado outra vez? Ai, ai… Ouve: está a começar a TAÇA CHARGE ARENA. O prémio paga a universidade e ainda sobra!"],
	[BIT, "Mas eu sou um robô comum, não sou de combate. Não tenho habilidades especiais, nem ultimate."],
	[BATIDA, "Tens um canhão e tens cabeça. Cada tijolo que partes na arena é dinheiro na LOJA DE PODERES: aprendes habilidades novas pelo caminho. Eu inscrevo-te!"],
	[BATIDA, "O primeiro é o ROSCA, mecânico de corrida. Monta sentinelas com miniguns: parte-lhe a muralha antes que as monte!"],
]

const LINES = {
	ROSCA: {
		"before": [
			[ROSCA, "Então tu é que és o novato? Um BIT de série na Taça? Vou-te desmontar peça a peça!"],
			[BIT, "Só preciso de passar esta ronda. Tenho propinas para pagar."],
			[ROSCA, "As minhas sentinelas não aceitam desculpas. Vruum!"],
		],
		"won": [
			[ROSCA, "Uau… partiste-me a muralha com um canhão de série? Tens jeito, miúdo."],
			[ROSCA, "Dica de mecânico: o próximo é o SALVO. Dispara quatro mísseis que caem ao acaso. Não fiques parado no mesmo sítio!"],
			[BATIDA, "Boa, BIT! Já tens tijolos: passa pela LOJA DE PODERES e aprende uma habilidade antes da próxima ronda."],
		],
		"lost": [
			[ROSCA, "Ha! Volta quando tiveres mais do que um canhão de série."],
			[BATIDA, "Não desistas. Gasta os tijolos na LOJA DE PODERES: uma boa habilidade muda tudo."],
		],
	},
	SALVO: {
		"before": [
			[SALVO, "Artilheiro SALVO, ao serviço. Quatro mísseis prontos, recruta."],
			[BIT, "O ROSCA disse para não ficar parado. Anotado."],
			[SALVO, "O ROSCA fala demais. Em posição!"],
		],
		"won": [
			[SALVO, "Manobras limpas. Tens o meu respeito, recruta."],
			[SALVO, "Próximo alvo: a BIGORNA. Muralha de aço e uma ultimate que a blinda. Guarda os golpes fortes para quando a blindagem cair."],
		],
		"lost": [
			[SALVO, "Negativo, recruta. Mexe-te mais e aprende na loja algo que parta muralhas depressa."],
		],
	},
	BIGORNA: {
		"before": [
			[BIGORNA, "Na minha forja as muralhas são de aço. E tu és de lata."],
			[BIT, "Lata ou não, não saio daqui sem passar."],
		],
		"won": [
			[BIGORNA, "Hmpf. Martelaste bem. Levas o meu respeito… e uma notícia."],
			[BIGORNA, "A próxima é a BATIDA. Sim, a tua amiga. Na arena, ela não tem amigos."],
			[BIT, "A BATIDA?! Ela também está no torneio?"],
		],
		"lost": [
			[BIGORNA, "Volta quando a tua muralha for de aço. Ou aprende uma habilidade que a repare sozinha."],
		],
	},
	BATIDA: {
		"before": [
			[BATIDA, "Surpresa! Também me inscrevi. Se é para ganhar o prémio, que seja um de nós."],
			[BIT, "Não quero lutar contigo…"],
			[BATIDA, "Luta a sério. Se me venceres, sei que chegas à final. Solta o som!"],
		],
		"won": [
			[BATIDA, "É assim mesmo! Fico feliz por perder para ti."],
			[BATIDA, "Ouve, uma coisa estranha: dizem que o ECLIPSE anda a sabotar pilotos nos bastidores. Tem cuidado."],
			[BATIDA, "O próximo é o BROTO, o jardineiro. Parece fofinho, mas a ultimate dele faz crescer tijolos novos."],
		],
		"lost": [
			[BATIDA, "Nem a mim me passas, BIT? Vai à loja, treina e volta. Eu espero por ti."],
		],
	},
	BROTO: {
		"before": [
			[BROTO, "Olá! Também cuidas das tuas plantas? Eu cuido das minhas muralhas."],
			[BIT, "És mesmo simpático… para um adversário."],
			[BROTO, "Simpático até à floração. Depois já não!"],
		],
		"won": [
			[BROTO, "Ah, cortaste-me as flores todas… Mas mereceste."],
			[BROTO, "O GANCHO é o próximo. Um pirata com um gancho que puxa tudo. Não te deixes arrastar!"],
		],
		"lost": [
			[BROTO, "As minhas flores voltam sempre a crescer. Tens de as partir mais depressa!"],
		],
	},
	GANCHO: {
		"before": [
			[GANCHO, "Arr! Um BIT perdido no meu recife. Que tesouro me trazes?"],
			[BIT, "Só dívidas, capitão."],
			[GANCHO, "Então lutas pelo ouro, como eu. Gosto disso!"],
		],
		"won": [
			[GANCHO, "Levaste o saque, marinheiro. Justo."],
			[GANCHO, "Aviso de pirata: a ÓRBITA vê tudo lá de cima. Faz chover meteoros sobre metade do campo. Ataca pelos lados."],
		],
		"lost": [
			[GANCHO, "Ao mar contigo! Volta com melhores canhões."],
		],
	},
	ORBITA: {
		"before": [
			[ORBITA, "Calculei a tua trajetória, BIT. Probabilidade de vitória: 3%."],
			[BIT, "Tenho uma amiga que diz que os números mentem."],
		],
		"won": [
			[ORBITA, "Erro de cálculo. Fascinante."],
			[ORBITA, "Dados sobre o próximo: FAÍSCA, caçador de tempestades. Os raios caem onde menos esperas. Protege a muralha."],
		],
		"lost": [
			[ORBITA, "Como previsto. Recalcula e volta."],
		],
	},
	FAISCA: {
		"before": [
			[FAISCA, "Sentes a eletricidade no ar? É a tempestade a chegar!"],
			[BIT, "Sinto… os meus circuitos todos a tremer."],
		],
		"won": [
			[FAISCA, "Uau! Tens mais voltagem do que parece."],
			[FAISCA, "Cuidado: o próximo é o MAGNUS. É o capanga do ECLIPSE, e tem ordens para te tirar do torneio."],
		],
		"lost": [
			[FAISCA, "Curto-circuito! Carrega as baterias e tenta outra vez."],
		],
	},
	MAGNUS: {
		"before": [
			[MAGNUS, "O mestre ECLIPSE mandou-me acabar com a tua pequena aventura, BIT."],
			[BIT, "Então é verdade: é o ECLIPSE que anda a sabotar o torneio."],
			[MAGNUS, "O mestre fica com a taça. Tu ficas com a sucata. Bazuca pronta!"],
		],
		"won": [
			[MAGNUS, "Impossível… um robô comum…"],
			[MAGNUS, "O mestre não vai gostar. E o HÉLIO… o HÉLIO vai esmagar-te."],
			[BATIDA, "BIT, o HÉLIO é o campeão. A COROA SOLAR dele atravessa a arena inteira. Prepara-te."],
		],
		"lost": [
			[MAGNUS, "Como o mestre previu. Desiste, lata."],
		],
	},
	HELIO: {
		"before": [
			[HELIO, "Então és tu o BIT de quem todos falam. Mostra-me o que vales, pequeno."],
			[BIT, "Estou pronto, campeão."],
			[HELIO, "Ninguém está pronto para o sol."],
		],
		# Win or lose, HÉLIO teaches BIT the RAIO DE ELITE (see "teach").
		"lost": [
			[HELIO, "…Isto não foi justo. Tu não tens ultimate, e eu usei a minha contra ti."],
			[HELIO, "Mas vi como lutaste com tão pouco. Tens mais coração do que muitos campeões."],
		],
		"won": [
			[HELIO, "Venceste-me sem ultimate… Incrível. Mas contra o ECLIPSE não vai chegar."],
		],
		"teach": [
			[HELIO, "O ECLIPSE anda a destruir este torneio. Não posso deixar que ganhe."],
			[HELIO, "Vou ensinar-te o meu raio solar. Mais pequeno e mais fino do que o meu… mas é teu: o RAIO DE ELITE."],
			[NARRADOR, "O BIT ganhou a skin BIT DE ELITE, com a ultimate RAIO DE ELITE."],
			[BATIDA, "BIT! Estás… brilhante! Agora vai à final e acaba com o ECLIPSE."],
			[BIT_ELITE, "Por todos os que ele sabotou. E pelas propinas!"],
		],
	},
	ECLIPSE: {
		"before": [
			[ECLIPSE, "Então o robô de série chegou à final. Com um brilho emprestado."],
			[BIT_ELITE, "Sabotaste pilotos e pagaste a capangas. Hoje acaba, ECLIPSE."],
			[ECLIPSE, "A minha singularidade engole tudo. Até a tua luz."],
		],
		"won": [
			[ECLIPSE, "Não… a minha singularidade… vencida por um estudante?"],
			[NARRADOR, "O BIT DE ELITE vence a TAÇA CHARGE ARENA!"],
			[HELIO, "Bem feito, BIT. A arena está limpa outra vez."],
			[BATIDA, "CAMPEÃO! O prémio chega para a universidade e ainda sobra para uma festa!"],
			[BIT_ELITE, "E desta vez… vou conduzir devagar."],
			[NARRADOR, "FIM. Obrigado por jogares! No DIFÍCIL, os chefes voltam com as suas skins difíceis."],
		],
		"lost": [
			[ECLIPSE, "Luz emprestada apaga-se depressa. Volta quando quiseres perder outra vez."],
			[HELIO, "Não desistas, BIT. Usa o RAIO DE ELITE quando ele abrir a singularidade."],
		],
	},
}

static func lines(boss: int, moment: String) -> Array:
	var out: Array = []
	for line in LINES.get(boss, {}).get(moment, []):
		out.append(Array(line).duplicate())
	# Beaten, the rival says its first words dazed.
	if moment == "won" and not out.is_empty() and int(out[0][0]) == boss:
		out[0].append("hit")
	return out

static func speaker_name(who: int) -> String:
	match who:
		NARRADOR: return ""
		AGENTE: return "AGENTE"
	return String(preload("res://scripts/skins.gd").CATALOG[who].name)
