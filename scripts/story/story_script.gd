extends RefCounted
## The story of the Modo história (NORMAL): BIT, a university robot who spent his tuition on
## a speeding fine, enters the Taça Charge Arena to win the prize money. Each boss has lines
## before the match and after it (won or lost); the speaker is a skin index, AGENTE (the
## traffic officer), LOCUTOR (VOLTZ, the tournament's announcer), NARRADOR (a caption with
## no portrait) or SCENE (a chapter card that changes the backdrop).

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

# Scene cards: [SCENE, title, {"bg": backdrop, "chapter": small label, "place": where and when}].
# A line may carry options as a third element: {"mood": "hit"} (dazed face), {"phone": true}
# (heard over the phone), {"fx": "siren" / "shake"}.
const SCENE = -3
# The fight card shown right before a match: [VERSUS, "", {"left", "right", "round", "place", ...}].
const VERSUS = -5
const LOCUTOR = -4

# Chapters 1 to 3: the fine, the phone call and the way to the training arena. The training
# match with BATIDA (the game's tutorial) comes right after them.
const INTRO = [
	[SCENE, "A MULTA", {"bg": "rua", "chapter": "CAPÍTULO 1", "place": "Avenida de Voltara · 19:42"}],
	[NARRADOR, "Voltara, a cidade dos robôs. Fim de tarde, hora de ponta."],
	[NARRADOR, "O BIT, estudante de engenharia na Universidade de Voltara, vem das aulas… e vai atrasado."],
	[BIT, "Vou chegar tarde outra vez! Só um bocadinho mais depressa…"],
	[NARRADOR, "UIII-UUU! UIII-UUU!", {"fx": "siren"}],
	[AGENTE, "Alto! Encoste à direita, robô modelo BIT.", {"fx": "siren"}],
	[BIT, "Senhor agente… eu ia só um bocadinho depressa."],
	[AGENTE, "92 km/h numa zona de 50. A multa é de 800 créditos, a pagar já."],
	[BIT, "800?! Mas… esse é o dinheiro das propinas da universidade!", {"mood": "hit", "fx": "shake"}],
	[AGENTE, "Regras são regras. Conduza com cuidado."],
	[NARRADOR, "O BIT pagou a multa. E ficou sem nada para pagar a universidade."],
	[SCENE, "UMA CHAMADA", {"bg": "quarto", "chapter": "CAPÍTULO 2", "place": "Casa do BIT · 21:15"}],
	[BIT, "As propinas acabam no fim do mês… Se não pagar, perco o curso."],
	[BIT, "Tenho de ligar à BATIDA. Ela sabe sempre o que fazer."],
	[BATIDA, "BIT? A esta hora? Que se passa?", {"phone": true}],
	[BIT, "Fui multado. Paguei com o dinheiro das propinas… Fiquei sem nada."],
	[BATIDA, "Ai, ai, BIT… Espera! Viste as notícias? Vai começar a TAÇA CHARGE ARENA!", {"phone": true}],
	[BATIDA, "O prémio paga a universidade e ainda sobra. Eu sou pilota, posso inscrever-te!", {"phone": true}],
	[BIT, "Eu? Numa arena? Sou um robô comum, não sou de combate. Não tenho habilidades especiais, nem ultimate…"],
	[BATIDA, "Tens um canhão e tens cabeça. Os tijolos que partes na arena viram créditos na LOJA DE PODERES, e aprendes habilidades novas pelo caminho.", {"phone": true}],
	[BIT, "Não sei, BATIDA… E se eu faço figura de parvo à frente do estádio inteiro?"],
	[BATIDA, "Faz assim: amanhã de manhã vens treinar comigo ao Circuito Aurora. Se não gostares, esquecemos. Combinado?", {"phone": true}],
	[BIT, "…Combinado."],
	[SCENE, "O TREINO", {"bg": "treino", "chapter": "CAPÍTULO 3", "place": "Circuito Aurora · 09:00 do dia seguinte"}],
	[BATIDA, "Bom dia, campeão! Bem-vindo ao Circuito Aurora, a arena de treino."],
	[BATIDA, "Vou-te mostrar como se joga. Parte a minha muralha e mete a bola na minha baliza. Quem marcar 2 golos ganha!"],
	[BIT, "Está bem… Vamos a isso."],
]

