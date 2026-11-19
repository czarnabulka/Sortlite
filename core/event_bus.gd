class_name EventBus
extends RefCounted
## Synchronous event bus. Handlers run in the order they were added, which is
## how item slot order (left to right) becomes effect order.

## Items may emit events from inside handlers (an extra swap, a free surface).
## This cap stops two items from feeding each other forever.
const MAX_DEPTH := 32

var record_history := false
var history: Array[Dictionary] = []
## Events cut off by MAX_DEPTH. Above 0 means two items feed each other.
var dropped := 0

var _handlers: Dictionary = {}  # StringName -> Array[Callable]
var _depth := 0


func on(event: StringName, handler: Callable) -> void:
	if not _handlers.has(event):
		_handlers[event] = []
	_handlers[event].append(handler)


func off(event: StringName, handler: Callable) -> void:
	if _handlers.has(event):
		_handlers[event].erase(handler)


func handler_count(event: StringName) -> int:
	return _handlers.get(event, []).size()


## Returns false when the event was dropped because of MAX_DEPTH.
func emit(event: StringName, data: Dictionary = {}) -> bool:
	if _depth >= MAX_DEPTH:
		dropped += 1
		return false
	_depth += 1
	if record_history:
		history.append({"event": event, "data": data})
	# Copy, so a handler that detaches itself does not skip the next one.
	for handler: Callable in _handlers.get(event, []).duplicate():
		if handler.is_valid():
			handler.call(data)
	_depth -= 1
	return true


func events_seen() -> Array[StringName]:
	var names: Array[StringName] = []
	for entry in history:
		names.append(entry["event"])
	return names
