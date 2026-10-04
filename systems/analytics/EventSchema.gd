extends RefCounted
# Every event the game may send, with the parameters each one accepts and their types.
# Anything else is refused before it reaches the queue: an unknown name, an unknown
# parameter, a wrong type, a text too long. The game uses the constants, never strings.

const FIRST_OPEN = "first_open"
const GAME_OPEN = "game_open"
const SESSION_START = "session_start"
const SESSION_END = "session_end"
const APP_BACKGROUND = "app_background"
const APP_FOREGROUND = "app_foreground"
const CONSENT_CHANGED = "consent_changed"
const LANGUAGE_CHANGED = "language_changed"
const APP_ERROR = "app_error"

const MAX_PARAMS = 25
const MAX_TEXT = 100
const MAX_NAME = 40

# name -> {parameter: type}. Types: TYPE_INT, TYPE_FLOAT (ints accepted), TYPE_STRING,
# TYPE_BOOL.
const EVENTS = {
	FIRST_OPEN: {},
	GAME_OPEN: {"cold_start": TYPE_BOOL},
	SESSION_START: {"session_number": TYPE_INT},
	SESSION_END: {"duration_s": TYPE_INT, "reason": TYPE_STRING},
	APP_BACKGROUND: {"seconds_in_session": TYPE_INT, "screen": TYPE_STRING},
	APP_FOREGROUND: {"seconds_away": TYPE_INT},
	CONSENT_CHANGED: {"analytics": TYPE_BOOL, "errors": TYPE_BOOL, "policy_version": TYPE_INT, "source": TYPE_STRING},
	LANGUAGE_CHANGED: {"from": TYPE_STRING, "to": TYPE_STRING, "source": TYPE_STRING},
	APP_ERROR: {"message": TYPE_STRING, "where": TYPE_STRING, "kind": TYPE_STRING, "screen": TYPE_STRING, "count": TYPE_INT},
}

# Error reports travel under their own consent, separate from gameplay statistics.
const ERROR_EVENTS = [APP_ERROR]

static func is_known(event: String) -> bool:
	return EVENTS.has(event)

# Returns "" when the event is valid, or why it is not.
static func validate(event: String, params: Dictionary) -> String:
	if not EVENTS.has(event):
		return "unknown event " + event
	if params.size() > MAX_PARAMS:
		return "too many parameters"
	var allowed: Dictionary = EVENTS[event]
	for key in params:
		if typeof(key) != TYPE_STRING or not allowed.has(key):
			return "unknown parameter %s for %s" % [str(key), event]
		var wanted: int = allowed[key]
		var value = params[key]
		var got := typeof(value)
		if wanted == TYPE_FLOAT and got == TYPE_INT:
			continue
		if got != wanted:
			return "%s.%s must be %s" % [event, key, type_string(wanted)]
		if got == TYPE_STRING and String(value).length() > MAX_TEXT:
			return "%s.%s is too long" % [event, key]
		if got == TYPE_FLOAT and not is_finite(value):
			return "%s.%s is not a number" % [event, key]
	return ""

static func is_error_event(event: String) -> bool:
	return ERROR_EVENTS.has(event)