# After the training match, whatever the result.
const TRAINING_WON = [
	[BATIDA, "Uau! Ganhaste-me à primeira! Tens jeito, BIT. Muito mais jeito do que eu pensava.", {"mood": "hit"}],
]
const TRAINING_LOST = [
	[BATIDA, "Nada mal para a primeira vez! A sério, BIT: tens jeito para isto."],
]
const TRAINING_AFTER = [
	[BATIDA, "Está decidido: vou inscrever-te na TAÇA. A cerimónia de abertura é amanhã!"],
	[BIT, "Amanhã?! …Está bem. Pelas propinas!"],
]

# Chapter 4: the opening ceremony. VOLTZ, the tournament's announcer, calls BIT's first fight.
const OPENING = [
	[SCENE, "A TAÇA", {"bg": "estadio", "chapter": "CAPÍTULO 4", "place": "Estádio de Voltara · Cerimónia de abertura"}],
	[LOCUTOR, "SENHORAS E SENHORES, ROBÔS DE TODAS AS IDADES… BEM-VINDOS À TAÇA CHARGE ARENA!", {"fx": "shake"}],
	[LOCUTOR, "Eu sou o VOLTZ, a vossa voz na arena! E este ano há novidades: arenas novas, poderes novos… e o maior prémio de sempre!"],
	[LOCUTOR, "As regras são simples: parte a muralha do adversário e mete a bola na baliza dele. Quem marcar 2 golos passa à ronda seguinte."],
	[LOCUTOR, "Os tijolos que partires são teus: entre combates, troca-os por habilidades na LOJA DE PODERES."],
	[LOCUTOR, "Hoje há combates em todas as arenas da cidade! Mas há um estreante de quem toda a gente fala…"],
	[BIT, "Um estreante de quem toda a gente fala? …Ai. Sou eu."],
	[LOCUTOR, "Na Oficina do Relógio: o mecânico mais rápido do circuito, ROSCA… contra o estudante estreante, BIT! QUE COMECE O COMBATE!", {"fx": "shake"}],
]

# The old one-scene prologue, kept for the recap's first lines of older saves.
const PROLOGUE = INTRO

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
			[BATIDA, "Luta a sério. Se me venceres, sei que chegas à final. No fim, eu trato-te das mazelas!"],
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
			[SCENE, "O CAMPEÃO", {"bg": "estadio", "chapter": "EPÍLOGO", "place": "Estádio de Voltara · Entrega da Taça"}],
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

# ==============================================================================
# DIFÍCIL - Temporada 2. Months later MAGNUS wrecks the city, dark and corrupted; BIT, the
# only arena pilot there, takes him on. Freed, MAGNUS IMPERADOR (HÉLIO's old right hand)
# becomes his ally. The other pilots have vanished and come back to the tournament as dark
# silhouettes; BIT beats them one by one, BATIDA the last surprise before ECLIPSE. ECLIPSE
# was not behind it this time: the corruption came from HÉLIO, who swallowed the singularity
# at the end of the first Taça. Beating HÉLIO in the final gives everyone their memory back.
# In DIFÍCIL the rivals fight in their hard skins: a line with {"face": "dark"} is a corrupted
# friend, shown in that hard skin (its portrait, name and colour) with a deeper voice. The
# twist: MAGNUS wrecks the city in his usual skin; only once BIT beats him does the armour
# fall and MAGNUS IMPERADOR, his true form, step out.
const MAGNUS_IMP = 23
const HELIO_POENTE = 21
const BATIDA_NEON = 19
const ORDER_HARD = [MAGNUS, ROSCA, SALVO, BIGORNA, BROTO, GANCHO, ORBITA, FAISCA, BATIDA, ECLIPSE, HELIO]
const FINAL_HARD = HELIO
# Where each season-two fight happens: the corrupted worlds (arena_theme.gd DARK_THEMES).
const S2_WORLD = {MAGNUS: "cidade_negra", ROSCA: "vale_corrompido", SALVO: "abismo_neon", BIGORNA: "vale_corrompido",
	BROTO: "aurora_sombria", GANCHO: "abismo_neon", ORBITA: "eclipse_orbital", FAISCA: "aurora_sombria",
	BATIDA: "cidade_negra", ECLIPSE: "eclipse_orbital", HELIO: "aurora_sombria"}
const DARK = {"face": "dark"}

