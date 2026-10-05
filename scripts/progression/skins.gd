extends RefCounted
## Cosmetic pilot skins. Every skin but the first is a campaign boss: beating its level
## unlocks it. Progress stays on this device.
const CONFIG_PATH = "user://skins.cfg"
const SHOT_SOUND = "res://audio/sfx/premium/shot_%d_0.wav"
# "level" is the campaign level (2-11) whose boss wears the skin; 0 means always owned.
# "ultimate" is the power in the third slot (see Powers.ULTIMATES); "" while one is missing.
# Level 1 is a training bout against a copy of the standard pilot, so it unlocks nothing.
# Empty colours fall back to the team colour, so each side stays readable.
# Each skin also restyles its team's bricks ("bricks" names that theme).
const CATALOG = [
	{"name": "BIT", "ultimate": "", "weapon": "Canhão de Braço", "bricks": "Monitores retro", "about": "O robô de série do circuito: cabeça-ecrã com sorriso, antena de sinal e um canhão de braço fiável.", "level": 0,
		"body": "", "light": "", "shot": ""},
	{"name": "SALVO", "ultimate": "volley", "weapon": "Lança-Mísseis Duplo", "bricks": "Caixas de munição", "about": "Artilheiro de oficina: cabeça larga com pega, lança-mísseis no ombro, braço pesado e cano duplo.", "level": 2,
		"body": "2e4270", "light": "ffb35c", "shot": "ffb35c"},
	{"name": "ÓRBITA", "ultimate": "meteors", "weapon": "Luneta de Plasma", "bricks": "Observatórios", "about": "Cartógrafa do céu: parabólica de lado, anel planetário a girar, asas nos ombros e um propulsor em vez de pernas.", "level": 9,
		"body": "5b50c4", "light": "c6a8ff", "shot": "c6a8ff"},
	{"name": "BROTO", "ultimate": "bloom", "weapon": "Semeador", "bricks": "Jarros mecânicos", "about": "Jardineiro de estufa: folhas como orelhas, vaso às costas, rodas nos pés e semeador de sementes de luz.", "level": 6,
		"body": "78bd57", "light": "d8ff8a", "shot": "b8f070"},
	{"name": "BIGORNA", "ultimate": "plating", "weapon": "Perfuradora", "bricks": "Bigornas de forja", "about": "Pesado de estaleiro: cabeça-visor com pirilampo, faixas de perigo, lagartas de tanque e broca.", "level": 3,
		"body": "f2b91c", "light": "ff9f2e", "shot": "ffb02e"},
	{"name": "ECLIPSE", "ultimate": "singularity", "weapon": "Canhão de Anel", "bricks": "Monólitos do eclipse", "about": "O executor: tronco blindado, ombreiras maciças, visor sob a sobrancelha em V e o núcleo do eclipse no peito. Fala pouco e não perdoa.", "level": 10,
		"body": "27272f", "light": "ff3b4d", "shot": "ff4f5e"},
	{"name": "ROSCA", "ultimate": "sentries", "weapon": "Minigun de Rebites", "bricks": "Caixas de engrenagens", "about": "Engenheiro da oficina e o mecânico mais rápido do circuito: capacete de obra com lanterna e óculos de soldar, fato-macaco com faixas refletoras, cinto de ferramentas e chave inglesa na mão. Monta sentinelas de minigun em segundos.", "level": 5,
		"body": "2b5d8a", "light": "ffc21a", "shot": "ffc21a"},
	{"name": "FAÍSCA", "ultimate": "thunder", "weapon": "Bobina de Tesla", "bricks": "Geradores de Tesla", "about": "Caçador de tempestades: espigões de raio na cabeça, pernas de pássaro, bobina às costas e visor que varre.", "level": 8,
		"body": "2f7de0", "light": "7ff4ff", "shot": "8aeeff"},
	{"name": "BATIDA", "ultimate": "surge", "weapon": "Seringa de Choque", "bricks": "Caixas de primeiros socorros", "about": "Enfermeira do circuito e amiga do BIT: cabeça de monitor de hospital num braço articulado, com a touca e a cruz vermelha, tronco em cápsula de comprimido, estetoscópio e mochila médica com dois frascos acesos. Dispara com uma seringa gigante e a SOBRECARGA é uma dose de adrenalina.", "level": 4,
		"body": "e23a4e", "light": "4ff2c8", "shot": "4ff2c8"},
	{"name": "GANCHO", "ultimate": "plunder", "weapon": "Bacamarte de Gancho", "bricks": "Baús de pirata", "about": "Pirata das rotas: capuz de lona, capa rasgada, um só olho e bacamarte com gancho.", "level": 7,
		"body": "c2472e", "light": "ffcf5a", "shot": "ffc84a"},
	{"name": "HÉLIO", "ultimate": "sun_ray", "weapon": "Cetro Solar", "bricks": "Obeliscos solares", "about": "Senhor do circuito: coroa de raios a girar, asas nos ombros, núcleo solar e cetro com um sol.", "level": 11,
		"body": "f0b429", "light": "ffe36a", "shot": "fff06a"},
	{"name": "MAGNUS", "ultimate": "b_forge", "weapon": "Manopla Imperial", "bricks": "Bastiões imperiais", "about": "Quatro títulos, um nome nas capas: armadura azul-real e ouro, louros a girar e capa de campeão.", "level": 0,
		"body": "27387c", "light": "ffd477", "shot": "ffd477"},
	# Modo difícil da história: o mesmo chefe, outra cor e alguns adereços. "hard_of" é o
	# chefe; vencê-lo no difícil desbloqueia esta skin.
	{"name": "SALVO BLINDADO", "ult_color": "c6ff3a", "ultimate": "volley", "weapon": "Lança-Mísseis Duplo", "bricks": "Caixas de munição", "hard_of": 1, "level": -1, "about": "Artilheiro de guerra: verde-militar e latão, um segundo casulo de mísseis e cartucheira às costas.",
		"body": "5b6b3a", "light": "ff6a2a", "shot": "ff6a2a"},
	{"name": "ÓRBITA DOURADA", "ult_color": "ffd76a", "ultimate": "meteors", "weapon": "Luneta de Plasma", "bricks": "Observatórios", "hard_of": 2, "level": -1, "about": "Navegadora do espaço fundo: azul-noite e ouro, anel orbital às costas com três satélites.",
		"body": "1f2a5c", "light": "ffd76a", "shot": "ffd76a"},
	{"name": "BROTO SELVAGEM", "ult_color": "3dffa8", "ultimate": "bloom", "weapon": "Semeador", "bricks": "Jarros mecânicos", "hard_of": 3, "level": -1, "about": "A estufa virou selva: verde-escuro e musgo, folhas grandes na cabeça, uma flor e um arbusto com trepadeiras.",
		"body": "2f6b3a", "light": "b6ff5a", "shot": "b6ff5a"},
	{"name": "BIGORNA DE FORJA", "ult_color": "ff4a1c", "ultimate": "plating", "weapon": "Perfuradora", "bricks": "Bigornas de forja", "hard_of": 4, "level": -1, "about": "Direto da forja: aço escuro e brasa, duas chaminés acesas às costas e faróis nos ombros.",
		"body": "3a3d44", "light": "ff6a1a", "shot": "ff6a1a"},
	{"name": "ECLIPSE RUBRO", "ult_color": "ff1f5a", "ultimate": "singularity", "weapon": "Lança de Anel", "bricks": "Monólitos do eclipse", "hard_of": 5, "level": -1, "about": "Eclipse de sangue: carmesim e negro, um sol negro com lâminas às costas e coroa de espigões.",
		"body": "5a1a24", "light": "ff2a3c", "shot": "ff2a3c"},
	{"name": "ROSCA TURBO", "ult_color": "3fd0ff", "ultimate": "sentries", "weapon": "Minigun de Rebites", "bricks": "Caixas de engrenagens", "hard_of": 6, "level": -1, "about": "Engenheiro de corrida: azul-aço e amarelo, chave inglesa gigante às costas e um pirilampo em cada ombro.",
		"body": "3f6f8f", "light": "ffd34a", "shot": "ffd34a"},
	{"name": "FAÍSCA TEMPESTADE", "ult_color": "fff04a", "ultimate": "thunder", "weapon": "Bobina de Tesla", "bricks": "Geradores de Tesla", "hard_of": 7, "level": -1, "about": "O olho da tempestade: cinza de trovoada e amarelo, dois para-raios gigantes e coroa de raios.",
		"body": "2a2f3a", "light": "fff04a", "shot": "fff04a"},
	{"name": "BATIDA NEON", "ult_color": "4ff0ff", "ultimate": "surge", "weapon": "Seringa de Choque", "bricks": "Caixas de primeiros socorros", "hard_of": 8, "level": -1, "about": "O turno da noite, corrompido: roxo-noite e ciano, touca alta com a cruz acesa, soro aceso num suporte às costas e pás de desfibrilhador à cintura.",
		"body": "3a2a5c", "light": "4ff0ff", "shot": "4ff0ff"},
	{"name": "GANCHO NEGRO", "ult_color": "5aff9d", "ultimate": "plunder", "weapon": "Bacamarte de Gancho", "bricks": "Baús de pirata", "hard_of": 9, "level": -1, "about": "O capitão temido: negro e ouro, tricórnio inclinado com uma gema acesa, um mastro com a bandeira negra e lanternas acesas no mastro e à anca.",
		"body": "23262e", "light": "ffcf5a", "shot": "ffcf5a"},
	{"name": "HÉLIO POENTE", "ult_color": "ff6a2a", "ultimate": "sun_ray", "weapon": "Cetro Solar", "bricks": "Obeliscos solares", "hard_of": 10, "level": -1, "about": "O sol a pôr-se: vermelho-poente e ouro, com um sol inteiro de raios atrás das asas.",
		"body": "c8452a", "light": "ff8a2a", "shot": "ff8a2a"},
	{"name": "BIT DE ELITE", "ult_color": "ffe45c", "ultimate": "sun_beam", "weapon": "Canhão de Braço", "bricks": "Monitores retro", "hard_of": 0, "level": -1, "about": "O robô de série, afinado para a elite: marfim, ouro e sol, como o HÉLIO e o MAGNUS IMPERADOR, com uma coroa solar de néon, bateria de três células acesas com a luz do sol que o HÉLIO lhe ensinou, escapes e aletas de luz.",
		"body": "fff1d0", "light": "ffcf4a", "shot": "ffcf4a"},
	{"name": "MAGNUS IMPERADOR", "ult_color": "ffcf4a", "ultimate": "b_forge", "weapon": "Manopla Imperial", "bricks": "Bastiões imperiais", "hard_of": 11, "level": -1, "about": "O campeão coroado: marfim e ouro, coroa com gemas acesas, dois estandartes e a estrela do Penta acesa às costas.",
		"body": "ece6d8", "light": "ffcf4a", "shot": "ffcf4a"},
]
# Testing build: every skin can be worn without beating its boss first. Set to false to
# earn them again; the bosses you have beaten are saved either way.
const UNLOCK_ALL_FOR_TESTS = false
# Saves written by the old unlocked test builds have every pilot already won. The demo
# refuses to read them, so a run starts with the standard pilot alone.
const SAVE_VERSION = 2

