extends Node
# Where batches of events go. The manager hands over one batch at a time and waits for
# `finished` before the next; a provider never blocks the game.

signal finished(ok: bool)

func provider_name() -> String:
	return "none"

# False when the provider cannot send anything (no key, no network code): the manager
# then keeps nothing on disk either.
func active() -> bool:
	return false

func send(_batch: Array) -> void:
	finished.emit.call_deferred(true)
