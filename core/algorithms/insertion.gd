class_name InsertionAlgorithm
extends Algorithm
## Insertion Sort. The board is a row: index 0 is the exit on the left.
## The sorted part is the longest non-decreasing run from the left; the first
## element after it is the key. The only move puts the key into the sorted
## part; every element it has to shift over costs 1.
## The leftmost element leaves when it is the smallest one on the board.
## Move: {"type": &"insert", "to": p} with 0 <= p < k (k = sorted length).


func _init() -> void:
	id = &"insertion"
	display_name = "Insertion"


func key_index(board: Board) -> int:
	return board.sorted_prefix_length()


func legal_moves(board: Board) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var k := key_index(board)
	if k >= board.size():
		return out
	for p in range(k):
		out.append({"type": Events.INSERT, "to": p})
	return out


func is_legal(board: Board, move: Dictionary) -> bool:
	if move.get("type") != Events.INSERT:
		return false
	var k := key_index(board)
	var p: int = move.get("to", -1)
	return k < board.size() and p >= 0 and p < k


func move_cost(board: Board, move: Dictionary) -> int:
	return maxi(1, key_index(board) - int(move["to"]))


## The right place keeps the sorted part sorted and is stable: the key goes
## after every element equal to it.
func is_wrong(board: Board, move: Dictionary) -> bool:
	var k := key_index(board)
	var p: int = move["to"]
	var key := board.value_at(k)
	var left_ok := p == 0 or board.value_at(p - 1) <= key
	var right_ok := board.value_at(p) > key
	return not (left_ok and right_ok)


func apply(board: Board, move: Dictionary) -> void:
	board.move_element(key_index(board), int(move["to"]))


func surface_index(_board: Board) -> int:
	return 0


func can_surface(board: Board) -> bool:
	return board.value_at(0) == board.min_value()


## Newcomers join the unsorted part on the right.
func arrive_index(board: Board) -> int:
	return board.size()
