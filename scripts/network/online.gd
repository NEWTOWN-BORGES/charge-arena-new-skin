extends RefCounted
# Online PvP: what the game and its server must agree on.
#
# The server is the referee: it runs the same rules as the game, both phones send it
# their input and draw the snapshots it sends back, exactly as a LAN guest does.

# Bumped whenever the messages between game and server change: an older game is told
# to update instead of playing a match it would misread.
const PROTOCOL = 1
const DEFAULT_PORT = 27941
# The address of the public server. Empty until it is deployed: the PvP menu then says
# online play is coming instead of offering a button that cannot work.
const SERVER_HOST = ""
# Rooms for friends: a short code without characters that look alike (0/O, 1/I).
const CODE_LETTERS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH = 4
# Ask for a private room with this instead of a code.
const NEW_ROOM = "+"
# Seconds without a rival before the game offers a match against the AI.
const OFFER_AI_AFTER = 20.0

# An address given at run time wins over the built-in one: `--online-server=host:port`
# on the command line (tests and a self-hosted server), then user://online.cfg.
static func server_address() -> Dictionary:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--online-server="):
			return parse(arg.trim_prefix("--online-server="))
	var config = ConfigFile.new()
	if config.load("user://online.cfg") == OK:
		var custom = String(config.get_value("online", "server", ""))
		if custom != "":
			return parse(custom)
	return {"host": SERVER_HOST, "port": DEFAULT_PORT}

static func parse(text: String) -> Dictionary:
	var host = text.strip_edges()
	var port = DEFAULT_PORT
	var colon = host.rfind(":")
	if colon > 0 and host.substr(colon + 1).is_valid_int():
		port = clampi(int(host.substr(colon + 1)), 1, 65535)
		host = host.substr(0, colon)
	return {"host": host, "port": port}

static func available() -> bool:
	return String(server_address().host) != ""

static func save_custom_server(text: String) -> void:
	var config = ConfigFile.new()
	config.load("user://online.cfg")
	config.set_value("online", "server", text.strip_edges())
	config.save("user://online.cfg")

static func clear_custom_server() -> void:
	var config = ConfigFile.new()
	if config.load("user://online.cfg") == OK:
		config.erase_section_key("online", "server")
		config.save("user://online.cfg")

static func clean_code(text: String) -> String:
	# Typed codes forgive case, spaces and dashes.
	var code = text.strip_edges().to_upper()
	var kept = ""
	for letter in code:
		if CODE_LETTERS.contains(letter):
			kept += letter
	return kept.substr(0, CODE_LENGTH)
