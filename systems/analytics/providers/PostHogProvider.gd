extends "res://systems/analytics/AnalyticsProvider.gd"
# PostHog Cloud, EU region, through its public batch endpoint. The project API key is a
# write-only key meant to ship inside apps; it cannot read data back. No admin key or
# personal API key ever goes into the game.

const TIMEOUT = 15.0

var host = "https://eu.i.posthog.com"
var api_key = ""
var http: HTTPRequest

func provider_name() -> String:
	return "posthog"

func active() -> bool:
	return api_key != "" and host.begins_with("https://")

func _ready() -> void:
	http = HTTPRequest.new()
	http.use_threads = true
	http.timeout = TIMEOUT
	add_child(http)
	http.request_completed.connect(_on_completed)

# The body PostHog expects. Players stay anonymous: no person profiles are built, and
# the distinct id is the random id made on the phone.
func payload(batch: Array) -> Dictionary:
	var items: Array = []
	for event in batch:
		var properties: Dictionary = event.properties.duplicate()
		properties["distinct_id"] = event.distinct_id
		properties["$process_person_profile"] = false
		properties["$lib"] = "charge-arena-godot"
		# The phone's address never reaches PostHog's records: PostHog takes the request's
		# address unless the event names one, so every event names a blank one, and no
		# location is looked up from it. The region comes from the phone's own locale
		# (system_locale), which is all the game needs.
		properties["$ip"] = "0.0.0.0"
		properties["$geoip_disable"] = true
		items.append({"event": event.event, "properties": properties, "timestamp": event.timestamp, "uuid": event.uuid})
	return {"api_key": api_key, "batch": items}

func send(batch: Array) -> void:
	if not active() or http == null:
		finished.emit.call_deferred(false)
		return
	var body = JSON.stringify(payload(batch))
	var error = http.request(host.trim_suffix("/") + "/batch/", ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if error != OK:
		finished.emit.call_deferred(false)

func _on_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	# A refused batch (4xx other than rate limiting) would be refused again: drop it.
	var ok = result == HTTPRequest.RESULT_SUCCESS and (code >= 200 and code < 300 or (code >= 400 and code < 500 and code != 429))
	finished.emit(ok)
