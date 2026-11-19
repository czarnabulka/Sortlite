class_name BubbleAlgorithm
extends Algorithm
## Bubble Sort, as in Bubble Sort Quest. The board is a column: index 0 is the
## bottom, the last index is the top. The only move swaps two neighbours.
## The top element leaves when it is the biggest one on the board.
## Move: {"type": &"swap", "index": j} swaps j and j + 1.


func _init() -> void:
	id = &"bubble"
	display_name = "Bubble"


func legal_moves(board: Board) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for j in range(board.size() - 1):
		out.append({"type": Events.SWAP, "index": j})
	return out


func is_legal(board: Board, move: Dictionary) -> bool:
	if move.get("type") != Events.SWAP:
		return false
	var j: int = move.get("index", -1)
	return j >= 0 and j < board.size() - 1


## Swap only if a[j] > a[j + 1], the lower one is bigger. Swapping equal
## values is wrong too: Bubble Sort is stable.
func is_wrong(board: Board, move: Dictionary) -> bool:
	var j: int = move["index"]
	return board.value_at(j) <= board.value_at(j + 1)


func apply(board: Board, move: Dictionary) -> void:
	var j: int = move["index"]
	board.swap(j, j + 1)


func surface_index(board: Board) -> int:
	return board.size() - 1


func can_surface(board: Board) -> bool:
	return board.value_at(board.size() - 1) == board.max_value()


## Newcomers enter at the bottom, so each one has to be carried up.
func arrive_index(_board: Board) -> int:
	return 0
