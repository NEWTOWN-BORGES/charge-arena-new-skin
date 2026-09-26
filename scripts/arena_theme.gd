extends RefCounted
## Environments for the arenas. Every map belongs to one of five: the floating sky deck, the
## countryside outpost, the seabed base, the orbital station and the city rooftop. Each colours
## the field and names the dressing that builds the world around it (scripts/arena_sky.gd,
## arena_ground.gd, arena_sea.gd, arena_space.gd, arena_city.gd). Rules never read this.
# A light field with crisp seams under saturated scenery, so every environment reads at a
# glance and the robots always stand out from the floor.
const THEMES = {
	"aurora": {
		"name": "Arena Aurora",
		# The floating sky arena: a steel deck in the clouds.
		"dressing": "sky", "deck": Color("c9d6e2"), "deck_panel": Color("5d7fa3"), "hull": Color("e9edf1"),
		"floor": Color("eef3f7"), "floor_alt": Color("d4e5f2"), "seam": Color("3a4656"), "line": Color("ffffff"),
		"sky_top": Color("2f7fd0"), "sky_mid": Color("5fa8e6"), "sky_low": Color("d6eef6"),
		"block": Color("f6f2e8"), "block_alt": Color("2fc4a5"), "frame": Color("2a3140"), "accent": Color("ffc53d"),
		"stand": Color("4f6f8a"), "crowd": [Color("2fc4a5"), Color("ff7a5c"), Color("ffc53d"), Color("f6f2e8")],
	},
	"terra": {
		"name": "Posto Terrestre",
		# A concrete pad in a green valley, with sandstone terraces, pines, wind turbines,
		# solar farms, silos and a hangar.
		"dressing": "ground", "grass": Color("86d65a"), "grass_high": Color("78cb4e"), "cliff": Color("eaa566"),
		"dirt": Color("f1d08e"), "pad": Color("ebe8e1"), "pad_panel": Color("6d93a6"),
		"floor": Color("f3f7ee"), "floor_alt": Color("dfecd2"), "seam": Color("3b4a3a"), "line": Color("ffffff"),
		"sky_top": Color("3f95e0"), "sky_mid": Color("7cc0ee"), "sky_low": Color("dff2f7"),
		"block": Color("f6f2e8"), "block_alt": Color("ff8a3d"), "frame": Color("2a3140"), "accent": Color("ffc53d"),
		"stand": Color("5d7f4f"), "crowd": [Color("ff8a3d"), Color("2fc4a5"), Color("ffc53d"), Color("f6f2e8")],
		"fog": {"color": Color("cfe9f5"), "begin": 34.0, "end": 110.0},
	},
	"oceano": {
		"name": "Base Submarina",
		# A lit steel deck on the sandy seabed: reef shelves, kelp and coral, habitat domes, a
		# yellow submarine, sonar masts and sunken cargo, in blue-green water.
		"dressing": "sea", "sand": Color("f3c979"), "sand_high": Color("edbd68"), "shelf": Color("2ea6c4"),
		"deck": Color("d3e0e6"), "deck_panel": Color("2f9fb3"), "sun": Color("d2f5ff"),
		"floor": Color("eef8f8"), "floor_alt": Color("d3eef0"), "seam": Color("2c4a55"), "line": Color("ffffff"),
		"sky_top": Color("0f5f8c"), "sky_mid": Color("1f8fb3"), "sky_low": Color("5cc9d6"),
		"block": Color("f4f8fa"), "block_alt": Color("ffb03d"), "frame": Color("233845"), "accent": Color("ff6f91"),
		"stand": Color("2f7f95"), "crowd": [Color("ffb03d"), Color("ff6f91"), Color("5cc9d6"), Color("f4f8fa")],
		"fog": {"color": Color("1b86b3"), "begin": 30.0, "end": 100.0},
	},
	"orbita": {
		"name": "Estação Orbital",
		# A white station deck in orbit: trusses, solar wings, modules, a docked shuttle and a
		# ringed planet below, against a violet starfield.
		"dressing": "space", "deck": Color("dfe3ea"), "deck_panel": Color("4a5fc4"), "hull": Color("eef0f5"),
		"floor": Color("f0f1f8"), "floor_alt": Color("dcdff2"), "seam": Color("343a58"), "line": Color("ffffff"),
		"sky_top": Color("171a4a"), "sky_mid": Color("3b2a86"), "sky_low": Color("a35bbd"), "stars": 1.0,
		"block": Color("f4f5fa"), "block_alt": Color("ff8a3d"), "frame": Color("262b45"), "accent": Color("7fe6ff"),
		"stand": Color("4a4f7a"), "crowd": [Color("ff8a3d"), Color("7fe6ff"), Color("ffd84a"), Color("f4f5fa")],
	},
	"jardim": {
		"name": "Ilha Jardim",
		# The grass island from the Blender diorama, its render lighting baked in
		# (arena_diorama.gd): teal checker floor, rubbery cream and orange walls, round trees.
		"dressing": "diorama",
		"floor": Color("3fbfa0"), "floor_alt": Color("37ad91"), "seam": Color("ff9a3c"), "line": Color("fff1d8"),
		"sky_top": Color("7fa9c4"), "sky_mid": Color("9dbfd2"), "sky_low": Color("c9dde8"),
		"block": Color("fff4e2"), "block_alt": Color("ff7a3c"), "frame": Color("2a3140"), "accent": Color("ffd23f"),
		"stand": Color("5d7f4f"), "crowd": [Color("ff7a3c"), Color("3fbfa0"), Color("ffd23f"), Color("fff4e2")],
	},
	"cidade": {
		"name": "Cidade Alta",
		# The top of a skyscraper: rooftop plant, a billboard and a helipad, with the towers of
		# the city around it and the streets far below.
		"dressing": "city", "roof": Color("dcd8e6"), "roof_panel": Color("6f63c9"), "street": Color("4a4d6b"),
		"floor": Color("f3f0f9"), "floor_alt": Color("e2dcf2"), "seam": Color("3a3556"), "line": Color("ffffff"),
		"sky_top": Color("5e4fc0"), "sky_mid": Color("9d8fe0"), "sky_low": Color("f2c9e0"),
		"block": Color("f6f4fc"), "block_alt": Color("7d6cf0"), "frame": Color("2b2742"), "accent": Color("3fd9e6"),
		"stand": Color("5d549a"), "crowd": [Color("ff7fd4"), Color("3fd9e6"), Color("ffe066"), Color("f6f4fc")],
		"fog": {"color": Color("c9bfe8"), "begin": 30.0, "end": 90.0},
	},
}
const BY_MAP = {
	"aurora": "aurora", "torre": "aurora", "treino": "aurora",
	"mina": "terra", "estufa": "terra", "colosseum": "terra",
	"farol": "oceano", "laboratorio": "oceano", "recife": "oceano",
	"oficina": "cidade", "tempestade": "cidade",
	"observatorio": "orbita", "santuario": "orbita", "coroa": "orbita",
	"torre_terra": "terra", "torre_oceano": "oceano", "torre_orbita": "orbita", "torre_cidade": "cidade", "torre_jardim": "jardim",
}
# The worlds in the order the map picker shows them, with the thumbnail of each.
const WORLDS = ["jardim", "aurora", "terra", "oceano", "orbita", "cidade"]
const WORLD_PICTURE = "res://art/ui/maps/%s.png"
# The road stations between the bosses take the four ground-level worlds in turn; the sky
# deck stays the home arena.
const ROAD_CYCLE = ["terra", "cidade", "oceano", "orbita"]

static func id_for(map: Dictionary) -> String:
	var id = String(map.get("id", "aurora"))
	if BY_MAP.has(id):
		return BY_MAP[id]
	if id.begins_with("posto_"):
		return ROAD_CYCLE[posmod(int(id.substr(6)) - 1, ROAD_CYCLE.size())]
	# Cup and custom arenas: stable pick from the id, so the same map always looks the same.
	# The baked island only fits the tower layout it was modelled round, so it is left out.
	var pool = THEMES.keys().filter(func(key): return key != "jardim")
	return pool[posmod(id.hash(), pool.size())]

static func for_map(map: Dictionary) -> Dictionary:
	return THEMES[id_for(map)]
