extends SceneTree
# Analytics without a network: identity, consent, validation, the queue, sessions, error
# notes and the PostHog body. Nothing here leaves the machine.
const Manager = preload("res://systems/analytics/AnalyticsManager.gd")
const Schema = preload("res://systems/analytics/EventSchema.gd")
const Queue = preload("res://systems/analytics/EventQueue.gd")
const BuildInfo = preload("res://systems/analytics/BuildInfo.gd")
const DebugProvider = preload("res://systems/analytics/providers/DebugProvider.gd")
const PostHog = preload("res://systems/analytics/providers/PostHogProvider.gd")

var failures = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, text: String) -> void:
	if condition:
		print("PASS ", text)
	else:
		failures += 1
		printerr("FAIL: ", text)

func fresh_manager(tag: String):
	var manager = Manager.new()
	manager.provider = DebugProvider.new()
	manager.privacy.path = "user://test-privacy-%s.cfg" % tag
	manager.id_path = "user://test-id-%s.cfg" % tag
	manager.queue.path = "user://test-queue-%s.json" % tag
	root.add_child(manager)
	return manager

func names(events: Array) -> Array:
	return events.map(func(e): return e.event)

func run() -> void:
	# The build the numbers say they come from is the build that was exported.
	var presets = ConfigFile.new()
	presets.load("res://export_presets.cfg")
	check(String(presets.get_value("preset.0.options", "version/name")).begins_with(BuildInfo.VERSION) and int(presets.get_value("preset.0.options", "version/code")) == BuildInfo.BUILD, "BuildInfo matches the export presets")
	check(BuildInfo.flavor() == "dev" and not BuildInfo.production(), "tests are a development build")

	var a = Manager.uuid4()
	check(Manager.is_uuid(a) and a != Manager.uuid4(), "random v4 ids")

	check(Schema.validate(Schema.SESSION_END, {"duration_s": 12, "reason": "quit"}) == "", "a valid event passes")
	check(Schema.validate("made_up", {}) != "", "an unknown event is refused")
	check(Schema.validate(Schema.SESSION_END, {"duration_s": "12"}) != "", "a wrong type is refused")
	check(Schema.validate(Schema.SESSION_END, {"player_name": "x"}) != "", "an unknown parameter is refused")
	check(Schema.validate(Schema.APP_ERROR, {"message": "x".repeat(200)}) != "", "a long text is refused")

	# The queue: bounded, retried with growing waits, saved and restored without doubles.
	var q = Queue.new()
	q.path = "user://test-queue-unit.json"
	for i in range(Queue.MAX_EVENTS + 10):
		q.push({"event": "e", "uuid": str(i), "properties": {}})
	check(q.size() == Queue.MAX_EVENTS and q.dropped == 10 and q.events[0].uuid == "10", "the queue keeps the newest 500")
	var batch = q.take_batch()
	check(batch.size() == Queue.BATCH and not q.ready_to_send(), "one batch in flight at a time")
	q.sent(false)
	check(q.retry_left == Queue.RETRY_FIRST and q.events[0].uuid == "10", "a failed batch goes back first and waits")
	q.retry_left = 0
	q.take_batch()
	q.sent(false)
	check(q.retry_wait == Queue.RETRY_FIRST * 2, "the wait doubles")
	q.retry_left = 0
	q.take_batch()
	q.sent(true)
	check(q.size() == Queue.MAX_EVENTS - Queue.BATCH and q.retry_wait == 0, "a sent batch leaves the queue")
	check(q.save() == OK, "the queue is saved")
	var r = Queue.new()
	r.path = q.path
	r.push(q.events[3].duplicate())
	r.restore()
	check(r.size() == q.size(), "restoring does not double an event already queued")
	q.clear()

	# Consent first: nothing is counted before the player says yes.
	var m = fresh_manager("a")
	check(m.needs_prompt() and m.queue.size() == 0, "no consent, nothing queued")
	check(not Manager.track(Schema.GAME_OPEN, {"cold_start": false}), "the facade refuses without consent")
	var anon: String = m.anonymous_id
	check(Manager.is_uuid(anon), "an anonymous id is made")
	m.set_consent(true, true, "first_launch")
	check(not m.needs_prompt(), "the choice is remembered")
	check(names(m.queue.events) == [Schema.FIRST_OPEN, Schema.CONSENT_CHANGED], "the install is counted when consent arrives")
	check(Manager.track(Schema.GAME_OPEN, {"cold_start": false}), "the facade records with consent")
	var props: Dictionary = m.queue.events[-1].properties
	for key in ["session_id", "game_version", "build_number", "build_flavor", "platform", "device_model", "device_tier", "game_language", "system_locale"]:
		check(props.has(key), "common property " + key)
	check(m.queue.events[-1].distinct_id == anon and not props.has("ip"), "events carry the anonymous id and no address")
	m.flush()
	await process_frame
	await process_frame
	check(m.queue.size() == 0 and m.provider.sent.size() == 3, "a flush sends the batch")

	# Sessions: a short trip away stays in the session, a long one starts another.
	var first_session: String = m.session_id
	m.went_background()
	m.came_back()
	check(m.session_id == first_session and names(m.queue.events).has(Schema.APP_FOREGROUND), "a short absence keeps the session")
	m.went_background()
	m.came_back(m.background_ms + 40000)
	check(m.session_id != first_session and names(m.queue.events).has(Schema.SESSION_END) and m.session_number == 2, "a long absence starts a new session")

	var none: Array[ScriptBacktrace] = []
	# Error notes, from the engine's logger, become app_error with the screen they hit.
	Manager.set_screen("shop")
	m.errors._log_error("buy", "res://scripts/ui/game_hud.gd", 10, "", "Invalid index", false, Logger.ERROR_TYPE_SCRIPT, none)
	m.errors._log_error("buy", "res://scripts/ui/game_hud.gd", 10, "", "Invalid index", false, Logger.ERROR_TYPE_SCRIPT, none)
	m.errors._log_error("x", "y.gd", 1, "", "only a warning", false, Logger.ERROR_TYPE_WARNING, none)
	await process_frame
	var reports = m.queue.events.filter(func(e): return e.event == Schema.APP_ERROR)
	check(reports.size() == 1 and reports[0].properties.screen == "shop" and reports[0].properties.count == 2 and reports[0].properties.where.begins_with("game_hud.gd:10"), "errors are reported once, with a count, warnings never")

	# Withdrawing: what waits is dropped and nothing more is counted; errors can stay on.
	m.set_consent(false, true, "options")
	check(m.queue.size() == 0 and not Manager.track(Schema.GAME_OPEN, {"cold_start": false}), "withdrawn consent sends nothing more")
	m.errors._log_error("f", "z.gd", 2, "", "another", false, Logger.ERROR_TYPE_ERROR, none)
	await process_frame
	check(m.queue.events.size() == 1 and m.queue.events[0].event == Schema.APP_ERROR, "error reports keep their own switch")
	m.queue.clear()
	m.queue_free()
	await process_frame

	# The id survives a restart, and the install is not counted twice.
	var again = fresh_manager("a")
	check(again.anonymous_id == anon and not again.first_open_pending and again.session_number == 3, "the id and session count survive a restart")
	again.queue.clear()
	again.queue_free()
	await process_frame
	check(Manager.instance() == null, "the facade is inert without a manager")

	# The PostHog body: the batch endpoint's shape, anonymous, no person profiles.
	var posthog = PostHog.new()
	posthog.api_key = "phc_test"
	var body = posthog.payload([{"event": "game_open", "properties": {"a": 1}, "distinct_id": anon, "timestamp": "2026-01-01T00:00:00Z", "uuid": a}])
	check(body.api_key == "phc_test" and body.batch[0].uuid == a and body.batch[0].properties.distinct_id == anon and body.batch[0].properties["$process_person_profile"] == false, "PostHog batch body")
	var keyless = PostHog.new()
	check(posthog.active() and not keyless.active(), "PostHog needs a key to send")
	posthog.free()
	keyless.free()

	for tag in ["a"]:
		for path in ["user://test-privacy-%s.cfg", "user://test-id-%s.cfg", "user://test-queue-%s.json"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path % tag))
	print("ANALYTICS_RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
