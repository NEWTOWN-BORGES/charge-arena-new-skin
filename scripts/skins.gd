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
	{"name": "BIT", "ultimate": "", "weapon": "Canhão de Braço", "bricks": "Baterias Aurora", "about": "O robô de série do circuito: cabeça-ecrã, antena de sinal e um canhão de braço fiável.", "level": 0,
		"body": "", "light": "", "shot": ""},
	{"name": "SALVO", "ultimate": "volley", "weapon": "Lança-Mísseis Duplo", "bricks": "Farolins", "about": "Artilheiro de oficina: pega de transporte na cabeça, casulo de mísseis no ombro e cano duplo.", "level": 2,
		"body": "f07a2e", "light": "ffb35c", "shot": "ffb35c"},
	{"name": "ÓRBITA", "ultimate": "meteors", "weapon": "Luneta de Plasma", "bricks": "Observatórios", "about": "Cartógrafo do céu: parabólica de lado, anel planetário à volta da cabeça e luneta de longo alcance.", "level": 9,
		"body": "4b4fa3", "light": "c6a8ff", "shot": "c6a8ff"},
	{"name": "BROTO", "ultimate": "bloom", "weapon": "Semeador", "bricks": "Estufas", "about": "Jardineiro de estufa: rebento na antena, vaso às costas, rodas nos pés e semeador de sementes de luz.", "level": 6,
		"body": "5f9a4a", "light": "a8f06a", "shot": "a8f06a"},
	{"name": "BIGORNA", "ultimate": "plating", "weapon": "Perfuradora", "bricks": "Veios de cristal", "about": "Pesado de estaleiro: ombreiras em bloco, faixas de perigo, tanques às costas e broca na ponta do braço.", "level": 3,
		"body": "f2c12e", "light": "ffd24a", "shot": "ffd24a"},
	{"name": "ECLIPSE", "ultimate": "singularity", "weapon": "Lança de Anel", "bricks": "Monólitos Eclipse", "about": "Guarda de elite: chifres varridos, halo de eclipse atrás da cabeça e lança com anel de luz.", "level": 10,
		"body": "33343f", "light": "b48cff", "shot": "c9a6ff"},
	{"name": "ROSCA", "ultimate": "sentries", "weapon": "Rebitadora", "bricks": "Relógios de torre", "about": "Mecânica de bancada: olho de lupa, caixa de ferramentas às costas, rodas nos pés e rebitadora de molas.", "level": 5,
		"body": "d5773a", "light": "ffb050", "shot": "ffb050"},
	{"name": "FAÍSCA", "ultimate": "thunder", "weapon": "Bobina de Tesla", "bricks": "Para-raios", "about": "Caçador de tempestades: para-raios na cabeça, bobina às costas e um visor que varre o céu.", "level": 8,
		"body": "4a6fa5", "light": "6ff0ff", "shot": "8aeeff"},
	{"name": "BATIDA", "ultimate": "surge", "weapon": "Megafone de Choque", "bricks": "Alambiques", "about": "DJ do circuito: crista de néon, colunas nos ombros e um megafone que dispara ao ritmo.", "level": 4,
		"body": "ea3e8c", "light": "ff5cc0", "shot": "ff5cc0"},
	{"name": "GANCHO", "ultimate": "plunder", "weapon": "Bacamarte de Gancho", "bricks": "Arcas do tesouro", "about": "Pirata das rotas: capuz de lona, capa rígida, um só olho e bacamarte de boca larga.", "level": 7,
		"body": "8e2b2b", "light": "ff4f6a", "shot": "ff4f7e"},
	{"name": "HÉLIO", "ultimate": "sun_ray", "weapon": "Cetro Solar", "bricks": "Obeliscos solares", "about": "Senhor do circuito: coroa de raios a girar, placas de marfim e ouro e um cetro com um sol.", "level": 11,
		"body": "f0b429", "light": "ffe36a", "shot": "fff06a"},
	{"name": "MAGNUS", "ultimate": "b_forge", "weapon": "Manopla Imperial", "bricks": "Emblemas do Penta", "about": "Quatro títulos, um nome nas capas: louros a girar, capa de campeão, armadura de marfim e ouro.", "level": 0, "cup_reward": true,
		"body": "d9a441", "light": "ffd477", "shot": "ffd477"},
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
	seen = Array(config.get_value("skins", "seen", [])).filter(func(i): return i is int and i >= 0 and i < CATALOG.size())
	var saved = int(config.get_value("skins", "selected", 0))
	selected = saved if is_unlocked(saved) else 0

func save_preferences() -> Error:
	var config = ConfigFile.new()
	config.set_value("skins", "version", SAVE_VERSION)
	config.set_value("skins", "defeated", defeated)
	config.set_value("skins", "seen", seen)
	config.set_value("skins", "selected", selected)
	return config.save(config_path)
