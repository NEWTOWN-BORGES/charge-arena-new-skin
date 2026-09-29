extends RefCounted
## Environments for the arenas. Every map belongs to one of five: the floating sky deck, the
## countryside outpost, the seabed base, the orbital station and the city rooftop. Each colours
## the field and names the dressing that builds the world around it (scripts/arena_sky.gd,
## arena_ground.gd, arena_sea.gd, arena_space.gd, arena_city.gd). Rules never read this.
# A light field with crisp seams under saturated scenery, so every environment reads at a
# glance and the robots always stand out from the floor. The court floors are neutral greys
# with only a hint of their world, so every shot, power and ultimate reads against them;
# only the season-two neon worlds keep their dark coloured floors.
const ArtStyle = preload("res://scripts/art_style.gd")

const THEMES = {
	"aurora": {
		"name": "Arena Aurora",
		# The floating sky arena: a steel deck in the clouds.
		"dressing": "sky", "deck": Color("ff9f7a"), "deck_panel": Color("2f6fc0"), "hull": Color("3f7fd6"),
		"armour": Color("ffc94d"), "armour_trim": Color("ff6f5c"), "cushion": Color("fff0b8"),
		"floor": Color("d3d9e0"), "floor_alt": Color("c7ced7"), "seam": Color("8792a2"), "line": Color("5f6b7c"),
		"sky_top": Color("2f7fd0"), "sky_mid": Color("5fa8e6"), "sky_low": Color("d6eef6"),
		"block": Color("f6f2e8"), "block_alt": Color("2fc4a5"), "frame": Color("2a3140"), "accent": Color("ffc53d"),
		"stand": Color("4f6f8a"), "crowd": [Color("2fc4a5"), Color("ff7a5c"), Color("ffc53d"), Color("f6f2e8")],
	},
	"terra": {
		"name": "Posto Terrestre",
		# A concrete pad in a green valley, with sandstone terraces, pines, wind turbines,
		# solar farms, silos and a hangar.
		"dressing": "ground", "grass": Color("86d65a"), "grass_high": Color("78cb4e"), "cliff": Color("eaa566"),
		"dirt": Color("f1d08e"), "pad": Color("f0a86a"), "pad_panel": Color("c9542a"),
		"armour": Color("3fc6a6"), "armour_trim": Color("ff7a3c"), "cushion": Color("c8f3e4"),
		"floor": Color("d8d3c9"), "floor_alt": Color("ccc6ba"), "seam": Color("8e8577"), "line": Color("635c52"),
		"sky_top": Color("3f95e0"), "sky_mid": Color("7cc0ee"), "sky_low": Color("dff2f7"),
		"block": Color("f6f2e8"), "block_alt": Color("ff8a3d"), "frame": Color("2a3140"), "accent": Color("ffc53d"),
		"stand": Color("5d7f4f"), "crowd": [Color("ff8a3d"), Color("2fc4a5"), Color("ffc53d"), Color("f6f2e8")],
	},
	"oceano": {
		"name": "Base Submarina",
		# A lit steel deck on the sandy seabed: reef shelves, kelp and coral, habitat domes, a
		# yellow submarine, sonar masts and sunken cargo, in blue-green water.
		"dressing": "sea", "sand": Color("f3c979"), "sand_high": Color("edbd68"), "shelf": Color("2ea6c4"),
		"deck": Color("ffd36b"), "deck_panel": Color("ff8a3d"), "sun": Color("d2f5ff"),
		"armour": Color("ff8f70"), "armour_trim": Color("ffd23f"), "cushion": Color("ffd9cc"),
		"floor": Color("cfd8da"), "floor_alt": Color("c3cdd0"), "seam": Color("7e8e94"), "line": Color("56666d"),
		"sky_top": Color("0f5f8c"), "sky_mid": Color("1f8fb3"), "sky_low": Color("5cc9d6"),
		"block": Color("f4f8fa"), "block_alt": Color("ffb03d"), "frame": Color("233845"), "accent": Color("ff6f91"),
		"stand": Color("2f7f95"), "crowd": [Color("ffb03d"), Color("ff6f91"), Color("5cc9d6"), Color("f4f8fa")],
		"fog": {"color": Color("1b86b3"), "begin": 40.0, "end": 140.0},
	},
	"orbita": {
		"name": "Estação Orbital",
		# A white station deck in orbit: trusses, solar wings, modules, a docked shuttle and a
		# ringed planet below, against a violet starfield.
		"dressing": "space", "deck": Color("4fc3e8"), "deck_panel": Color("ff8a3d"), "hull": Color("3a3f72"),
		"armour": Color("ffb04d"), "armour_trim": Color("ff5c7a"), "cushion": Color("ffe6bf"),
		"floor": Color("d2d2da"), "floor_alt": Color("c6c6d0"), "seam": Color("7f7f92"), "line": Color("5c5c70"),
		"sky_top": Color("171a4a"), "sky_mid": Color("3b2a86"), "sky_low": Color("a35bbd"), "stars": 1.0, "glass_floor": true,
		"block": Color("f4f5fa"), "block_alt": Color("ff8a3d"), "frame": Color("262b45"), "accent": Color("7fe6ff"),
		"stand": Color("4a4f7a"), "crowd": [Color("ff8a3d"), Color("7fe6ff"), Color("ffd84a"), Color("f4f5fa")],
	},
	"jardim": {
		"name": "Ilha Jardim",
		# The grass island from the Blender diorama, its render lighting baked in
		# (arena_diorama.gd): teal checker floor, rubbery cream and orange walls, round trees.
		"dressing": "diorama",
		"floor": Color("d6dad1"), "floor_alt": Color("cacfc4"), "seam": Color("8a927f"), "line": Color("5d6655"),
		"sky_top": Color("6f9fbf"), "sky_mid": Color("86aecb"), "sky_low": Color("a9c6d8"),
		"block": Color("fff4e2"), "block_alt": Color("ff7a3c"), "frame": Color("2a3140"), "accent": Color("ffd23f"),
		"stand": Color("5d7f4f"), "crowd": [Color("ff7a3c"), Color("3fbfa0"), Color("ffd23f"), Color("fff4e2")],
	},
	"cidade": {
		"name": "Cidade Alta",
		# The top of a skyscraper: rooftop plant, a billboard and a helipad, with the towers of
		# the city around it and the streets far below.
		"dressing": "city", "roof": Color("5fd0e0"), "roof_panel": Color("7d5cf0"), "street": Color("4a4d6b"),
		"armour": Color("9a86f7"), "armour_trim": Color("ffd23f"), "cushion": Color("e6defe"),
		"floor": Color("dad4d6"), "floor_alt": Color("cec7ca"), "seam": Color("8f8388"), "line": Color("675c61"),
		"sky_top": Color("5e4fc0"), "sky_mid": Color("9d8fe0"), "sky_low": Color("f2c9e0"),
		"block": Color("f6f4fc"), "block_alt": Color("7d6cf0"), "frame": Color("2b2742"), "accent": Color("3fd9e6"),
		"stand": Color("5d549a"), "crowd": [Color("ff7fd4"), Color("3fd9e6"), Color("ffe066"), Color("f6f4fc")],
	},
}
# Season two's worlds: the five worlds again, corrupted - dark, lit by neon, never in daylight:
# a city at midnight, the sky deck at dawn, the valley at the end of the day, the deep sea at
# night and the orbital station under the eclipse. Each is its base world with its colours,
# its light ("key"/"fill"/"ambient", colour and strength) and a neon rim round the court.
const DARK_THEMES = {
	"cidade_negra": {"base": "cidade", "name": "Cidade Negra · meia-noite",
		"roof": Color("1c1a2e"), "roof_panel": Color("3a1f5e"), "street": Color("14121f"),
		"floor": Color("2a2440"), "floor_alt": Color("241f38"), "seam": Color("a24bff"), "line": Color("3ff0ff"),
		"sky_top": Color("05040f"), "sky_mid": Color("1a0b2e"), "sky_low": Color("4a1a5e"), "stars": 0.6,
		"block": Color("2e2a44"), "block_alt": Color("a24bff"), "frame": Color("0e0c18"), "accent": Color("ff3fbf"),
		"armour": Color("3a3458"), "armour_trim": Color("ff3fbf"), "cushion": Color("5a4f7a"), "stand": Color("1c1830"),
		"neon": Color("a24bff"), "neon_alt": Color("3ff0ff"),
		"key": Color("9fb0ff"), "key_energy": 0.45, "fill": Color("ff3fbf"), "fill_energy": 0.55, "ambient": Color("4a3a7a"), "ambient_energy": 0.5},
	"aurora_sombria": {"base": "aurora", "name": "Aurora Sombria · amanhecer",
		"deck": Color("3a2f4a"), "deck_panel": Color("1f2a44"), "hull": Color("22263a"),
		"floor": Color("363a58"), "floor_alt": Color("30344f"), "seam": Color("3ff0ff"), "line": Color("ffb08a"),
		"sky_top": Color("141a40"), "sky_mid": Color("5a3a7a"), "sky_low": Color("ff9a6a"),
		"block": Color("3a3f5a"), "block_alt": Color("3ff0ff"), "frame": Color("12141f"), "accent": Color("ffb08a"),
		"armour": Color("44405e"), "armour_trim": Color("3ff0ff"), "cushion": Color("6a6490"), "stand": Color("22263a"),
		"neon": Color("3ff0ff"), "neon_alt": Color("ff9a6a"),
		"key": Color("ffb08a"), "key_energy": 0.7, "fill": Color("a24bff"), "fill_energy": 0.45, "ambient": Color("5a4a80"), "ambient_energy": 0.6},
	"vale_corrompido": {"base": "terra", "name": "Vale Corrompido · fim do dia",
		"grass": Color("2a3326"), "grass_high": Color("252d22"), "cliff": Color("5a2f2a"), "dirt": Color("4a3228"),
		"pad": Color("3a2a2a"), "pad_panel": Color("ff3f6f"),
		"floor": Color("4a3040"), "floor_alt": Color("42293a"), "seam": Color("ff3f6f"), "line": Color("ffb86a"),
		"sky_top": Color("2a0f2e"), "sky_mid": Color("8a2a3a"), "sky_low": Color("ff7a3a"),
		"block": Color("4a3a44"), "block_alt": Color("ff3f6f"), "frame": Color("160d12"), "accent": Color("ffb86a"),
		"armour": Color("4a3040"), "armour_trim": Color("ff3f6f"), "cushion": Color("7a5060"), "stand": Color("2a1a22"),
		"neon": Color("ff3f6f"), "neon_alt": Color("ffb86a"),
		"key": Color("ff8a4a"), "key_energy": 0.6, "fill": Color("a24bff"), "fill_energy": 0.5, "ambient": Color("6a3a4a"), "ambient_energy": 0.55},
	"abismo_neon": {"base": "oceano", "name": "Abismo Néon · meia-noite",
		"sand": Color("1a2a33"), "sand_high": Color("16242c"), "shelf": Color("0e3a44"),
		"deck": Color("123a44"), "deck_panel": Color("3fffd0"), "sun": Color("3fffd0"),
		"floor": Color("0e3a44"), "floor_alt": Color("0b323b"), "seam": Color("3fffd0"), "line": Color("a24bff"),
		"sky_top": Color("020818"), "sky_mid": Color("06203a"), "sky_low": Color("0a3a5a"),
		"block": Color("1a3a44"), "block_alt": Color("3fffd0"), "frame": Color("06141a"), "accent": Color("3fffd0"),
		"armour": Color("1f4a55"), "armour_trim": Color("3fffd0"), "cushion": Color("3a6a74"), "stand": Color("0e2a33"),
		"neon": Color("3fffd0"), "neon_alt": Color("a24bff"), "fog": {"color": Color("041822"), "begin": 25.0, "end": 110.0},
		"key": Color("7fd8ff"), "key_energy": 0.35, "fill": Color("3fffd0"), "fill_energy": 0.55, "ambient": Color("1f4a5a"), "ambient_energy": 0.55},
	"eclipse_orbital": {"base": "orbita", "name": "Eclipse Orbital · meia-noite",
		"deck": Color("1a1030"), "deck_panel": Color("ff2a6a"), "hull": Color("120a22"),
		"floor": Color("1f1438"), "floor_alt": Color("1a1030"), "seam": Color("ff2a6a"), "line": Color("a24bff"),
		"sky_top": Color("000000"), "sky_mid": Color("12061e"), "sky_low": Color("3a0a3a"), "stars": 1.0,
		"block": Color("2a1f44"), "block_alt": Color("ff2a6a"), "frame": Color("08050f"), "accent": Color("ff2a6a"),
		"armour": Color("2e2248"), "armour_trim": Color("ff2a6a"), "cushion": Color("4a3a6a"), "stand": Color("140c22"),
		"neon": Color("ff2a6a"), "neon_alt": Color("a24bff"),
		"key": Color("ffd0a0"), "key_energy": 0.4, "fill": Color("a24bff"), "fill_energy": 0.65, "ambient": Color("3a2a5a"), "ambient_energy": 0.5},
}
const BY_MAP = {
	"aurora": "aurora", "torre": "aurora", "treino": "aurora",
	"mina": "terra", "estufa": "terra", "colosseum": "terra",
	"farol": "oceano", "laboratorio": "oceano", "recife": "oceano",
	"oficina": "cidade", "tempestade": "cidade",
	"observatorio": "orbita", "santuario": "orbita", "coroa": "orbita",
	"cidade_negra": "cidade_negra", "aurora_sombria": "aurora_sombria", "vale_corrompido": "vale_corrompido",
	"abismo_neon": "abismo_neon", "eclipse_orbital": "eclipse_orbital",
	"torre_terra": "terra", "torre_oceano": "oceano", "torre_orbita": "orbita", "torre_cidade": "cidade", "torre_jardim": "jardim",
}
# The worlds in the order the map picker shows them, with the thumbnail of each.
const WORLDS = ["jardim", "aurora", "terra", "oceano", "orbita", "cidade", "cidade_negra", "aurora_sombria", "vale_corrompido", "abismo_neon", "eclipse_orbital"]
const WORLD_PICTURE = "res://art/ui/maps/%s.png"
# The road stations between the bosses take the four ground-level worlds in turn; the sky
# deck stays the home arena.
const ROAD_CYCLE = ["terra", "cidade", "oceano", "orbita"]

