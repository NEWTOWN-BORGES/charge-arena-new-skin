extends SceneTree
# Starts the online PvP server without a window or sound:
#   godot --headless --path <project> --script res://scripts/network/server_main.gd -- --port=27941

const Online = preload("res://scripts/network/online.gd")
const Server = preload("res://scripts/network/online_server.gd")

func _initialize() -> void:
	# The tree's multiplayer exists once the main loop runs, not yet here.
	call_deferred("launch")

func launch() -> void:
	var port = Online.DEFAULT_PORT
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port=") and arg.trim_prefix("--port=").is_valid_int():
			port = clampi(int(arg.trim_prefix("--port=")), 1, 65535)
	randomize()
	var server = Server.new()
	# The game's root node is called this; remote calls address it by that path.
	server.name = "ChargeArena"
	root.add_child(server)
	var error = server.start(port)
	if error != OK:
		printerr("ONLINE_SERVER_FAILED port=%d error=%d" % [port, error])
		quit(1)
