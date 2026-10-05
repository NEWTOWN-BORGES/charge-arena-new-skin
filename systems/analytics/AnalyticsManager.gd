extends Node
# Gameplay statistics and error reports, with the player's consent.
#
# The game calls the static facade, which does nothing when no manager is installed
# (tests, tools), so no call site needs to know whether analytics exists:
#     AnalyticsManager.track(EventSchema.MATCH_END, {...})
#
# track() only validates and queues; sending happens in batches over HTTP on a thread,
# every FLUSH_SECONDS, when a batch fills up, and when the game goes to the background.
# Nothing is ever sent per frame.

const EventSchema = preload("res://systems/analytics/EventSchema.gd")
const PrivacyManager = preload("res://systems/analytics/PrivacyManager.gd")
const EventQueue = preload("res://systems/analytics/EventQueue.gd")
const BuildInfo = preload("res://systems/analytics/BuildInfo.gd")
const AnalyticsConfig = preload("res://systems/analytics/AnalyticsConfig.gd")
const ErrorMonitor = preload("res://systems/analytics/ErrorMonitor.gd")
const NullProvider = preload("res://systems/analytics/providers/NullProvider.gd")
const DebugProvider = preload("res://systems/analytics/providers/DebugProvider.gd")
const PostHogProvider = preload("res://systems/analytics/providers/PostHogProvider.gd")

const META = "charge_arena_analytics"
# Away longer than this and coming back starts a new session.
const SESSION_GAP = 30.0

signal consent_changed

var privacy = PrivacyManager.new()
var queue = EventQueue.new()
var provider
var errors
var id_path = "user://analytics_id.cfg"
var anonymous_id = ""
var first_open_pending = false
var session_id = ""
var session_number = 0
var session_started_ms = 0
# When the game went to the background (ticks), or -1 while it is on screen.
var background_ms = -1
var flush_timer = 0.0
var screen = "menu"
var tier = "normal"
var rejected: Array = []

# --- Facade ------------------------------------------------------------------------

static func instance():
	return Engine.get_meta(META) if Engine.has_meta(META) else null

static func track(event: String, params: Dictionary = {}) -> bool:
	var manager = instance()
	return manager.record(event, params) if manager != null else false

static func set_screen(name: String) -> void:
	var manager = instance()
	if manager != null:
		manager.screen = name

# Installs the manager under `parent` (the game's root). `provider_kind` overrides the
# choice from the build: "null", "debug" or "posthog".
static func install(parent: Node, provider_kind: String = "") -> Node:
	var manager = new()
	manager.name = "Analytics"
	manager.provider = make_provider(provider_kind)
	parent.add_child(manager)
	return manager

static func make_provider(kind: String) -> Node:
	var key = AnalyticsConfig.API_KEY if BuildInfo.production() else AnalyticsConfig.DEV_API_KEY
	if kind == "":
		# Automated runs (no screen) never send anything anywhere.
		if DisplayServer.get_name() == "headless":
			return NullProvider.new()
		if OS.get_cmdline_user_args().has("--analytics-debug"):
			kind = "debug"
		else:
			kind = AnalyticsConfig.PROVIDER if key != "" else "null"
	match kind:
		"debug":
			return DebugProvider.new()
		"posthog":
			var posthog = PostHogProvider.new()
			posthog.host = AnalyticsConfig.HOST
			posthog.api_key = key
			return posthog
	return NullProvider.new()

# --- Life cycle ----------------------------------------------------------------------

func _enter_tree() -> void:
	Engine.set_meta(META, self)

func _exit_tree() -> void:
	if instance() == self:
		end_session("quit")
		save_queue()
		Engine.remove_meta(META)
	if errors != null:
		OS.remove_logger(errors)
		errors = null

func _ready() -> void:
	if provider == null:
		provider = NullProvider.new()
	provider.name = "Provider"
	add_child(provider)
	provider.finished.connect(_on_sent)
	privacy.load_choices()
	load_identity()
	if provider.active():
		queue.restore()
	errors = ErrorMonitor.new()
	OS.add_logger(errors)
	tier = "low" if preload("res://scripts/settings/video_settings.gd").low_end() else "normal"
	start_session()
	record(EventSchema.GAME_OPEN, {"cold_start": true})

func load_identity() -> void:
	var config = ConfigFile.new()
	if config.load(id_path) == OK:
		anonymous_id = String(config.get_value("analytics", "id", ""))
		session_number = int(config.get_value("analytics", "sessions", 0))
		first_open_pending = not bool(config.get_value("analytics", "first_open_sent", false))
	if not is_uuid(anonymous_id):
		anonymous_id = uuid4()
		session_number = 0
		first_open_pending = true
	save_identity()

func save_identity() -> void:
	var config = ConfigFile.new()
	config.set_value("analytics", "id", anonymous_id)
	config.set_value("analytics", "sessions", session_number)
	config.set_value("analytics", "first_open_sent", not first_open_pending)
	config.save(id_path)