var config_path = CONFIG_PATH
var unlock_all = UNLOCK_ALL_FOR_TESTS
var defeated: Array = []
# Skins won but not yet opened in the panel: the menu points at them until it is.
var seen: Array = []
var selected = 0
# Story mode: who has fallen, "n<skin>" in NORMAL and "h<skin>" in DIFÍCIL.
var story_won: Array = []

static func colors(index: int, team_color: Color, boss_tint: bool = false) -> Dictionary:
	# boss_tint: campaign bosses fight in their team's red until beaten.
	if boss_tint:
		return {"body": team_color.darkened(0.3), "light": team_color.lightened(0.3), "shot": team_color}
	var entry: Dictionary = CATALOG[clampi(index, 0, CATALOG.size() - 1)]
	return {
		"body": Color(entry.body) if entry.body != "" else team_color,
		"light": Color(entry.light) if entry.light != "" else team_color.lightened(0.3),
		"shot": Color(entry.shot) if entry.shot != "" else team_color,
	}

static func ultimate_color(index: int) -> String:
	# A hard-mode skin paints its ultimate in a colour of its own ("" keeps the power's).
	if index >= 0 and index < CATALOG.size():
		return String(CATALOG[index].get("ult_color", ""))
	return ""

static func base_of(index: int) -> int:
	# A hard-mode skin sounds and plays like its boss.
	if index >= 0 and index < CATALOG.size():
		return int(CATALOG[index].get("hard_of", index))
	return index

