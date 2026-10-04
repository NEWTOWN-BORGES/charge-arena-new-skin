extends Node
# The online PvP server: a quick-match queue, rooms with a code for friends, and the
# referee of every match. Each match runs the game's own rules here, and both phones
# play it the way a LAN guest plays a host: they send input, they draw snapshots.
#
# It must be named like the game's root node (ChargeArena) and declare the same RPC
# methods with the same settings: Godot matches remote calls by node path and by the
# sorted list of RPC names. tests/regression/test_online.gd checks that they agree.

const Online = preload("res://scripts/network/online.gd")
const Rules = preload("res://scripts/gameplay/arena_rules.gd")
const Skins = preload("res://scripts/progression/skins.gd")
const PowerShop = preload("res://scripts/gameplay/powers.gd")

const MAX_PEERS = 256
# Measured (tests/benchmarks/bench_online_server.gd): a match costs about 2 % of one
# CPU core, and this process steps every match on one thread. 40 keeps it under
# about 80 % of a core; more players need a second server process on another port.
const MAX_MATCHES = 40
const MAX_ROOMS = 200
const HELLO_SECONDS = 10.0
const ROOM_SECONDS = 15 * 60.0
const AWAY_SECONDS = 90.0
# The last snapshots keep going out this long after the final whistle, so both phones
# see the same result before the match is closed.
const FINAL_SECONDS = 1.5
const KICK_DELAY = 1.0
const SNAPSHOT_RATE = 20.0
# Same tolerances as the LAN host (main.gd).
const STALE_INPUT = 0.35
const POWER_HOLD_MS = 500
const FIRE_BUFFER_MS = 900
const MAX_QUEUED_SHOTS = 24
const MAX_PENDING_EVENTS = 80

class Match:
	var rules
	var peers: Array = [0, 0]
	var commands: Array = [{"move": Vector2.ZERO, "fire": false}, {"move": Vector2.ZERO, "fire": false}]
	var ages: Array = [1.0, 1.0]
	var powers: Array = [-1, -1]
	var power_until: Array = [0, 0]
	var shots: Array = [0, 0]
	var shots_until: Array = [0, 0]
	var away: Array = [false, false]
	var away_time = 0.0
	var tick = 0.0
	var events: Array = []
	var final_time = -1.0

# Peer id -> {"state": "new"|"queue"|"room"|"match", "since": seconds, "skin": int,
# "kit": Array, "room": String, "match": Match}
var peers: Dictionary = {}
var queue: Array = []
var rooms: Dictionary = {}
var matches: Array = []
var kicks: Dictionary = {}
var clock = 0.0
var port = Online.DEFAULT_PORT
var stats_time = 0.0
var verbose = true

func start(listen_port: int = Online.DEFAULT_PORT) -> int:
	port = listen_port
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_PEERS)
	if error != OK:
		return error
	# Players talk to the server only: no relaying calls between them, and no news of
	# who else is connected.
	if multiplayer is SceneMultiplayer:
		multiplayer.server_relay = false
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	log_line("ONLINE_SERVER_READY port=%d protocol=%d" % [port, Online.PROTOCOL])
	return OK

func stop() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peers.clear()
	queue.clear()
	rooms.clear()
	matches.clear()

func log_line(text: String) -> void:
	if verbose:
		print(text)

func _on_peer_connected(id: int) -> void:
	peers[id] = {"state": "new", "since": clock}

func _on_peer_disconnected(id: int) -> void:
	forget(id, "O rival saiu da partida.")
	kicks.erase(id)

func forget(id: int, reason: String) -> void:
	var info: Dictionary = peers.get(id, {})
	peers.erase(id)
	queue.erase(id)
	if info.get("room", "") != "" and rooms.get(info.room, 0) == id:
		rooms.erase(info.room)
	var game: Match = info.get("match", null)
	if game != null:
		end_match(game, reason, id)

func kick(id: int) -> void:
	# Late enough for the reliable message just sent to arrive first.
	kicks[id] = clock + KICK_DELAY

func refuse(id: int, reason: String) -> void:
	online_closed.rpc_id(id, reason)
	forget(id, "")
	kick(id)

func _physics_process(dt: float) -> void:
	clock += dt
	for id in kicks.keys():
		if clock >= float(kicks[id]):
			kicks.erase(id)
			if multiplayer.multiplayer_peer is ENetMultiplayerPeer and multiplayer.get_peers().has(id):
				multiplayer.multiplayer_peer.disconnect_peer(id)
	for id in peers.keys():
		var info: Dictionary = peers[id]
		if info.state == "new" and clock - float(info.since) > HELLO_SECONDS:
			refuse(id, "")
		elif info.state == "room" and clock - float(info.since) > ROOM_SECONDS:
			refuse(id, "A sala fechou: ninguém entrou a tempo.")
	for game in matches.duplicate():
		step_match(game, dt)
	stats_time += dt
	if stats_time >= 60.0:
		stats_time = 0.0
		log_line("ONLINE_STATS peers=%d queue=%d rooms=%d matches=%d" % [peers.size(), queue.size(), rooms.size(), matches.size()])

