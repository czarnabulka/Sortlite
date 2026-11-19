class_name ScoreContext
extends RefCounted
## One surfacing being scored. Gained score = points × mult, like chips × mult.
## Handlers of Events.SURFACE add to either side; their order is slot order.

var element: Element
## 1 for the first element of a chain, 2 for the second, and so on.
var chain: int
var points: int
var mult: int


func _init(p_element: Element, p_chain: int, p_points: int, p_mult: int) -> void:
	element = p_element
	chain = p_chain
	points = p_points
	mult = p_mult


func total() -> int:
	return points * mult
