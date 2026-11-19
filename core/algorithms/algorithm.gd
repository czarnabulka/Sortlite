class_name Algorithm
extends RefCounted
## Base for one algorithm = one kind of room: which moves the player has,
## what they cost, which ones break the algorithm's rule, and where the exit is.
## A move is a Dictionary with at least "type" (an Events move-kind name).

var id: StringName
var display_name: String


func legal_moves(_board: Board) -> Array[Dictionary]:
	return []


func is_legal(board: Board, move: Dictionary) -> bool:
	return legal_moves(board).has(move)


func move_cost(_board: Board, _move: Dictionary) -> int:
	return 1


## True when the move goes against the algorithm (the "wrong swap" of BSQ).
## It is still allowed; items and difficulty decide what it costs.
func is_wrong(_board: Board, _move: Dictionary) -> bool:
	return false


func apply(_board: Board, _move: Dictionary) -> void:
	pass


## Index of the exit cell. Only called on a non-empty board.
func surface_index(_board: Board) -> int:
	return 0


## True when the element at the exit is in its final place and may leave.
func can_surface(_board: Board) -> bool:
	return false


## Where a newcomer enters.
func arrive_index(board: Board) -> int:
	return board.size()


## Order in which a refill batch enters, so its elements still need sorting.
func order_batch(values: Array[int]) -> Array[int]:
	return values


## The newcomer that hurts most (the Adversary boss feeds these).
func adversary_value(_board: Board, rng: RandomNumberGenerator, vmax: int) -> int:
	return rng.randi_range(1, vmax)
