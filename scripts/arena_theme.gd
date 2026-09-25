extends RefCounted
## Environments for the arenas. Every map belongs to one: it colours the floor, the sky behind
## the platform, the perimeter blocks and the stadium around them. Rules never read this.
const THEMES = {
	"aurora": {
		"name": "Arena Aurora",
		"floor": Color("243a66"), "floor_alt": Color("2c4677"), "seam": Color("101a33"), "line": Color("7fe7ff"),
		"sky_top": Color("0b1030"), "sky_mid": Color("3a2a6e"), "sky_low": Color("ff8a5c"),
		"block": Color("f08a2c"), "block_alt": Color("ece5d6"), "frame": Color("262a36"), "accent": Color("ffd166"),
		"stand": Color("2d3450"), "crowd": [Color("7fe7ff"), Color("ff7a59"), Color("ffd166"), Color("e8e8f0"), Color("9b7bff")],
		"flag": Color("e8465f"),
	},
	"cidade": {
		"name": "Cidade Alta",
		"floor": Color("2a2552"), "floor_alt": Color("342c63"), "seam": Color("120f26"), "line": Color("ff5cf0"),
		"sky_top": Color("07061a"), "sky_mid": Color("2a1650"), "sky_low": Color("ff4fa3"),
		"block": Color("5e5a8c"), "block_alt": Color("d9d4ef"), "frame": Color("1c1a2e"), "accent": Color("3df2ff"),
		"stand": Color("24203e"), "crowd": [Color("ff5cf0"), Color("3df2ff"), Color("ffe45c"), Color("e0dcff")],
		"flag": Color("3df2ff"),
	},
	"fabrica": {
		"name": "Fábrica Orbital",
		"floor": Color("3a2a26"), "floor_alt": Color("47332c"), "seam": Color("1b1210"), "line": Color("ffb03a"),
		"sky_top": Color("150a08"), "sky_mid": Color("4a1c12"), "sky_low": Color("ff6a1a"),
		"block": Color("d0582a"), "block_alt": Color("d9cbb2"), "frame": Color("2a2320"), "accent": Color("ffcf3a"),
		"stand": Color("3a2d28"), "crowd": [Color("ffb03a"), Color("ff6a3a"), Color("e8dcc8"), Color("7fd0ff")],
		"flag": Color("ffcf3a"),
	},
	"canyon": {
		"name": "Canyon Vermelho",
		"floor": Color("5a3326"), "floor_alt": Color("673b2b"), "seam": Color("2a150f"), "line": Color("ffd08a"),
		"sky_top": Color("2a1b3a"), "sky_mid": Color("a2462e"), "sky_low": Color("ffc07a"),
		"block": Color("e0a14a"), "block_alt": Color("efdcc0"), "frame": Color("3a2419"), "accent": Color("5fd0ff"),
		"stand": Color("5a3a2c"), "crowd": [Color("ffd08a"), Color("5fd0ff"), Color("ff7a4a"), Color("f2e6d0")],
		"flag": Color("5fd0ff"),
	},
	"gelada": {
		"name": "Base Gelada",
		"floor": Color("3b5f86"), "floor_alt": Color("456c95"), "seam": Color("1a2c44"), "line": Color("dffaff"),
		"sky_top": Color("0b1a33"), "sky_mid": Color("2f5c8f"), "sky_low": Color("bfe8ff"),
		"block": Color("3d78c9"), "block_alt": Color("eef4fb"), "frame": Color("1d2a3d"), "accent": Color("ff7a8a"),
		"stand": Color("2c3f5c"), "crowd": [Color("dffaff"), Color("7fc4ff"), Color("ff7a8a"), Color("ffffff")],
		"flag": Color("ff7a8a"),
	},
	"floresta": {
		"name": "Floresta Mecânica",
		"floor": Color("264c3a"), "floor_alt": Color("2d5843"), "seam": Color("0f2219"), "line": Color("aaff6a"),
		"sky_top": Color("071a14"), "sky_mid": Color("1d4a3a"), "sky_low": Color("ffe07a"),
		"block": Color("6f9e3a"), "block_alt": Color("e6e2c8"), "frame": Color("1f2a1e"), "accent": Color("ffd24a"),
		"stand": Color("2b3d2c"), "crowd": [Color("aaff6a"), Color("ffd24a"), Color("5fe0c0"), Color("f0ecd0")],
		"flag": Color("ffd24a"),
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
