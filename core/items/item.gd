class_name Item
extends RefCounted
## A passive item: data plus handlers for the events it reacts to. Items never
## reference each other; synergies come from sharing events and number props.

var id: StringName
var display_name: String
var description: String
var tags: Array[StringName] = []
var rarity := 1

var _handlers: Dictionary = {}  # StringName -> Callable
var _bus: EventBus


func _init(p_id: StringName, p_name: String, p_description: String, p_tags: Array[StringName] = []) -> void:
	id = p_id
	display_name = p_name
	description = p_description
	tags = p_tags


func react(event: StringName, handler: Callable) -> Item:
	_handlers[event] = handler
	return self


## Attach in slot order: the first attached item acts first.
func attach(bus: EventBus) -> void:
	_bus = bus
	for event in _handlers:
		bus.on(event, _handlers[event])


func detach() -> void:
	if _bus == null:
		return
	for event in _handlers:
		_bus.off(event, _handlers[event])
	_bus = null
