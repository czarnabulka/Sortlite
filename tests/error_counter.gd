class_name ErrorCounter
extends Logger
## Counts engine and script errors. A GDScript runtime error does not stop the
## caller, so without this a broken test would still be reported as passing.

var count := 0
var last := ""
var _mutex := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	_mutex.lock()
	count += 1
	last = "%s (%s:%d in %s)" % [rationale if rationale != "" else code, file, line, function]
	_mutex.unlock()