# --- Lobby -------------------------------------------------------------------------

func valid_kit(first: String, second: String) -> bool:
	return PowerShop.index_of(first) >= 0 and PowerShop.index_of(second) >= 0

func new_code() -> String:
	for attempt in range(50):
		var code = ""
		for i in range(Online.CODE_LENGTH):
			code += Online.CODE_LETTERS[randi() % Online.CODE_LETTERS.length()]
		if not rooms.has(code):
			return code
	return ""

func welcome(id: int, protocol: int, skin: int, first: String, second: String, room: String) -> void:
	var info: Dictionary = peers.get(id, {})
	if info.is_empty() or info.state != "new":
		return
	if protocol != Online.PROTOCOL:
		refuse(id, "Há uma versão nova do jogo. Atualiza-o para jogar online.")
		return
	if skin < 0 or skin >= Skins.CATALOG.size() or not valid_kit(first, second):
		refuse(id, "")
		return
	info.skin = skin
	info.kit = [first, second]
	info.since = clock
	if room == "":
		if matches.size() >= MAX_MATCHES:
			refuse(id, "O servidor está cheio. Tenta daqui a pouco.")
			return
		while not queue.is_empty():
			var other: int = queue.pop_front()
			if peers.has(other) and other != id:
				start_match(other, id)
				return
		info.state = "queue"
		queue.append(id)
		online_waiting.rpc_id(id, "")
	elif room == Online.NEW_ROOM:
		var code = new_code() if rooms.size() < MAX_ROOMS else ""
		if code == "":
			refuse(id, "O servidor está cheio. Tenta daqui a pouco.")
			return
		info.state = "room"
		info.room = code
		rooms[code] = id
		online_waiting.rpc_id(id, code)
	else:
		var code = Online.clean_code(room)
		var host: int = rooms.get(code, 0)
		if host == 0 or host == id or not peers.has(host):
			refuse(id, "Não há nenhuma sala com o código %s." % code if code != "" else "Escreve o código da sala.")
			return
		if matches.size() >= MAX_MATCHES:
			refuse(id, "O servidor está cheio. Tenta daqui a pouco.")
			return
		rooms.erase(code)
		peers[host].room = ""
		start_match(host, id)

func start_match(first: int, second: int) -> void:
	var game = Match.new()
	game.peers = [first, second]
	game.rules = Rules.new()
	game.rules.set_map(Rules.pvp_map())
	for team in range(2):
		var info: Dictionary = peers[game.peers[team]]
		info.state = "match"
		info.match = game
		game.rules.loadouts[team] = info.kit + [String(Skins.CATALOG[int(info.skin)].ultimate)]
	game.rules.reset_match()
	if PowerShop.START_WITH_ULTIMATE_FOR_TESTS:
		for team in range(2):
			var cost = game.rules.power_charge_cost(team, 2)
			if cost > 0:
				game.rules.powers[team].charge[2] = cost
	matches.append(game)
	for team in range(2):
		var id: int = game.peers[team]
		var rival: Dictionary = peers[game.peers[1 - team]]
		online_matched.rpc_id(id, team)
		share_skin.rpc_id(id, int(rival.skin))
		share_kit.rpc_id(id, String(rival.kit[0]), String(rival.kit[1]))
	log_line("ONLINE_MATCH_START matches=%d" % matches.size())

func end_match(game: Match, reason: String, leaver: int = 0) -> void:
	if not matches.has(game):
		return
	matches.erase(game)
	for id in game.peers:
		if id == leaver or not peers.has(id):
			continue
		online_closed.rpc_id(id, reason)
		peers.erase(id)
		kick(id)
	log_line("ONLINE_MATCH_END matches=%d" % matches.size())

# --- Referee -----------------------------------------------------------------------

func team_of(game: Match, id: int) -> int:
	return game.peers.find(id)

func sender_match() -> Array:
	# [match, team] for the peer that sent the current call, or [] when it is not playing.
	var id = multiplayer.get_remote_sender_id()
	var info: Dictionary = peers.get(id, {})
	var game: Match = info.get("match", null)
	if game == null:
		return []
	return [game, team_of(game, id)]