static func hard_of_boss(boss: int) -> int:
	# The hard-mode skin of a boss, or -1.
	for index in range(CATALOG.size()):
		if int(CATALOG[index].get("hard_of", -1)) == boss:
			return index
	return -1

static func boss_skin(level: int) -> int:
	# The skin worn by the boss of campaign level `level` (1-10), or -1.
	for index in range(CATALOG.size()):
		if CATALOG[index].level == level and level > 0:
			return index
	return -1

func is_unlocked(index: int) -> bool:
	return index >= 0 and index < CATALOG.size() and (unlock_all or index == 0 or defeated.has(index))

func unseen() -> Array:
	# Won and not yet looked at. The starter pilot is never news.
	return range(CATALOG.size()).filter(func(i): return i > 0 and is_unlocked(i) and not seen.has(i))

func mark_seen() -> void:
	for index in range(CATALOG.size()):
		if is_unlocked(index) and not seen.has(index):
			seen.append(index)

func unlocked_count() -> int:
	return range(CATALOG.size()).filter(is_unlocked).size()

func defeat(index: int) -> bool:
	# Returns true when beating this boss unlocked its skin for the first time.
	if index <= 0 or index >= CATALOG.size() or is_unlocked(index):
		return false
	defeated.append(index)
	return true

func select(index: int) -> bool:
	if not is_unlocked(index):
		return false
	selected = index
	return true

func load_preferences() -> void:
	var config = ConfigFile.new()
	if config.load(config_path) != OK:
		return
	if int(config.get_value("skins", "version", 1)) < SAVE_VERSION:
		return
	defeated = []
	for index in Array(config.get_value("skins", "defeated", [])):
		if index is int and index > 0 and index < CATALOG.size() and not defeated.has(index):
			defeated.append(index)
	story_won = Array(config.get_value("skins", "story_won", [])).filter(func(k): return k is String)
	seen = Array(config.get_value("skins", "seen", [])).filter(func(i): return i is int and i >= 0 and i < CATALOG.size())
	var saved = int(config.get_value("skins", "selected", 0))
	selected = saved if is_unlocked(saved) else 0

func save_preferences() -> Error:
	var config = ConfigFile.new()
	config.set_value("skins", "version", SAVE_VERSION)
	config.set_value("skins", "defeated", defeated)
	config.set_value("skins", "seen", seen)
	config.set_value("skins", "story_won", story_won)
	config.set_value("skins", "selected", selected)
	return config.save(config_path)
