class_name ScoreContext
extends RefCounted
## One surfacing being scored. Gained score = points × mult, like chips × mult.
## Handlers of Events.SURFACE add to either side; their order is slot order.

var element: Element
## 1 for the first element of a chain, 2 for the second, and so on.
var chain: int
var points: int
var mult: int
## Ids of the items that changed this scoring, in order (the UI flashes them).
var notes: Array[StringName] = []
## What each item did, in order: {"id", "kind", "amount"}, kind is one of
## POINTS (+points), MULT (+mult), XPOINTS (points ×), XMULT (mult ×).
var effects: Array[Dictionary] = []

const POINTS := &"points"
const MULT := &"mult"
const XPOINTS := &"xpoints"
const XMULT := &"xmult"


func _init(p_element: Element, p_chain: int, p_points: int, p_mult: int) -> void:
	element = p_element
	chain = p_chain
	points = p_points
	mult = p_mult


func total() -> int:
	return points * mult


## Applies an item's change and records it, so the screen can show it.
func apply(id: StringName, kind: StringName, amount: int) -> void:
	match kind:
		POINTS:
			points += amount
		MULT:
			mult += amount
		XPOINTS:
			points *= amount
		XMULT:
			mult *= amount
	notes.append(id)
	effects.append({"id": id, "kind": kind, "amount": amount})
