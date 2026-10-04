extends "res://systems/analytics/AnalyticsProvider.gd"
# Prints each event as [ANALYTICS] to the console instead of sending it: for checking
# the instrumentation on a development build.

var sent: Array = []

func provider_name() -> String:
	return "debug"

func active() -> bool:
	return true

func send(batch: Array) -> void:
	for event in batch:
		print("[ANALYTICS] ", event.event, " ", JSON.stringify(event.properties))
		sent.append(event)
	finished.emit.call_deferred(true)
