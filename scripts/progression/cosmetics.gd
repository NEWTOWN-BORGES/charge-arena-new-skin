extends RefCounted
# OFICINA: looks bought with bricks. Nothing here changes how a match plays.
#
# Paints repaint a robot's hull, trim and lights, chosen per skin. The story's hard skins
# (the corrupted ones) take their own set: always dark, with a neon of a different colour.
# Shot colours tint the rounds, their trail and the muzzle flash, for every robot.

const PAINTS = [
	{"id": "carbono", "name": "Carbono", "price": 250, "kind": "normal",
		"palette": {"shell": "2b2f36", "trim": "5a6170", "dark": "15171c", "metal": "8a9099", "glow": "46d7ff", "eyes": "7fe8ff"}},
	{"id": "artico", "name": "Ártico", "price": 250, "kind": "normal",
		"palette": {"shell": "eef3f8", "trim": "9fd4ff", "dark": "51606f", "metal": "c6ced8", "glow": "6fe3ff", "eyes": "bff4ff"}},
	{"id": "camuflagem", "name": "Camuflagem", "price": 300, "kind": "normal",
		"palette": {"shell": "4f5d3a", "trim": "8a7a4a", "dark": "2a301f", "metal": "6d7059", "glow": "c6e05a", "eyes": "e6f59a"}},
	{"id": "oceano", "name": "Oceano", "price": 300, "kind": "normal",
		"palette": {"shell": "1f5f8b", "trim": "49d3c9", "dark": "0f2c40", "metal": "7aa6b8", "glow": "7ff0e6", "eyes": "c8fff8"}},
	{"id": "lava", "name": "Lava", "price": 400, "kind": "normal",
		"palette": {"shell": "3a1d14", "trim": "ff5a1f", "dark": "1e0e0a", "metal": "8c5a44", "glow": "ff8a2a", "eyes": "ffd36a"}},
	{"id": "neon_rosa", "name": "Néon rosa", "price": 400, "kind": "normal",
		"palette": {"shell": "2a2140", "trim": "ff4fb8", "dark": "17122a", "metal": "7a6c9a", "glow": "ff7ad9", "eyes": "ffc2ee"}},
	{"id": "real", "name": "Real", "price": 500, "kind": "normal",
		"palette": {"shell": "3b2a7a", "trim": "e2b84a", "dark": "1b1440", "metal": "a48fd0", "glow": "c9a7ff", "eyes": "f2e2ff"}},
	# Earned, not bought: fifteen wins in a row in the MARATONA.
	{"id": "ouro", "name": "Ouro", "price": 0, "kind": "normal", "earn": "marathon_15",
		"palette": {"shell": "e6b53c", "trim": "fff0b8", "dark": "5a4318", "metal": "c9a24f", "glow": "fff3a6", "eyes": "fff8d0"}},
	# Corrupted: the story's second season, dark hulls lit by a sick neon.
	{"id": "veneno", "name": "Veneno", "price": 350, "kind": "corrupted",
		"palette": {"shell": "101312", "trim": "1f2a20", "dark": "07090a", "metal": "2c332e", "glow": "7dff3a", "eyes": "b6ff4a"}},
	{"id": "sangue", "name": "Sangue", "price": 350, "kind": "corrupted",
		"palette": {"shell": "140b0c", "trim": "3a0f14", "dark": "080405", "metal": "2e2224", "glow": "ff2a3c", "eyes": "ff6a74"}},
	{"id": "vazio", "name": "Vazio", "price": 400, "kind": "corrupted",
		"palette": {"shell": "0e0b16", "trim": "2a1846", "dark": "05040a", "metal": "2a2536", "glow": "b04dff", "eyes": "d9a6ff"}},
	{"id": "gelo_morto", "name": "Gelo morto", "price": 400, "kind": "corrupted",
		"palette": {"shell": "0b1218", "trim": "15303d", "dark": "05090c", "metal": "26343c", "glow": "3ff0ff", "eyes": "b8fbff"}},
	{"id": "brasa", "name": "Brasa", "price": 450, "kind": "corrupted",
		"palette": {"shell": "120d0a", "trim": "3a1a08", "dark": "080605", "metal": "302620", "glow": "ff7a12", "eyes": "ffc070"}},
	{"id": "espectro", "name": "Espectro", "price": 500, "kind": "corrupted",
		"palette": {"shell": "1a1a1e", "trim": "2c2c34", "dark": "0a0a0c", "metal": "3a3a44", "glow": "e8f0ff", "eyes": "ffffff"}},
]

