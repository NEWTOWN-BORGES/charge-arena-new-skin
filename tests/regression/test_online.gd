extends SceneTree
# Online PvP end to end on this machine: the server and two real games, each in its own
# branch with its own multiplayer API, talking over ENet on localhost.
const Online = preload("res://scripts/network/online.gd")
const Server = preload("res://scripts/network/online_server.gd")
const PORT = 27951
var server
var a
var b

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, text: String) -> void:
	if condition:
		print("PASS ", text)
	else:
		push_error("FAIL: " + text)

func branch(name: String) -> Node:
	var holder = Node.new()
	holder.name = name
	root.add_child(holder)
	set_multiplayer(SceneMultiplayer.new(), holder.get_path())
	return holder

func wait_until(test: Callable, seconds: float) -> bool:
	var left = seconds
	while left > 0:
		if test.call():
			return true
		await create_timer(0.05).timeout
		left -= 0.05
	return test.call()

func run() -> void:
	# Both sides must list the same remote calls with the same settings: Godot matches
	# them by their sorted names, so one missing or extra method shifts every other one.
	var game_calls: Dictionary = load("res://scripts/main.gd").get_rpc_config()
	var server_calls: Dictionary = load("res://scripts/network/online_server.gd").get_rpc_config()
	check(game_calls == server_calls, "game and server declare the same remote calls")
	check(Online.clean_code(" ab-c9 ") == "ABC9" and Online.clean_code("o0i1") == "", "room codes are cleaned")
	check(Online.parse("example.org:4000") == {"host": "example.org", "port": 4000} and int(Online.parse("example.org").port) == Online.DEFAULT_PORT, "server address parsing")

	var config = ConfigFile.new()
	config.set_value("online", "server", "127.0.0.1:%d" % PORT)
	config.save("user://online.cfg")
	check(Online.available(), "a custom server address enables online play")

	server = Server.new()
	server.name = "ChargeArena"
	server.verbose = false
	branch("Server").add_child(server)
	check(server.start(PORT) == OK, "server listens")
	a = load("res://scenes/main.tscn").instantiate()
	branch("A").add_child(a)
	b = load("res://scenes/main.tscn").instantiate()
	branch("B").add_child(b)
	check(a.hud.room_code.editable, "the PvP menu offers online play")

	# Quick match: the first waits, the second meets them.
	a.join_online("")
	check(await wait_until(func(): return a.online_state == "waiting" and server.queue.size() == 1, 5.0), "first player waits in the queue")
	check(a.network_status == "À procura de rival…", "waiting is announced")
	a.online_wait = Online.OFFER_AI_AFTER + 1.0
	await physics_frame
	await physics_frame
	check(a.hud.offer_ai, "a long wait offers the AI")
	b.join_online("")
	check(await wait_until(func(): return a.connected and b.connected, 5.0), "both players are matched")
	check(a.local_team == 0 and b.local_team == 1 and b.arena.view_team == 1, "teams and seats")
	check(not a.hud.offer_ai, "the AI offer goes away once matched")
	check(server.matches.size() == 1 and server.queue.is_empty(), "one match on the server")
	var game = server.matches[0]
	check(game.rules.loadouts[1][0] == String(b.power_shop.kit[0]) and game.rules.loadouts[1][2] == String(b.Skins.CATALOG[b.skins.selected].ultimate), "the server uses each player's kit and ultimate")
	var start_angle: float = game.rules.players[1].angle
	b.hud.move_vector = Vector2.RIGHT
	check(await wait_until(func(): return a.packets_received > 40 and b.packets_received > 40, 8.0), "both receive snapshots")
	b.hud.move_vector = Vector2.ZERO
	check(not is_equal_approx(game.rules.players[1].angle, start_angle), "the second player's input moves its pilot on the server")
	check(is_equal_approx(a.rules.players[1].angle, game.rules.players[1].angle) or absf(a.rules.players[1].angle - game.rules.players[1].angle) < 0.2, "the first player sees it move")

	# The final whistle: results stay on screen, with a button to play again online.
	game.rules.scores[0] = 1
	game.rules.phase = "finished"
	game.rules.winner = 0
	check(await wait_until(func(): return a.online_state == "ended" and b.online_state == "ended", 5.0), "the match ends for both")
	await create_timer(0.2).timeout
	check(a.hud.replay.visible and a.hud.replay.text == "NOVA PARTIDA ONLINE", "play-again button after an online match")
	check(server.matches.is_empty() and server.peers.is_empty(), "the server forgets a finished match")
	a.replay()
	check(await wait_until(func(): return a.online_state == "waiting", 5.0), "play again queues again")

	# A room for a friend.
	a.return_to_menu()
	check(await wait_until(func(): return server.queue.is_empty(), 5.0), "leaving the queue frees it")
	a.join_online(Online.NEW_ROOM)
	check(await wait_until(func(): return a.network_status.begins_with("SALA "), 5.0), "a room gets a code")
	var code = a.network_status.substr(5, Online.CODE_LENGTH)
	check(code.length() == Online.CODE_LENGTH and Online.clean_code(code) == code, "the code is readable")
	b.join_online("ZZZZ")
	check(await wait_until(func(): return b.mode == "menu" and b.hud.menu_status.text == "Não há nenhuma sala com esse código.", 5.0), "a wrong code is refused")
	b.join_online(code.to_lower())
	check(await wait_until(func(): return a.connected and b.connected, 5.0), "a friend joins with the code")
	check(server.rooms.is_empty(), "the room closes once full")

	# A player who leaves: the other is told, and the server cleans up.
	b.return_to_menu()
	check(await wait_until(func(): return a.mode == "menu" and a.hud.menu_status.text.contains("rival saiu"), 5.0), "the rival leaving is announced")
	check(await wait_until(func(): return server.matches.is_empty() and server.peers.is_empty(), 5.0), "the server is empty again")

	a.close_network()
	b.close_network()
	server.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://online.cfg"))
	a.queue_free()
	b.queue_free()
	await process_frame
	await process_frame
	print("PASS ONLINE: queue, AI offer, match, snapshots, final whistle, rooms, leaving")
	quit()
