class_name MoveContext
extends RefCounted
## Passed with BEFORE_MOVE so items can change what a move costs.

var move: Dictionary
var cost: int
var wrong: bool
## Ids of the items that changed this move.
var notes: Array[StringName] = []
## What to show for them: {"id", "label"}. The room sends these as
## Events.ITEM_TRIGGERED only once the move is really made, so a move refused
## for lack of budget shows nothing.
var pings: Array[Dictionary] = []


func _init(p_move: Dictionary, p_cost: int, p_wrong: bool) -> void:
	move = p_move
	cost = p_cost
	wrong = p_wrong


## Records that item `id` changed this move; `label` is a translation key.
func note(id: StringName, label := "") -> void:
	notes.append(id)
	pings.append({"id": id, "label": label})