const SHOTS = [
	{"id": "eletrico", "name": "Azul elétrico", "price": 100, "color": "2fd0ff"},
	{"id": "toxico", "name": "Verde tóxico", "price": 100, "color": "6dff5a"},
	{"id": "laranja", "name": "Laranja", "price": 100, "color": "ff8a1e"},
	{"id": "rosa", "name": "Rosa", "price": 150, "color": "ff5ad1"},
	{"id": "roxo", "name": "Roxo", "price": 150, "color": "a46bff"},
	{"id": "branco", "name": "Branco puro", "price": 200, "color": "f4f8ff"},
	{"id": "dourado", "name": "Dourado", "price": 250, "color": "ffd23f"},
	# Cycles through the colours as it flies.
	{"id": "arco_iris", "name": "Arco-íris", "price": 300, "color": "rainbow"},
]

var path = "user://cosmetics.cfg"
var owned: Array = []
# skin index (as a string, ConfigFile keys) -> paint id
var paints: Dictionary = {}
var shot = ""
var unlock_all = false

static func paint_entry(id: String) -> Dictionary:
	for entry in PAINTS:
		if entry.id == id:
			return entry
	return {}

static func shot_entry(id: String) -> Dictionary:
	for entry in SHOTS:
		if entry.id == id:
			return entry
	return {}

static func is_corrupted_skin(skin: int, catalog: Array) -> bool:
	# The hard-mode skins of the story's second season (BIT DE ELITE and MAGNUS IMPERADOR
	# are champions, not corrupted, and keep the normal set).
	if skin < 0 or skin >= catalog.size() or not catalog[skin].has("hard_of"):
		return false
	var name = String(catalog[skin].name)
	return not (name.begins_with("BIT DE ELITE") or name.begins_with("MAGNUS IMPERADOR"))

# The paints a skin can wear: the corrupted set on corrupted skins, the normal set elsewhere.
static func paints_for(skin: int, catalog: Array) -> Array:
	var kind = "corrupted" if is_corrupted_skin(skin, catalog) else "normal"
	return PAINTS.filter(func(entry): return entry.kind == kind)

func owns(id: String) -> bool:
	return unlock_all or owned.has(id)

func price(id: String) -> int:
	var entry = paint_entry(id)
	if entry.is_empty():
		entry = shot_entry(id)
	return int(entry.get("price", 0)) if not entry.is_empty() else -1

func can_buy(id: String) -> bool:
	var entry = paint_entry(id)
	if entry.is_empty():
		entry = shot_entry(id)
	return not entry.is_empty() and not owns(id) and not entry.has("earn")

# Pays from the brick wallet (the power shop's). Returns true when bought.
func buy(id: String, wallet) -> bool:
	if not can_buy(id):
		return false
	var cost = price(id)
	if int(wallet.bricks) < cost:
		return false
	wallet.bricks = int(wallet.bricks) - cost
	owned.append(id)
	return true

# An earned look: given once, free.
func award(id: String) -> bool:
	if owns(id) or (paint_entry(id).is_empty() and shot_entry(id).is_empty()):
		return false
	owned.append(id)
	return true

func equip_paint(skin: int, id: String, catalog: Array) -> bool:
	if id == "":
		paints.erase(str(skin))
		return true
	if not owns(id) or not paints_for(skin, catalog).any(func(entry): return entry.id == id):
		return false
	paints[str(skin)] = id
	return true

func equip_shot(id: String) -> bool:
	if id != "" and not owns(id):
		return false
	shot = id
	return true

func paint_of(skin: int) -> String:
	return String(paints.get(str(skin), ""))

# The palette overrides for a skin ({} when it wears its own colours).
func palette_for(skin: int) -> Dictionary:
	var id = paint_of(skin)
	return paint_entry(id).get("palette", {}) if id != "" else {}

# The shot colour as text: "" (the skin's own), a hex colour, or "rainbow".
func shot_color() -> String:
	return String(shot_entry(shot).get("color", "")) if shot != "" else ""

func load_preferences() -> void:
	var config = ConfigFile.new()
	if config.load(path) != OK:
		return
	owned = Array(config.get_value("cosmetics", "owned", []))
	var saved = config.get_value("cosmetics", "paints", {})
	paints = saved if typeof(saved) == TYPE_DICTIONARY else {}
	shot = String(config.get_value("cosmetics", "shot", ""))
	if shot != "" and not owns(shot):
		shot = ""

func save_preferences() -> int:
	var config = ConfigFile.new()
	config.set_value("cosmetics", "owned", owned)
	config.set_value("cosmetics", "paints", paints)
	config.set_value("cosmetics", "shot", shot)
	return config.save(path)