func take_shot(game: Match, team: int) -> bool:
	if int(game.shots[team]) <= 0:
		return false
	if Time.get_ticks_msec() > int(game.shots_until[team]):
		game.shots[team] = 0
		return false
	if not game.rules.can_fire(team, 1.0 / Engine.physics_ticks_per_second):
		return false
	game.shots[team] = int(game.shots[team]) - 1
	game.shots_until[team] = Time.get_ticks_msec() + FIRE_BUFFER_MS
	return true

func step_match(game: Match, dt: float) -> void:
	if game.away[0] or game.away[1]:
		game.away_time += dt
		if game.away_time > AWAY_SECONDS:
			end_match(game, "O rival não voltou à partida.")
		return
	game.away_time = 0.0
	var commands: Array = []
	for team in range(2):
		game.ages[team] = float(game.ages[team]) + dt
		var stale = float(game.ages[team]) >= STALE_INPUT
		var slot = -1
		if int(game.powers[team]) >= 0:
			if Time.get_ticks_msec() > int(game.power_until[team]):
				game.powers[team] = -1
			elif game.rules.can_activate_power(team, int(game.powers[team])):
				slot = int(game.powers[team])
				game.powers[team] = -1
		var held: Dictionary = game.commands[team]
		var tap = false if (not stale and held.fire) else take_shot(game, team)
		commands.append({"move": Vector2.ZERO if stale else held.move, "fire": (false if stale else held.fire) or tap, "manual": tap, "power": slot})
	game.rules.step(dt, commands)
	var room = MAX_PENDING_EVENTS - game.events.size()
	if room > 0:
		game.events.append_array(game.rules.events.slice(0, room))
	game.tick += dt
	if game.tick >= 1.0 / SNAPSHOT_RATE:
		game.tick = 0.0
		var packet: Dictionary = game.rules.network_snapshot()
		packet["e"] = game.events
		game.events = []
		for id in game.peers:
			receive_state.rpc_id(id, packet)
	if game.rules.phase == "finished":
		if game.final_time < 0:
			game.final_time = 0.0
		game.final_time += dt
		if game.final_time >= FINAL_SECONDS:
			end_match(game, "")

# --- Remote calls: the same names and settings as scripts/main.gd --------------------

@rpc("any_peer", "call_remote", "reliable")
func online_hello(protocol: int, skin: int, first: String, second: String, room: String) -> void:
	welcome(multiplayer.get_remote_sender_id(), protocol, skin, first, second, room)

@rpc("authority", "call_remote", "reliable")
func online_waiting(_code: String) -> void:
	pass

@rpc("authority", "call_remote", "reliable")
func online_matched(_team: int) -> void:
	pass

@rpc("authority", "call_remote", "reliable")
func online_closed(_reason: String) -> void:
	pass

@rpc("any_peer", "call_remote", "reliable")
func share_skin(_skin: int) -> void:
	# The skin came with the hello; a later change is not taken mid-match.
	pass

@rpc("any_peer", "call_remote", "reliable")
func share_kit(_first: String, _second: String) -> void:
	pass

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(move: Vector2, firing: bool) -> void:
	var seat = sender_match()
	if seat.is_empty() or not move.is_finite():
		return
	var game: Match = seat[0]
	game.commands[seat[1]] = {"move": Vector2(clampf(move.x, -1, 1), 0), "fire": firing}
	game.ages[seat[1]] = 0.0

@rpc("any_peer", "call_remote", "reliable")
func submit_fire_tap() -> void:
	var seat = sender_match()
	if seat.is_empty():
		return
	var game: Match = seat[0]
	var team: int = seat[1]
	game.shots[team] = mini(int(game.shots[team]) + 1, MAX_QUEUED_SHOTS)
	game.shots_until[team] = Time.get_ticks_msec() + FIRE_BUFFER_MS

@rpc("any_peer", "call_remote", "reliable")
func submit_power(power: int) -> void:
	var seat = sender_match()
	if seat.is_empty() or power < 0 or power >= Rules.POWER_SLOTS:
		return
	var game: Match = seat[0]
	game.powers[seat[1]] = power
	game.power_until[seat[1]] = Time.get_ticks_msec() + POWER_HOLD_MS

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_state(_data: Dictionary) -> void:
	pass

@rpc("any_peer", "call_remote", "reliable")
func receive_peer_suspension(away: bool) -> void:
	# A phone went to the background: the match waits, and the rival is told why.
	var seat = sender_match()
	if seat.is_empty():
		return
	var game: Match = seat[0]
	var team: int = seat[1]
	game.away[team] = away
	game.commands[team] = {"move": Vector2.ZERO, "fire": false}
	game.shots[team] = 0
	receive_peer_suspension.rpc_id(game.peers[1 - team], away)
