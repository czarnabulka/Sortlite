class_name Item
extends RefCounted
## A passive item: data plus handlers for the events it reacts to. Items never
## reference each other; synergies come from sharing events and number props.

var id: StringName
## Translation keys (i18n/strings.csv); the screen shows tr(name_key).
var name_key: String
var desc_key: String
var tags: Array[StringName] = []
var rarity := 1
## The only algorithm this item works in (Algorithms.*), or &"" for any.
## Offers skip it when no room left on the floor uses that algorithm.
var algorithm: StringName = &""

var _handlers: Dictionary = {}  # StringName -> Callable
var _bus: EventBus


func _init(p_id: StringName, p_tags: Array[StringName] = []) -> void:
	id = p_id
	var key := "ITEM_%s" % String(p_id).to_upper()
	name_key = key + "_NAME"
	desc_key = key + "_DESC"
	tags = p_tags


func only_for(p_algorithm: StringName) -> Item:
	algorithm = p_algorithm
	return self


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