const S2_INTRO = [
	[SCENE, "O REGRESSO", {"bg": "cidade", "chapter": "TEMPORADA 2 · CAPÍTULO 1", "place": "Centro de Voltara · meses depois"}],
	[NARRADOR, "Meses depois da Taça. O BIT pagou a universidade, voltou às aulas… e Voltara parecia em paz."],
	[NARRADOR, "BUUUM!", {"fx": "shake"}],
	[BIT_ELITE, "O que foi isto?! Vem do centro da cidade!"],
	[NARRADOR, "Hologramas a cair, carros virados, alarmes por todo o lado. E no meio do caos, uma figura enorme e escura.", {"fx": "siren"}],
	[MAGNUS, "SUCATA… TUDO SUCATA… A CIDADE TEM DE FICAR EM SILÊNCIO.", {"face": "dark", "fx": "shake"}],
	[BIT_ELITE, "O MAGNUS?! Está diferente… a armadura, os olhos… está todo escuro."],
	[AGENTE, "Civis, afastem-se! Já chamámos os pilotos de arena, estão a caminho!", {"fx": "siren"}],
	[BIT_ELITE, "Não há tempo para esperar pelos mais experientes. Sou o único piloto de arena aqui."],
	[BIT_ELITE, "MAGNUS! Aqui! Se queres uma luta, é comigo!"],
	[MAGNUS, "O ESTUDANTE… DISSERAM-ME QUE VIRIAS.", {"face": "dark"}],
]

const S2_AFTER_MAGNUS = [
	[MAGNUS, "Argh… a minha cabeça… que luz é esta…?", {"face": "dark", "mood": "hit"}],
	[NARRADOR, "A armadura do MAGNUS estala e cai aos pedaços. Por baixo, marfim e ouro: MAGNUS IMPERADOR, a sua forma verdadeira.", {"fx": "shake"}],
	[BIT_ELITE, "Espera… o MAGNUS que todos conhecíamos era só uma armadura?!"],
	[MAGNUS_IMP, "Onde… onde estou? Tu és… o BIT? O campeão da Taça?"],
	[BIT_ELITE, "MAGNUS? Estavas a destruir a cidade! O que te aconteceu?"],
	[MAGNUS_IMP, "Aquela carapaça nunca fui eu. Antes do ECLIPSE, eu era o braço direito do HÉLIO. Treinávamos ao nascer do sol; estas cores douradas são as do sol dele."],
	[MAGNUS_IMP, "Mas não me lembro de nada… Um dia estava ao lado do HÉLIO; no dia seguinte, estava contra ele e contra todos."],
	[BIT_ELITE, "Senhor agente! Onde estão os outros pilotos de arena?"],
	[AGENTE, "Ninguém sabe. Desapareceram todos. A segunda temporada da Taça vai começar e não há sinal de nenhum piloto de arena."],
	[SCENE, "SEM SINAL", {"bg": "quarto", "chapter": "TEMPORADA 2 · CAPÍTULO 2", "place": "Casa do BIT · nessa noite"}],
	[BIT_ELITE, "Vou ligar à BATIDA. Ela sabe sempre o que fazer…"],
	[NARRADOR, "« O número para que ligou não está disponível. »  Sem sinal."],
	[BIT_ELITE, "E o HÉLIO…? Nada. Também sem sinal."],
	[MAGNUS_IMP, "Eu fico contigo, BIT. Devo-te isso. Vamos descobrir o que se passa."],
	[SCENE, "A SEGUNDA TEMPORADA", {"bg": "estadio", "chapter": "TEMPORADA 2 · CAPÍTULO 3", "place": "Estádio de Voltara · dias depois"}],
	[LOCUTOR, "BEM-VINDOS À SEGUNDA TEMPORADA DA TAÇA CHARGE ARENA!", {"fx": "shake"}],
	[LOCUTOR, "Este ano temos… participantes misteriosos. Ninguém sabe os seus nomes."],
	[NARRADOR, "Um a um, os participantes entram na arena: silhuetas escuras, com luzes a arder onde deviam estar os olhos.", {"fx": "lineup"}],
	[MAGNUS_IMP, "BIT… aquelas formas, eu conheço-as. São os teus amigos. Estão como eu estava: corrompidos."],
	[BIT_ELITE, "Então vou vencê-los um a um. Para os trazer de volta."],
]