static func uuid4() -> String:
	var b: PackedByteArray = Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h = b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]

static func is_uuid(text: String) -> bool:
	var pattern = RegEx.create_from_string("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
	return pattern.search(text) != null

# --- Sessions ------------------------------------------------------------------------

func start_session() -> void:
	session_id = uuid4()
	session_number += 1
	session_started_ms = Time.get_ticks_msec()
	save_identity()
	record(EventSchema.SESSION_START, {"session_number": session_number})

func end_session(reason: String, at_ms: int = -1) -> void:
	if session_id == "":
		return
	var end_ms = at_ms if at_ms >= 0 else Time.get_ticks_msec()
	record(EventSchema.SESSION_END, {"duration_s": int((end_ms - session_started_ms) / 1000.0), "reason": reason})
	session_id = ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile")):
		went_background()
	elif what == NOTIFICATION_APPLICATION_RESUMED or (what == NOTIFICATION_APPLICATION_FOCUS_IN and OS.has_feature("mobile")):
		came_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		end_session("quit")
		save_queue()

func went_background() -> void:
	if background_ms >= 0:
		return
	background_ms = Time.get_ticks_msec()
	record(EventSchema.APP_BACKGROUND, {"seconds_in_session": int((background_ms - session_started_ms) / 1000.0), "screen": screen})
	flush()
	save_queue()

func came_back(now_ms: int = -1) -> void:
	if background_ms < 0:
		return
	var away = ((now_ms if now_ms >= 0 else Time.get_ticks_msec()) - background_ms) / 1000.0
	var left_at = background_ms
	background_ms = -1
	if away >= SESSION_GAP:
		end_session("background", left_at)
		start_session()
	else:
		record(EventSchema.APP_FOREGROUND, {"seconds_away": int(away)})

# --- Consent -------------------------------------------------------------------------

func needs_prompt() -> bool:
	return privacy.needs_prompt()

func set_consent(allow_analytics: bool, allow_errors: bool, source: String) -> void:
	var had_analytics = privacy.analytics_allowed()
	privacy.choose(allow_analytics, allow_errors)
	if had_analytics and not allow_analytics:
		# Withdrawn: what was waiting is not sent.
		queue.clear()
	record(EventSchema.CONSENT_CHANGED, {"analytics": allow_analytics, "errors": allow_errors, "policy_version": PrivacyManager.POLICY_VERSION, "source": source})
	consent_changed.emit()

# --- Recording -----------------------------------------------------------------------

func allowed(event: String) -> bool:
	return privacy.errors_allowed() if EventSchema.is_error_event(event) else privacy.analytics_allowed()

func record(event: String, params: Dictionary = {}) -> bool:
	var problem = EventSchema.validate(event, params)
	if problem != "":
		# Logged quietly: an analytics mistake must never look like a game error.
		rejected.append(problem)
		if OS.is_debug_build():
			print_verbose("[ANALYTICS] refused: ", problem)
		return false
	if not allowed(event) or not provider.active():
		return false
	if first_open_pending and not EventSchema.is_error_event(event):
		# The install is counted the first time the player lets anything be counted.
		first_open_pending = false
		save_identity()
		queue.push(build(EventSchema.FIRST_OPEN, {}))
	queue.push(build(event, params))
	if queue.events.size() >= AnalyticsConfig.BATCH_SIZE:
		flush()
	return true

func common() -> Dictionary:
	return {
		"session_id": session_id,
		"game_version": BuildInfo.VERSION,
		"build_number": BuildInfo.BUILD,
		"build_flavor": BuildInfo.flavor(),
		"store": BuildInfo.store(),
		"platform": BuildInfo.platform(),
		"os_version": BuildInfo.os_version(),
		"device_model": BuildInfo.device_model(),
		"device_tier": tier,
		"game_language": TranslationServer.get_locale(),
		"system_locale": OS.get_locale(),
	}

func build(event: String, params: Dictionary) -> Dictionary:
	var properties = common()
	properties.merge(params, true)
	return {"event": event, "properties": properties, "distinct_id": anonymous_id,
		"timestamp": Time.get_datetime_string_from_system(true) + "Z", "uuid": uuid4()}

# --- Sending -------------------------------------------------------------------------

func _process(dt: float) -> void:
	if errors != null and privacy.errors_allowed():
		for note in errors.take():
			note["screen"] = screen
			record(EventSchema.APP_ERROR, note)
	flush_timer += dt
	if flush_timer >= AnalyticsConfig.FLUSH_SECONDS:
		flush_timer = 0.0
		flush()
	if queue.retry_left > 0:
		queue.retry_left = maxf(queue.retry_left - dt, 0.0)

func flush() -> void:
	flush_timer = 0.0
	if not provider.active() or not queue.ready_to_send():
		return
	provider.send(queue.take_batch())

func _on_sent(ok: bool) -> void:
	queue.sent(ok)

func save_queue() -> void:
	if provider != null and provider.active() and queue.size() > 0:
		queue.save()