static func id_for(map: Dictionary) -> String:
	var id = String(map.get("id", "aurora"))
	if BY_MAP.has(id):
		return BY_MAP[id]
	if id.begins_with("torre_") and DARK_THEMES.has(id.substr(6)):
		return id.substr(6)
	if id.begins_with("posto_"):
		return ROAD_CYCLE[posmod(int(id.substr(6)) - 1, ROAD_CYCLE.size())]
	# Cup and custom arenas: stable pick from the id, so the same map always looks the same.
	# The baked island only fits the tower layout it was modelled round, so it is left out.
	var pool = THEMES.keys().filter(func(key): return key != "jardim")
	return pool[posmod(id.hash(), pool.size())]

static func for_map(map: Dictionary) -> Dictionary:
	return theme(id_for(map))

static func theme(key: String) -> Dictionary:
	if ArtStyle.militar():
		return ArtStyle.world(_theme(key))
	return _theme(key)

static func _theme(key: String) -> Dictionary:
	# A season-two world is its base world with the dark colours laid over it.
	if DARK_THEMES.has(key):
		var dark: Dictionary = THEMES[String(DARK_THEMES[key].base)].duplicate()
		dark.merge(DARK_THEMES[key], true)
		dark.erase("base")
		return dark
	return THEMES.get(key, THEMES.aurora)
