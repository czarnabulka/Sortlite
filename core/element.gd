class_name Element
extends RefCounted
## One number on the board. It keeps its identity (uid) while it moves, so
## markers such as "glass" or "gold" can stay attached to it.

var uid: int
var value: int
var markers: Dictionary = {}  # StringName -> Variant


func _init(p_value: int, p_uid: int) -> void:
	value = p_value
	uid = p_uid


func has_marker(marker: StringName) -> bool:
	return markers.has(marker)


func _to_string() -> String:
	return str(value)
