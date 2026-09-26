extends RefCounted
## Environments for the arenas. Every map belongs to one: it colours the floor, the sky behind
## the platform, the perimeter blocks and the stadium around them. Rules never read this.
# The toy-diorama look: a warm white floor with crisp seams under a coloured sky, graphite
# frames with bright caps, and saturated blocks, so every environment reads at a glance.
const THEMES = {
	"aurora": {
		"name": "Arena Aurora",
		# The floating sky arena (scripts/arena_sky.gd): a steel deck in the clouds.
		"dressing": "sky", "deck": Color("c9d6e2"), "deck_panel": Color("5d7fa3"), "hull": Color("e9edf1"),
		"floor": Color("eef3f7"), "floor_alt": Color("d4e5f2"), "seam": Color("3a4656"), "line": Color("ffffff"),
		"sky_top": Color("2f7fd0"), "sky_mid": Color("5fa8e6"), "sky_low": Color("d6eef6"),
		"block": Color("f6f2e8"), "block_alt": Color("2fc4a5"), "frame": Color("2a3140"), "accent": Color("ffc53d"),
		"stand": Color("4f6f8a"), "crowd": [Color("2fc4a5"), Color("ff7a5c"), Color("ffc53d"), Color("f6f2e8"), Color("8f7cf0")],
		"flag": Color("ff7a5c"),
	},
	"cidade": {
		"name": "Cidade Alta",
		"floor": Color("f2eff9"), "floor_alt": Color("e8e4f5"), "seam": Color("b3aad6"), "line": Color("ffffff"),
		"sky_top": Color("5e4fc0"), "sky_mid": Color("9d8fe0"), "sky_low": Color("e4dff7"),
		"block": Color("7d6cf0"), "block_alt": Color("f6f4fc"), "frame": Color("2b2742"), "accent": Color("3fd9e6"),
		"stand": Color("5d549a"), "crowd": [Color("ff7fd4"), Color("3fd9e6"), Color("ffe066"), Color("f6f4fc")],
		"flag": Color("3fd9e6"),
	},
	"fabrica": {
		"name": "Fábrica Orbital",
		"floor": Color("f7f0e7"), "floor_alt": Color("eee4d6"), "seam": Color("c9b098"), "line": Color("ffffff"),
		"sky_top": Color("d9743a"), "sky_mid": Color("efb07e"), "sky_low": Color("f9e5d2"),
		"block": Color("f07d3e"), "block_alt": Color("faf3ea"), "frame": Color("3b2f28"), "accent": Color("ffcc33"),
		"stand": Color("98694b"), "crowd": [Color("ffb03d"), Color("f0663e"), Color("faf3ea"), Color("3fb4f0")],
		"flag": Color("ffcc33"),
	},
	"canyon": {
		"name": "Canyon Vermelho",
		"floor": Color("f8eee4"), "floor_alt": Color("efdfcf"), "seam": Color("cda587"), "line": Color("ffffff"),
		"sky_top": Color("c44a36"), "sky_mid": Color("e8916c"), "sky_low": Color("f8dccb"),
		"block": Color("e89a30"), "block_alt": Color("fbf1e4"), "frame": Color("45302a"), "accent": Color("2fb2e0"),
		"stand": Color("8e5646"), "crowd": [Color("ffc05c"), Color("2fb2e0"), Color("ef6a4a"), Color("fbf1e4")],
		"flag": Color("2fb2e0"),
	},
	"gelada": {
		"name": "Base Gelada",
		"floor": Color("f1f7fc"), "floor_alt": Color("e4eef7"), "seam": Color("a4c2dc"), "line": Color("ffffff"),
		"sky_top": Color("347bd0"), "sky_mid": Color("86b8e8"), "sky_low": Color("e0edfa"),
		"block": Color("4f93e8"), "block_alt": Color("f6fbff"), "frame": Color("24364e"), "accent": Color("ff7d95"),
		"stand": Color("50779f"), "crowd": [Color("c9ecff"), Color("4f93e8"), Color("ff7d95"), Color("ffffff")],
		"flag": Color("ff7d95"),
	},
	"floresta": {
		"name": "Floresta Mecânica",
		"floor": Color("f1f6ec"), "floor_alt": Color("e5eedd"), "seam": Color("a9c49f"), "line": Color("ffffff"),
		"sky_top": Color("3f9150"), "sky_mid": Color("8fcb84"), "sky_low": Color("e2f2da"),
		"block": Color("6fbf4a"), "block_alt": Color("f6f9ee"), "frame": Color("2a3829"), "accent": Color("ffcf3d"),
		"stand": Color("557f4d"), "crowd": [Color("a8e36a"), Color("ffcf3d"), Color("3fd1a8"), Color("f6f9ee")],
		"flag": Color("ffcf3d"),
	},
}
const BY_MAP = {
	"aurora": "aurora", "treino": "aurora", "torre": "aurora", "colosseum": "aurora", "santuario": "aurora",
	"farol": "cidade", "tempestade": "cidade",
	"mina": "fabrica", "oficina": "fabrica",
	"recife": "canyon",
	"laboratorio": "gelada", "observatorio": "gelada",
	"estufa": "floresta",
}
const ROAD_CYCLE = ["cidade", "fabrica", "canyon", "gelada", "floresta"]

static func id_for(map: Dictionary) -> String:
	var id = String(map.get("id", "aurora"))
	if BY_MAP.has(id):
		return BY_MAP[id]
	if id.begins_with("posto_"):
		return ROAD_CYCLE[posmod(int(id.substr(6)) - 1, ROAD_CYCLE.size())]
	# Cup and custom arenas: stable pick from the id, so the same map always looks the same.
	return THEMES.keys()[posmod(id.hash(), THEMES.size())]

static func for_map(map: Dictionary) -> Dictionary:
	return THEMES[id_for(map)]
