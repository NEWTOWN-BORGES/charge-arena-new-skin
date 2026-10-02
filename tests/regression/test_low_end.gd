extends SceneTree
# Entry-level phones (32-bit Android Go, little memory) start light and steady.
var failures = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var Video = load("res://scripts/settings/video_settings.gd")
	const GB = 1024 * 1024 * 1024
	check(Video.low_end(false, 4 * GB), "A 32-bit Android (Android Go, like a Redmi A3) is entry level")
	check(Video.low_end(true, 3 * GB), "A 64-bit phone with 3 GB is entry level")
	check(not Video.low_end(true, 8 * GB), "A 64-bit phone with 8 GB is not")
	check(not Video.low_end(), "A PC is never entry level")
	var video = Video.new()
	check(video.fps == 60 or OS.has_feature("mobile"), "On a PC the frame rate stays at 60")
	print("LOW_END_RESULT failures=%d" % failures)
	quit(failures)