const S2_LINES = {
	MAGNUS: {
		"lost": [
			[MAGNUS, "SUCATA. COMO TODOS OS OUTROS.", {"face": "dark"}],
			[AGENTE, "Recua, miúdo! Reagrupa e tenta outra vez: ele ainda está aqui."],
		],
	},
	ROSCA: {
		"before": [
			[LOCUTOR, "Primeiro combate: o campeão da temporada passada, o BIT DE ELITE… contra a sombra do ROSCA!"],
			[ROSCA, "Vruum… a tua sucata vai ser minha, estudante.", DARK],
			[BIT_ELITE, "ROSCA, sou eu, o BIT! Não te lembras?"],
		],
		"won": [
			[ROSCA, "…BIT? Não… não me lembro de ti. Só de uma luz… quente demais.", {"face": "dark", "mood": "hit"}],
			[MAGNUS_IMP, "Também eu me lembro de uma luz. Vamos continuar."],
		],
		"lost": [[ROSCA, "Vruum. Próximo.", DARK]],
	},
	SALVO: {
		"before": [
			[SALVO, "Alvo identificado. Ordens: eliminar.", DARK],
			[BIT_ELITE, "Ordens de quem, SALVO?"],
		],
		"won": [
			[SALVO, "Ordens… de quem? Não sei de quem são as minhas ordens.", {"face": "dark", "mood": "hit"}],
		],
		"lost": [[SALVO, "Alvo neutralizado.", DARK]],
	},
	BIGORNA: {
		"before": [
			[BIGORNA, "A forja arde. E tu vais para o fogo.", DARK],
		],
		"won": [
			[BIGORNA, "A minha cabeça é um martelo a bater… deixa-me.", {"face": "dark", "mood": "hit"}],
			[MAGNUS_IMP, "Todos falam de fogo e de luz. Isto não é obra do ECLIPSE sozinho."],
		],
		"lost": [[BIGORNA, "Derretido. Como tudo o resto.", DARK]],
	},
	BROTO: {
		"before": [
			[BROTO, "As minhas flores… ficaram negras. Tu também vais ficar.", DARK],
			[BIT_ELITE, "BROTO… até tu."],
		],
		"won": [
			[BROTO, "Porque é que me sinto tão triste…?", {"face": "dark", "mood": "hit"}],
		],
		"lost": [[BROTO, "Murcha, pequena flor.", DARK]],
	},
	GANCHO: {
		"before": [
			[GANCHO, "Arr… o tesouro agora é do sol negro. E tu és a próxima presa.", DARK],
			[MAGNUS_IMP, "Sol negro… ouviste isto, BIT?"],
		],
		"won": [
			[GANCHO, "Perdi o rumo, marinheiro… não sei quem me deu este mapa.", {"face": "dark", "mood": "hit"}],
		],
		"lost": [[GANCHO, "Ao fundo do mar contigo.", DARK]],
	},
	ORBITA: {
		"before": [
			[ORBITA, "Probabilidade de resistires à escuridão: zero.", DARK],
		],
		"won": [
			[ORBITA, "Erro… os meus dados foram… reescritos.", {"face": "dark", "mood": "hit"}],
			[BIT_ELITE, "Reescritos por quem, ÓRBITA?"],
			[ORBITA, "Por uma luz… no céu. Uma luz que queima.", DARK],
		],
		"lost": [[ORBITA, "Como calculado.", DARK]],
	},
	FAISCA: {
		"before": [
			[FAISCA, "A tempestade agora é negra!", DARK],
		],
		"won": [
			[FAISCA, "Curto-circuito… na memória…", {"face": "dark", "mood": "hit"}],
			[LOCUTOR, "E agora, senhoras e senhores… uma participante que ninguém esperava!"],
		],
		"lost": [[FAISCA, "Trovão. Fim.", DARK]],
	},
	BATIDA: {
		"before": [
			[BATIDA, "…", DARK],
			[BIT_ELITE, "BATIDA?! Não… tu não!", {"mood": "hit", "fx": "shake"}],
			[BATIDA, "Não conheço nenhum BIT. Fica quieto… isto não vai doer nada.", DARK],
			[MAGNUS_IMP, "Ela não te reconhece, BIT. Vence-a: é a única maneira de a ajudar."],
		],
		"won": [
			[BATIDA, "BIT…? Esse nome soa-me a casa. Mas não sei porquê…", {"face": "dark", "mood": "hit"}],
			[BIT_ELITE, "Eu vou trazer-te de volta, BATIDA. Prometo."],
		],
		"lost": [[BATIDA, "Silêncio. Finalmente.", DARK]],
	},
	ECLIPSE: {
		"before": [
			[LOCUTOR, "SEMIFINAL! O vilão da temporada passada está de volta: o ECLIPSE!"],
			[BIT_ELITE, "Foste tu outra vez, ECLIPSE! Corrompeste toda a gente!"],
			[ECLIPSE, "Eu? Desta vez não, estudante… mas vou gostar de te apagar na mesma.", DARK],
		],
		"won": [
			[ECLIPSE, "Tolos… acham que acabou? A luz que os corrompeu não é minha. Olhem para o sol.", {"face": "dark", "mood": "hit"}],
			[NARRADOR, "O BIT venceu o ECLIPSE. Mas os amigos continuam sem memória. Nada voltou ao normal."],
			[MAGNUS_IMP, "O sol… Não pode ser. O HÉLIO."],
		],
		"lost": [[ECLIPSE, "A escuridão tem paciência.", DARK]],
	},
	HELIO: {
		"before": [
			[SCENE, "A FINAL", {"bg": "estadio", "chapter": "TEMPORADA 2 · FINAL", "place": "Estádio de Voltara · a grande final"}],
			[LOCUTOR, "A GRANDE FINAL! Do outro lado da arena… o finalista mistério!", {"fx": "shake"}],
			[HELIO, "Pequeno BIT. Ensinei-te o meu raio… agora vou apagá-lo.", DARK],
			[MAGNUS_IMP, "HÉLIO! Sou eu, o teu braço direito! Quando venceste o ECLIPSE, a singularidade dele ficou dentro de ti!"],
			[HELIO, "Então sabes o que vem aí. O sol negro vai engolir a Taça… e a memória de todos.", DARK],
			[BIT_ELITE, "Vou devolver a luz a todos. Até a ti, HÉLIO."],
		],
		"won": [
			[HELIO, "Esta luz… é a minha. A que te ensinei…", {"face": "dark", "mood": "hit"}],
			[NARRADOR, "O sol negro desfaz-se. Por todo o estádio, as silhuetas voltam a ganhar cor."],
			[SCENE, "A LUZ DE VOLTA", {"bg": "estadio", "chapter": "EPÍLOGO", "place": "Estádio de Voltara"}],
			[HELIO_POENTE, "BIT… o que é que eu fiz? Obrigado por me trazeres de volta."],
			[MAGNUS_IMP, "Bem-vindo de volta, mestre."],
			[BATIDA_NEON, "BIT! Lembro-me de tudo! Da multa, do treino… de ti!", {"fx": "shake"}],
			[BIT_ELITE, "Bem-vinda de volta, BATIDA."],
			[LOCUTOR, "O BIT DE ELITE É BICAMPEÃO DA TAÇA CHARGE ARENA!", {"fx": "shake"}],
			[NARRADOR, "FIM DA SEGUNDA TEMPORADA. Obrigado por jogares!"],
		],
		"lost": [
			[HELIO, "O sol nunca se põe para ti, pequeno.", DARK],
			[MAGNUS_IMP, "Levanta-te, BIT. Usa o RAIO DE ELITE: a luz dele também é tua."],
		],
	},
}

