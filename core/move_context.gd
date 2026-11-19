class_name MoveContext
extends RefCounted
## Passed with BEFORE_MOVE so items can change what a move costs.

var move: Dictionary
var cost: int
var wrong: bool
## Ids of the items that changed this move.
var notes: Array[StringName] = []


func _init(p_move: Dictionary, p_cost: int, p_wrong: bool) -> void:
	move = p_move
	cost = p_cost
	wrong = p_wrong
