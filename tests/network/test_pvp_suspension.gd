extends SceneTree
## Both peers must freeze the authoritative match while either app is in the background.
var failures = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func run() -> void:
	assert("ChargeArenaQA" in OS.get_user_data_dir())
	var host = OS.get_cmdline_user_args().has("--host")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.game_settings.auto_fire = false
	game.hud.sync_game(game.game_settings)
	if host: game.host_game()
	else: game.join_game("127.0.0.1")
	var own_paused = false
	var own_resumed = false
	var peer_paused = false
	var peer_resumed = false
	var pause_at = 0
	var own_clock = 0.0
	var peer_clock = 0.0
	var deadline = Time.get_ticks_msec() + 45000
	var both_ready_at = 0
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
		if not game.connected: continue
		var now = Time.get_ticks_msec()
		if game.remote_backgrounded and not peer_paused:
			peer_paused = true
			peer_clock = game.rules.match_clock
			check(game.network_status != "" and game.hud.host_ai_button.visible == false, "Peer suspension has a waiting state, not an AI replacement")
		elif game.remote_backgrounded:
			check(is_equal_approx(game.rules.match_clock, peer_clock), "The match clock stays frozen while the peer is away")
		elif peer_paused and not peer_resumed:
			peer_resumed = true
			check(game.network_status == "", "Peer return clears the waiting state")
		if not own_paused and ((host and game.rules.match_clock > 0.5) or (not host and peer_resumed)):
			own_clock = game.rules.match_clock
			game.go_background(true)
			own_paused = true
			pause_at = now
		elif own_paused and not own_resumed and now - pause_at > 2100:
			check(is_equal_approx(game.rules.match_clock, own_clock), "Local background does not advance the match")
			game.go_background(false)
			own_resumed = true
		if own_resumed and peer_resumed and not game.remote_backgrounded and both_ready_at == 0:
			both_ready_at = now
		if both_ready_at > 0 and now - both_ready_at > 3000:
			check(game.rules.match_clock > maxf(own_clock, peer_clock) + 0.2, "The same match resumes and advances after both peers return")
			check(game.rules.scores == [0, 0], "Suspension does not start a new round or score a goal")
			print("SUSPENSION_RESULT role=", "host" if host else "client", " failures=", failures)
			await create_timer(2.0 if host else 0.5).timeout
			game.close_network()
			game.queue_free()
			await process_frame
			await process_frame
			quit(failures)
			return
	push_error("FAIL: Suspension handshake timed out")
	game.close_network()
	game.queue_free()
	await process_frame
	quit(1)
