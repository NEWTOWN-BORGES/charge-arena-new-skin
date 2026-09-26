extends RefCounted
## Environments for the arenas. Every map belongs to one: it colours the floor, the sky behind
## the platform, the perimeter blocks and the stadium around them. Rules never read this.
# The studio look: pale, soft-matte grounds and backdrops, cream and pastel armour, graphite
# frames. Each environment keeps its own hue, like the same studio lit in six colours.
const THEMES = {
	"aurora": {
		"name": "Arena Aurora",
		"floor": Color("c9d0d7"), "floor_alt": Color("c2c9d1"), "seam": Color("a2acb7"), "line": Color("f7f9fb"),
		"sky_top": Color("b9c0c7"), "sky_mid": Color("aab1b8"), "sky_low": Color("c9ced3"),
		"block": Color("ece6d6"), "block_alt": Color("8fd8c8"), "frame": Color("3b414c"), "accent": Color("f2cb6e"),
		"stand": Color("98a2ad"), "crowd": [Color("8fd8c8"), Color("ef9f8b"), Color("f2cb6e"), Color("ece6d6"), Color("b4a8e6")],
		"flag": Color("ef9f8b"),
	},
	"cidade": {
		"name": "Cidade Alta",
		"floor": Color("cfcbe0"), "floor_alt": Color("c7c2da"), "seam": Color("aaa4c5"), "line": Color("fbfaff"),
		"sky_top": Color("c3bed6"), "sky_mid": Color("b1abc9"), "sky_low": Color("d3cfe2"),
		"block": Color("a39bd0"), "block_alt": Color("eeebf7"), "frame": Color("3c3a52"), "accent": Color("8fe0e8"),
		"stand": Color("a39fbb"), "crowd": [Color("e59fdc"), Color("8fe0e8"), Color("f2e28e"), Color("eeebf7")],
		"flag": Color("8fe0e8"),
	},
	"fabrica": {
		"name": "Fábrica Orbital",
		"floor": Color("d9cfc6"), "floor_alt": Color("d1c6bb"), "seam": Color("b5a797"), "line": Color("fffaf3"),
		"sky_top": Color("cfc4b8"), "sky_mid": Color("bfb2a4"), "sky_low": Color("ddd4ca"),
		"block": Color("e39a6c"), "block_alt": Color("efe7da"), "frame": Color("4a413b"), "accent": Color("f3cb6e"),
		"stand": Color("ada194"), "crowd": [Color("f3b56e"), Color("e98b6e"), Color("efe7da"), Color("9fd3ef")],
		"flag": Color("f3cb6e"),
	},
	"canyon": {
		"name": "Canyon Vermelho",
		"floor": Color("ddc8b8"), "floor_alt": Color("d6bfad"), "seam": Color("b99f8b"), "line": Color("fff7ec"),
		"sky_top": Color("d7c3b3"), "sky_mid": Color("c7ad98"), "sky_low": Color("e3d2c3"),
		"block": Color("dca969"), "block_alt": Color("f2e5d2"), "frame": Color("56443b"), "accent": Color("8ccde6"),
		"stand": Color("b39c89"), "crowd": [Color("f3c98c"), Color("8ccde6"), Color("e9977a"), Color("f2e5d2")],
		"flag": Color("8ccde6"),
	},
	"gelada": {
		"name": "Base Gelada",
		"floor": Color("cfdeea"), "floor_alt": Color("c6d7e5"), "seam": Color("a6bdd0"), "line": Color("fbfdff"),
		"sky_top": Color("c6d6e3"), "sky_mid": Color("b3c7d8"), "sky_low": Color("d7e3ed"),
		"block": Color("7ea9dd"), "block_alt": Color("f1f6fb"), "frame": Color("3a4a5e"), "accent": Color("f2a0ab"),
		"stand": Color("a2b5c7"), "crowd": [Color("dcf2fb"), Color("93c3ef"), Color("f2a0ab"), Color("ffffff")],
		"flag": Color("f2a0ab"),
	},
	"floresta": {
		"name": "Floresta Mecânica",
		"floor": Color("ccd9ca"), "floor_alt": Color("c3d2c0"), "seam": Color("a3b6a0"), "line": Color("f8fbf3"),
		"sky_top": Color("c4d2c1"), "sky_mid": Color("b1c2ad"), "sky_low": Color("d5e0d2"),
		"block": Color("98bf76"), "block_alt": Color("eff1e2"), "frame": Color("3d4a3c"), "accent": Color("f2d06e"),
		"stand": Color("9fae9b"), "crowd": [Color("c3e79a"), Color("f2d06e"), Color("8fdcc6"), Color("eff1e2")],
		"flag": Color("f2d06e"),
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
