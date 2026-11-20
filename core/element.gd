class_name Element
extends RefCounted
## One number on the board. It keeps its identity (uid) while it moves, so
## markers such as "glass" or "gold" can stay attached to it.

var uid: int
var value: int
var markers: Dictionary = {}  # StringName -> Variant

## Sent by a boss: scores half.
const CURSED := &"cursed"
## Burnt side up (the Burnt Stack boss): scores half.
const BURNT := &"burnt"


func _init(p_value: int, p_uid: int) -> void:
	value = p_value
	uid = p_uid


func has_marker(marker: StringName) -> bool:
	return markers.has(marker)


## Flips the number over: burnt side up becomes clean side up and back.
func turn_over() -> void:
	if markers.has(BURNT):
		markers.erase(BURNT)
	else:
		markers[BURNT] = true


func _to_string() -> String:
	return str(value)