static func hard_lines(boss: int, moment: String) -> Array:
	var out: Array = []
	for line in S2_LINES.get(boss, {}).get(moment, []):
		var copy = Array(line).duplicate()
		if copy.size() > 2 and copy[2] is Dictionary:
			copy[2] = copy[2].duplicate()
		out.append(copy)
	return out

static func versus(left: int, right: int, step: int, total: int, place: String, rival_dark: bool = false) -> Array:
	# The fight card: BIT on the left, the rival on the right, the round and the arena.
	return [VERSUS, "", {"left": left, "right": right, "round": "RONDA %d DE %d" % [step + 1, total] if step >= 0 else "TREINO",
		"place": place, "dark": rival_dark}]

static func voice_key(who: int) -> String:
	# Hard skins speak with their boss's voice (BIT DE ELITE has its own).
	if who >= 0 and who != BIT_ELITE:
		var base = int(preload("res://scripts/progression/skins.gd").CATALOG[who].get("hard_of", -1))
		if base >= 0:
			return str(base)
	return face_key(who)

static func lines(boss: int, moment: String) -> Array:
	var out: Array = []
	for line in LINES.get(boss, {}).get(moment, []):
		out.append(Array(line).duplicate())
	# Beaten, the rival says its first words dazed.
	if moment == "won" and not out.is_empty() and int(out[0][0]) == boss:
		out[0].append({"mood": "hit"})
	return out

static func round_card(step: int, boss: int, arena_name: String, bg: String = "") -> Array:
	# The card that opens each round: the rival's name over its own arena.
	return [SCENE, speaker_name(boss), {"bg": bg if bg != "" else "arena_%d" % boss, "chapter": "RONDA %d DE %d" % [step + 1, ORDER.size()], "place": arena_name}]

static func face_key(who: int) -> String:
	match who:
		AGENTE: return "agente"
		LOCUTOR: return "locutor"
		NARRADOR, SCENE: return "narrador"
	return str(who)

static func speaker_name(who: int) -> String:
	match who:
		NARRADOR, SCENE: return ""
		AGENTE: return "AGENTE"
		LOCUTOR: return "VOLTZ"
	return String(preload("res://scripts/progression/skins.gd").CATALOG[who].name)
