extends Logger
# Catches the engine's and the scripts' errors as they are logged, from any thread, and
# keeps a short note of each for the manager to report on the main thread. Warnings and
# ordinary messages are ignored. Nothing is printed from here: that would log again.

const MAX_PER_SESSION = 20
const MAX_TEXT = 100

var mutex = Mutex.new()
var pending: Array = []
var counts: Dictionary = {}
var reported = 0

func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	var message = rationale if rationale != "" else code
	var where = "%s:%d %s" % [file.get_file(), line, function]
	var key = where + "|" + message
	mutex.lock()
	if counts.has(key):
		counts[key] = int(counts[key]) + 1
	elif reported < MAX_PER_SESSION:
		counts[key] = 1
		reported += 1
		pending.append({"message": message.substr(0, MAX_TEXT), "where": where.substr(0, MAX_TEXT),
			"kind": ["error", "warning", "script", "shader"][clampi(error_type, 0, 3)], "key": key})
	mutex.unlock()

func _log_message(_message: String, _error: bool) -> void:
	pass

# The notes gathered since the last call, each with how many times it happened so far.
func take() -> Array:
	mutex.lock()
	var out: Array = []
	for note in pending:
		var copy: Dictionary = note.duplicate()
		copy["count"] = int(counts.get(note.key, 1))
		copy.erase("key")
		out.append(copy)
	pending.clear()
	mutex.unlock()
	return out
