extends RefCounted
# Events waiting to be sent. Kept in memory while the game runs and written to disk when
# it goes to the background or quits, so an offline match is not lost. Bounded in count
# and size; each event carries a uuid, so a batch sent twice is counted once.

const MAX_EVENTS = 500
const MAX_BYTES = 256 * 1024
const BATCH = 50
# Retry after a failed send: 30 s, then doubling, at most 10 minutes.
const RETRY_FIRST = 30.0
const RETRY_MAX = 600.0

var path = "user://analytics_queue.json"
var events: Array = []
var in_flight: Array = []
var retry_wait = 0.0
var retry_left = 0.0
var dropped = 0

func size() -> int:
	return events.size() + in_flight.size()

func push(event: Dictionary) -> void:
	events.append(event)
	while events.size() + in_flight.size() > MAX_EVENTS and not events.is_empty():
		# The oldest go first: recent events say more about what is happening now.
		events.pop_front()
		dropped += 1

func ready_to_send() -> bool:
	return in_flight.is_empty() and not events.is_empty() and retry_left <= 0

func take_batch() -> Array:
	in_flight = events.slice(0, BATCH)
	events = events.slice(BATCH)
	return in_flight

func sent(ok: bool) -> void:
	if ok:
		in_flight = []
		retry_wait = 0.0
		retry_left = 0.0
		return
	# Back to the front, in order, for the next try.
	events = in_flight + events
	in_flight = []
	retry_wait = RETRY_FIRST if retry_wait <= 0 else minf(retry_wait * 2.0, RETRY_MAX)
	retry_left = retry_wait

func clear() -> void:
	events.clear()
	in_flight.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func save() -> int:
	var all: Array = in_flight + events
	var text = JSON.stringify(all)
	while text.length() > MAX_BYTES and not all.is_empty():
		all.pop_front()
		text = JSON.stringify(all)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK

func restore() -> void:
	if not FileAccess.file_exists(path):
		return
	var text = FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text) if text.length() <= MAX_BYTES else null
	if typeof(data) != TYPE_ARRAY:
		return
	var seen: Dictionary = {}
	for event in events:
		seen[event.get("uuid", "")] = true
	var restored: Array = []
	for event in data:
		if typeof(event) == TYPE_DICTIONARY and event.has("uuid") and event.has("event") and not seen.has(event.uuid):
			seen[event.uuid] = true
			restored.append(event)
	events = restored + events
	while events.size() > MAX_EVENTS:
		events.pop_front()
